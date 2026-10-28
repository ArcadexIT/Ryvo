import { BadRequestException, NotFoundException } from '@nestjs/common';
import { UserRole } from '@ryvo/database';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Hard-deletes a customer or provider user after clearing foreign keys that
 * do not cascade. Admin accounts are rejected.
 */
export async function deleteAppUser(prisma: PrismaService, userId: string) {
  await prisma.$transaction(
    async (tx) => {
      const user = await tx.user.findUnique({
        where: { id: userId },
        select: {
          id: true,
          role: true,
          adminUser: { select: { id: true } },
          customer: { select: { id: true } },
          provider: { select: { id: true } },
        },
      });
      if (!user) throw new NotFoundException('User not found');
      if (user.role === UserRole.admin || user.adminUser) {
        throw new BadRequestException('Admin accounts cannot be deleted here');
      }

      const providerId = user.provider?.id;
      if (providerId) {
        await tx.providerEarning.deleteMany({ where: { providerId } });
        await tx.payout.deleteMany({ where: { providerId } });
        await tx.jobOffer.deleteMany({ where: { providerId } });
        await tx.jobLocationLog.deleteMany({ where: { providerId } });
        await tx.job.updateMany({ where: { providerId }, data: { providerId: null } });
      }

      const customerId = user.customer?.id;
      if (customerId) {
        const jobs = await tx.job.findMany({
          where: { customerId },
          select: { id: true },
        });
        const jobIds = jobs.map((job) => job.id);
        if (jobIds.length > 0) {
          await tx.invoice.deleteMany({ where: { jobId: { in: jobIds } } });
          await tx.payment.deleteMany({ where: { jobId: { in: jobIds } } });
          await tx.providerEarning.deleteMany({ where: { jobId: { in: jobIds } } });
          await tx.rating.deleteMany({ where: { jobId: { in: jobIds } } });
          await tx.supportTicket.updateMany({
            where: { jobId: { in: jobIds } },
            data: { jobId: null },
          });
          await tx.job.deleteMany({ where: { id: { in: jobIds } } });
        }
        await tx.invoice.deleteMany({ where: { customerId } });
      }

      await tx.rating.deleteMany({
        where: { OR: [{ fromUserId: userId }, { toUserId: userId }] },
      });
      await tx.supportMessage.deleteMany({ where: { senderId: userId } });
      await tx.supportTicket.deleteMany({ where: { userId } });

      await tx.user.delete({ where: { id: userId } });
    },
    { timeout: 30_000 },
  );
}
