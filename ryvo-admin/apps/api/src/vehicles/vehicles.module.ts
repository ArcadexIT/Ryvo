import { Module } from '@nestjs/common';
import { VehiclesService } from './vehicles.service';
import { CustomerVehiclesController } from './customer-vehicles.controller';
import { FilesModule } from '../files/files.module';

@Module({
  imports: [FilesModule],
  providers: [VehiclesService],
  controllers: [CustomerVehiclesController],
  exports: [VehiclesService],
})
export class VehiclesModule {}
