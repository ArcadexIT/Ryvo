import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AgreementKey } from '@ryvo/database';

const TAX_BODY = `As a RYVO driver, you will provide services as an independent driver rather than as an employee of RYVO Ltd.

You are responsible for managing your own tax affairs, including any Income Tax, National Insurance and HMRC reporting obligations that apply to you.

RYVO does not normally deduct PAYE tax or employee National Insurance from your driver earnings.

You should keep appropriate records of your earnings and expenses and obtain independent tax advice if you are unsure of your obligations.

Your legal employment status depends on the actual working relationship and applicable law. This acknowledgement does not remove or override any statutory rights you may have.`;

const INSURANCE_BODY = `To provide services through RYVO, you must make sure you have insurance that is valid and appropriate for how you use your vehicle and the services you provide.

It is your responsibility to check that your policy allows you to use your vehicle while providing services through RYVO and to keep your cover valid while you are active on the platform.

RYVO may request evidence of insurance at any time. Failure to provide satisfactory evidence when requested may result in suspension of access to the platform.`;

const SERVICE_BODY = `Ryvo Driver Agreement

By accepting this agreement, you confirm that you are licensed to carry passengers, that your vehicle, insurance and documents are accurate, and that you will follow RYVO ride platform policies.

This text is a product placeholder and should be reviewed by a lawyer before it is treated as a binding agreement.`;

const DEFAULT_ACKNOWLEDGEMENTS: Record<AgreementKey, string[]> = {
  service: ['I have read and accept this agreement.'],
  tax_status: [
    'I understand that I am registering with RYVO as an independent driver and not as an employee of RYVO Ltd.',
    'I understand that I am responsible for determining and meeting my own tax, National Insurance and HMRC reporting obligations where applicable.',
  ],
  insurance: [
    'I confirm that I currently hold valid motor insurance that is appropriate for my use of the vehicle while providing services through RYVO.',
    'I understand that I am responsible for making sure my insurance remains valid and suitable, and I will notify RYVO if my cover expires, is cancelled or becomes unsuitable for the services I provide.',
  ],
};

function cleanAcknowledgements(values: string[] | null | undefined) {
  return (values ?? []).map((value) => value.trim()).filter(Boolean);
}

@Injectable()
export class AgreementsService {
  constructor(private prisma: PrismaService) {}

  async ensureDefaults() {
    const count = await this.prisma.agreementDocument.count();
    if (count > 0) return;
    await this.prisma.agreementDocument.createMany({
      data: [
        { key: 'service', version: '1', title: 'Driver Agreement', body: SERVICE_BODY, acknowledgements: DEFAULT_ACKNOWLEDGEMENTS.service, isCurrent: true },
        { key: 'tax_status', version: '1', title: 'Driver Status & Tax Responsibilities', body: TAX_BODY, acknowledgements: DEFAULT_ACKNOWLEDGEMENTS.tax_status, isCurrent: true },
        { key: 'insurance', version: '1', title: 'Insurance & Cover', body: INSURANCE_BODY, acknowledgements: DEFAULT_ACKNOWLEDGEMENTS.insurance, isCurrent: true },
      ],
    });
  }

  async currentDocuments() {
    const docs = await this.prisma.agreementDocument.findMany({
      where: { isCurrent: true },
      orderBy: { key: 'asc' },
    });
    return docs.map((doc) => {
      const statements = cleanAcknowledgements(doc.acknowledgements);
      return {
        ...doc,
        acknowledgements: statements.length ? statements : DEFAULT_ACKNOWLEDGEMENTS[doc.key],
      };
    });
  }

  async publish(input: { key: AgreementKey; title: string; body: string; version: string; acknowledgements?: string[] }) {
    const title = input.title.trim();
    const body = input.body.trim();
    const version = input.version.trim();
    const acknowledgements = cleanAcknowledgements(input.acknowledgements);
    if (!title || !body || !version) {
      throw new BadRequestException('Title, body, and version are required.');
    }
    if (!acknowledgements.length) {
      throw new BadRequestException('Add at least one statement for the driver to tick.');
    }
    const existing = await this.prisma.agreementDocument.findFirst({
      where: { key: input.key, version },
    });
    if (existing) {
      throw new BadRequestException(
        `Version ${version} of this agreement already exists. Choose a new version number.`,
      );
    }
    await this.prisma.agreementDocument.updateMany({
      where: { key: input.key, isCurrent: true },
      data: { isCurrent: false },
    });
    return this.prisma.agreementDocument.create({
      data: {
        key: input.key,
        version,
        title,
        body,
        acknowledgements,
        isCurrent: true,
        isRequiredForOnline: true,
      },
    });
  }

  async statusForProvider(providerId: string) {
    const [docs, acceptances, provider] = await Promise.all([
      this.currentDocuments(),
      this.prisma.providerAgreementAcceptance.findMany({
        where: { providerId },
        orderBy: { acceptedAt: 'desc' },
      }),
      this.prisma.provider.findUnique({
        where: { id: providerId },
        select: { insuranceProofStatus: true, insuranceProofRequestedAt: true },
      }),
    ]);
    return docs.map((doc) => {
      const acceptance = acceptances.find((a) => a.agreementKey === doc.key && a.version === doc.version);
      return {
        key: doc.key,
        version: doc.version,
        title: doc.title,
        body: doc.body,
        acknowledgements: doc.acknowledgements,
        accepted: !!acceptance,
        acceptedAt: acceptance?.acceptedAt ?? null,
        reacceptanceRequired: !acceptance,
        insuranceProofStatus: doc.key === 'insurance' ? provider?.insuranceProofStatus ?? 'not_requested' : null,
        insuranceProofRequestedAt: doc.key === 'insurance' ? provider?.insuranceProofRequestedAt ?? null : null,
      };
    });
  }

  async accept(providerId: string, key: AgreementKey, version: string, appVersion?: string) {
    const current = await this.prisma.agreementDocument.findFirst({
      where: { key, isCurrent: true },
    });
    if (!current || current.version !== version) {
      throw new BadRequestException('Agreement version is out of date. Reload and accept the current version.');
    }
    const row = await this.prisma.providerAgreementAcceptance.create({
      data: { providerId, agreementKey: key, version, appVersion },
    });
    if (key === 'service') {
      await this.prisma.provider.update({
        where: { id: providerId },
        data: { agreementAcceptedAt: row.acceptedAt, agreementVersionAccepted: version },
      });
    }
    return row;
  }

  async assertCurrent(providerId: string) {
    const status = await this.statusForProvider(providerId);
    const pending = status.filter((s) => s.reacceptanceRequired);
    if (pending.length) {
      throw new ForbiddenException(
        'AGREEMENT_REQUIRED: Accept the updated agreements before going online.',
      );
    }
  }

  async adminView(providerId: string) {
    return this.statusForProvider(providerId);
  }
}
