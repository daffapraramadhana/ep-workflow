# Fase 2 — Session Engine & App User Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Engine sesi harian lengkap di BE (perakitan, penilaian, XP, streak+freeze, review queue) dan seluruh app user (onboarding → beranda → sesi 3 tipe + media → perayaan → perjalanan → progress → profil) sesuai spec UI/UX, plus retrofit gaya admin.

**Architecture:** Semua logika di `apps/api` (NestJS): modul `session` (perakitan+penilaian), `me` (summary/streak/profil), `journey`, `progress`. FE `apps/web` murni render + animasi; kebenaran jawaban, XP, streak selalu dari BE. Kontrak DTO didefinisikan di plan ini dan di-copy tipis ke web.

**Tech Stack:** NestJS 11 + Prisma 6 + Postgres (sudah ada) · Next.js 15 + Tailwind 4 · `lucide-react` · WebAudio (tanpa file aset) · Nunito via next/font.

**Spec:** `docs/superpowers/specs/2026-08-25-user-app-uiux-design.md` (utama) · `docs/superpowers/specs/2026-08-25-english-app-foundation-design.md` (engine §5-6, invarian) · `docs/design-system.md` (tokens/komponen/motion/bunyi/ikon — WAJIB dibaca sebelum task FE). Mockup acuan: `.superpowers/brainstorm/*/content/user-app-mockup-v2.html`.

## Global Constraints

- Repo terpisah: commit api di `apps/api`, web di `apps/web`; JANGAN `git add` dari workspace root.
- **Semua penilaian/XP/streak/queue dihitung BE.** FE tidak pernah menerima `answerKey`/`acceptedAnswers`.
- `attempt` append-only; akurasi SELALU dari `firstTry=true`; `firstTry` = belum ada attempt (user,item) sebelumnya sama sekali.
- Angka XP/limit dari tabel `config` (key: `XP_FIRST_TRY=10, XP_RETRY=2, XP_SESSION_COMPLETE=20, XP_PERFECT_SESSION=15, XP_DAILY_REVIEW_CAP=100, REVIEW_MAX_PER_SESSION=3`) — jangan hardcode.
- Interval review: salah → due besok, streak 0; benar saat review → interval [1,3,7] hari, `correctStreak>=3` → hapus baris.
- Zona waktu bisnis: **Asia/Jakarta (WIB)** untuk "hari".
- Hanya sesi `kind=DAILY` dihitung untuk target harian & streak; bonus sesi (complete/perfect) tidak diberikan untuk `REPLAY`.
- Copy user-facing bahasa Indonesia; ikon Lucide `strokeWidth 2.25`; emoji hanya perayaan/kalender; tanpa timer soal, tanpa hearts, tanpa leaderboard, light-only.
- `prefers-reduced-motion`: matikan confetti/pulse/count-up. Bunyi default on, mute persisten (localStorage), tanpa bunyi di admin.
- Test e2e api butuh Postgres lokal hidup; pola bootstrap + cleanup presisi ada di test yang sudah ada (`test/users-import.e2e-spec.ts`). Jangan pernah menghapus admin seed; bersihkan data test dengan prefix unik.
- Env baru: tidak ada. Migrasi baru: satu, di Task 1.

---

### Task 1: Migrasi skema untuk engine (api)

**Files:**
- Modify: `apps/api/prisma/schema.prisma`
- Test: `apps/api/test/schema-phase2.e2e-spec.ts`

**Interfaces:**
- Produces (dipakai semua task BE): `Session.kind SessionKind @default(DAILY)` (enum `DAILY|REPLAY`), `Session.xpAwarded Int @default(0)`, `Attempt.xpAwarded Int @default(0)`, `StreakFreeze.coveredDate DateTime @db.Date`, `User.soundOn Boolean @default(true)`, `User.onboardedAt DateTime?`; constraint `@@unique([userId, date])` pada Session DIGANTI `@@index([userId, date])`.

Alasan tiap perubahan (spec-driven): target harian bisa 2 sesi (UI/UX §3) → unique(userId,date) harus lepas; total XP di hero & summary harus bisa dijumlah tanpa mengulang aturan (ledger di attempt/session); kalender minggu menampilkan hari yang diselamatkan 🧊 (UI/UX §7) → freeze butuh `coveredDate`; replay dari Perjalanan (UI/UX §5) → `kind`; onboarding gate (UI/UX §2) → `onboardedAt`; toggle bunyi tersimpan di akun (design-system §4) → `soundOn`.

- [ ] **Step 1: Failing test** — `schema-phase2.e2e-spec.ts`:

```ts
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

describe('schema fase 2', () => {
  const day = new Date('2026-01-05');
  afterAll(async () => {
    await prisma.session.deleteMany({ where: { user: { email: 'p2schema@test.local' } } });
    await prisma.user.deleteMany({ where: { email: 'p2schema@test.local' } });
    await prisma.$disconnect();
  });
  it('dua sesi DAILY di tanggal sama boleh; kolom baru ada', async () => {
    const u = await prisma.user.create({ data: { name: 'P2', email: 'p2schema@test.local' } });
    const s1 = await prisma.session.create({ data: { userId: u.id, date: day } });
    const s2 = await prisma.session.create({ data: { userId: u.id, date: day, kind: 'REPLAY' } });
    expect(s1.kind).toBe('DAILY'); expect(s2.xpAwarded).toBe(0);
    expect(u.soundOn).toBe(true); expect(u.onboardedAt).toBeNull();
  });
});
```

Run: `npx jest --config ./test/jest-e2e.json schema-phase2` → FAIL (unique violation / kolom tak ada).

- [ ] **Step 2: Edit schema.prisma** — tambah `enum SessionKind { DAILY REPLAY }`; di `Session`: `kind SessionKind @default(DAILY)`, `xpAwarded Int @default(0)`, ganti `@@unique([userId, date])` → `@@index([userId, date])`; di `Attempt`: `xpAwarded Int @default(0)`; di `StreakFreeze`: `coveredDate DateTime @db.Date`; di `User`: `soundOn Boolean @default(true)`, `onboardedAt DateTime?`.

- [ ] **Step 3:** `npx prisma migrate dev --name phase2_engine` → sukses; jalankan test → PASS. Perbaiki test/kode lama yang mengandalkan unique (grep `userId_date` — upsert di test lama jika ada → ganti create).
- [ ] **Step 4: Commit** — `"feat(schema): phase-2 engine columns (session kind/xp, freeze coveredDate, user prefs)"`

---

### Task 2: Utilitas hari WIB + ConfigService (api)

**Files:**
- Create: `apps/api/src/common/wib.ts`, `apps/api/src/common/config.service.ts`, `apps/api/src/common/common.module.ts` (`@Global()`)
- Test: `apps/api/src/common/wib.spec.ts`

**Interfaces:**
- Produces: `todayWIB(): Date` (UTC-midnight dari tanggal WIB kini), `dateWIB(d: Date): Date` (normalisasi ke UTC-midnight tanggal WIB), `addDays(d: Date, n: number): Date`, `weekStartWIB(d: Date): Date` (Senin); `AppConfigService.getInt(key: string): Promise<number>` (baca tabel `config`, cache 60 detik, throw jika key tak ada).

- [ ] **Step 1: Failing test** (murni, tanpa DB):

```ts
import { dateWIB, addDays, weekStartWIB } from './wib';

describe('wib', () => {
  it('22:00 UTC = 05:00 WIB hari berikutnya', () => {
    expect(dateWIB(new Date('2026-03-10T22:00:00Z')).toISOString()).toBe('2026-03-11T00:00:00.000Z');
  });
  it('06:00 UTC = 13:00 WIB hari sama', () => {
    expect(dateWIB(new Date('2026-03-10T06:00:00Z')).toISOString()).toBe('2026-03-10T00:00:00.000Z');
  });
  it('weekStart Senin', () => {
    expect(weekStartWIB(new Date('2026-03-11T06:00:00Z')).toISOString()).toBe('2026-03-09T00:00:00.000Z');
  });
  it('addDays', () => {
    expect(addDays(new Date('2026-03-10T00:00:00Z'), 3).toISOString()).toBe('2026-03-13T00:00:00.000Z');
  });
});
```

- [ ] **Step 2: Implementasi**

```ts
// wib.ts — WIB = UTC+7, tanpa DST, aman aritmetika manual
const H7 = 7 * 3600_000;
export function dateWIB(d: Date): Date {
  const t = d.getTime() + H7;
  return new Date(Math.floor(t / 86_400_000) * 86_400_000);
}
export const todayWIB = () => dateWIB(new Date());
export const addDays = (d: Date, n: number) => new Date(d.getTime() + n * 86_400_000);
export function weekStartWIB(d: Date): Date {
  const day = dateWIB(d);
  const dow = (day.getUTCDay() + 6) % 7; // Senin=0
  return addDays(day, -dow);
}
```

```ts
// config.service.ts
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AppConfigService {
  private cache = new Map<string, { v: number; at: number }>();
  constructor(private prisma: PrismaService) {}
  async getInt(key: string): Promise<number> {
    const hit = this.cache.get(key);
    if (hit && Date.now() - hit.at < 60_000) return hit.v;
    const row = await this.prisma.config.findUnique({ where: { key } });
    if (!row) throw new Error(`Config '${key}' tidak ditemukan`);
    const v = parseInt(row.value, 10);
    this.cache.set(key, { v, at: Date.now() });
    return v;
  }
}
```

`common.module.ts` `@Global()` provider+export `AppConfigService`; daftarkan di `AppModule`.

- [ ] **Step 3:** `npx jest wib` → PASS; full unit suite → PASS. **Step 4: Commit** — `"feat: WIB date utils + cached config service"`

---

### Task 3: Perakitan sesi (api) — `POST /session/today`, `GET /session/:id`, `POST /session/replay`

**Files:**
- Create: `apps/api/src/session/session.module.ts`, `session.service.ts`, `session.controller.ts`, `session.types.ts`
- Test: `apps/api/test/session-assembly.e2e-spec.ts`

**Interfaces:**
- Consumes: guard `JwtAuthGuard` + `@CurrentUser()` (`{sub, role}`), `todayWIB/addDays`, `AppConfigService.getInt('REVIEW_MAX_PER_SESSION')`, model Task 1.
- Produces (kontrak FE, JANGAN bocorkan kunci):

```ts
// session.types.ts
export interface SessionItemView {
  itemId: string; source: 'LESSON' | 'REVIEW'; order: number;
  type: 'PILIHAN_GANDA' | 'ISIAN' | 'SUSUN_KALIMAT';
  prompt: string; options: string[] | null;
  mediaUrl: string | null;   // dari StorageService.getUrl(mediaFile) bila ada
  passage: string | null;
  chips: string[] | null;    // SUSUN_KALIMAT: kata answerKey di-shuffle DI BE (agar FE tak tahu urutan asli = urutan array)
  answeredCorrect: boolean;
}
export interface SessionView {
  id: string; kind: 'DAILY' | 'REPLAY'; status: 'IN_PROGRESS' | 'COMPLETED';
  lessonTitle: string | null; items: SessionItemView[];
  progress: { answered: number; total: number };
}
```

Perilaku (fondasi §5.1 + UI/UX §6):
1. `POST /session/today`: ada sesi `kind=DAILY, status=IN_PROGRESS, date=todayWIB()` → kembalikan (lanjut). Tidak ada → rakit: review due (`dueDate <= today`, item LIVE, urut dueDate, limit config) + lesson berikutnya = lesson LIVE pada `user.level` urut `order` yang **belum selesai** (selesai = semua item LIVE-nya punya ≥1 attempt benar oleh user); item lesson urut `order`, review diselipkan di posisi acak; tulis `session` + `session_item` dalam satu `$transaction`.
2. Lesson habis → **sesi penguatan**: 10 item dari riwayat attempt user (item LIVE, prioritas: pernah salah terbanyak, lalu paling lama tak dijawab), semua `source=REVIEW`. Tanpa riwayat & tanpa lesson → 409 `"Belum ada konten untuk levelmu"`.
3. `POST /session/replay {lessonId}`: lesson done milik user → sesi `kind=REPLAY` berisi semua item LIVE lesson itu; lesson belum done → 400.
4. `GET /session/:id`: milik user sendiri (404 jika bukan); `answeredCorrect` per item dari attempt benar dalam sesi ini.
5. `chips`: `answerKey.split(/\s+/)` di-shuffle (Fisher-Yates; jika hasil sama dengan asli dan panjang>1, tukar dua pertama).

- [ ] **Step 1: Failing e2e** — seed konten test via Prisma langsung (prefix `P2A-`): 2 lesson LIVE level DASAR (3 + 2 item, semua LIVE, 1 item bertipe SUSUN_KALIMAT), user USER level DASAR (buat + set passwordHash agar bisa login, atau sign token langsung via JwtService dari app — pakai login endpoint dengan akun yang di-set password bcrypt). Kasus:

```ts
it('merakit sesi baru: item lesson urut + tanpa kunci jawaban', async () => {
  const res = await post('/session/today', {}, userToken).expect(201);
  expect(res.body.kind).toBe('DAILY');
  expect(res.body.items.length).toBe(3);
  expect(res.body.items[0]).not.toHaveProperty('answerKey');
  expect(res.body.items.find((i:any)=>i.type==='SUSUN_KALIMAT').chips.length).toBeGreaterThan(2);
});
it('panggil kedua kali = sesi yang sama (beku)', async () => {
  const a = await post('/session/today', {}, userToken).expect(201);
  const b = await post('/session/today', {}, userToken).expect(201);
  expect(b.body.id).toBe(a.body.id);
});
it('review due diselipkan, maks sesuai config', /* seed 5 baris review_queue due kemarin → total items = 3 + 3 */);
it('GET sesi milik user lain → 404', /* token user kedua */);
it('replay lesson yang belum selesai → 400');
```

Run → FAIL 404. 

- [ ] **Step 2: Implementasi** `session.service.ts` — kerangka inti:

```ts
async getOrCreateToday(userId: string): Promise<SessionView> {
  const today = todayWIB();
  const open = await this.prisma.session.findFirst({
    where: { userId, date: today, kind: 'DAILY', status: 'IN_PROGRESS' } });
  if (open) return this.view(open.id, userId);

  const maxReview = await this.config.getInt('REVIEW_MAX_PER_SESSION');
  const reviews = await this.prisma.reviewQueue.findMany({
    where: { userId, dueDate: { lte: today }, item: { status: 'LIVE' } },
    orderBy: { dueDate: 'asc' }, take: maxReview, include: { item: true } });

  const lesson = await this.nextLesson(userId);       // null bila habis
  const lessonItems = lesson
    ? await this.prisma.item.findMany({ where: { lessonId: lesson.id, status: 'LIVE' }, orderBy: { order: 'asc' } })
    : [];
  let rows: { itemId: string; source: 'LESSON'|'REVIEW' }[];
  if (lesson) {
    rows = lessonItems.map(i => ({ itemId: i.id, source: 'LESSON' as const }));
    for (const r of reviews) {                         // selip acak
      const pos = Math.floor(Math.random() * (rows.length + 1));
      rows.splice(pos, 0, { itemId: r.itemId, source: 'REVIEW' });
    }
  } else {
    const hist = await this.reinforcementItems(userId, 10);
    if (!hist.length) throw new ConflictException('Belum ada konten untuk levelmu');
    rows = hist.map(id => ({ itemId: id, source: 'REVIEW' as const }));
  }
  const created = await this.prisma.$transaction(async tx => {
    const s = await tx.session.create({ data: { userId, date: today } });
    await tx.sessionItem.createMany({ data: rows.map((r, i) => ({ sessionId: s.id, ...r, order: i })) });
    return s;
  });
  return this.view(created.id, userId);
}
```

`nextLesson`: ambil lesson LIVE level user urut order; untuk tiap lesson (query agregat, bukan loop N+1 penuh — pakai satu query `findMany` lesson + satu query attempt benar user ke item lesson-lesson itu, hitung di memori). `view()`: join session_item+item, map ke `SessionItemView` (mediaUrl via `StorageService.getUrl`), `answeredCorrect` dari attempt benar sesi ini, `chips` di-shuffle **stabil per sesi** (seed dari hash sessionId+itemId — supaya reload tidak mengubah urutan chip: implement `seededShuffle(arr, seedString)` dengan LCG sederhana).

- [ ] **Step 3:** e2e PASS; full suite PASS. **Step 4: Commit** — `"feat: session assembly (today/replay/get) with frozen sessions and review slots"`

---

### Task 4: Penilaian + XP + review queue (api) — `POST /session/:id/answer`

**Files:**
- Create: `apps/api/src/session/grading.ts` (murni), `apps/api/src/session/answer.service.ts`
- Modify: `apps/api/src/session/session.controller.ts`, `session.module.ts`
- Test: `apps/api/src/session/grading.spec.ts`, `apps/api/test/session-answer.e2e-spec.ts`

**Interfaces:**
- Consumes: Task 3 (sesi + session_item), config keys XP_*, wib utils.
- Produces:

```ts
// grading.ts — murni
export function gradeAnswer(item: { type: string; answerKey: string; acceptedAnswers: string[] },
                            answer: string): boolean;
// PILIHAN_GANDA: answer 'A'-'D' case-insensitive === answerKey
// ISIAN: normal(answer) ∈ acceptedAnswers.map(normal); normal = lowercase + trim + rangkap spasi jadi satu
// SUSUN_KALIMAT: normal(answer) === normal(answerKey)

// Respons endpoint:
export interface AnswerResult {
  correct: boolean; explanation: string;
  correctAnswer: string | null;          // hanya saat salah: teks opsi benar / kalimat / accepted pertama
  xpAwarded: number;
  sessionCompleted: boolean;
  summary: null | { xpSession: number; accuracyFirstTry: number;  // 0-100
                    streak: number; streakChanged: boolean; milestone: 7|30|100|null };
}
```

Perilaku (fondasi §5.2-5.3, §6.1):
1. Validasi: sesi milik user, IN_PROGRESS, item ada di sesi; item yang sudah `answeredCorrect` → 400 `"Soal ini sudah dijawab benar"`.
2. `firstTry` = tidak ada attempt (userId,itemId) sebelumnya **sama sekali** (lintas sesi — definisi fondasi "percobaan pertama" historis).
3. XP per jawaban: benar&firstTry → `XP_FIRST_TRY`; benar&!firstTry → `XP_RETRY`; salah → 0. **Cap review harian**: jika `source=REVIEW`, hitung total xp attempt hari ini (WIB) user dari item ber-source REVIEW (join session_item) — bila ≥ `XP_DAILY_REVIEW_CAP`, xp jawaban ini 0.
4. Tulis `attempt` (answer, correct, firstTry, xpAwarded) — append-only.
5. Update `review_queue`: salah (konteks apa pun) → upsert `{dueDate: besok, correctStreak: 0}`; benar & `source=REVIEW` & baris ada → `correctStreak+1`; streak baru ≥3 → delete baris; else `dueDate = today + [1,3,7][min(correctStreak,2)]`.
6. Selesai? = semua session_item punya attempt benar di sesi ini. Ya → status COMPLETED, `completedAt=now`; bonus (hanya `kind=DAILY`): `XP_SESSION_COMPLETE` + (`XP_PERFECT_SESSION` bila semua item benar pada attempt pertama-dalam-sesi) → simpan di `session.xpAwarded`; hitung streak via `StreakService` (Task 5 — di task ini pakai stub yang mengembalikan `{streak: 0, changed: false}` dan tandai TODO-koneksi di Task 5 Step 4, BUKAN placeholder logika: stub-nya dipanggil lewat interface `StreakEvaluator` yang di-inject).
7. Seluruh tulis dalam `$transaction`.

- [ ] **Step 1: Failing unit** `grading.spec.ts` — 8 kasus: MC benar huruf kecil; MC salah; isian variasi accepted + kapital/spasi; isian salah; susun benar; susun beda urutan; normalisasi spasi ganda; answer kosong → false.
- [ ] **Step 2: Implement `gradeAnswer`** (fungsi murni ±20 baris, `const normal = (s:string)=>s.toLowerCase().trim().replace(/\s+/g,' ')`) → unit PASS.
- [ ] **Step 3: Failing e2e** `session-answer.e2e-spec.ts` (seed seperti Task 3, prefix `P2B-`): jawab benar → `{correct:true, xpAwarded:10}` & attempt tercatat firstTry; jawab salah → correctAnswer terisi + review_queue due besok; jawab ulang benar → xp 2 (firstTry false); item sudah benar dijawab lagi → 400; menyelesaikan semua item → `sessionCompleted:true`, summary.accuracyFirstTry benar hitungannya, `session.xpAwarded = 20(+15 bila perfect)`; REPLAY selesai → tanpa bonus.
- [ ] **Step 4: Implement `answer.service.ts`** per perilaku 1-7 → e2e PASS; full suite PASS.
- [ ] **Step 5: Commit** — `"feat: grading, XP with review cap, SM-2 queue updates, session completion"`

---

### Task 5: Streak + freeze + `GET /me/summary` + profil (api)

**Files:**
- Create: `apps/api/src/me/me.module.ts`, `me.controller.ts`, `streak.service.ts`, `summary.service.ts`
- Modify: `apps/api/src/session/answer.service.ts` (ganti stub `StreakEvaluator` → `StreakService`)
- Test: `apps/api/src/me/streak.service.spec.ts` (unit, prisma di-mock tipis via seed nyata lebih baik → jadikan e2e ringan), `apps/api/test/me.e2e-spec.ts`

**Interfaces:**
- Consumes: sessions COMPLETED kind DAILY, `StreakFreeze`, wib utils, `User.dailyTargetSessions`.
- Produces:

```ts
// StreakService
evaluate(userId: string): Promise<{ streak: number; longest: number;
  frozenDates: string[] /* ISO date */ }>;
// Aturan: hari "tercapai" = jumlah sesi DAILY COMPLETED hari itu >= dailyTargetSessions user (nilai kini).
// Berjalan mundur dari hari ini: hari ini boleh belum tercapai (belum putus).
// Hari bolong: boleh ditutup freeze — konsumsi lazy: jika minggu WIB hari itu belum punya baris
// StreakFreeze, CREATE baris {weekStart, coveredDate=hari itu}; sudah ada & coveredDate beda → putus.
// Dua bolong berurutan → putus. longest dihitung dari seluruh riwayat dengan aturan sama tanpa konsumsi baru.

// GET /me → { id,name,email,level,dailyTargetSessions,soundOn,onboarded:boolean }
// PATCH /me {level?, dailyTargetSessions?(1|2), soundOn?} → set onboardedAt bila level+target terisi pertama kali
// GET /me/summary → {
//   name, streak, xpTotal,            // xpTotal = sum(attempt.xpAwarded)+sum(session.xpAwarded)
//   freezeAvailableThisWeek: boolean, sessionsCompletedToday, dailyTarget,
//   reviewsDue: number, contentExhausted: boolean,
//   nextLesson: { id, title, topic, itemCount, estMinutes, xpEstimate } | null }
// estMinutes = ceil(itemCount * 0.75); xpEstimate = itemCount * XP_FIRST_TRY + XP_SESSION_COMPLETE + XP_PERFECT_SESSION.
```

- [ ] **Step 1: Failing e2e streak** — seed user (prefix `P2C-`) + sesi COMPLETED tanggal-tanggal terkontrol (tulis langsung via Prisma, `date` eksplisit): rangkaian 5 hari beruntun → streak 5; bolong 1 hari di tengah → freeze row tercipta & streak utuh; bolong 2 hari → streak = hari setelah bolong; dua bolong di minggu yang sama → putus (freeze cuma 1/minggu).
- [ ] **Step 2: Implement `StreakService.evaluate`** — ambil semua tanggal sesi DAILY COMPLETED user (group by date, count) + semua freeze rows sekali, jalan mundur maks 400 hari di memori; konsumsi freeze = create (idempoten by @@id(userId,weekStart)). PASS.
- [ ] **Step 3: Failing e2e me/summary** — GET /me sebelum PATCH → `onboarded:false`; PATCH level+target → `onboarded:true`; summary: xpTotal sesuai seed attempt+session, `nextLesson` = lesson belum selesai pertama, `contentExhausted` true bila tak ada, `reviewsDue` menghitung due hari ini.
- [ ] **Step 4: Implement controller+summary; sambungkan `StreakService` ke `answer.service`** (summary sesi memakai `evaluate()` sesudah COMPLETED; `streakChanged` = streak naik dibanding sebelum sesi; `milestone` bila streak ∈ {7,30,100}). Semua e2e (termasuk Task 4 yang tadinya stub) PASS.
- [ ] **Step 5: Commit** — `"feat: streak with lazy freeze, me/profile endpoints, summary"`

---

### Task 6: Journey + Progress + lapor soal (api)

**Files:**
- Create: `apps/api/src/journey/journey.module.ts`, `journey.controller.ts`, `journey.service.ts`; `apps/api/src/progress/progress.module.ts`, `progress.controller.ts`, `progress.service.ts`; `apps/api/src/content/report.controller.ts` (masuk ContentModule)
- Test: `apps/api/test/journey-progress.e2e-spec.ts`

**Interfaces:**
- Produces:

```ts
// GET /journey → { topics: [{ topic, lessons: [{ id, title, order,
//   state: 'done'|'now'|'locked', accuracy: number|null /* first-try %, done saja */ }] }] }
// Urutan: topic sesuai order lesson terkecilnya; state 'now' = lesson belum-done pertama pada level user;
// setelahnya locked. Hanya lesson LIVE pada level user.
// GET /progress → { skills: [{ skill:'VOCABULARY'|..., answered, accuracy: number|null }],
//   week: [{ date: string, state: 'active'|'frozen'|'empty' }],  // 7 hari Senin-Minggu pekan WIB ini
//   totals: { lessonsDone, xpTotal, longestStreak } }
// POST /items/:id/report { note: string (3..500) } → 201; role USER & ADMIN boleh (JwtAuthGuard saja).
```

- [ ] **Step 1: Failing e2e** (prefix `P2D-`): journey memetakan done/now/locked benar setelah seed attempt; accuracy hanya di done; progress.skills menghitung dari firstTry saja; week menandai `frozen` pada `StreakFreeze.coveredDate`; report menulis `item_report` (OPEN) dan menolak note kosong (400).
- [ ] **Step 2: Implementasi** — journey: satu query lessons + satu query attempts benar user (item→lessonId), hitung done di memori (pola `nextLesson` Task 3 — ekstrak helper bersama `lessonCompletion(userId, level)` ke `session.service.ts` dan konsumsi dari kedua modul via export SessionModule). Progress: agregasi attempt `groupBy` skill (join item→lesson.skill via dua query + gabung memori). PASS.
- [ ] **Step 3: Commit** — `"feat: journey map, progress aggregates, item report endpoint"`

---

### Task 7: Fondasi design system di web (tokens, font, ikon, komponen inti, bunyi)

**Files:**
- Modify: `apps/web/src/app/globals.css`, `apps/web/src/app/layout.tsx`
- Create: `apps/web/src/components/ui.tsx` (ChunkyButton, Card, StatPill, MetaChip), `apps/web/src/components/progress.tsx` (Ring, SegmentBar), `apps/web/src/lib/sfx.ts`, `apps/web/src/lib/api-types.ts` (copy kontrak Task 3-6)
- Test: build + `apps/web/src/lib/sfx.test-manual.md` bukan — verifikasi via halaman `/dev/ds` sementara? TIDAK (YAGNI). Verifikasi: `npm run build` + pemakaian di Task 8+.

**Interfaces:**
- Consumes: `docs/design-system.md` §1-5 — **baca dulu, nilai token disalin persis dari sana**.
- Produces: `ChunkyButton({variant:'brand'|'good'|'danger'|'ghost', ...props})`; `Card`, `StatPill({hot}), MetaChip({tone:'brand'|'amber'})`; `Ring({size, stroke, pct, trackClass, arcClass, children})` (SVG, dasharray dihitung dari size); `SegmentBar({total, filled})`; `sfx.play('good'|'bad'|'win')` + `sfx.muted` (persisten localStorage key `soundOn`, sinkron PATCH /me saat toggle di Profil); font Nunito via `next/font/google` (weight 600/800/900) menggantikan font scaffold; `npm i lucide-react`.

- [ ] **Step 1:** Tulis token CSS variables di `globals.css` persis design-system §1 (pertahankan `color-scheme: light`). Ganti font di `layout.tsx` ke Nunito. 
- [ ] **Step 2:** Implement `ui.tsx` + `progress.tsx` — CSS tombol chunky persis design-system §2 (via Tailwind arbitrary values atau kelas util di globals). `sfx.ts` = port fungsi `snd()` dari mockup v2 (osilator; good 660→880, bad 220 square, win arpeggio C-E-G-C, gain ≤.15) + guard `prefers-reduced-motion` TIDAK berlaku ke bunyi (hanya gerak) + lazy AudioContext.
- [ ] **Step 3:** `npm run build` PASS; commit — `"feat(ds): tokens, Nunito, lucide, core components, sfx"`

---

### Task 8: Shell app user — routing gate, nav mengambang, layout sesi

**Files:**
- Create: `apps/web/src/app/(user)/layout.tsx` (guard + nav), `apps/web/src/components/user-nav.tsx`, `apps/web/src/lib/use-me.ts`
- Modify: `apps/web/src/app/page.tsx` (gate 3 arah)

**Interfaces:**
- Consumes: `GET /me` (Task 5), api() helper, komponen Task 7.
- Produces: route group `(user)` berisi `/home /journey /progress /profile /onboarding /session`; `useMe()` (SWR-ringan: fetch sekali + mutate manual); nav: 4 item Lucide (`Home, Map, ChartColumn, User`) pill navy mengambang (mobile) / sidebar kiri ≥1024px; **nav disembunyikan di `/session*` dan `/onboarding`**; guard: tanpa token → `/login`; `onboarded:false` → `/onboarding`; role ADMIN tetap boleh memakai app user (untuk demo).

- [ ] **Step 1:** Implement gate `page.tsx`: token? → fetch /me → onboarded? `/home` : `/onboarding`; else `/admin/login`? BUKAN — user login page terpisah? Fase 1 hanya punya `/admin/login`. **Buat `/login` user-facing** (form sama, copy netral "Masuk", tanpa cek role; sukses → gate ulang) — file `apps/web/src/app/login/page.tsx`; `/admin/login` tetap untuk admin. `/invite/[token]` sukses → sekarang arahkan ke `/login` dengan pesan "Akun aktif — silakan masuk" (ganti copy lama "aplikasi menyusul").
- [ ] **Step 2:** Layout `(user)` + nav (aktif per pathname); build PASS; verifikasi manual: login user → mendarat `/onboarding` (halaman belum ada → placeholder minim "…" dibuat di Task 9 — buat file kosong ber-judul agar route hidup).
- [ ] **Step 3:** Commit — `"feat: user shell (gate, login, floating nav, session-aware layout)"`

---

### Task 9: Onboarding + Beranda

**Files:**
- Create: `apps/web/src/app/(user)/onboarding/page.tsx`, `apps/web/src/app/(user)/home/page.tsx`, `apps/web/src/components/hero.tsx`
- Test: build + verifikasi manual terskrip (di bawah)

**Interfaces:**
- Consumes: `GET /me/summary`, `PATCH /me`, `POST /session/today` (hanya navigasi), komponen Task 7, `useMe`.
- Produces: Beranda per UI/UX §4 — dipakai sebagai pola styling oleh Task 10-13.

- [ ] **Step 1: Onboarding** 2 langkah (state lokal, tanpa route ganda): kartu level (Dasar/Menengah/Mahir + deskripsi manusia + catatan "bisa diubah di Profil") → kartu target (Santai 1 · Serius 2, default Santai) → PATCH /me → `/home`.
- [ ] **Step 2: Beranda** — hero gelap gradien (`navy→navy2→#4338CA`): StatPill `Flame` streak / `Star` xpTotal / `Snowflake` bila `freezeAvailableThisWeek`; sapaan per jam WIB (pagi<11, siang<15, sore<19, malam); Ring amber `sessionsCompletedToday/dailyTarget`; pesan status (belum mulai / tercapai "Sampai jumpa besok ✅"). Kartu Lanjutkan (judul nextLesson, MetaChip topic/±menit/+XP, ChunkyButton MULAI → POST /session/today → `/session`). Kartu review bila `reviewsDue>0` (AlarmClock, juga → sesi). `contentExhausted` → kartu "Sesi Penguatan". Skeleton saat loading (kartu abu pulse).
- [ ] **Step 3: Verifikasi manual terskrip** (server api+web hidup, akun user test): onboarding lengkap → beranda menampilkan angka summary asli; klik MULAI → mendarat di `/session` (halaman Task 10; sebelum itu route stub). Dokumentasikan di report.
- [ ] **Step 4:** Commit — `"feat: onboarding + home (hero, target ring, continue/review cards)"`

---

### Task 10: Sesi — kerangka, submit, feedback sheet, keluar-lanjut

**Files:**
- Create: `apps/web/src/app/(user)/session/page.tsx`, `apps/web/src/components/session/feedback-sheet.tsx`, `apps/web/src/components/session/use-session.ts`
- Test: build + verifikasi manual terskrip

**Interfaces:**
- Consumes: `POST /session/today`, `GET /session/:id`, `POST /session/:id/answer`, `SessionView/AnswerResult` (api-types), SegmentBar, sfx.
- Produces: `useSession()` state machine — dipakai Task 11-12:

```ts
interface SessionState {
  view: SessionView | null;
  queue: number[];              // indeks item belum-benar, urutan tampil; salah → push ke belakang
  currentIdx: number | null;
  phase: 'loading'|'answering'|'feedback'|'done'|'error';
  last: AnswerResult | null;
  submit(answer: string): Promise<void>;   // gagal jaringan → phase tetap 'answering' + error flag, jawaban user utuh
  next(): void;                 // dari feedback → soal berikut / done
}
```

Perilaku: muat via POST /session/today (atau `?replay=<lessonId>` → POST /session/replay); `queue` awal = item `!answeredCorrect` urut `order` (lanjut sesi beku); submit → AnswerResult → sheet (hijau/merah + explanation + correctAnswer saat salah + tombol "Laporkan soal" kecil → dialog 1 field → POST /items/:id/report); benar → segmen terisi + keluar dari queue; salah → tetap, push belakang; sheet `role="status"`. Header: ✕ (router ke /home, tanpa dialog), SegmentBar (`filled = total - queue.length`), mute (sfx). Gagal jaringan submit → toast "Koneksi terputus" + tombol PERIKSA berganti "COBA LAGI".

- [ ] **Step 1:** Implement `use-session.ts` + sheet + halaman dengan area jawab sementara (textarea polos — diganti Task 11) supaya alur bisa diuji end-to-end lebih awal.
- [ ] **Step 2: Verifikasi manual terskrip**: jalankan sesi asli dari seed konten; jawab benar & salah; matikan api di tengah → COBA LAGI muncul, nyalakan → lanjut tanpa kehilangan jawaban; keluar ✕ lalu masuk lagi → sesi lanjut dari soal tersisa.
- [ ] **Step 3:** Commit — `"feat: session flow (state machine, feedback sheet, resilience)"`

---

### Task 11: Sesi — tiga tipe soal + lapisan media

**Files:**
- Create: `apps/web/src/components/session/answer-mc.tsx`, `answer-isian.tsx`, `answer-chips.tsx`, `media-block.tsx`
- Modify: `apps/web/src/app/(user)/session/page.tsx` (ganti textarea)
- Test: build + verifikasi manual terskrip

**Interfaces:**
- Consumes: `SessionItemView` (options/chips/mediaUrl/passage), `useSession.submit`.
- Produces: tiap komponen `({item, disabled, onReady(answer: string|null)})` — `onReady` meng-enable PERIKSA; nilai answer yang dikirim: MC = huruf `'A'|'B'|'C'|'D'` (indeks opsi), isian = teks input, chips = kata-kata zona di-join spasi.

- [ ] **Step 1: MC** — grid 2 kolom bila semua opsi ≤12 char, else 1 kolom (UI/UX §6); pilih = tint brand; setelah hasil: benar hijau, salah merah + opsi benar (dari `correctAnswer` teks — cocokkan ke options untuk highlight) hijau.
- [ ] **Step 2: Isian** — render prompt split pada `___` → input inline auto-width (min 80px, `size` mengikuti panjang); Enter = PERIKSA.
- [ ] **Step 3: Chips** — port dari mockup v2: bank chip dari `item.chips`, tap → zona (asal ghost), tap zona → balik; PERIKSA aktif saat semua terpasang; keyboard: chip fokusable, Enter/Space memindah.
- [ ] **Step 4: MediaBlock** — audio: kartu player (tombol Play bulat 56px Lucide, autoplay sekali kecuali muted, replay bebas, `<audio>` + label ARIA); gambar radius 16 max-h 200; passage kartu scroll max-h 40vh. Tampil di atas prompt bila `mediaUrl/passage` ada.
- [ ] **Step 5: Verifikasi manual terskrip** ketiga tipe + soal ber-audio & ber-passage dari template seed; commit — `"feat: MC/isian/chips answers + media layer"`

---

### Task 12: Perayaan + integrasi selesai-sesi

**Files:**
- Create: `apps/web/src/components/session/celebrate.tsx`
- Modify: `apps/web/src/app/(user)/session/page.tsx` (phase 'done')

**Interfaces:**
- Consumes: `AnswerResult.summary` (xpSession, accuracyFirstTry, streak, streakChanged, milestone), sfx 'win', useMe.mutate.
- Produces: layar perayaan per UI/UX §6: confetti CSS (26 partikel 4 warna; skip bila reduced-motion), 🎉, XP count-up (~700ms, langsung final bila reduced-motion), kartu Akurasi, baris streak hanya bila `streakChanged` ("Streak jadi N hari!"), copy khusus milestone 7/30/100 + confetti 2×, ChunkyButton good LANJUT → `/home` (mutate useMe agar hero ter-update).

- [ ] Implement + verifikasi manual (selesaikan sesi penuh, lihat summary asli & hero berubah) + commit — `"feat: celebration screen with real summary"`

---

### Task 13: Perjalanan

**Files:**
- Create: `apps/web/src/app/(user)/journey/page.tsx`, `apps/web/src/components/journey-path.tsx`

**Interfaces:**
- Consumes: `GET /journey`, `POST /session/replay` (tap node done), POST /session/today (tap node now).
- Produces: path per UI/UX §5: header topic pill sticky (siklus warna: brand, sky, amber, pink), node done/now/locked (76px now + pulse; locked tap → shake + toast), sub-teks judul+status+akurasi; tap done → konfirmasi ringan ("Ulangi lesson ini? XP dihitung sebagai ulangan") → replay → `/session?replay=<lessonId>`.

- [ ] Implement + verifikasi manual + commit — `"feat: journey path"`

---

### Task 14: Progress + Profil

**Files:**
- Create: `apps/web/src/app/(user)/progress/page.tsx`, `apps/web/src/app/(user)/profile/page.tsx`

**Interfaces:**
- Consumes: `GET /progress`, `GET/PATCH /me`, sfx.muted sink.
- Produces: Progress per UI/UX §7 (4 baris skill warna token + ikon `BookOpen/Pencil/Headphones/FileText` + ring % putih; baris abu "belum ada data" bila accuracy null; kartu minggu 🔥/🧊/·; kartu totals). Profil per §8 (read-only nama/email; ubah level dengan dialog konfirmasi "Progress lesson level lama tetap tersimpan"; target harian; toggle bunyi → localStorage + PATCH /me; Keluar hapus token → `/login`).

- [ ] Implement + verifikasi manual + commit — `"feat: progress & profile"`

---

### Task 15: Retrofit admin (mimic guide)

**Files:**
- Modify: `apps/web/src/app/admin/*` (login, layout, 4 halaman), memakai komponen Task 7

**Interfaces:**
- Consumes: design-system §6 — tabel adopsi/tolak adalah kontraknya.
- Produces: admin memakai Nunito+token (otomatis via globals), ChunkyButton pada CTA utama per halaman (Masuk, Import, Unggah, Simpan, Terbitkan), pill status DRAFT/LIVE/RETIRED (abu/hijau-soft/merah-soft), ikon sidebar Lucide (`Upload, Table2, Image → gunakan ImageIcon, Users` + `LogOut`), hover baris tabel `--brand-soft`. TANPA: nav mengambang, bunyi, confetti, hero gelap.

- [ ] Implement (perubahan styling murni — perilaku/endpoint tidak disentuh) + `npm run build` + verifikasi manual 4 halaman + commit — `"style: admin adopts design system (tokens, chunky CTA, status pills, lucide)"`

---

### Task 16: Verifikasi lintas-alur + viewport mobile

**Files:**
- Create: `docs/superpowers/verifikasi/2026-fase2-checklist.md` (workspace)

- [ ] **Step 1:** Jalankan skenario penuh di viewport mobile (375px) dan desktop: onboarding → 3 hari simulasi (ubah tanggal sesi via psql untuk menguji streak & review due besok) → sesi dengan ketiga tipe + audio → salah 2 → muncul lagi di akhir → perayaan → journey replay → progress menampilkan freeze. Catat hasil per butir (✓/✗ + catatan) di file checklist.
- [ ] **Step 2:** Perbaiki temuan kecil (styling/copy) langsung; temuan besar → laporkan sebagai concern, jangan perbaiki diam-diam.
- [ ] **Step 3:** Commit workspace — `"docs: phase-2 verification checklist results"`

---

## Self-Review (sudah dijalankan)

- **Spec coverage:** UI/UX §2 shell/gate → T8 · §3 onboarding → T9 · §4 beranda → T9 · §5 journey+replay → T3/T6/T13 · §6 sesi+tipe+media+perayaan → T3/T4/T10/T11/T12 · §7 progress → T6/T14 · §8 profil → T5/T14 · §9 state/error → T10 (retry), skeleton T9 · §10 kontrak & penilaian-BE → T3-T6 · §11 a11y → tersebar (sheet role=status T10, chip keyboard T11, reduced-motion T7/T12) · §12 lapor soal → T6/T10 · design-system §6 admin → T15. Fondasi §5-6 (engine) → T3-T5 penuh.
- **Gap ditemukan & ditutup saat review:** login user-facing belum ada di Fase 1 → T8 membuat `/login` + ubah copy sukses invite; unique(userId,date) menghalangi target 2 sesi → T1; chips harus di-shuffle di BE agar kunci tak bocor lewat urutan array → T3; stub streak di T4 diberi interface eksplisit agar penggantian di T5 terverifikasi test T4 yang di-unskip.
- **Type consistency:** `SessionView/SessionItemView/AnswerResult` (T3/T4) = konsumen T10-T12; nama endpoint konsisten T3-T6 vs T8-T14; config keys sama dengan seed Fase 1; komponen T7 (`ChunkyButton, StatPill, MetaChip, Ring, SegmentBar, sfx`) dipakai persis di T9-T15.
