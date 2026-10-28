-- Persist Stripe Customer id only (no raw card data).
ALTER TABLE "customers" ADD COLUMN IF NOT EXISTS "stripe_customer_id" TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS "customers_stripe_customer_id_key"
  ON "customers"("stripe_customer_id");

-- MVP-02: wallet is off unless an admin explicitly re-enables it.
INSERT INTO "platform_settings" ("key", "value", "updated_at")
VALUES
  ('customer_wallet_enabled', 'false'::jsonb, NOW()),
  ('payment_wallet_enabled', 'false'::jsonb, NOW())
ON CONFLICT ("key") DO UPDATE SET
  "value" = EXCLUDED."value",
  "updated_at" = NOW();
