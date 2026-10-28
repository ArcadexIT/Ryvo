-- Rider trips no longer require the customer's own car.
ALTER TABLE "jobs" ALTER COLUMN "vehicle_id" DROP NOT NULL;

-- Saved card used to charge the fare when the trip ends.
ALTER TABLE "payments" ADD COLUMN "stripe_payment_method_id" TEXT;
