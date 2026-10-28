-- Taxi / bidding / parcel, driver subscriptions, WhatsApp sessions

CREATE TYPE "JobType" AS ENUM ('taxi', 'bidding', 'parcel');
CREATE TYPE "ParcelSize" AS ENUM ('small', 'medium', 'large');
CREATE TYPE "JobBidKind" AS ENUM ('accept', 'counter');
CREATE TYPE "JobBidStatus" AS ENUM ('pending', 'accepted', 'rejected', 'expired', 'withdrawn');
CREATE TYPE "ServiceBusinessType" AS ENUM ('taxi', 'parcel');
CREATE TYPE "SubscriptionPeriod" AS ENUM ('daily', 'weekly', 'monthly');
CREATE TYPE "DriverSubscriptionStatus" AS ENUM ('pending', 'active', 'expired', 'cancelled');

ALTER TABLE "service_categories"
  ADD COLUMN "business_type" "ServiceBusinessType" NOT NULL DEFAULT 'taxi';

ALTER TABLE "jobs"
  ADD COLUMN "job_type" "JobType" NOT NULL DEFAULT 'taxi',
  ADD COLUMN "offered_price" DECIMAL(10, 2),
  ADD COLUMN "agreed_fare" DECIMAL(10, 2),
  ADD COLUMN "recipient_name" TEXT,
  ADD COLUMN "recipient_phone" TEXT,
  ADD COLUMN "parcel_size" "ParcelSize",
  ADD COLUMN "parcel_notes" TEXT,
  ADD COLUMN "pickup_photo_url" TEXT,
  ADD COLUMN "dropoff_photo_url" TEXT,
  ADD COLUMN "recipient_otp" TEXT,
  ADD COLUMN "channel" TEXT NOT NULL DEFAULT 'app';

CREATE INDEX "jobs_job_type_status_idx" ON "jobs"("job_type", "status");

CREATE TABLE "job_bids" (
  "id" TEXT NOT NULL,
  "job_id" TEXT NOT NULL,
  "provider_id" TEXT NOT NULL,
  "amount" DECIMAL(10, 2) NOT NULL,
  "kind" "JobBidKind" NOT NULL,
  "status" "JobBidStatus" NOT NULL DEFAULT 'pending',
  "message" TEXT,
  "expires_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "job_bids_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "job_bids_job_id_provider_id_key" ON "job_bids"("job_id", "provider_id");
CREATE INDEX "job_bids_job_id_status_idx" ON "job_bids"("job_id", "status");
CREATE INDEX "job_bids_provider_id_idx" ON "job_bids"("provider_id");

ALTER TABLE "job_bids"
  ADD CONSTRAINT "job_bids_job_id_fkey"
  FOREIGN KEY ("job_id") REFERENCES "jobs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "job_bids"
  ADD CONSTRAINT "job_bids_provider_id_fkey"
  FOREIGN KEY ("provider_id") REFERENCES "providers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "driver_subscription_plans" (
  "id" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "period" "SubscriptionPeriod" NOT NULL,
  "price" DECIMAL(10, 2) NOT NULL,
  "commission_rate" DECIMAL(5, 4) NOT NULL DEFAULT 0,
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "driver_subscription_plans_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "driver_subscriptions" (
  "id" TEXT NOT NULL,
  "provider_id" TEXT NOT NULL,
  "plan_id" TEXT NOT NULL,
  "status" "DriverSubscriptionStatus" NOT NULL DEFAULT 'pending',
  "starts_at" TIMESTAMP(3),
  "expires_at" TIMESTAMP(3),
  "stripe_payment_intent_id" TEXT,
  "stripe_checkout_session_id" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "driver_subscriptions_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "driver_subscriptions_provider_id_status_idx" ON "driver_subscriptions"("provider_id", "status");
CREATE INDEX "driver_subscriptions_expires_at_idx" ON "driver_subscriptions"("expires_at");

ALTER TABLE "driver_subscriptions"
  ADD CONSTRAINT "driver_subscriptions_provider_id_fkey"
  FOREIGN KEY ("provider_id") REFERENCES "providers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "driver_subscriptions"
  ADD CONSTRAINT "driver_subscriptions_plan_id_fkey"
  FOREIGN KEY ("plan_id") REFERENCES "driver_subscription_plans"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "whatsapp_sessions" (
  "id" TEXT NOT NULL,
  "phone" TEXT NOT NULL,
  "customer_id" TEXT,
  "state" TEXT NOT NULL DEFAULT 'idle',
  "draft" JSONB NOT NULL DEFAULT '{}',
  "last_job_id" TEXT,
  "last_message_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "whatsapp_sessions_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "whatsapp_sessions_phone_key" ON "whatsapp_sessions"("phone");
