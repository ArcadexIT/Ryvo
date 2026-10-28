import { config } from 'dotenv';
import { resolve } from 'path';
import { PrismaClient } from '@prisma/client';
import { COUNTRIES_DATA, flagEmoji } from './data/countries-data';

config({ path: resolve(__dirname, '../.env') });

const prisma = new PrismaClient();

async function main() {
  console.log(`Seeding ${COUNTRIES_DATA.length} countries...`);

  for (let i = 0; i < COUNTRIES_DATA.length; i++) {
    const country = COUNTRIES_DATA[i];
    await prisma.country.upsert({
      where: { code: country.code },
      update: {
        name: country.name,
        code3: country.code3,
        numeric: country.numeric,
        dialCode: country.dialCode,
        icon: flagEmoji(country.code),
        sortOrder: i,
        ...(country.code === 'GB' && { isActive: true }),
      },
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

  console.log('Countries seeded.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
