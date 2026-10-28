import { Controller, Get } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';

@ApiTags('Health')
@Controller('health')
export class HealthController {
  @Get()
  check() {
    return { status: 'ok', service: 'ryvo-api', timestamp: new Date().toISOString() };
  }
}
