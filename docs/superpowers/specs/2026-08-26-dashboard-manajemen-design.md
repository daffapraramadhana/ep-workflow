# Dashboard Manajemen (Fase 3) — Spec Desain

**Tanggal:** 26 Agustus 2026 · **Status:** menunggu review
**Fondasi:** spec fondasi §6.3 (prinsip: aktivitas + tren per-orang, TANPA ranking/rata-rata skor antar-orang — level dipilih sendiri membuat perbandingan lintas-orang tidak valid). Spec ini tidak mengubah keputusan fondasi/Fase 2.
**Design system:** `docs/design-system.md` §6 (mimic guide admin — tanpa bunyi/confetti/nav mengambang).

---

## 1. Keputusan terkunci

| # | Keputusan | Pilihan |
|---|---|---|
| 1 | Bentuk | Seksi baru di app admin yang sama — BUKAN aplikasi terpisah |
| 2 | Landing admin | `/admin/ringkasan` setelah login (menggantikan Import Soal) |
| 3 | Role | Satu role ADMIN (pemisahan Konten vs HR ditunda sampai terbukti perlu) |
| 4 | Ambang "Butuh Perhatian" | `config.MONITOR_INACTIVE_DAYS` (default `5`) — tanpa UI pengaturan |
| 5 | Yang DITOLAK | Leaderboard, rata-rata skor organisasi, breakdown per-departemen (tidak ada field departemen), lib chart baru |

## 2. Navigasi admin

Sidebar admin dua kelompok berlabel (label eyebrow kecil, gaya design system):

```
PEMANTAUAN            KONTEN
├ Ringkasan           ├ Import Soal
├ Karyawan            ├ Soal & Lesson
└ Laporan Soal        ├ Media
                      └ Undang Karyawan   (halaman /admin/users yang ada)
```

Login sukses → `router.push('/admin/ringkasan')`.

## 3. Definisi metrik (semua dihitung BE; "hari" = WIB)

| Metrik | Definisi |
|---|---|
| **Aktif** | ≥1 sesi DAILY COMPLETED dalam 7 hari terakhir (termasuk hari ini) |
| **On-track** | Target harian tercapai pada ≥5 dari 7 hari terakhir |
| **Butuh perhatian** | Onboarded, tapi tidak ada sesi COMPLETED selama ≥ `MONITOR_INACTIVE_DAYS` hari |
| **Belum mulai** | Akun dibuat tapi `onboardedAt` null |
| **Tren akurasi** (per orang) | Akurasi first-try 14 hari terakhir vs 14 hari sebelumnya. ↗ = naik ≥5 poin persen; ↘ = turun ≥5; → = selainnya; ∅ "belum cukup data" bila salah satu jendela < 10 attempt first-try |
| **Soal bermasalah** | Wrong-rate first-try tertinggi, minimum 5 jawaban first-try, item LIVE |
| **Kehabisan konten** | % user onboarded per level yang semua lesson LIVE level-nya sudah selesai |

Status per-orang adalah SATU nilai dengan prioritas: `belum_mulai > butuh_perhatian > on_track > aktif` — hindari orang muncul di dua kategori. ("Aktif" kartu ringkasan = hitungan definisi aktif murni; kartu-kartu ringkasan boleh saling tumpang tindih dan itu wajar, tabel karyawan memakai status prioritas.)

Skor mentah/akurasi antar-orang TIDAK ditampilkan sebagai kolom yang bisa diurutkan — hanya panah tren.

## 4. Endpoint BE — modul `monitoring` (semua `JwtAuthGuard + RolesGuard @Roles('ADMIN')`)

```
GET /admin/monitoring/overview →
{ totals: { employees, active, onTrack, needsAttention, notStarted },
  activitySeries: [{ date, sessionsCompleted }] /* 28 hari, termasuk 0 */,
  contentHealth: {
    hardestItems: [{ itemId, lessonId, lessonTitle, prompt(80c), wrongRate, answers }] /* top 5 */,
    exhaustedByLevel: [{ level, exhaustedPct, users }] },
  openReports: number }

GET /admin/monitoring/employees →
[{ id, name, email, level|null, status: 'aktif'|'on_track'|'butuh_perhatian'|'belum_mulai',
   activeDays7, sessionsThisWeek, streak, lessonsDone,
   trend: 'up'|'down'|'flat'|null, lastActiveAt|null }]

GET /admin/monitoring/employees/:id →
{ name, email, level, joinedAt, streak, longestStreak, xpTotal,
  calendar: [{ date, state: 'met'|'partial'|'frozen'|'empty' }] /* 56 hari */,
  skills: [{ skill, answered, accuracy|null }] /* first-try, format /progress */,
  lessonHistory: [{ lessonId, title, topic, completedAt, accuracy }] }

GET /admin/reports?status=OPEN|RESOLVED →
[{ id, note, status, createdAt, reporter: { name },
   item: { id, lessonId, prompt(120c), type, status } }]

PATCH /admin/reports/:id  { status: 'RESOLVED' } → 200
```

- Semua read-only kecuali PATCH reports. Tidak ada endpoint delete.
- Streak per-orang memakai `StreakService.evaluate` yang ada; agregasi lain query langsung (attempt/session groupBy) — hindari N+1: satu query per metrik, gabung di memori (pola journey/progress).
- Kinerja: 20-50 user pilot — komputasi on-request tanpa cache boleh; JANGAN menambah cron/materialized view (fondasi: tanpa background job).

## 5. Layar

### /admin/ringkasan
1. **5 kartu angka** (pola stat-card design system): Karyawan · Aktif · On-track · Butuh Perhatian (amber, klik → tabel Karyawan berfilter) · Belum Mulai. Badge kecil "N laporan soal terbuka" bila `openReports > 0` → tautan.
2. **Grafik sesi per hari (28 hari)** — SVG line/area tulis-tangan (±60 baris; tanpa lib): sumbu-x tanggal tiap 7 hari, tooltip hover per titik, area fill brand-soft. Ikuti prinsip dataviz design system (kontras, bukan-warna-saja: nilai tertera di tooltip + titik).
3. **Kesehatan konten** — dua kartu: "Soal paling sering salah" (5 baris: prompt terpotong · wrong-rate% · n jawaban · tombol *Lihat* → `/admin/content/{lessonId}`) dan "Kehabisan konten" (bar per level + % + jumlah user; kosong → "Semua level masih punya konten ✅").

### /admin/karyawan  (rename nav "Pemantauan → Karyawan"; route baru, TIDAK menyentuh /admin/users yang ada)
- Tabel: Nama · Hari aktif (7h, "5/7") · Sesi minggu ini · Streak (🔥N) · Lesson selesai · Tren (ikon TrendingUp/TrendingDown/Minus Lucide + label sr-only; ∅ = "—") · Status (pill berwarna: hijau on_track, biru aktif, amber butuh_perhatian, abu belum_mulai).
- Filter pill status (klik kartu ringkasan membawa `?status=`), pencarian nama client-side, sort default: butuh_perhatian dulu, lalu nama.
- **Unduh CSV** — `downloadCsv()` klien yang ada, kolom = kolom tabel + email + lastActiveAt.
- Klik baris → **panel detail** (route `/admin/karyawan/[id]`, bukan modal): header identitas + 3 stat (streak · terpanjang · XP) · **kalender aktivitas 56 hari** (grid 8×7, pola visual kalender-streak yang ada; met=brand, partial=brand-soft, frozen=sky 🧊, empty=abu) · bar 4 skill (komponen skill-row yang ada) · riwayat lesson (judul · topic · tanggal · akurasi).

### /admin/laporan
- Tab OPEN (default) / RESOLVED. Baris: prompt soal (terpotong) · tipe · catatan pelapor · nama pelapor · tanggal · aksi: **Lihat soal** (→ halaman edit lesson yang ada) · **Tandai selesai** (PATCH; optimistic, pindah tab).
- Kosong → "Tidak ada laporan terbuka 🎉" (satu-satunya emoji yang diizinkan di admin: state kosong positif — konsisten aturan emoji perayaan).

## 6. Data & skema

**Tanpa migrasi.** Semua metrik dihitung dari tabel yang ada (`session`, `attempt`, `review_queue`, `item_report`, `streak_freeze`, `user`, `lesson`, `item`). Satu baris config baru di seed: `MONITOR_INACTIVE_DAYS = 5` (upsert idempoten — seed berjalan tiap boot).

## 7. Error & state

Pola halaman admin yang ada: loading skeleton, error inline + retry. Tabel kosong (belum ada karyawan) → arahkan ke Undang Karyawan. Grafik dengan <7 hari data tetap render (deret selalu 28 titik, 0 termasuk).

## 8. Pengujian

- BE e2e (`monitoring.e2e-spec`): seed terkontrol per definisi — kasus batas: aktif tepat 7 hari lalu (masuk) vs 8 hari (keluar); on-track 5/7 vs 4/7; tren tepat +5pp (↗) vs +4.9pp (→); jendela <10 attempt → null; wrong-rate minimum 5 jawaban; prioritas status; RolesGuard 403 untuk USER.
- Reports e2e: list filter status, PATCH resolve, USER → 403.
- FE: verifikasi manual terskrip (desktop; admin tidak dipakai di HP pada pilot, cukup cek tidak pecah di 768px).

## 9. Di luar cakupan

Pemisahan role admin · UI pengaturan ambang · export XLSX/PDF · grafik per-departemen · notifikasi email "butuh perhatian" · cache/agregasi terjadwal → backlog, sebagian menunggu bukti kebutuhan dari pilot.
