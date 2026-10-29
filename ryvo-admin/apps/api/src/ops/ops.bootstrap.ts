import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AgreementsService } from './agreements.service';

@Injectable()
export class OpsBootstrap implements OnModuleInit {
  private readonly logger = new Logger(OpsBootstrap.name);

  constructor(
    private prisma: PrismaService,
    private agreements: AgreementsService,
  ) {}

  async onModuleInit() {
    await this.agreements.ensureDefaults().catch((err) => this.logger.warn(err));
    await this.ensureZone().catch((err) => this.logger.warn(err));
    await this.ensureRideClasses().catch((err) => this.logger.warn(err));
    await this.ensureParcelClasses().catch((err) => this.logger.warn(err));
    await this.ensureSubscriptionPlans().catch((err) => this.logger.warn(err));
    await this.ensureFeatureSettings().catch((err) => this.logger.warn(err));
    await this.refreshRideCopy().catch((err) => this.logger.warn(err));
    await this.refreshDriverWording().catch((err) => this.logger.warn(err));
  }

  /** User-facing copy says Driver. Rewrite stored text that still says provider. */
  private driverWord(text: string) {
    return text
      .replace(/\bProviders\b/g, 'Drivers')
      .replace(/\bproviders\b/g, 'drivers')
      .replace(/\bProvider\b/g, 'Driver')
      .replace(/\bprovider\b/g, 'driver');
  }

  private async refreshDriverWording() {
    const docs = await this.prisma.agreementDocument.findMany();
    for (const doc of docs) {
      const title = this.driverWord(doc.title);
      const body = this.driverWord(doc.body);
      const acknowledgements = doc.acknowledgements.map((item) => this.driverWord(item));
      const same =
        title === doc.title &&
        body === doc.body &&
        acknowledgements.every((item, index) => item === doc.acknowledgements[index]);
      if (same) continue;
      await this.prisma.agreementDocument.update({
        where: { id: doc.id },
        data: { title, body, acknowledgements },
      });
    }

    const programs = await this.prisma.trainingProgram.findMany();
    for (const program of programs) {
      const title = this.driverWord(program.title);
      if (title !== program.title) {
        await this.prisma.trainingProgram.update({ where: { id: program.id }, data: { title } });
      }
    }

    const blocks = await this.prisma.trainingBlock.findMany();
    for (const block of blocks) {
      const body = this.driverWord(block.body);
      if (body !== block.body) {
        await this.prisma.trainingBlock.update({ where: { id: block.id }, data: { body } });
      }
    }

    const options = await this.prisma.trainingOption.findMany();
    for (const option of options) {
      const label = this.driverWord(option.label);
      if (label !== option.label) {
        await this.prisma.trainingOption.update({ where: { id: option.id }, data: { label } });
      }
    }

    const templates = await this.prisma.notificationTemplate.findMany();
    for (const template of templates) {
      const titleTemplate = this.driverWord(template.titleTemplate);
      const bodyTemplate = this.driverWord(template.bodyTemplate);
      if (titleTemplate === template.titleTemplate && bodyTemplate === template.bodyTemplate) continue;
      await this.prisma.notificationTemplate.update({
        where: { id: template.id },
        data: { titleTemplate, bodyTemplate },
      });
    }
  }

  /** Activate passenger ride classes and retire roadside categories. */
  private async ensureRideClasses() {
    const legacy = ['jump-start', 'flat-tire', 'fuel-delivery', 'towing'];
    await this.prisma.serviceCategory.updateMany({
      where: { slug: { in: legacy } },
      data: { isActive: false },
    });

    const rideClasses = [
      {
        name: 'Ryvo Go',
        slug: 'ryvo-go',
        icon: 'directions_car',
        description: 'Everyday rides for up to 4 passengers',
        sortOrder: 1,
        baseFare: 2.5,
        perKmRate: 1.2,
        perMinuteRate: 0.25,
        minFare: 4.5,
      },
      {
        name: 'Comfort',
        slug: 'comfort',
        icon: 'airline_seat_recline_extra',
        description: 'Newer cars with extra legroom',
        sortOrder: 2,
        baseFare: 4,
        perKmRate: 1.8,
        perMinuteRate: 0.35,
        minFare: 7,
      },
      {
        name: 'XL',
        slug: 'xl',
        icon: 'airport_shuttle',
        description: 'Larger vehicles for groups and luggage',
        sortOrder: 3,
        baseFare: 5.5,
        perKmRate: 2.2,
        perMinuteRate: 0.4,
        minFare: 9,
      },
      {
        name: 'Premium',
        slug: 'premium',
        icon: 'diamond',
        description: 'Top-rated drivers in higher-end cars',
        sortOrder: 4,
        baseFare: 7,
        perKmRate: 2.8,
        perMinuteRate: 0.5,
        minFare: 12,
      },
      {
        name: 'Pet',
        slug: 'pet',
        icon: 'pets',
        description: 'Pet-friendly rides, with help for your animal',
        sortOrder: 5,
        baseFare: 3.5,
        perKmRate: 1.5,
        perMinuteRate: 0.3,
        minFare: 6,
      },
      {
        name: 'Van',
        slug: 'van',
        icon: 'local_shipping',
        description: 'Vans for groups, luggage, and bulky items',
        sortOrder: 6,
        baseFare: 6.5,
        perKmRate: 2.6,
        perMinuteRate: 0.45,
        minFare: 11,
      },
      {
        name: 'Assist',
        slug: 'assist',
        icon: 'accessible',
        description: 'Wheelchair-accessible vehicles',
        sortOrder: 7,
        baseFare: 3,
        perKmRate: 1.4,
        perMinuteRate: 0.3,
        minFare: 5.5,
      },
      {
        name: 'Green',
        slug: 'green',
        icon: 'electric_car',
        description: 'Electric and hybrid cars',
        sortOrder: 8,
        baseFare: 3,
        perKmRate: 1.4,
        perMinuteRate: 0.28,
        minFare: 5,
      },
    ];

    for (const rideClass of rideClasses) {
      const category = await this.prisma.serviceCategory.upsert({
        where: { slug: rideClass.slug },
        update: {},
        create: {
          name: rideClass.name,
          slug: rideClass.slug,
          icon: rideClass.icon,
          description: rideClass.description,
          sortOrder: rideClass.sortOrder,
          businessType: 'taxi',
          isActive: true,
        },
      });
      const ruleId = `${rideClass.slug}-default-pricing`;
      const existingRule = await this.prisma.servicePricingRule.findUnique({ where: { id: ruleId } });
      if (!existingRule) {
        await this.prisma.servicePricingRule.create({
          data: {
            id: ruleId,
            serviceCategoryId: category.id,
            baseFare: rideClass.baseFare,
            perKmRate: rideClass.perKmRate,
            perMinuteRate: rideClass.perMinuteRate,
            minFare: rideClass.minFare,
            city: 'default',
          },
        });
      }
    }
  }

  private async ensureParcelClasses() {
    const parcelClasses = [
      {
        name: 'Parcel Bike',
        slug: 'parcel-bike',
        icon: 'two_wheeler',
        description: 'Small packages by motorcycle',
        sortOrder: 10,
        baseFare: 2,
        perKmRate: 0.8,
        perMinuteRate: 0.15,
        minFare: 3.5,
      },
      {
        name: 'Parcel Car',
        slug: 'parcel-car',
        icon: 'local_shipping',
        description: 'Larger parcels by car',
        sortOrder: 11,
        baseFare: 3.5,
        perKmRate: 1.1,
        perMinuteRate: 0.2,
        minFare: 6,
      },
    ];
    for (const parcelClass of parcelClasses) {
      const category = await this.prisma.serviceCategory.upsert({
        where: { slug: parcelClass.slug },
        update: {},
        create: {
          name: parcelClass.name,
          slug: parcelClass.slug,
          icon: parcelClass.icon,
          description: parcelClass.description,
          sortOrder: parcelClass.sortOrder,
          businessType: 'parcel',
          isActive: true,
        },
      });
      const ruleId = `${parcelClass.slug}-default-pricing`;
      const existingRule = await this.prisma.servicePricingRule.findUnique({ where: { id: ruleId } });
      if (!existingRule) {
        await this.prisma.servicePricingRule.create({
          data: {
            id: ruleId,
            serviceCategoryId: category.id,
            baseFare: parcelClass.baseFare,
            perKmRate: parcelClass.perKmRate,
            perMinuteRate: parcelClass.perMinuteRate,
            minFare: parcelClass.minFare,
            city: 'default',
          },
        });
      }
    }
  }

  private async ensureSubscriptionPlans() {
    const plans = [
      { id: 'plan-daily', name: 'Daily', period: 'daily' as const, price: 4.99, sortOrder: 1 },
      { id: 'plan-weekly', name: 'Weekly', period: 'weekly' as const, price: 24.99, sortOrder: 2 },
      { id: 'plan-monthly', name: 'Monthly', period: 'monthly' as const, price: 79.99, sortOrder: 3 },
    ];
    for (const plan of plans) {
      await this.prisma.driverSubscriptionPlan.upsert({
        where: { id: plan.id },
        update: {
          name: plan.name,
          period: plan.period,
          price: plan.price,
          isActive: true,
          sortOrder: plan.sortOrder,
        },
        create: {
          id: plan.id,
          name: plan.name,
          period: plan.period,
          price: plan.price,
          commissionRate: 0,
          isActive: true,
          sortOrder: plan.sortOrder,
        },
      });
    }
  }

  private async ensureFeatureSettings() {
    const defaults: { key: string; value: unknown }[] = [
      { key: 'bid_window_sec', value: 120 },
      { key: 'bid_min_fare_ratio', value: 0.5 },
      { key: 'bid_max_fare_ratio', value: 2 },
      { key: 'bid_counters_enabled', value: true },
      { key: 'parcel_otp_enabled', value: true },
      { key: 'driver_monetization_mode', value: 'commission' },
      { key: 'whatsapp_booking_enabled', value: false },
      {
        key: 'whatsapp_welcome_text',
        value:
          'Hi, this is RYVO. Reply with Ride, Bid, or Parcel to book without the app. Send your pickup, then dropoff.',
      },
    ];
    for (const setting of defaults) {
      await this.prisma.platformSetting.upsert({
        where: { key: setting.key },
        update: {},
        create: { key: setting.key, value: setting.value as object },
      });
    }
  }

  /** Replace leftover roadside agreement copy on databases that already seeded it. */
  private async refreshRideCopy() {
    await this.prisma.agreementDocument.updateMany({
      where: { key: 'service', isCurrent: true, body: { contains: 'roadside' } },
      data: {
        title: 'Driver Agreement',
        body: `Ryvo Driver Agreement

By accepting this agreement, you confirm that you are licensed to carry passengers, that your vehicle, insurance and documents are accurate, and that you will follow RYVO ride platform policies.

This text is a product placeholder and should be reviewed by a lawyer before it is treated as a binding agreement.`,
      },
    });
  }

  private async ensureZone() {
    const count = await this.prisma.serviceZone.count();
    if (count > 0) return;
    await this.prisma.serviceZone.create({
      data: {
        name: 'Birmingham',
        audience: 'both',
        centerLat: 52.4862,
        centerLng: -1.8904,
        radiusKm: 25,
        isActive: true,
      },
    });
  }

  private async ensureEquipment() {
    const categories = await this.prisma.serviceCategory.findMany({
      where: { slug: { in: ['jump-start', 'fuel-delivery'] } },
    });
    for (const category of categories) {
      const existing = await this.prisma.equipmentRequirement.count({
        where: { serviceCategoryId: category.id },
      });
      if (existing) continue;
      const labels =
        category.slug === 'jump-start'
          ? ['12v Jump pack - 15000A+', 'Jump cables']
          : ['10 litre petrol canister with nozzle (green)', '10 litre diesel canister with nozzle (black)'];
      await this.prisma.equipmentRequirement.createMany({
        data: labels.map((label, index) => ({
          serviceCategoryId: category.id,
          label,
          sortOrder: index,
        })),
      });
    }
  }

  private async ensureTraining() {
    const onboarding = await this.prisma.trainingProgram.findFirst({ where: { serviceCategoryId: null } });
    if (!onboarding) {
      const program = await this.prisma.trainingProgram.create({
        data: { title: 'Driver onboarding', passPercent: 80, isActive: true },
      });
      await this.prisma.trainingBlock.createMany({
        data: [
          {
            programId: program.id,
            sortOrder: 0,
            type: 'text',
            body: 'Work safely, confirm the vehicle details, and only use equipment you are qualified to use.',
          },
          {
            programId: program.id,
            sortOrder: 1,
            type: 'text',
            body: 'You are an independent driver. You are responsible for your own tax and for keeping valid insurance.',
          },
        ],
      });
      await this.addQuestion(program.id, 0, 'Who is responsible for your tax and National Insurance?', [
        ['RYVO deducts PAYE for every driver', false],
        ['You are responsible for your own tax affairs where they apply', true],
      ]);
      await this.addQuestion(program.id, 1, 'When should you confirm the job details with the customer?', [
        ['After you leave the scene', false],
        ['Before you start work', true],
      ]);
    }

    const categories = await this.prisma.serviceCategory.findMany({
      where: { slug: { in: ['jump-start', 'fuel-delivery'] } },
    });
    for (const category of categories) {
      const exists = await this.prisma.trainingProgram.findFirst({ where: { serviceCategoryId: category.id } });
      if (exists) continue;
      const program = await this.prisma.trainingProgram.create({
        data: {
          title: `${category.name} qualification`,
          serviceCategoryId: category.id,
          passPercent: 80,
          isActive: true,
        },
      });
      await this.prisma.trainingBlock.create({
        data: {
          programId: program.id,
          sortOrder: 0,
          type: 'text',
          body: `Complete this ${category.name} module, then pass the test and upload the equipment photos for this job type.`,
        },
      });
      await this.addQuestion(program.id, 0, `Can you accept a ${category.name} job before this qualification is approved?`, [
        ['Yes, any approved driver can take every job type', false],
        ['No, this job type stays locked until the qualification is approved', true],
      ]);
    }
  }

  private async addQuestion(programId: string, sortOrder: number, prompt: string, options: [string, boolean][]) {
    const question = await this.prisma.trainingQuestion.create({
      data: { programId, sortOrder, prompt },
    });
    await this.prisma.trainingOption.createMany({
      data: options.map(([label, isCorrect]) => ({ questionId: question.id, label, isCorrect })),
    });
  }
}
