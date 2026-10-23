# Satu Perjalanan — modul & pelajaran dalam satu journey

Tanggal: 23 Okt 2026 · Status: draf, menunggu persetujuan pemilik proyek

## 1. Latar & alasan

Di Beranda ada dua ajakan "lanjut" yang saling bersaing:

- Kartu besar **"Lanjutkan sesimu"** (hero) menampilkan sesi harian dari Perjalanan, contohnya "Membaca Email Kerja, 4 dari 11 soal".
- Kartu **"Lanjutkan modul"** menampilkan modul "Making & Handling Complaints · Bab 2" dengan progres sendiri.

User tidak tahu harus klik yang mana, dan tidak tahu apakah keduanya dihitung. (Sebenarnya keduanya dihitung ke target, streak, dan XP.)

Akar masalahnya ada dua:

1. **Ada dua aturan untuk modul.**
   - Modul dengan `Module.showInPath = true` (EFTL 1–5): kuisnya sudah masuk Perjalanan.
   - Modul dengan `showInPath = false` ("Making & Handling Complaints"): berdiri sendiri, jadi muncul sebagai jalur kedua.
2. **Bacaan bab tidak ikut ke Perjalanan.** Walaupun kuis modul sudah masuk, Perjalanan hanya berisi `Lesson`. User yang mengikuti Perjalanan langsung mengerjakan kuis bab (sebagai sesi DAILY) tanpa pernah membuka materi bacaannya.

Yang diminta pemilik: **satu journey, satu progres** untuk modul dan sesi.

## 2. Tujuan

- **Perjalanan jadi satu-satunya journey belajar** untuk level user.
  - Pelajaran biasa dan bab modul ada di jalur yang sama.
  - Ada satu angka progres total.
- **Perjalanan dikelompokkan per unit** (opsi B yang dipilih pemilik):
  - Unit topik = satu topik dengan pelajaran-pelajarannya. Ini sama dengan "Bagian" sekarang.
  - Unit modul = satu modul dengan bab-babnya.
  - Setiap unit menampilkan progresnya sendiri, di samping progres total.
- **Langkah bab modul = baca materi, lalu kuis.**
  - Membuka langkah bab membawa user ke halaman bab (`/modules/{slug}/{order}`).
  - Kuis dikerjakan dari halaman itu, seperti sekarang (sesi `MODULE`).
- **Beranda punya satu ajakan lanjut.**
  - Hero selalu menunjuk satu langkah berikutnya di Perjalanan, entah pelajaran atau bab modul.
  - Konteks unit ikut tampil, misalnya "Unit 3 · Bab 2".
  - Kartu "Lanjutkan modul" dihapus.
- **Semua modul LIVE otomatis masuk Perjalanan.**
  - Flag `showInPath` dan toggle admin-nya dihapus.
  - Kendali admin cukup lewat status modul: DRAFT (belum tampil), LIVE (tampil di Perjalanan dan menu Modul), RETIRED (ditarik).

## 3. Non-goal

- **Pelacakan "sudah baca".** Bab tetap dianggap selesai bila kuisnya tuntas (aturan sekarang). UI hanya *menjelaskan* alurnya ("Baca materi, lalu kerjakan kuis") tanpa centang baca.
- **Mengatur urutan unit oleh admin.** Urutan tetap otomatis (lihat §5.3). Masuk backlog.
- **Perayaan "unit selesai" (Mitha).** Bagus untuk nanti, bukan bagian dari perubahan ini.
- **Mengubah menu Modul.** Tetap jadi perpustakaan: baca ulang, loncat ke bab mana saja. Halaman bab tetap bisa dibuka bebas seperti sekarang.
- **Mengubah aturan target, streak, XP, atau `COUNTED_SESSION_KINDS`.** Kuis bab sudah dihitung sama dengan sesi harian.

## 4. Anti-goal (gagal walau secara teknis jalan)

- Masih ada dua progres atau dua "lanjut" di Beranda untuk materi yang sama.
- Progres lama user hilang atau dihitung ganda.
  - Bab selesai = lesson tuntas, berdasarkan soal yang sama. Siapa pun yang sudah mengerjakan bab "Complaints" lewat menu Modul harus melihat unit itu sebagian selesai.
- Soal yang sama muncul dua kali di jalur.
- User yang mengikuti Perjalanan dibawa ke kuis bab tanpa melewati halaman bacaannya.

## 5. Perilaku

### 5.1 Struktur Perjalanan

- Isi Perjalanan untuk level user adalah urutan **unit**.
- **Unit topik:**
  - Berisi lesson LIVE yang tidak tertaut ke bab modul LIVE dan punya ≥1 item LIVE.
    - *Perubahan kecil, keputusan saya:* sekarang `JourneyService` tidak menyaring lesson tanpa item LIVE. Lesson seperti itu bisa jadi `now` dan memblokir user, sementara mesin sesi melewatinya. Kini Perjalanan menyaringnya juga, supaya selaras dengan mesin sesi.
  - Dikelompokkan per `Lesson.topic`, sama seperti `JourneyService` sekarang.
- **Unit modul:**
  - Satu per modul LIVE yang punya ≥1 bab kuis di level user.
    - *Keputusan saya:* yang menentukan level adalah **`Lesson.level`** milik lesson kuis, bukan `Module.level`. Alasannya, mesin sesi dan hitungan selesai sudah memfilter per `Lesson.level`.
    - Bila kedua level itu beda (misalnya `linkQuiz` tidak mengecek level), bab itu muncul di unit modul pada Perjalanan level lesson-nya.
  - Kunci pengelompokan adalah **modul**, bukan string topik. Lesson modul tidak boleh tergabung ke unit topik meskipun string `topic`-nya kebetulan sama.
  - Isinya semua bab modul, urut `ModuleChapter.order`.
    - **Bab kuis** = langkah yang dihitung.
    - **Bab bacaan saja** (tanpa lesson / tanpa item LIVE) tetap tampil di posisinya. Bab ini tidak dihitung ke progres dan tidak ikut alur kunci. Bab ini selalu bisa dibuka, dengan label "Bacaan".
- **Modul yang tidak punya bab kuis** tidak muncul di Perjalanan. Modul itu hanya ada di menu Modul.
- **Lesson yang tertaut ke modul DRAFT/RETIRED** tetap diperlakukan sebagai lesson biasa di unit topiknya. Ini aturan yang sudah ada: menyusun modul tidak boleh menarik konten dari Perjalanan.

### 5.2 Status langkah & progres

- **Urutan langkah = satu sumber.** Urutannya: unit (lihat §5.3), lalu langkah di dalam unit.
  - Urutan ini dipakai oleh `/journey`, langkah berikutnya di Beranda, **dan** mesin sesi: `nextLesson` / `POST /session/today`, pilihan "belum tuntas" di latihan berbicara, serta hitungan konten habis.
  - Tujuannya supaya tidak ada tempat yang masih berjalan menurut `Lesson.order` mentah.
  - Ini penting karena `Lesson.order` bisa tidak cocok dengan `ModuleChapter.order`. Contohnya, admin memindah bab ↑/↓ tanpa mengubah `Lesson.order`, atau `createQuiz` memberi `max+1`.
  - Akibatnya, di dalam unit modul, urutan bab **selalu** mengikuti `ModuleChapter.order`.
- **Status `done` / `now` / `locked`:**
  - Langkah dijalani menurut urutan di atas.
  - Langkah yang sudah selesai **selalu** `done`, di mana pun posisinya. Ini termasuk langkah setelah `now`, misalnya bab yang dikerjakan duluan lewat menu Modul. *(Keputusan pemilik; berubah dari aturan lama yang mengunci semua langkah setelah `now`.)*
  - Langkah pertama yang belum selesai = `now`.
  - Langkah belum selesai lainnya = `locked`.
  - Hanya langkah yang dihitung (lesson / bab kuis) yang ikut alur ini.
- **Progres total** = langkah selesai ÷ jumlah langkah yang dihitung di level itu.
  - Teks: "X dari N langkah selesai".
  - Angka ini menggantikan "X dari N materi selesai".
- **Progres unit** = langkah selesai ÷ langkah yang dihitung di unit itu.

### 5.3 Urutan unit

- Unit diurutkan menurut `Lesson.order` terkecil di dalam unit itu. Ini setara dengan "first-seen" sekarang.
- Kolom `Module.order` tidak dipakai untuk Perjalanan. Kolom itu tetap mengatur urutan di menu Modul, jadi kedua urutan bisa berbeda. Itu bisa diterima.
- Langkah di dalam unit modul diurutkan menurut `ModuleChapter.order`.
- Akibatnya, posisi unit modul ditentukan oleh `order` lesson kuisnya.
  - Lesson CMP-2xx milik "Complaints" punya `order` lama dari masa sebelum menu Modul, yang jatuh di tengah MENENGAH (sebelum EFT-3xx/5xx).
    - *Keputusan pemilik:* unit Complaints ditaruh **di akhir** Perjalanan MENENGAH.
    - Caranya, migrasi data sekali jalan menomori ulang `Lesson.order` CMP-201..211 menjadi `max(order MENENGAH) + 1…`, mengikuti urutan bab.
    - Tujuannya supaya karyawan MENENGAH yang sudah maju ke EFTL tidak ditarik mundur.
  - Lesson EFTL diberi `order` setelah konten yang sudah ada, oleh `seed-module-kit`.
- Pemilik sudah menyatakan dua unit bertema keluhan di MENENGAH ("Making & Handling Complaints" dan "Guest Complaint Handling") **tidak masalah** berdampingan.

### 5.4 Aksi dari Perjalanan

- Langkah **lesson** `now` → `POST /session/today` → `/session`, seperti sekarang.
- Langkah **bab kuis** `now` → buka `/modules/{slug}/{order}`. User membaca, lalu memulai kuis dari halaman bab (sesi `MODULE`, sudah ada).
- Langkah `done`:
  - Lesson → konfirmasi ulangi, lalu `/session?replay=…`, seperti sekarang.
  - Bab → buka halaman bab. Halaman bab sudah menangani ulangan kuis lewat REPLAY.
- Langkah `locked` → toast, seperti sekarang.
- Bab bacaan → buka halaman bab.

### 5.5 Beranda

- **Hero menunjuk langkah `now` dari Perjalanan.**
- **Langkah pelajaran:** sama seperti sekarang (judul, topik, estimasi menit/XP/soal, tombol "Mulai belajar" → `POST /session/today`).
- **Langkah bab modul:**
  - Konteks: "Unit N · {judul modul}".
  - Judul: "Bab {posisi} · {judul bab}".
  - Deskripsi singkat yang menjelaskan alurnya: baca materi, lalu kuis.
  - Meta (menit, soal, XP) dari data bab.
  - Tombol "Mulai belajar" → `/modules/{slug}/{order}`.
- **Sesi yang sedang berjalan** ("Lanjutkan sesimu", "x dari y soal") tetap diutamakan, seperti sekarang.
  - Sesi `MODULE` hari ini yang `IN_PROGRESS` kini juga dihitung sebagai sesi berjalan. Sekarang sesi ini dikecualikan di `getOpenSession`.
  - Judulnya judul bab. Tombol lanjut membawa user kembali ke kuis bab itu, dengan cara apa pun sesi MODULE dilanjutkan saat ini.
- **Kartu "Lanjutkan modul" dihapus** dari `home-content.tsx`. Field `SummaryView.moduleInProgress` ikut dihapus bila tidak dipakai di tempat lain.
- **Status lain hero tetap:** target tercapai, konten habis → penguatan, materi belum ada.

### 5.6 Admin & data

- **Migrasi:** hapus kolom `Module.showInPath`.
- **`PATH_LESSON` jadi tidak relevan.** Semua lesson LIVE kini masuk jalur.
  - Hapus `PATH_LESSON` beserta pemakaiannya (Perjalanan, sesi harian/berbicara, penguatan, materi selesai, dan 3 titik di `monitoring.service.ts`), atau sederhanakan. Pilihan bentuknya diserahkan ke builder.
  - Perilakunya wajib: semua lesson LIVE di level user ikut jalur.
- **Hapus toggle** "tampilkan di Perjalanan":
  - Di BE, toggle ini adalah field `showInPath` pada `ModuleInput` / `updateModule` (`admin-modules.service.ts`), bukan endpoint tersendiri.
  - Di web: `app/admin/modul/types.ts` dan `app/admin/modul/[id]/page.tsx`.
- **Komentar yang jadi salah diperbarui:** seed `seed-module-complaints.ts`, `seed-module-kit.ts`, `content-scope.ts`, spec modul §9, dan CLAUDE.md.

### 5.7 API

- `GET /journey` berubah bentuk. Bentuk persisnya diserahkan ke builder. Yang dibutuhkan web:
  - Daftar unit: jenis (topik/modul), judul, slug modul (untuk unit modul), progres unit.
  - Langkah per unit: jenis (lesson/bab kuis/bab bacaan), id, judul, status, akurasi bila `done`. Untuk bab juga slug modul, `order`, dan posisi bab.
  - Progres total.
- `SummaryView` membawa **langkah berikutnya** dalam bentuk yang membedakan pelajaran vs bab modul, berikut konteks unitnya. Ini menggantikan atau memperluas `nextLesson`.
  - Turunannya harus memakai logika yang sama dengan `/journey`, supaya Beranda dan Perjalanan tidak pernah menunjuk langkah berbeda.
- **Kontrak DTO:** di `apps/api`, di-copy ke `apps/web/src/lib/api-types.ts` seperti biasa.

## 6. Keputusan saya (bukan dari pemilik; silakan dikoreksi)

- Tidak melacak "sudah baca". Chip "✓ Baca materi" di mockup diganti teks penjelasan.
- Bab bacaan saja: tampil, tidak dihitung, tidak dikunci.
- Modul tanpa bab kuis tidak masuk Perjalanan.
- Urutan unit otomatis menurut `Lesson.order`. Pengaturan urutan oleh admin masuk backlog.
- Sesi `MODULE` yang sedang berjalan ikut tampil sebagai "Lanjutkan sesimu" di Beranda.
- Urutan langkah satu sumber (§5.2), dipakai juga oleh mesin sesi.
- Level unit modul ditentukan `Lesson.level`.
- Perjalanan kini menyaring lesson tanpa item LIVE.
- Angka dashboard ikut Perjalanan baru (§8).
- `POST /session/today` tetap boleh merakit sesi DAILY dari lesson bab modul bila dipanggil langsung, sebagai cadangan. Ini dihitung sama dan progresnya sama. Web tidak memanggilnya untuk langkah bab.

## 7. Diserahkan ke builder

- Bentuk persis DTO `/journey` dan `SummaryView`.
- Cara menghapus atau menyederhanakan `PATH_LESSON` tanpa mengubah perilaku di luar §5.6.
- Detail visual unit (bisa dibuka-tutup atau tidak, ikon bab vs pelajaran, label "Bacaan"), mengikuti `docs/design-system.md`.
  - Mockup acuan: opsi B di `.superpowers/brainstorm/…/satu-journey.html`.
- Struktur test. Suite api wajib tetap hijau. Tambahkan e2e untuk:
  - unit modul dan urutannya
  - bab bacaan tidak dihitung
  - langkah berikutnya di Beranda = langkah `now` di Perjalanan
  - modul DRAFT tidak menarik lesson

## 8. Kendala

- Semua logika (unit, status, progres) di BE. Next.js murni tampilan.
- Tanpa background job. `attempt` tetap append-only. Soal retired tidak dihapus.
- Dashboard manajemen tidak berubah bentuknya. Aktivitas modul sudah dihitung lewat `COUNTED_SESSION_KINDS`.
  - *Keputusan saya:* angka "materi selesai" dan "konten habis" per karyawan **ikut** Perjalanan baru, karena `monitoring.service.ts` memakai `PATH_LESSON`.
  - Akibatnya, angka itu untuk MENENGAH berubah begitu lesson Complaints masuk. Ini disengaja: dashboard harus menghitung isi yang sama dengan yang dilihat karyawan.
