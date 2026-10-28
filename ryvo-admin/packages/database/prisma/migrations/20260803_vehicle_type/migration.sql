-- AlterTable
ALTER TABLE "vehicles" ADD COLUMN "vehicle_type" TEXT NOT NULL DEFAULT 'car';

-- AlterTable
ALTER TABLE "provider_vehicles" ADD COLUMN "vehicle_type" TEXT NOT NULL DEFAULT 'car';
