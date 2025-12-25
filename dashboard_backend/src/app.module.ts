import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { join } from 'path';
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
      host: '127.0.0.1', // localhost yerine kesin IP
      port: 5432,
      username: 'kuser',
      password: 'kpass',
      database: 'dashboard_db',
      // ÖNEMLİ: dist klasörü içindeki derlenmiş JS dosyalarını hedef alıyoruz
      entities: [join(__dirname, '..', '**', '*.entity.{js,ts}')],
      synchronize: true, 
      logging: true, // Hata olursa loglarda SQL hatasını görelim
      retryAttempts: 10,
      retryDelay: 3000,
    }),
    ChatsModule,
    AssistantsModule,
    AnalyticsModule,
    UsersModule,
    AuthModule
  ],
})
export class AppModule {}