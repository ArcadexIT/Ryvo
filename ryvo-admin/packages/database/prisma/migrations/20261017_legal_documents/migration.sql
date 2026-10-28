-- Legal pages the admin can edit, plus the timestamp recorded when a customer accepts them.

CREATE TABLE "legal_documents" (
    "key" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "legal_documents_pkey" PRIMARY KEY ("key")
);

ALTER TABLE "customers" ADD COLUMN "terms_accepted_at" TIMESTAMP(3);
