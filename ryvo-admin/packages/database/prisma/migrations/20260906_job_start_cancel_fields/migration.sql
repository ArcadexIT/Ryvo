-- AlterTable
ALTER TABLE "jobs" ADD COLUMN "arrived_at" TIMESTAMP(3),
ADD COLUMN "provider_start_confirmed_at" TIMESTAMP(3),
ADD COLUMN "customer_start_confirmed_at" TIMESTAMP(3),
ADD COLUMN "cancellation_fee_amount" DECIMAL(10, 2),
ADD COLUMN "provider_penalty_amount" DECIMAL(10, 2);
