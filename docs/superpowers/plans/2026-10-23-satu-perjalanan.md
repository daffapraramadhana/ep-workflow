# Satu Perjalanan Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Perjalanan menjadi satu-satunya journey. Pelajaran biasa dan bab modul tampil sebagai unit dengan satu progres. Beranda hanya punya satu ajakan "lanjut".

**Architecture:**
- Satu fungsi murni `groupPath()` menentukan unit dan urutan langkah. `SessionService.path()` memakainya. Konsumennya: mesin sesi (harian/berbicara), `JourneyService`, dan lewat Journey juga `SummaryService`. Dengan begitu tidak ada dua tempat yang berjalan menurut urutan berbeda.
- `PATH_LESSON` dimaknai ulang menjadi "lesson punya ≥1 item LIVE". Semua modul LIVE ikut jalur.
- Migrasi menghapus `Module.showInPath` dan memindah lesson Complaints ke akhir MENENGAH.
- Web hanya menampilkan.

**Tech Stack:** NestJS + Prisma + Postgres (`apps/api`), Next.js App Router (`apps/web`), Jest (unit `*.spec.ts`, e2e `test/*.e2e-spec.ts --runInBand`).

**Spec:** `docs/superpowers/specs/2026-10-23-satu-perjalanan-design.md`. Baca dulu. Bagian §-nomor di plan ini merujuk ke spec.

## Global Constraints

- Repo terpisah: kerjakan di branch `feat/satu-perjalanan` di `apps/api` **dan** `apps/web`. Workspace (`english-app/`) hanya untuk docs. Jangan commit apa pun di `apps/` ke repo workspace.
- `apps/web` punya perubahan maskot yang belum di-commit (`assets/mascot/…`, `public/mascot/animation-kit-v1/`, `scripts/build-mascot-animation-kit.mjs`). Jangan disentuh. Selalu `git add` file spesifik, jangan `git add -A`/`.`.
- Semua logika (unit, urutan, status, progres) di BE. Next.js murni tampilan.
- `attempt` append-only. Soal retired tidak dihapus. Tanpa background job.
- "Selesai" = semua item LIVE lesson pernah dijawab benar. Definisinya tetap, jangan ubah.
- Copy UI berbahasa Indonesia. Teks yang dipatok spec:
  - "X dari N langkah selesai"
  - "Unit N · {judul}"
  - "Bab {posisi} · {judul bab}"
  - label "Bacaan"
- Pesan commit gaya repo: `feat(scope): …` / `test(scope): …`, diakhiri `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Suite harus hijau di akhir: `cd apps/api && npm test && npm run test:e2e`, `cd apps/web && npm run lint && npm run build`.

## Review Focus

1. **Karyawan MENENGAH yang sudah mengerjakan EFTL 3/5 tapi belum Complaints.** Setelah migrasi, `now` tetap di langkah yang sama dan langkah EFTL yang selesai tetap ✓. Test di Task 3 ("langkah selesai setelah now tetap done"), ditambah cek SQL migrasi di Task 2.
2. **Dua sesi terbuka hari ini (DAILY dan MODULE).** Beranda harus konsisten menampilkan DAILY/SPEAKING lebih dulu, MODULE hanya bila tidak ada yang lain. Test di Task 4.
3. **Bab yang lesson-nya DRAFT/RETIRED atau tanpa item LIVE.** Tampil sebagai "Bacaan", tidak dihitung, tidak bisa jadi `now`. Test di Task 3.
4. **Modul yang semua babnya bacaan.** Tidak muncul di Perjalanan dan tidak membuat unit kosong. Test di Task 3.
5. **User tanpa level.** `/journey` → `{units: [], done: 0, total: 0}`, summary `nextLesson: null`, tanpa error. Test di Task 4.

---

### Task 1: Fungsi urutan jalur `groupPath`

**Files:**
- Create: `apps/api/src/common/path-order.ts`
- Test: `apps/api/src/common/path-order.spec.ts`

**Interfaces:**
- Produces:
  ```ts
  export interface PathLessonInput {
    id: string;
    order: number;
    topic: string;
    moduleChapter: {
      order: number;
      module: { id: string; slug: string; title: string; status: ContentStatus };
    } | null;
  }
  export interface PathUnit<T extends PathLessonInput> {
    kind: 'topic' | 'module';
    key: string;            // `module:${moduleId}` | `topic:${topic}`
    title: string;          // module.title | topic
    moduleId: string | null;
    moduleSlug: string | null;
    lessons: T[];           // sudah terurut
  }
  export function groupPath<T extends PathLessonInput>(lessons: T[]): PathUnit<T>[];
  export function flattenPath<T extends PathLessonInput>(units: PathUnit<T>[]): T[];
  ```

**Aturan (spec §5.1–5.3):**
- Lesson masuk unit modul **hanya** bila `moduleChapter` ada dan `module.status === 'LIVE'`. Selain itu masuk unit topik `topic:${topic}`.
- Unit diurutkan menurut `min(Lesson.order)` di dalam unit. Bila seri, urutkan menurut `key`.
- Di dalam unit modul, lesson diurutkan menurut `moduleChapter.order`. Di dalam unit topik, menurut `Lesson.order`.

- [ ] **Step 1: Tulis test yang gagal** di `path-order.spec.ts`, dengan fixture lesson kecil:
  - `groups topic lessons and orders units by min lesson order`: input topik A order 1 dan 5, topik B order 3 → unit `[A(1,5), B(3)]`. `flattenPath` → id `[a1, a5, b3]`.
  - `module lessons form one unit ordered by chapter order, not lesson order`: modul LIVE M, lesson x (order 10, chapter 2) dan y (order 11, chapter 1) → satu unit `kind 'module'`, lessons `[y, x]`, `title` = judul modul, `moduleSlug` terisi.
  - `module unit key never merges with a topic unit of the same topic string`: lesson modul ber-topic "Greetings" dan lesson biasa ber-topic "Greetings" → 2 unit.
  - `lesson linked to a DRAFT or RETIRED module stays in its topic unit`: unit `kind 'topic'`, `moduleSlug: null`.
  - `module unit position follows its smallest lesson order`: modul dengan lesson order 20 dan 30, topik dengan order 25 → `[module, topic]`.
- [ ] **Step 2: Jalankan** `cd apps/api && npx jest src/common/path-order.spec.ts`. Ekspektasi: FAIL (modul tidak ada).
- [ ] **Step 3: Implementasi** `groupPath` dan `flattenPath` di `path-order.ts`. Murni, tanpa Prisma. Pakai `Map` per key, lalu sort. Komentar header singkat yang merujuk spec §5.3.
- [ ] **Step 4: Jalankan** perintah yang sama. Ekspektasi: PASS.
- [ ] **Step 5: Commit** (di `apps/api`, branch baru `feat/satu-perjalanan`):
  ```bash
  git checkout -b feat/satu-perjalanan
  git add src/common/path-order.ts src/common/path-order.spec.ts
  git commit -m "feat(path): groupPath — unit & urutan langkah Perjalanan"
  ```

---

### Task 2: Semua modul LIVE masuk jalur + mesin sesi pakai urutan jalur

**Files:**
- Modify: `apps/api/src/common/content-scope.ts` (`PATH_LESSON`)
- Modify: `apps/api/src/session/session.service.ts:512-566` (`lessonCompletionInternal` → `path`), `:244-265` (pilihan berbicara)
- Modify: `apps/api/prisma/schema.prisma` (hapus `Module.showInPath`)
- Create: `apps/api/prisma/migrations/<timestamp>_satu_perjalanan/migration.sql`
- Modify: `apps/api/src/modules/admin-modules.service.ts:35,150-156,250,283` (hapus `showInPath`)
- Modify: `apps/api/prisma/seed-module-kit.ts:60-61,207`, `prisma/seed-eftl-1..5.ts` (hapus `showInPath`), `prisma/seed-module-complaints.ts:6-9` (komentar)
- Modify tests: `test/module-scope.e2e-spec.ts`, `test/session-speaking.e2e-spec.ts:30-62,196`, `test/modules-admin.e2e-spec.ts` (bila menyebut `showInPath`)
- Delete: `test/module-in-path.e2e-spec.ts`. Kasusnya pindah ke `module-scope`.

**Interfaces:**
- Consumes: `groupPath`, `flattenPath`, `PathLessonInput` (Task 1).
- Produces:
  ```ts
  // session.service.ts
  export type PathLesson = Lesson & {
    items: { id: string }[];                     // item LIVE
    moduleChapter: PathLessonInput['moduleChapter'];
  };
  async path(userId: string, level: Level, db?: Db): Promise<{
    units: PathUnit<PathLesson>[];
    lessons: PathLesson[];          // = flattenPath(units)
    done: Map<string, boolean>;
  }>;
  ```
- `lessonCompletion(userId, level)` tetap ada dengan signature yang sama, sekarang membungkus `path().done`.
- `PATH_LESSON` tetap bernama sama, tapi isinya `{ items: { some: { status: 'LIVE' } } }`.
  - Selalu dipakai bersama `status: 'LIVE'` (sudah begitu di semua call site).
  - Doc comment ditulis ulang: semua lesson LIVE yang punya item LIVE = jalur; modul tidak lagi mengecualikan (spec §5.6).
  - Call site di `monitoring.service.ts:651,777`, `journey.service.ts:49`, `summary.service.ts:207`, dan `reinforcementItems` tidak perlu diubah.

- [ ] **Step 1: Ubah test e2e menjadi semantik baru (gagal dulu).**
  - Di `module-scope.e2e-spec.ts`, kasus yang dulu menegaskan lesson bab modul LIVE **keluar** dibalik menjadi **masuk**:
    - `sesi harian memakai lesson bab modul LIVE bila itu langkah berikutnya`
    - `sesi berbicara memuat UCAPAN dari lesson bab modul LIVE`
    - `penguatan boleh memuat item lesson bab modul LIVE`
  - Kasus `lesson yang ditautkan ke modul DRAFT tetap di /journey` tetap.
  - Kasus `/journey …` dan `summary.nextLesson …` di file ini sesuaikan ke shape lama dulu: lesson bab kini **ada** di `topics`. Task 3 mengganti shape-nya.
  - Tambah: `mesin sesi mengikuti urutan bab, bukan Lesson.order`. Modul LIVE dengan bab 1 → lesson order 200 dan bab 2 → lesson order 100, user baru → `POST /session/today` memakai item lesson bab 1.
  - Pindahkan kasus berguna dari `module-in-path.e2e-spec.ts` lalu hapus file itu.
  - Di `session-speaking.e2e-spec.ts`: test lama mematikan `showInPath` supaya UCAPAN EFTL tidak ikut ke sesi berbicara DASAR. Ganti isolasinya dengan menyetel `status: 'DRAFT'` pada lesson-lesson EFTL DASAR di `beforeAll`, lalu kembalikan ke status asalnya di `afterAll`. Simpan id dan status asalnya.
- [ ] **Step 2: Jalankan** `npm run test:e2e -- module-scope session-speaking`. Ekspektasi: FAIL pada kasus yang dibalik.
- [ ] **Step 3: Skema + migrasi.**
  - Hapus field `showInPath` dari `model Module`.
  - Jalankan `npx prisma migrate dev --name satu_perjalanan --create-only`. Ganti isi SQL-nya dengan yang di bawah (renumber dulu, lalu drop):
  ```sql
  -- Spec §5.3: unit "Making & Handling Complaints" ke akhir Perjalanan MENENGAH,
  -- supaya karyawan yang sudah maju ke EFTL tidak ditarik mundur.
  WITH cmp AS (
    SELECT l.id, ROW_NUMBER() OVER (ORDER BY c."order") AS rn
    FROM "Lesson" l
    JOIN "ModuleChapter" c ON c."lessonId" = l.id
    JOIN "Module" m ON m.id = c."moduleId"
    WHERE m.slug = 'making-handling-complaints' AND l.level = 'MENENGAH'
  ), base AS (
    SELECT COALESCE(MAX("order"), 0) AS mx FROM "Lesson"
    WHERE level = 'MENENGAH' AND id NOT IN (SELECT id FROM cmp)
  )
  UPDATE "Lesson" l SET "order" = base.mx + cmp.rn FROM cmp, base WHERE l.id = cmp.id;

  ALTER TABLE "Module" DROP COLUMN "showInPath";
  ```
  - Lalu `npx prisma migrate dev` (terapkan ke DB dev) dan `npx prisma generate`.
- [ ] **Step 4: Verifikasi migrasi di DB dev.** Jalankan `npx prisma studio` atau psql:
  ```sql
  SELECT MIN(l."order") FROM "Lesson" l JOIN "ModuleChapter" c ON c."lessonId"=l.id JOIN "Module" m ON m.id=c."moduleId" WHERE m.slug='making-handling-complaints';
  SELECT MAX("order") FROM "Lesson" WHERE level='MENENGAH' AND code NOT LIKE 'CMP-%';
  ```
  Ekspektasi: nilai pertama > nilai kedua. (Bila DB dev tidak berisi modul Complaints, catat itu dan lanjut.)
- [ ] **Step 5: Implementasi.**
  - `PATH_LESSON` diganti seperti di Interfaces.
  - `SessionService.path()`:
    - Satu query lesson `{ level, status: 'LIVE', ...PATH_LESSON }` dengan `include: { items: { where: { status: 'LIVE' }, select: { id: true } }, moduleChapter: { select: { order: true, module: { select: { id: true, slug: true, title: true, status: true } } } } }`.
    - Satu query attempts benar (sama seperti `lessonCompletionInternal` sekarang).
    - Lalu `groupPath`.
  - Hapus `lessonCompletionInternal`. `nextLesson` dan pilihan berbicara memakai `path()`.
  - Item sesi berbicara diurutkan di memori: indeks lesson di `lessons`, lalu `item.order`. Ini menggantikan `orderBy lesson.order`.
  - `completionForLessons` tidak berubah.
- [ ] **Step 6: Admin + seed.**
  - Hapus `showInPath` dari `ModuleInput`, validasi `updateModule`, default `createModule`, dan view admin.
  - Hapus `showInPath` dari `seed-module-kit.ts` dan kelima `seed-eftl-N.ts`.
  - Perbarui komentar `seed-module-complaints.ts` (lesson CMP kini masuk Perjalanan sebagai unit modul).
  - Jalankan `npm run validate:module seed-eftl-1` → tetap lulus.
- [ ] **Step 7: Jalankan** `npm test && npm run test:e2e`. Ekspektasi: semua PASS. Bila `journey-progress` gagal hanya karena lesson bab modul kini ikut, perbaiki fixture-nya, jangan perilakunya.
- [ ] **Step 8: Commit**
  ```bash
  git add prisma/schema.prisma prisma/migrations src/common/content-scope.ts src/session/session.service.ts src/modules/admin-modules.service.ts prisma/seed-module-kit.ts prisma/seed-eftl-*.ts prisma/seed-module-complaints.ts test/module-scope.e2e-spec.ts test/session-speaking.e2e-spec.ts test/modules-admin.e2e-spec.ts
  git rm test/module-in-path.e2e-spec.ts
  git commit -m "feat(path): semua modul LIVE masuk Perjalanan, mesin sesi ikut urutan bab; hapus showInPath"
  ```

---

### Task 3: `GET /journey` berbentuk unit

**Files:**
- Modify: `apps/api/src/journey/journey.service.ts` (seluruhnya; tipe view baru)
- Modify: `apps/api/src/journey/journey.module.ts` (`exports: [JourneyService]` untuk Task 4)
- Modify: `apps/api/test/journey-progress.e2e-spec.ts:215` (assert shape baru)
- Create: `apps/api/test/journey-units.e2e-spec.ts` (prefix data `JU-`/`ju-`, level `MAHIR`, user baru per kasus, pola mengikuti `module-scope.e2e-spec.ts`)

**Interfaces:**
- Consumes: `SessionService.path()` (Task 2).
- Produces (diekspor dari `journey.service.ts`, disalin ke web di Task 5):
  ```ts
  export type JourneyStepState = 'done' | 'now' | 'locked';
  export interface JourneyStepView {
    kind: 'lesson' | 'chapter' | 'reading';
    id: string;                     // lessonId (lesson/chapter) | chapterId (reading)
    title: string;                  // judul lesson | judul bab
    state: JourneyStepState | null; // null untuk reading
    accuracy: number | null;        // first-try %, hanya done
    itemCount: number;              // 0 untuk reading
    chapter: { moduleSlug: string; chapterId: string; order: number; position: number; estMinutes: number } | null;
  }
  export interface JourneyUnitView {
    kind: 'topic' | 'module';
    title: string;
    moduleSlug: string | null;
    done: number;                   // langkah dihitung saja (lesson/chapter)
    total: number;
    steps: JourneyStepView[];
  }
  export interface JourneyView { units: JourneyUnitView[]; done: number; total: number }
  ```

**Aturan (spec §5.1–5.2):**
- **Status:**
  - `done` bila lesson tuntas, **di mana pun posisinya**.
  - Langkah pertama yang belum tuntas (urutan `path().lessons`) = `now`.
  - Sisanya `locked`.
- **Bab per unit modul:** ambil semua bab modul dengan satu query `moduleChapter.findMany({ where: { moduleId: { in } }, orderBy: { order: 'asc' } })`, berikut `lesson { status, level, items LIVE take 1 }`.
  - `position` = indeks 1-based di antara **semua** bab modul (sama dengan `ModulesService.rows`).
  - Bab yang lesson-nya ada di unit → `kind 'chapter'`.
  - Bab tanpa lesson, atau lesson tidak LIVE, atau lesson tanpa item LIVE → `kind 'reading'`.
  - Bab yang lesson-nya LIVE berisi tapi beda level → dilewati.
- **Akurasi:** hitung seperti sekarang (attempt `firstTry && correct`).

- [ ] **Step 1: Tulis test yang gagal** di `journey-units.e2e-spec.ts`:
  - `unit modul berisi bab urut ModuleChapter.order dengan posisi bab`: modul LIVE, bab 1 (lesson order 200), bab 2 bacaan, bab 3 (lesson order 100) → satu unit `module`, langkah `[chapter pos1, reading pos2, chapter pos3]`, `total 2`.
  - `bacaan tidak dihitung dan state null`: langkah reading `state: null, itemCount: 0`. `JourneyView.total` tidak menghitungnya.
  - `langkah selesai setelah now tetap done`: jawab benar semua item bab 3 (insert attempt langsung via prisma) → bab 1 `now`, bab 3 `done`.
  - `bab dengan lesson DRAFT/tanpa item LIVE tampil sebagai Bacaan`.
  - `modul yang semua babnya bacaan tidak muncul`.
  - `lesson modul DRAFT ada di unit topik`.
  - `lesson LIVE tanpa item LIVE tidak muncul sama sekali`.
  - `user tanpa level → { units: [], done: 0, total: 0 }`.
  - Di `journey-progress.e2e-spec.ts:215`: ubah ekspektasi `topics[...]` menjadi `units[...].steps[...]` dengan nilai yang sama (judul, state, akurasi, urutan unit by min order).
- [ ] **Step 2: Jalankan** `npm run test:e2e -- journey`. Ekspektasi: FAIL (shape lama).
- [ ] **Step 3: Implementasi** `JourneyService.get(userId): Promise<JourneyView>` sesuai aturan di atas. Total query: `path()` (2) + attempts firstTry (1) + bab modul (1). Tanpa N+1. Tambah `exports: [JourneyService]` di modul.
- [ ] **Step 4: Jalankan** `npm run test:e2e -- journey module-scope`. Kasus `/journey` di `module-scope` sesuaikan ke shape baru (lesson bab muncul sebagai `kind 'chapter'` di unit modul). Ekspektasi: PASS.
- [ ] **Step 5: Commit**
  ```bash
  git add src/journey test/journey-units.e2e-spec.ts test/journey-progress.e2e-spec.ts test/module-scope.e2e-spec.ts
  git commit -m "feat(journey): Perjalanan berbentuk unit — modul jadi unit berisi bab, bacaan tak dihitung"
  ```

---

### Task 4: Beranda — satu langkah berikutnya, sesi MODULE terbuka, hapus `moduleInProgress`

**Files:**
- Modify: `apps/api/src/me/summary.service.ts` (`getNextLesson` → dari Journey; `getOpenSession`; hapus `moduleInProgress`)
- Modify: `apps/api/src/me/me.module.ts` (import `JourneyModule`; hapus `ModulesModule` bila tak dipakai lagi)
- Modify: `apps/api/src/modules/modules.service.ts:214-232` + `modules.types.ts` (hapus `inProgressSummary`/`ModuleInProgressView` bila tak dipakai lagi; `pickInProgress` tetap untuk menu Modul)
- Modify tests: `test/module-scope.e2e-spec.ts` (kasus `summary.nextLesson`), `test/session-orphan.e2e-spec.ts:125`, `test/me.e2e-spec.ts` (bila menegaskan `moduleInProgress`)
- Test: tambah kasus di `test/journey-units.e2e-spec.ts`

**Interfaces:**
- Consumes: `JourneyService.get` dan `JourneyView` (Task 3).
- Produces (`SummaryView`, disalin ke web di Task 6):
  ```ts
  export interface NextLessonView {
    id: string;              // lessonId
    title: string;           // judul lesson | judul bab
    topic: string;           // judul unit
    itemCount: number;
    estMinutes: number;      // lesson: ceil(itemCount*0.75) (seperti sekarang); bab: chapter.estMinutes
    xpEstimate: number;      // rumus sekarang
    kind: 'lesson' | 'chapter';
    unit: { position: number; title: string };   // position 1-based di JourneyView.units
    chapter: { moduleSlug: string; chapterId: string; order: number; position: number } | null;
  }
  export interface OpenSessionView {
    lessonTitle: string | null;      // MODULE: judul bab
    answered: number;
    total: number;
    moduleChapterId: string | null;  // terisi hanya untuk sesi MODULE
  }
  // SummaryView: field moduleInProgress DIHAPUS.
  ```

- [ ] **Step 1: Tulis test yang gagal** di `journey-units.e2e-spec.ts`:
  - `summary.nextLesson = langkah now di /journey (lesson)`: `kind 'lesson'`, `unit.position` cocok, `chapter: null`.
  - `summary.nextLesson = langkah now di /journey (bab modul)`: `kind 'chapter'`, `title` = judul bab, `chapter.moduleSlug/order/position` cocok dengan step `now`.
  - `sesi MODULE terbuka tampil sebagai openSession`: `POST /session/module {chapterId}` → `summary.openSession.moduleChapterId === chapterId` dan `lessonTitle` = judul bab.
  - `sesi DAILY terbuka diutamakan atas MODULE`: buka keduanya hari ini → `openSession.moduleChapterId === null`.
  - `summary tidak lagi punya moduleInProgress`: `expect(body).not.toHaveProperty('moduleInProgress')`.
  - `user tanpa level → nextLesson null, contentExhausted true`, tanpa 500. (Cocokkan dengan perilaku `contentExhausted` yang ada. Bila sekarang berbeda untuk user tanpa level, pertahankan perilaku sekarang dan tegaskan itu.)
- [ ] **Step 2: Jalankan** `npm run test:e2e -- journey-units`. Ekspektasi: FAIL.
- [ ] **Step 3: Implementasi.**
  - `getNextLesson` memanggil `journey.get(userId)` dan mengambil step `state === 'now'` pertama beserta indeks unitnya. Hapus query lesson sendiri dan komentar "C2 mirror".
  - `getOpenSession`:
    - Cari dulu `kind IN (DAILY, SPEAKING)`. Bila tidak ada, cari `MODULE` (dua query, prioritas eksplisit).
    - Untuk MODULE, ikutkan `moduleChapter: { select: { id: true, title: true } }`.
    - Ganti komentar "Sengaja BUKAN COUNTED_SESSION_KINDS…".
  - Hapus `moduleInProgress` dari summary.
- [ ] **Step 4: Jalankan** `npm test && npm run test:e2e`. Ekspektasi: semua PASS. Perbarui `session-orphan:125` dengan `moduleChapterId: null` bila memakai `toEqual`.
- [ ] **Step 5: Commit**
  ```bash
  git add src/me src/modules/modules.service.ts src/modules/modules.types.ts test
  git commit -m "feat(summary): langkah berikutnya dari Perjalanan (lesson/bab), sesi MODULE terbuka, hapus moduleInProgress"
  ```

---

### Task 5: Web — Perjalanan per unit

**Files:**
- Modify: `apps/web/src/lib/api-types.ts:160-180` (tipe Journey diganti tipe dari Task 3)
- Modify: `apps/web/src/components/journey-path.tsx` (render unit dan langkah)
- Modify: `apps/web/src/app/(user)/journey/page.tsx` (aksi per jenis langkah, teks progres)

**Interfaces:**
- Consumes: `JourneyView`, `JourneyUnitView`, `JourneyStepView` (Task 3, disalin persis).
- Produces: `JourneyPath({ units, nowDisabled, onTapStep }: { units: JourneyUnitView[]; nowDisabled?: boolean; onTapStep: (step: JourneyStepView) => void })`.

**Perilaku (spec §5.4):** `tapStep(step)` di page:

| Langkah | Aksi |
|---|---|
| reading | `router.push('/modules/{slug}/{order}')` |
| chapter, bukan locked | `router.push('/modules/{slug}/{order}')` |
| lesson `now` | `tapNow()` (tetap `POST /session/today`) |
| lesson `done` | konfirmasi ulangi seperti sekarang |
| locked | toast seperti sekarang |

**Tampilan:**
- **Heading unit:**
  - eyebrow `Unit 01`, judul unit, `${done}/${total} selesai`.
  - Unit modul memakai ikon `BookOpenText`.
- **Langkah bab:**
  - small text `Bab {position} · Baca materi, lalu kerjakan kuis` (saat `now`).
  - Saat `done`: akurasi seperti sekarang.
- **Langkah reading:**
  - state label `Bacaan`, small `Bab {position} · Bacaan`.
  - Tidak bernomor marker. Tidak pernah tampil terkunci.
- **Penanda nomor langkah:** marker angka hanya menghitung langkah yang dihitung.
- **Header progres:** `<b>{done}</b> dari {total} langkah selesai`. Pakai `journey.done` dan `journey.total`, jangan dihitung ulang di web.
- **`next`:** step `now` pertama dari semua unit.
- **Tombol companion "Mulai belajar":** memanggil `tapStep(next)`.
- **Gaya:** ikuti kelas `learn-route-*` yang ada dan `docs/design-system.md`. Mockup acuan: opsi B (`.superpowers/brainstorm/88546-1792726112/content/satu-journey.html`).

- [ ] **Step 1: Ganti tipe** di `api-types.ts`. Jalankan `npm run build`. Ekspektasi: GAGAL di `journey-path.tsx` / `journey/page.tsx`. Itu daftar yang harus diubah.
- [ ] **Step 2: Implementasi** `JourneyPath` dan `tapStep` sesuai tabel.
- [ ] **Step 3: Jalankan** `npm run lint && npm run build`. Ekspektasi: lulus.
- [ ] **Step 4: Verifikasi di browser.**
  - Jalankan dev server (API + web via `.claude/launch.json` / `preview_start`). Login user MENENGAH (atau admin dengan level MENENGAH), lalu buka `/journey`.
  - Cek:
    - (a) unit "Making & Handling Complaints" ada di **akhir**, dengan bab bernomor;
    - (b) unit EFTL tampil sebagai unit modul;
    - (c) tap bab `now` membuka halaman bab;
    - (d) teks "X dari N langkah selesai".
  - Ambil screenshot. Cek juga lebar mobile (375px).
- [ ] **Step 5: Commit** (di `apps/web`, branch baru `feat/satu-perjalanan`):
  ```bash
  git checkout -b feat/satu-perjalanan
  git add src/lib/api-types.ts src/components/journey-path.tsx "src/app/(user)/journey/page.tsx"
  git commit -m "feat(journey): Perjalanan per unit — modul jadi unit berisi bab & bacaan"
  ```

---

### Task 6: Web — Beranda satu ajakan lanjut + hapus toggle admin

**Files:**
- Modify: `apps/web/src/lib/api-types.ts:104-135,423+` (`NextLessonView`, `OpenSessionView` dari Task 4; hapus `moduleInProgress` dan `ModuleInProgressView` bila tak dipakai lagi)
- Modify: `apps/web/src/components/hero.tsx`
- Modify: `apps/web/src/components/home-content.tsx:23-25` (hapus kartu "Lanjutkan modul" dan import yang jadi tak terpakai)
- Modify: `apps/web/src/app/(user)/home/page.tsx:54-65` (`startSession` merutekan)
- Modify: `apps/web/src/app/admin/modul/types.ts:43`, `apps/web/src/app/admin/modul/[id]/page.tsx:18,25,100-110` (hapus toggle `showInPath`)

**Interfaces:**
- Consumes: `NextLessonView`, `OpenSessionView` (Task 4).

**Perilaku (spec §5.5):**
- **`startSession` di home page:**
  - Bila `summary.openSession?.moduleChapterId` ada → `router.push('/session?module=' + id)`. `use-session` sudah memanggil `POST /session/module` yang melanjutkan sesi.
  - Bila tidak ada sesi terbuka dan `summary.nextLesson?.chapter` ada → `router.push('/modules/{moduleSlug}/{order}')`.
  - Selain itu, perilaku sekarang (`POST /session/today`).
- **Hero untuk `nextLesson.kind === 'chapter'`** (tanpa sesi terbuka):
  - judul `Bab {chapter.position} · {title}`
  - deskripsi `Unit {unit.position} · {unit.title}. Baca materinya dulu, lalu kerjakan kuis bab.`
  - meta `±{estMinutes} menit · +{xpEstimate} XP · {itemCount} soal`
- **Hero untuk `kind === 'lesson'`:** deskripsi `Unit {unit.position} · {topic}`, sisanya seperti sekarang.
- **Sesi terbuka, target tercapai, konten habis:** tidak berubah.

- [ ] **Step 1: Ganti tipe** di `api-types.ts`. Jalankan `npm run build`. Ekspektasi: GAGAL di `home-content.tsx` (`moduleInProgress`) dan di admin modul (`showInPath`).
- [ ] **Step 2: Implementasi** hero, home-content, `startSession`, dan penghapusan toggle admin.
- [ ] **Step 3: Jalankan** `npm run lint && npm run build`. Ekspektasi: lulus.
- [ ] **Step 4: Verifikasi di browser.**
  - (a) Beranda hanya punya satu kartu lanjut, tanpa "Lanjutkan modul".
  - (b) Bila langkah berikutnya bab modul, hero menampilkan "Bab N · …" dan tombol membuka halaman bab.
  - (c) Mulai kuis bab, kembali ke Beranda → "Lanjutkan sesimu" dengan judul bab, dan tombol kembali ke kuis.
  - (d) Admin `/admin/modul/[id]` tanpa toggle Perjalanan, dan simpan modul tetap berhasil.
  - Ambil screenshot desktop dan 375px.
- [ ] **Step 5: Commit**
  ```bash
  git add src/lib/api-types.ts src/components/hero.tsx src/components/home-content.tsx "src/app/(user)/home/page.tsx" src/app/admin/modul/types.ts "src/app/admin/modul/[id]/page.tsx"
  git commit -m "feat(home): satu ajakan lanjut dari Perjalanan (lesson/bab), hapus kartu Lanjutkan modul & toggle showInPath"
  ```

---

### Task 7: Dokumentasi workspace

**Files:**
- Modify: `CLAUDE.md` (Status: entri baru "Satu Perjalanan SELESAI", plus koreksi entri "Kuis modul di Perjalanan" dan "Menu Modul" yang menyebut `showInPath`/lesson tertaut keluar dari Perjalanan)
- Modify: `docs/superpowers/specs/2026-10-14-menu-modul-design.md` §9 (catatan: digantikan oleh spec satu-perjalanan)
- Create: `docs/superpowers/verifikasi/2026-10-satu-perjalanan-checklist.md` (checklist manual dari Step 4 di Task 5 dan Task 6, plus "karyawan MENENGAH yang sudah di EFTL tidak ditarik mundur" di data staging)

- [ ] **Step 1:** Tulis ketiga perubahan. Entri CLAUDE.md memuat:
  - jumlah suite akhir (unit + e2e)
  - path spec dan plan
  - catatan migrasi renumber CMP
  - bahwa `PATH_LESSON` kini berarti "lesson punya item LIVE"
- [ ] **Step 2: Commit** (repo workspace)
  ```bash
  git add CLAUDE.md docs/superpowers/specs/2026-10-14-menu-modul-design.md docs/superpowers/verifikasi/2026-10-satu-perjalanan-checklist.md docs/superpowers/plans/2026-10-23-satu-perjalanan.md
  git commit -m "docs: status Satu Perjalanan + checklist verifikasi"
  ```
