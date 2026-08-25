# Fase 1 — Fondasi & Admin (Minggu 1–2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fondasi sistem lengkap (repos, skema DB penuh, auth + undangan) dan seluruh jalur konten (template spreadsheet → importer → CRUD admin → media), plus deploy + backup — sehingga tim konten klien bisa mulai bekerja dan admin klien bisa memuat soal.

**Architecture:** Monorepo-of-repos: workspace ini (docs/infra) + `apps/api` (NestJS 11 + Prisma 6 + PostgreSQL 16, repo git sendiri) + `apps/web` (Next.js 15 app router, repo git sendiri). Semua logika di API; web murni tampilan. Tanpa background job.

**Tech Stack:** Node 22 · TypeScript strict · NestJS 11 · Prisma 6 · PostgreSQL 16 · Next.js 15 + Tailwind · exceljs (xlsx) · csv-parse · bcrypt · @nestjs/jwt · Jest + supertest.

**Spec:** `docs/superpowers/specs/2026-08-25-english-app-foundation-design.md` (workspace root). Eksekutor WAJIB membaca spec bagian 3 (model data) dan 4 (template) sebelum Task 4–11.

## Global Constraints

- Repo `apps/web` dan `apps/api` adalah repo git **terpisah** — jangan pernah `git add` isi `apps/` dari workspace root. Commit task dilakukan di repo tempat file berubah.
- Semua logika bisnis (validasi, grading, import, agregasi) hidup di `apps/api`. `apps/web` tidak menghitung apa pun.
- Tabel `attempt` append-only selamanya; soal/lesson `RETIRED` tidak pernah di-DELETE.
- Akun hanya dibuat admin (CSV import / seed) — tidak ada endpoint registrasi publik.
- Angka konfigurasi (XP dsb.) di tabel `config`, bukan konstanta kode.
- Enum nilai template (huruf kecil, persis): level `dasar|menengah|mahir`, cefr `A1|A2|B1|B2|C1|C2`, skill `vocabulary|grammar|listening|reading`, type `pilihan_ganda|isian|susun_kalimat`.
- Copy UI admin berbahasa Indonesia.
- Tanpa cron/queue/background job.
- Env yang dipakai lintas task: `DATABASE_URL`, `JWT_SECRET`, `ADMIN_EMAIL`, `ADMIN_PASSWORD`, `STORAGE_DRIVER=local|s3`, `STORAGE_DIR` (local), `S3_*` (s3), `WEB_ORIGIN` (CORS), `NEXT_PUBLIC_API_URL` (web).

**Catatan penyelarasan spec (sudah diputuskan saat planning):** template tidak punya kolom urutan lesson; `lesson.order` = urutan kemunculan lesson_code dalam file saat import pertama (per level), bisa diubah lewat admin CRUD. Import ulang soal yang sudah ada memperbarui isinya dan **mengembalikan status ke DRAFT** (admin memverifikasi ulang).

---

### Task 1: Scaffold `apps/api` (NestJS + Prisma + Postgres dev)

**Files:**
- Create: `apps/api/` (repo git baru — NestJS scaffold)
- Create: `apps/api/docker-compose.yml`
- Create: `apps/api/.env.example`
- Test: `apps/api/test/health.e2e-spec.ts`

**Interfaces:**
- Produces: app NestJS berjalan di :3001, `GET /health` → `{"status":"ok"}`; Postgres dev di :5432 (`docker compose up -d`); skrip npm `start:dev`, `test`, `test:e2e`.

- [ ] **Step 1: Scaffold & init repo**

```bash
cd /Users/alva.e202511001/Desktop/project/english-app/apps
npx --yes @nestjs/cli@11 new api --package-manager npm --skip-git
cd api && git init -q
npm i prisma@6 @prisma/client@6 && npx prisma init
```

- [ ] **Step 2: Postgres dev via docker-compose**

`apps/api/docker-compose.yml`:
```yaml
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: app
      POSTGRES_DB: english_app
    ports: ["5432:5432"]
    volumes: [dbdata:/var/lib/postgresql/data]
volumes:
  dbdata:
```

`apps/api/.env.example` (copy ke `.env`):
```env
DATABASE_URL="postgresql://app:app@localhost:5432/english_app"
JWT_SECRET="ganti-di-produksi"
ADMIN_EMAIL="admin@example.com"
ADMIN_PASSWORD="admin1234"
STORAGE_DRIVER="local"
STORAGE_DIR="./storage"
WEB_ORIGIN="http://localhost:3000"
PORT=3001
```

Jalankan: `docker compose up -d`

- [ ] **Step 3: Health endpoint + port + CORS.** Di `src/main.ts`:

```ts
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableCors({ origin: process.env.WEB_ORIGIN, credentials: false });
  await app.listen(process.env.PORT ?? 3001);
}
bootstrap();
```

Di `src/app.controller.ts` ganti isi jadi:
```ts
import { Controller, Get } from '@nestjs/common';

@Controller()
export class AppController {
  @Get('health')
  health() { return { status: 'ok' }; }
}
```

- [ ] **Step 4: e2e test.** `test/health.e2e-spec.ts`:

```ts
import { Test } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';

describe('health', () => {
  let app: INestApplication;
  beforeAll(async () => {
    const m = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = m.createNestApplication();
    await app.init();
  });
  afterAll(() => app.close());
  it('GET /health', () =>
    request(app.getHttpServer()).get('/health').expect(200).expect({ status: 'ok' }));
});
```

Run: `npm run test:e2e` → PASS.

- [ ] **Step 5: Commit (di repo apps/api)**

```bash
git add -A && git commit -m "chore: scaffold NestJS + Prisma + postgres dev + health endpoint"
```

---

### Task 2: Skema Prisma lengkap (10 tabel) + migrasi + seed

**Files:**
- Create: `apps/api/prisma/schema.prisma` (ganti isi)
- Create: `apps/api/prisma/seed.ts`
- Create: `apps/api/src/prisma/prisma.module.ts`, `apps/api/src/prisma/prisma.service.ts`
- Test: `apps/api/test/schema.e2e-spec.ts`

**Interfaces:**
- Produces: `PrismaService` (global module, extends `PrismaClient`); semua model & enum di bawah; seed = 1 admin (dari env) + baris `config`. Task lain memakai nama model/field **persis** seperti di sini.

- [ ] **Step 1: Tulis schema.prisma**

```prisma
generator client { provider = "prisma-client-js" }
datasource db { provider = "postgresql"; url = env("DATABASE_URL") }

enum Role { USER ADMIN }
enum ContentStatus { DRAFT LIVE RETIRED }
enum ItemType { PILIHAN_GANDA ISIAN SUSUN_KALIMAT }
enum Level { DASAR MENENGAH MAHIR }
enum Cefr { A1 A2 B1 B2 C1 C2 }
enum SkillTag { VOCABULARY GRAMMAR LISTENING READING }
enum SessionStatus { IN_PROGRESS COMPLETED }
enum InviteStatus { PENDING ACCEPTED }
enum ReportStatus { OPEN RESOLVED }
enum SessionItemSource { LESSON REVIEW }

model User {
  id           String  @id @default(cuid())
  name         String
  email        String  @unique
  role         Role    @default(USER)
  passwordHash String?
  level        Level?
  dailyTargetSessions Int @default(1)
  inviteToken  String? @unique
  inviteStatus InviteStatus @default(PENDING)
  createdAt    DateTime @default(now())
  sessions     Session[]
  attempts     Attempt[]
  reviewQueue  ReviewQueue[]
  itemReports  ItemReport[]
  streakFreezes StreakFreeze[]
}

model Lesson {
  id     String @id @default(cuid())
  code   String @unique
  title  String
  topic  String
  level  Level
  cefr   Cefr
  skill  SkillTag
  order  Int
  status ContentStatus @default(DRAFT)
  items  Item[]
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

model Item {
  id              String @id @default(cuid())
  lessonId        String
  lesson          Lesson @relation(fields: [lessonId], references: [id])
  type            ItemType
  prompt          String
  options         Json?
  answerKey       String
  acceptedAnswers String[] @default([])
  explanation     String
  mediaFile       String?
  passage         String?
  order           Int
  status          ContentStatus @default(DRAFT)
  createdAt       DateTime @default(now())
  updatedAt       DateTime @updatedAt
  attempts        Attempt[]
  sessionItems    SessionItem[]
  reviewQueue     ReviewQueue[]
  itemReports     ItemReport[]
  @@unique([lessonId, order])
}

model Session {
  id          String @id @default(cuid())
  userId      String
  user        User @relation(fields: [userId], references: [id])
  date        DateTime @db.Date
  status      SessionStatus @default(IN_PROGRESS)
  completedAt DateTime?
  items       SessionItem[]
  attempts    Attempt[]
  @@unique([userId, date])
}

model SessionItem {
  sessionId String
  session   Session @relation(fields: [sessionId], references: [id])
  itemId    String
  item      Item @relation(fields: [itemId], references: [id])
  source    SessionItemSource
  order     Int
  @@id([sessionId, itemId])
}

model Attempt {
  id         String  @id @default(cuid())
  userId     String
  user       User @relation(fields: [userId], references: [id])
  itemId     String
  item       Item @relation(fields: [itemId], references: [id])
  sessionId  String
  session    Session @relation(fields: [sessionId], references: [id])
  answer     String
  correct    Boolean
  firstTry   Boolean
  answeredAt DateTime @default(now())
  @@index([userId, answeredAt])
}

model ReviewQueue {
  userId        String
  user          User @relation(fields: [userId], references: [id])
  itemId        String
  item          Item @relation(fields: [itemId], references: [id])
  dueDate       DateTime @db.Date
  correctStreak Int @default(0)
  @@id([userId, itemId])
}

model ItemReport {
  id        String @id @default(cuid())
  userId    String
  user      User @relation(fields: [userId], references: [id])
  itemId    String
  item      Item @relation(fields: [itemId], references: [id])
  note      String
  status    ReportStatus @default(OPEN)
  createdAt DateTime @default(now())
}

model Config {
  key   String @id
  value String
}

model StreakFreeze {
  userId    String
  user      User @relation(fields: [userId], references: [id])
  weekStart DateTime @db.Date
  usedAt    DateTime @default(now())
  @@id([userId, weekStart])
}
```

Run: `npx prisma migrate dev --name init` → migrasi sukses.

- [ ] **Step 2: PrismaService global.** `src/prisma/prisma.service.ts`:

```ts
import { Injectable, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit {
  async onModuleInit() { await this.$connect(); }
}
```

`src/prisma/prisma.module.ts`:
```ts
import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Global()
@Module({ providers: [PrismaService], exports: [PrismaService] })
export class PrismaModule {}
```

Import `PrismaModule` di `AppModule`.

- [ ] **Step 3: Seed.** `prisma/seed.ts`:

```ts
import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';
const prisma = new PrismaClient();

const CONFIG: Record<string, string> = {
  XP_FIRST_TRY: '10', XP_RETRY: '2', XP_SESSION_COMPLETE: '20',
  XP_PERFECT_SESSION: '15', XP_DAILY_REVIEW_CAP: '100',
  REVIEW_MAX_PER_SESSION: '3',
};

async function main() {
  for (const [key, value] of Object.entries(CONFIG))
    await prisma.config.upsert({ where: { key }, update: {}, create: { key, value } });
  const email = process.env.ADMIN_EMAIL!;
  await prisma.user.upsert({
    where: { email }, update: {},
    create: {
      name: 'Admin', email, role: 'ADMIN', inviteStatus: 'ACCEPTED',
      passwordHash: await bcrypt.hash(process.env.ADMIN_PASSWORD!, 10),
    },
  });
}
main().finally(() => prisma.$disconnect());
```

`npm i bcrypt && npm i -D @types/bcrypt ts-node`. Di `package.json` tambah:
```json
"prisma": { "seed": "ts-node prisma/seed.ts" }
```
Run: `npx prisma db seed` → sukses.

- [ ] **Step 4: Test skema hidup.** `test/schema.e2e-spec.ts`:

```ts
import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

describe('schema & seed', () => {
  afterAll(() => prisma.$disconnect());
  it('admin ada dan config terisi', async () => {
    const admin = await prisma.user.findUnique({ where: { email: process.env.ADMIN_EMAIL! } });
    expect(admin?.role).toBe('ADMIN');
    expect(await prisma.config.count()).toBeGreaterThanOrEqual(6);
  });
});
```

Run: `npm run test:e2e` → PASS. (e2e config Nest sudah memuat `.env`? Jika tidak: `npm i -D dotenv` dan tambahkan `import 'dotenv/config'` di atas test.)

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: full prisma schema (10 tables), prisma module, seed admin + config"
```

---

### Task 3: Auth — login JWT + role guard

**Files:**
- Create: `apps/api/src/auth/auth.module.ts`, `auth.service.ts`, `auth.controller.ts`, `jwt-auth.guard.ts`, `roles.guard.ts`, `roles.decorator.ts`, `current-user.decorator.ts`
- Test: `apps/api/test/auth.e2e-spec.ts`

**Interfaces:**
- Consumes: `PrismaService`; user admin hasil seed Task 2.
- Produces: `POST /auth/login {email, password}` → `{accessToken, role, name}` (401 jika salah). Guard stack untuk task lain: `@UseGuards(JwtAuthGuard, RolesGuard)` + `@Roles('ADMIN')`. Decorator `@CurrentUser()` → `{ sub: string; role: Role }`. Payload JWT: `{ sub, role }`, expiry 7d.

- [ ] **Step 1: Failing test.** `test/auth.e2e-spec.ts`:

```ts
import 'dotenv/config';
import { Test } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';

describe('auth', () => {
  let app: INestApplication;
  beforeAll(async () => {
    const m = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = m.createNestApplication();
    await app.init();
  });
  afterAll(() => app.close());

  it('login benar → token + role', async () => {
    const res = await request(app.getHttpServer()).post('/auth/login')
      .send({ email: process.env.ADMIN_EMAIL, password: process.env.ADMIN_PASSWORD })
      .expect(201);
    expect(res.body.accessToken).toBeDefined();
    expect(res.body.role).toBe('ADMIN');
  });
  it('password salah → 401', () =>
    request(app.getHttpServer()).post('/auth/login')
      .send({ email: process.env.ADMIN_EMAIL, password: 'salah' }).expect(401));
});
```

Run → FAIL (404 /auth/login).

- [ ] **Step 2: Implementasi.** `npm i @nestjs/jwt`. `src/auth/auth.service.ts`:

```ts
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AuthService {
  constructor(private prisma: PrismaService, private jwt: JwtService) {}

  async login(email: string, password: string) {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user?.passwordHash || !(await bcrypt.compare(password, user.passwordHash)))
      throw new UnauthorizedException('Email atau password salah');
    return {
      accessToken: await this.jwt.signAsync({ sub: user.id, role: user.role }),
      role: user.role, name: user.name,
    };
  }
}
```

`src/auth/jwt-auth.guard.ts`:
```ts
import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private jwt: JwtService) {}
  async canActivate(ctx: ExecutionContext) {
    const req = ctx.switchToHttp().getRequest();
    const token = req.headers.authorization?.replace('Bearer ', '');
    if (!token) throw new UnauthorizedException();
    try { req.user = await this.jwt.verifyAsync(token); } 
    catch { throw new UnauthorizedException(); }
    return true;
  }
}
```

`src/auth/roles.decorator.ts` + `roles.guard.ts`:
```ts
import { SetMetadata } from '@nestjs/common';
export const Roles = (...roles: string[]) => SetMetadata('roles', roles);
```
```ts
import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}
  canActivate(ctx: ExecutionContext) {
    const roles = this.reflector.get<string[]>('roles', ctx.getHandler())
      ?? this.reflector.get<string[]>('roles', ctx.getClass());
    if (!roles) return true;
    const { user } = ctx.switchToHttp().getRequest();
    if (!roles.includes(user?.role)) throw new ForbiddenException();
    return true;
  }
}
```

`src/auth/current-user.decorator.ts`:
```ts
import { createParamDecorator, ExecutionContext } from '@nestjs/common';
export const CurrentUser = createParamDecorator((_: unknown, ctx: ExecutionContext) =>
  ctx.switchToHttp().getRequest().user);
```

`src/auth/auth.controller.ts`:
```ts
import { Body, Controller, Post } from '@nestjs/common';
import { AuthService } from './auth.service';

@Controller('auth')
export class AuthController {
  constructor(private auth: AuthService) {}
  @Post('login')
  login(@Body() b: { email: string; password: string }) {
    return this.auth.login(b.email, b.password);
  }
}
```

`src/auth/auth.module.ts`:
```ts
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';
import { RolesGuard } from './roles.guard';

@Module({
  imports: [JwtModule.register({
    global: true,
    secret: process.env.JWT_SECRET,
    signOptions: { expiresIn: '7d' },
  })],
  controllers: [AuthController],
  providers: [AuthService, JwtAuthGuard, RolesGuard],
  exports: [JwtAuthGuard, RolesGuard],
})
export class AuthModule {}
```

Import `AuthModule` di `AppModule`.

- [ ] **Step 3: Run test** → PASS.

- [ ] **Step 4: Commit** — `git add -A && git commit -m "feat: JWT login + role guard"`

---

### Task 4: Alur undangan (invite token → set password)

**Files:**
- Modify: `apps/api/src/auth/auth.service.ts`, `auth.controller.ts`
- Test: `apps/api/test/invite.e2e-spec.ts`

**Interfaces:**
- Consumes: model `User` (field `inviteToken`, `inviteStatus`).
- Produces: `GET /auth/invite/:token` → `{name, email}` (404 jika tidak valid/terpakai); `POST /auth/accept-invite {token, password}` → `{accessToken, role, name}` — set `passwordHash`, `inviteStatus=ACCEPTED`, `inviteToken=null`. Password min 8 karakter (400 jika kurang). Task 5 membuat user ber-token; Task 12 (web) memakai kedua endpoint ini.

- [ ] **Step 1: Failing test.** `test/invite.e2e-spec.ts` (pola bootstrap sama dengan auth.e2e):

```ts
// ...bootstrap seperti auth.e2e-spec...
import { PrismaService } from '../src/prisma/prisma.service';
import { randomUUID } from 'crypto';

it('alur undangan lengkap', async () => {
  const prisma = app.get(PrismaService);
  const token = randomUUID();
  const email = `t-${token}@example.com`;
  await prisma.user.create({ data: { name: 'Budi', email, inviteToken: token } });

  const info = await request(app.getHttpServer()).get(`/auth/invite/${token}`).expect(200);
  expect(info.body.email).toBe(email);

  await request(app.getHttpServer()).post('/auth/accept-invite')
    .send({ token, password: 'pendek' }).expect(400);

  const ok = await request(app.getHttpServer()).post('/auth/accept-invite')
    .send({ token, password: 'rahasia123' }).expect(201);
  expect(ok.body.accessToken).toBeDefined();

  // token sekali pakai
  await request(app.getHttpServer()).get(`/auth/invite/${token}`).expect(404);
  await prisma.attempt.deleteMany({ where: { user: { email } } });
  await prisma.user.delete({ where: { email } });
});
```

Run → FAIL.

- [ ] **Step 2: Implementasi.** Tambah di `AuthService`:

```ts
async inviteInfo(token: string) {
  const u = await this.prisma.user.findFirst({
    where: { inviteToken: token, inviteStatus: 'PENDING' } });
  if (!u) throw new NotFoundException('Undangan tidak ditemukan atau sudah dipakai');
  return { name: u.name, email: u.email };
}

async acceptInvite(token: string, password: string) {
  if (!password || password.length < 8)
    throw new BadRequestException('Password minimal 8 karakter');
  const u = await this.prisma.user.findFirst({
    where: { inviteToken: token, inviteStatus: 'PENDING' } });
  if (!u) throw new NotFoundException('Undangan tidak ditemukan atau sudah dipakai');
  const updated = await this.prisma.user.update({
    where: { id: u.id },
    data: { passwordHash: await bcrypt.hash(password, 10),
            inviteStatus: 'ACCEPTED', inviteToken: null },
  });
  return {
    accessToken: await this.jwt.signAsync({ sub: updated.id, role: updated.role }),
    role: updated.role, name: updated.name,
  };
}
```

Controller:
```ts
@Get('invite/:token')
inviteInfo(@Param('token') token: string) { return this.auth.inviteInfo(token); }

@Post('accept-invite')
acceptInvite(@Body() b: { token: string; password: string }) {
  return this.auth.acceptInvite(b.token, b.password);
}
```

- [ ] **Step 3: Run test** → PASS. **Step 4: Commit** — `"feat: invitation flow (info + accept)"`

---

### Task 5: Import CSV karyawan → akun + link undangan

**Files:**
- Create: `apps/api/src/users/users.module.ts`, `users.service.ts`, `users.controller.ts`
- Test: `apps/api/test/users-import.e2e-spec.ts`

**Interfaces:**
- Consumes: guard Task 3; model `User`.
- Produces: `POST /admin/users/import` (multipart `file`, CSV header `nama,email`) → `{created: n, skipped: n, errors: [{row, message}], invites: [{name, email, inviteUrl}]}`. `inviteUrl` = `${WEB_ORIGIN}/invite/${token}`. Email duplikat (sudah ada di DB atau di file) → skipped + error per baris. `GET /admin/users` → daftar `{id,name,email,role,inviteStatus,level,createdAt}`.

- [ ] **Step 1: Failing test.** `test/users-import.e2e-spec.ts`:

```ts
// ...bootstrap; login admin dulu untuk dapat token (helper: POST /auth/login)...
const csv = 'nama,email\nBudi,budi-X@ex.com\nSiti,siti-X@ex.com\nBudi Lagi,budi-X@ex.com\n,kosong@ex.com'
  .replaceAll('X', Date.now().toString());

it('import karyawan: buat akun, laporkan duplikat & baris invalid', async () => {
  const res = await request(app.getHttpServer())
    .post('/admin/users/import')
    .set('Authorization', `Bearer ${adminToken}`)
    .attach('file', Buffer.from(csv), 'karyawan.csv')
    .expect(201);
  expect(res.body.created).toBe(2);
  expect(res.body.skipped).toBe(2);            // duplikat dalam file + nama kosong
  expect(res.body.errors).toHaveLength(2);
  expect(res.body.invites[0].inviteUrl).toContain('/invite/');
});

it('tanpa token admin → 401/403', () =>
  request(app.getHttpServer()).post('/admin/users/import').expect(401));
```

Run → FAIL.

- [ ] **Step 2: Implementasi.** `npm i csv-parse @nestjs/platform-express multer && npm i -D @types/multer`. `src/users/users.service.ts`:

```ts
import { Injectable } from '@nestjs/common';
import { parse } from 'csv-parse/sync';
import { randomUUID } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  list() {
    return this.prisma.user.findMany({
      select: { id: true, name: true, email: true, role: true,
                inviteStatus: true, level: true, createdAt: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async importCsv(buf: Buffer) {
    const rows: { nama: string; email: string }[] = parse(buf, {
      columns: true, skip_empty_lines: true, trim: true, bom: true,
    });
    const errors: { row: number; message: string }[] = [];
    const invites: { name: string; email: string; inviteUrl: string }[] = [];
    const seen = new Set<string>();
    let created = 0, skipped = 0;

    for (const [i, r] of rows.entries()) {
      const row = i + 2; // baris spreadsheet (1 = header)
      const email = (r.email ?? '').toLowerCase();
      if (!r.nama || !EMAIL_RE.test(email)) {
        errors.push({ row, message: 'Nama kosong atau email tidak valid' }); skipped++; continue;
      }
      if (seen.has(email)) {
        errors.push({ row, message: `Email duplikat di dalam file: ${email}` }); skipped++; continue;
      }
      seen.add(email);
      if (await this.prisma.user.findUnique({ where: { email } })) {
        errors.push({ row, message: `Email sudah terdaftar: ${email}` }); skipped++; continue;
      }
      const token = randomUUID();
      await this.prisma.user.create({ data: { name: r.nama, email, inviteToken: token } });
      invites.push({ name: r.nama, email,
        inviteUrl: `${process.env.WEB_ORIGIN}/invite/${token}` });
      created++;
    }
    return { created, skipped, errors, invites };
  }
}
```

`src/users/users.controller.ts`:
```ts
import { Controller, Get, Post, UseGuards, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { UsersService } from './users.service';

@Controller('admin/users')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class UsersController {
  constructor(private users: UsersService) {}
  @Get() list() { return this.users.list(); }
  @Post('import')
  @UseInterceptors(FileInterceptor('file'))
  import(@UploadedFile() file: Express.Multer.File) {
    return this.users.importCsv(file.buffer);
  }
}
```

Module + daftarkan di `AppModule`.

- [ ] **Step 3: Run test** → PASS. **Step 4: Commit** — `"feat: employee CSV import with per-row errors + invite links"`

---

### Task 6: StorageService + upload/list media

**Files:**
- Create: `apps/api/src/storage/storage.module.ts`, `storage.service.ts`
- Create: `apps/api/src/media/media.module.ts`, `media.controller.ts`
- Test: `apps/api/test/media.e2e-spec.ts`

**Interfaces:**
- Consumes: guard Task 3.
- Produces: `StorageService` global dengan `put(name, buf, mime): Promise<void>`, `exists(name): Promise<boolean>`, `listNames(): Promise<string[]>`, `getUrl(name): string`. Driver `local` (dir `STORAGE_DIR`, disajikan statis di `GET /media/:name`) — driver `s3` ditambahkan di Task 14 (deploy) dengan interface yang sama. Endpoint admin: `POST /admin/media` (multipart `files[]`, maks 20 file; ekstensi wajib `.mp3 .m4a .png .jpg .jpeg .webp`; nama sudah ada → 409 per file dalam laporan), `GET /admin/media` → `[{name, size}]`.

- [ ] **Step 1: Failing test.** `test/media.e2e-spec.ts`:

```ts
it('upload lalu list', async () => {
  const res = await request(app.getHttpServer())
    .post('/admin/media').set('Authorization', `Bearer ${adminToken}`)
    .attach('files', Buffer.from('fake-mp3'), 'audio_test_001.mp3')
    .attach('files', Buffer.from('fake-exe'), 'virus.exe')
    .expect(201);
  expect(res.body.saved).toContain('audio_test_001.mp3');
  expect(res.body.rejected[0]).toMatchObject({ name: 'virus.exe' });

  const list = await request(app.getHttpServer())
    .get('/admin/media').set('Authorization', `Bearer ${adminToken}`).expect(200);
  expect(list.body.map((f: any) => f.name)).toContain('audio_test_001.mp3');
});
```

Run → FAIL.

- [ ] **Step 2: Implementasi local driver.** `src/storage/storage.service.ts`:

```ts
import { Injectable } from '@nestjs/common';
import { promises as fs } from 'fs';
import * as path from 'path';

@Injectable()
export class StorageService {
  private dir = process.env.STORAGE_DIR ?? './storage';

  private safe(name: string) {
    const base = path.basename(name); // tolak path traversal
    return path.join(this.dir, base);
  }
  async put(name: string, buf: Buffer) {
    await fs.mkdir(this.dir, { recursive: true });
    await fs.writeFile(this.safe(name), buf);
  }
  async exists(name: string) {
    try { await fs.access(this.safe(name)); return true; } catch { return false; }
  }
  async listNames() {
    await fs.mkdir(this.dir, { recursive: true });
    return fs.readdir(this.dir);
  }
  async stat(name: string) { return fs.stat(this.safe(name)); }
  getUrl(name: string) { return `/media/${name}`; }
}
```

`src/media/media.controller.ts`:
```ts
import { BadRequestException, Controller, Get, Param, Post, Res,
  UploadedFiles, UseGuards, UseInterceptors } from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { Response } from 'express';
import * as path from 'path';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { StorageService } from '../storage/storage.service';

const ALLOWED = new Set(['.mp3', '.m4a', '.png', '.jpg', '.jpeg', '.webp']);

@Controller()
export class MediaController {
  constructor(private storage: StorageService) {}

  @Post('admin/media')
  @UseGuards(JwtAuthGuard, RolesGuard) @Roles('ADMIN')
  @UseInterceptors(FilesInterceptor('files', 20))
  async upload(@UploadedFiles() files: Express.Multer.File[]) {
    if (!files?.length) throw new BadRequestException('Tidak ada file');
    const saved: string[] = [];
    const rejected: { name: string; reason: string }[] = [];
    for (const f of files) {
      const ext = path.extname(f.originalname).toLowerCase();
      if (!ALLOWED.has(ext)) { rejected.push({ name: f.originalname, reason: 'Ekstensi tidak didukung' }); continue; }
      if (await this.storage.exists(f.originalname)) { rejected.push({ name: f.originalname, reason: 'Nama sudah ada' }); continue; }
      await this.storage.put(f.originalname, f.buffer);
      saved.push(f.originalname);
    }
    return { saved, rejected };
  }

  @Get('admin/media')
  @UseGuards(JwtAuthGuard, RolesGuard) @Roles('ADMIN')
  async list() {
    const names = await this.storage.listNames();
    return Promise.all(names.map(async (name) => ({ name, size: (await this.storage.stat(name)).size })));
  }

  @Get('media/:name')
  async serve(@Param('name') name: string, @Res() res: Response) {
    if (!(await this.storage.exists(name))) return res.status(404).end();
    res.sendFile(path.basename(name), { root: process.env.STORAGE_DIR ?? './storage' });
  }
}
```

Storage module `@Global()`, export `StorageService`; daftarkan keduanya di `AppModule`. Tambah `storage/` ke `.gitignore` repo api.

- [ ] **Step 3: Run test** → PASS. **Step 4: Commit** — `"feat: media storage (local driver) + admin upload/list"`

---

### Task 7: Validator baris soal (fungsi murni — inti importer)

**Files:**
- Create: `apps/api/src/content/import/row-validator.ts`
- Test: `apps/api/src/content/import/row-validator.spec.ts`

**Interfaces:**
- Produces (dipakai Task 8):

```ts
export interface RawRow { [col: string]: string }           // semua nilai string ter-trim
export interface RowError { row: number; column: string; message: string }
export interface NormalizedRow {
  lessonCode: string; lessonTitle: string; topic: string;
  level: 'DASAR'|'MENENGAH'|'MAHIR'; cefr: 'A1'|'A2'|'B1'|'B2'|'C1'|'C2';
  skill: 'VOCABULARY'|'GRAMMAR'|'LISTENING'|'READING';
  itemOrder: number;
  type: 'PILIHAN_GANDA'|'ISIAN'|'SUSUN_KALIMAT';
  prompt: string; options: string[] | null; answerKey: string;
  acceptedAnswers: string[]; explanation: string;
  mediaFile: string | null; passage: string | null;
  sourceRow: number;
}
export function validateRows(rows: RawRow[], mediaNames: Set<string>):
  { valid: NormalizedRow[]; errors: RowError[] }
```

Baris pertama data = `sourceRow` 2 (baris 1 = header). Baris dengan error apa pun TIDAK masuk `valid`.

**Aturan validasi (lengkap — inilah kontrak template):**
1. Wajib nonkosong: `lesson_code, lesson_title, topic, level, cefr, skill, item_order, type, prompt, answer, explanation`.
2. `level ∈ {dasar,menengah,mahir}`, `cefr ∈ {A1..C2}`, `skill ∈ {vocabulary,grammar,listening,reading}`, `type ∈ {pilihan_ganda,isian,susun_kalimat}` (case-insensitive; dinormalkan ke enum kode).
3. `item_order` bilangan bulat ≥ 1.
4. `pilihan_ganda`: `option_a..option_d` semua terisi; `answer` ∈ {A,B,C,D} (case-insensitive).
5. `isian`: `prompt` mengandung `___`; `accepted_answers` terisi (dipecah `;`, trim, buang kosong; `answer` ikut dimasukkan ke daftar jawaban sah bila belum ada).
6. `susun_kalimat`: `answer` minimal 3 kata.
7. `media_file` terisi → harus ada di `mediaNames` (pesan: `File media 'X' belum diunggah`).
8. Lintas-baris: duplikat `(lesson_code, item_order)` → error di baris kedua dst.; `lesson_code` sama dengan `lesson_title|topic|level|cefr|skill` berbeda dari kemunculan pertama → error di baris yang menyimpang (pesan menyebut baris acuan).

- [ ] **Step 1: Tulis failing tests** — `row-validator.spec.ts`, minimal kasus: (a) baris pilihan_ganda valid → 1 valid 0 error; (b) MC tanpa option_c; (c) answer `E`; (d) isian tanpa `___`; (e) isian: accepted_answers dipecah & answer tergabung; (f) susun_kalimat 2 kata → error; (g) level `Pemula` → error enum; (h) media hilang; (i) duplikat lesson_code+item_order; (j) metadata lesson konflik; (k) item_order `abc`. Contoh dua di antaranya:

```ts
const base: RawRow = {
  lesson_code: 'BUS-01', lesson_title: 'Email Perkenalan', topic: 'Business',
  level: 'menengah', cefr: 'B1', skill: 'vocabulary', item_order: '1',
  type: 'pilihan_ganda', prompt: 'What does "schedule" mean?',
  option_a: 'Jadwal', option_b: 'Pertemuan', option_c: 'Perjalanan', option_d: 'Tujuan',
  answer: 'a', accepted_answers: '', explanation: 'Schedule = jadwal.',
  media_file: '', passage: '',
};

it('baris valid dinormalkan', () => {
  const { valid, errors } = validateRows([base], new Set());
  expect(errors).toHaveLength(0);
  expect(valid[0]).toMatchObject({ level: 'MENENGAH', type: 'PILIHAN_GANDA',
    answerKey: 'A', options: ['Jadwal','Pertemuan','Perjalanan','Tujuan'], sourceRow: 2 });
});

it('metadata lesson konflik → error di baris menyimpang', () => {
  const r2 = { ...base, item_order: '2', level: 'dasar' };
  const { valid, errors } = validateRows([base, r2], new Set());
  expect(valid).toHaveLength(1);
  expect(errors[0]).toMatchObject({ row: 3, column: 'level' });
});
```

Run: `npx jest row-validator` → FAIL.

- [ ] **Step 2: Implementasi `validateRows`** — fungsi murni tanpa dependensi Nest/Prisma:

```ts
const LEVELS: Record<string, NormalizedRow['level']> =
  { dasar: 'DASAR', menengah: 'MENENGAH', mahir: 'MAHIR' };
const CEFRS = new Set(['A1','A2','B1','B2','C1','C2']);
const SKILLS: Record<string, NormalizedRow['skill']> =
  { vocabulary: 'VOCABULARY', grammar: 'GRAMMAR', listening: 'LISTENING', reading: 'READING' };
const TYPES: Record<string, NormalizedRow['type']> =
  { pilihan_ganda: 'PILIHAN_GANDA', isian: 'ISIAN', susun_kalimat: 'SUSUN_KALIMAT' };
const REQUIRED = ['lesson_code','lesson_title','topic','level','cefr','skill',
  'item_order','type','prompt','answer','explanation'];

export function validateRows(rows: RawRow[], mediaNames: Set<string>) {
  const valid: NormalizedRow[] = [];
  const errors: RowError[] = [];
  const lessonMeta = new Map<string, { row: number; sig: string }>();
  const seenOrder = new Set<string>();

  rows.forEach((r, i) => {
    const row = i + 2;
    const errsBefore = errors.length;
    const err = (column: string, message: string) => errors.push({ row, column, message });

    for (const col of REQUIRED) if (!r[col]) err(col, `Kolom '${col}' wajib diisi`);

    const level = LEVELS[(r.level ?? '').toLowerCase()];
    if (r.level && !level) err('level', `Nilai level harus dasar/menengah/mahir, bukan '${r.level}'`);
    const cefr = (r.cefr ?? '').toUpperCase();
    if (r.cefr && !CEFRS.has(cefr)) err('cefr', `Nilai cefr harus A1–C2, bukan '${r.cefr}'`);
    const skill = SKILLS[(r.skill ?? '').toLowerCase()];
    if (r.skill && !skill) err('skill', `Nilai skill tidak dikenal: '${r.skill}'`);
    const type = TYPES[(r.type ?? '').toLowerCase()];
    if (r.type && !type) err('type', `Nilai type tidak dikenal: '${r.type}'`);

    const itemOrder = Number(r.item_order);
    if (r.item_order && (!Number.isInteger(itemOrder) || itemOrder < 1))
      err('item_order', `item_order harus bilangan bulat ≥ 1, bukan '${r.item_order}'`);

    let options: string[] | null = null;
    let answerKey = (r.answer ?? '').trim();
    let acceptedAnswers: string[] = [];

    if (type === 'PILIHAN_GANDA') {
      options = [r.option_a, r.option_b, r.option_c, r.option_d].map((o) => (o ?? '').trim());
      options.forEach((o, oi) => { if (!o) err(`option_${'abcd'[oi]}`, 'Opsi wajib diisi untuk pilihan_ganda'); });
      answerKey = answerKey.toUpperCase();
      if (!['A','B','C','D'].includes(answerKey)) err('answer', `Kunci pilihan_ganda harus A/B/C/D, bukan '${r.answer}'`);
    } else if (type === 'ISIAN') {
      if (r.prompt && !r.prompt.includes('___')) err('prompt', "Soal isian harus mengandung '___'");
      acceptedAnswers = (r.accepted_answers ?? '').split(';').map((s) => s.trim()).filter(Boolean);
      if (answerKey && !acceptedAnswers.some((a) => a.toLowerCase() === answerKey.toLowerCase()))
        acceptedAnswers.unshift(answerKey);
      if (!acceptedAnswers.length) err('accepted_answers', 'Soal isian butuh minimal satu jawaban sah');
    } else if (type === 'SUSUN_KALIMAT') {
      if (answerKey.split(/\s+/).filter(Boolean).length < 3)
        err('answer', 'Kalimat susun_kalimat minimal 3 kata');
    }

    const mediaFile = (r.media_file ?? '').trim() || null;
    if (mediaFile && !mediaNames.has(mediaFile))
      err('media_file', `File media '${mediaFile}' belum diunggah`);

    const code = (r.lesson_code ?? '').trim();
    if (code) {
      const sig = [r.lesson_title, r.topic, (r.level ?? '').toLowerCase(),
        cefr, (r.skill ?? '').toLowerCase()].join('|');
      const first = lessonMeta.get(code);
      if (!first) lessonMeta.set(code, { row, sig });
      else if (first.sig !== sig) {
        const diff = ['lesson_title','topic','level','cefr','skill'].find(
          (c, ci) => first.sig.split('|')[ci] !== sig.split('|')[ci]) ?? 'lesson_title';
        err(diff, `Metadata lesson '${code}' berbeda dari baris ${first.row}`);
      }
      const key = `${code}#${itemOrder}`;
      if (r.item_order && seenOrder.has(key))
        err('item_order', `Duplikat: lesson '${code}' sudah punya item_order ${itemOrder}`);
      seenOrder.add(key);
    }

    if (errors.length === errsBefore)
      valid.push({ lessonCode: code, lessonTitle: r.lesson_title.trim(), topic: r.topic.trim(),
        level: level!, cefr: cefr as NormalizedRow['cefr'], skill: skill!,
        itemOrder, type: type!, prompt: r.prompt.trim(), options, answerKey,
        acceptedAnswers, explanation: r.explanation.trim(), mediaFile,
        passage: (r.passage ?? '').trim() || null, sourceRow: row });
  });
  return { valid, errors };
}
```

- [ ] **Step 3: Run** `npx jest row-validator` → semua PASS. Tambah kasus yang belum lolos sampai 11 kasus hijau.

- [ ] **Step 4: Commit** — `"feat: pure row validator for question import (11 rules, per-row errors)"`

---

### Task 8: Import service — parse xlsx + upsert idempoten

**Files:**
- Create: `apps/api/src/content/import/import.service.ts`, `apps/api/src/content/import/xlsx-parser.ts`
- Test: `apps/api/test/import.e2e-spec.ts` (bagian service; endpoint di Task 9)

**Interfaces:**
- Consumes: `validateRows` (Task 7), `StorageService.listNames()` (Task 6), `PrismaService`.
- Produces: `ImportService.importWorkbook(buf: Buffer): Promise<ImportResult>` dengan

```ts
interface ImportResult {
  lessonsCreated: number; lessonsUpdated: number;
  itemsCreated: number; itemsUpdated: number;
  skippedRows: number; errors: RowError[];
}
```

Perilaku: hanya baris valid diimpor (parsial); lesson di-upsert by `code` (baru → `order` = max(order per level)+1 sesuai urutan kemunculan; sudah ada → metadata diperbarui, `order` & `status` TIDAK disentuh); item di-upsert by `(lessonId, order=itemOrder)` — baru → `DRAFT`; sudah ada → konten diperbarui **dan status di-reset ke DRAFT**. Seluruh penulisan dalam satu `$transaction`.

- [ ] **Step 1: xlsx parser.** `npm i exceljs`. `xlsx-parser.ts`:

```ts
import * as ExcelJS from 'exceljs';
import { RawRow } from './row-validator';

export async function parseWorkbook(buf: Buffer): Promise<RawRow[]> {
  const wb = new ExcelJS.Workbook();
  await wb.xlsx.load(buf as any);
  const ws = wb.worksheets.find((w) => w.name.toLowerCase() !== 'petunjuk') ?? wb.worksheets[0];
  const headers: string[] = [];
  ws.getRow(1).eachCell((c, i) => { headers[i] = String(c.value ?? '').trim().toLowerCase(); });
  const rows: RawRow[] = [];
  ws.eachRow((row, n) => {
    if (n === 1) return;
    const r: RawRow = {};
    headers.forEach((h, i) => {
      if (!h) return;
      const v = row.getCell(i).value;
      r[h] = (typeof v === 'object' && v !== null && 'text' in (v as any)
        ? (v as any).text : String(v ?? '')).trim();
    });
    if (Object.values(r).some((x) => x !== '')) rows.push(r);
  });
  return rows;
}
```

- [ ] **Step 2: Failing test.** Di `test/import.e2e-spec.ts`, bangun workbook di memori (exceljs) berisi header standar + 3 baris valid (2 lesson) + 1 baris rusak, panggil `ImportService.importWorkbook` dua kali:

```ts
it('import → idempoten → status reset ke DRAFT saat re-import', async () => {
  const svc = app.get(ImportService);
  const buf = await buildTestWorkbook(); // helper dalam file test, exceljs, 4 baris
  const r1 = await svc.importWorkbook(buf);
  expect(r1).toMatchObject({ lessonsCreated: 2, itemsCreated: 3, skippedRows: 1 });
  // naikkan satu item ke LIVE lalu import ulang file yang sama
  const item = await prisma.item.findFirst({ where: { lesson: { code: 'TST-01' } } });
  await prisma.item.update({ where: { id: item!.id }, data: { status: 'LIVE' } });
  const r2 = await svc.importWorkbook(buf);
  expect(r2).toMatchObject({ lessonsCreated: 0, itemsCreated: 0, itemsUpdated: 3 });
  const after = await prisma.item.findUnique({ where: { id: item!.id } });
  expect(after!.status).toBe('DRAFT'); // re-import → verifikasi ulang
});
```

Run → FAIL.

- [ ] **Step 3: Implementasi.** `import.service.ts`:

```ts
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { StorageService } from '../../storage/storage.service';
import { parseWorkbook } from './xlsx-parser';
import { validateRows, NormalizedRow, RowError } from './row-validator';

@Injectable()
export class ImportService {
  constructor(private prisma: PrismaService, private storage: StorageService) {}

  async importWorkbook(buf: Buffer) {
    const rows = await parseWorkbook(buf);
    const media = new Set(await this.storage.listNames());
    const { valid, errors } = validateRows(rows, media);
    const result = { lessonsCreated: 0, lessonsUpdated: 0, itemsCreated: 0,
      itemsUpdated: 0, skippedRows: errors.length ? new Set(errors.map(e => e.row)).size : 0,
      errors };

    await this.prisma.$transaction(async (tx) => {
      const byLesson = new Map<string, NormalizedRow[]>();
      for (const v of valid)
        byLesson.set(v.lessonCode, [...(byLesson.get(v.lessonCode) ?? []), v]);

      for (const [code, items] of byLesson) {
        const meta = items[0];
        let lesson = await tx.lesson.findUnique({ where: { code } });
        if (!lesson) {
          const max = await tx.lesson.aggregate({ where: { level: meta.level }, _max: { order: true } });
          lesson = await tx.lesson.create({ data: { code, title: meta.lessonTitle,
            topic: meta.topic, level: meta.level, cefr: meta.cefr, skill: meta.skill,
            order: (max._max.order ?? 0) + 1 } });
          result.lessonsCreated++;
        } else {
          lesson = await tx.lesson.update({ where: { id: lesson.id },
            data: { title: meta.lessonTitle, topic: meta.topic, level: meta.level,
              cefr: meta.cefr, skill: meta.skill } });
          result.lessonsUpdated++;
        }
        for (const v of items) {
          const data = { type: v.type, prompt: v.prompt,
            options: v.options ?? undefined, answerKey: v.answerKey,
            acceptedAnswers: v.acceptedAnswers, explanation: v.explanation,
            mediaFile: v.mediaFile, passage: v.passage };
          const existing = await tx.item.findUnique({
            where: { lessonId_order: { lessonId: lesson.id, order: v.itemOrder } } });
          if (existing) {
            await tx.item.update({ where: { id: existing.id },
              data: { ...data, status: 'DRAFT' } });
            result.itemsUpdated++;
          } else {
            await tx.item.create({ data: { ...data, lessonId: lesson.id, order: v.itemOrder } });
            result.itemsCreated++;
          }
        }
      }
    });
    return result;
  }
}
```

- [ ] **Step 4: Run test** → PASS. **Step 5: Commit** — `"feat: idempotent question import service (xlsx → validate → upsert)"`

---

### Task 9: Endpoint import + laporan error

**Files:**
- Create: `apps/api/src/content/content.module.ts`, `apps/api/src/content/import/import.controller.ts`
- Modify: `apps/api/test/import.e2e-spec.ts` (tambah kasus endpoint)

**Interfaces:**
- Consumes: `ImportService` (Task 8), guard Task 3.
- Produces: `POST /admin/import/questions` (multipart `file` .xlsx) → `ImportResult` (JSON; web membuat CSV error di sisi klien dari array `errors`). File bukan .xlsx → 400. `ContentModule` mendaftarkan `ImportService`, `ImportController`, dan (Task 10–11) controller lain; terdaftar di `AppModule`.

- [ ] **Step 1: Failing test** — upload workbook test yang sama via supertest `.attach('file', buf, 'soal.xlsx')`, expect 201 + body sama dengan hasil service; upload `soal.txt` → 400; tanpa token → 401.

- [ ] **Step 2: Implementasi.** `import.controller.ts`:

```ts
import { BadRequestException, Controller, Post, UploadedFile,
  UseGuards, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../../auth/jwt-auth.guard';
import { RolesGuard } from '../../auth/roles.guard';
import { Roles } from '../../auth/roles.decorator';
import { ImportService } from './import.service';

@Controller('admin/import')
@UseGuards(JwtAuthGuard, RolesGuard) @Roles('ADMIN')
export class ImportController {
  constructor(private importer: ImportService) {}
  @Post('questions')
  @UseInterceptors(FileInterceptor('file'))
  import(@UploadedFile() file: Express.Multer.File) {
    if (!file?.originalname.toLowerCase().endsWith('.xlsx'))
      throw new BadRequestException('File harus .xlsx (pakai template yang dikirim)');
    return this.importer.importWorkbook(file.buffer);
  }
}
```

- [ ] **Step 3: Run test** → PASS. **Step 4: Commit** — `"feat: question import endpoint"`

---

### Task 10: Generator template xlsx + petunjuk (deliverable klien minggu 1)

**Files:**
- Create: `apps/api/scripts/generate-template.ts`
- Create (output, di workspace): `deliverables/template-soal-v1.xlsx`, `deliverables/petunjuk-pengisian.md`

**Interfaces:**
- Consumes: daftar kolom & enum dari Task 7 (kontraknya sama persis — validator adalah kebenaran tunggal).
- Produces: file xlsx 2 sheet — `Soal` (header + 5 baris contoh terisi: 3 pilihan_ganda [1 dengan media_file, 1 dengan passage], 1 isian, 1 susun_kalimat; dropdown data-validation untuk kolom `level`, `cefr`, `skill`, `type`; header di-freeze) dan `Petunjuk` (ringkasan aturan per kolom). Plus dokumen petunjuk markdown untuk dikirim bersama file.

- [ ] **Step 1: Tulis script** `scripts/generate-template.ts` dengan exceljs:

```ts
import * as ExcelJS from 'exceljs';

const HEADERS = ['lesson_code','lesson_title','topic','level','cefr','skill',
  'item_order','type','prompt','option_a','option_b','option_c','option_d',
  'answer','accepted_answers','explanation','media_file','passage'];

const EXAMPLES = [
  ['BUS-01','Email Perkenalan','Business English','menengah','B1','vocabulary','1','pilihan_ganda',
   'What does "schedule" mean?','Jadwal','Pertemuan','Perjalanan','Tujuan','A','',
   '"Schedule" berarti jadwal — daftar waktu kegiatan.','',''],
  ['BUS-01','Email Perkenalan','Business English','menengah','B1','grammar','2','isian',
   'Please ___ the report before Friday.','','','','','submit','submit;send;hand in',
   '"Submit" = menyerahkan. Umum dipakai untuk laporan.','',''],
  ['BUS-01','Email Perkenalan','Business English','menengah','B1','grammar','3','susun_kalimat',
   'Susun kalimat berikut:','','','','','I will send the report tomorrow','',
   'Pola: Subject + will + verb. "Will" untuk rencana.','',''],
  ['LIS-01','Sapaan di Telepon','Phone English','dasar','A2','listening','1','pilihan_ganda',
   'Dengarkan audio. Siapa yang menelepon?','Mr. Tanaka','Ms. Sari','Mr. Budi','Ms. Rina','B','',
   'Penelepon menyebut namanya di detik ke-3.','audio_001.mp3',''],
  ['RD-01','Memo Kantor','Office English','menengah','B1','reading','1','pilihan_ganda',
   'Baca teks. Kapan rapat diadakan?','Senin','Selasa','Rabu','Kamis','C','',
   'Kalimat kedua memo menyebut "Wednesday".','',
   'MEMO: The monthly meeting is moved. It will be held on Wednesday at 10 AM in Room 3.'],
];

async function main() {
  const wb = new ExcelJS.Workbook();
  const ws = wb.addWorksheet('Soal');
  ws.addRow(HEADERS).font = { bold: true };
  EXAMPLES.forEach((r) => ws.addRow(r));
  ws.views = [{ state: 'frozen', ySplit: 1 }];
  ws.columns.forEach((c, i) => { c.width = [12,20,18,10,6,12,10,14,40,14,14,14,14,10,24,40,16,50][i]; });
  const dropdown = (col: string, list: string[]) => {
    for (let row = 2; row <= 500; row++)
      ws.getCell(`${col}${row}`).dataValidation =
        { type: 'list', allowBlank: true, formulae: [`"${list.join(',')}"`] };
  };
  dropdown('D', ['dasar','menengah','mahir']);
  dropdown('E', ['A1','A2','B1','B2','C1','C2']);
  dropdown('F', ['vocabulary','grammar','listening','reading']);
  dropdown('H', ['pilihan_ganda','isian','susun_kalimat']);

  const pj = wb.addWorksheet('Petunjuk');
  ([['Kolom','Aturan'],
    ['lesson_code','Kode unik lesson, mis. BUS-01. Baris dengan kode sama = satu lesson (8–10 soal).'],
    ['level / cefr / skill / type','Pilih dari dropdown. Jangan mengetik nilai lain.'],
    ['item_order','Nomor urut soal di dalam lesson: 1, 2, 3, …'],
    ['prompt','Teks soal. Untuk isian, tulis ___ (3 underscore) di bagian yang dikosongkan.'],
    ['option_a–d','Hanya untuk pilihan_ganda. Keempatnya wajib diisi.'],
    ['answer','pilihan_ganda: A/B/C/D · isian: jawaban utama · susun_kalimat: kalimat lengkap yang benar (min. 3 kata).'],
    ['accepted_answers','Hanya isian: variasi jawaban yang diterima, dipisah titik-koma. Contoh: submit;send'],
    ['explanation','WAJIB. Jelaskan kenapa jawabannya benar — muncul ke karyawan saat menjawab salah.'],
    ['media_file','Nama file audio/gambar persis seperti yang diunggah admin. Kosongkan jika tidak ada.'],
    ['passage','Teks bacaan untuk soal reading. Kosongkan jika tidak ada.'],
  ]).forEach((r) => pj.addRow(r));
  pj.getRow(1).font = { bold: true };
  pj.getColumn(1).width = 22; pj.getColumn(2).width = 90;

  await wb.xlsx.writeFile('../../deliverables/template-soal-v1.xlsx');
  console.log('template written');
}
main();
```

Tambah npm script: `"template": "ts-node scripts/generate-template.ts"`. Run: `mkdir -p ../../deliverables && npm run template`.

- [ ] **Step 2: Tulis `deliverables/petunjuk-pengisian.md`** (workspace) — 1 halaman: cara kerja lesson (kode sama = 1 lesson, 8–10 soal), 3 tipe soal dengan 1 contoh masing-masing (salin dari baris contoh), aturan media (upload dulu → tulis nama file), larangan mengubah header, dan catatan bahwa file bisa dikirim bertahap (import ulang aman).

- [ ] **Step 3: Verifikasi round-trip** — tambah test di `import.e2e-spec.ts`: baca `deliverables/template-soal-v1.xlsx` dari disk, jalankan `importWorkbook`; expect `errors` hanya berisi 1 error `media_file` (audio_001.mp3 belum diunggah) dan 4 baris valid terimpor. **Template yang dikirim ke klien terbukti lolos importer kita sendiri.**

- [ ] **Step 4: Commit** — repo api: `"feat: xlsx template generator"`; repo workspace: `git add deliverables && git commit -m "docs: template soal v1 + petunjuk pengisian (deliverable minggu 1)"`

---

### Task 11: Admin CRUD lessons & items + transisi status

**Files:**
- Create: `apps/api/src/content/lessons.controller.ts`, `apps/api/src/content/items.controller.ts`, `apps/api/src/content/content.service.ts`
- Test: `apps/api/test/content-crud.e2e-spec.ts`

**Interfaces:**
- Consumes: guard Task 3, `PrismaService`, data hasil import Task 8.
- Produces (semua di bawah `@Roles('ADMIN')`):
  - `GET /admin/lessons?level=&status=&topic=` → `[{id,code,title,topic,level,cefr,skill,order,status,itemCount,liveItemCount}]` urut `level, order`.
  - `PATCH /admin/lessons/:id` body subset `{title,topic,order,status}`.
  - `GET /admin/lessons/:id/items` → item lengkap urut `order`.
  - `PATCH /admin/items/:id` body subset `{prompt,options,answerKey,acceptedAnswers,explanation,mediaFile,passage,status}`.
  - Aturan status (lesson & item sama): `DRAFT→LIVE`, `LIVE→DRAFT`, `LIVE→RETIRED`. Transisi lain → 400 `Transisi status X→Y tidak diizinkan`. Tidak ada endpoint DELETE.
  - Validasi konten saat PATCH item: aturan tipe dari Task 7 berlaku (mis. mengosongkan `option_b` pada pilihan_ganda → 400) — pakai `validateRows` dengan membangun `RawRow` tunggal dari state hasil merge.

- [ ] **Step 1: Failing tests** — kasus minimal: list lessons berisi lesson hasil import dengan `itemCount` benar; PATCH item `explanation` berubah; `DRAFT→LIVE` sukses; `DRAFT→RETIRED` → 400; PATCH pilihan_ganda dengan `answerKey:'E'` → 400; tidak ada route DELETE (supertest `.delete(...)` → 404).

- [ ] **Step 2: Implementasi** `content.service.ts` — poin krusial transisi:

```ts
const ALLOWED_TRANSITIONS: Record<string, string[]> =
  { DRAFT: ['LIVE'], LIVE: ['DRAFT', 'RETIRED'], RETIRED: [] };

assertTransition(from: ContentStatus, to: ContentStatus) {
  if (from !== to && !ALLOWED_TRANSITIONS[from].includes(to))
    throw new BadRequestException(`Transisi status ${from}→${to} tidak diizinkan`);
}
```

dan validasi PATCH item: merge state lama + patch → bangun `RawRow` (balikkan enum ke huruf kecil, options ke option_a..d, acceptedAnswers join ';') → `validateRows([raw], mediaNames)` → jika error, 400 dengan pesan error pertama.

- [ ] **Step 3: Run tests** → PASS. **Step 4: Commit** — `"feat: admin CRUD for lessons/items with status transitions"`

---

### Task 12: Scaffold `apps/web` + login admin + halaman undangan

**Files:**
- Create: `apps/web/` (repo git baru — Next.js scaffold + Tailwind)
- Create: `apps/web/src/lib/api.ts`, `apps/web/src/app/admin/login/page.tsx`, `apps/web/src/app/admin/layout.tsx`, `apps/web/src/app/invite/[token]/page.tsx`

**Interfaces:**
- Consumes: `POST /auth/login`, `GET /auth/invite/:token`, `POST /auth/accept-invite` (Task 3–4).
- Produces: helper `api(path, opts)` (prefix `NEXT_PUBLIC_API_URL`, sisipkan `Authorization` dari `localStorage.token`, lempar `Error(message)` dari body error API); guard layout `/admin/*` (tanpa token → redirect `/admin/login`, simpan juga `role`; role bukan ADMIN → tolak); halaman `/invite/[token]` (tampilkan nama/email → form password ≥8 → sukses → pesan "Akun aktif. Aplikasi belajar menyusul — tunggu pengumuman." — app user belum ada di Fase 1). Token di localStorage = pilot-grade, diterima sadar; catat sebagai hutang di README repo web.

- [ ] **Step 1: Scaffold**

```bash
cd /Users/alva.e202511001/Desktop/project/english-app/apps
npx --yes create-next-app@15 web --ts --tailwind --eslint --app --src-dir --use-npm --skip-git \
  --import-alias "@/*" --turbopack
cd web && git init -q
echo 'NEXT_PUBLIC_API_URL=http://localhost:3001' > .env.local
```

- [ ] **Step 2: `src/lib/api.ts`**

```ts
export async function api<T = unknown>(path: string, opts: RequestInit = {}): Promise<T> {
  const token = typeof window !== 'undefined' ? localStorage.getItem('token') : null;
  const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}${path}`, {
    ...opts,
    headers: {
      ...(opts.body instanceof FormData ? {} : { 'Content-Type': 'application/json' }),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...opts.headers,
    },
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(Array.isArray(body.message) ? body.message[0] : body.message ?? `HTTP ${res.status}`);
  }
  return res.json();
}
```

- [ ] **Step 3: Login page** (`/admin/login`, client component): form email+password → `api('/auth/login', {method:'POST', body: JSON.stringify(...)})` → jika `role !== 'ADMIN'` tampilkan "Akun ini bukan admin" → simpan `token`+`name` → `router.push('/admin/import')`. Error → tampilkan pesan merah di bawah form.

- [ ] **Step 4: Admin layout** (`/admin/layout.tsx`, client): `useEffect` cek `localStorage.token`, kalau kosong dan path ≠ `/admin/login` → redirect login; sidebar nav: Import Soal · Soal & Lesson · Media · Karyawan; tombol Keluar (hapus token). Copy Indonesia.

- [ ] **Step 5: Invite page** (`/invite/[token]`, client): on-mount `api('/auth/invite/'+token)` → 404 → "Undangan tidak valid atau sudah dipakai."; valid → sapa nama, form password + konfirmasi (cek sama & ≥8 di klien) → `accept-invite` → layar sukses.

- [ ] **Step 6: Verifikasi manual terskrip** — jalankan api (`npm run start:dev`) + web (`npm run dev`): login admin sukses → mendarat di /admin/import (404 halaman belum ada itu OK, guard jalan); login password salah → pesan; buka /invite/token-ngawur → pesan tidak valid. **Step 7: Commit (repo web)** — `"feat: scaffold admin shell (login, guard, invite page)"`

---

### Task 13: Web admin — halaman Import Soal, Media, Karyawan

**Files:**
- Create: `apps/web/src/app/admin/import/page.tsx`, `apps/web/src/app/admin/media/page.tsx`, `apps/web/src/app/admin/users/page.tsx`, `apps/web/src/lib/csv.ts`

**Interfaces:**
- Consumes: `POST /admin/import/questions` (Task 9), `POST/GET /admin/media` (Task 6), `POST /admin/users/import` + `GET /admin/users` (Task 5).
- Produces: tiga halaman admin fungsional. `csv.ts` ekspor `downloadCsv(filename: string, rows: Record<string,string|number>[])` (bangun string CSV ber-BOM, trigger `<a download>`).

- [ ] **Step 1: `csv.ts`**

```ts
export function downloadCsv(filename: string, rows: Record<string, string | number>[]) {
  if (!rows.length) return;
  const headers = Object.keys(rows[0]);
  const esc = (v: string | number) => `"${String(v).replaceAll('"', '""')}"`;
  const csv = [headers.join(','), ...rows.map((r) => headers.map((h) => esc(r[h])).join(','))].join('\n');
  const url = URL.createObjectURL(new Blob(['﻿' + csv], { type: 'text/csv' }));
  const a = Object.assign(document.createElement('a'), { href: url, download: filename });
  a.click(); URL.revokeObjectURL(url);
}
```

- [ ] **Step 2: Halaman Import Soal** — input file .xlsx → `FormData` → POST → tampilkan kartu hasil (`lessonsCreated`, `itemsCreated/Updated`, `skippedRows`) + tabel `errors` (baris · kolom · pesan, merah) + tombol **"Unduh laporan error (CSV)"** → `downloadCsv('laporan-error-import.csv', errors)`. State loading saat upload.

- [ ] **Step 3: Halaman Media** — multi-file input → POST `/admin/media` (FormData `files`) → tampilkan `saved` (hijau) & `rejected` dengan alasan (merah); di bawahnya tabel `GET /admin/media` (nama · ukuran KB) dengan tombol muat-ulang.

- [ ] **Step 4: Halaman Karyawan** — upload CSV (`nama,email`) → hasil `{created, skipped, errors}` + tabel `invites` (nama · email · inviteUrl + tombol salin per baris) + **"Unduh semua link undangan (CSV)"** via `downloadCsv` — inilah yang dibagikan HR ke karyawan; di bawah: tabel `GET /admin/users` (nama · email · status undangan).

- [ ] **Step 5: Verifikasi manual terskrip** — end-to-end nyata: upload `template-soal-v1.xlsx` hasil Task 10 → lihat 1 error media_file di tabel → buka halaman Media → upload file mp3 apa pun bernama `audio_001.mp3` → import ulang → 0 error, 5 item terimpor. Upload CSV 2 karyawan → salin inviteUrl → buka di tab lain → set password → sukses. **Step 6: Commit** — `"feat: admin pages for question import, media, employees"`

---

### Task 14: Web admin — tabel Soal & Lesson + form edit + status

**Files:**
- Create: `apps/web/src/app/admin/content/page.tsx`, `apps/web/src/app/admin/content/[lessonId]/page.tsx`

**Interfaces:**
- Consumes: endpoint CRUD Task 11.
- Produces: halaman daftar lesson (filter level & status; kolom: kode · judul · topic · level/cefr · skill · jumlah soal · status · aksi) dengan tombol status per lesson (Terbitkan [DRAFT→LIVE] / Tarik [LIVE→DRAFT] / Pensiunkan [LIVE→RETIRED, dengan `confirm()` "Soal pensiun tidak bisa dihidupkan lagi. Lanjut?"]); halaman detail lesson: tabel item urut `order` (prompt terpotong 80 char · type · status) → klik baris → form edit sesuai tipe (pilihan_ganda: 4 opsi + radio kunci; isian: prompt + accepted_answers textarea; susun_kalimat: kalimat jawaban) + explanation + media_file + passage → PATCH; error 400 dari API tampil apa adanya (pesannya sudah Indonesia dari Task 11). Tombol status per item, aturan sama.

- [ ] **Step 1: Halaman daftar lesson** (client; fetch `GET /admin/lessons`, filter via query state).
- [ ] **Step 2: Halaman detail + form edit per tipe** (state form di-init dari item terpilih; simpan → PATCH → refresh list; disable tombol saat menyimpan).
- [ ] **Step 3: Verifikasi manual terskrip** — dari data import Task 13: terbitkan lesson TST/BUS → status berubah; edit satu explanation → tersimpan; coba kosongkan option_b → pesan error validasi muncul; pensiunkan satu item LIVE → hilang dari... tetap tampil dengan badge RETIRED (bukan hilang). **Step 4: Commit** — `"feat: content management pages (lessons/items, edit, status)"`

---

### Task 15: Deploy + backup harian + driver S3

**Files:**
- Create: `apps/api/Dockerfile`, `apps/web/Dockerfile`
- Create: `apps/api/src/storage/s3.storage.ts` (implementasi kedua `StorageService`)
- Create (workspace): `infra/docker-compose.prod.yml`, `infra/backup.sh`, `infra/README.md`

**Interfaces:**
- Consumes: semua service jalan lokal.
- Produces: stack produksi satu VPS: `docker compose -f infra/docker-compose.prod.yml up -d` menjalankan postgres + api + web + caddy (TLS otomatis); backup harian `pg_dump` → gzip → object storage, retensi 30 hari; `STORAGE_DRIVER=s3` mengalihkan media ke bucket S3-compatible (R2) tanpa mengubah kode pemakai `StorageService`.

- [ ] **Step 1: Dockerfile api** (multi-stage node:22-alpine: install → `prisma generate` → build → runtime `node dist/main.js`; jalankan `prisma migrate deploy` sebagai entrypoint step). **Dockerfile web** (multi-stage, `next build` → `next start`).

- [ ] **Step 2: S3 driver.** `npm i @aws-sdk/client-s3`. `s3.storage.ts` mengimplementasikan interface yang sama (`put/exists/listNames/stat/getUrl`) via `PutObjectCommand/HeadObjectCommand/ListObjectsV2Command`; `getUrl` → `${S3_PUBLIC_URL}/${name}`. Provider di `storage.module.ts`:

```ts
{ provide: StorageService,
  useClass: process.env.STORAGE_DRIVER === 's3' ? S3StorageService : LocalStorageService }
```
(refactor: rename kelas Task 6 jadi `LocalStorageService`, `StorageService` jadi abstract class/token). Test media Task 6 tetap PASS dengan driver local.

- [ ] **Step 3: `infra/docker-compose.prod.yml`** — services: `db` (postgres:16, volume, healthcheck), `api` (build ../apps/api, env dari `.env.prod`, depends_on db healthy), `web` (build ../apps/web), `caddy` (caddy:2, Caddyfile reverse-proxy `app.DOMAIN` → web:3000, `api.DOMAIN` → api:3001, volume sertifikat).

- [ ] **Step 4: `infra/backup.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
STAMP=$(date +%F)
docker compose -f "$(dirname "$0")/docker-compose.prod.yml" exec -T db \
  pg_dump -U app english_app | gzip > "/var/backups/english-app-$STAMP.sql.gz"
# unggah ke bucket (rclone/aws-cli, kredensial di env VPS)
aws s3 cp "/var/backups/english-app-$STAMP.sql.gz" "s3://$BACKUP_BUCKET/db/" --endpoint-url "$S3_ENDPOINT"
find /var/backups -name 'english-app-*.sql.gz' -mtime +30 -delete
```

Crontab (didokumentasikan di `infra/README.md`, dipasang manual di VPS): `0 2 * * * /opt/english-app/infra/backup.sh`. **Catatan: ini cron OS untuk backup infra — bukan background job aplikasi; batasan "tanpa cron" di spec berlaku untuk logika produk.**

- [ ] **Step 5: `infra/README.md`** — runbook: provisioning VPS, env yang wajib diisi, perintah deploy, perintah restore backup (`gunzip | psql`), cara rotasi `JWT_SECRET`. **Uji restore sekali** ke database kosong lokal — backup yang belum pernah di-restore bukan backup.

- [ ] **Step 6: Commit** — repo api: `"feat: dockerfile + s3 storage driver"`; repo web: `"chore: dockerfile"`; workspace: `"infra: prod compose, caddy, daily backup + runbook"`

---

## Self-Review (sudah dijalankan)

- **Spec coverage Fase 1:** repos ✓(1,12) · skema 10 tabel ✓(2) · auth+undangan ✓(3,4) · CSV karyawan ✓(5,13) · media ✓(6,13) · template+petunjuk ✓(10) · importer+laporan error ✓(7–9,13) · CRUD+lifecycle ✓(11,14) · deploy+backup ✓(15). Di luar cakupan fase ini (sesuai rencana): session engine, XP/streak, dashboard, app user — Fase 2+.
- **Gap yang ditemukan & ditutup saat review:** urutan lesson tidak ada di template → keputusan "urutan kemunculan, editable" ditulis di Global Constraints; halaman invite butuh rumah sebelum app user ada → pesan tunggu di Task 12; template harus terbukti lolos importer sendiri → test round-trip Task 10 Step 3.
- **Type consistency:** `NormalizedRow` (7) = input upsert (8); nama guard/decorator (3) dipakai konsisten di 5,6,9,11; `StorageService` (6) di-refactor jadi token di 15 dengan interface tak berubah; `ImportResult` (8) = kontrak endpoint (9) = UI (13).
