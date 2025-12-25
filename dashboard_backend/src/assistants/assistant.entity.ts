import { Entity, PrimaryGeneratedColumn, Column, OneToMany, ManyToOne } from 'typeorm';
import { Chat } from '../chats/chat.entity';
import { User } from '../users/user.entity';

@Entity('assistants')
export class Assistant {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  name: string;

  @Column({ nullable: true })
  description: string;

  @Column({ type: 'text', nullable: true })
  instructions: string;

  @Column({ default: 'gpt-3.5-turbo' })
  model: string;

  @OneToMany(() => Chat, (chat) => chat.assistant)
  chats: Chat[];

  @ManyToOne(() => User, { onDelete: 'CASCADE', nullable: true }) // İlişkiyi de nullable yaptık
  user: User;

  @Column({ nullable: true }) // <--- BURAYI DEĞİŞTİRDİK (Artık boş olabilir)
  userId: string;
}