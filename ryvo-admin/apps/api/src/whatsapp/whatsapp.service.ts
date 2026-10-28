import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@ryvo/database';
import { PrismaService } from '../prisma/prisma.service';
import { SettingsService } from '../settings/settings.service';
import { JobsService } from '../jobs/jobs.service';
import { SmsService } from '../sms/sms.service';

type SessionState =
  | 'idle'
  | 'choose_type'
  | 'pickup'
  | 'dropoff'
  | 'category'
  | 'offer_price'
  | 'parcel_details'
  | 'confirm';

interface SessionDraft {
  jobType?: 'taxi' | 'bidding' | 'parcel';
  pickupAddress?: string;
  pickupLat?: number;
  pickupLng?: number;
  dropoffAddress?: string;
  dropoffLat?: number;
  dropoffLng?: number;
  serviceCategoryId?: string;
  serviceCategoryName?: string;
  offeredPrice?: number;
  estimatedFare?: number;
  recipientName?: string;
  recipientPhone?: string;
  parcelSize?: 'small' | 'medium' | 'large';
}

@Injectable()
export class WhatsAppService {
  private readonly logger = new Logger(WhatsAppService.name);

  constructor(
    private prisma: PrismaService,
    private settings: SettingsService,
    private jobs: JobsService,
    private sms: SmsService,
    private config: ConfigService,
  ) {}

  async handleIncoming(fromRaw: string, bodyRaw: string) {
    if (!(await this.settings.isWhatsAppBookingEnabled())) {
      return { ignored: true };
    }
    const phone = this.normalizePhone(fromRaw);
    const text = (bodyRaw ?? '').trim();
    if (!phone || !text) return { ignored: true };

    const welcome = await this.settings.getWhatsAppWelcomeText();
    let session = await this.prisma.whatsAppSession.findUnique({ where: { phone } });
    if (!session) {
      session = await this.prisma.whatsAppSession.create({
        data: { phone, state: 'idle', draft: {} },
      });
    }

    const lower = text.toLowerCase();
    if (['hi', 'hello', 'start', 'menu', 'help'].includes(lower)) {
      await this.setState(session.id, 'choose_type', {});
      await this.reply(phone, welcome);
      return { ok: true };
    }

    const draft = (session.draft ?? {}) as SessionDraft;
    const interpreted = await this.interpret(text, session.state, draft);
    const nextText = interpreted.text ?? text;
    let state = (interpreted.state ?? session.state) as SessionState;
    let nextDraft: SessionDraft = { ...draft, ...interpreted.draft };

    if (state === 'idle' || state === 'choose_type') {
      const type = this.parseJobType(nextText);
      if (!type) {
        await this.setState(session.id, 'choose_type', nextDraft);
        await this.reply(phone, 'Reply with Ride, Bid, or Parcel to start.');
        return { ok: true };
      }
      nextDraft.jobType = type;
      state = 'pickup';
      await this.setState(session.id, state, nextDraft);
      await this.reply(phone, `Great, ${type} it is. Send your pickup address.`);
      return { ok: true };
    }

    if (state === 'pickup') {
      const geo = await this.geocode(nextText);
      if (!geo) {
        await this.reply(phone, 'I could not find that pickup. Send a street address or landmark.');
        return { ok: true };
      }
      nextDraft.pickupAddress = geo.address;
      nextDraft.pickupLat = geo.lat;
      nextDraft.pickupLng = geo.lng;
      state = 'dropoff';
      await this.setState(session.id, state, nextDraft);
      await this.reply(phone, `Pickup set to ${geo.address}. Now send the dropoff address.`);
      return { ok: true };
    }

    if (state === 'dropoff') {
      const geo = await this.geocode(nextText);
      if (!geo) {
        await this.reply(phone, 'I could not find that dropoff. Send another address.');
        return { ok: true };
      }
      nextDraft.dropoffAddress = geo.address;
      nextDraft.dropoffLat = geo.lat;
      nextDraft.dropoffLng = geo.lng;
      state = nextDraft.jobType === 'parcel' ? 'parcel_details' : 'category';
      await this.setState(session.id, state, nextDraft);
      if (state === 'parcel_details') {
        await this.reply(phone, 'Send recipient as: Name, phone, size (small/medium/large).');
      } else {
        const categories = await this.categoriesFor(nextDraft.jobType === 'parcel' ? 'parcel' : 'taxi');
        await this.reply(
          phone,
          `Choose a class by number:\n${categories.map((c, i) => `${i + 1}. ${c.name}`).join('\n')}`,
        );
      }
      return { ok: true };
    }

    if (state === 'parcel_details') {
      const parsed = this.parseParcelDetails(nextText);
      if (!parsed) {
        await this.reply(phone, 'Send recipient as: Name, phone, size (small/medium/large).');
        return { ok: true };
      }
      nextDraft = { ...nextDraft, ...parsed };
      state = 'category';
      await this.setState(session.id, state, nextDraft);
      const categories = await this.categoriesFor('parcel');
      await this.reply(
        phone,
        `Choose a parcel class by number:\n${categories.map((c, i) => `${i + 1}. ${c.name}`).join('\n')}`,
      );
      return { ok: true };
    }

    if (state === 'category') {
      const businessType = nextDraft.jobType === 'parcel' ? 'parcel' : 'taxi';
      const categories = await this.categoriesFor(businessType);
      const index = Number(nextText) - 1;
      const chosen =
        categories[index] ??
        categories.find((c) => c.name.toLowerCase() === nextText.toLowerCase() || c.slug === nextText.toLowerCase());
      if (!chosen) {
        await this.reply(phone, 'Reply with the class number from the list.');
        return { ok: true };
      }
      nextDraft.serviceCategoryId = chosen.id;
      nextDraft.serviceCategoryName = chosen.name;
      const fare = await this.jobs.estimateFare({
        serviceCategoryId: chosen.id,
        pickupLat: nextDraft.pickupLat!,
        pickupLng: nextDraft.pickupLng!,
        dropoffLat: nextDraft.dropoffLat,
        dropoffLng: nextDraft.dropoffLng,
      });
      nextDraft.estimatedFare = fare.estimatedFare;
      if (nextDraft.jobType === 'bidding') {
        state = 'offer_price';
        await this.setState(session.id, state, nextDraft);
        await this.reply(
          phone,
          `Suggested fare is ${fare.estimatedFare}. Send the price you want to offer.`,
        );
        return { ok: true };
      }
      state = 'confirm';
      await this.setState(session.id, state, nextDraft);
      await this.reply(
        phone,
        `Confirm ${nextDraft.jobType} ${chosen.name} from ${nextDraft.pickupAddress} to ${nextDraft.dropoffAddress} for ${fare.estimatedFare}? Reply YES to book.`,
      );
      return { ok: true };
    }

    if (state === 'offer_price') {
      const amount = Number(nextText.replace(/[^0-9.]/g, ''));
      if (!Number.isFinite(amount) || amount <= 0) {
        await this.reply(phone, 'Send a number for your offer.');
        return { ok: true };
      }
      nextDraft.offeredPrice = amount;
      state = 'confirm';
      await this.setState(session.id, state, nextDraft);
      await this.reply(
        phone,
        `Confirm bid of ${amount} from ${nextDraft.pickupAddress} to ${nextDraft.dropoffAddress}? Reply YES to book.`,
      );
      return { ok: true };
    }

    if (state === 'confirm') {
      if (!['yes', 'y', 'confirm', 'book', 'ok'].includes(lower)) {
        await this.setState(session.id, 'choose_type', {});
        await this.reply(phone, 'Cancelled. Reply Ride, Bid, or Parcel to start again.');
        return { ok: true };
      }
      try {
        const customer = await this.ensureCustomer(phone);
        const job = await this.jobs.createJob(customer.id, {
          serviceCategoryId: nextDraft.serviceCategoryId!,
          pickupAddress: nextDraft.pickupAddress!,
          pickupLat: nextDraft.pickupLat!,
          pickupLng: nextDraft.pickupLng!,
          dropoffAddress: nextDraft.dropoffAddress!,
          dropoffLat: nextDraft.dropoffLat!,
          dropoffLng: nextDraft.dropoffLng!,
          paymentMethod: 'cash',
          jobType: nextDraft.jobType,
          offeredPrice: nextDraft.offeredPrice,
          recipientName: nextDraft.recipientName,
          recipientPhone: nextDraft.recipientPhone,
          parcelSize: nextDraft.parcelSize,
          channel: 'whatsapp',
        });
        await this.prisma.whatsAppSession.update({
          where: { id: session.id },
          data: { state: 'idle', draft: {}, lastJobId: job.id, customerId: customer.id, lastMessageAt: new Date() },
        });
        await this.reply(
          phone,
          `Booked ${job.jobNumber}. We are looking for a driver. I will message you when one accepts.`,
        );
      } catch (err) {
        const message = (err as Error).message ?? 'Could not create the booking';
        await this.reply(phone, `Could not book: ${message}`);
      }
      return { ok: true };
    }

    await this.reply(phone, welcome);
    return { ok: true };
  }

  async notifyJob(jobId: string, text: string) {
    const session = await this.prisma.whatsAppSession.findFirst({ where: { lastJobId: jobId } });
    if (!session) return;
    await this.reply(session.phone, text);
  }

  private async reply(phone: string, body: string) {
    await this.sms.sendWhatsApp(phone, body);
  }

  private async setState(id: string, state: SessionState, draft: SessionDraft) {
    await this.prisma.whatsAppSession.update({
      where: { id },
      data: { state, draft: draft as Prisma.InputJsonValue, lastMessageAt: new Date() },
    });
  }

  private parseJobType(text: string): SessionDraft['jobType'] | null {
    const lower = text.toLowerCase();
    if (lower.includes('parcel') || lower.includes('delivery') || lower.includes('package')) return 'parcel';
    if (lower.includes('bid') || lower.includes('offer') || lower.includes('indrive')) return 'bidding';
    if (lower.includes('ride') || lower.includes('taxi') || lower.includes('cab')) return 'taxi';
    return null;
  }

  private parseParcelDetails(text: string): Pick<SessionDraft, 'recipientName' | 'recipientPhone' | 'parcelSize'> | null {
    const parts = text.split(',').map((part) => part.trim()).filter(Boolean);
    if (parts.length < 2) return null;
    const sizeRaw = (parts[2] ?? 'small').toLowerCase();
    const parcelSize = sizeRaw.includes('large') ? 'large' : sizeRaw.includes('medium') ? 'medium' : 'small';
    return { recipientName: parts[0], recipientPhone: parts[1], parcelSize };
  }

  private async categoriesFor(businessType: 'taxi' | 'parcel') {
    return this.prisma.serviceCategory.findMany({
      where: { isActive: true, businessType },
      orderBy: { sortOrder: 'asc' },
    });
  }

  private async ensureCustomer(phone: string) {
    const existing = await this.prisma.user.findUnique({
      where: { phone },
      include: { customer: true },
    });
    if (existing?.customer) return existing.customer;
    const user = await this.prisma.user.create({
      data: {
        phone,
        fullName: `WhatsApp ${phone.slice(-4)}`,
        role: 'customer',
        status: 'active',
        phoneVerifiedAt: new Date(),
        customer: { create: {} },
        wallet: { create: { balance: 0 } },
      },
      include: { customer: true },
    });
    return user.customer!;
  }

  private normalizePhone(value: string) {
    return value.replace(/^whatsapp:/, '').trim();
  }

  private async geocode(query: string): Promise<{ address: string; lat: number; lng: number } | null> {
    const key = await this.settings.get('map_api_key');
    const apiKey = typeof key === 'string' && key.trim() ? key.trim() : this.config.get<string>('GOOGLE_MAPS_API_KEY') ?? '';
    if (!apiKey) {
      return { address: query, lat: 52.4862, lng: -1.8904 };
    }
    try {
      const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(query)}&key=${apiKey}`;
      const res = await fetch(url);
      const json = (await res.json()) as {
        results?: { formatted_address: string; geometry: { location: { lat: number; lng: number } } }[];
      };
      const first = json.results?.[0];
      if (!first) return null;
      return {
        address: first.formatted_address,
        lat: first.geometry.location.lat,
        lng: first.geometry.location.lng,
      };
    } catch (err) {
      this.logger.warn(err);
      return null;
    }
  }

  private async interpret(text: string, state: string, draft: SessionDraft) {
    const apiKey = this.config.get<string>('OPENAI_API_KEY')?.trim();
    if (!apiKey) return {};
    try {
      const res = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: this.config.get<string>('OPENAI_MODEL')?.trim() || 'gpt-4o-mini',
          temperature: 0,
          messages: [
            {
              role: 'system',
              content:
                'Extract taxi booking fields. Return JSON only: {"state":"idle|choose_type|pickup|dropoff|category|offer_price|parcel_details|confirm","draft":{"jobType":"taxi|bidding|parcel","pickupAddress":"","dropoffAddress":"","offeredPrice":0,"recipientName":"","recipientPhone":"","parcelSize":"small"},"text":"normalized user text"}. Keep unknown fields omitted.',
            },
            {
              role: 'user',
              content: JSON.stringify({ state, draft, text }),
            },
          ],
        }),
      });
      const json = (await res.json()) as { choices?: { message?: { content?: string } }[] };
      const content = json.choices?.[0]?.message?.content ?? '{}';
      return JSON.parse(content) as { state?: SessionState; draft?: SessionDraft; text?: string };
    } catch (err) {
      this.logger.warn(`OpenAI interpret failed: ${(err as Error).message}`);
      return {};
    }
  }
}
