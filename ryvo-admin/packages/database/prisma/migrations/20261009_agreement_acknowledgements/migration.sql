-- Statements the provider must tick before an agreement can be accepted.

ALTER TABLE "agreement_documents"
ADD COLUMN "acknowledgements" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];

UPDATE "agreement_documents"
SET "acknowledgements" = ARRAY['I have read and accept this agreement.']::TEXT[]
WHERE "key" = 'service' AND cardinality("acknowledgements") = 0;

UPDATE "agreement_documents"
SET "acknowledgements" = ARRAY[
  'I understand that I am registering with RYVO as an independent provider and not as an employee of RYVO Ltd.',
  'I understand that I am responsible for determining and meeting my own tax, National Insurance and HMRC reporting obligations where applicable.'
]::TEXT[]
WHERE "key" = 'tax_status' AND cardinality("acknowledgements") = 0;

UPDATE "agreement_documents"
SET "acknowledgements" = ARRAY[
  'I confirm that I currently hold valid motor insurance that is appropriate for my use of the vehicle while providing services through RYVO.',
  'I understand that I am responsible for making sure my insurance remains valid and suitable, and I will notify RYVO if my cover expires, is cancelled or becomes unsuitable for the services I provide.'
]::TEXT[]
WHERE "key" = 'insurance' AND cardinality("acknowledgements") = 0;
