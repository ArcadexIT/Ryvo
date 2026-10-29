import { config } from 'dotenv';
import { resolve } from 'path';
import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import {
  RIDE_CLASS_SLUGS,
  PARCEL_CLASS_SLUGS,
  SERVICE_SLUGS,
  PLATFORM_SETTINGS_KEYS,
} from '@ryvo/shared';
import { COUNTRIES_DATA, flagEmoji } from './data/countries-data';

config({ path: resolve(__dirname, '../.env') });

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding database...');

  // Platform settings
  const settings = [
    { key: PLATFORM_SETTINGS_KEYS.MATCHING_RADIUS_KM, value: 15 },
    { key: PLATFORM_SETTINGS_KEYS.OFFER_TIMEOUT_SEC, value: 30 },
    { key: PLATFORM_SETTINGS_KEYS.SEARCH_TIMEOUT_SEC, value: 60 },
    { key: PLATFORM_SETTINGS_KEYS.DEFAULT_COMMISSION_RATE, value: 0.15 },
    { key: PLATFORM_SETTINGS_KEYS.SURGE_ENABLED, value: false },
    { key: PLATFORM_SETTINGS_KEYS.SURGE_MULTIPLIER, value: 1.0 },
    { key: PLATFORM_SETTINGS_KEYS.MAP_API_KEY, value: '' },
    { key: PLATFORM_SETTINGS_KEYS.PROVIDER_OTP_ENABLED, value: true },
    { key: PLATFORM_SETTINGS_KEYS.PROVIDER_AGREEMENT_VERSION, value: '1' },
    { key: PLATFORM_SETTINGS_KEYS.PAYMENT_WALLET_ENABLED, value: false },
    { key: PLATFORM_SETTINGS_KEYS.PAYMENT_STRIPE_ENABLED, value: true },
    { key: PLATFORM_SETTINGS_KEYS.PAYMENT_CASH_ENABLED, value: false },
    { key: PLATFORM_SETTINGS_KEYS.CUSTOMER_WALLET_ENABLED, value: false },
    { key: PLATFORM_SETTINGS_KEYS.CUSTOMER_CANCEL_FEE_AFTER_MATCH, value: 0 },
    { key: PLATFORM_SETTINGS_KEYS.CUSTOMER_CANCEL_FEE_AFTER_ARRIVED, value: 0 },
    { key: PLATFORM_SETTINGS_KEYS.CUSTOMER_CANCEL_FEE_AFTER_START, value: 0 },
    { key: PLATFORM_SETTINGS_KEYS.PROVIDER_CANCEL_PENALTY_AFTER_ACCEPT, value: 0 },
    { key: PLATFORM_SETTINGS_KEYS.PROVIDER_CANCEL_PENALTY_AFTER_ARRIVED, value: 0 },
    { key: PLATFORM_SETTINGS_KEYS.PROVIDER_CANCEL_PENALTY_AFTER_START, value: 0 },
    { key: PLATFORM_SETTINGS_KEYS.BID_WINDOW_SEC, value: 120 },
    { key: PLATFORM_SETTINGS_KEYS.BID_MIN_FARE_RATIO, value: 0.5 },
    { key: PLATFORM_SETTINGS_KEYS.BID_MAX_FARE_RATIO, value: 2 },
    { key: PLATFORM_SETTINGS_KEYS.BID_COUNTERS_ENABLED, value: true },
    { key: PLATFORM_SETTINGS_KEYS.PARCEL_OTP_ENABLED, value: true },
    { key: PLATFORM_SETTINGS_KEYS.DRIVER_MONETIZATION_MODE, value: 'commission' },
    { key: PLATFORM_SETTINGS_KEYS.WHATSAPP_BOOKING_ENABLED, value: false },
    {
      key: PLATFORM_SETTINGS_KEYS.WHATSAPP_WELCOME_TEXT,
      value:
        'Hi, this is RYVO. Reply with Ride, Bid, or Parcel to book without the app. Send your pickup, then dropoff.',
    },
  ];

  for (const setting of settings) {
    await prisma.platformSetting.upsert({
      where: { key: setting.key },
      update: { value: setting.value },
      create: { key: setting.key, value: setting.value },
    });
  }

  // Create-only so a re-seed does not wipe a key saved from the admin panel.
  const vehicleLookupSettings = [
    {
      key: PLATFORM_SETTINGS_KEYS.VEHICLE_LOOKUP_BASE_URL,
      value: 'https://api.checkcardetails.co.uk/vehicledata/vehicleregistration',
    },
    { key: PLATFORM_SETTINGS_KEYS.VEHICLE_LOOKUP_API_KEY, value: '' },
  ];
  for (const setting of vehicleLookupSettings) {
    await prisma.platformSetting.upsert({
      where: { key: setting.key },
      update: {},
      create: { key: setting.key, value: setting.value },
    });
  }

  await prisma.platformSetting.upsert({
    where: { key: PLATFORM_SETTINGS_KEYS.CURRENCY },
    update: {},
    create: { key: PLATFORM_SETTINGS_KEYS.CURRENCY, value: 'GBP' },
  });

  const legacySlugs = [
    SERVICE_SLUGS.JUMP_START,
    SERVICE_SLUGS.FLAT_TIRE,
    SERVICE_SLUGS.FUEL_DELIVERY,
    SERVICE_SLUGS.TOWING,
  ];
  await prisma.serviceCategory.updateMany({
    where: { slug: { in: legacySlugs } },
    data: { isActive: false },
  });

  const rideClasses = [
    {
      name: 'Ryvo Go',
      slug: RIDE_CLASS_SLUGS.RYVO_GO,
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
      slug: RIDE_CLASS_SLUGS.COMFORT,
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
      slug: RIDE_CLASS_SLUGS.XL,
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
      slug: RIDE_CLASS_SLUGS.PREMIUM,
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
      slug: RIDE_CLASS_SLUGS.PET,
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
      slug: RIDE_CLASS_SLUGS.VAN,
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
      slug: RIDE_CLASS_SLUGS.ASSIST,
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
      slug: RIDE_CLASS_SLUGS.GREEN,
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
    const category = await prisma.serviceCategory.upsert({
      where: { slug: rideClass.slug },
      update: {},
      create: {
        name: rideClass.name,
        slug: rideClass.slug,
        icon: rideClass.icon,
        description: rideClass.description,
        sortOrder: rideClass.sortOrder,
        isActive: true,
      },
    });

    const ruleId = `${rideClass.slug}-default-pricing`;
    const existingRule = await prisma.servicePricingRule.findUnique({ where: { id: ruleId } });
    if (!existingRule) {
      await prisma.servicePricingRule.create({
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

  const parcelClasses = [
    {
      name: 'Parcel Bike',
      slug: PARCEL_CLASS_SLUGS.PARCEL_BIKE,
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
      slug: PARCEL_CLASS_SLUGS.PARCEL_CAR,
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
    const category = await prisma.serviceCategory.upsert({
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

    const parcelRuleId = `${parcelClass.slug}-default-pricing`;
    const existingParcelRule = await prisma.servicePricingRule.findUnique({ where: { id: parcelRuleId } });
    if (!existingParcelRule) {
      await prisma.servicePricingRule.create({
        data: {
          id: parcelRuleId,
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

  const subscriptionPlans = [
    { id: 'plan-daily', name: 'Daily', period: 'daily' as const, price: 4.99, sortOrder: 1 },
    { id: 'plan-weekly', name: 'Weekly', period: 'weekly' as const, price: 24.99, sortOrder: 2 },
    { id: 'plan-monthly', name: 'Monthly', period: 'monthly' as const, price: 79.99, sortOrder: 3 },
  ];
  for (const plan of subscriptionPlans) {
    await prisma.driverSubscriptionPlan.upsert({
      where: { id: plan.id },
      update: {
        name: plan.name,
        period: plan.period,
        price: plan.price,
        commissionRate: 0,
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

  // Super admin
  const adminPhone = '+01754713136';
  const adminPassword = '123456';
  const passwordHash = await bcrypt.hash(adminPassword, 12);
  const adminUser = await prisma.user.upsert({
    where: { phone: adminPhone },
    update: { passwordHash },
    create: {
      phone: adminPhone,
      email: 'admin@ryvo.com',
      passwordHash,
      fullName: 'Super Admin',
      role: 'admin',
      status: 'active',
      phoneVerifiedAt: new Date(),
      adminUser: {
        create: {
          adminRole: 'super_admin',
          permissions: ['*'],
        },
      },
      wallet: { create: { balance: 0 } },
    },
    include: { adminUser: true },
  });

  console.log(`Super admin: ${adminUser.phone} / ${adminPassword}`);

  // Sample customer (US)
  const customerPassword = await bcrypt.hash('Customer@123', 12);
  await prisma.user.upsert({
    where: { phone: '+12345678900' },
    update: {},
    create: {
      phone: '+12345678900',
      passwordHash: customerPassword,
      fullName: 'John Doe',
      role: 'customer',
      status: 'active',
      phoneVerifiedAt: new Date(),
      customer: {
        create: {
          defaultPaymentMethod: 'wallet',
          vehicles: {
            create: {
              make: 'Toyota',
              model: 'Camry',
              year: 2020,
              plateNumber: 'NYC-1234',
              transmission: 'auto',
              fuelType: 'petrol',
              isDefault: true,
            },
          },
        },
      },
      wallet: { create: { balance: 42.5 } },
    },
  });

  // Sample customer (UK, +44)
  await prisma.user.upsert({
    where: { phone: '+447700900001' },
    update: {},
    create: {
      phone: '+447700900001',
      passwordHash: customerPassword,
      fullName: 'James Wilson',
      role: 'customer',
      status: 'active',
      phoneVerifiedAt: new Date(),
      customer: {
        create: {
          defaultPaymentMethod: 'wallet',
          vehicles: {
            create: {
              make: 'Vauxhall',
              model: 'Corsa',
              year: 2019,
              plateNumber: 'AB12 CDE',
              transmission: 'manual',
              fuelType: 'petrol',
              isDefault: true,
            },
          },
        },
      },
      wallet: { create: { balance: 50 } },
    },
  });

  console.log('UK customer: +447700900001 / Customer@123');

  // Sample provider (US)
  const providerPassword = await bcrypt.hash('Provider@123', 12);
  await prisma.user.upsert({
    where: { phone: '+19876543210' },
    update: {},
    create: {
      phone: '+19876543210',
      passwordHash: providerPassword,
      fullName: 'John Davidson',
      role: 'provider',
      status: 'active',
      phoneVerifiedAt: new Date(),
      provider: {
        create: {
          businessName: 'JD Roadside Services',
          verificationStatus: 'approved',
          onlineStatus: 'online',
          currentLat: 40.7148,
          currentLng: -74.006,
          ratingAvg: 4.8,
          totalJobs: 156,
          vehicles: {
            create: {
              make: 'Ford',
              model: 'F-150',
              year: 2022,
              plateNumber: 'SRV-5678',
              transmission: 'auto',
              fuelType: 'petrol',
              serviceCapabilities: ['jump-start', 'flat-tire', 'fuel-delivery', 'towing'],
            },
          },
          serviceAreas: {
            create: {
              centerLat: 40.7128,
              centerLng: -74.006,
              radiusKm: 25,
            },
          },
        },
      },
      wallet: { create: { balance: 0 } },
    },
  });

  // Sample provider (UK, +44)
  await prisma.user.upsert({
    where: { phone: '+447700900002' },
    update: {},
    create: {
      phone: '+447700900002',
      passwordHash: providerPassword,
      fullName: 'Oliver Hughes',
      role: 'provider',
      status: 'active',
      phoneVerifiedAt: new Date(),
      provider: {
        create: {
          businessName: 'London Roadside Rescue',
          verificationStatus: 'approved',
          onlineStatus: 'online',
          currentLat: 51.5074,
          currentLng: -0.1278,
          ratingAvg: 4.9,
          totalJobs: 84,
          vehicles: {
            create: {
              make: 'Ford',
              model: 'Transit',
              year: 2021,
              plateNumber: 'LD12 ABC',
              transmission: 'manual',
              fuelType: 'diesel',
              serviceCapabilities: ['jump-start', 'flat-tire', 'fuel-delivery', 'towing'],
            },
          },
          serviceAreas: {
            create: {
              centerLat: 51.5074,
              centerLng: -0.1278,
              radiusKm: 30,
            },
          },
        },
      },
      wallet: { create: { balance: 0 } },
    },
  });

  console.log('UK driver: +447700900002 / Provider@123');

  // Notification templates
  const templates = [
    { slug: 'job_matched', channel: 'push' as const, titleTemplate: 'Driver Found!', bodyTemplate: 'Your driver {{providerName}} is on the way.' },
    { slug: 'job_completed', channel: 'push' as const, titleTemplate: 'Job Completed', bodyTemplate: 'Your {{serviceName}} service is complete.' },
    { slug: 'payment_received', channel: 'in_app' as const, titleTemplate: 'Payment Received', bodyTemplate: 'Payment of ${{amount}} received for job {{jobNumber}}.' },
  ];

  for (const t of templates) {
    await prisma.notificationTemplate.upsert({
      where: { slug: t.slug },
      update: {},
      create: t,
    });
  }

  // Sample FAQs
  await prisma.faq.createMany({
    skipDuplicates: true,
    data: [
      { question: 'How do I request roadside assistance?', answer: 'Open the app, select your service type, and tap Request.', category: 'general', sortOrder: 1 },
      { question: 'What payment methods are accepted?', answer: 'We accept Stripe cards, wallet balance, and cash.', category: 'payment', sortOrder: 2 },
    ],
  });

  // Countries
  for (let i = 0; i < COUNTRIES_DATA.length; i++) {
    const country = COUNTRIES_DATA[i];
    await prisma.country.upsert({
      where: { code: country.code },
      update: country.code === 'GB' ? { isActive: true } : {},
      create: {
        name: country.name,
        code: country.code,
        code3: country.code3,
        numeric: country.numeric,
        dialCode: country.dialCode,
        icon: flagEmoji(country.code),
        sortOrder: i,
        isActive: country.code === 'GB',
      },
    });
  }
  console.log(`Seeded ${COUNTRIES_DATA.length} countries (inactive by default).`);

  console.log('Seed completed.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
