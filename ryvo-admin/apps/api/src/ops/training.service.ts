import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { QualificationStatus } from '@ryvo/database';

@Injectable()
export class TrainingService {
  constructor(private prisma: PrismaService) {}

  async listForProvider(providerId: string) {
    const programs = await this.prisma.trainingProgram.findMany({
      where: { isActive: true },
      include: { serviceCategory: { select: { id: true, name: true, slug: true } } },
      orderBy: { title: 'asc' },
    });
    const attempts = await this.prisma.providerTrainingAttempt.findMany({
      where: { providerId },
      orderBy: { createdAt: 'desc' },
    });
    const quals = await this.prisma.providerQualification.findMany({ where: { providerId } });
    return programs.map((program) => {
      const latest = attempts.find((a) => a.programId === program.id);
      const qual = program.serviceCategoryId
        ? quals.find((q) => q.serviceCategoryId === program.serviceCategoryId)
        : null;
      return {
        id: program.id,
        title: program.title,
        passPercent: program.passPercent,
        serviceCategory: program.serviceCategory,
        passed: !!latest?.passed,
        lastScore: latest?.score ?? null,
        qualificationStatus: qual?.status ?? (program.serviceCategoryId ? 'not_started' : null),
      };
    });
  }

  async getProgram(programId: string) {
    const program = await this.prisma.trainingProgram.findUnique({
      where: { id: programId },
      include: {
        blocks: { orderBy: { sortOrder: 'asc' } },
        questions: { orderBy: { sortOrder: 'asc' }, include: { options: true } },
      },
    });
    if (!program) throw new NotFoundException('Training not found');
    return {
      ...program,
      questions: program.questions.map((q) => ({
        id: q.id,
        prompt: q.prompt,
        options: q.options.map((o) => ({ id: o.id, label: o.label })),
      })),
    };
  }

  async submit(providerId: string, programId: string, answers: { questionId: string; optionId: string }[]) {
    const program = await this.prisma.trainingProgram.findUnique({
      where: { id: programId },
      include: { questions: { include: { options: true } } },
    });
    if (!program || !program.isActive) throw new NotFoundException('Training not found');
    if (!program.questions.length) throw new BadRequestException('This training has no test yet');

    let correct = 0;
    for (const question of program.questions) {
      const answer = answers.find((a) => a.questionId === question.id);
      const option = question.options.find((o) => o.id === answer?.optionId);
      if (option?.isCorrect) correct += 1;
    }
    const score = Math.round((correct / program.questions.length) * 100);
    const passed = score >= program.passPercent;
    const attempt = await this.prisma.providerTrainingAttempt.create({
      data: { providerId, programId, score, passed },
    });

    if (program.serviceCategoryId) {
      // A passed test unlocks the job type. Equipment photos are reviewed
      // separately and do not keep a passed provider out of dispatch.
      const status: QualificationStatus = passed ? 'approved' : 'training';
      await this.prisma.providerQualification.upsert({
        where: {
          providerId_serviceCategoryId: {
            providerId,
            serviceCategoryId: program.serviceCategoryId,
          },
        },
        create: { providerId, serviceCategoryId: program.serviceCategoryId, status },
        update: { status },
      });
    }

    return { score, passed, passPercent: program.passPercent, attemptId: attempt.id };
  }

  async hasPassedOnboarding(providerId: string) {
    const program = await this.prisma.trainingProgram.findFirst({
      where: { isActive: true, serviceCategoryId: null },
    });
    if (!program) return true;
    const passed = await this.prisma.providerTrainingAttempt.findFirst({
      where: { providerId, programId: program.id, passed: true },
    });
    return !!passed;
  }

  async providerIdsQualifiedFor(serviceCategoryId: string, providerIds: string[]) {
    const program = await this.prisma.trainingProgram.findFirst({
      where: { serviceCategoryId, isActive: true },
    });
    if (!program || !providerIds.length) return providerIds;
    const [quals, passedAttempts] = await Promise.all([
      this.prisma.providerQualification.findMany({
        where: {
          serviceCategoryId,
          providerId: { in: providerIds },
          // equipment_review means the test was already passed; older rows were
          // left in that state and never received offers.
          status: { in: ['approved', 'equipment_review'] },
        },
        select: { providerId: true },
      }),
      this.prisma.providerTrainingAttempt.findMany({
        where: { programId: program.id, providerId: { in: providerIds }, passed: true },
        select: { providerId: true },
      }),
    ]);
    const allowed = new Set([
      ...quals.map((q) => q.providerId),
      ...passedAttempts.map((a) => a.providerId),
    ]);
    return providerIds.filter((id) => allowed.has(id));
  }

  async refreshEquipmentQualification(providerId: string, serviceCategoryId: string) {
    const [requirements, docs, program] = await Promise.all([
      this.prisma.equipmentRequirement.findMany({
        where: { serviceCategoryId, isActive: true },
      }),
      this.prisma.providerDocument.findMany({
        where: { providerId, serviceCategoryId, docType: 'equipment_proof', status: 'approved' },
      }),
      this.prisma.trainingProgram.findFirst({ where: { serviceCategoryId, isActive: true } }),
    ]);
    if (!requirements.length) return;
    const approvedIds = new Set(docs.map((d) => d.equipmentRequirementId).filter(Boolean));
    const complete = requirements.every((r) => approvedIds.has(r.id));
    if (!complete) return;
    let passed = true;
    if (program) {
      const attempt = await this.prisma.providerTrainingAttempt.findFirst({
        where: { providerId, programId: program.id, passed: true },
      });
      passed = !!attempt;
    }
    if (!passed) return;
    await this.upsertApproved(providerId, serviceCategoryId);
  }

  async saveProgram(input: {
    id?: string;
    title: string;
    passPercent: number;
    serviceCategoryId?: string | null;
    isActive?: boolean;
    blocks: { type: 'text' | 'image' | 'video'; body: string; caption?: string }[];
    questions: { prompt: string; options: { label: string; isCorrect: boolean }[] }[];
  }) {
    return this.prisma.$transaction(async (tx) => {
      const data = {
        title: input.title,
        passPercent: input.passPercent,
        isActive: input.isActive ?? true,
        serviceCategoryId: input.serviceCategoryId || null,
      };
      const program = input.id
        ? await tx.trainingProgram.update({ where: { id: input.id }, data })
        : await tx.trainingProgram.create({ data });
      await tx.trainingBlock.deleteMany({ where: { programId: program.id } });
      await tx.trainingQuestion.deleteMany({ where: { programId: program.id } });
      for (const [index, block] of input.blocks.entries()) {
        await tx.trainingBlock.create({
          data: {
            programId: program.id,
            sortOrder: index,
            type: block.type,
            body: block.body || ' ',
            caption: block.caption,
          },
        });
      }
      for (const [index, question] of input.questions.entries()) {
        await tx.trainingQuestion.create({
          data: {
            programId: program.id,
            sortOrder: index,
            prompt: question.prompt,
            options: {
              create: question.options.map((option) => ({
                label: option.label,
                isCorrect: option.isCorrect,
              })),
            },
          },
        });
      }
      return program;
    });
  }

  async saveEquipment(input: {
    id?: string;
    serviceCategoryId: string;
    label: string;
    sortOrder?: number;
    isActive?: boolean;
  }) {
    const data = {
      serviceCategoryId: input.serviceCategoryId,
      label: input.label,
      sortOrder: input.sortOrder ?? 0,
      isActive: input.isActive ?? true,
    };
    return input.id
      ? this.prisma.equipmentRequirement.update({ where: { id: input.id }, data })
      : this.prisma.equipmentRequirement.create({ data });
  }

  private async upsertApproved(providerId: string, serviceCategoryId: string) {
    await this.prisma.providerQualification.upsert({
      where: { providerId_serviceCategoryId: { providerId, serviceCategoryId } },
      create: { providerId, serviceCategoryId, status: 'approved' },
      update: { status: 'approved' },
    });
  }
}
