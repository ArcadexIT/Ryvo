import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { FilesService } from '../files/files.service';

function assertNamedVehicleField(value: string | undefined, field: 'make' | 'model') {
  if (value == null) return undefined;
  const trimmed = value.trim();
  if (!trimmed) {
    throw new BadRequestException(`${field} is required`);
  }
  if (trimmed.toLowerCase() === 'other') {
    throw new BadRequestException(`Enter a ${field} name instead of Other`);
  }
  return trimmed;
}

function normalizePlate(value: string | undefined) {
  if (value == null) return undefined;
  const plate = value.trim().toUpperCase();
  if (!plate) throw new BadRequestException('plateNumber is required');
  return plate;
}

@Injectable()
export class VehiclesService {
  constructor(
    private prisma: PrismaService,
    private files: FilesService,
  ) {}

  private async withReadablePhoto<T extends { photoUrl: string | null }>(vehicle: T): Promise<T> {
    if (!vehicle.photoUrl) return vehicle;
    try {
      const photoUrl = await this.files.resolveAccessUrl(vehicle.photoUrl);
      return { ...vehicle, photoUrl };
    } catch {
      return vehicle;
    }
  }

  async findAll(customerId: string) {
    const vehicles = await this.prisma.vehicle.findMany({
      where: { customerId },
      orderBy: [{ isDefault: 'desc' }, { createdAt: 'desc' }],
    });
    return Promise.all(vehicles.map((vehicle) => this.withReadablePhoto(vehicle)));
  }

  async findOne(customerId: string, id: string) {
    const vehicle = await this.prisma.vehicle.findFirst({
      where: { id, customerId },
    });
    if (!vehicle) throw new NotFoundException('Vehicle not found');
    return this.withReadablePhoto(vehicle);
  }

  async create(
    customerId: string,
    data: {
      vehicleType: string;
      make: string;
      model: string;
      year: number;
      plateNumber: string;
      transmission: string;
      fuelType: string;
      color?: string;
      engineCapacity?: string;
      photoUrl?: string;
      isDefault?: boolean;
    },
  ) {
    const make = assertNamedVehicleField(data.make, 'make')!;
    const model = assertNamedVehicleField(data.model, 'model')!;
    const plateNumber = normalizePlate(data.plateNumber)!;

    if (data.isDefault) {
      await this.prisma.vehicle.updateMany({
        where: { customerId },
        data: { isDefault: false },
      });
    }

    const vehicle = await this.prisma.vehicle.create({
      data: { customerId, ...data, make, model, plateNumber },
    });
    return this.withReadablePhoto(vehicle);
  }

  async update(
    customerId: string,
    id: string,
    data: {
      vehicleType?: string;
      make?: string;
      model?: string;
      year?: number;
      plateNumber?: string;
      transmission?: string;
      fuelType?: string;
      color?: string;
      engineCapacity?: string;
      photoUrl?: string;
      isDefault?: boolean;
    },
  ) {
    await this.findOne(customerId, id);

    const make = assertNamedVehicleField(data.make, 'make');
    const model = assertNamedVehicleField(data.model, 'model');
    const plateNumber = data.plateNumber != null ? normalizePlate(data.plateNumber) : undefined;

    if (data.isDefault) {
      await this.prisma.vehicle.updateMany({
        where: { customerId, id: { not: id } },
        data: { isDefault: false },
      });
    }

    const vehicle = await this.prisma.vehicle.update({
      where: { id },
      data: {
        ...data,
        ...(make != null ? { make } : {}),
        ...(model != null ? { model } : {}),
        ...(plateNumber != null ? { plateNumber } : {}),
      },
    });
    return this.withReadablePhoto(vehicle);
  }

  async remove(customerId: string, id: string) {
    await this.findOne(customerId, id);

    const jobCount = await this.prisma.job.count({ where: { vehicleId: id } });
    if (jobCount > 0) {
      throw new BadRequestException('Cannot delete vehicle with associated jobs');
    }

    return this.prisma.vehicle.delete({ where: { id } });
  }
}
