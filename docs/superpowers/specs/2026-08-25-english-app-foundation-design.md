# Fluen (Daily English Learning Platform) — Spec Fondasi (Rilis 1)

**Tanggal:** 25 Agustus 2026
**Status:** Menunggu review
**Cakupan spec ini:** model data & template konten, engine sesi harian, grading & gamification, arsitektur, pemetaan jadwal. **UI/UX dibahas di spec terpisah** setelah spec ini disetujui.

---

## 1. Konteks & Batasan

Rilis pertama platform belajar bahasa Inggris harian untuk karyawan, sesuai deck penawaran "Breakdown Timeline":

- **Anggaran:** Rp 8.000.000 fixed-price · **40 hari kerja / 8 minggu** · dikerjakan solo.
- **Bentuk:** 2 aplikasi web (user + admin), responsive mobile & PC. Tanpa app native.
- **Konten (materi, soal, kunci jawaban) dari tim klien.** Kita menyediakan template (dikirim minggu 1) dan alat. Materi ditargetkan siap minggu 6.
- **Pilot:** 20–50 karyawan.
- **Di luar Rilis 1:** placement test, assessment berkala, notifikasi, jalur personal, AI tutor, speaking/speech recognition, leaderboard.

### Posisi strategis

Demo/pilot yang meyakinkan, **tetapi model data dan skema pencatatan dibuat benar sejak awal** — karena dua hal itu mahal diperbaiki belakangan:

1. **Skema item & tagging** — konten yang sudah ditulis tim klien tidak boleh perlu ditulis ulang saat Rilis 2.
2. **Tabel `attempt`** — data jawaban yang tidak dicatat hari ini hilang permanen; Rilis 2 ("Pengukuran") mustahil tanpanya.

Yang boleh sederhana: engine pemilihan soal (rule-based, bukan adaptif), spaced repetition (SM-2 minimal), tanpa kalibrasi difficulty otomatis.

### Risiko terbesar proyek

**Bentuk template spreadsheet minggu 1.** Template adalah skema database yang menyamar; ia dikunci saat kita paling sedikit tahu, dan baru teruji saat materi masuk minggu 6. Mitigasi utama: **minta 10 soal asli dari tim klien di minggu 2** dan jalankan melalui importer — semua salah paham template ketahuan selagi masih ada 4 minggu.

---

## 2. Keputusan Fondasi (sudah diputuskan)

| # | Keputusan | Pilihan |
|---|---|---|
| 1 | Tipe soal | **3 tipe + lapisan media**: pilihan ganda, isian, susun kalimat. Audio/gambar/passage adalah lampiran pada soal, bukan tipe tersendiri. |
| 2 | Struktur konten | **Hybrid**: Lesson (paket tetap ~8–10 soal) + slot review otomatis dari jawaban salah. |
| 3 | Level | **Label ramah di permukaan** (Dasar / Menengah / Mahir), **tag CEFR (A1–C2) di database** per lesson & soal. User memilih levelnya sendiri (tanpa placement test di Rilis 1). |
| 4 | Dashboard manajemen | **Aktivitas + tren per-orang, tanpa ranking skor.** "Butuh perhatian" = tidak aktif, bukan skor rendah. Skor mentah tetap dicatat penuh untuk Rilis 2. |
| 5 | Jalur konten | **Spreadsheet + importer** (dengan laporan error per baris) + form edit di admin untuk perbaikan satuan. |
| 6 | Target harian | **Jumlah sesi** (internal), ditampilkan dengan estimasi menit ("1 sesi · ±7 menit"). |
| 7 | Stack | **Next.js (satu app: `/` user + `/admin`) + BE standalone (NestJS + Prisma) + Postgres + object storage.** |

Konsekuensi keputusan #1 dan absennya speech: **Speaking dihapus dari halaman progress Rilis 1** (bukan ditampilkan "segera hadir"). Skill yang dilacak: Vocabulary, Grammar, Listening, Reading.

---

## 3. Model Data

### 3.1 Tabel inti

```
user          id · nama · email · role(user|admin) · level_pilihan
              · target_sesi_harian · status_undangan
lesson        id · kode · judul · topic · level · cefr · skill
              · urutan · status(draft|live|retired)
item          id · lesson_id · type(pilihan_ganda|isian|susun_kalimat)
              · prompt · options(json) · answer_key · accepted_answers
              · explanation · media_file · passage · urutan
              · status(draft|live|retired)
session       id · user_id · tanggal · status(berjalan|selesai) · selesai_pada
session_item  session_id · item_id · sumber(lesson|review) · urutan
attempt       id · user_id · item_id · session_id · jawaban(raw)
              · benar · percobaan_pertama(bool) · dijawab_pada
review_queue  user_id · item_id · jatuh_tempo · benar_beruntun
item_report   id · user_id · item_id · catatan · dibuat_pada · status
config        key · value   -- angka XP, batas harian, dsb.
streak_freeze user_id · minggu · terpakai_pada
```

**Aturan keras:**

- `attempt` mencatat **setiap** jawaban, satu baris per jawaban, selamanya. Tidak boleh disederhanakan atau di-agregasi-lalu-hapus.
- Soal `retired` berhenti disajikan tapi **tidak pernah dihapus** — `attempt` merujuknya.
- Akurasi apa pun yang ditampilkan dihitung **hanya dari `percobaan_pertama = true`**.

### 3.2 Hierarki konten

`Level → Lesson → Item`. **Tidak ada tabel Unit** — pengelompokan tematik lewat kolom `topic` (teks bebas). Satu tingkat hierarki lebih sedikit = satu sumber kesalahan pengisian lebih sedikit.

### 3.3 Siklus hidup soal

`draft → live → retired`. Import selalu masuk **draft**; admin klien yang menaikkan ke live. Jalur perawatan konten pasca-serah-terima: laporan user (`item_report`) → admin edit/retire → tanpa deploy, tanpa vendor.

---

## 4. Template Spreadsheet (dikirim minggu 1)

**Prinsip: satu baris = satu soal.** Metadata lesson diulang tiap baris. Redundan secara database, benar secara manusia: bisa difilter, dibagi per penulis, direview atasan. Importer yang menormalkan.

| Kolom | Contoh | Wajib |
|---|---|---|
| `lesson_code` | `BUS-01` | ✓ |
| `lesson_title` | Email Perkenalan | ✓ |
| `topic` | Business English | ✓ |
| `level` | Menengah | ✓ |
| `cefr` | B1 | ✓ |
| `skill` | Vocabulary | ✓ |
| `item_order` | 1 | ✓ |
| `type` | `pilihan_ganda` | ✓ |
| `prompt` | What does "schedule" mean? | ✓ |
| `option_a`…`option_d` | Jadwal · Pertemuan · … | pilihan ganda saja |
| `answer` | `A` / kalimat lengkap | ✓ |
| `accepted_answers` | `jadwal;agenda` | isian saja |
| `explanation` | "Schedule" = daftar waktu kegiatan. | ✓ |
| `media_file` | `audio_001.mp3` | opsional |
| `passage` | (teks bacaan) | opsional |

**Keputusan format yang menyederhanakan:**

- **`susun_kalimat`:** penulis mengisi `answer` dengan kalimat benar; engine memecah & mengacak kepingan. Tidak ada kolom urutan.
- **`isian`:** tanda `___` di dalam `prompt`; `accepted_answers` menampung variasi sah dipisah `;`. Penilaian menormalkan kapitalisasi & spasi.
- **Media di luar spreadsheet:** file diunggah ke folder media admin; kolom `media_file` hanya merujuk nama. Rujukan yang tidak ketemu dilaporkan per baris saat import.
- **`explanation` wajib** — memaksa penulis memverifikasi kuncinya sendiri (QA termurah yang ada), dan dipakai di layar feedback.

**Importer:** validasi per baris (enum level/cefr/skill/type, kunci jawaban cocok dengan tipe, media_file ada), laporan error per-baris yang bisa diunduh, import ulang idempoten berbasis `lesson_code + item_order`.

**Importer kedua (pola sama):** CSV karyawan (nama + email) → akun + link undangan. Tanpa halaman registrasi publik.

---

## 5. Engine Sesi Harian

### 5.1 Perakitan (saat user membuka aplikasi — tanpa cron)

```
1. Ambil review jatuh tempo dari review_queue      → maks 3 soal
2. Ambil lesson live berikutnya (level user, kolom urutan) → ~8–10 soal
3. Selipkan review di antara soal lesson, posisi acak
```

Deterministik, tanpa adaptivitas. Urutan kurikulum = kolom `urutan` yang diisi penulis konten.

- **Sesi dibekukan saat dibuat** (`session` + `session_item` ditulis di awal). Berhenti di tengah → lanjut sesi yang sama, bukan dirakit ulang.
- **Kehabisan lesson → sesi review penuh** (8–10 soal dari riwayat, prioritas yang pernah salah). Streak tetap bisa dijaga; pesan layar jujur menyatakan mode review.

### 5.2 Alur menjawab

Salah → tampilkan `explanation` → soal kembali di **akhir sesi**. Sesi selesai saat semua terjawab benar. Percobaan pertama dicatat `percobaan_pertama = true`; percobaan ulang `false`.

### 5.3 Review (SM-2 minimal)

- Jawaban salah (kapan pun) → masuk `review_queue`, jatuh tempo besok, `benar_beruntun = 0`.
- Benar saat review → interval ganda: 1 → 3 → 7 hari; `benar_beruntun` +1.
- `benar_beruntun` = 3 → keluar antrean. Salah lagi → kembali ke awal.

Bahan baku (`attempt`) lengkap, sehingga upgrade ke FSRS di masa depan tidak menyentuh skema.

---

## 6. Gamification & Grading

### 6.1 XP (semua angka di tabel `config`, bisa di-tuning tanpa deploy)

| Kejadian | XP |
|---|---|
| Benar, percobaan pertama | +10 |
| Benar, percobaan ulang | +2 |
| Sesi selesai | +20 |
| Sesi semua-benar-langsung | +15 |
| Batas harian dari review tambahan | 100 |

Dua sifat yang wajib dipertahankan apa pun angkanya: percobaan ulang hampir tak bernilai (menebak bukan strategi), dan ada langit-langit harian (konsistensi mengalahkan maraton).

### 6.2 Target harian & streak

- Target = N sesi selesai (default 1), ditampilkan "1 sesi · ±X menit" (estimasi dari jumlah soal).
- Streak bertambah saat target tercapai. Zona waktu WIB; putus hanya jika kemarin **dan** hari ini kosong lewat tengah malam.
- **1 token streak-freeze per minggu**, otomatis terpakai saat absen sehari.
- **Tanpa leaderboard** di Rilis 1 (sesuai deck, dan level dipilih-sendiri membuat perbandingan antar-orang tidak valid).

### 6.3 Metrik per lapisan

| Lapisan | Metrik | Catatan |
|---|---|---|
| User — harian | XP, streak, sesi selesai | engagement murni |
| User — progress | % lesson selesai per topic; akurasi percobaan-pertama per skill (4 skill, tanpa Speaking) | perbandingan dengan diri sendiri |
| Manajemen | hari aktif, sesi/minggu, lesson selesai, tren akurasi 4-minggu per orang (panah membaik/stabil/menurun), daftar tidak-aktif ≥5 hari, unduh CSV | **tanpa rata-rata skor antar-orang, tanpa ranking** |

**Prinsip grading Rilis 1:** tanpa placement test, skor lintas-user/lintas-level tidak dapat dibandingkan secara jujur. Yang dilaporkan adalah aktivitas dan tren tiap orang terhadap dirinya sendiri. Skor mentah tetap tercatat penuh di `attempt` sebagai fondasi Rilis 2.

---

## 7. Arsitektur

```
next-app (satu proyek Next.js)
  /          → app user
  /admin     → dashboard admin (guard role)
        │  HTTP/JSON (kontrak DTO TypeScript dibagi)
        ▼
api — BE standalone (NestJS + Prisma)
  modul: auth · content · session · progress · admin
  (JWT · perakitan sesi & grading · importer · media · agregasi dashboard)
        │
        ▼
Postgres  +  object storage (media: R2/Supabase)
```

- **Semua logika di BE** (grading, XP, perakitan sesi, importer); Next.js murni lapisan tampilan. Aturan grading hanya hidup di satu tempat.
- **Tanpa background job.** Sesi dirakit on-demand; streak dihitung dari riwayat saat dimuat. Tidak ada proses yang bisa gagal diam-diam.
- **Akun dibuat admin** (import CSV + link undangan). Tanpa registrasi publik.
- **Backup Postgres harian otomatis sejak minggu 1** — isi database adalah kerja manual tim klien.
- **Biaya sadar:** BE terpisah menambah ±2–3 hari (CORS, dua deploy, kontrak API), dibayar dari jatah revisi minggu 7. Imbalannya: BE siap dipakai ulang untuk klien mobile di rilis lanjutan.
- Infra ±Rp 2,3 juta/tahun (slide 9): VPS kecil / tier hobi + Postgres + object storage + domain. Muat.

**Penanganan error yang dikunci sejak desain:** importer tidak pernah gagal diam-diam (laporan per-baris); media yang hilang terdeteksi saat import, bukan saat user membuka soal; sesi yang setengah jalan selalu bisa dilanjutkan; jawaban user tersimpan per-soal (bukan per-sesi) sehingga koneksi putus kehilangan maksimal satu jawaban.

**Testing:** unit test wajib untuk logika penilaian 3 tipe soal (termasuk normalisasi isian), perakitan sesi, aturan review-interval, XP, dan streak/freeze — inilah bagian yang salah-diam-diam paling mahal. UI diuji lewat alur manual terskrip di minggu 8. TDD untuk modul-modul logika tersebut.

---

## 8. Pemetaan Jadwal 8 Minggu

| Minggu | Slide 5 | Isi konkret |
|---|---|---|
| 1 | Fondasi & akses | Skema DB lengkap, auth, setup deploy + backup, **template dikirim ke klien** |
| 2 | Aplikasi admin | Importer + laporan error, CRUD soal, upload media, import CSV karyawan. **Uji 10 soal asli dari klien** |
| 3 | Kerangka app user | Login/undangan, home, pilih level & target, kerangka sesi |
| 4 | Alur sesi | 3 tipe soal + lapisan media, sesi beku, salah-kembali-di-akhir |
| 5 | Penilaian & masukan | Grading isian/susun-kalimat, layar explanation, `attempt`, tombol lapor soal |
| 6 | Progress, XP, streak | XP + config, streak + freeze, review queue, halaman progress. **Materi klien masuk** |
| 7 | Dashboard & revisi | Dashboard aktivitas + tren, CSV export, putaran revisi |
| 8 | Muat & luncurkan | Import konten penuh, QA terskrip, seeding user pilot, launch |

Dua pergeseran dari urutan "alami", disengaja: **importer maju ke minggu 2** (ia alat uji template, bukan sekadar alat muat) dan **review queue mundur ke minggu 6** (baru berguna setelah ada riwayat jawaban).

---

## 9. Di Luar Cakupan Spec Ini

- **UI/UX** — spec terpisah, disusun setelah spec ini disetujui. Jatah harinya sudah terhitung (minggu 3–4).
- Placement test & assessment berkala (Rilis 2 — "Pengukuran").
- Notifikasi, jalur belajar personal, leaderboard, AI tutor, speaking.
- Kalibrasi difficulty otomatis & adaptivitas (butuh data `attempt` yang justru baru mulai terkumpul di pilot).

## 10. Catatan untuk Presentasi Klien

- Deck penawaran memuat dua angka tim pilot yang berbeda: slide 6 "10–20 user", slide 10 "20–50 karyawan". Samakan sebelum dipresentasikan.
- Contoh dashboard di deck konsep ("Rata-rata Skor 82%") tidak dijanjikan di Rilis 1 — sampaikan reframing-nya sejak kesepakatan cakupan: Rilis 1 melaporkan aktivitas & tren, pengukuran skor antar-orang adalah justru isi Rilis 2. Ini konsisten dengan cara deck menjual arah ("kolom kanan adalah arah, bukan komitmen").
- Contoh progress di deck konsep menampilkan bar "Speaking" — tidak ada di Rilis 1.
