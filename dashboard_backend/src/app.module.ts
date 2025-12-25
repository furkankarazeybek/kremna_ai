import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ChatsModule } from './chats/chats.module';
import { AssistantsModule } from './assistants/assistants.module';
import { AnalyticsModule } from './analytics/analytics.module';
import { UsersModule } from './users/users.module';
import { AuthModule } from './auth/auth.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: '127.0.0.1', // Localhost yerine bunu kullanmak daha güvenli
      port: 5432,
      username: 'kuser',
      password: 'kpass',
      // DÜZELTME: Dockerfile'daki isimle birebir aynı olmalı:
      database: 'dashboard_db', 
      entities: [__dirname + '/**/*.entity{.ts,.js}'],
      synchronize: true,
    }),
    ChatsModule,
    AssistantsModule,
    AnalyticsModule,
    UsersModule,
    AuthModule
  ],
})
export class AppModule {}