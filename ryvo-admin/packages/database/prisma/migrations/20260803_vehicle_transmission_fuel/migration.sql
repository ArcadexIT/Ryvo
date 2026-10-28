-- AlterTable
ALTER TABLE "vehicles" ADD COLUMN "transmission" TEXT;
ALTER TABLE "vehicles" ADD COLUMN "fuel_type" TEXT;

-- AlterTable
ALTER TABLE "provider_vehicles" ADD COLUMN "transmission" TEXT;
ALTER TABLE "provider_vehicles" ADD COLUMN "fuel_type" TEXT;
