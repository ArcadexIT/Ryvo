-- V2 coverage, training, agreements, invoices, Stripe Connect

ALTER TYPE "PayoutStatus" ADD VALUE IF NOT EXISTS 'rejected';

CREATE TYPE "ZoneAudience" AS ENUM ('customer', 'provider', 'both');
CREATE TYPE "QualificationStatus" AS ENUM ('not_started', 'training', 'equipment_review', 'approved');
CREATE TYPE "TrainingBlockType" AS ENUM ('text', 'image', 'video');
CREATE TYPE "AgreementKey" AS ENUM ('service', 'tax_status', 'insurance');
CREATE TYPE "InsuranceProofStatus" AS ENUM ('not_requested', 'requested', 'submitted', 'approved', 'rejected');

ALTER TABLE "providers"
  ADD COLUMN IF NOT EXISTS "stripe_account_id" TEXT,
  ADD COLUMN IF NOT EXISTS "insurance_proof_status" "InsuranceProofStatus" NOT NULL DEFAULT 'not_requested',
  ADD COLUMN IF NOT EXISTS "insurance_proof_requested_at" TIMESTAMP(3);
CREATE UNIQUE INDEX IF NOT EXISTS "providers_stripe_account_id_key" ON "providers"("stripe_account_id");

ALTER TABLE "provider_documents"
  ADD COLUMN IF NOT EXISTS "service_category_id" TEXT,
  ADD COLUMN IF NOT EXISTS "equipment_requirement_id" TEXT,
  ADD COLUMN IF NOT EXISTS "equipment_label" TEXT;

ALTER TABLE "jobs"
  ADD COLUMN IF NOT EXISTS "excluded_provider_ids" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];

ALTER TABLE "payouts"
  ADD COLUMN IF NOT EXISTS "stripe_transfer_id" TEXT;

CREATE TABLE IF NOT EXISTS "service_zones" (
  "id" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "audience" "ZoneAudience" NOT NULL DEFAULT 'both',
  "center_lat" DECIMAL(10,7) NOT NULL,
  "center_lng" DECIMAL(10,7) NOT NULL,
  "radius_km" DECIMAL(6,2) NOT NULL,
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "service_zones_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "coverage_interests" (
  "id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "audience" "ZoneAudience" NOT NULL,
  "lat" DECIMAL(10,7) NOT NULL,
  "lng" DECIMAL(10,7) NOT NULL,
  "address_label" TEXT,
  "notified_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "coverage_interests_pkey" PRIMARY KEY ("id")
);
CREATE INDEX IF NOT EXISTS "coverage_interests_user_id_idx" ON "coverage_interests"("user_id");
ALTER TABLE "coverage_interests" DROP CONSTRAINT IF EXISTS "coverage_interests_user_id_fkey";
ALTER TABLE "coverage_interests" ADD CONSTRAINT "coverage_interests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE IF NOT EXISTS "training_programs" (
  "id" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "service_category_id" TEXT,
  "pass_percent" INTEGER NOT NULL DEFAULT 80,
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "training_programs_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "training_programs_service_category_id_key" ON "training_programs"("service_category_id");

CREATE TABLE IF NOT EXISTS "training_blocks" (
  "id" TEXT NOT NULL,
  "program_id" TEXT NOT NULL,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "type" "TrainingBlockType" NOT NULL,
  "body" TEXT NOT NULL,
  "caption" TEXT,
  CONSTRAINT "training_blocks_pkey" PRIMARY KEY ("id")
);
CREATE INDEX IF NOT EXISTS "training_blocks_program_id_sort_order_idx" ON "training_blocks"("program_id", "sort_order");

CREATE TABLE IF NOT EXISTS "training_questions" (
  "id" TEXT NOT NULL,
  "program_id" TEXT NOT NULL,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "prompt" TEXT NOT NULL,
  CONSTRAINT "training_questions_pkey" PRIMARY KEY ("id")
);
CREATE INDEX IF NOT EXISTS "training_questions_program_id_sort_order_idx" ON "training_questions"("program_id", "sort_order");

CREATE TABLE IF NOT EXISTS "training_options" (
  "id" TEXT NOT NULL,
  "question_id" TEXT NOT NULL,
  "label" TEXT NOT NULL,
  "is_correct" BOOLEAN NOT NULL DEFAULT false,
  CONSTRAINT "training_options_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "provider_training_attempts" (
  "id" TEXT NOT NULL,
  "provider_id" TEXT NOT NULL,
  "program_id" TEXT NOT NULL,
  "score" INTEGER NOT NULL,
  "passed" BOOLEAN NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "provider_training_attempts_pkey" PRIMARY KEY ("id")
);
CREATE INDEX IF NOT EXISTS "provider_training_attempts_provider_id_program_id_idx" ON "provider_training_attempts"("provider_id", "program_id");

CREATE TABLE IF NOT EXISTS "provider_qualifications" (
  "id" TEXT NOT NULL,
  "provider_id" TEXT NOT NULL,
  "service_category_id" TEXT NOT NULL,
  "status" "QualificationStatus" NOT NULL DEFAULT 'not_started',
  "updated_at" TIMESTAMP(3) NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "provider_qualifications_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "provider_qualifications_provider_id_service_category_id_key" ON "provider_qualifications"("provider_id", "service_category_id");

CREATE TABLE IF NOT EXISTS "equipment_requirements" (
  "id" TEXT NOT NULL,
  "service_category_id" TEXT NOT NULL,
  "label" TEXT NOT NULL,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  CONSTRAINT "equipment_requirements_pkey" PRIMARY KEY ("id")
);
CREATE INDEX IF NOT EXISTS "equipment_requirements_service_category_id_idx" ON "equipment_requirements"("service_category_id");

CREATE TABLE IF NOT EXISTS "agreement_documents" (
  "id" TEXT NOT NULL,
  "key" "AgreementKey" NOT NULL,
  "version" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "body" TEXT NOT NULL,
  "is_required_for_online" BOOLEAN NOT NULL DEFAULT true,
  "is_current" BOOLEAN NOT NULL DEFAULT true,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "agreement_documents_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "agreement_documents_key_version_key" ON "agreement_documents"("key", "version");

CREATE TABLE IF NOT EXISTS "provider_agreement_acceptances" (
  "id" TEXT NOT NULL,
  "provider_id" TEXT NOT NULL,
  "agreement_key" "AgreementKey" NOT NULL,
  "version" TEXT NOT NULL,
  "accepted_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "app_version" TEXT,
  CONSTRAINT "provider_agreement_acceptances_pkey" PRIMARY KEY ("id")
);
CREATE INDEX IF NOT EXISTS "provider_agreement_acceptances_provider_id_agreement_key_idx" ON "provider_agreement_acceptances"("provider_id", "agreement_key");

CREATE TABLE IF NOT EXISTS "invoices" (
  "id" TEXT NOT NULL,
  "invoice_number" TEXT NOT NULL,
  "job_id" TEXT NOT NULL,
  "payment_id" TEXT,
  "customer_id" TEXT NOT NULL,
  "email" TEXT,
  "total" DECIMAL(12,2) NOT NULL,
  "issued_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "sent_at" TIMESTAMP(3),
  CONSTRAINT "invoices_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "invoices_invoice_number_key" ON "invoices"("invoice_number");
CREATE UNIQUE INDEX IF NOT EXISTS "invoices_job_id_key" ON "invoices"("job_id");
CREATE UNIQUE INDEX IF NOT EXISTS "invoices_payment_id_key" ON "invoices"("payment_id");
CREATE INDEX IF NOT EXISTS "invoices_customer_id_idx" ON "invoices"("customer_id");
