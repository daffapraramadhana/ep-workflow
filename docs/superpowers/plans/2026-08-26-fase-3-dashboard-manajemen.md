# Fase 3 — Dashboard Manajemen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Seksi Pemantauan di app admin — ringkasan organisasi (angka + grafik 28 hari + kesehatan konten), tabel karyawan dengan tren per-orang + detail + CSV, dan antrean laporan soal — di atas endpoint agregasi BE baru.

**Architecture:** Modul BE baru `monitoring` (read-only) + `reports` controller di ContentModule; FE menambah 4 route `/admin/{ringkasan,karyawan,karyawan/[id],laporan}` + regrouping sidebar. Tanpa migrasi skema; satu baris config baru via seed. Tanpa lib chart (SVG tulis-tangan).

**Tech Stack:** Stack yang ada (NestJS+Prisma / Next+Tailwind+Lucide). Tidak ada dependensi baru.

**Spec:** `docs/superpowers/specs/2026-08-26-dashboard-manajemen-design.md` — §3 definisi metrik dan §4 kontrak endpoint adalah OTORITAS; angka & shape di plan ini disalin dari sana. Baca juga design-system §6 (mimic admin) sebelum task FE.

## Global Constraints

- Commit api di `apps/api`, web di `apps/web`, JANGAN dari workspace root. Postgres lokal (role app/app, db english_app) untuk e2e.
- Semua endpoint monitoring/reports `@UseGuards(JwtAuthGuard, RolesGuard)` + `@Roles('ADMIN')`; USER → 403 (dites).
- DILARANG: kolom/sort skor antar-orang, leaderboard, migrasi skema, cron/cache, lib chart, bunyi/confetti di admin.
- "Hari" = WIB (`todayWIB/addDays` dari src/common/wib.ts). Ambang: `config.MONITOR_INACTIVE_DAYS` default '5' (via AppConfigService; TAMBAHKAN ke CONFIG map prisma/seed.ts — upsert idempoten).
- Definisi metrik persis spec §3: aktif=≥1 DAILY COMPLETED ≤7 hari; on-track=target tercapai ≥5/7 hari; butuh_perhatian=onboarded & tanpa sesi COMPLETED ≥ambang hari; belum_mulai=onboardedAt null; status tunggal prioritas belum_mulai>butuh_perhatian>on_track>aktif; tren=akurasi firstTry 14h terakhir vs 14h sebelumnya, ↗≥+5pp ↘≤-5pp else →, null bila jendela <10 attempt; soal bermasalah=wrong-rate firstTry min 5 jawaban item LIVE; kehabisan konten=% user onboarded per level yang menyelesaikan semua lesson LIVE levelnya.
- Anti-N+1: agregasi via groupBy/agregat + gabung memori (pola journey/progress); `lessonCompletion` & `StreakService.evaluate` yang ada di-reuse.
- e2e hygiene: prefix `P3M-`, cleanup FK-safe, jangan sentuh admin seed; tanggal sesi/attempt di-seed eksplisit via Prisma (jangan tergantung "hari ini" kecuali disengaja).
- Copy Indonesia; ikon Lucide strokeWidth 2.25; emoji admin HANYA state kosong positif ("Tidak ada laporan terbuka 🎉").

---

### Task 1: BE — fungsi metrik murni + `GET /admin/monitoring/overview`

**Files:**
- Create: `apps/api/src/monitoring/monitoring.module.ts`, `monitoring.service.ts`, `monitoring.controller.ts`, `metrics.ts` (murni)
- Modify: `apps/api/prisma/seed.ts` (CONFIG += `MONITOR_INACTIVE_DAYS: '5'`), `src/app.module.ts`
- Test: `apps/api/src/monitoring/metrics.spec.ts` (unit), `apps/api/test/monitoring-overview.e2e-spec.ts`

**Interfaces:**
- Consumes: wib utils, AppConfigService, PrismaService, guards.
- Produces — `metrics.ts` murni (dipakai Task 2 juga):

```ts
export type EmployeeStatus = 'aktif' | 'on_track' | 'butuh_perhatian' | 'belum_mulai';
export interface DayCount { date: string /* YYYY-MM-DD */; count: number }

/** hari "tercapai" = completed >= target (target minimal 1) */
export function metDays(perDayCompleted: Map<string, number>, target: number, days: string[]): number;

export function computeStatus(args: {
  onboarded: boolean;
  lastCompletedDate: string | null;  // YYYY-MM-DD WIB
  today: string;
  inactiveThresholdDays: number;
  metDaysLast7: number;
  activeLast7: boolean;              // >=1 completed session in last 7 days
}): EmployeeStatus;
// urutan: !onboarded -> belum_mulai;
// lastCompletedDate null ATAU selisih hari >= threshold -> butuh_perhatian;
// metDaysLast7 >= 5 -> on_track; else -> aktif (activeLast7 tidak dipakai untuk
// cabang terakhir — orang yang lolos cek threshold pasti pernah aktif; param
// disimpan untuk kartu ringkasan).

export function computeTrend(recent: { correct: number; total: number },
                             prior: { correct: number; total: number }):
  'up' | 'down' | 'flat' | null;
// null bila recent.total < 10 || prior.total < 10;
// delta = (recent.correct/recent.total - prior.correct/prior.total) * 100;
// >= 5 -> up; <= -5 -> down; else flat. Batas: delta tepat 5.0 -> up; 4.9 -> flat.
```

- Endpoint: `GET /admin/monitoring/overview` → shape persis spec §4 (totals{employees,active,onTrack,needsAttention,notStarted}, activitySeries 28 entri termasuk 0, contentHealth{hardestItems top-5, exhaustedByLevel}, openReports).
  Catatan hitung: `totals` dari status prioritas per user KECUALI `active` = hitungan definisi aktif murni (spec §3 alinea terakhir); `onTrack/needsAttention/notStarted` dari status prioritas.

- [ ] **Step 1: Unit test murni** `metrics.spec.ts` — kasus WAJIB: status keempat cabang + batas (tidak aktif tepat `threshold` hari → butuh_perhatian; `threshold-1` → bukan); metDays 5/7 → on_track vs 4/7 → aktif; trend +5.0pp → up, +4.9 → flat, -5.0 → down; jendela 9 attempt → null; prior 0 total → null. RED → implement `metrics.ts` → GREEN.
- [ ] **Step 2: Failing e2e** `monitoring-overview.e2e-spec.ts` — seed `P3M-` (2 lesson LIVE + item; user A aktif+on-track [sesi met 5 hari beruntun], user B butuh-perhatian [sesi terakhir 6 hari lalu], user C belum onboard; attempt salah-banyak pada 1 item [6 firstTry salah dari 8] untuk hardestItems; 1 item_report OPEN): assert totals per definisi, activitySeries.length === 28 & jumlah sesi cocok, hardestItems[0] = item tsb dengan wrongRate 75, openReports 1, USER token → 403.
- [ ] **Step 3: Implement service+controller** — satu query per metrik: sessions 28 hari groupBy date; users findMany (onboardedAt, dailyTargetSessions); sessions 7+threshold hari per user (satu findMany where date >= X, group di memori); attempts firstTry 28 hari (untuk trend TIDAK di task ini — overview tak butuh trend); wrong-rate: groupBy itemId pada attempt firstTry (correct true/false) join item LIVE; exhausted: reuse `SessionService.lessonCompletion` per level user. Daftarkan modul di AppModule; tambah seed key; `npx prisma db seed`.
- [ ] **Step 4:** Full suite green. **Step 5: Commit** — `"feat(monitoring): pure metrics + overview endpoint"`

---

### Task 2: BE — employees list + detail

**Files:**
- Modify: `apps/api/src/monitoring/monitoring.service.ts`, `monitoring.controller.ts`
- Test: `apps/api/test/monitoring-employees.e2e-spec.ts`

**Interfaces:**
- Consumes: `metrics.ts` Task 1, `StreakService.evaluate` (longest juga), progress-style skill aggregate.
- Produces: `GET /admin/monitoring/employees` dan `GET /admin/monitoring/employees/:id` — shape persis spec §4. Kalender 56 hari: state `met` (completed>=target), `partial` (>=1 tapi <target), `frozen` (StreakFreeze.coveredDate), `empty`. `lessonHistory.completedAt` = tanggal attempt benar TERAKHIR yang menuntaskan lesson (approx: max(answeredAt) attempt benar pada item lesson itu); accuracy = firstTry % item lesson.

- [ ] **Step 1: Failing e2e** — seed `P3M2-`: user dengan trend up (14h terakhir 9/10 benar vs sebelumnya 5/10), user trend null (<10), verifikasi urutan default TIDAK di-BE (FE yang sort) — BE kembalikan apa adanya urut nama; detail: kalender 56 entri dengan met/partial/frozen/empty masing-masing muncul; :id user lain valid; id tak ada → 404; USER → 403.
- [ ] **Step 2: Implement** — list: query batch (users + sessions 14h*2 + attempts firstTry 28 hari dalam 2 jendela via 1 findMany date>=28h lalu, split memori) + `computeStatus`/`computeTrend`; detail: reuse StreakService.evaluate (streak, longest, frozenDates→calendar), xpTotal pola summary, skills pola progress, lessonHistory via lessonCompletion + attempt max date.
- [ ] **Step 3:** Full suite green. **Step 4: Commit** — `"feat(monitoring): employees list + per-employee detail"`

---

### Task 3: BE — laporan soal (list + resolve)

**Files:**
- Create: `apps/api/src/content/admin-reports.controller.ts` (masuk ContentModule)
- Test: `apps/api/test/admin-reports.e2e-spec.ts`

**Interfaces:**
- Produces: `GET /admin/reports?status=OPEN|RESOLVED` (default OPEN; status lain → 400) → shape spec §4 (include reporter.name, item{id,lessonId,prompt≤120,type,status}); `PATCH /admin/reports/:id {status:'RESOLVED'}` → 200 (id tak ada → 404; body selain RESOLVED → 400). Urut createdAt desc.

- [ ] **Step 1: Failing e2e** — seed `P3R-` user+item+2 report (1 OPEN 1 RESOLVED): filter bekerja; resolve OPEN → muncul di RESOLVED; USER → 403; status query aneh → 400.
- [ ] **Step 2: Implement** (thin controller + prisma include). **Step 3:** suite green. **Step 4: Commit** — `"feat(admin): item report queue endpoints"`

---

### Task 4: FE — sidebar regroup + landing + halaman Ringkasan

**Files:**
- Modify: `apps/web/src/app/admin/layout.tsx` (grup PEMANTAUAN/KONTEN + item baru), `apps/web/src/app/admin/login/page.tsx` (redirect → `/admin/ringkasan`)
- Create: `apps/web/src/app/admin/ringkasan/page.tsx`, `apps/web/src/components/admin/activity-chart.tsx`, `apps/web/src/lib/api-types.ts` (tambah tipe monitoring — MIRROR persis §4)

**Interfaces:**
- Produces: `ActivityChart({series}: {series: {date:string; sessionsCompleted:number}[]})` — SVG 100%×160px: area fill `--brand-soft`, garis `--brand` 2.5px, titik hover + tooltip (nilai & tanggal, `<title>` + div absolute), label sumbu-x tiap 7 hari, sumbu-y 3 garis bantu. Tanpa lib.
- Halaman Ringkasan per spec §5: 5 stat-card (Butuh Perhatian amber & clickable → `/admin/karyawan?status=butuh_perhatian`; badge laporan → `/admin/laporan`), ActivityChart, 2 kartu kesehatan konten (baris hardestItems + tombol Lihat → `/admin/content/{lessonId}`; exhausted bar per level, kosong → "Semua level masih punya konten ✅"). Skeleton + error/retry pola admin.

- [ ] **Step 1:** Tipe + sidebar regroup (label eyebrow kecil di sidebar, dua kelompok, nav item: Ringkasan `Gauge`, Karyawan `Users`, Laporan Soal `Flag`; kelompok KONTEN memakai item lama; "Karyawan" lama di-relabel **"Undang Karyawan"**). Login redirect + root admin index? — `/admin` tidak ada route: biarkan (guard sudah menangani); update tautan yang menunjuk `/admin/import` pasca-login.
- [ ] **Step 2:** ActivityChart + halaman. **Step 3:** build+lint; verifikasi manual dengan server hidup (data seed P3M boleh dipakai ulang atau seed via UI). **Step 4: Commit** — `"feat(admin): monitoring nav regroup + ringkasan page with activity chart"`

---

### Task 5: FE — halaman Karyawan (tabel + filter + CSV) + detail

**Files:**
- Create: `apps/web/src/app/admin/karyawan/page.tsx`, `apps/web/src/app/admin/karyawan/[id]/page.tsx`

**Interfaces:**
- Consumes: endpoints Task 2, `downloadCsv` (src/lib/csv.ts), pill status CSS (`.status-pill-*` ada; tambah varian warna status karyawan di globals bila perlu).
- Produces per spec §5: tabel + filter pill status (init dari `?status=`), search nama client-side, sort default butuh_perhatian→nama; tren = `TrendingUp`(good)/`TrendingDown`(bad)/`Minus`(muted)/"—" + `sr-only` label; Unduh CSV (kolom tabel + email + lastActiveAt). Detail: header + 3 stat, kalender 56 hari grid 8×7 (met=brand, partial=brand-soft, frozen=sky, empty=line; legend), skill bars (reuse pola skill-row), riwayat lesson. Baris → `router.push`.

- [ ] **Step 1:** Tabel + filter + CSV. **Step 2:** Detail page. **Step 3:** build+lint + verifikasi manual (klik kartu ringkasan → filter terpasang; CSV terunduh benar kolomnya). **Step 4: Commit** — `"feat(admin): employees monitoring table + detail"`

---

### Task 6: FE — halaman Laporan Soal + verifikasi lintas-alur admin

**Files:**
- Create: `apps/web/src/app/admin/laporan/page.tsx`

**Interfaces:**
- Consumes: endpoints Task 3.
- Produces per spec §5: tab OPEN/RESOLVED; baris (prompt terpotong · tipe · catatan · pelapor · tanggal · Lihat soal → `/admin/content/{lessonId}` · Tandai selesai [OPEN saja] — optimistic: hapus dari list, PATCH, gagal → kembalikan + toast). Kosong OPEN → "Tidak ada laporan terbuka 🎉".

- [ ] **Step 1:** Implement halaman. **Step 2: Verifikasi manual terskrip seluruh Fase 3** (kedua server; seed konten via template + akun test; buat laporan dari sesi user; jalankan: login → mendarat Ringkasan (angka benar vs psql) → klik Butuh Perhatian → tabel terfilter → detail karyawan (kalender masuk akal) → CSV → Laporan: resolve bekerja → cek 768px tidak pecah). Bersihkan data test; catat hasil ke report file task. **Step 3:** build+lint. **Step 4: Commit** — `"feat(admin): item reports queue page"`

---

## Self-Review (sudah dijalankan)

- **Spec coverage:** §2 nav/landing→T4 · §3 metrik→T1 (murni+unit) · §4 endpoint→T1/T2/T3 · §5 ringkasan→T4, karyawan→T5, laporan→T6 · §6 config-only→T1 seed · §7 state→T4-6 (pola admin) · §8 test→T1-T3 e2e + T6 verifikasi manual. Kasus batas §8 semuanya tercantum di T1 Step 1 & T2 Step 1.
- **Placeholder scan:** bersih — semua step menunjuk shape/aturan konkret (§4 disalin ke Interfaces; fungsi murni berkode lengkap di kontraknya).
- **Type consistency:** `EmployeeStatus/computeStatus/computeTrend` (T1) dipakai T2; shape endpoint T1-T3 = tipe FE T4-T6; nama route `/admin/{ringkasan,karyawan,laporan}` konsisten di T4-T6.
