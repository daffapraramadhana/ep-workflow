# Menu Modul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menu **Modul** — bab bacaan pendek (Markdown → blok bertipe, di-parse BE) yang ditutup kuis memakai mesin sesi yang ada; dihitung ke target harian/streak; dikelola admin lewat editor Markdown + pratinjau; modul pertama "Making & Handling Complaints" memakai CMP-201..211.

**Architecture:** 2 tabel baru (`Module`, `ModuleChapter`) + `SessionKind.MODULE` + `Session.moduleChapterId`. Parser murni `parseChapter()` (markdown-it) dipakai simpan, pratinjau, dan seeder. Kuis bab = `Lesson` biasa yang ditautkan (`ModuleChapter.lessonId` unik); lesson tertaut dikecualikan dari jalur harian lewat satu filter bersama `PATH_LESSON`; jenis sesi yang dihitung disatukan di `COUNTED_SESSION_KINDS`. Web: tab ke-3 Modul (3 halaman user) + 3 halaman admin, satu komponen render blok dipakai keduanya.

**Tech Stack:** NestJS 11 + Prisma 6 + Postgres (apps/api, jest unit + e2e supertest) · Next.js 15 + React 19 + Tailwind 4 + lucide-react (apps/web, tanpa test runner — verifikasi via `tsc`, lint, preview browser) · lib baru: `markdown-it` + `@types/markdown-it` (api saja).

**Spec:** `docs/superpowers/specs/2026-10-14-menu-modul-design.md` (baca dulu — plan ini berargumen dari sana). Mockup: `.superpowers/brainstorm/modul/modul-mockup.html` (user) dan `modul-admin-mockup.html` (admin).

## Global Constraints

- Tiga repo terpisah: kode api di-commit di `apps/api`, kode web di `apps/web`, docs di root workspace. Jangan pernah `git add apps/...` dari root.
- Fondasi tak boleh dilanggar: attempt dicatat selamanya; akurasi = percobaan pertama; konten `RETIRED` tak pernah dihapus; semua logika di BE (FE hanya render); angka XP dari tabel `config`; tanpa cron/background job.
- Status konten: `DRAFT → LIVE`, `LIVE → DRAFT | RETIRED`, `RETIRED → (tidak ada)` — pakai `ContentService.assertTransition`.
- Teks UI berbahasa Indonesia; istilah: "Modul", "Bab", "Bacaan", "Kuis bab". Ikon Lucide `strokeWidth 2.25` (kecuali ikon dekoratif 1.8 yang sudah ada polanya). Ikon tab Modul: `BookOpenText`.
- Pesan error parse: `Baris N: <pesan>` (N = nomor baris 1-based di body Markdown).
- TTS contoh: Web Speech API, `lang = 'en-US'`, `rate = 0.85` — tanpa asset audio.
- Lesson kuis bab buatan admin: code `MOD-<SLUG-UPPER>-<order>` (suffix `-2`, `-3`… bila bentrok), skill `VOCABULARY`, status `DRAFT`.
- Kuis bab "tersedia" ⇔ lesson tertaut berstatus `LIVE` **dan** punya ≥1 item `LIVE` (penegasan spec §5.2: lesson DRAFT/RETIRED diperlakukan sama dengan 0 item LIVE → bab Bacaan).
- `prisma` tetap di `dependencies` api (jangan "dirapikan").

## Review Focus

1. **Lesson CMP yang sudah dituntaskan user lewat Perjalanan** sebelum ditautkan → bab langsung ✓ dan kuisnya membuka sesi `REPLAY` (tanpa bonus, tak menambah target) — bukan MODULE kedua kalinya. Ditest di Task 6.
2. **Body Markdown dari sumber luar yang "hampir benar"** (CRLF Windows, `:::` di tengah teks, fence tak ditutup lalu ada fence lain, baris kosong di dalam blok) → error bernomor baris yang tepat, bukan 500 atau blok hilang diam-diam. Ditest di Task 3.
3. **Admin menaruh `media:` yang belum di-upload** → simpan ditolak dengan nama file; pratinjau menampilkan error yang sama. Ditest di Task 4.
4. **Sesi kuis bab yang ditinggal di tengah lalu dibuka lagi hari yang sama** → resume sesi yang sama (bukan sesi baru) dan tidak mengganggu sesi DAILY yang sedang berjalan. Ditest di Task 6.
5. **Modul/bab yang tidak LIVE dibuka via URL langsung** (link lama, modul ditarik ke DRAFT) → 404 lembut ke daftar modul, termasuk `POST /session/module` → 404. Ditest di Task 5 & 6.

---

## File Structure

**apps/api**
| File | Tanggung jawab |
|---|---|
| `prisma/schema.prisma` (modify) | `Module`, `ModuleChapter`, `SessionKind.MODULE`, `Session.moduleChapterId`, relasi balik di `Lesson` |
| `prisma/migrations/<ts>_menu_modul/` (create via CLI) | migrasi |
| `src/common/content-scope.ts` (create) | `COUNTED_SESSION_KINDS`, `PATH_LESSON` |
| `src/modules/chapter-parser.ts` (+ `.spec.ts`) | `parseChapter(body)` murni: Markdown → `StoredBlock[]` + daftar media, atau error bernomor baris |
| `src/modules/blocks.ts` | tipe `ChapterBlock` (bentuk API) + `resolveBlocks()` (file media → URL) |
| `src/modules/modules.types.ts` | kontrak view user (`ModulesView`, `ModuleDetailView`, `ChapterView`, `ModuleInProgressView`) |
| `src/modules/modules.service.ts` | baca modul untuk user (daftar, detail, bab, in-progress) |
| `src/modules/modules.controller.ts` | `GET /modules…` |
| `src/modules/admin-modules.service.ts` | CRUD modul/bab, pratinjau, kuis bab |
| `src/modules/admin-modules.controller.ts` | `/admin/modules…`, `/admin/chapters…` |
| `src/modules/slug.ts` (+ `.spec.ts`) | `slugify()` |
| `src/modules/modules.module.ts` | wiring |
| `src/session/session.service.ts` (modify) | `completionForLessons()`, `moduleQuiz()`, `view()` + moduleSlug/chapterOrder, filter `PATH_LESSON` |
| `src/session/session.controller.ts`, `session.types.ts`, `answer.service.ts` (modify) | endpoint `POST /session/module`, kind `MODULE`, gate bonus |
| `src/me/summary.service.ts`, `streak.service.ts`, `src/progress/progress.service.ts`, `src/monitoring/monitoring.service.ts`, `src/journey/journey.service.ts` (modify) | ganti filter kind → `COUNTED_SESSION_KINDS`; query lesson + `PATH_LESSON`; summary + `moduleInProgress` |
| `src/content/content.service.ts` (modify) | `listLessons` + `moduleChapter` badge |
| `prisma/seed-module-complaints.ts` (create) | seeder create-only modul Keluhan |
| `test/schema-modul.e2e-spec.ts`, `test/module-scope.e2e-spec.ts`, `test/modules-admin.e2e-spec.ts`, `test/modules-user.e2e-spec.ts`, `test/session-module.e2e-spec.ts` (create) | e2e |

**apps/web**
| File | Tanggung jawab |
|---|---|
| `src/lib/api-types.ts` (modify) | tipe modul + `SessionView.kind/moduleSlug/chapterOrder` + `SummaryView.moduleInProgress` |
| `src/lib/speak.ts` (create) | `canSpeak()`, `speakEn()` (dipakai pembaca bab & AnswerSpeak) |
| `src/lib/modules.ts` (create) | `LEVEL_LABEL`, `coverTone()` |
| `src/components/modules/chapter-blocks.tsx` (create) | render `ChapterBlock[]` (user & pratinjau admin) |
| `src/components/modules/module-cover.tsx` (create) | cover/ikon modul |
| `src/app/(user)/modules/page.tsx`, `[slug]/page.tsx`, `[slug]/[order]/page.tsx` (create) | 3 layar user |
| `src/components/user-nav.tsx`, `src/app/learner.css` (modify) | tab ke-5 + gaya modul |
| `src/components/session/use-session.ts`, `src/app/(user)/session/page.tsx`, `src/components/session/answer-speak.tsx` (modify) | `?module=` + kembali ke modul |
| `src/components/home-content.tsx` (modify) | kartu "Lanjutkan modul" |
| `src/app/admin/layout.tsx` (modify) | menu Modul |
| `src/app/admin/modul/types.ts`, `page.tsx`, `[id]/page.tsx`, `[id]/bab/[chapterId]/page.tsx` (create) | 3 layar admin |
| `src/app/admin/content/page.tsx` (modify) | badge "Kuis modul" |
| `src/app/globals.css` (modify) | gaya editor admin |

---

### Task 0: Preflight

**Files:** tidak ada kode baru.

- [ ] **Step 1: Bereskan pekerjaan yang belum di-commit di apps/api**

`apps/api` punya seeder Complaints yang belum di-commit (`prisma/seed-complaints.ts`, `prisma/seed-audio.ts`, perubahan `package.json`, `prisma/seed-demo.ts`). Tanyakan ke pemilik proyek dulu, lalu bila setuju:

```bash
cd apps/api && git status --short
git add prisma/seed-complaints.ts prisma/seed-audio.ts prisma/seed-demo.ts package.json
git commit -m "feat(content): seeder Complaints at Work (CMP-201..211) + helper audio TTS"
```

- [ ] **Step 2: Pastikan baseline hijau**

```bash
cd apps/api && npm test && npm run test:e2e
cd ../web && npx tsc --noEmit && npm run lint
```
Expected: api 105 unit + 141 e2e PASS (angka dari status terakhir; catat angka aktual), web tanpa error. Bila ada yang merah sebelum mulai, laporkan — jangan lanjut.

- [ ] **Step 3: Pastikan konten Complaints ada di DB dev**

```bash
cd apps/api && npx ts-node -e "import {PrismaClient} from '@prisma/client';const p=new PrismaClient();p.lesson.count({where:{code:{startsWith:'CMP-'}}}).then(n=>{console.log(n);return p.\$disconnect()})"
```
Expected: `11`. Bila `0`, jalankan `npm run seed:complaints`.

---

### Task 1: Schema & migrasi

**Files:**
- Modify: `apps/api/prisma/schema.prisma`
- Create: `apps/api/prisma/migrations/<timestamp>_menu_modul/migration.sql` (via CLI)
- Test: `apps/api/test/schema-modul.e2e-spec.ts`

**Interfaces:**
- Produces: model Prisma `Module`, `ModuleChapter` (unique `moduleId_order`, unique `lessonId`), `SessionKind.MODULE`, `Session.moduleChapterId`, relasi `Lesson.moduleChapter`, `ModuleChapter.sessions`.

- [ ] **Step 1: Tulis test schema yang gagal**

```ts
// apps/api/test/schema-modul.e2e-spec.ts
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';

// Prefix SMD- / smd- milik file ini.
describe('schema menu modul', () => {
  const prisma = new PrismaClient();
  const stamp = Date.now();

  afterAll(async () => {
    await prisma.session.deleteMany({ where: { user: { email: { startsWith: 'smd-' } } } });
    await prisma.moduleChapter.deleteMany({ where: { module: { slug: { startsWith: 'smd-' } } } });
    await prisma.module.deleteMany({ where: { slug: { startsWith: 'smd-' } } });
    await prisma.lesson.deleteMany({ where: { code: { startsWith: 'SMD-' } } });
    await prisma.user.deleteMany({ where: { email: { startsWith: 'smd-' } } });
    await prisma.$disconnect();
  });

  it('modul + bab + lesson tertaut + sesi MODULE tersimpan; lessonId unik', async () => {
    const lesson = await prisma.lesson.create({
      data: { code: `SMD-L-${stamp}`, title: 'L', topic: 'T', level: 'DASAR', cefr: 'A1', skill: 'VOCABULARY', order: 1 },
    });
    const mod = await prisma.module.create({
      data: { slug: `smd-${stamp}`, title: 'M', summary: 'S', level: 'DASAR', cefr: 'A1', order: 1 },
    });
    const ch = await prisma.moduleChapter.create({
      data: { moduleId: mod.id, order: 1, title: 'Bab 1', estMinutes: 5, body: 'Halo', blocks: [], lessonId: lesson.id },
    });
    const user = await prisma.user.create({ data: { name: 'U', email: `smd-${stamp}@ex.com` } });
    const s = await prisma.session.create({
      data: { userId: user.id, date: new Date('2026-10-14'), kind: 'MODULE', moduleChapterId: ch.id },
    });
    expect(s.kind).toBe('MODULE');

    const withRel = await prisma.lesson.findUniqueOrThrow({ where: { id: lesson.id }, include: { moduleChapter: true } });
    expect(withRel.moduleChapter?.id).toBe(ch.id);

    await expect(
      prisma.moduleChapter.create({
        data: { moduleId: mod.id, order: 2, title: 'Bab 2', estMinutes: 5, body: 'x', blocks: [], lessonId: lesson.id },
      }),
    ).rejects.toMatchObject({ code: 'P2002' });

    await expect(
      prisma.moduleChapter.create({
        data: { moduleId: mod.id, order: 1, title: 'Dobel', estMinutes: 5, body: 'x', blocks: [] },
      }),
    ).rejects.toMatchObject({ code: 'P2002' });
  });
});
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `cd apps/api && npx jest --config ./test/jest-e2e.json test/schema-modul.e2e-spec.ts`
Expected: FAIL — TypeScript: `Property 'module' does not exist on type 'PrismaClient'`.

- [ ] **Step 3: Ubah schema**

Di `apps/api/prisma/schema.prisma`:

```prisma
enum SessionKind {
  DAILY
  REPLAY
  SPEAKING
  MODULE
}
```

Tambahkan ke `model Lesson` (setelah `items  Item[]`):

```prisma
  moduleChapter ModuleChapter?
```

Tambahkan ke `model Session` (setelah `xpAwarded`):

```prisma
  moduleChapterId String?
  moduleChapter   ModuleChapter? @relation(fields: [moduleChapterId], references: [id])
```

Tambahkan model baru di akhir file:

```prisma
// Menu Modul (spec 2026-10-14-menu-modul-design.md). Modul = wadah bab
// bacaan; kuis bab = Lesson biasa yang ditautkan (lessonId unik). Tidak ada
// tabel progres — progres diturunkan dari attempt saat request.
model Module {
  id        String @id @default(cuid())
  slug      String @unique
  title     String
  summary   String
  level     Level
  cefr      Cefr
  coverFile String?
  order     Int
  status    ContentStatus @default(DRAFT)
  chapters  ModuleChapter[]
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

model ModuleChapter {
  id         String @id @default(cuid())
  moduleId   String
  module     Module @relation(fields: [moduleId], references: [id])
  order      Int
  title      String
  estMinutes Int
  body       String  // Markdown — sumber kebenaran
  blocks     Json    // hasil parseChapter (cache), selalu sinkron dengan body
  lessonId   String? @unique
  lesson     Lesson? @relation(fields: [lessonId], references: [id])
  sessions   Session[]
  createdAt  DateTime @default(now())
  updatedAt  DateTime @updatedAt
  @@unique([moduleId, order])
}
```

- [ ] **Step 4: Buat migrasi**

Run: `cd apps/api && npx prisma migrate dev --name menu_modul`
Expected: migrasi `…_menu_modul` terbuat & diterapkan, client ter-generate.

- [ ] **Step 5: Jalankan test, pastikan lolos**

Run: `npx jest --config ./test/jest-e2e.json test/schema-modul.e2e-spec.ts`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd apps/api
git add prisma/schema.prisma prisma/migrations test/schema-modul.e2e-spec.ts
git commit -m "feat(modul): schema Module, ModuleChapter, SessionKind MODULE"
```

---

### Task 2: Cakupan bersama — `COUNTED_SESSION_KINDS` & `PATH_LESSON`

Menyatukan ±10 filter `kind: { in: ['DAILY','SPEAKING'] }` dan mengecualikan lesson milik bab dari semua jalur harian. Perilaku lama tidak berubah untuk data tanpa modul.

**Files:**
- Create: `apps/api/src/common/content-scope.ts`
- Modify: `src/me/summary.service.ts:87,184-189` · `src/me/streak.service.ts:105,136` · `src/progress/progress.service.ts:75` · `src/monitoring/monitoring.service.ts:190,224,465,475,645,757,771` · `src/session/session.service.ts:356-360,404-412` · `src/session/answer.service.ts:316` · `src/journey/journey.service.ts:47`
- Test: `apps/api/test/module-scope.e2e-spec.ts`

**Interfaces:**
- Produces: `COUNTED_SESSION_KINDS: SessionKind[]`, `PATH_LESSON: Prisma.LessonWhereInput` dari `src/common/content-scope.ts`.

- [ ] **Step 1: Tulis test e2e yang gagal**

```ts
// apps/api/test/module-scope.e2e-spec.ts
import 'dotenv/config';
import { Test } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import * as bcrypt from 'bcrypt';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { todayWIB } from '../src/common/wib';

// Lesson yang ditautkan ke bab modul TIDAK boleh muncul di jalur harian
// (journey, sesi harian, sesi berbicara, next lesson Beranda), dan sesi
// MODULE COMPLETED dihitung ke target harian. Order negatif supaya lesson
// tes selalu paling depan meski DB dev berisi lesson lain di level ini.
// Prefix MSC- / msc-.
const PASSWORD = 'Password123!';

describe('cakupan modul (PATH_LESSON & COUNTED_SESSION_KINDS)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let token: string;
  let token2: string;
  let userId2: string;
  let pathLessonId: string;
  let moduleLessonId: string;
  let pathItemIds: string[] = [];
  let moduleItemIds: string[] = [];
  const stamp = Date.now();

  const get = (p: string, t: string) =>
    request(app.getHttpServer()).get(p).set('Authorization', `Bearer ${t}`);
  const post = (p: string, t: string, body: object = {}) =>
    request(app.getHttpServer()).post(p).set('Authorization', `Bearer ${t}`).send(body);

  beforeAll(async () => {
    const m = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = m.createNestApplication();
    await app.init();
    prisma = app.get(PrismaService);

    const mk = async (code: string, order: number) => {
      const l = await prisma.lesson.create({
        data: { code: `MSC-${code}-${stamp}`, title: `MSC ${code}`, topic: 'MSC', level: 'MAHIR', cefr: 'C1', skill: 'SPEAKING', order, status: 'LIVE' },
      });
      const a = await prisma.item.create({
        data: { lessonId: l.id, type: 'PILIHAN_GANDA', prompt: 'p', options: ['A', 'B', 'C', 'D'], answerKey: 'A', explanation: 'e', order: 1, status: 'LIVE' },
      });
      const b = await prisma.item.create({
        data: { lessonId: l.id, type: 'UCAPAN', prompt: 'Baca', answerKey: `msc ${code} sentence`, explanation: 'e', order: 2, status: 'LIVE' },
      });
      return { l, ids: [a.id, b.id] };
    };
    const modL = await mk('MOD', -1000);
    const pathL = await mk('PATH', -999);
    moduleLessonId = modL.l.id;
    moduleItemIds = modL.ids;
    pathLessonId = pathL.l.id;
    pathItemIds = pathL.ids;

    const mod = await prisma.module.create({
      data: { slug: `msc-${stamp}`, title: 'MSC Modul', summary: 's', level: 'MAHIR', cefr: 'C1', order: 1, status: 'LIVE' },
    });
    await prisma.moduleChapter.create({
      data: { moduleId: mod.id, order: 1, title: 'Bab', estMinutes: 5, body: 'x', blocks: [], lessonId: moduleLessonId },
    });

    const passwordHash = await bcrypt.hash(PASSWORD, 10);
    const u = await prisma.user.create({
      data: { name: 'MSC', email: `msc-a-${stamp}@ex.com`, role: 'USER', level: 'MAHIR', passwordHash, inviteStatus: 'ACCEPTED', voiceConsentAt: new Date() },
    });
    const u2 = await prisma.user.create({
      data: { name: 'MSC2', email: `msc-b-${stamp}@ex.com`, role: 'USER', level: 'MAHIR', passwordHash, inviteStatus: 'ACCEPTED' },
    });
    userId2 = u2.id;
    const login = async (email: string) =>
      (await request(app.getHttpServer()).post('/auth/login').send({ email, password: PASSWORD }).expect(201)).body.accessToken as string;
    token = await login(u.email);
    token2 = await login(u2.email);
  });

  afterAll(async () => {
    const users = { user: { email: { startsWith: 'msc-' } } };
    await prisma.attempt.deleteMany({ where: users });
    await prisma.sessionItem.deleteMany({ where: { session: users } });
    await prisma.session.deleteMany({ where: users });
    await prisma.reviewQueue.deleteMany({ where: users });
    await prisma.moduleChapter.deleteMany({ where: { module: { slug: { startsWith: 'msc-' } } } });
    await prisma.module.deleteMany({ where: { slug: { startsWith: 'msc-' } } });
    await prisma.item.deleteMany({ where: { lesson: { code: { startsWith: 'MSC-' } } } });
    await prisma.lesson.deleteMany({ where: { code: { startsWith: 'MSC-' } } });
    await prisma.user.deleteMany({ where: { email: { startsWith: 'msc-' } } });
    await app.close();
  });

  it('/journey tidak memuat lesson milik bab', async () => {
    const res = await get('/journey', token).expect(200);
    const ids = res.body.topics.flatMap((t: any) => t.lessons.map((l: any) => l.id));
    expect(ids).toContain(pathLessonId);
    expect(ids).not.toContain(moduleLessonId);
  });

  it('summary.nextLesson = lesson jalur, bukan lesson bab', async () => {
    const res = await get('/me/summary', token).expect(200);
    expect(res.body.nextLesson.id).toBe(pathLessonId);
  });

  it('sesi harian memakai lesson jalur', async () => {
    const res = await post('/session/today', token).expect(201);
    const ids = res.body.items.map((i: any) => i.itemId);
    expect(ids).toEqual(expect.arrayContaining(pathItemIds));
    expect(ids.some((id: string) => moduleItemIds.includes(id))).toBe(false);
  });

  it('sesi berbicara tidak memuat UCAPAN dari lesson bab', async () => {
    const res = await post('/session/speaking', token).expect(201);
    const ids = res.body.items.map((i: any) => i.itemId);
    expect(ids).toContain(pathItemIds[1]);
    expect(ids).not.toContain(moduleItemIds[1]);
  });

  it('sesi MODULE COMPLETED hari ini dihitung ke target harian', async () => {
    await prisma.session.create({
      data: { userId: userId2, date: todayWIB(), kind: 'MODULE', status: 'COMPLETED', completedAt: new Date() },
    });
    const res = await get('/me/summary', token2).expect(200);
    expect(res.body.sessionsCompletedToday).toBe(1);
    expect(res.body.streak).toBeGreaterThanOrEqual(1);
  });
});
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `cd apps/api && npx jest --config ./test/jest-e2e.json test/module-scope.e2e-spec.ts`
Expected: FAIL — journey memuat `moduleLessonId`, nextLesson = lesson bab, `sessionsCompletedToday` = 0.

- [ ] **Step 3: Buat `content-scope.ts`**

```ts
// apps/api/src/common/content-scope.ts
import { Prisma, SessionKind } from '@prisma/client';

/**
 * Jenis sesi yang dihitung ke target harian, streak, dan aktivitas
 * monitoring. REPLAY sengaja tidak (ulangan). Satu sumber — jangan tulis
 * ulang daftar ini di query.
 */
export const COUNTED_SESSION_KINDS: SessionKind[] = ['DAILY', 'SPEAKING', 'MODULE'];

/**
 * Lesson "jalur harian" = lesson yang TIDAK ditautkan ke bab modul. Dipakai
 * di semua query lesson untuk Perjalanan, perakitan sesi harian/berbicara,
 * penguatan, dan hitungan "materi selesai".
 */
export const PATH_LESSON: Prisma.LessonWhereInput = { moduleChapter: { is: null } };
```

- [ ] **Step 4: Ganti semua filter kind yang dihitung**

Di setiap titik berikut, ganti `kind: { in: ['DAILY', 'SPEAKING'] }` → `kind: { in: COUNTED_SESSION_KINDS }` dan tambahkan `import { COUNTED_SESSION_KINDS } from '../common/content-scope';`:
- `src/me/summary.service.ts:87` (count `sessionsCompletedToday`)
- `src/me/streak.service.ts:105` dan `:136`
- `src/progress/progress.service.ts:75`
- `src/monitoring/monitoring.service.ts:190`, `:224`, `:465`, `:475`, `:757`

**JANGAN** ganti `src/me/summary.service.ts:152` (`getOpenSession`) — itu kartu "LANJUTKAN" Beranda yang menekan `POST /session/today`; sesi MODULE tidak boleh muncul di sana. Tambahkan komentar satu baris di atasnya:

```ts
      // Sengaja BUKAN COUNTED_SESSION_KINDS: sesi kuis bab dilanjutkan dari halaman modul.
```

Perbarui komentar di `src/me/streak.service.ts:26` dari `kind:DAILY` menjadi `kind IN COUNTED_SESSION_KINDS`.

Di `src/session/answer.service.ts:316` ganti:

```ts
        if (session.kind === 'DAILY' || session.kind === 'SPEAKING') {
```
menjadi
```ts
        if (COUNTED_SESSION_KINDS.includes(session.kind)) {
```
(+ import `COUNTED_SESSION_KINDS` dari `'../common/content-scope'`).

- [ ] **Step 5: Tambahkan `PATH_LESSON` ke query lesson jalur**

`src/session/session.service.ts` — `lessonCompletionInternal` (baris ±356):
```ts
    const lessons = await db.lesson.findMany({
      where: { level, status: 'LIVE', ...PATH_LESSON },
```
`reinforcementItems` (baris ±409):
```ts
      where: { userId, item: { status: 'LIVE', lesson: PATH_LESSON } },
```
`src/me/summary.service.ts` — `getNextLesson`:
```ts
      where: { level, status: 'LIVE', ...PATH_LESSON },
```
`src/journey/journey.service.ts:47`:
```ts
      where: { level: user.level, status: 'LIVE', ...PATH_LESSON },
```
`src/monitoring/monitoring.service.ts:645`:
```ts
      where: { level: { in: levelsUsed }, status: 'LIVE', ...PATH_LESSON },
```
`src/monitoring/monitoring.service.ts:771`:
```ts
            where: { level: user.level, status: 'LIVE', ...PATH_LESSON },
```
Import `PATH_LESSON` dari `'../common/content-scope'` di tiap file.

- [ ] **Step 6: Jalankan test baru + seluruh suite**

Run: `npx jest --config ./test/jest-e2e.json test/module-scope.e2e-spec.ts && npm test && npm run test:e2e`
Expected: semua PASS (suite lama tak berubah perilaku).

- [ ] **Step 7: Commit**

```bash
git add src/common/content-scope.ts src test/module-scope.e2e-spec.ts
git commit -m "refactor(session): COUNTED_SESSION_KINDS + PATH_LESSON — lesson bab keluar dari jalur harian, sesi MODULE dihitung"
```

---

### Task 3: Parser bab `parseChapter`

**Files:**
- Create: `apps/api/src/modules/chapter-parser.ts`, `apps/api/src/modules/chapter-parser.spec.ts`
- Modify: `apps/api/package.json` (dependency)

**Interfaces:**
- Produces:
```ts
export type Inline = { t: string; b?: true; i?: true; code?: true; href?: string }[];
export type StoredBlock =
  | { type: 'heading'; level: 2 | 3; text: Inline }
  | { type: 'paragraph'; text: Inline }
  | { type: 'list'; ordered: boolean; items: Inline[] }
  | { type: 'table'; head: Inline[]; rows: Inline[][] }
  | { type: 'image'; file: string; alt: string }
  | { type: 'audio'; file: string }
  | { type: 'phrases'; items: { en: string; id: string; note?: string }[] }
  | { type: 'dialog'; lines: { speaker: string; role?: string; side: 'left' | 'right'; text: string }[] }
  | { type: 'tip'; text: Inline[] };
export interface ParseError { line: number; message: string }
export interface MediaRef { file: string; line: number }
export type ParseResult =
  | { ok: true; blocks: StoredBlock[]; media: MediaRef[] }
  | { ok: false; errors: ParseError[] };
export function parseChapter(body: string): ParseResult;
```

- [ ] **Step 1: Pasang dependency**

```bash
cd apps/api && npm install markdown-it@^14 && npm install -D @types/markdown-it@^14
```

- [ ] **Step 2: Tulis test unit yang gagal**

```ts
// apps/api/src/modules/chapter-parser.spec.ts
import { parseChapter } from './chapter-parser';

function ok(body: string) {
  const r = parseChapter(body);
  if (!r.ok) throw new Error(JSON.stringify(r.errors));
  return r;
}
function errs(body: string) {
  const r = parseChapter(body);
  if (r.ok) throw new Error('harusnya gagal');
  return r.errors;
}

describe('parseChapter', () => {
  it('paragraf dengan inline tebal/miring/kode/tautan', () => {
    const { blocks } = ok('Halo **tebal** dan *miring*, `kode`, [link](https://x.id).');
    expect(blocks).toEqual([
      {
        type: 'paragraph',
        text: [
          { t: 'Halo ' },
          { t: 'tebal', b: true },
          { t: ' dan ' },
          { t: 'miring', i: true },
          { t: ', ' },
          { t: 'kode', code: true },
          { t: ', ' },
          { t: 'link', href: 'https://x.id' },
          { t: '.' },
        ],
      },
    ]);
  });

  it('heading: # dan ## → level 2, ### ke bawah → level 3', () => {
    const { blocks } = ok('# A\n\n## B\n\n#### C');
    expect(blocks.map((b) => (b.type === 'heading' ? b.level : 0))).toEqual([2, 2, 3]);
  });

  it('daftar berurut & tidak berurut', () => {
    const { blocks } = ok('- satu\n- dua\n\n1. a\n2. b');
    expect(blocks).toEqual([
      { type: 'list', ordered: false, items: [[{ t: 'satu' }], [{ t: 'dua' }]] },
      { type: 'list', ordered: true, items: [[{ t: 'a' }], [{ t: 'b' }]] },
    ]);
  });

  it('tabel GFM', () => {
    const { blocks } = ok('| Nonformal | Formal |\n|---|---|\n| Fix it. | Could you fix it? |');
    expect(blocks).toEqual([
      {
        type: 'table',
        head: [[{ t: 'Nonformal' }], [{ t: 'Formal' }]],
        rows: [[[{ t: 'Fix it.' }], [{ t: 'Could you fix it?' }]]],
      },
    ]);
  });

  it('gambar & audio dari media: menjadi blok + tercatat di media', () => {
    const r = ok('Teks\n\n![Kantor](media:kantor.png)\n\n![audio](media:sapa.mp3)');
    expect(r.blocks.slice(1)).toEqual([
      { type: 'image', file: 'kantor.png', alt: 'Kantor' },
      { type: 'audio', file: 'sapa.mp3' },
    ]);
    expect(r.media).toEqual([
      { file: 'kantor.png', line: 3 },
      { file: 'sapa.mp3', line: 5 },
    ]);
  });

  it(':::phrases dengan catatan opsional', () => {
    const { blocks } = ok(':::phrases\n- Could you help? | Bisa bantu?\n- Sorry. | Maaf. | santai\n:::');
    expect(blocks).toEqual([
      {
        type: 'phrases',
        items: [
          { en: 'Could you help?', id: 'Bisa bantu?' },
          { en: 'Sorry.', id: 'Maaf.', note: 'santai' },
        ],
      },
    ]);
  });

  it(':::dialog — pembicara pertama kiri, kedua kanan, peran opsional', () => {
    const { blocks } = ok(':::dialog\nRina (Finance): Invoice salah.\nKamu: Maaf, nomornya?\nRina (Finance): INV-1.\n:::');
    expect(blocks).toEqual([
      {
        type: 'dialog',
        lines: [
          { speaker: 'Rina', role: 'Finance', side: 'left', text: 'Invoice salah.' },
          { speaker: 'Kamu', side: 'right', text: 'Maaf, nomornya?' },
          { speaker: 'Rina', role: 'Finance', side: 'left', text: 'INV-1.' },
        ],
      },
    ]);
  });

  it(':::tip berisi paragraf inline', () => {
    const { blocks } = ok(':::tip\nPakai **Could you**.\n:::');
    expect(blocks).toEqual([{ type: 'tip', text: [[{ t: 'Pakai ' }, { t: 'Could you', b: true }, { t: '.' }]] }]);
  });

  it('urutan blok markdown dan directive terjaga', () => {
    const { blocks } = ok('## Frasa\n\n:::tip\nA\n:::\n\nPenutup');
    expect(blocks.map((b) => b.type)).toEqual(['heading', 'tip', 'paragraph']);
  });

  it('CRLF diperlakukan sama dengan LF', () => {
    const { blocks } = ok(':::tip\r\nA\r\n:::\r\n');
    expect(blocks).toEqual([{ type: 'tip', text: [[{ t: 'A' }]] }]);
  });

  it('HTML mentah tidak dirender — tetap teks', () => {
    const { blocks } = ok('<b>x</b>');
    expect(blocks).toEqual([{ type: 'paragraph', text: [{ t: '<b>x</b>' }] }]);
  });

  // --- error bernomor baris ---
  it('body kosong', () => {
    expect(errs('  \n ')).toEqual([{ line: 1, message: 'Isi bab masih kosong' }]);
  });

  it('blok tidak ditutup', () => {
    expect(errs('Intro\n\n:::dialog\nA: hai')).toEqual([
      { line: 3, message: 'Blok ":::dialog" belum ditutup dengan ":::"' },
    ]);
  });

  it('blok tidak ditutup lalu ada blok lain — keduanya dilaporkan dengan benar', () => {
    expect(errs(':::tip\nA\n:::phrases\n- a | b\n:::')).toEqual([
      { line: 1, message: 'Blok ":::tip" belum ditutup dengan ":::"' },
    ]);
  });

  it('penutup tanpa pembuka', () => {
    expect(errs('Teks\n:::')).toEqual([{ line: 2, message: '":::" penutup tanpa blok pembuka' }]);
  });

  it('directive tak dikenal', () => {
    expect(errs(':::quiz\nx\n:::')).toEqual([
      { line: 1, message: 'Blok ":::quiz" tidak dikenal (pakai phrases, dialog, atau tip)' },
    ]);
  });

  it('frasa tanpa | atau sisi kosong', () => {
    expect(errs(':::phrases\n- tanpa pemisah\n- EN |\n:::')).toEqual([
      { line: 2, message: 'Frasa harus berformat "EN | arti"' },
      { line: 3, message: 'Frasa harus berformat "EN | arti"' },
    ]);
  });

  it('dialog tanpa ":" dan pembicara ketiga', () => {
    expect(errs(':::dialog\nA: hai\nB: halo\nbaris rusak\nC: aku\n:::')).toEqual([
      { line: 4, message: 'Baris dialog harus berformat "Nama (peran): teks"' },
      { line: 5, message: 'Dialog maksimal 2 pembicara per blok' },
    ]);
  });

  it('blok directive kosong', () => {
    expect(errs(':::phrases\n\n:::')).toEqual([{ line: 1, message: 'Blok ":::phrases" masih kosong' }]);
  });

  it('tautan non-http(s) ditolak', () => {
    expect(errs('Klik [x](javascript:alert(1))')).toEqual([
      { line: 1, message: 'Tautan harus diawali http:// atau https://' },
    ]);
  });

  it('gambar bukan dari media: ditolak', () => {
    expect(errs('![a](https://x.id/a.png)')).toEqual([
      { line: 1, message: 'Gambar/audio harus dari Media: tulis ![keterangan](media:nama-file)' },
    ]);
  });

  it('format yang belum didukung (kutipan, blok kode, garis)', () => {
    expect(errs('> kutip\n\n```\nkode\n```\n\n---')).toEqual([
      { line: 1, message: 'Format "kutipan" belum didukung di bab' },
      { line: 3, message: 'Format "blok kode" belum didukung di bab' },
      { line: 7, message: 'Format "garis pemisah" belum didukung di bab' },
    ]);
  });

  it('daftar bertingkat ditolak', () => {
    expect(errs('- a\n  - b')).toEqual([{ line: 1, message: 'Daftar bertingkat belum didukung' }]);
  });
});
```

- [ ] **Step 3: Jalankan, pastikan gagal**

Run: `cd apps/api && npx jest src/modules/chapter-parser.spec.ts`
Expected: FAIL — `Cannot find module './chapter-parser'`.

- [ ] **Step 4: Implementasi parser**

```ts
// apps/api/src/modules/chapter-parser.ts
import MarkdownIt from 'markdown-it';

/**
 * Parser bab modul (spec §4). Fungsi MURNI: Markdown → blok bertipe, atau
 * daftar error bernomor baris. Dipakai simpan, pratinjau admin, dan seeder —
 * satu jalur validasi. Keberadaan file media dicek pemanggil (async) lewat
 * `media`.
 *
 * Directive (:::phrases / :::dialog / :::tip) dipotong lebih dulu dengan
 * pemindai baris sendiri — markdown-it-container menutup blok diam-diam di
 * akhir dokumen, padahal kita butuh error "belum ditutup".
 */

export type Inline = { t: string; b?: true; i?: true; code?: true; href?: string }[];

export type StoredBlock =
  | { type: 'heading'; level: 2 | 3; text: Inline }
  | { type: 'paragraph'; text: Inline }
  | { type: 'list'; ordered: boolean; items: Inline[] }
  | { type: 'table'; head: Inline[]; rows: Inline[][] }
  | { type: 'image'; file: string; alt: string }
  | { type: 'audio'; file: string }
  | { type: 'phrases'; items: { en: string; id: string; note?: string }[] }
  | {
      type: 'dialog';
      lines: { speaker: string; role?: string; side: 'left' | 'right'; text: string }[];
    }
  | { type: 'tip'; text: Inline[] };

export interface ParseError {
  line: number;
  message: string;
}
export interface MediaRef {
  file: string;
  line: number;
}
export type ParseResult =
  | { ok: true; blocks: StoredBlock[]; media: MediaRef[] }
  | { ok: false; errors: ParseError[] };

type Token = ReturnType<MarkdownIt['parse']>[number];

const DIRECTIVES = ['phrases', 'dialog', 'tip'];
const AUDIO_EXT = /\.(mp3|m4a|wav|ogg|webm)$/i;
const OPEN_RE = /^:::([A-Za-z][\w-]*)$/;
const DIALOG_RE = /^([^:()]+?)\s*(?:\(([^)]*)\))?\s*:\s*(.+)$/;

const md = new MarkdownIt('default', { html: false, linkify: false, typographer: false });
// Validasi tautan dilakukan di toInline supaya bisa melaporkan nomor baris
// (validateLink bawaan diam-diam membuang tautan javascript:).
md.validateLink = () => true;

const UNSUPPORTED: Record<string, string> = {
  blockquote_open: 'kutipan',
  code_block: 'blok kode',
  fence: 'blok kode',
  hr: 'garis pemisah',
  html_block: 'HTML',
};

interface Ctx {
  blocks: StoredBlock[];
  errors: ParseError[];
  media: MediaRef[];
}

export function parseChapter(body: string): ParseResult {
  const lines = body.replace(/\r\n?/g, '\n').split('\n');
  if (!lines.some((l) => l.trim())) {
    return { ok: false, errors: [{ line: 1, message: 'Isi bab masih kosong' }] };
  }
  const ctx: Ctx = { blocks: [], errors: [], media: [] };

  let mdStart = 0;
  let i = 0;
  while (i < lines.length) {
    const t = lines[i].trim();
    if (t === ':::') {
      ctx.errors.push({ line: i + 1, message: '":::" penutup tanpa blok pembuka' });
      convertMarkdown(lines.slice(mdStart, i), mdStart, ctx);
      i += 1;
      mdStart = i;
      continue;
    }
    const open = OPEN_RE.exec(t);
    if (!open) {
      i += 1;
      continue;
    }
    convertMarkdown(lines.slice(mdStart, i), mdStart, ctx);
    const name = open[1];
    let j = i + 1;
    while (j < lines.length && lines[j].trim() !== ':::' && !OPEN_RE.test(lines[j].trim())) j += 1;
    if (j >= lines.length || lines[j].trim() !== ':::') {
      ctx.errors.push({ line: i + 1, message: `Blok ":::${name}" belum ditutup dengan ":::"` });
      // Bila berhenti karena ada pembuka lain di baris j, blok itu dilewati
      // utuh (sampai penutupnya) — isinya ambigu, satu error sudah cukup.
      const resume = j < lines.length ? nextAfterClose(lines, j) : lines.length;
      i = resume;
      mdStart = resume;
      continue;
    }
    if (!DIRECTIVES.includes(name)) {
      ctx.errors.push({
        line: i + 1,
        message: `Blok ":::${name}" tidak dikenal (pakai phrases, dialog, atau tip)`,
      });
    } else {
      convertDirective(name, lines.slice(i + 1, j), i + 1, ctx);
    }
    i = j + 1;
    mdStart = i;
  }
  convertMarkdown(lines.slice(mdStart), mdStart, ctx);

  if (ctx.errors.length) {
    ctx.errors.sort((a, b) => a.line - b.line);
    return { ok: false, errors: ctx.errors };
  }
  return { ok: true, blocks: ctx.blocks, media: ctx.media };
}

/** Indeks baris setelah penutup ":::" pertama mulai dari `from`, atau akhir. */
function nextAfterClose(lines: string[], from: number): number {
  for (let k = from + 1; k < lines.length; k++) if (lines[k].trim() === ':::') return k + 1;
  return lines.length;
}

/** `fenceLine` = nomor baris (1-based) pembuka `:::name`; isi mulai fenceLine + 1. */
function convertDirective(name: string, content: string[], fenceLine: number, ctx: Ctx) {
  const fenceIdx = fenceLine;
  const rows = content
    .map((text, k) => ({ text: text.trim(), line: fenceIdx + 1 + k }))
    .filter((r) => r.text);
  if (!rows.length) {
    ctx.errors.push({ line: fenceLine, message: `Blok ":::${name}" masih kosong` });
    return;
  }

  if (name === 'phrases') {
    const items: { en: string; id: string; note?: string }[] = [];
    for (const r of rows) {
      const parts = r.text.replace(/^[-*]\s+/, '').split('|').map((p) => p.trim());
      if (parts.length < 2 || !parts[0] || !parts[1]) {
        ctx.errors.push({ line: r.line, message: 'Frasa harus berformat "EN | arti"' });
        continue;
      }
      items.push(parts[2] ? { en: parts[0], id: parts[1], note: parts[2] } : { en: parts[0], id: parts[1] });
    }
    if (items.length) ctx.blocks.push({ type: 'phrases', items });
    return;
  }

  if (name === 'dialog') {
    const sides = new Map<string, 'left' | 'right'>();
    const out: { speaker: string; role?: string; side: 'left' | 'right'; text: string }[] = [];
    for (const r of rows) {
      const m = DIALOG_RE.exec(r.text);
      if (!m) {
        ctx.errors.push({ line: r.line, message: 'Baris dialog harus berformat "Nama (peran): teks"' });
        continue;
      }
      const speaker = m[1].trim();
      const key = speaker.toLowerCase();
      if (!sides.has(key)) {
        if (sides.size >= 2) {
          ctx.errors.push({ line: r.line, message: 'Dialog maksimal 2 pembicara per blok' });
          continue;
        }
        sides.set(key, sides.size === 0 ? 'left' : 'right');
      }
      const role = m[2]?.trim();
      out.push({ speaker, ...(role ? { role } : {}), side: sides.get(key)!, text: m[3].trim() });
    }
    if (out.length) ctx.blocks.push({ type: 'dialog', lines: out });
    return;
  }

  // tip: hanya paragraf
  const tokens = md.parse(content.join('\n'), {});
  const paras: Inline[] = [];
  for (let k = 0; k < tokens.length; k++) {
    const tok = tokens[k];
    if (tok.type === 'paragraph_open') {
      const line = fenceIdx + 1 + (tok.map?.[0] ?? 0);
      paras.push(toInline(tokens[k + 1], line, ctx));
    } else if (tok.level === 0 && !tok.type.endsWith('_close') && tok.type !== 'inline') {
      ctx.errors.push({ line: fenceIdx + 1 + (tok.map?.[0] ?? 0), message: 'Blok tip hanya boleh berisi teks' });
    }
  }
  if (paras.length) ctx.blocks.push({ type: 'tip', text: paras });
}

function convertMarkdown(chunk: string[], offset: number, ctx: Ctx) {
  if (!chunk.some((l) => l.trim())) return;
  const tokens = md.parse(chunk.join('\n'), {});
  const lineOf = (tok: Token) => offset + 1 + (tok.map?.[0] ?? 0);

  for (let k = 0; k < tokens.length; k++) {
    const tok = tokens[k];
    if (tok.level !== 0) continue;

    if (UNSUPPORTED[tok.type]) {
      ctx.errors.push({ line: lineOf(tok), message: `Format "${UNSUPPORTED[tok.type]}" belum didukung di bab` });
      continue;
    }

    if (tok.type === 'heading_open') {
      const level = tok.tag === 'h1' || tok.tag === 'h2' ? 2 : 3;
      ctx.blocks.push({ type: 'heading', level, text: toInline(tokens[k + 1], lineOf(tok), ctx) });
      continue;
    }

    if (tok.type === 'paragraph_open') {
      const inline = tokens[k + 1];
      const kids = (inline.children ?? []).filter((c) => !(c.type === 'text' && !c.content.trim()));
      if (kids.length === 1 && kids[0].type === 'image') {
        const img = kids[0];
        const src = img.attrGet('src') ?? '';
        if (!src.startsWith('media:') || src.length <= 6) {
          ctx.errors.push({
            line: lineOf(tok),
            message: 'Gambar/audio harus dari Media: tulis ![keterangan](media:nama-file)',
          });
          continue;
        }
        const file = src.slice(6);
        ctx.media.push({ file, line: lineOf(tok) });
        ctx.blocks.push(AUDIO_EXT.test(file) ? { type: 'audio', file } : { type: 'image', file, alt: img.content });
        continue;
      }
      ctx.blocks.push({ type: 'paragraph', text: toInline(inline, lineOf(tok), ctx) });
      continue;
    }

    if (tok.type === 'bullet_list_open' || tok.type === 'ordered_list_open') {
      const closeType = tok.type.replace('_open', '_close');
      const items: Inline[] = [];
      let nested = false;
      let e = k + 1;
      for (; e < tokens.length; e++) {
        const t = tokens[e];
        if (t.type === closeType && t.level === 0) break;
        if ((t.type === 'bullet_list_open' || t.type === 'ordered_list_open') && t.level > 0) nested = true;
        if (t.type === 'inline') items.push(toInline(t, offset + 1 + (t.map?.[0] ?? 0), ctx));
      }
      if (nested) ctx.errors.push({ line: lineOf(tok), message: 'Daftar bertingkat belum didukung' });
      else ctx.blocks.push({ type: 'list', ordered: tok.type === 'ordered_list_open', items });
      k = e;
      continue;
    }

    if (tok.type === 'table_open') {
      const head: Inline[] = [];
      const rows: Inline[][] = [];
      let inHead = false;
      let row: Inline[] = [];
      let e = k + 1;
      for (; e < tokens.length && tokens[e].type !== 'table_close'; e++) {
        const t = tokens[e];
        if (t.type === 'thead_open') inHead = true;
        else if (t.type === 'thead_close') inHead = false;
        else if (t.type === 'tr_open') row = [];
        else if (t.type === 'tr_close' && !inHead) rows.push(row);
        else if (t.type === 'inline') {
          const cell = toInline(t, lineOf(tok), ctx);
          if (inHead) head.push(cell);
          else row.push(cell);
        }
      }
      ctx.blocks.push({ type: 'table', head, rows });
      k = e;
    }
  }
}

function toInline(inline: Token | undefined, line: number, ctx: Ctx): Inline {
  const out: Inline = [];
  let b = false;
  let it = false;
  let href: string | undefined;
  for (const c of inline?.children ?? []) {
    switch (c.type) {
      case 'text':
        if (c.content) out.push({ t: c.content, ...(b ? { b: true } : {}), ...(it ? { i: true } : {}), ...(href ? { href } : {}) });
        break;
      case 'softbreak':
      case 'hardbreak':
        out.push({ t: ' ' });
        break;
      case 'strong_open':
        b = true;
        break;
      case 'strong_close':
        b = false;
        break;
      case 'em_open':
        it = true;
        break;
      case 'em_close':
        it = false;
        break;
      case 'code_inline':
        out.push({ t: c.content, code: true });
        break;
      case 'link_open': {
        const h = c.attrGet('href') ?? '';
        if (!/^https?:\/\//i.test(h)) {
          ctx.errors.push({ line, message: 'Tautan harus diawali http:// atau https://' });
          href = undefined;
        } else href = h;
        break;
      }
      case 'link_close':
        href = undefined;
        break;
      case 'image':
        ctx.errors.push({ line, message: 'Gambar harus berdiri di baris sendiri' });
        break;
      default:
        if (c.content) out.push({ t: c.content });
    }
  }
  return out;
}
```

> Catatan implementer: `nextAfterClose` menangani kasus "blok tak ditutup lalu ada blok lain" (test `blok tidak ditutup lalu ada blok lain`) — blok kedua dilewati utuh agar hanya satu error yang dilaporkan.
>
> Bila `import MarkdownIt from 'markdown-it'` ditolak TypeScript di build CJS (`module: nodenext`), ganti dengan `import MarkdownIt = require('markdown-it');` — perilaku sama.

- [ ] **Step 5: Jalankan test, perbaiki sampai hijau**

Run: `npx jest src/modules/chapter-parser.spec.ts`
Expected: PASS semua. Bila ada kasus gagal karena detail token markdown-it (mis. `map` tabel), sesuaikan implementasi — **jangan** mengubah ekspektasi test kecuali ekspektasinya jelas salah terhadap spec §4.

- [ ] **Step 6: Commit**

```bash
git add package.json package-lock.json src/modules/chapter-parser.ts src/modules/chapter-parser.spec.ts
git commit -m "feat(modul): parser bab Markdown → blok bertipe dengan error bernomor baris"
```

---

### Task 4: API admin modul

**Files:**
- Create: `src/modules/slug.ts`, `src/modules/slug.spec.ts`, `src/modules/blocks.ts`, `src/modules/admin-modules.service.ts`, `src/modules/admin-modules.controller.ts`, `src/modules/modules.module.ts`
- Modify: `src/app.module.ts`, `src/content/content.service.ts` (`listLessons`)
- Test: `test/modules-admin.e2e-spec.ts`

**Interfaces:**
- Consumes: `parseChapter`, `StoredBlock`, `ParseError`, `ParseResult` (Task 3); `ContentService.assertTransition(from, to)`; `StorageService.exists(name)`, `.getUrl(name)`.
- Produces:
```ts
// src/modules/blocks.ts
export type ChapterBlock =
  | Exclude<StoredBlock, { type: 'image' } | { type: 'audio' }>
  | { type: 'image'; url: string; alt: string }
  | { type: 'audio'; url: string };
export function resolveBlocks(blocks: StoredBlock[], storage: StorageService): ChapterBlock[];
// src/modules/slug.ts
export function slugify(s: string): string;
// AdminModulesService (dipakai Task 7 secara tidak langsung lewat parseChapter saja)
// Endpoint (role ADMIN):
//   GET    /admin/modules?level&status → AdminModuleRow[]
//   POST   /admin/modules {title,summary,level,cefr,slug?,coverFile?} → Module
//   POST   /admin/modules/preview {body} → {blocks: ChapterBlock[]} | {errors: ParseError[]}
//   GET    /admin/modules/:id → AdminModuleDetail
//   PATCH  /admin/modules/:id {title?,slug?,summary?,level?,cefr?,coverFile?,order?,status?} → AdminModuleDetail
//   POST   /admin/modules/:id/chapters {title,estMinutes,body} → AdminChapterDetail
//   GET    /admin/chapters/:id → AdminChapterDetail
//   PATCH  /admin/chapters/:id {title?,estMinutes?,body?} → AdminChapterDetail
//   DELETE /admin/chapters/:id → {ok: true}
//   POST   /admin/chapters/:id/move {direction:'up'|'down'} → AdminModuleDetail
//   POST   /admin/chapters/:id/quiz → {lessonId, code}
//   PATCH  /admin/chapters/:id/quiz {lessonId: string|null} → AdminChapterDetail
//   GET    /admin/lessons → tiap baris + moduleChapter: {moduleTitle, order} | null
```

- [ ] **Step 1: Test unit slugify (gagal)**

```ts
// apps/api/src/modules/slug.spec.ts
import { slugify } from './slug';

describe('slugify', () => {
  it.each([
    ['Making & Handling Complaints', 'making-handling-complaints'],
    ['  Écrire des E-mails!  ', 'ecrire-des-e-mails'],
    ['---', ''],
  ])('%s → %s', (input, out) => expect(slugify(input)).toBe(out));

  it('maksimal 60 karakter tanpa tanda hubung di ujung', () => {
    const s = slugify('a'.repeat(59) + ' bcd');
    expect(s.length).toBeLessThanOrEqual(60);
    expect(s.endsWith('-')).toBe(false);
  });
});
```

Run: `npx jest src/modules/slug.spec.ts` → FAIL (module tidak ada).

- [ ] **Step 2: Implementasi slug & blocks**

```ts
// apps/api/src/modules/slug.ts
export function slugify(s: string): string {
  return s
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60)
    .replace(/-+$/, '');
}
```

```ts
// apps/api/src/modules/blocks.ts
import { StorageService } from '../storage/storage.service';
import type { StoredBlock } from './chapter-parser';

/** Bentuk blok yang dikirim ke FE: file media sudah jadi URL publik. */
export type ChapterBlock =
  | Exclude<StoredBlock, { type: 'image' } | { type: 'audio' }>
  | { type: 'image'; url: string; alt: string }
  | { type: 'audio'; url: string };

export function resolveBlocks(blocks: StoredBlock[], storage: StorageService): ChapterBlock[] {
  return blocks.map((b) => {
    if (b.type === 'image') return { type: 'image', url: storage.getUrl(b.file), alt: b.alt };
    if (b.type === 'audio') return { type: 'audio', url: storage.getUrl(b.file) };
    return b;
  });
}
```

Run: `npx jest src/modules/slug.spec.ts` → PASS.

- [ ] **Step 3: Tulis e2e admin yang gagal**

```ts
// apps/api/test/modules-admin.e2e-spec.ts
import 'dotenv/config';
import { Test } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { StorageService } from '../src/storage/storage.service';

// Prefix judul "MAD " → slug mad-…; lesson MAD-… / MOD-MAD-….
describe('admin modul', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let admin: string;
  const stamp = Date.now();
  // Nama tetap: StorageService tak punya delete, jadi fixture ditimpa tiap run, tidak menumpuk.
  const mediaName = 'mad-e2e-fixture.png';

  const req = () => request(app.getHttpServer());
  const auth = (r: request.Test) => r.set('Authorization', `Bearer ${admin}`);

  beforeAll(async () => {
    const m = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = m.createNestApplication();
    await app.init();
    prisma = app.get(PrismaService);
    await app.get(StorageService).put(mediaName, Buffer.from('png'));
    const login = await req().post('/auth/login').send({ email: process.env.ADMIN_EMAIL, password: process.env.ADMIN_PASSWORD }).expect(201);
    admin = login.body.accessToken;
  });

  afterAll(async () => {
    const mods = { module: { slug: { startsWith: 'mad-' } } };
    await prisma.moduleChapter.deleteMany({ where: mods });
    await prisma.module.deleteMany({ where: { slug: { startsWith: 'mad-' } } });
    await prisma.lesson.deleteMany({ where: { OR: [{ code: { startsWith: 'MAD-' } }, { code: { startsWith: 'MOD-MAD-' } }] } });
    await app.close();
  });

  let moduleId: string;
  let ch1: string;
  let ch2: string;

  it('non-admin ditolak', async () => {
    await req().get('/admin/modules').expect(401);
  });

  it('membuat modul: slug otomatis, status DRAFT; slug ganda 409', async () => {
    const res = await auth(req().post('/admin/modules')).send({ title: `MAD ${stamp}`, summary: 'Ringkas', level: 'MENENGAH', cefr: 'B1' }).expect(201);
    moduleId = res.body.id;
    expect(res.body.slug).toBe(`mad-${stamp}`);
    expect(res.body.status).toBe('DRAFT');
    await auth(req().post('/admin/modules')).send({ title: `MAD ${stamp}`, summary: 'x', level: 'MENENGAH', cefr: 'B1' }).expect(409);
    await auth(req().post('/admin/modules')).send({ title: '', summary: 'x', level: 'X', cefr: 'B1' }).expect(400);
  });

  it('pratinjau: valid → blocks, invalid → errors (tanpa menyimpan)', async () => {
    const good = await auth(req().post('/admin/modules/preview')).send({ body: `Halo\n\n![k](media:${mediaName})` }).expect(201);
    expect(good.body.blocks[1]).toEqual({ type: 'image', url: expect.stringContaining(mediaName), alt: 'k' });
    const bad = await auth(req().post('/admin/modules/preview')).send({ body: 'A\n\n![k](media:tidak-ada.png)' }).expect(201);
    expect(bad.body.errors).toEqual([{ line: 3, message: 'File media tidak ditemukan: tidak-ada.png' }]);
  });

  it('membuat bab: Markdown invalid → 400 "Baris N"; valid → blocks tersimpan', async () => {
    const bad = await auth(req().post(`/admin/modules/${moduleId}/chapters`)).send({ title: 'B1', estMinutes: 5, body: ':::tip\nA' }).expect(400);
    expect(bad.body.message[0]).toBe('Baris 1: Blok ":::tip" belum ditutup dengan ":::"');
    expect(await prisma.moduleChapter.count({ where: { moduleId } })).toBe(0);

    const a = await auth(req().post(`/admin/modules/${moduleId}/chapters`)).send({ title: 'Bab satu', estMinutes: 5, body: ':::tip\nA\n:::' }).expect(201);
    const b = await auth(req().post(`/admin/modules/${moduleId}/chapters`)).send({ title: 'Bab dua', estMinutes: 4, body: 'Dua' }).expect(201);
    ch1 = a.body.id;
    ch2 = b.body.id;
    expect(a.body.order).toBe(1);
    expect(b.body.order).toBe(2);
    const row = await prisma.moduleChapter.findUniqueOrThrow({ where: { id: ch1 } });
    expect(row.blocks).toEqual([{ type: 'tip', text: [[{ t: 'A' }]] }]);
  });

  it('mengubah bab memperbarui body & blocks bersamaan', async () => {
    const res = await auth(req().patch(`/admin/chapters/${ch2}`)).send({ body: '## Judul' }).expect(200);
    expect(res.body.body).toBe('## Judul');
    const row = await prisma.moduleChapter.findUniqueOrThrow({ where: { id: ch2 } });
    expect((row.blocks as any[])[0].type).toBe('heading');
  });

  it('memindah urutan bab', async () => {
    const res = await auth(req().post(`/admin/chapters/${ch2}/move`)).send({ direction: 'up' }).expect(201);
    expect(res.body.chapters.map((c: any) => c.id)).toEqual([ch2, ch1]);
    await auth(req().post(`/admin/chapters/${ch2}/move`)).send({ direction: 'up' }).expect(201); // sudah paling atas → no-op
  });

  it('buat kuis → lesson MOD-… DRAFT tertaut; kedua kalinya 409', async () => {
    const res = await auth(req().post(`/admin/chapters/${ch1}/quiz`)).expect(201);
    expect(res.body.code).toBe(`MOD-MAD-${stamp}-2`.toUpperCase()); // ch1 kini order 2
    const lesson = await prisma.lesson.findUniqueOrThrow({ where: { id: res.body.lessonId } });
    expect(lesson.status).toBe('DRAFT');
    expect(lesson.level).toBe('MENENGAH');
    await auth(req().post(`/admin/chapters/${ch1}/quiz`)).expect(409);
  });

  it('tautkan lesson yang ada; lesson milik bab lain 409; lepas tautan', async () => {
    const free = await prisma.lesson.create({ data: { code: `MAD-FREE-${stamp}`, title: 'F', topic: 'T', level: 'MENENGAH', cefr: 'B1', skill: 'GRAMMAR', order: 1 } });
    const linked = await prisma.moduleChapter.findUniqueOrThrow({ where: { id: ch1 } });
    await auth(req().patch(`/admin/chapters/${ch2}/quiz`)).send({ lessonId: linked.lessonId }).expect(409);
    const res = await auth(req().patch(`/admin/chapters/${ch2}/quiz`)).send({ lessonId: free.id }).expect(200);
    expect(res.body.lesson.code).toBe(`MAD-FREE-${stamp}`);
    const un = await auth(req().patch(`/admin/chapters/${ch2}/quiz`)).send({ lessonId: null }).expect(200);
    expect(un.body.lesson).toBeNull();
  });

  it('/admin/lessons memberi badge moduleChapter', async () => {
    const res = await auth(req().get('/admin/lessons')).expect(200);
    const row = res.body.find((l: any) => l.code === `MOD-MAD-${stamp}-2`.toUpperCase());
    expect(row.moduleChapter).toEqual({ moduleTitle: `MAD ${stamp}`, order: 2 });
  });

  it('detail modul: hitungan bab', async () => {
    const list = await auth(req().get('/admin/modules')).expect(200);
    const row = list.body.find((m: any) => m.id === moduleId);
    expect(row).toMatchObject({ chapterCount: 2, quizChapterCount: 0, pendingQuizCount: 1, readingCount: 1 });
  });

  it('status LIVE lalu hapus bab ditolak; DRAFT tanpa sesi boleh', async () => {
    await auth(req().patch(`/admin/modules/${moduleId}`)).send({ status: 'LIVE' }).expect(200);
    await auth(req().delete(`/admin/chapters/${ch2}`)).expect(409);
    await auth(req().patch(`/admin/modules/${moduleId}`)).send({ status: 'DRAFT' }).expect(200);
    await auth(req().delete(`/admin/chapters/${ch2}`)).expect(200);
    await auth(req().patch(`/admin/modules/${moduleId}`)).send({ status: 'RETIRED' }).expect(400); // DRAFT→RETIRED tak diizinkan
  });
});
```

Run: `npx jest --config ./test/jest-e2e.json test/modules-admin.e2e-spec.ts` → FAIL (404 semua route).

- [ ] **Step 4: Implementasi `AdminModulesService`**

```ts
// apps/api/src/modules/admin-modules.service.ts
import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { Cefr, ContentStatus, Level, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { ContentService } from '../content/content.service';
import { parseChapter, ParseError, ParseResult, StoredBlock } from './chapter-parser';
import { ChapterBlock, resolveBlocks } from './blocks';
import { slugify } from './slug';

const LEVELS: Level[] = ['DASAR', 'MENENGAH', 'MAHIR'];
const CEFRS: Cefr[] = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
const STATUSES: ContentStatus[] = ['DRAFT', 'LIVE', 'RETIRED'];

export interface ModuleInput {
  title?: unknown;
  slug?: unknown;
  summary?: unknown;
  level?: unknown;
  cefr?: unknown;
  coverFile?: unknown;
  order?: unknown;
  status?: unknown;
}
export interface ChapterInput {
  title?: unknown;
  estMinutes?: unknown;
  body?: unknown;
}

const lessonSummarySelect = {
  id: true,
  code: true,
  title: true,
  status: true,
  items: { select: { status: true } },
} satisfies Prisma.LessonSelect;

type LessonSummaryRow = Prisma.LessonGetPayload<{ select: typeof lessonSummarySelect }>;

function lessonSummary(l: LessonSummaryRow | null) {
  if (!l) return null;
  return {
    id: l.id,
    code: l.code,
    title: l.title,
    status: l.status,
    liveItemCount: l.items.filter((i) => i.status === 'LIVE').length,
    draftItemCount: l.items.filter((i) => i.status === 'DRAFT').length,
  };
}

function quizAvailable(l: LessonSummaryRow | null): boolean {
  return !!l && l.status === 'LIVE' && l.items.some((i) => i.status === 'LIVE');
}

@Injectable()
export class AdminModulesService {
  constructor(
    private prisma: PrismaService,
    private storage: StorageService,
    private content: ContentService,
  ) {}

  // ---------- parse ----------

  async parseWithMedia(body: unknown): Promise<ParseResult> {
    if (typeof body !== 'string') return { ok: false, errors: [{ line: 1, message: 'Isi bab wajib diisi' }] };
    const r = parseChapter(body);
    if (!r.ok) return r;
    const missing: ParseError[] = [];
    for (const m of r.media) {
      if (!(await this.storage.exists(m.file))) {
        missing.push({ line: m.line, message: `File media tidak ditemukan: ${m.file}` });
      }
    }
    return missing.length ? { ok: false, errors: missing } : r;
  }

  private async parseOrThrow(body: unknown): Promise<StoredBlock[]> {
    const r = await this.parseWithMedia(body);
    if (!r.ok) throw new BadRequestException(r.errors.map((e) => `Baris ${e.line}: ${e.message}`));
    return r.blocks;
  }

  async preview(body: unknown): Promise<{ blocks: ChapterBlock[] } | { errors: ParseError[] }> {
    const r = await this.parseWithMedia(body);
    return r.ok ? { blocks: resolveBlocks(r.blocks, this.storage) } : { errors: r.errors };
  }

  // ---------- modul ----------

  private async cleanModule(dto: ModuleInput, creating: boolean) {
    const data: { title?: string; slug?: string; summary?: string; level?: Level; cefr?: Cefr; coverFile?: string | null; order?: number } = {};
    if (dto.title !== undefined || creating) {
      if (typeof dto.title !== 'string' || !dto.title.trim()) throw new BadRequestException('Judul wajib diisi');
      data.title = dto.title.trim();
    }
    if (dto.summary !== undefined || creating) {
      if (typeof dto.summary !== 'string' || !dto.summary.trim()) throw new BadRequestException('Ringkasan wajib diisi');
      data.summary = dto.summary.trim();
    }
    if (dto.level !== undefined || creating) {
      if (!LEVELS.includes(dto.level as Level)) throw new BadRequestException('Level tidak valid');
      data.level = dto.level as Level;
    }
    if (dto.cefr !== undefined || creating) {
      if (!CEFRS.includes(dto.cefr as Cefr)) throw new BadRequestException('CEFR tidak valid');
      data.cefr = dto.cefr as Cefr;
    }
    if (dto.slug !== undefined) {
      const s = slugify(String(dto.slug ?? ''));
      if (!s) throw new BadRequestException('Slug tidak valid');
      data.slug = s;
    }
    if (dto.coverFile !== undefined) {
      const f = dto.coverFile ? String(dto.coverFile) : null;
      if (f && !(await this.storage.exists(f))) throw new BadRequestException(`File media tidak ditemukan: ${f}`);
      data.coverFile = f;
    }
    if (dto.order !== undefined) {
      if (!Number.isInteger(dto.order)) throw new BadRequestException('Urutan harus bilangan bulat');
      data.order = dto.order as number;
    }
    return data;
  }

  async listModules(query: { level?: string; status?: string }) {
    const modules = await this.prisma.module.findMany({
      where: {
        ...(LEVELS.includes(query.level as Level) ? { level: query.level as Level } : {}),
        ...(STATUSES.includes(query.status as ContentStatus) ? { status: query.status as ContentStatus } : {}),
      },
      orderBy: { order: 'asc' },
      include: { chapters: { select: { lesson: { select: lessonSummarySelect } } } },
    });
    return modules.map((m) => {
      const withLesson = m.chapters.filter((c) => c.lesson).length;
      const quiz = m.chapters.filter((c) => quizAvailable(c.lesson)).length;
      return {
        id: m.id,
        slug: m.slug,
        title: m.title,
        level: m.level,
        cefr: m.cefr,
        status: m.status,
        order: m.order,
        updatedAt: m.updatedAt,
        chapterCount: m.chapters.length,
        quizChapterCount: quiz,
        pendingQuizCount: withLesson - quiz,
        readingCount: m.chapters.length - withLesson,
      };
    });
  }

  async createModule(dto: ModuleInput) {
    const data = await this.cleanModule(dto, true);
    const slug = data.slug ?? slugify(data.title!);
    if (!slug) throw new BadRequestException('Slug tidak valid');
    if (await this.prisma.module.findUnique({ where: { slug } })) {
      throw new ConflictException(`Slug "${slug}" sudah dipakai modul lain`);
    }
    const max = await this.prisma.module.aggregate({ _max: { order: true } });
    return this.prisma.module.create({
      data: {
        title: data.title!,
        summary: data.summary!,
        level: data.level!,
        cefr: data.cefr!,
        coverFile: data.coverFile ?? null,
        slug,
        order: data.order ?? (max._max.order ?? 0) + 1,
      },
    });
  }

  async getModule(id: string) {
    const m = await this.prisma.module.findUnique({
      where: { id },
      include: {
        chapters: {
          orderBy: { order: 'asc' },
          select: { id: true, order: true, title: true, estMinutes: true, lesson: { select: lessonSummarySelect } },
        },
      },
    });
    if (!m) throw new NotFoundException();
    return {
      id: m.id,
      slug: m.slug,
      title: m.title,
      summary: m.summary,
      level: m.level,
      cefr: m.cefr,
      coverFile: m.coverFile,
      coverUrl: m.coverFile ? this.storage.getUrl(m.coverFile) : null,
      order: m.order,
      status: m.status,
      chapters: m.chapters.map((c) => ({
        id: c.id,
        order: c.order,
        title: c.title,
        estMinutes: c.estMinutes,
        lesson: lessonSummary(c.lesson),
      })),
    };
  }

  async updateModule(id: string, dto: ModuleInput) {
    const current = await this.prisma.module.findUnique({ where: { id } });
    if (!current) throw new NotFoundException();
    const data = await this.cleanModule(dto, false);
    let status: ContentStatus | undefined;
    if (dto.status !== undefined) {
      if (!STATUSES.includes(dto.status as ContentStatus)) throw new BadRequestException('Status tidak valid');
      this.content.assertTransition(current.status, dto.status as string);
      status = dto.status as ContentStatus;
    }
    if (data.slug && data.slug !== current.slug && (await this.prisma.module.findUnique({ where: { slug: data.slug } }))) {
      throw new ConflictException(`Slug "${data.slug}" sudah dipakai modul lain`);
    }
    await this.prisma.module.update({ where: { id }, data: { ...data, ...(status ? { status } : {}) } });
    return this.getModule(id);
  }

  // ---------- bab ----------

  private async cleanChapter(dto: ChapterInput, creating: boolean) {
    const data: { title?: string; estMinutes?: number; body?: string; blocks?: Prisma.InputJsonValue } = {};
    if (dto.title !== undefined || creating) {
      if (typeof dto.title !== 'string' || !dto.title.trim()) throw new BadRequestException('Judul bab wajib diisi');
      data.title = dto.title.trim();
    }
    if (dto.estMinutes !== undefined || creating) {
      const n = dto.estMinutes;
      if (!Number.isInteger(n) || (n as number) < 1 || (n as number) > 60) {
        throw new BadRequestException('Estimasi menit harus 1–60');
      }
      data.estMinutes = n as number;
    }
    if (dto.body !== undefined || creating) {
      data.blocks = (await this.parseOrThrow(dto.body)) as unknown as Prisma.InputJsonValue;
      data.body = (dto.body as string).replace(/\r\n?/g, '\n');
    }
    return data;
  }

  async getChapter(id: string) {
    const c = await this.prisma.moduleChapter.findUnique({
      where: { id },
      include: { module: { select: { id: true, title: true, slug: true, status: true } }, lesson: { select: lessonSummarySelect } },
    });
    if (!c) throw new NotFoundException();
    return {
      id: c.id,
      order: c.order,
      title: c.title,
      estMinutes: c.estMinutes,
      body: c.body,
      blocks: resolveBlocks(c.blocks as unknown as StoredBlock[], this.storage),
      module: c.module,
      lesson: lessonSummary(c.lesson),
    };
  }

  async createChapter(moduleId: string, dto: ChapterInput) {
    if (!(await this.prisma.module.findUnique({ where: { id: moduleId } }))) throw new NotFoundException();
    const data = await this.cleanChapter(dto, true);
    const max = await this.prisma.moduleChapter.aggregate({ where: { moduleId }, _max: { order: true } });
    const c = await this.prisma.moduleChapter.create({
      data: {
        moduleId,
        order: (max._max.order ?? 0) + 1,
        title: data.title!,
        estMinutes: data.estMinutes!,
        body: data.body!,
        blocks: data.blocks!,
      },
    });
    return this.getChapter(c.id);
  }

  async updateChapter(id: string, dto: ChapterInput) {
    if (!(await this.prisma.moduleChapter.findUnique({ where: { id } }))) throw new NotFoundException();
    const data = await this.cleanChapter(dto, false);
    await this.prisma.moduleChapter.update({ where: { id }, data });
    return this.getChapter(id);
  }

  async deleteChapter(id: string) {
    const c = await this.prisma.moduleChapter.findUnique({
      where: { id },
      include: { module: true, _count: { select: { sessions: true } } },
    });
    if (!c) throw new NotFoundException();
    if (c.module.status !== 'DRAFT' || c._count.sessions > 0) {
      throw new ConflictException('Bab hanya bisa dihapus selama modul DRAFT dan belum pernah dikerjakan');
    }
    await this.prisma.moduleChapter.delete({ where: { id } });
    return { ok: true };
  }

  async moveChapter(id: string, direction: unknown) {
    if (direction !== 'up' && direction !== 'down') throw new BadRequestException('direction harus up atau down');
    const c = await this.prisma.moduleChapter.findUnique({ where: { id } });
    if (!c) throw new NotFoundException();
    await this.prisma.$transaction(async (tx) => {
      const neighbor = await tx.moduleChapter.findFirst({
        where: { moduleId: c.moduleId, order: direction === 'up' ? { lt: c.order } : { gt: c.order } },
        orderBy: { order: direction === 'up' ? 'desc' : 'asc' },
      });
      if (!neighbor) return;
      // @@unique([moduleId, order]) — tukar lewat nilai sementara.
      await tx.moduleChapter.update({ where: { id: c.id }, data: { order: -1 } });
      await tx.moduleChapter.update({ where: { id: neighbor.id }, data: { order: c.order } });
      await tx.moduleChapter.update({ where: { id: c.id }, data: { order: neighbor.order } });
    });
    return this.getModule(c.moduleId);
  }

  // ---------- kuis bab ----------

  async createQuiz(chapterId: string) {
    const c = await this.prisma.moduleChapter.findUnique({ where: { id: chapterId }, include: { module: true } });
    if (!c) throw new NotFoundException();
    if (c.lessonId) throw new ConflictException('Bab ini sudah punya kuis');
    const base = `MOD-${c.module.slug.toUpperCase()}-${c.order}`;
    let code = base;
    for (let n = 2; await this.prisma.lesson.findUnique({ where: { code } }); n++) code = `${base}-${n}`;
    const maxOrder = await this.prisma.lesson.aggregate({ where: { level: c.module.level }, _max: { order: true } });
    const lesson = await this.prisma.$transaction(async (tx) => {
      const l = await tx.lesson.create({
        data: {
          code,
          title: c.title,
          topic: c.module.title,
          level: c.module.level,
          cefr: c.module.cefr,
          skill: 'VOCABULARY',
          order: (maxOrder._max.order ?? 0) + 1,
          status: 'DRAFT',
        },
      });
      await tx.moduleChapter.update({ where: { id: chapterId }, data: { lessonId: l.id } });
      return l;
    });
    return { lessonId: lesson.id, code: lesson.code };
  }

  async linkQuiz(chapterId: string, lessonId: unknown) {
    const c = await this.prisma.moduleChapter.findUnique({ where: { id: chapterId } });
    if (!c) throw new NotFoundException();
    if (lessonId === null) {
      await this.prisma.moduleChapter.update({ where: { id: chapterId }, data: { lessonId: null } });
      return this.getChapter(chapterId);
    }
    if (typeof lessonId !== 'string') throw new BadRequestException('lessonId wajib diisi');
    const lesson = await this.prisma.lesson.findUnique({ where: { id: lessonId }, include: { moduleChapter: true } });
    if (!lesson) throw new NotFoundException('Lesson tidak ditemukan');
    if (lesson.moduleChapter && lesson.moduleChapter.id !== chapterId) {
      throw new ConflictException('Lesson ini sudah dipakai bab lain');
    }
    await this.prisma.moduleChapter.update({ where: { id: chapterId }, data: { lessonId } });
    return this.getChapter(chapterId);
  }
}
```

- [ ] **Step 5: Controller, module, wiring**

```ts
// apps/api/src/modules/admin-modules.controller.ts
import { Body, Controller, Delete, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { AdminModulesService } from './admin-modules.service';
import type { ChapterInput, ModuleInput } from './admin-modules.service';

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
export class AdminModulesController {
  constructor(private svc: AdminModulesService) {}

  @Get('modules')
  list(@Query() q: { level?: string; status?: string }) {
    return this.svc.listModules(q);
  }

  @Post('modules')
  create(@Body() dto: ModuleInput) {
    return this.svc.createModule(dto);
  }

  @Post('modules/preview')
  preview(@Body('body') body: unknown) {
    return this.svc.preview(body);
  }

  @Get('modules/:id')
  get(@Param('id') id: string) {
    return this.svc.getModule(id);
  }

  @Patch('modules/:id')
  update(@Param('id') id: string, @Body() dto: ModuleInput) {
    return this.svc.updateModule(id, dto);
  }

  @Post('modules/:id/chapters')
  createChapter(@Param('id') id: string, @Body() dto: ChapterInput) {
    return this.svc.createChapter(id, dto);
  }

  @Get('chapters/:id')
  getChapter(@Param('id') id: string) {
    return this.svc.getChapter(id);
  }

  @Patch('chapters/:id')
  updateChapter(@Param('id') id: string, @Body() dto: ChapterInput) {
    return this.svc.updateChapter(id, dto);
  }

  @Delete('chapters/:id')
  deleteChapter(@Param('id') id: string) {
    return this.svc.deleteChapter(id);
  }

  @Post('chapters/:id/move')
  move(@Param('id') id: string, @Body('direction') direction: unknown) {
    return this.svc.moveChapter(id, direction);
  }

  @Post('chapters/:id/quiz')
  createQuiz(@Param('id') id: string) {
    return this.svc.createQuiz(id);
  }

  @Patch('chapters/:id/quiz')
  linkQuiz(@Param('id') id: string, @Body('lessonId') lessonId: unknown) {
    return this.svc.linkQuiz(id, lessonId);
  }
}
```

```ts
// apps/api/src/modules/modules.module.ts
import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { ContentModule } from '../content/content.module';
import { AdminModulesController } from './admin-modules.controller';
import { AdminModulesService } from './admin-modules.service';

@Module({
  imports: [AuthModule, ContentModule],
  controllers: [AdminModulesController],
  providers: [AdminModulesService],
})
export class ModulesModule {}
```

Di `src/app.module.ts` tambahkan `import { ModulesModule } from './modules/modules.module';` dan `ModulesModule` di array `imports` (setelah `VoiceConversationModule`).

- [ ] **Step 6: Badge di `/admin/lessons`**

Di `src/content/content.service.ts`:
- `LessonListItem` + `moduleChapter: { moduleTitle: string; order: number } | null;`
- `listLessons` → `include: { items: { select: { status: true } }, moduleChapter: { select: { order: true, module: { select: { title: true } } } } },`
- map → `moduleChapter: l.moduleChapter ? { moduleTitle: l.moduleChapter.module.title, order: l.moduleChapter.order } : null,`

- [ ] **Step 7: Jalankan test**

Run: `npx jest --config ./test/jest-e2e.json test/modules-admin.e2e-spec.ts && npx jest --config ./test/jest-e2e.json test/content-crud.e2e-spec.ts && npm test`
Expected: PASS.

> Catatan: `POST` di Nest mengembalikan 201 (termasuk `preview` & `move`) — test sudah memakai 201.

- [ ] **Step 8: Commit**

```bash
git add src/modules src/app.module.ts src/content/content.service.ts test/modules-admin.e2e-spec.ts
git commit -m "feat(modul): API admin — CRUD modul/bab, pratinjau, urutan, kuis bab, badge lesson"
```

---

### Task 5: API user modul + `moduleInProgress` di summary

**Files:**
- Create: `src/modules/modules.types.ts`, `src/modules/modules.service.ts`, `src/modules/modules.controller.ts`
- Modify: `src/session/session.service.ts` (helper `completionForLessons`), `src/modules/modules.module.ts`, `src/me/me.module.ts`, `src/me/summary.service.ts`
- Test: `test/modules-user.e2e-spec.ts`

**Interfaces:**
- Consumes: `resolveBlocks`, `StoredBlock`; `AppConfigService.getInt('XP_FIRST_TRY' | 'XP_SESSION_COMPLETE' | 'XP_PERFECT_SESSION')`.
- Produces:
```ts
// SessionService (public)
export interface LessonProgress { liveItemCount: number; done: boolean; accuracy: number | null }
completionForLessons(userId: string, lessonIds: string[], db?: Db): Promise<Map<string, LessonProgress>>;
// ModulesService (exported dari ModulesModule)
list(userId): Promise<ModulesView>; detail(userId, slug): Promise<ModuleDetailView>;
chapter(userId, slug, order: string): Promise<ChapterView>; inProgressSummary(userId): Promise<ModuleInProgressView | null>;
// SummaryView + moduleInProgress: ModuleInProgressView | null
```

- [ ] **Step 1: Tulis e2e yang gagal**

```ts
// apps/api/test/modules-user.e2e-spec.ts
import 'dotenv/config';
import { Test } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import * as bcrypt from 'bcrypt';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { parseChapter } from '../src/modules/chapter-parser';

// Prefix MUS- / mus-.
const PASSWORD = 'Password123!';

describe('modul untuk user', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let token: string;
  let userId: string;
  const stamp = Date.now();
  const slugA = `mus-a-${stamp}`; // MAHIR, 3 bab: kuis (sudah tuntas), kuis (belum), bacaan
  const slugB = `mus-b-${stamp}`; // DASAR
  const slugDraft = `mus-d-${stamp}`;
  const slugEmpty = `mus-e-${stamp}`; // LIVE tanpa bab
  let doneItemId: string;

  const get = (p: string) => request(app.getHttpServer()).get(p).set('Authorization', `Bearer ${token}`);
  const blocks = (body: string) => {
    const r = parseChapter(body);
    if (!r.ok) throw new Error('fixture invalid');
    return r.blocks as any;
  };

  beforeAll(async () => {
    const m = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = m.createNestApplication();
    await app.init();
    prisma = app.get(PrismaService);

    const lesson = async (code: string, n: number) => {
      const l = await prisma.lesson.create({
        data: { code: `MUS-${code}-${stamp}`, title: code, topic: 'MUS', level: 'MAHIR', cefr: 'C1', skill: 'VOCABULARY', order: 1, status: 'LIVE' },
      });
      const ids: string[] = [];
      for (let k = 1; k <= n; k++) {
        const it = await prisma.item.create({
          data: { lessonId: l.id, type: 'PILIHAN_GANDA', prompt: 'p', options: ['A', 'B', 'C', 'D'], answerKey: 'A', explanation: 'e', order: k, status: 'LIVE' },
        });
        ids.push(it.id);
      }
      return { l, ids };
    };
    const l1 = await lesson('L1', 1);
    const l2 = await lesson('L2', 2);
    doneItemId = l1.ids[0];

    const a = await prisma.module.create({ data: { slug: slugA, title: 'MUS A', summary: 'sa', level: 'MAHIR', cefr: 'C1', order: 1, status: 'LIVE' } });
    await prisma.moduleChapter.createMany({
      data: [
        { moduleId: a.id, order: 1, title: 'Satu', estMinutes: 5, body: 'Satu', blocks: blocks('Satu'), lessonId: l1.l.id },
        { moduleId: a.id, order: 2, title: 'Dua', estMinutes: 4, body: ':::tip\nT\n:::', blocks: blocks(':::tip\nT\n:::'), lessonId: l2.l.id },
        { moduleId: a.id, order: 3, title: 'Tiga', estMinutes: 3, body: 'Baca', blocks: blocks('Baca') },
      ],
    });
    const b = await prisma.module.create({ data: { slug: slugB, title: 'MUS B', summary: 'sb', level: 'DASAR', cefr: 'A2', order: 2, status: 'LIVE' } });
    await prisma.moduleChapter.create({ data: { moduleId: b.id, order: 1, title: 'B1', estMinutes: 5, body: 'B', blocks: blocks('B') } });
    const d = await prisma.module.create({ data: { slug: slugDraft, title: 'MUS D', summary: 'sd', level: 'MAHIR', cefr: 'C1', order: 3 } });
    await prisma.moduleChapter.create({ data: { moduleId: d.id, order: 1, title: 'D1', estMinutes: 5, body: 'D', blocks: blocks('D') } });
    await prisma.module.create({ data: { slug: slugEmpty, title: 'MUS E', summary: 'se', level: 'MAHIR', cefr: 'C1', order: 4, status: 'LIVE' } });

    const passwordHash = await bcrypt.hash(PASSWORD, 10);
    const u = await prisma.user.create({
      data: { name: 'MUS', email: `mus-${stamp}@ex.com`, role: 'USER', level: 'MAHIR', passwordHash, inviteStatus: 'ACCEPTED' },
    });
    userId = u.id;
    // Bab 1 tuntas lewat "jalur lain": attempt benar percobaan pertama.
    const s = await prisma.session.create({ data: { userId, date: new Date('2026-10-01'), kind: 'DAILY', status: 'COMPLETED' } });
    await prisma.attempt.create({ data: { userId, itemId: doneItemId, sessionId: s.id, answer: 'A', correct: true, firstTry: true } });

    token = (await request(app.getHttpServer()).post('/auth/login').send({ email: u.email, password: PASSWORD }).expect(201)).body.accessToken;
  });

  afterAll(async () => {
    const users = { user: { email: { startsWith: 'mus-' } } };
    await prisma.attempt.deleteMany({ where: users });
    await prisma.sessionItem.deleteMany({ where: { session: users } });
    await prisma.session.deleteMany({ where: users });
    await prisma.moduleChapter.deleteMany({ where: { module: { slug: { startsWith: 'mus-' } } } });
    await prisma.module.deleteMany({ where: { slug: { startsWith: 'mus-' } } });
    await prisma.item.deleteMany({ where: { lesson: { code: { startsWith: 'MUS-' } } } });
    await prisma.lesson.deleteMany({ where: { code: { startsWith: 'MUS-' } } });
    await prisma.user.deleteMany({ where: { email: { startsWith: 'mus-' } } });
    await app.close();
  });

  it('GET /modules: forYou sesuai level, others level lain, tanpa DRAFT & tanpa modul kosong', async () => {
    const res = await get('/modules').expect(200);
    const slugs = (xs: any[]) => xs.map((x) => x.slug);
    expect(slugs(res.body.forYou)).toContain(slugA);
    expect(slugs(res.body.others)).toContain(slugB);
    const all = [...slugs(res.body.forYou), ...slugs(res.body.others)];
    expect(all).not.toContain(slugDraft);
    expect(all).not.toContain(slugEmpty);
    const a = res.body.forYou.find((x: any) => x.slug === slugA);
    expect(a).toMatchObject({ chapterCount: 3, quizChapterCount: 2, doneCount: 1, estMinutes: 12 });
    expect(res.body.inProgress.slug).toBe(slugA);
  });

  it('GET /modules/:slug: status per bab + nextOrder', async () => {
    const res = await get(`/modules/${slugA}`).expect(200);
    expect(res.body.nextOrder).toBe(2);
    expect(res.body.chapters).toEqual([
      expect.objectContaining({ order: 1, kind: 'quiz', done: true, accuracy: 100, itemCount: 1 }),
      expect.objectContaining({ order: 2, kind: 'quiz', done: false, accuracy: null, itemCount: 2 }),
      expect.objectContaining({ order: 3, kind: 'reading', done: false, itemCount: 0 }),
    ]);
  });

  it('GET /modules/:slug/chapters/:order: blocks + kuis + navigasi', async () => {
    const res = await get(`/modules/${slugA}/chapters/2`).expect(200);
    expect(res.body.blocks).toEqual([{ type: 'tip', text: [[{ t: 'T' }]] }]);
    expect(res.body.quiz).toMatchObject({ itemCount: 2, done: false });
    expect(res.body.quiz.estXp).toBeGreaterThan(0);
    expect(res.body).toMatchObject({ prevOrder: 1, nextOrder: 3, chapterCount: 3, moduleSlug: slugA });
    const done = await get(`/modules/${slugA}/chapters/1`).expect(200);
    expect(done.body.quiz).toMatchObject({ done: true, estXp: null });
    const reading = await get(`/modules/${slugA}/chapters/3`).expect(200);
    expect(reading.body.quiz).toBeNull();
  });

  it('404 untuk modul DRAFT, slug tak dikenal, bab tak ada', async () => {
    await get(`/modules/${slugDraft}`).expect(404);
    await get(`/modules/${slugDraft}/chapters/1`).expect(404);
    await get('/modules/tidak-ada').expect(404);
    await get(`/modules/${slugA}/chapters/9`).expect(404);
    await get(`/modules/${slugA}/chapters/abc`).expect(404);
  });

  it('lesson kuis jadi DRAFT → bab dianggap Bacaan', async () => {
    const ch = await prisma.moduleChapter.findFirstOrThrow({ where: { module: { slug: slugA }, order: 2 } });
    await prisma.lesson.update({ where: { id: ch.lessonId! }, data: { status: 'DRAFT' } });
    const res = await get(`/modules/${slugA}`).expect(200);
    expect(res.body.chapters[1]).toMatchObject({ kind: 'reading' });
    await prisma.lesson.update({ where: { id: ch.lessonId! }, data: { status: 'LIVE' } });
  });

  it('summary.moduleInProgress menunjuk bab berikutnya', async () => {
    const res = await get('/me/summary').expect(200);
    expect(res.body.moduleInProgress).toEqual({ slug: slugA, title: 'MUS A', nextOrder: 2, nextTitle: 'Dua' });
  });
});
```

Run: `npx jest --config ./test/jest-e2e.json test/modules-user.e2e-spec.ts` → FAIL (404 / `moduleInProgress` undefined).

- [ ] **Step 2: Helper `completionForLessons` di SessionService**

Tambahkan di `src/session/session.service.ts` (setelah `lessonCompletion`), plus export interface di atas class:

```ts
export interface LessonProgress {
  /** item LIVE bila lesson LIVE; 0 bila lesson DRAFT/RETIRED */
  liveItemCount: number;
  /** semua item LIVE pernah dijawab benar (definisi lessonCompletionInternal) */
  done: boolean;
  /** akurasi percobaan pertama bila done, selain itu null */
  accuracy: number | null;
}
```

```ts
  /**
   * Progres per-lesson berdasarkan id (tidak difilter level/PATH_LESSON) —
   * dipakai kuis bab modul. Definisi "done" identik lessonCompletionInternal.
   */
  async completionForLessons(
    userId: string,
    lessonIds: string[],
    db: Db = this.prisma,
  ): Promise<Map<string, LessonProgress>> {
    const map = new Map<string, LessonProgress>();
    if (!lessonIds.length) return map;
    const lessons = await db.lesson.findMany({
      where: { id: { in: lessonIds } },
      select: { id: true, status: true, items: { where: { status: 'LIVE' }, select: { id: true } } },
    });
    const itemIds = lessons.filter((l) => l.status === 'LIVE').flatMap((l) => l.items.map((i) => i.id));
    const attempts = itemIds.length
      ? await db.attempt.findMany({
          where: { userId, itemId: { in: itemIds }, correct: true },
          select: { itemId: true, firstTry: true },
        })
      : [];
    const correct = new Set(attempts.map((a) => a.itemId));
    const firstTryCorrect = new Set(attempts.filter((a) => a.firstTry).map((a) => a.itemId));
    for (const l of lessons) {
      const items = l.status === 'LIVE' ? l.items : [];
      const done = items.length > 0 && items.every((i) => correct.has(i.id));
      map.set(l.id, {
        liveItemCount: items.length,
        done,
        accuracy: done
          ? Math.round((items.filter((i) => firstTryCorrect.has(i.id)).length / items.length) * 100)
          : null,
      });
    }
    return map;
  }
```

- [ ] **Step 3: Tipe view user**

```ts
// apps/api/src/modules/modules.types.ts
import type { Cefr, Level } from '@prisma/client';
import type { ChapterBlock } from './blocks';

export interface ModuleCard {
  slug: string;
  title: string;
  summary: string;
  level: Level;
  cefr: Cefr;
  coverUrl: string | null;
  chapterCount: number;
  quizChapterCount: number;
  doneCount: number;
  estMinutes: number;
}

export interface ModulesView {
  inProgress: ModuleCard | null;
  forYou: ModuleCard[];
  others: ModuleCard[];
}

export interface ModuleChapterRow {
  id: string;
  order: number;
  title: string;
  estMinutes: number;
  kind: 'quiz' | 'reading';
  done: boolean;
  accuracy: number | null;
  itemCount: number;
}

export interface ModuleDetailView extends ModuleCard {
  nextOrder: number | null;
  chapters: ModuleChapterRow[];
}

export interface ChapterView {
  id: string;
  order: number;
  title: string;
  estMinutes: number;
  blocks: ChapterBlock[];
  quiz: { itemCount: number; done: boolean; estXp: number | null } | null;
  prevOrder: number | null;
  nextOrder: number | null;
  chapterCount: number;
  moduleSlug: string;
  moduleTitle: string;
}

export interface ModuleInProgressView {
  slug: string;
  title: string;
  nextOrder: number;
  nextTitle: string;
}
```

- [ ] **Step 4: `ModulesService` + controller**

```ts
// apps/api/src/modules/modules.service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { AppConfigService } from '../common/config.service';
import { LessonProgress, SessionService } from '../session/session.service';
import { resolveBlocks } from './blocks';
import type { StoredBlock } from './chapter-parser';
import type { ChapterView, ModuleCard, ModuleChapterRow, ModuleDetailView, ModuleInProgressView, ModulesView } from './modules.types';

const chapterSelect = { id: true, order: true, title: true, estMinutes: true, lessonId: true } satisfies Prisma.ModuleChapterSelect;
type LiveModule = Prisma.ModuleGetPayload<{ include: { chapters: { select: typeof chapterSelect } } }>;

@Injectable()
export class ModulesService {
  constructor(
    private prisma: PrismaService,
    private storage: StorageService,
    private config: AppConfigService,
    private session: SessionService,
  ) {}

  /** Modul LIVE yang punya ≥1 bab — satu-satunya yang boleh dilihat user. */
  private loadLive(where: Prisma.ModuleWhereInput = {}): Promise<LiveModule[]> {
    return this.prisma.module.findMany({
      where: { status: 'LIVE', chapters: { some: {} }, ...where },
      orderBy: { order: 'asc' },
      include: { chapters: { orderBy: { order: 'asc' }, select: chapterSelect } },
    });
  }

  private progressFor(userId: string, modules: LiveModule[]) {
    const ids = modules.flatMap((m) => m.chapters.map((c) => c.lessonId).filter((x): x is string => !!x));
    return this.session.completionForLessons(userId, ids);
  }

  private rows(m: LiveModule, prog: Map<string, LessonProgress>): ModuleChapterRow[] {
    return m.chapters.map((c) => {
      const p = c.lessonId ? prog.get(c.lessonId) : undefined;
      const quiz = !!p && p.liveItemCount > 0;
      return {
        id: c.id,
        order: c.order,
        title: c.title,
        estMinutes: c.estMinutes,
        kind: quiz ? 'quiz' : 'reading',
        done: quiz && !!p?.done,
        accuracy: quiz ? (p?.accuracy ?? null) : null,
        itemCount: quiz ? (p?.liveItemCount ?? 0) : 0,
      };
    });
  }

  private card(m: LiveModule, rows: ModuleChapterRow[]): ModuleCard {
    const quiz = rows.filter((r) => r.kind === 'quiz');
    return {
      slug: m.slug,
      title: m.title,
      summary: m.summary,
      level: m.level,
      cefr: m.cefr,
      coverUrl: m.coverFile ? this.storage.getUrl(m.coverFile) : null,
      chapterCount: rows.length,
      quizChapterCount: quiz.length,
      doneCount: quiz.filter((r) => r.done).length,
      estMinutes: rows.reduce((n, r) => n + r.estMinutes, 0),
    };
  }

  async list(userId: string): Promise<ModulesView> {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId }, select: { level: true } });
    const modules = await this.loadLive();
    const prog = await this.progressFor(userId, modules);
    const cards = modules.map((m) => this.card(m, this.rows(m, prog)));
    const inProgressSlug = await this.pickInProgress(userId, modules, cards);
    return {
      inProgress: cards.find((c) => c.slug === inProgressSlug) ?? null,
      forYou: cards.filter((c) => c.level === user.level),
      others: cards.filter((c) => c.level !== user.level),
    };
  }

  /** Modul berjalan (≥1 bab selesai, belum semua) yang paling baru dikerjakan; seri → urutan modul. */
  private async pickInProgress(userId: string, modules: LiveModule[], cards: ModuleCard[]): Promise<string | null> {
    const candidates = cards.filter((c) => c.doneCount > 0 && c.doneCount < c.quizChapterCount);
    if (!candidates.length) return null;
    const chapterToSlug = new Map<string, string>();
    for (const m of modules) for (const c of m.chapters) chapterToSlug.set(c.id, m.slug);
    const sessions = await this.prisma.session.findMany({
      where: { userId, moduleChapterId: { in: [...chapterToSlug.keys()] } },
      select: { moduleChapterId: true, date: true },
    });
    const latest = new Map<string, number>();
    for (const s of sessions) {
      const slug = chapterToSlug.get(s.moduleChapterId!)!;
      latest.set(slug, Math.max(latest.get(slug) ?? 0, s.date.getTime()));
    }
    return [...candidates].sort((a, b) => (latest.get(b.slug) ?? 0) - (latest.get(a.slug) ?? 0))[0].slug;
  }

  async detail(userId: string, slug: string): Promise<ModuleDetailView> {
    const [m] = await this.loadLive({ slug });
    if (!m) throw new NotFoundException();
    const rows = this.rows(m, await this.progressFor(userId, [m]));
    return {
      ...this.card(m, rows),
      nextOrder: rows.find((r) => r.kind === 'quiz' && !r.done)?.order ?? null,
      chapters: rows,
    };
  }

  async chapter(userId: string, slug: string, orderParam: string): Promise<ChapterView> {
    const order = Number(orderParam);
    if (!Number.isInteger(order)) throw new NotFoundException();
    const [m] = await this.loadLive({ slug });
    if (!m) throw new NotFoundException();
    const idx = m.chapters.findIndex((c) => c.order === order);
    if (idx < 0) throw new NotFoundException();
    const ch = await this.prisma.moduleChapter.findUniqueOrThrow({ where: { id: m.chapters[idx].id } });
    const p = ch.lessonId ? (await this.session.completionForLessons(userId, [ch.lessonId])).get(ch.lessonId) : undefined;

    let quiz: ChapterView['quiz'] = null;
    if (p && p.liveItemCount > 0) {
      const [first, complete, perfect] = await Promise.all([
        this.config.getInt('XP_FIRST_TRY'),
        this.config.getInt('XP_SESSION_COMPLETE'),
        this.config.getInt('XP_PERFECT_SESSION'),
      ]);
      quiz = { itemCount: p.liveItemCount, done: p.done, estXp: p.done ? null : p.liveItemCount * first + complete + perfect };
    }
    return {
      id: ch.id,
      order: ch.order,
      title: ch.title,
      estMinutes: ch.estMinutes,
      blocks: resolveBlocks(ch.blocks as unknown as StoredBlock[], this.storage),
      quiz,
      prevOrder: m.chapters[idx - 1]?.order ?? null,
      nextOrder: m.chapters[idx + 1]?.order ?? null,
      chapterCount: m.chapters.length,
      moduleSlug: m.slug,
      moduleTitle: m.title,
    };
  }

  async inProgressSummary(userId: string): Promise<ModuleInProgressView | null> {
    const { inProgress } = await this.list(userId);
    if (!inProgress) return null;
    const d = await this.detail(userId, inProgress.slug);
    const next = d.chapters.find((c) => c.order === d.nextOrder);
    return next ? { slug: d.slug, title: d.title, nextOrder: next.order, nextTitle: next.title } : null;
  }
}
```

```ts
// apps/api/src/modules/modules.controller.ts
import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { ModulesService } from './modules.service';

type AuthUser = { sub: string; role: string };

@Controller('modules')
@UseGuards(JwtAuthGuard)
export class ModulesController {
  constructor(private modules: ModulesService) {}

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.modules.list(user.sub);
  }

  @Get(':slug')
  detail(@Param('slug') slug: string, @CurrentUser() user: AuthUser) {
    return this.modules.detail(user.sub, slug);
  }

  @Get(':slug/chapters/:order')
  chapter(@Param('slug') slug: string, @Param('order') order: string, @CurrentUser() user: AuthUser) {
    return this.modules.chapter(user.sub, slug, order);
  }
}
```

Perbarui `src/modules/modules.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { ContentModule } from '../content/content.module';
import { SessionModule } from '../session/session.module';
import { AdminModulesController } from './admin-modules.controller';
import { AdminModulesService } from './admin-modules.service';
import { ModulesController } from './modules.controller';
import { ModulesService } from './modules.service';

@Module({
  imports: [AuthModule, ContentModule, SessionModule],
  controllers: [AdminModulesController, ModulesController],
  providers: [AdminModulesService, ModulesService],
  exports: [ModulesService],
})
export class ModulesModule {}
```

- [ ] **Step 5: `moduleInProgress` di summary**

`src/me/me.module.ts`: tambahkan `ModulesModule` ke `imports` (`import { ModulesModule } from '../modules/modules.module';`).

`src/me/summary.service.ts`:
- import `ModulesService` dan `ModuleInProgressView`;
- `SummaryView` + 
```ts
  /** modul yang sedang berjalan — kartu kecil "Lanjutkan modul" di Beranda. */
  moduleInProgress: ModuleInProgressView | null;
```
- constructor + `private modules: ModulesService,`
- di `get()` setelah `const openSession = …`:
```ts
    const moduleInProgress = await this.modules.inProgressSummary(userId);
```
- return object + `moduleInProgress,`

- [ ] **Step 6: Jalankan test**

Run: `npx jest --config ./test/jest-e2e.json test/modules-user.e2e-spec.ts test/me.e2e-spec.ts`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add src/modules src/session/session.service.ts src/me test/modules-user.e2e-spec.ts
git commit -m "feat(modul): API user — daftar, detail, bab + moduleInProgress di summary"
```

---

### Task 6: Sesi kuis bab — `POST /session/module`

**Files:**
- Modify: `src/session/session.service.ts`, `src/session/session.controller.ts`, `src/session/session.types.ts`
- Test: `test/session-module.e2e-spec.ts`

**Interfaces:**
- Consumes: `completionForLessons` (Task 5), `COUNTED_SESSION_KINDS` (Task 2).
- Produces: `POST /session/module {chapterId}` → `SessionView` dengan `kind: 'MODULE' | 'REPLAY'`, `moduleSlug: string | null`, `chapterOrder: number | null`; `SessionView.kind` union + `'MODULE'`.

- [ ] **Step 1: Tulis e2e yang gagal**

```ts
// apps/api/test/session-module.e2e-spec.ts
import 'dotenv/config';
import { Test } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import * as bcrypt from 'bcrypt';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';

// Prefix SMO- / smo-.
const PASSWORD = 'Password123!';

describe('POST /session/module (kuis bab)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let token: string;
  let userId: string;
  let chQuiz: string; // lesson 2 item, belum tuntas
  let chDone: string; // lesson sudah tuntas lewat Perjalanan
  let chReading: string; // tanpa lesson
  let chDraftModule: string;
  let quizItemIds: string[] = [];
  const stamp = Date.now();

  const post = (p: string, body: object) =>
    request(app.getHttpServer()).post(p).set('Authorization', `Bearer ${token}`).send(body);
  const get = (p: string) => request(app.getHttpServer()).get(p).set('Authorization', `Bearer ${token}`);

  beforeAll(async () => {
    const m = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = m.createNestApplication();
    await app.init();
    prisma = app.get(PrismaService);

    const lesson = async (code: string, n: number) => {
      const l = await prisma.lesson.create({
        data: { code: `SMO-${code}-${stamp}`, title: `Kuis ${code}`, topic: 'SMO', level: 'DASAR', cefr: 'A2', skill: 'VOCABULARY', order: 1, status: 'LIVE' },
      });
      const ids: string[] = [];
      for (let k = 1; k <= n; k++) {
        ids.push((await prisma.item.create({
          data: { lessonId: l.id, type: 'PILIHAN_GANDA', prompt: 'p', options: ['A', 'B', 'C', 'D'], answerKey: 'A', explanation: 'e', order: k, status: 'LIVE' },
        })).id);
      }
      return { l, ids };
    };
    const q = await lesson('Q', 2);
    const d = await lesson('D', 1);
    quizItemIds = q.ids;

    const mod = await prisma.module.create({ data: { slug: `smo-${stamp}`, title: 'SMO', summary: 's', level: 'DASAR', cefr: 'A2', order: 1, status: 'LIVE' } });
    const mk = (order: number, lessonId?: string) =>
      prisma.moduleChapter.create({ data: { moduleId: mod.id, order, title: `Bab ${order}`, estMinutes: 5, body: 'x', blocks: [], lessonId } });
    chQuiz = (await mk(1, q.l.id)).id;
    chDone = (await mk(2, d.l.id)).id;
    chReading = (await mk(3)).id;
    const draft = await prisma.module.create({ data: { slug: `smo-d-${stamp}`, title: 'SMO D', summary: 's', level: 'DASAR', cefr: 'A2', order: 2 } });
    chDraftModule = (await prisma.moduleChapter.create({ data: { moduleId: draft.id, order: 1, title: 'X', estMinutes: 5, body: 'x', blocks: [], lessonId: (await lesson('X', 1)).l.id } })).id;

    const passwordHash = await bcrypt.hash(PASSWORD, 10);
    const u = await prisma.user.create({
      data: { name: 'SMO', email: `smo-${stamp}@ex.com`, role: 'USER', level: 'DASAR', passwordHash, inviteStatus: 'ACCEPTED' },
    });
    userId = u.id;
    const old = await prisma.session.create({ data: { userId, date: new Date('2026-10-01'), kind: 'DAILY', status: 'COMPLETED' } });
    await prisma.attempt.create({ data: { userId, itemId: d.ids[0], sessionId: old.id, answer: 'A', correct: true, firstTry: true } });
    token = (await request(app.getHttpServer()).post('/auth/login').send({ email: u.email, password: PASSWORD }).expect(201)).body.accessToken;
  });

  afterAll(async () => {
    const users = { user: { email: { startsWith: 'smo-' } } };
    await prisma.attempt.deleteMany({ where: users });
    await prisma.sessionItem.deleteMany({ where: { session: users } });
    await prisma.session.deleteMany({ where: users });
    await prisma.reviewQueue.deleteMany({ where: users });
    await prisma.moduleChapter.deleteMany({ where: { module: { slug: { startsWith: 'smo-' } } } });
    await prisma.module.deleteMany({ where: { slug: { startsWith: 'smo-' } } });
    await prisma.item.deleteMany({ where: { lesson: { code: { startsWith: 'SMO-' } } } });
    await prisma.lesson.deleteMany({ where: { code: { startsWith: 'SMO-' } } });
    await prisma.user.deleteMany({ where: { email: { startsWith: 'smo-' } } });
    await app.close();
  });

  let sessionId: string;

  it('lesson belum tuntas → sesi MODULE berisi item lesson, urut, tanpa review', async () => {
    const res = await post('/session/module', { chapterId: chQuiz }).expect(201);
    sessionId = res.body.id;
    expect(res.body.kind).toBe('MODULE');
    expect(res.body.lessonTitle).toBe('Bab 1');
    expect(res.body.moduleSlug).toBe(`smo-${stamp}`);
    expect(res.body.chapterOrder).toBe(1);
    expect(res.body.items.map((i: any) => i.itemId)).toEqual(quizItemIds);
    expect(res.body.items.every((i: any) => i.source === 'LESSON')).toBe(true);
  });

  it('dipanggil lagi → resume sesi yang sama; sesi DAILY tidak terganggu', async () => {
    const again = await post('/session/module', { chapterId: chQuiz }).expect(201);
    expect(again.body.id).toBe(sessionId);
    const daily = await post('/session/today', {});
    expect(daily.body.id).not.toBe(sessionId);
  });

  it('selesai → bonus XP, target harian & bab ✓', async () => {
    let last: any;
    for (const itemId of quizItemIds) {
      last = (await post(`/session/${sessionId}/answer`, { itemId, answer: 'A' }).expect(201)).body;
    }
    expect(last.summary).not.toBeNull();
    const s = await prisma.session.findUniqueOrThrow({ where: { id: sessionId } });
    expect(s.status).toBe('COMPLETED');
    expect(s.xpAwarded).toBeGreaterThan(0);
    const summary = await get('/me/summary').expect(200);
    expect(summary.body.sessionsCompletedToday).toBeGreaterThanOrEqual(1);
    const detail = await get(`/modules/smo-${stamp}`).expect(200);
    expect(detail.body.chapters[0]).toMatchObject({ done: true, accuracy: 100 });
  });

  it('lesson sudah tuntas (lewat Perjalanan) → REPLAY tanpa bonus', async () => {
    const res = await post('/session/module', { chapterId: chDone }).expect(201);
    expect(res.body.kind).toBe('REPLAY');
    const last = (await post(`/session/${res.body.id}/answer`, { itemId: res.body.items[0].itemId, answer: 'A' }).expect(201)).body;
    expect(last.summary).not.toBeNull();
    const s = await prisma.session.findUniqueOrThrow({ where: { id: res.body.id } });
    expect(s.xpAwarded).toBe(0);
  });

  it('bab bacaan → 409; modul DRAFT → 404; chapterId tak valid → 400/404', async () => {
    const r = await post('/session/module', { chapterId: chReading }).expect(409);
    expect(r.body.message).toBe('Kuis bab ini belum tersedia');
    await post('/session/module', { chapterId: chDraftModule }).expect(404);
    await post('/session/module', { chapterId: 'tidak-ada' }).expect(404);
    await post('/session/module', {}).expect(400);
  });
});
```

Run: `npx jest --config ./test/jest-e2e.json test/session-module.e2e-spec.ts` → FAIL (404 route).

- [ ] **Step 2: Tipe**

`src/session/session.types.ts` — ganti `SessionView`:

```ts
export interface SessionView {
  id: string;
  kind: 'DAILY' | 'REPLAY' | 'SPEAKING' | 'MODULE';
  status: 'IN_PROGRESS' | 'COMPLETED';
  lessonTitle: string | null;
  /** terisi untuk sesi kuis bab (MODULE/REPLAY dari modul) — tombol kembali ke modul */
  moduleSlug: string | null;
  chapterOrder: number | null;
  items: SessionItemView[];
  progress: { answered: number; total: number };
}
```

- [ ] **Step 3: `moduleQuiz` + `view` di SessionService**

Tambahkan method (setelah `speaking`):

```ts
  /**
   * Kuis bab modul (spec §5.4). Pola getOrCreateToday: transaksi + advisory
   * lock + resume sesi terbuka hari ini untuk bab yang sama + handling yatim.
   * Lesson belum tuntas → MODULE (dihitung target/streak/bonus); sudah tuntas
   * → REPLAY (semantik ulangan). Tanpa review yang diselipkan.
   */
  async moduleQuiz(userId: string, chapterId: string): Promise<SessionView> {
    if (typeof chapterId !== 'string') throw new BadRequestException('chapterId wajib diisi');
    const today = todayWIB();

    const session = await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${userId}))`;

      const chapter = await tx.moduleChapter.findUnique({ where: { id: chapterId }, include: { module: true } });
      if (!chapter || chapter.module.status !== 'LIVE') throw new NotFoundException();

      const open = await tx.session.findFirst({
        where: { userId, date: today, moduleChapterId: chapterId, status: 'IN_PROGRESS' },
        include: { _count: { select: { items: true, attempts: true } } },
      });
      if (open && open._count.items > 0) return open;
      if (open) {
        if (open._count.attempts === 0) {
          await tx.session.delete({ where: { id: open.id } });
        } else {
          await tx.session.update({ where: { id: open.id }, data: { status: 'COMPLETED', completedAt: new Date() } });
        }
      }

      const prog = chapter.lessonId
        ? (await this.completionForLessons(userId, [chapter.lessonId], tx)).get(chapter.lessonId)
        : undefined;
      if (!chapter.lessonId || !prog || prog.liveItemCount === 0) {
        throw new ConflictException('Kuis bab ini belum tersedia');
      }
      const items = await tx.item.findMany({
        where: { lessonId: chapter.lessonId, status: 'LIVE' },
        orderBy: { order: 'asc' },
      });

      const s = await tx.session.create({
        data: { userId, date: today, kind: prog.done ? 'REPLAY' : 'MODULE', moduleChapterId: chapterId },
      });
      await tx.sessionItem.createMany({
        data: items.map((i, idx) => ({ sessionId: s.id, itemId: i.id, source: 'LESSON' as const, order: idx })),
      });
      return s;
    });
    return this.view(session.id, userId);
  }
```

Di `view()`:
- `findUnique` include + `moduleChapter: { select: { order: true, title: true, module: { select: { slug: true } } } },`
- `lessonTitle`:
```ts
    const lessonTitle =
      session.kind === 'SPEAKING'
        ? 'Latihan Berbicara'
        : session.moduleChapter
          ? session.moduleChapter.title
          : firstLessonSlot
            ? firstLessonSlot.item.lesson.title
            : null;
```
- return + 
```ts
      moduleSlug: session.moduleChapter?.module.slug ?? null,
      chapterOrder: session.moduleChapter?.order ?? null,
```

- [ ] **Step 4: Endpoint**

`src/session/session.controller.ts` (setelah `speaking`):

```ts
  @Post('module')
  module(@Body() body: { chapterId: string }, @CurrentUser() user: AuthUser) {
    return this.session.moduleQuiz(user.sub, body?.chapterId);
  }
```

- [ ] **Step 5: Jalankan test + regresi sesi**

Run: `npx jest --config ./test/jest-e2e.json test/session-module.e2e-spec.ts && npm run test:e2e`
Expected: PASS semua.

- [ ] **Step 6: Commit**

```bash
git add src/session test/session-module.e2e-spec.ts
git commit -m "feat(modul): sesi kuis bab — POST /session/module (MODULE/REPLAY, resume, moduleSlug)"
```

---

### Task 7: Seeder modul "Making & Handling Complaints"

**Files:**
- Create: `apps/api/prisma/seed-module-complaints.ts`
- Modify: `apps/api/package.json` (script)

**Interfaces:**
- Consumes: `parseChapter` (Task 3); lesson CMP-201..211 (seed-complaints).

- [ ] **Step 1: Tulis seeder**

```ts
// apps/api/prisma/seed-module-complaints.ts
import 'dotenv/config';
import { Prisma, PrismaClient } from '@prisma/client';
import { parseChapter } from '../src/modules/chapter-parser';

/**
 * Seed KONTEN — modul "Making & Handling Complaints" (MENENGAH·B1).
 * 11 bab, bab n menautkan lesson CMP-2xx yang dibuat seed-complaints.ts
 * (jalankan itu dulu). Akibatnya lesson CMP keluar dari Perjalanan — disengaja
 * (spec menu modul §9). Ungkapan diadaptasi dari modul SKKNI BHS.IS03.004.01;
 * penjelasan & dialog ditulis ulang untuk konteks kerja umum, tidak disalin.
 *
 * Jalankan: `npm run seed:module-complaints`. CREATE-ONLY: modul (by slug) dan
 * bab (by moduleId+order) yang sudah ada dilewati — edit admin aman.
 */

const prisma = new PrismaClient();
const SLUG = 'making-handling-complaints';

type Ch = { code: string; title: string; estMinutes: number; body: string };

const CHAPTERS: Ch[] = [
  {
    code: 'CMP-201',
    title: 'Kosakata Keluhan',
    estMinutes: 5,
    body: `Keluhan muncul di mana saja: barang dari vendor terlambat, laptop kantor rusak, atau laporan yang salah angka. Kenali dulu kata-kata intinya.

## Kata kunci

:::phrases
- complaint | keluhan (kata benda)
- to complain about something | mengeluhkan sesuatu
- faulty | rusak, tidak berfungsi
- delay | keterlambatan
- refund | pengembalian dana
- replacement | penggantian (barang)
- inconvenience | ketidaknyamanan
- to resolve | menyelesaikan (masalah)
:::

:::tip
**complain** adalah kata kerja, **complaint** kata benda: *I want to complain* — *I have a complaint*.
:::

## Dalam percakapan

:::dialog
Sari (Admin Kantor): The new printer is faulty again.
Kamu (IT Support): Sorry for the inconvenience. I'll arrange a replacement.
:::`,
  },
  {
    code: 'CMP-202',
    title: 'Menyampaikan Keluhan & Harapan',
    estMinutes: 5,
    body: `Keluhan yang baik punya dua bagian: **apa masalahnya** dan **apa yang kamu harapkan**. Tanpa harapan, lawan bicara tidak tahu harus berbuat apa.

## Membuka keluhan

:::phrases
- I'd like to make a complaint about… | Saya ingin menyampaikan keluhan tentang…
- I'm not happy with… | Saya kurang puas dengan…
- I'm afraid there's a problem with… | Sepertinya ada masalah dengan…
:::

## Menyampaikan harapan

:::phrases
- I would appreciate it if you could… | Saya akan sangat berterima kasih jika Anda bisa…
- Could you please look into it? | Bisakah Anda menindaklanjutinya?
- I'd like it to be fixed by Friday. | Saya ingin ini diperbaiki paling lambat Jumat.
:::

:::dialog
Dimas (Procurement): I'm afraid there's a problem with the last delivery. Two boxes are missing.
Vendor: I see. What would you like us to do?
Dimas (Procurement): I would appreciate it if you could send them by Thursday.
:::`,
  },
  {
    code: 'CMP-203',
    title: 'Bahasa Formal vs Nonformal',
    estMinutes: 4,
    body: `Saat kesal, kalimat cenderung jadi pendek dan kasar. Di kantor, versi formal membuat keluhan lebih didengar.

| Nonformal | Formal |
|---|---|
| This is wrong. | I'm afraid there seems to be an error. |
| Fix it now. | Could you please fix it as soon as possible? |
| What's the problem? | How may I help you? |
| Wait. | Could you hold on for a moment, please? |
| You didn't send it. | It seems the file hasn't arrived yet. |

:::tip
Kata **seems**, **I'm afraid**, dan **could you** melunakkan kalimat tanpa mengubah isinya.
:::`,
  },
  {
    code: 'CMP-204',
    title: 'Menggali Informasi',
    estMinutes: 5,
    body: `Sebelum menyelesaikan keluhan, kamu perlu tahu detailnya. Gunakan pertanyaan yang sopan dan spesifik.

## Frasa kunci

:::phrases
- Could you tell me what happened? | Boleh ceritakan apa yang terjadi?
- When did you first notice it? | Kapan pertama kali Anda menyadarinya?
- May I have the order number? | Boleh saya minta nomor pesanannya?
- Has this happened before? | Apakah ini pernah terjadi sebelumnya?
:::

:::tip
"Could you…" terdengar lebih sopan daripada "Can you…" saat bicara dengan pelanggan atau atasan.
:::

## Contoh percakapan

:::dialog
Rina (Finance): The vendor invoice still shows the wrong amount.
Kamu (IT Support): I'm sorry about that. Could you tell me which invoice number it is?
Rina (Finance): It's INV-2047, from last Monday.
Kamu (IT Support): Thank you. When did you first notice the difference?
:::`,
  },
  {
    code: 'CMP-205',
    title: 'Minta Maaf & Empati',
    estMinutes: 5,
    body: `Permintaan maaf yang tulus meredakan suasana, bahkan sebelum masalahnya selesai. Tunjukkan bahwa kamu memahami perasaan lawan bicara.

:::phrases
- I'm very sorry for the inconvenience. | Mohon maaf atas ketidaknyamanannya.
- I apologize for the delay. | Saya mohon maaf atas keterlambatannya.
- I understand how frustrating this must be. | Saya paham ini pasti membuat kesal.
- That must have been difficult. | Itu pasti tidak mudah.
:::

:::tip
Hindari menyalahkan pihak lain ("It's the courier's fault"). Fokus pada apa yang bisa kamu lakukan.
:::

:::dialog
Budi (Sales): I waited two hours for the meeting room to be ready.
Kamu (General Affairs): I'm very sorry for the inconvenience. I understand how frustrating that must be.
:::`,
  },
  {
    code: 'CMP-206',
    title: 'Berterima Kasih atas Masukan',
    estMinutes: 4,
    body: `Orang yang mengeluh sebenarnya memberi informasi berharga. Ucapkan terima kasih — itu membuat mereka merasa didengar.

:::phrases
- Thank you for letting us know. | Terima kasih sudah memberi tahu kami.
- Thanks for bringing this to our attention. | Terima kasih sudah menyampaikan hal ini.
- We appreciate your feedback. | Kami menghargai masukan Anda.
- Thank you for your patience. | Terima kasih atas kesabaran Anda.
:::

:::tip
Ucapkan terima kasih di awal **dan** di akhir percakapan — pembuka yang hangat, penutup yang rapi.
:::`,
  },
  {
    code: 'CMP-207',
    title: 'Menjanjikan Tindakan',
    estMinutes: 5,
    body: `Setelah minta maaf, sampaikan langkah konkret. Janji yang baik menjawab **apa** yang akan dilakukan dan **kapan**.

:::phrases
- I'll look into it right away. | Saya akan segera memeriksanya.
- Let me check with the team. | Saya cek dulu dengan tim.
- I'll get back to you by 3 p.m. | Saya akan mengabari Anda paling lambat pukul 3 sore.
- We will replace it free of charge. | Kami akan menggantinya tanpa biaya.
:::

:::tip
"I'll try" terdengar ragu. Pilih "I will…" bila kamu yakin bisa menepatinya.
:::

:::dialog
Maya (HR): My access card stopped working this morning.
Kamu (Security): Let me check with the team. I'll get back to you by noon.
:::`,
  },
  {
    code: 'CMP-208',
    title: 'Konfirmasi Penyelesaian',
    estMinutes: 4,
    body: `Keluhan belum selesai sampai pelapor setuju masalahnya beres. Tutup dengan konfirmasi.

:::phrases
- Is everything working now? | Apakah semuanya sudah berjalan normal?
- Has the issue been resolved? | Apakah masalahnya sudah selesai?
- Is there anything else I can help with? | Ada lagi yang bisa saya bantu?
- Please let me know if it happens again. | Kabari saya jika terjadi lagi.
:::

:::dialog
Kamu (IT Support): I've reset your account. Is everything working now?
Andi (Marketing): Yes, I can log in. Thanks!
Kamu (IT Support): Great. Please let me know if it happens again.
:::`,
  },
  {
    code: 'CMP-209',
    title: 'Email Keluhan & Balasannya',
    estMinutes: 6,
    body: `Keluhan tertulis perlu struktur yang jelas supaya cepat ditindaklanjuti.

## Struktur email keluhan

1. Subjek yang spesifik
2. Masalahnya dalam satu kalimat
3. Detail: tanggal, nomor dokumen, dampak
4. Harapanmu
5. Penutup sopan

:::phrases
- I am writing to complain about… | Saya menulis untuk menyampaikan keluhan tentang…
- Please find attached… | Terlampir…
- I look forward to your reply. | Saya menantikan balasan Anda.
- Thank you for your email regarding… | Terima kasih atas email Anda terkait…
:::

:::tip
Subjek seperti **"Wrong amount on invoice INV-2047"** jauh lebih berguna daripada **"Complaint"**.
:::`,
  },
  {
    code: 'CMP-210',
    title: 'Menangani Keluhan lewat Telepon',
    estMinutes: 5,
    body: `Di telepon kamu tidak bisa melihat ekspresi lawan bicara. Bicara pelan, jelas, dan ulangi informasi penting.

:::phrases
- Thank you for calling IT Support, this is Dewi speaking. | Terima kasih telah menghubungi IT Support, dengan Dewi di sini.
- Could you hold the line, please? | Mohon ditunggu sebentar.
- Sorry, could you repeat that? | Maaf, bisa diulang?
- Could you spell your name, please? | Bisa dieja namanya?
:::

:::tip
Ulangi angka penting untuk konfirmasi: *"That's INV two-zero-four-seven, correct?"*
:::

:::dialog
Kamu (IT Support): Thank you for calling IT Support, this is Dewi speaking.
Penelepon: Hi, my email has stopped syncing since yesterday.
Kamu (IT Support): I'm sorry to hear that. Could you spell your name, please?
:::`,
  },
  {
    code: 'CMP-211',
    title: 'Ucapkan: Menangani Keluhan',
    estMinutes: 5,
    body: `Bab terakhir: latih pelafalan. Tekan 🔊 untuk mendengar contoh, lalu tirukan dengan suaramu sendiri di kuis.

:::phrases
- I'm very sorry for the inconvenience. | Mohon maaf atas ketidaknyamanannya.
- Could you tell me what happened? | Boleh ceritakan apa yang terjadi?
- I'll look into it right away. | Saya akan segera memeriksanya.
- Is there anything else I can help with? | Ada lagi yang bisa saya bantu?
:::

:::tip
Ucapkan perlahan dan beri jeda di koma — kejelasan lebih penting daripada kecepatan.
:::`,
  },
];

async function main() {
  // Validasi semua body dulu — gagal keras sebelum menulis apa pun.
  const parsed = CHAPTERS.map((c) => {
    const r = parseChapter(c.body);
    if (!r.ok) throw new Error(`${c.code}: ${r.errors.map((e) => `Baris ${e.line}: ${e.message}`).join('; ')}`);
    if (r.media.length) throw new Error(`${c.code}: seeder ini tidak memakai media`);
    return r.blocks;
  });

  let mod = await prisma.module.findUnique({ where: { slug: SLUG } });
  if (!mod) {
    const max = await prisma.module.aggregate({ _max: { order: true } });
    mod = await prisma.module.create({
      data: {
        slug: SLUG,
        title: 'Making & Handling Complaints',
        summary: 'Menyampaikan keluhan dengan sopan dan menanganinya sampai tuntas.',
        level: 'MENENGAH',
        cefr: 'B1',
        order: (max._max.order ?? 0) + 1,
        status: 'LIVE',
      },
    });
    console.log(`Modul dibuat: ${mod.title}`);
  } else {
    console.log(`Modul sudah ada, dilewati: ${mod.title}`);
  }

  let created = 0;
  for (const [idx, c] of CHAPTERS.entries()) {
    const order = idx + 1;
    const exists = await prisma.moduleChapter.findUnique({ where: { moduleId_order: { moduleId: mod.id, order } } });
    if (exists) continue;
    const lesson = await prisma.lesson.findUnique({ where: { code: c.code }, include: { moduleChapter: true } });
    let lessonId: string | null = null;
    if (!lesson) console.warn(`  ! ${c.code} tidak ditemukan — bab ${order} jadi Bacaan (jalankan seed:complaints dulu)`);
    else if (lesson.moduleChapter) console.warn(`  ! ${c.code} sudah dipakai bab lain — tidak ditautkan`);
    else lessonId = lesson.id;
    await prisma.moduleChapter.create({
      data: {
        moduleId: mod.id,
        order,
        title: c.title,
        estMinutes: c.estMinutes,
        body: c.body,
        blocks: parsed[idx] as unknown as Prisma.InputJsonValue,
        lessonId,
      },
    });
    created += 1;
  }
  console.log(`${created} bab baru.`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
```

Tambahkan di `package.json` → `scripts`: `"seed:module-complaints": "ts-node prisma/seed-module-complaints.ts",`

- [ ] **Step 2: Jalankan dua kali**

Run: `npm run seed:module-complaints && npm run seed:module-complaints`
Expected: run 1 → `Modul dibuat…` + `11 bab baru.`; run 2 → `Modul sudah ada, dilewati…` + `0 bab baru.` Tanpa warning `!`.

- [ ] **Step 3: Verifikasi Perjalanan Menengah**

```bash
npx ts-node -e "import {PrismaClient} from '@prisma/client';const p=new PrismaClient();p.lesson.count({where:{level:'MENENGAH',status:'LIVE',moduleChapter:{is:null}}}).then(n=>{console.log(n);return p.\$disconnect()})"
```
Expected: jumlah lesson Menengah LIVE yang tidak tertaut (di DB dev berisi demo: WC-201..204 → `4`).

- [ ] **Step 4: Commit**

```bash
git add prisma/seed-module-complaints.ts package.json
git commit -m "feat(content): seeder modul Making & Handling Complaints (11 bab, kuis CMP-201..211)"
```

---

### Task 8: Web — tipe, nav 5 tab, halaman daftar modul

**Files:**
- Modify: `apps/web/src/lib/api-types.ts`, `src/components/user-nav.tsx`, `src/app/learner.css`
- Create: `src/lib/modules.ts`, `src/components/modules/module-cover.tsx`, `src/app/(user)/modules/page.tsx`

**Interfaces:**
- Produces (TS, dipakai Task 9–12):
```ts
// api-types.ts
export type ModuleInline = { t: string; b?: true; i?: true; code?: true; href?: string }[];
export type ChapterBlock = …; export interface ModuleCard …; ModulesView; ModuleChapterRow; ModuleDetailView; ChapterView; ModuleInProgressView
// lib/modules.ts
export const LEVEL_LABEL: Record<string, string>; export function coverTone(i: number): string;
// components/modules/module-cover.tsx
export function ModuleCover({ url, index, size }: { url: string | null; index: number; size?: number }): JSX.Element;
```

- [ ] **Step 1: Tipe**

Di `src/lib/api-types.ts`: tambah `'MODULE'` ke `SessionView.kind`, plus field `moduleSlug: string | null; chapterOrder: number | null;` di `SessionView`; tambah `moduleInProgress: ModuleInProgressView | null;` di `SummaryView`; lalu tambahkan di akhir file:

```ts
// ---------------------------------------------------------------------------
// Menu Modul — GET /modules, /modules/:slug, /modules/:slug/chapters/:order
// (apps/api/src/modules/modules.types.ts + blocks.ts)
// ---------------------------------------------------------------------------

export type ModuleInline = { t: string; b?: true; i?: true; code?: true; href?: string }[];

export type ChapterBlock =
  | { type: 'heading'; level: 2 | 3; text: ModuleInline }
  | { type: 'paragraph'; text: ModuleInline }
  | { type: 'list'; ordered: boolean; items: ModuleInline[] }
  | { type: 'table'; head: ModuleInline[]; rows: ModuleInline[][] }
  | { type: 'image'; url: string; alt: string }
  | { type: 'audio'; url: string }
  | { type: 'phrases'; items: { en: string; id: string; note?: string }[] }
  | { type: 'dialog'; lines: { speaker: string; role?: string; side: 'left' | 'right'; text: string }[] }
  | { type: 'tip'; text: ModuleInline[] };

export interface ModuleCard {
  slug: string;
  title: string;
  summary: string;
  level: 'DASAR' | 'MENENGAH' | 'MAHIR';
  cefr: string;
  coverUrl: string | null;
  chapterCount: number;
  quizChapterCount: number;
  doneCount: number;
  estMinutes: number;
}

export interface ModulesView {
  inProgress: ModuleCard | null;
  forYou: ModuleCard[];
  others: ModuleCard[];
}

export interface ModuleChapterRow {
  id: string;
  order: number;
  title: string;
  estMinutes: number;
  kind: 'quiz' | 'reading';
  done: boolean;
  accuracy: number | null;
  itemCount: number;
}

export interface ModuleDetailView extends ModuleCard {
  nextOrder: number | null;
  chapters: ModuleChapterRow[];
}

export interface ChapterView {
  id: string;
  order: number;
  title: string;
  estMinutes: number;
  blocks: ChapterBlock[];
  quiz: { itemCount: number; done: boolean; estXp: number | null } | null;
  prevOrder: number | null;
  nextOrder: number | null;
  chapterCount: number;
  moduleSlug: string;
  moduleTitle: string;
}

export interface ModuleInProgressView {
  slug: string;
  title: string;
  nextOrder: number;
  nextTitle: string;
}
```

Tambahkan juga baris sumber di komentar header file: ` * - ModulesView / ModuleDetailView / ChapterView / ChapterBlock: apps/api/src/modules/modules.types.ts`.

- [ ] **Step 2: Helper & cover**

```ts
// apps/web/src/lib/modules.ts
export const LEVEL_LABEL: Record<string, string> = { DASAR: 'Dasar', MENENGAH: 'Menengah', MAHIR: 'Mahir' };

/** Warna cover tanpa gambar: siklus varian -deep skill (kontras teks putih ≥4.5:1). */
const TONES = ['#4F46E5', '#0369A1', '#BE185D', '#B45309'];
export function coverTone(i: number): string {
  return TONES[((i % TONES.length) + TONES.length) % TONES.length];
}
```

```tsx
// apps/web/src/components/modules/module-cover.tsx
import { BookOpenText } from 'lucide-react';
import { coverTone } from '@/lib/modules';

export function ModuleCover({ url, index, size = 54 }: { url: string | null; index: number; size?: number }) {
  if (url) {
    // eslint-disable-next-line @next/next/no-img-element
    return <img src={url} alt="" className="mod-cover" style={{ width: size, height: size }} />;
  }
  return (
    <span className="mod-cover" style={{ width: size, height: size, background: coverTone(index) }} aria-hidden="true">
      <BookOpenText size={Math.round(size * 0.48)} strokeWidth={2.25} />
    </span>
  );
}
```

- [ ] **Step 3: Nav 5 tab**

`src/components/user-nav.tsx`: import `BookOpenText` dari lucide, dan `NAV_ITEMS` jadi:

```ts
const NAV_ITEMS: NavItem[] = [
  { href: '/home', label: 'Beranda', icon: Home },
  { href: '/journey', label: 'Perjalanan', icon: Map },
  { href: '/modules', label: 'Modul', icon: BookOpenText },
  { href: '/progress', label: 'Progress', icon: ChartColumn },
  { href: '/profile', label: 'Profil', icon: User },
];
```

`src/app/learner.css:106` (pill mobile, 4 item × 46 + aktif 124 → 5 item): ganti `width: 268px;` → `width: 316px;` dan perbarui komentar di atasnya bila menyebut jumlah item.

- [ ] **Step 4: CSS modul (tambahkan di akhir `learner.css`)**

```css
/* ---- Menu Modul ---------------------------------------------------- */
.mod-cover { display: grid; place-items: center; flex: none; border-radius: 16px; color: #fff; object-fit: cover; }
.learner-ui .mod-list { display: grid; gap: 12px; }
.learner-ui .mod-section-title { margin: 26px 0 10px; color: var(--muted); font-size: 10px; font-weight: 800; letter-spacing: 1.5px; text-transform: uppercase; }
.learner-ui .mod-card { display: flex; gap: 13px; align-items: flex-start; width: 100%; padding: 16px; background: #fff; border: 1px solid var(--line); border-radius: 20px; text-align: left; }
.learner-ui .mod-card:hover { border-color: #d6d7ee; }
.learner-ui .mod-card h3 { font-size: 15px; font-weight: 900; line-height: 1.3; }
.learner-ui .mod-card p { font-size: 12.5px; color: var(--muted); line-height: 1.45; margin: 3px 0 8px; }
.learner-ui .mod-meta { display: flex; flex-wrap: wrap; align-items: center; gap: 6px; font-size: 12px; color: var(--muted); font-weight: 700; }
.learner-ui .mod-chip { display: inline-flex; align-items: center; gap: 4px; border-radius: 10px; padding: 3px 9px; font-size: 11.5px; font-weight: 900; background: var(--brand-soft); color: var(--brand-dark); }
.learner-ui .mod-chip-good { background: #f0fdf4; color: #15803d; }
.learner-ui .mod-bar { flex: 1; height: 8px; border-radius: 99px; background: var(--brand-soft); overflow: hidden; }
.learner-ui .mod-bar > i { display: block; height: 100%; background: var(--brand); border-radius: 99px; }
.learner-ui .mod-progress { display: flex; align-items: center; gap: 10px; margin: 12px 0 14px; font-size: 13px; font-weight: 900; color: var(--brand-dark); }
.learner-ui .mod-back { display: inline-flex; align-items: center; gap: 4px; color: var(--muted); font-size: 14px; font-weight: 800; margin-bottom: 14px; }
.learner-ui .mod-chapters { padding: 4px 14px; }
.learner-ui .mod-ch { display: flex; align-items: center; gap: 12px; width: 100%; padding: 13px 4px; border-bottom: 1px solid var(--line); text-align: left; }
.learner-ui .mod-ch:last-child { border-bottom: 0; }
.learner-ui .mod-ch b { display: block; font-size: 14.5px; font-weight: 900; }
.learner-ui .mod-ch small { font-size: 12px; color: var(--muted); font-weight: 700; }
.learner-ui .mod-ch-next { background: var(--brand-soft); border-radius: 16px; border-bottom-color: transparent; padding: 13px 10px; margin: 4px -6px; width: calc(100% + 12px); }
.learner-ui .mod-ch-next small { color: var(--brand); }
.learner-ui .mod-num { display: grid; place-items: center; flex: none; width: 34px; height: 34px; border-radius: 50%; background: #f1f5f9; color: var(--muted); font-size: 14px; font-weight: 900; }
.learner-ui .mod-num-done { background: #22c55e; color: #fff; border-bottom: 3px solid #15803d; }
.learner-ui .mod-num-next { background: var(--brand); color: #fff; border-bottom: 3px solid var(--brand-dark); }
.learner-ui .mod-chev { margin-left: auto; color: var(--muted); flex: none; }
.learner-ui .mod-reader-top { position: sticky; top: 0; z-index: 5; margin: -26px -20px 0; padding: 14px 20px 10px; background: #fff; border-bottom: 1px solid var(--line); }
.learner-ui .mod-reader-top > div { display: flex; justify-content: space-between; align-items: center; font-size: 13px; font-weight: 900; color: var(--muted); }
.learner-ui .mod-readbar { height: 4px; margin-top: 10px; background: var(--line); border-radius: 9px; overflow: hidden; }
.learner-ui .mod-readbar > i { display: block; height: 100%; background: var(--brand); }
.learner-ui .mod-quiz { margin-top: 22px; padding: 18px; text-align: center; background: #fff; border: 2px solid var(--brand); border-radius: 22px; }
.learner-ui .mod-quiz h4 { font-size: 18px; font-weight: 900; margin: 4px 0; }
.learner-ui .mod-pager { display: flex; justify-content: space-between; margin-top: 16px; font-size: 13.5px; font-weight: 900; }
.learner-ui .mod-pager a { display: inline-flex; align-items: center; gap: 4px; color: var(--brand-dark); }
.learner-ui .mod-continue { margin-top: 14px; }

/* Blok bab — TIDAK di-scope .learner-ui supaya pratinjau admin memakai gaya yang sama. */
.chapter-blocks { color: #374151; }
.chapter-blocks h2 { font-size: 19px; font-weight: 900; color: var(--ink); margin: 22px 0 8px; }
.chapter-blocks h3 { font-size: 16px; font-weight: 900; color: var(--ink); margin: 18px 0 6px; }
.chapter-blocks p { font-size: 15px; line-height: 1.65; margin-bottom: 10px; }
.chapter-blocks ul, .chapter-blocks ol { margin: 0 0 12px 20px; font-size: 15px; line-height: 1.6; }
.chapter-blocks ul { list-style: disc; }
.chapter-blocks ol { list-style: decimal; }
.chapter-blocks a { color: var(--brand); text-decoration: underline; }
.chapter-blocks code { font-family: ui-monospace, Menlo, monospace; font-size: .9em; background: #f1f5f9; border-radius: 6px; padding: 1px 5px; }
.chapter-blocks .cb-table { width: 100%; border-collapse: collapse; margin: 6px 0 14px; font-size: 13.5px; background: #fff; border: 1px solid var(--line); border-radius: 14px; overflow: hidden; }
.chapter-blocks .cb-table th { text-align: left; background: var(--brand-soft); color: var(--brand-dark); font-weight: 900; padding: 9px 11px; }
.chapter-blocks .cb-table td { padding: 9px 11px; border-top: 1px solid var(--line); vertical-align: top; }
.chapter-blocks .cb-img { width: 100%; max-height: 240px; object-fit: cover; border-radius: 16px; margin: 6px 0 12px; }
.chapter-blocks audio { width: 100%; margin: 6px 0 12px; }
.chapter-blocks .cb-phrase { display: flex; align-items: center; gap: 10px; padding: 12px 14px; margin-bottom: 8px; background: #fff; border: 1px solid var(--line); border-radius: 16px; }
.chapter-blocks .cb-phrase-en { font-size: 15px; font-weight: 900; color: var(--ink); }
.chapter-blocks .cb-phrase-id { font-size: 13px; color: var(--muted); margin-top: 2px; }
.chapter-blocks .cb-phrase-note { font-size: 12px; color: var(--muted); font-style: italic; }
.chapter-blocks .cb-speak { display: grid; place-items: center; flex: none; width: 34px; height: 34px; margin-left: auto; border-radius: 50%; background: var(--brand-soft); color: var(--brand); }
.chapter-blocks .cb-dialog { display: flex; flex-direction: column; gap: 8px; margin: 6px 0 14px; }
.chapter-blocks .cb-bubble { max-width: 86%; padding: 10px 13px; border-radius: 18px; font-size: 14px; line-height: 1.45; display: flex; gap: 8px; align-items: flex-end; }
.chapter-blocks .cb-bubble small { display: block; font-size: 10.5px; font-weight: 900; letter-spacing: .6px; text-transform: uppercase; margin-bottom: 2px; }
.chapter-blocks .cb-left { align-self: flex-start; background: #fff; border: 1px solid var(--line); border-bottom-left-radius: 6px; }
.chapter-blocks .cb-left small { color: #0369a1; }
.chapter-blocks .cb-right { align-self: flex-end; background: var(--brand); color: #fff; border-bottom-right-radius: 6px; }
.chapter-blocks .cb-right small { color: #c7d2fe; }
.chapter-blocks .cb-bubble .cb-speak { width: 26px; height: 26px; }
.chapter-blocks .cb-right .cb-speak { background: rgba(255,255,255,.18); color: #fff; }
.chapter-blocks .cb-tip { display: flex; gap: 10px; margin: 12px 0; padding: 12px 14px; border-radius: 16px; background: var(--brand-soft); color: var(--brand-dark); font-size: 14px; line-height: 1.5; }
.chapter-blocks .cb-tip p { font-size: 14px; margin: 0; }
.chapter-blocks .cb-tip p + p { margin-top: 6px; }
```

- [ ] **Step 5: Halaman `/modules`**

```tsx
// apps/web/src/app/(user)/modules/page.tsx
'use client';

/**
 * Tab Modul (spec menu modul §7). GET /modules → kartu "Sedang kamu
 * pelajari" + seksi "Cocok untukmu" (level user) + "Modul lainnya".
 * Skeleton/error meniru Perjalanan.
 */

import { useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { ArrowRight, Check } from 'lucide-react';
import { api } from '@/lib/api';
import type { ModuleCard, ModulesView } from '@/lib/api-types';
import { Card, ChunkyButton } from '@/components/ui';
import { LearningPageSkeleton } from '@/components/learning-companion';
import { ModuleCover } from '@/components/modules/module-cover';
import { LEVEL_LABEL } from '@/lib/modules';
import { useMe } from '@/lib/use-me';

export default function ModulesPage() {
  const { me } = useMe();
  const [data, setData] = useState<ModulesView | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = useCallback(() => {
    setLoading(true);
    setError('');
    api<ModulesView>('/modules')
      .then((d) => setData(d))
      .catch((e) => setError(e instanceof Error ? e.message : 'Terjadi kesalahan'))
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  if (!data && loading) return <LearningPageSkeleton title="Modul" />;

  if (!data) {
    return (
      <div className="flex min-h-screen items-center justify-center px-5">
        <Card eyebrow="Modul" title="Gagal memuat data" className="w-full max-w-sm text-center">
          <p className="mb-4 text-sm font-semibold text-muted">{error || 'Periksa koneksimu, lalu coba lagi.'}</p>
          <ChunkyButton variant="ghost" onClick={load}>Coba lagi</ChunkyButton>
        </Card>
      </div>
    );
  }

  const empty = data.forYou.length + data.others.length === 0;
  const all = [...data.forYou, ...data.others];
  const indexOf = (slug: string) => all.findIndex((m) => m.slug === slug);

  return (
    <div className="learn-page">
      <header className="learn-page-heading">
        <p className="learn-eyebrow">Belajar per topik</p>
        <h1>Modul</h1>
        <p>Baca materi singkat, lalu coba kuisnya.</p>
      </header>

      {empty ? (
        <Card title="Modul sedang disiapkan">
          <p className="mb-4 text-sm font-semibold text-muted">Sementara itu, lanjutkan latihan harianmu.</p>
          <Link className="learn-text-link" href="/home">Ke Beranda <ArrowRight size={17} aria-hidden="true" /></Link>
        </Card>
      ) : null}

      {data.inProgress ? (
        <Card eyebrow="Sedang kamu pelajari" title={data.inProgress.title}>
          <ProgressLine m={data.inProgress} />
          <Link href={`/modules/${data.inProgress.slug}`} className="btn" style={{ display: 'flex', justifyContent: 'center', gap: 8 }}>
            LANJUTKAN <ArrowRight size={18} aria-hidden="true" />
          </Link>
        </Card>
      ) : null}

      {data.forYou.length ? (
        <>
          <p className="mod-section-title">Cocok untukmu · {LEVEL_LABEL[me?.level ?? ''] ?? ''}</p>
          <div className="mod-list">{data.forYou.map((m) => <ModuleRow key={m.slug} m={m} index={indexOf(m.slug)} />)}</div>
        </>
      ) : null}

      {data.others.length ? (
        <>
          <p className="mod-section-title">Modul lainnya</p>
          <div className="mod-list">{data.others.map((m) => <ModuleRow key={m.slug} m={m} index={indexOf(m.slug)} />)}</div>
        </>
      ) : null}
    </div>
  );
}

function ProgressLine({ m }: { m: ModuleCard }) {
  return (
    <div className="mod-progress">
      <div className="mod-bar"><i style={{ width: `${m.quizChapterCount ? (m.doneCount / m.quizChapterCount) * 100 : 0}%` }} /></div>
      <span>{m.doneCount}/{m.quizChapterCount}</span>
    </div>
  );
}

function ModuleRow({ m, index }: { m: ModuleCard; index: number }) {
  const finished = m.quizChapterCount > 0 && m.doneCount === m.quizChapterCount;
  return (
    <Link href={`/modules/${m.slug}`} className="mod-card">
      <ModuleCover url={m.coverUrl} index={index} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <h3>{m.title}</h3>
        <p>{m.summary}</p>
        <div className="mod-meta">
          <span className="mod-chip">{LEVEL_LABEL[m.level]} · {m.cefr}</span>
          {finished ? (
            <span className="mod-chip mod-chip-good"><Check size={13} strokeWidth={2.25} aria-hidden="true" />Selesai</span>
          ) : (
            <span>{m.chapterCount} bab · ±{m.estMinutes} mnt{m.doneCount ? ` · ${m.doneCount}/${m.quizChapterCount} ✓` : ''}</span>
          )}
        </div>
      </div>
    </Link>
  );
}
```

> Bila `LearningPageSkeleton` tidak menerima prop `title`, cek signature di `src/components/learning-companion.tsx` dan sesuaikan (Perjalanan memakainya dengan `title="Perjalanan"`).

- [ ] **Step 6: Verifikasi**

```bash
cd apps/web && npx tsc --noEmit && npm run lint
```
Lalu preview: jalankan dev server api + web (`.claude/launch.json` di workspace; buat bila belum ada dengan konfigurasi `npm run start:dev` di apps/api dan `npm run dev` di apps/web), login user Menengah, buka `/modules`. Expected: kartu modul Keluhan di "Cocok untukmu", nav 5 tab dengan Modul aktif, lebar pill nav pas di viewport 375px (`resize_window` preset mobile). Screenshot.

- [ ] **Step 7: Commit**

```bash
git add src/lib/api-types.ts src/lib/modules.ts src/components/modules src/components/user-nav.tsx src/app/learner.css "src/app/(user)/modules/page.tsx"
git commit -m "feat(modul): tab Modul — daftar modul + nav 5 tab"
```

---

### Task 9: Web — halaman modul & pembaca bab

**Files:**
- Create: `src/lib/speak.ts`, `src/components/modules/chapter-blocks.tsx`, `src/app/(user)/modules/[slug]/page.tsx`, `src/app/(user)/modules/[slug]/[order]/page.tsx`
- Modify: `src/components/session/answer-speak.tsx`

**Interfaces:**
- Consumes: tipe Task 8.
- Produces: `canSpeak(): boolean`, `speakEn(text: string): void`; `<ChapterBlocks blocks={ChapterBlock[]} />`.

- [ ] **Step 1: `speak.ts` + pakai di AnswerSpeak**

```ts
// apps/web/src/lib/speak.ts
/** TTS contoh ucapan — Web Speech API browser, tanpa asset audio. */
export function canSpeak(): boolean {
  return typeof window !== 'undefined' && 'speechSynthesis' in window;
}

export function speakEn(text: string) {
  if (!canSpeak()) return;
  const u = new SpeechSynthesisUtterance(text);
  u.lang = 'en-US';
  u.rate = 0.85;
  window.speechSynthesis.cancel(); // hentikan yang sedang berjalan, ganti yang baru
  window.speechSynthesis.speak(u);
}
```

Di `src/components/session/answer-speak.tsx`: import `{ canSpeak as browserCanSpeak, speakEn } from '@/lib/speak'`; ganti

```ts
  const canSpeak =
    typeof window !== 'undefined' && 'speechSynthesis' in window && !!item.targetText;

  function speakTarget() {
    const u = new SpeechSynthesisUtterance(item.targetText!);
    u.lang = 'en-US';
    u.rate = 0.85;
    window.speechSynthesis.cancel(); // hentikan yang sedang berjalan, ganti yang baru
    window.speechSynthesis.speak(u);
  }
```
menjadi
```ts
  const canSpeak = browserCanSpeak() && !!item.targetText;

  function speakTarget() {
    speakEn(item.targetText!);
  }
```

- [ ] **Step 2: Komponen `ChapterBlocks`**

```tsx
// apps/web/src/components/modules/chapter-blocks.tsx
'use client';

import { Fragment, useEffect, useState } from 'react';
import { Lightbulb, Volume2 } from 'lucide-react';
import type { ChapterBlock, ModuleInline } from '@/lib/api-types';
import { canSpeak, speakEn } from '@/lib/speak';

/** Render blok bab — dipakai pembaca user & pratinjau admin (gaya: .chapter-blocks di learner.css). */
export function ChapterBlocks({ blocks }: { blocks: ChapterBlock[] }) {
  // canSpeak() baru akurat setelah mount (SSR tidak punya window).
  const [tts, setTts] = useState(false);
  useEffect(() => setTts(canSpeak()), []);

  return (
    <div className="chapter-blocks">
      {blocks.map((b, i) => (
        <Block key={i} b={b} tts={tts} />
      ))}
    </div>
  );
}

function Block({ b, tts }: { b: ChapterBlock; tts: boolean }) {
  switch (b.type) {
    case 'heading':
      return b.level === 2 ? <h2><Inline text={b.text} /></h2> : <h3><Inline text={b.text} /></h3>;
    case 'paragraph':
      return <p><Inline text={b.text} /></p>;
    case 'list': {
      const items = b.items.map((it, k) => <li key={k}><Inline text={it} /></li>);
      return b.ordered ? <ol>{items}</ol> : <ul>{items}</ul>;
    }
    case 'table':
      return (
        <table className="cb-table">
          <thead><tr>{b.head.map((h, k) => <th key={k}><Inline text={h} /></th>)}</tr></thead>
          <tbody>{b.rows.map((r, k) => <tr key={k}>{r.map((c, j) => <td key={j}><Inline text={c} /></td>)}</tr>)}</tbody>
        </table>
      );
    case 'image':
      // eslint-disable-next-line @next/next/no-img-element
      return <img className="cb-img" src={b.url} alt={b.alt} />;
    case 'audio':
      return <audio controls preload="none" src={b.url} />;
    case 'phrases':
      return (
        <div>
          {b.items.map((p, k) => (
            <div key={k} className="cb-phrase">
              <div>
                <div className="cb-phrase-en">{p.en}</div>
                <div className="cb-phrase-id">{p.id}</div>
                {p.note ? <div className="cb-phrase-note">{p.note}</div> : null}
              </div>
              {tts ? <SpeakButton text={p.en} /> : null}
            </div>
          ))}
        </div>
      );
    case 'dialog':
      return (
        <div className="cb-dialog">
          {b.lines.map((l, k) => (
            <div key={k} className={`cb-bubble ${l.side === 'left' ? 'cb-left' : 'cb-right'}`}>
              <div>
                <small>{l.speaker}{l.role ? ` · ${l.role}` : ''}</small>
                {l.text}
              </div>
              {tts ? <SpeakButton text={l.text} /> : null}
            </div>
          ))}
        </div>
      );
    case 'tip':
      return (
        <div className="cb-tip">
          <Lightbulb size={20} strokeWidth={2.25} aria-hidden="true" style={{ flex: 'none' }} />
          <div>{b.text.map((t, k) => <p key={k}><Inline text={t} /></p>)}</div>
        </div>
      );
  }
}

function SpeakButton({ text }: { text: string }) {
  return (
    <button type="button" className="cb-speak" aria-label={`Dengarkan: ${text}`} onClick={() => speakEn(text)}>
      <Volume2 size={17} strokeWidth={2.25} />
    </button>
  );
}

function Inline({ text }: { text: ModuleInline }) {
  return (
    <>
      {text.map((s, i) => {
        let node: React.ReactNode = s.t;
        if (s.code) node = <code>{node}</code>;
        if (s.i) node = <em>{node}</em>;
        if (s.b) node = <strong>{node}</strong>;
        if (s.href) node = <a href={s.href} target="_blank" rel="noopener noreferrer">{node}</a>;
        return <Fragment key={i}>{node}</Fragment>;
      })}
    </>
  );
}
```

- [ ] **Step 3: Halaman modul `/modules/[slug]`**

```tsx
// apps/web/src/app/(user)/modules/[slug]/page.tsx
'use client';

import { useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { useParams, useRouter } from 'next/navigation';
import { BookOpenText, Check, ChevronLeft, ChevronRight, Clock } from 'lucide-react';
import { api } from '@/lib/api';
import type { ModuleChapterRow, ModuleDetailView } from '@/lib/api-types';
import { Card, ChunkyButton } from '@/components/ui';
import { LearningPageSkeleton } from '@/components/learning-companion';
import { ModuleCover } from '@/components/modules/module-cover';
import { LEVEL_LABEL } from '@/lib/modules';

export default function ModulePage() {
  const { slug } = useParams<{ slug: string }>();
  const router = useRouter();
  const [m, setM] = useState<ModuleDetailView | null>(null);
  const [error, setError] = useState('');

  const load = useCallback(() => {
    setError('');
    api<ModuleDetailView>(`/modules/${slug}`)
      .then(setM)
      .catch((e) => setError(e instanceof Error ? e.message : 'Terjadi kesalahan'));
  }, [slug]);

  useEffect(() => {
    load();
  }, [load]);

  if (error) {
    return (
      <div className="flex min-h-screen items-center justify-center px-5">
        <Card eyebrow="Modul" title="Modul tidak ditemukan" className="w-full max-w-sm text-center">
          <p className="mb-4 text-sm font-semibold text-muted">Modul ini mungkin sudah ditarik. Pilih modul lain.</p>
          <ChunkyButton variant="ghost" onClick={() => router.push('/modules')}>Ke daftar modul</ChunkyButton>
        </Card>
      </div>
    );
  }
  if (!m) return <LearningPageSkeleton title="Modul" />;

  const allDone = m.quizChapterCount > 0 && m.doneCount === m.quizChapterCount;
  const ctaOrder = m.nextOrder ?? m.chapters[0]?.order ?? 1;
  const ctaLabel = allDone ? 'ULANGI DARI BAB 1' : m.doneCount === 0 ? 'MULAI BAB 1' : `LANJUTKAN BAB ${ctaOrder}`;

  return (
    <div className="learn-page">
      <Link href="/modules" className="mod-back"><ChevronLeft size={18} strokeWidth={2.25} />Modul</Link>
      <ModuleCover url={m.coverUrl} index={0} size={60} />
      <header className="learn-page-heading" style={{ marginTop: 12, marginBottom: 10 }}>
        <h1>{m.title}</h1>
        <p>{m.summary}</p>
      </header>
      <div className="mod-meta">
        <span className="mod-chip">{LEVEL_LABEL[m.level]} · {m.cefr}</span>
        <span className="mod-chip"><Clock size={13} strokeWidth={2.25} aria-hidden="true" />±{m.estMinutes} mnt</span>
      </div>
      {m.quizChapterCount > 0 ? (
        <div className="mod-progress">
          <div className="mod-bar"><i style={{ width: `${(m.doneCount / m.quizChapterCount) * 100}%` }} /></div>
          <span>{m.doneCount} dari {m.quizChapterCount} bab</span>
        </div>
      ) : <div style={{ height: 14 }} />}
      <ChunkyButton onClick={() => router.push(`/modules/${m.slug}/${allDone ? m.chapters[0].order : ctaOrder}`)}>{ctaLabel}</ChunkyButton>

      <p className="mod-section-title">Daftar bab</p>
      <Card className="mod-chapters">
        {m.chapters.map((c) => (
          <ChapterRow key={c.id} c={c} next={c.order === m.nextOrder} href={`/modules/${m.slug}/${c.order}`} />
        ))}
      </Card>
    </div>
  );
}

function ChapterRow({ c, next, href }: { c: ModuleChapterRow; next: boolean; href: string }) {
  const sub = c.kind === 'reading'
    ? `Bacaan · ±${c.estMinutes} mnt`
    : c.done
      ? `Selesai · akurasi ${c.accuracy ?? 0}%`
      : `${next ? 'Berikutnya · ' : ''}±${c.estMinutes} mnt · ${c.itemCount} soal`;
  return (
    <Link href={href} className={`mod-ch${next ? ' mod-ch-next' : ''}`}>
      <span className={`mod-num${c.done ? ' mod-num-done' : next ? ' mod-num-next' : ''}`}>
        {c.done ? <Check size={17} strokeWidth={2.25} aria-label="Selesai" /> : c.kind === 'reading' ? <BookOpenText size={16} strokeWidth={2.25} aria-label="Bacaan" /> : c.order}
      </span>
      <div><b>{c.title}</b><small>{sub}</small></div>
      <ChevronRight size={18} strokeWidth={2.25} className="mod-chev" aria-hidden="true" />
    </Link>
  );
}
```

- [ ] **Step 4: Pembaca bab `/modules/[slug]/[order]`**

```tsx
// apps/web/src/app/(user)/modules/[slug]/[order]/page.tsx
'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { useParams, useRouter } from 'next/navigation';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { api } from '@/lib/api';
import type { ChapterView, SessionView } from '@/lib/api-types';
import { Card, ChunkyButton } from '@/components/ui';
import { LearningPageSkeleton } from '@/components/learning-companion';
import { ChapterBlocks } from '@/components/modules/chapter-blocks';

export default function ChapterPage() {
  const { slug, order } = useParams<{ slug: string; order: string }>();
  const router = useRouter();
  const [ch, setCh] = useState<ChapterView | null>(null);
  const [error, setError] = useState('');
  const [starting, setStarting] = useState(false);
  const [toast, setToast] = useState('');
  const [read, setRead] = useState(0);
  const topRef = useRef<HTMLDivElement>(null);

  const load = useCallback(() => {
    setError('');
    setCh(null);
    api<ChapterView>(`/modules/${slug}/chapters/${order}`)
      .then(setCh)
      .catch((e) => setError(e instanceof Error ? e.message : 'Terjadi kesalahan'));
  }, [slug, order]);

  useEffect(() => {
    load();
    window.scrollTo(0, 0);
  }, [load]);

  // Garis progres baca — murni visual.
  useEffect(() => {
    function onScroll() {
      const max = document.documentElement.scrollHeight - window.innerHeight;
      setRead(max > 0 ? Math.min(100, (window.scrollY / max) * 100) : 100);
    }
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, [ch]);

  useEffect(() => {
    if (!toast) return;
    const t = setTimeout(() => setToast(''), 3000);
    return () => clearTimeout(t);
  }, [toast]);

  async function startQuiz() {
    if (!ch || starting) return;
    setStarting(true);
    try {
      await api<SessionView>('/session/module', { method: 'POST', body: JSON.stringify({ chapterId: ch.id }) });
      router.push(`/session?module=${ch.id}`);
    } catch (e) {
      setToast(e instanceof Error ? e.message : 'Terjadi kesalahan');
      setStarting(false);
    }
  }

  if (error) {
    return (
      <div className="flex min-h-screen items-center justify-center px-5">
        <Card eyebrow="Modul" title="Bab tidak ditemukan" className="w-full max-w-sm text-center">
          <p className="mb-4 text-sm font-semibold text-muted">Urutan bab mungkin sudah berubah.</p>
          <ChunkyButton variant="ghost" onClick={() => router.push(`/modules/${slug}`)}>Kembali ke modul</ChunkyButton>
        </Card>
      </div>
    );
  }
  if (!ch) return <LearningPageSkeleton title="Bab" />;

  return (
    <div className="learn-page" ref={topRef}>
      <div className="mod-reader-top">
        <div>
          <Link href={`/modules/${ch.moduleSlug}`} className="mod-back" style={{ margin: 0 }}><ChevronLeft size={18} strokeWidth={2.25} />Kembali</Link>
          <span>Bab {ch.order} dari {ch.chapterCount}</span>
        </div>
        <div className="mod-readbar" aria-hidden="true"><i style={{ width: `${read}%` }} /></div>
      </div>

      <p className="learn-eyebrow" style={{ marginTop: 20 }}>Bab {ch.order}</p>
      <h1 style={{ fontSize: 24, fontWeight: 900, lineHeight: 1.2, margin: '4px 0 10px' }}>{ch.title}</h1>
      <ChapterBlocks blocks={ch.blocks} />

      {ch.quiz ? (
        <div className="mod-quiz">
          <p className="learn-eyebrow">{ch.quiz.done ? 'Sudah selesai' : 'Coba yang barusan'}</p>
          <h4>Kuis Bab {ch.order}</h4>
          <p className="mb-3.5 text-[12.5px] font-bold text-muted">
            {ch.quiz.itemCount} soal · ±{Math.max(1, Math.ceil(ch.quiz.itemCount * 0.75))} mnt
            {ch.quiz.estXp !== null ? ` · +${ch.quiz.estXp} XP · dihitung ke target harian` : ' · ulangan, XP percobaan ulang'}
          </p>
          <ChunkyButton variant={ch.quiz.done ? 'ghost' : 'brand'} onClick={startQuiz} disabled={starting} aria-busy={starting}>
            {starting ? 'Menyiapkan…' : ch.quiz.done ? 'ULANGI KUIS' : 'MULAI KUIS'}
          </ChunkyButton>
        </div>
      ) : ch.nextOrder !== null ? (
        <div className="mod-continue">
          <ChunkyButton onClick={() => router.push(`/modules/${ch.moduleSlug}/${ch.nextOrder}`)}>BAB BERIKUTNYA</ChunkyButton>
        </div>
      ) : null}

      <nav className="mod-pager" aria-label="Navigasi bab">
        {ch.prevOrder !== null ? <Link href={`/modules/${ch.moduleSlug}/${ch.prevOrder}`}><ChevronLeft size={16} />Bab sebelumnya</Link> : <span />}
        {ch.nextOrder !== null ? <Link href={`/modules/${ch.moduleSlug}/${ch.nextOrder}`}>Bab berikutnya<ChevronRight size={16} /></Link> : <span />}
      </nav>

      {toast ? <div className="toast" role="status">{toast}</div> : null}
    </div>
  );
}
```

- [ ] **Step 5: Verifikasi**

`npx tsc --noEmit && npm run lint`, lalu preview: `/modules/making-handling-complaints` → daftar 11 bab; buka Bab 4 → kartu frasa + 🔊 (klik, cek tidak ada error console), dialog kiri/kanan, tip, kartu kuis, pager. Bab 3 → tabel rapi di 375px tanpa scroll horizontal halaman (`resize_window` mobile). Slug salah → kartu "Modul tidak ditemukan". Screenshot.

- [ ] **Step 6: Commit**

```bash
git add src/lib/speak.ts src/components/modules/chapter-blocks.tsx src/components/session/answer-speak.tsx "src/app/(user)/modules"
git commit -m "feat(modul): halaman modul + pembaca bab (frasa, dialog, tip, TTS)"
```

---

### Task 10: Web — sesi kuis bab & kartu Beranda

**Files:**
- Modify: `src/components/session/use-session.ts`, `src/app/(user)/session/page.tsx`, `src/components/home-content.tsx`

**Interfaces:**
- Consumes: `POST /session/module`, `SessionView.moduleSlug`, `SummaryView.moduleInProgress`.
- Produces: `useSession(replayLessonId, speaking, moduleChapterId)`.

- [ ] **Step 1: `useSession` mengenali kuis bab**

Di `src/components/session/use-session.ts`:
- signature: `export function useSession(replayLessonId: string | null, speaking = false, moduleChapterId: string | null = null): UseSessionResult {`
- `load`:
```ts
      const path = replayLessonId
        ? '/session/replay'
        : moduleChapterId
          ? '/session/module'
          : speaking
            ? '/session/speaking'
            : '/session/today';
      const body = replayLessonId
        ? JSON.stringify({ lessonId: replayLessonId })
        : moduleChapterId
          ? JSON.stringify({ chapterId: moduleChapterId })
          : undefined;
      const nextView = await api<SessionView>(path, { method: 'POST', body });
```
- deps `load`: `[replayLessonId, speaking, moduleChapterId]`
- effect key: `const key = replayLessonId ?? (moduleChapterId ? \`module:${moduleChapterId}\` : speaking ? 'speaking' : '');` dan deps `[replayLessonId, speaking, moduleChapterId, load]`.

- [ ] **Step 2: Halaman sesi kembali ke modul**

Di `src/app/(user)/session/page.tsx`:
- `SessionHeader` terima prop `exitHref: string` dan `onClick={() => router.push(exitHref)}`.
- `SessionBody`: `const moduleChapterId = searchParams.get('module');` → `useSession(replayLessonId, speaking, moduleChapterId)`; ambil juga `view` dari hook.
- `const exitHref = view?.moduleSlug ? \`/modules/${view.moduleSlug}\` : '/home';`
- `Celebrate … onContinue={() => router.push(exitHref)}`; `<SessionHeader … exitHref={exitHref} />`.

- [ ] **Step 3: Kartu "Lanjutkan modul" di Beranda**

Di `src/components/home-content.tsx`: import `BookOpenText`; setelah `<Hero …/>` dan sebelum `<section className="learn-practice"…>` tambahkan:

```tsx
    {summary.moduleInProgress && <Link className="learn-review" href={`/modules/${summary.moduleInProgress.slug}/${summary.moduleInProgress.nextOrder}`}>
      <BookOpenText size={22} aria-hidden="true" style={{ color: 'var(--brand)' }} /><span><b>Lanjutkan modul</b><small>{summary.moduleInProgress.title} · Bab {summary.moduleInProgress.nextOrder} berikutnya</small></span><ChevronRight size={18} aria-hidden="true" />
    </Link>}
```

(`.learn-review` sudah bergaya kartu baris; ikon pertama di-override ke warna brand inline karena gaya default ikon pertama amber untuk review.)

- [ ] **Step 4: Verifikasi end-to-end di browser**

`npx tsc --noEmit && npm run lint`, lalu preview dengan user Menengah baru: Bab 1 → MULAI KUIS → sesi tampil (tanpa nav) → jawab semua → perayaan → LANJUT kembali ke `/modules/making-handling-complaints` dengan Bab 1 ✓ dan Bab 2 tersorot. ✕ di tengah kuis juga kembali ke halaman modul. Beranda: kartu "Lanjutkan modul · Bab 2 berikutnya" muncul; target harian bertambah 1. Cek `read_console_messages` bersih. Screenshot halaman modul setelah selesai.

- [ ] **Step 5: Commit**

```bash
git add src/components/session/use-session.ts "src/app/(user)/session/page.tsx" src/components/home-content.tsx
git commit -m "feat(modul): kuis bab di layar sesi + kembali ke modul + kartu Lanjutkan modul"
```

---

### Task 11: Web admin — daftar & detail modul

**Files:**
- Create: `src/app/admin/modul/types.ts`, `src/app/admin/modul/page.tsx`, `src/app/admin/modul/[id]/page.tsx`
- Modify: `src/app/admin/layout.tsx`, `src/app/admin/content/page.tsx`

**Interfaces:**
- Consumes: endpoint admin Task 4.
- Produces: tipe `AdminModuleRow`, `AdminModuleDetail`, `AdminChapterDetail`, `AdminLessonSummary` di `types.ts` (dipakai Task 12).

- [ ] **Step 1: Tipe admin**

```ts
// apps/web/src/app/admin/modul/types.ts
import type { ChapterBlock } from '@/lib/api-types';

export const LEVELS = ['DASAR', 'MENENGAH', 'MAHIR'] as const;
export const CEFRS = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'] as const;

export interface AdminModuleRow {
  id: string;
  slug: string;
  title: string;
  level: string;
  cefr: string;
  status: string;
  order: number;
  updatedAt: string;
  chapterCount: number;
  quizChapterCount: number;
  pendingQuizCount: number;
  readingCount: number;
}

export interface AdminLessonSummary {
  id: string;
  code: string;
  title: string;
  status: string;
  liveItemCount: number;
  draftItemCount: number;
}

export interface AdminModuleDetail {
  id: string;
  slug: string;
  title: string;
  summary: string;
  level: string;
  cefr: string;
  coverFile: string | null;
  coverUrl: string | null;
  order: number;
  status: string;
  chapters: { id: string; order: number; title: string; estMinutes: number; lesson: AdminLessonSummary | null }[];
}

export interface AdminChapterDetail {
  id: string;
  order: number;
  title: string;
  estMinutes: number;
  body: string;
  blocks: ChapterBlock[];
  module: { id: string; title: string; slug: string; status: string };
  lesson: AdminLessonSummary | null;
}

export type PreviewResult = { blocks: ChapterBlock[] } | { errors: { line: number; message: string }[] };
```

- [ ] **Step 2: Sidebar**

`src/app/admin/layout.tsx`: import `BookOpenText`; di grup `Konten` jadikan item pertama `{ label: 'Modul', href: '/admin/modul', icon: BookOpenText },`.

- [ ] **Step 3: Daftar modul `/admin/modul`**

```tsx
// apps/web/src/app/admin/modul/page.tsx
'use client';

import { useCallback, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Plus } from 'lucide-react';
import { api } from '@/lib/api';
import { ChunkyButton, StatusPill } from '@/components/ui';
import { CEFRS, LEVELS, type AdminModuleRow } from './types';

export default function AdminModulesPage() {
  const router = useRouter();
  const [rows, setRows] = useState<AdminModuleRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [level, setLevel] = useState('');
  const [status, setStatus] = useState('');
  const [creating, setCreating] = useState(false);
  const [form, setForm] = useState({ title: '', summary: '', level: 'MENENGAH', cefr: 'B1' });
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const qs = new URLSearchParams();
      if (level) qs.set('level', level);
      if (status) qs.set('status', status);
      setRows(await api<AdminModuleRow[]>(`/admin/modules${qs.toString() ? `?${qs}` : ''}`));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Terjadi kesalahan');
    } finally {
      setLoading(false);
    }
  }, [level, status]);

  useEffect(() => {
    load();
  }, [load]);

  async function create() {
    setSaving(true);
    setError('');
    try {
      const m = await api<{ id: string }>('/admin/modules', { method: 'POST', body: JSON.stringify(form) });
      router.push(`/admin/modul/${m.id}`);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Terjadi kesalahan');
      setSaving(false);
    }
  }

  const select = 'rounded-xl border border-line px-3 py-1.5 text-sm font-semibold text-ink focus:border-brand focus:outline-none';
  const input = 'w-full rounded-xl border-2 border-line px-3 py-2 text-sm font-semibold text-ink focus:border-brand focus:outline-none';

  return (
    <div>
      <div className="mb-6 flex items-start justify-between gap-4">
        <div>
          <h1 className="mb-1 text-xl font-black text-ink">Modul</h1>
          <p className="text-sm font-semibold text-muted">Materi bacaan per topik. Tiap bab bisa punya kuis dari lesson.</p>
        </div>
        <ChunkyButton className="btn-sm" onClick={() => setCreating((v) => !v)}><Plus size={16} strokeWidth={2.25} /> Modul baru</ChunkyButton>
      </div>

      {creating ? (
        <div className="admin-card mb-5 grid grid-cols-1 gap-3 rounded-2xl border border-line bg-white p-4 md:grid-cols-4">
          <label className="md:col-span-2 text-xs font-black uppercase tracking-wider text-muted">Judul
            <input className={input} value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
          </label>
          <label className="text-xs font-black uppercase tracking-wider text-muted">Level
            <select className={input} value={form.level} onChange={(e) => setForm({ ...form, level: e.target.value })}>{LEVELS.map((l) => <option key={l}>{l}</option>)}</select>
          </label>
          <label className="text-xs font-black uppercase tracking-wider text-muted">CEFR
            <select className={input} value={form.cefr} onChange={(e) => setForm({ ...form, cefr: e.target.value })}>{CEFRS.map((c) => <option key={c}>{c}</option>)}</select>
          </label>
          <label className="md:col-span-3 text-xs font-black uppercase tracking-wider text-muted">Ringkasan (1 kalimat)
            <input className={input} value={form.summary} onChange={(e) => setForm({ ...form, summary: e.target.value })} />
          </label>
          <div className="flex items-end"><ChunkyButton className="btn-sm w-full" disabled={saving} onClick={create}>{saving ? 'Menyimpan…' : 'Buat modul'}</ChunkyButton></div>
        </div>
      ) : null}

      <div className="mb-4 flex items-center gap-3">
        <select value={level} onChange={(e) => setLevel(e.target.value)} className={select}>
          <option value="">Semua level</option>
          {LEVELS.map((l) => <option key={l} value={l}>{l}</option>)}
        </select>
        <select value={status} onChange={(e) => setStatus(e.target.value)} className={select}>
          <option value="">Semua status</option>
          {['DRAFT', 'LIVE', 'RETIRED'].map((s) => <option key={s} value={s}>{s}</option>)}
        </select>
        <button type="button" onClick={load} disabled={loading} className="btn-outline-sm">{loading ? 'Memuat...' : 'Muat ulang'}</button>
      </div>

      {error && <p className="mb-4 text-sm font-semibold text-bad">{error}</p>}

      <div className="admin-table-wrap">
        <table className="admin-table">
          <thead>
            <tr><th>#</th><th>Modul</th><th>Level/CEFR</th><th>Bab</th><th>Status</th><th>Diubah</th></tr>
          </thead>
          <tbody>
            {rows.length === 0 && !loading && (
              <tr><td colSpan={6} className="text-center text-muted">Belum ada modul.</td></tr>
            )}
            {rows.map((m) => (
              <tr key={m.id} onClick={() => router.push(`/admin/modul/${m.id}`)} className="admin-table-row-clickable">
                <td className="text-muted">{m.order}</td>
                <td><div className="font-bold">{m.title}</div><div className="text-xs text-muted">{m.slug}</div></td>
                <td className="text-muted">{m.level} / {m.cefr}</td>
                <td>
                  <div className="font-bold">{m.chapterCount}</div>
                  <div className="text-xs text-muted">
                    {m.chapterCount === 0
                      ? 'Belum ada bab — tidak tampil walau LIVE'
                      : [
                          m.quizChapterCount ? `${m.quizChapterCount} berkuis` : '',
                          m.readingCount ? `${m.readingCount} bacaan` : '',
                          m.pendingQuizCount ? `${m.pendingQuizCount} kuis belum siap` : '',
                        ].filter(Boolean).join(' · ')}
                  </div>
                </td>
                <td><StatusPill status={m.status} /></td>
                <td className="text-muted">{new Date(m.updatedAt).toLocaleDateString('id-ID', { day: 'numeric', month: 'short' })}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Detail modul `/admin/modul/[id]`**

```tsx
// apps/web/src/app/admin/modul/[id]/page.tsx
'use client';

import { useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { useParams, useRouter } from 'next/navigation';
import { ChevronDown, ChevronRight, ChevronUp, Plus } from 'lucide-react';
import { api } from '@/lib/api';
import { ChunkyButton, StatusPill } from '@/components/ui';
import { CEFRS, LEVELS, type AdminModuleDetail } from '../types';

const NEW_CHAPTER_BODY = 'Tulis pengantar bab di sini.';

export default function AdminModuleDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const [m, setM] = useState<AdminModuleDetail | null>(null);
  const [form, setForm] = useState({ title: '', slug: '', summary: '', level: '', cefr: '', coverFile: '' });
  const [media, setMedia] = useState<string[]>([]);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  const apply = (d: AdminModuleDetail) => {
    setM(d);
    setForm({ title: d.title, slug: d.slug, summary: d.summary, level: d.level, cefr: d.cefr, coverFile: d.coverFile ?? '' });
  };

  const load = useCallback(() => {
    api<AdminModuleDetail>(`/admin/modules/${id}`).then(apply).catch((e) => setError(e instanceof Error ? e.message : 'Terjadi kesalahan'));
    api<{ name: string }[]>('/admin/media').then((xs) => setMedia(xs.map((x) => x.name).filter((n) => /\.(png|jpe?g|webp|svg)$/i.test(n)))).catch(() => setMedia([]));
  }, [id]);

  useEffect(() => {
    load();
  }, [load]);

  async function run(fn: () => Promise<AdminModuleDetail | void>) {
    setBusy(true);
    setError('');
    try {
      const d = await fn();
      if (d) apply(d);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Terjadi kesalahan');
    } finally {
      setBusy(false);
    }
  }

  const save = () => run(() => api<AdminModuleDetail>(`/admin/modules/${id}`, { method: 'PATCH', body: JSON.stringify({ ...form, coverFile: form.coverFile || null }) }));
  const transition = (status: string) => {
    if (status === 'RETIRED' && !confirm('Modul pensiun tidak bisa dihidupkan lagi. Lanjut?')) return;
    run(() => api<AdminModuleDetail>(`/admin/modules/${id}`, { method: 'PATCH', body: JSON.stringify({ status }) }));
  };
  const move = (chapterId: string, direction: 'up' | 'down') =>
    run(() => api<AdminModuleDetail>(`/admin/chapters/${chapterId}/move`, { method: 'POST', body: JSON.stringify({ direction }) }));
  const addChapter = () =>
    run(async () => {
      const c = await api<{ id: string }>(`/admin/modules/${id}/chapters`, { method: 'POST', body: JSON.stringify({ title: 'Bab baru', estMinutes: 5, body: NEW_CHAPTER_BODY }) });
      router.push(`/admin/modul/${id}/bab/${c.id}`);
    });

  if (!m) return <p className="text-sm font-semibold text-muted">{error || 'Memuat…'}</p>;

  const input = 'w-full rounded-xl border-2 border-line px-3 py-2 text-sm font-semibold text-ink focus:border-brand focus:outline-none';
  const label = 'text-xs font-black uppercase tracking-wider text-muted';

  return (
    <div>
      <div className="mb-2 flex items-center gap-1.5 text-sm font-bold text-muted">
        <Link href="/admin/modul">Modul</Link><ChevronRight size={14} /> {m.title}
      </div>
      <div className="mb-4 flex items-start justify-between gap-4">
        <div>
          <h1 className="mb-1 text-xl font-black text-ink">{m.title}</h1>
          <p className="text-sm font-semibold text-muted">Status <StatusPill status={m.status} /> · tampil ke semua karyawan bila LIVE dan punya ≥1 bab</p>
        </div>
        <div className="flex gap-2">
          {m.status === 'DRAFT' && <ChunkyButton variant="good" className="btn-sm" disabled={busy} onClick={() => transition('LIVE')}>Terbitkan</ChunkyButton>}
          {m.status === 'LIVE' && <ChunkyButton variant="ghost" className="btn-sm" disabled={busy} onClick={() => transition('DRAFT')}>Jadikan DRAFT</ChunkyButton>}
          {m.status === 'LIVE' && <ChunkyButton variant="danger" className="btn-sm" disabled={busy} onClick={() => transition('RETIRED')}>Pensiunkan</ChunkyButton>}
          <ChunkyButton className="btn-sm" disabled={busy} onClick={save}>Simpan</ChunkyButton>
        </div>
      </div>

      {error && <p className="mb-4 text-sm font-semibold text-bad">{error}</p>}

      <div className="mb-6 grid grid-cols-1 gap-3 rounded-2xl border border-line bg-white p-4 md:grid-cols-3">
        <label className={label}>Judul<input className={input} value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} /></label>
        <label className={label}>Level<select className={input} value={form.level} onChange={(e) => setForm({ ...form, level: e.target.value })}>{LEVELS.map((l) => <option key={l}>{l}</option>)}</select></label>
        <label className={label}>CEFR<select className={input} value={form.cefr} onChange={(e) => setForm({ ...form, cefr: e.target.value })}>{CEFRS.map((c) => <option key={c}>{c}</option>)}</select></label>
        <label className={`${label} md:col-span-2`}>Ringkasan (1 kalimat)<input className={input} value={form.summary} onChange={(e) => setForm({ ...form, summary: e.target.value })} /></label>
        <label className={label}>Slug<input className={input} value={form.slug} onChange={(e) => setForm({ ...form, slug: e.target.value })} /></label>
        <label className={`${label} md:col-span-3`}>Cover (dari Media)
          <select className={input} value={form.coverFile} onChange={(e) => setForm({ ...form, coverFile: e.target.value })}>
            <option value="">Tanpa cover (ikon default)</option>
            {media.map((n) => <option key={n} value={n}>{n}</option>)}
          </select>
        </label>
      </div>

      <div className="mb-3 flex items-center justify-between">
        <h2 className="text-base font-black text-ink">Bab <span className="text-muted">· {m.chapters.length}</span></h2>
        <ChunkyButton className="btn-sm" disabled={busy} onClick={addChapter}><Plus size={16} strokeWidth={2.25} /> Bab baru</ChunkyButton>
      </div>
      <div className="admin-table-wrap">
        <table className="admin-table">
          <thead><tr><th>Urut</th><th>Bab</th><th>Menit</th><th>Kuis</th></tr></thead>
          <tbody>
            {m.chapters.length === 0 && <tr><td colSpan={4} className="text-center text-muted">Belum ada bab.</td></tr>}
            {m.chapters.map((c, i) => (
              <tr key={c.id} className="admin-table-row-clickable" onClick={() => router.push(`/admin/modul/${id}/bab/${c.id}`)}>
                <td onClick={(e) => e.stopPropagation()}>
                  <div className="flex flex-col gap-0.5">
                    <button type="button" aria-label="Naikkan" className="btn-outline-sm" disabled={busy || i === 0} onClick={() => move(c.id, 'up')}><ChevronUp size={13} /></button>
                    <button type="button" aria-label="Turunkan" className="btn-outline-sm" disabled={busy || i === m.chapters.length - 1} onClick={() => move(c.id, 'down')}><ChevronDown size={13} /></button>
                  </div>
                </td>
                <td className="font-bold">{c.order} · {c.title}</td>
                <td className="text-muted">±{c.estMinutes}</td>
                <td><QuizChip lesson={c.lesson} /></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function QuizChip({ lesson }: { lesson: AdminModuleDetail['chapters'][number]['lesson'] }) {
  if (!lesson) return <span className="status-pill status-pill-draft">Bacaan saja</span>;
  const ready = lesson.status === 'LIVE' && lesson.liveItemCount > 0;
  return ready
    ? <span className="status-pill status-pill-live">{lesson.code} · {lesson.liveItemCount} soal LIVE</span>
    : <span className="status-pill status-pill-employee-butuh-perhatian">{lesson.code} · belum siap → tampil sebagai Bacaan</span>;
}
```

- [ ] **Step 5: Badge di Soal & Lesson**

`src/app/admin/content/page.tsx`: tambah `moduleChapter: { moduleTitle: string; order: number } | null;` ke `LessonListItem`, dan di sel Judul:

```tsx
                <td>
                  {l.title}
                  {l.moduleChapter ? (
                    <div className="text-xs font-bold text-brand">Kuis modul: {l.moduleChapter.moduleTitle} · Bab {l.moduleChapter.order}</div>
                  ) : null}
                </td>
```

- [ ] **Step 6: Verifikasi**

`npx tsc --noEmit && npm run lint`; preview login admin → sidebar "Modul" teratas di KONTEN → daftar menampilkan modul Keluhan (11 bab · 11 berkuis) → buka detail → ubah ringkasan + Simpan → ↑/↓ menukar urutan (lalu kembalikan) → "Soal & Lesson" menampilkan badge di CMP-201. Buat modul uji "Coba" → Bab baru → diarahkan ke editor (404 dulu sampai Task 12 — wajar). Screenshot daftar & detail.

- [ ] **Step 7: Commit**

```bash
git add src/app/admin/modul src/app/admin/layout.tsx src/app/admin/content/page.tsx
git commit -m "feat(admin): menu Modul — daftar, detail, urutan bab, badge kuis di lesson"
```

---

### Task 12: Web admin — editor bab (Markdown + pratinjau + kuis)

**Files:**
- Create: `src/app/admin/modul/[id]/bab/[chapterId]/page.tsx`
- Modify: `src/app/globals.css`

**Interfaces:**
- Consumes: `AdminChapterDetail`, `PreviewResult` (Task 11), `ChapterBlocks` (Task 9), endpoint Task 4.

- [ ] **Step 1: CSS editor (akhir `globals.css`)**

```css
/* ---- Editor bab modul (admin) ---- */
.chap-editor { display: grid; grid-template-columns: minmax(0, 1fr) 400px; gap: 16px; align-items: start; }
@media (max-width: 1100px) { .chap-editor { grid-template-columns: minmax(0, 1fr); } }
.chap-pane { background: #fff; border: 1px solid var(--line); border-radius: 20px; overflow: hidden; }
.chap-pane-title { display: flex; justify-content: space-between; padding: 10px 14px; border-bottom: 1px solid var(--line); font-size: 11px; font-weight: 900; letter-spacing: .8px; text-transform: uppercase; color: var(--muted); }
.chap-code { display: flex; height: 560px; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 12.5px; line-height: 1.75; }
.chap-gutter { flex: none; width: 44px; padding: 10px 10px 10px 0; text-align: right; color: #cbd5e1; background: #fafbfc; overflow: hidden; user-select: none; white-space: pre; }
.chap-gutter .err { color: var(--bad); font-weight: 800; }
.chap-textarea { flex: 1; resize: none; border: 0; outline: none; padding: 10px 12px; font: inherit; color: #334155; white-space: pre; overflow: auto; }
.chap-errors { border-top: 1.5px solid var(--bad); background: var(--bad-soft, #fef2f2); color: var(--bad-dark, #b91c1c); padding: 10px 14px; font-size: 13px; font-weight: 800; }
.chap-errors li + li { margin-top: 2px; }
.chap-preview { height: 520px; overflow: auto; background: var(--bg); padding: 16px; }
.chap-preview-frame { max-width: 375px; margin: 0 auto; }
.chap-cheat { font-size: 12.5px; }
.chap-cheat pre { font-family: ui-monospace, Menlo, monospace; font-size: 11.5px; background: var(--bg); border: 1px solid var(--line); border-radius: 10px; padding: 8px 10px; margin: 4px 0 10px; white-space: pre-wrap; }
```

- [ ] **Step 2: Halaman editor**

```tsx
// apps/web/src/app/admin/modul/[id]/bab/[chapterId]/page.tsx
'use client';

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import { useParams, useRouter } from 'next/navigation';
import { ChevronRight, HelpCircle, ListChecks } from 'lucide-react';
import { api } from '@/lib/api';
import type { ChapterBlock } from '@/lib/api-types';
import { ChunkyButton } from '@/components/ui';
import { ChapterBlocks } from '@/components/modules/chapter-blocks';
import type { AdminChapterDetail, PreviewResult } from '../../../types';

interface LessonOption { id: string; code: string; title: string; moduleChapter: unknown }

export default function ChapterEditorPage() {
  const { id: moduleId, chapterId } = useParams<{ id: string; chapterId: string }>();
  const router = useRouter();
  const [ch, setCh] = useState<AdminChapterDetail | null>(null);
  const [title, setTitle] = useState('');
  const [minutes, setMinutes] = useState(5);
  const [body, setBody] = useState('');
  const [blocks, setBlocks] = useState<ChapterBlock[]>([]);
  const [errors, setErrors] = useState<{ line: number; message: string }[]>([]);
  const [dirty, setDirty] = useState(false);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState('');
  const [cheat, setCheat] = useState(false);
  const [lessons, setLessons] = useState<LessonOption[]>([]);
  const [pick, setPick] = useState('');
  const gutterRef = useRef<HTMLDivElement>(null);

  const apply = (c: AdminChapterDetail) => {
    setCh(c);
    setTitle(c.title);
    setMinutes(c.estMinutes);
    setBody(c.body);
    setBlocks(c.blocks);
    setErrors([]);
    setDirty(false);
  };

  useEffect(() => {
    api<AdminChapterDetail>(`/admin/chapters/${chapterId}`).then(apply).catch((e) => setMsg(e instanceof Error ? e.message : 'Terjadi kesalahan'));
    api<LessonOption[]>('/admin/lessons').then((ls) => setLessons(ls.filter((l) => !l.moduleChapter))).catch(() => setLessons([]));
  }, [chapterId]);

  // Pratinjau: parser BE yang sama dengan simpan (debounce 500 ms).
  useEffect(() => {
    if (!dirty) return;
    const t = setTimeout(() => {
      api<PreviewResult>('/admin/modules/preview', { method: 'POST', body: JSON.stringify({ body }) })
        .then((r) => {
          if ('blocks' in r) {
            setBlocks(r.blocks);
            setErrors([]);
          } else setErrors(r.errors); // pratinjau tetap versi valid terakhir
        })
        .catch(() => {});
    }, 500);
    return () => clearTimeout(t);
  }, [body, dirty]);

  const save = useCallback(async () => {
    if (saving || errors.length) return;
    setSaving(true);
    setMsg('');
    try {
      apply(await api<AdminChapterDetail>(`/admin/chapters/${chapterId}`, { method: 'PATCH', body: JSON.stringify({ title, estMinutes: minutes, body }) }));
      setMsg('Tersimpan');
    } catch (e) {
      setMsg(e instanceof Error ? e.message : 'Terjadi kesalahan');
    } finally {
      setSaving(false);
    }
  }, [saving, errors.length, chapterId, title, minutes, body]);

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 's') {
        e.preventDefault();
        save();
      }
    }
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [save]);

  async function quizAction(fn: () => Promise<unknown>) {
    setMsg('');
    try {
      await fn();
      apply(await api<AdminChapterDetail>(`/admin/chapters/${chapterId}`));
    } catch (e) {
      setMsg(e instanceof Error ? e.message : 'Terjadi kesalahan');
    }
  }

  async function remove() {
    if (!confirm('Hapus bab ini? Hanya bisa selama modul DRAFT dan bab belum pernah dikerjakan.')) return;
    try {
      await api(`/admin/chapters/${chapterId}`, { method: 'DELETE' });
      router.push(`/admin/modul/${moduleId}`);
    } catch (e) {
      setMsg(e instanceof Error ? e.message : 'Terjadi kesalahan');
    }
  }

  const lineCount = useMemo(() => body.split('\n').length, [body]);
  const errLines = useMemo(() => new Set(errors.map((e) => e.line)), [errors]);

  if (!ch) return <p className="text-sm font-semibold text-muted">{msg || 'Memuat…'}</p>;

  const lesson = ch.lesson;
  const input = 'rounded-xl border-2 border-line px-3 py-2 text-sm font-bold text-ink focus:border-brand focus:outline-none';

  return (
    <div>
      <div className="mb-2 flex items-center gap-1.5 text-sm font-bold text-muted">
        <Link href="/admin/modul">Modul</Link><ChevronRight size={14} />
        <Link href={`/admin/modul/${moduleId}`}>{ch.module.title}</Link><ChevronRight size={14} /> Bab {ch.order}
      </div>

      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div className="flex gap-2">
          <input className={`${input} w-80`} value={title} aria-label="Judul bab" onChange={(e) => { setTitle(e.target.value); setDirty(true); }} />
          <label className="flex items-center gap-2 text-sm font-bold text-muted">±
            <input className={`${input} w-20`} type="number" min={1} max={60} value={minutes} aria-label="Estimasi menit" onChange={(e) => { setMinutes(Number(e.target.value)); setDirty(true); }} />
            menit
          </label>
        </div>
        <div className="flex items-center gap-2">
          {msg && <span className={`text-sm font-bold ${msg === 'Tersimpan' ? 'text-good' : 'text-bad'}`}>{msg}</span>}
          <button type="button" className="btn-outline-sm" onClick={() => setCheat((v) => !v)}><HelpCircle size={14} /> Sintaks</button>
          <button type="button" className="btn-outline-sm" onClick={remove}>Hapus bab</button>
          <ChunkyButton className="btn-sm" disabled={saving || errors.length > 0 || !dirty} onClick={save}>{saving ? 'Menyimpan…' : 'Simpan'}</ChunkyButton>
        </div>
      </div>

      {cheat ? (
        <div className="chap-cheat mb-4 rounded-2xl border border-line bg-white p-4">
          <b>Blok khusus</b>
          <pre>{':::phrases\n- Could you help me? | Bisa bantu saya?\n- Sorry. | Maaf. | catatan opsional\n:::'}</pre>
          <pre>{':::dialog\nRina (Finance): The invoice is wrong.\nKamu (IT Support): Which invoice is it?\n:::'}</pre>
          <pre>{':::tip\n"Could you…" lebih sopan daripada "Can you…".\n:::'}</pre>
          <b>Markdown biasa</b>: <code>## Judul</code>, <code>**tebal**</code>, <code>*miring*</code>, daftar <code>- a</code> / <code>1. a</code>, tabel <code>| a | b |</code>, gambar/audio <code>![keterangan](media:nama-file.png)</code> (upload dulu di Media).
        </div>
      ) : null}

      <div className="chap-editor">
        <div className="chap-pane">
          <div className="chap-pane-title"><span>Markdown</span><span style={{ textTransform: 'none', letterSpacing: 0 }}>Ctrl/Cmd+S simpan</span></div>
          <div className="chap-code">
            <div className="chap-gutter" ref={gutterRef} aria-hidden="true">
              {Array.from({ length: lineCount }, (_, k) => (
                <div key={k} className={errLines.has(k + 1) ? 'err' : undefined}>{k + 1}</div>
              ))}
            </div>
            <textarea
              className="chap-textarea"
              value={body}
              spellCheck={false}
              aria-label="Isi bab (Markdown)"
              onScroll={(e) => { if (gutterRef.current) gutterRef.current.scrollTop = e.currentTarget.scrollTop; }}
              onChange={(e) => { setBody(e.target.value); setDirty(true); }}
            />
          </div>
          {errors.length ? (
            <ul className="chap-errors" role="alert">
              {errors.map((e, k) => <li key={k}>Baris {e.line}: {e.message}</li>)}
            </ul>
          ) : null}
        </div>

        <div className="flex flex-col gap-4">
          <div className="chap-pane">
            <div className="chap-pane-title"><span>Pratinjau · 375px</span><span style={{ textTransform: 'none', letterSpacing: 0 }}>{errors.length ? 'versi valid terakhir' : 'parser BE'}</span></div>
            <div className="chap-preview">
              <div className="chap-preview-frame">
                <p style={{ fontSize: 11, fontWeight: 800, letterSpacing: 1, textTransform: 'uppercase', color: 'var(--brand)' }}>Bab {ch.order}</p>
                <h3 style={{ fontSize: 20, fontWeight: 900, margin: '2px 0 8px' }}>{title}</h3>
                <ChapterBlocks blocks={blocks} />
              </div>
            </div>
          </div>

          <div className="chap-pane p-4">
            <div className="mb-2 flex items-center gap-2 text-xs font-black uppercase tracking-wider text-muted"><ListChecks size={16} /> Kuis bab</div>
            {lesson ? (
              <>
                <div className="font-black text-ink">{lesson.code} · {lesson.title}</div>
                <div className="mb-3 text-xs font-bold text-muted">
                  {lesson.status} · {lesson.liveItemCount} soal LIVE · {lesson.draftItemCount} DRAFT
                  {!(lesson.status === 'LIVE' && lesson.liveItemCount > 0) ? ' — user melihat bab ini sebagai Bacaan' : ''}
                </div>
                <div className="flex gap-2">
                  <Link className="btn-outline-sm" href={`/admin/content/${lesson.id}`}>Kelola soal →</Link>
                  <button type="button" className="btn-outline-sm" onClick={() => quizAction(() => api(`/admin/chapters/${chapterId}/quiz`, { method: 'PATCH', body: JSON.stringify({ lessonId: null }) }))}>Lepas tautan</button>
                </div>
              </>
            ) : (
              <>
                <p className="mb-3 text-xs font-bold text-muted">Belum ada kuis — user melihat bab ini sebagai Bacaan.</p>
                <div className="flex flex-col gap-2">
                  <ChunkyButton className="btn-sm" onClick={() => quizAction(() => api(`/admin/chapters/${chapterId}/quiz`, { method: 'POST' }))}>Buat kuis</ChunkyButton>
                  <div className="flex gap-2">
                    <select className={`${input} flex-1`} value={pick} onChange={(e) => setPick(e.target.value)} aria-label="Pilih lesson">
                      <option value="">Tautkan lesson yang ada…</option>
                      {lessons.map((l) => <option key={l.id} value={l.id}>{l.code} · {l.title}</option>)}
                    </select>
                    <button type="button" className="btn-outline-sm" disabled={!pick} onClick={() => quizAction(() => api(`/admin/chapters/${chapterId}/quiz`, { method: 'PATCH', body: JSON.stringify({ lessonId: pick }) }))}>Tautkan</button>
                  </div>
                </div>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
```

> Bila `text-good` / `text-bad` belum ada sebagai utilitas Tailwind di proyek, cek `globals.css` `@theme` (halaman admin lain memakai `text-bad`); pakai yang ada.

- [ ] **Step 3: Verifikasi di browser**

`npx tsc --noEmit && npm run lint`; preview admin → modul uji "Coba" → Bab baru → editor:
1. Ketik `:::dialog` tanpa penutup → dalam ±0.5 dtk baris disorot merah, daftar error "Baris N: Blok ":::dialog" belum ditutup…", Simpan nonaktif, pratinjau tetap versi lama.
2. Tutup blok → error hilang, pratinjau menampilkan gelembung dialog.
3. `![x](media:tidak-ada.png)` → error "File media tidak ditemukan".
4. Cmd+S menyimpan ("Tersimpan").
5. "Buat kuis" → panel menampilkan `MOD-COBA-1 · DRAFT · 0 soal LIVE` → "Kelola soal →" membuka editor soal yang ada.
6. Hapus bab di modul DRAFT berhasil; di modul Keluhan (LIVE) → pesan 409.
Screenshot editor dengan error & pratinjau. Hapus modul uji? Tidak bisa (tak ada delete modul) — biarkan DRAFT atau pensiunkan.

- [ ] **Step 4: Commit**

```bash
git add "src/app/admin/modul/[id]/bab" src/app/globals.css
git commit -m "feat(admin): editor bab — Markdown + pratinjau parser BE + panel kuis"
```

---

### Task 13: Dokumentasi & checklist manual

**Files:**
- Modify: `CLAUDE.md` (root workspace)
- Create: `docs/superpowers/verifikasi/2026-10-menu-modul-checklist.md`

- [ ] **Step 1: Checklist manual**

```markdown
# Checklist manual — Menu Modul (Okt 2026)

Butuh: api + web jalan, DB sudah `seed:complaints` + `seed:module-complaints`, 1 akun user Menengah baru, 1 admin.

## User (mobile 375px & desktop ≥1024px)
- [ ] Nav 5 tab; tab Modul aktif berlabel; pill tidak terpotong di 375px.
- [ ] /modules: "Cocok untukmu · Menengah" berisi Making & Handling Complaints; modul level lain di "Modul lainnya".
- [ ] Halaman modul: 11 bab, Bab 1 "Berikutnya", CTA "MULAI BAB 1".
- [ ] Pembaca Bab 4: kartu frasa + 🔊 bersuara (Chrome & iOS Safari), dialog kiri/kanan, tip, pager.
- [ ] Bab 3: tabel terbaca tanpa geser horizontal halaman.
- [ ] Kuis Bab 1 → sesi → perayaan → kembali ke halaman modul; Bab 1 ✓ + akurasi; target harian Beranda +1; streak hidup.
- [ ] ✕ di tengah kuis → halaman modul; buka kuis lagi → melanjutkan soal yang sama.
- [ ] Ulangi kuis Bab 1 → label "ULANGI KUIS", XP tanpa bonus, target tidak bertambah.
- [ ] Beranda: kartu "Lanjutkan modul · Bab 2 berikutnya".
- [ ] Perjalanan Menengah tidak lagi memuat CMP-201..211.
- [ ] URL modul DRAFT / bab tak ada → kartu "tidak ditemukan" dengan tombol kembali.

## Admin
- [ ] Sidebar KONTEN: Modul paling atas.
- [ ] Buat modul, ubah metadata & cover, terbitkan/tarik/pensiunkan.
- [ ] Editor: error bernomor baris muncul < 1 dtk, Simpan terkunci saat error, pratinjau = tampilan user.
- [ ] Buat kuis → lesson MOD-… DRAFT → tambah soal → terbitkan lesson → bab tampil "berkuis" di user.
- [ ] Soal & Lesson: badge "Kuis modul: … · Bab n".
```

- [ ] **Step 2: Status di CLAUDE.md**

Tambahkan di daftar Status (setelah butir Konten "Complaints at Work"):

```markdown
- [x] **Menu Modul SELESAI** (<tanggal selesai>): tab ke-3 **Modul** (`BookOpenText`) — bab bacaan Markdown (sumber) → blok bertipe di-parse BE (`parseChapter`, markdown-it; `:::phrases`/`:::dialog`/`:::tip`; error `Baris N`) + kuis bab = Lesson tertaut (`ModuleChapter.lessonId` unik). Kuis belum tuntas → sesi `kind: 'MODULE'` (dihitung target/streak/bonus); sudah tuntas → `REPLAY`. Bab selesai = lesson tuntas (progres Perjalanan lama terbawa). `COUNTED_SESSION_KINDS` + `PATH_LESSON` (src/common/content-scope.ts) menggantikan filter kind tersebar; lesson tertaut keluar dari Perjalanan/sesi harian/berbicara/penguatan. Admin: daftar, detail (↑/↓), editor Markdown + pratinjau parser BE + panel kuis. Seeder `seed:module-complaints` (11 bab → CMP-201..211; Perjalanan Menengah tinggal WC). Spec: docs/superpowers/specs/2026-10-14-menu-modul-design.md · Plan: docs/superpowers/plans/2026-10-14-menu-modul.md · Checklist manual: docs/superpowers/verifikasi/2026-10-menu-modul-checklist.md. Suite api: <angka unit> unit + <angka e2e> e2e.
- [ ] Backlog modul: importer PDF/sumber lain → draf Markdown + soal DRAFT (spec terpisah, prinsip di spec modul §10), penugasan modul ke grup, statistik per-modul di Ringkasan, hapus modul DRAFT.
```

Isi `<tanggal selesai>` dan angka suite dari hasil `npm test` / `npm run test:e2e` terakhir.

- [ ] **Step 3: Commit (root workspace)**

```bash
cd <root workspace>
git add CLAUDE.md docs/superpowers/verifikasi/2026-10-menu-modul-checklist.md docs/superpowers/plans/2026-10-14-menu-modul.md
git commit -m "docs: status menu Modul + checklist manual"
```
