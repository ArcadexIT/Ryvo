import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { parsePagination, paginateMeta } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';
import { WalletTransactionType } from '@ryvo/database';
import { SettingsService } from '../settings/settings.service';

@Injectable()
export class WalletService {
  constructor(
    private prisma: PrismaService,
    private settings: SettingsService,
  ) {}

  private async assertCustomerWalletEnabled() {
    if (!(await this.settings.isCustomerWalletEnabled())) {
      throw new BadRequestException('Customer wallet is currently disabled');
    }
  }

  async getOrCreateWallet(userId: string) {
    let wallet = await this.prisma.wallet.findUnique({ where: { userId } });
    if (!wallet) {
      const currency = await this.settings.getPlatformCurrency();
      wallet = await this.prisma.wallet.create({ data: { userId, currency: currency.code } });
    }
    return wallet;
  }

  async getBalance(userId: string, options?: { bypassFeatureFlag?: boolean }) {
    if (!options?.bypassFeatureFlag) {
      await this.assertCustomerWalletEnabled();
    }
    const wallet = await this.getOrCreateWallet(userId);
    return {
      balance: Number(wallet.balance),
      heldBalance: Number(wallet.heldBalance),
      currency: wallet.currency,
    };
  }

  async getTransactions(
    userId: string,
    dto: PaginationDto,
    options?: { bypassFeatureFlag?: boolean },
  ) {
    if (!options?.bypassFeatureFlag) {
      await this.assertCustomerWalletEnabled();
    }
    const wallet = await this.getOrCreateWallet(userId);
    const { page, limit, skip } = parsePagination(dto);

    const [items, total] = await Promise.all([
      this.prisma.walletTransaction.findMany({
        where: { walletId: wallet.id },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.walletTransaction.count({ where: { walletId: wallet.id } }),
    ]);

    return { items, meta: paginateMeta(page, limit, total) };
  }

  async topUp(userId: string, amount: number, description?: string) {
    await this.assertCustomerWalletEnabled();
    if (amount <= 0) throw new BadRequestException('Amount must be positive');
    return this.applyTransaction(userId, amount, 'top_up', description);
  }

  async adminAdjust(
    userId: string,
    amount: number,
    description?: string,
    adminId?: string,
  ) {
    if (amount === 0) throw new BadRequestException('Amount cannot be zero');
    return this.applyTransaction(
      userId,
      amount,
      'admin_adjustment',
      description ?? `Admin adjustment by ${adminId ?? 'system'}`,
    );
  }

  /** @deprecated Use hold() for job escrow */
  async deduct(userId: string, amount: number, referenceType: string, referenceId: string) {
    if (amount <= 0) throw new BadRequestException('Amount must be positive');
    const wallet = await this.getOrCreateWallet(userId);
    if (Number(wallet.balance) < amount) {
      throw new BadRequestException('Insufficient wallet balance');
    }
    return this.applyTransaction(userId, -amount, 'job_payment', undefined, referenceType, referenceId);
  }

  /** Move funds from available balance into escrow hold for a job. */
  async hold(userId: string, amount: number, jobId: string) {
    if (amount <= 0) throw new BadRequestException('Amount must be positive');

    return this.prisma.$transaction(async (tx) => {
      const wallet = await tx.wallet.upsert({
        where: { userId },
        create: { userId, balance: 0, heldBalance: 0 },
        update: {},
      });

      const available = Number(wallet.balance);
      if (available < amount) {
        throw new BadRequestException('Insufficient wallet balance');
      }

      const newBalance = available - amount;
      const newHeld = Number(wallet.heldBalance) + amount;

      const updated = await tx.wallet.update({
        where: { id: wallet.id },
        data: { balance: newBalance, heldBalance: newHeld },
      });

      const transaction = await tx.walletTransaction.create({
        data: {
          walletId: wallet.id,
          type: 'job_hold',
          amount,
          balanceAfter: newBalance,
          referenceType: 'job',
          referenceId: jobId,
          description: 'Payment held for job',
        },
      });

      return { wallet: updated, transaction };
    });
  }

  /** Capture a held amount when the job completes (funds released to platform). */
  async captureHold(userId: string, amount: number, jobId: string) {
    if (amount <= 0) throw new BadRequestException('Amount must be positive');

    return this.prisma.$transaction(async (tx) => {
      const wallet = await tx.wallet.findUnique({ where: { userId } });
      if (!wallet) throw new BadRequestException('Wallet not found');

      const held = Number(wallet.heldBalance);
      if (held < amount) {
        throw new BadRequestException('Insufficient held balance for this job');
      }

      const newHeld = held - amount;

      const updated = await tx.wallet.update({
        where: { id: wallet.id },
        data: { heldBalance: newHeld },
      });

      const transaction = await tx.walletTransaction.create({
        data: {
          walletId: wallet.id,
          type: 'job_payment',
          amount,
          balanceAfter: Number(wallet.balance),
          referenceType: 'job',
          referenceId: jobId,
          description: 'Job payment captured',
        },
      });

      return { wallet: updated, transaction };
    });
  }

  /** Release a held amount back to the customer wallet (cancel / no-show). */
  async releaseHold(userId: string, amount: number, jobId: string) {
    if (amount <= 0) throw new BadRequestException('Amount must be positive');

    return this.prisma.$transaction(async (tx) => {
      const wallet = await tx.wallet.findUnique({ where: { userId } });
      if (!wallet) throw new BadRequestException('Wallet not found');

      const held = Number(wallet.heldBalance);
      const releaseAmount = Math.min(amount, held);
      if (releaseAmount <= 0) {
        throw new BadRequestException('No held funds to release for this job');
      }

      const newBalance = Number(wallet.balance) + releaseAmount;
      const newHeld = held - releaseAmount;

      const updated = await tx.wallet.update({
        where: { id: wallet.id },
        data: { balance: newBalance, heldBalance: newHeld },
      });

      const transaction = await tx.walletTransaction.create({
        data: {
          walletId: wallet.id,
          type: 'refund',
          amount: releaseAmount,
          balanceAfter: newBalance,
          referenceType: 'job',
          referenceId: jobId,
          description: 'Payment hold released',
        },
      });

      return { wallet: updated, transaction };
    });
  }

  async credit(
    userId: string,
    amount: number,
    description?: string,
    referenceType?: string,
    referenceId?: string,
  ) {
    if (amount <= 0) throw new BadRequestException('Amount must be positive');
    return this.applyTransaction(userId, amount, 'refund', description, referenceType, referenceId);
  }

  private async applyTransaction(
    userId: string,
    amount: number,
    type: WalletTransactionType,
    description?: string,
    referenceType?: string,
    referenceId?: string,
  ) {
    return this.prisma.$transaction(async (tx) => {
      const wallet = await tx.wallet.upsert({
        where: { userId },
        create: { userId, balance: 0, heldBalance: 0 },
        update: {},
      });

      const newBalance = Number(wallet.balance) + amount;
      if (newBalance < 0) {
        throw new BadRequestException('Insufficient wallet balance');
      }

      const updated = await tx.wallet.update({
        where: { id: wallet.id },
        data: { balance: newBalance },
      });

      const transaction = await tx.walletTransaction.create({
        data: {
          walletId: wallet.id,
          type,
          amount: Math.abs(amount),
          balanceAfter: newBalance,
          referenceType,
          referenceId,
          description,
        },
      });

      return { wallet: updated, transaction };
    });
  }

  async findUserById(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async lookupUser(query: string) {
    const user = await this.prisma.user.findFirst({
      where: {
        OR: [
          { id: query },
          { phone: { contains: query } },
          { fullName: { contains: query, mode: 'insensitive' } },
        ],
      },
      select: { id: true, fullName: true, phone: true, role: true },
    });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  /**
   * Admin finance view. Providers use provider_earnings for withdrawable balance
   * (same as the provider app). The wallets table is the customer payment wallet.
   */
  async getAdminBalanceView(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        role: true,
        provider: { select: { id: true } },
      },
    });
    if (!user) throw new NotFoundException('User not found');

    const customerWallet = await this.getBalance(userId, { bypassFeatureFlag: true });

    let providerEarnings: {
      available: number;
      pending: number;
      currency: string;
    } | null = null;

    if (user.provider) {
      const [pendingAgg, processingAgg] = await Promise.all([
        this.prisma.providerEarning.aggregate({
          where: { providerId: user.provider.id, payoutStatus: 'pending' },
          _sum: { netAmount: true },
        }),
        this.prisma.providerEarning.aggregate({
          where: { providerId: user.provider.id, payoutStatus: 'processing' },
          _sum: { netAmount: true },
        }),
      ]);
      providerEarnings = {
        available: Math.round(Number(pendingAgg._sum.netAmount ?? 0) * 100) / 100,
        pending: Math.round(Number(processingAgg._sum.netAmount ?? 0) * 100) / 100,
        currency: (await this.settings.getPlatformCurrency()).code,
      };
    }

    return {
      role: user.role,
      // Primary display balance: provider withdrawable earnings when applicable.
      balance: providerEarnings?.available ?? customerWallet.balance,
      heldBalance: customerWallet.heldBalance,
      currency: providerEarnings?.currency ?? customerWallet.currency,
      customerWallet,
      providerEarnings,
    };
  }
}
