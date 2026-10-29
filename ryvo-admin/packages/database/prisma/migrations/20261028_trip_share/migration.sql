-- Private family share links for an active trip. The token is the secret in the public URL.

CREATE TABLE "trip_shares" (
  "id" TEXT NOT NULL,
  "job_id" TEXT NOT NULL,
  "token" TEXT NOT NULL,
  "revoked_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "trip_shares_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "trip_shares_job_id_key" ON "trip_shares"("job_id");
CREATE UNIQUE INDEX "trip_shares_token_key" ON "trip_shares"("token");

ALTER TABLE "trip_shares"
  ADD CONSTRAINT "trip_shares_job_id_fkey"
  FOREIGN KEY ("job_id") REFERENCES "jobs"("id") ON DELETE CASCADE ON UPDATE CASCADE;
