import { Module } from '@nestjs/common';
import { CountriesService } from './countries.service';
import { AdminCountriesController, PublicCountriesController } from './countries.controller';

@Module({
  providers: [CountriesService],
  controllers: [AdminCountriesController, PublicCountriesController],
  exports: [CountriesService],
})
export class CountriesModule {}
