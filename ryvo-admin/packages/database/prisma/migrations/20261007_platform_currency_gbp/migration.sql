-- Platform currency is GBP for the UK launch. Existing USD wallet labels
-- are relabeled; amounts are not converted.

ALTER TABLE "wallets" ALTER COLUMN "currency" SET DEFAULT 'GBP';

UPDATE "wallets" SET "currency" = 'GBP' WHERE "currency" = 'USD';

INSERT INTO "platform_settings" ("key", "value", "updated_at")
VALUES ('currency', '"GBP"', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
