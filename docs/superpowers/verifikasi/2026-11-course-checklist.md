# Checklist manual — Course (Nov 2026)

Butuh: api + web dari branch `feat/course`, migrasi course sudah diterapkan (termasuk pemetaan konten lama: `EFT-*` → "English for Tour Leaders", `CMP-*` → "General English at Work", `DC-*` dibuang), browser desktop + lebar 375px, satu akun admin + dua akun karyawan (satu lama yang sudah punya progres, satu baru yang belum onboarding).

## Katalog & pendaftaran
- [ ] Tab **Course** ada di navigasi (Beranda · Course · Modul · Progress · Profil); menu **Perjalanan** sudah tidak ada.
- [ ] `/courses`: seksi "Course saya" (yang sudah diambil) dan "Katalog" (sisanya); course DRAFT tidak muncul.
- [ ] Tombol **Daftar** di katalog → kartu pindah ke "Course saya", Beranda langsung punya kartunya.
- [ ] Menu ⋯ → **Keluar dari course** → dialog "Progresmu disimpan…"; setelah keluar, kartu balik ke katalog dan progres tidak hilang saat mendaftar ulang.
- [ ] Course yang sudah tuntas: kartu bercentang "Selesai", tidak ada tombol lanjut, tetap bisa dibuka lewat "Lihat perjalanan".

## Onboarding karyawan baru
- [ ] Langkah 1 = **pilih course pertama** (daftar course LIVE, bukan pilih level); tombol Lanjut mati sebelum satu dipilih.
- [ ] Langkah 2 = target harian + checkbox consent suara (tetap wajib).
- [ ] Selesai onboarding → langsung ke Beranda dengan kartu course itu; `/onboarding` tidak muncul lagi saat dibuka ulang.
- [ ] Tidak ada pilihan level di mana pun, termasuk `/profile`.

## Beranda (kartu geser)
- [ ] Dua pendaftaran → hero bisa digeser kiri/kanan, satu kartu penuh per layar, titik indikator mengikuti.
- [ ] Tombol **Mulai belajar** di kartu kedua membuka sesi course kedua (bukan course pertama).
- [ ] Kartu dengan sesi berjalan tampil lebih dulu dan tombolnya "Lanjutkan belajar"; melanjutkan membuka sesi yang sama.
- [ ] Judul langkah: pelajaran → judul lesson + "Unit N · {judul unit}"; bab modul → "Bab N · {judul bab}" dan tombolnya ke halaman bab.
- [ ] Kartu **Latihan berbicara** menyebut course kartu yang sedang tampil, dan sesinya berisi soal ucapan course itu.
- [ ] Tanpa pendaftaran: hero "Pilih course dulu" + tautan ke `/courses`.
- [ ] Semua course sudah habis: hero jadi kartu penguatan, tombolnya membuat sesi penguatan lintas course.
- [ ] Lebar 375px: tanpa scroll horizontal; geser hero tidak menggeser halaman.

## Satu sesi per hari per course, satu target harian
- [ ] Target harian 2: selesaikan sesi course A → "1/2"; sesi kedua di course A **ditolak** (sudah ada sesi hari ini untuk course itu).
- [ ] Sesi di course B pada hari yang sama **boleh** → "2/2" dan target tercapai.
- [ ] Streak dan XP naik dari dua sesi itu; tidak ada dua target terpisah.

## Perjalanan per course
- [ ] `/courses/<slug>/journey`: judul halaman = nama course, strip "X dari N langkah selesai".
- [ ] Urutan unit = urutan di admin; unit modul menampilkan bab bernomor, bab bacaan tampil tapi tidak dihitung.
- [ ] Langkah selesai bercentang (progres karyawan lama terbawa), langkah terkunci → toast, langkah selesai → dialog "Ulangi materi ini?".
- [ ] Course orang lain / slug ngawur → kartu error dengan tautan ke daftar course.

## Menu Modul (modul bebas)
- [ ] Modul yang dipanggil sebuah course **tidak** muncul di daftar `/modules`, tapi halaman babnya tetap terbuka untuk peserta course-nya (langkah bab di Perjalanan menautkan ke sana); karyawan yang tidak mendaftar course itu → 403.
- [ ] Tanpa modul bebas: keadaan kosong "Belum ada bacaan bebas" + tautan ke Course.
- [ ] Kuis bab modul bebas: boleh dikerjakan kapan saja, hasilnya **tidak** menambah sesi harian, streak, atau bonus sesi lengkap (dihitung sebagai latihan ulang).

## Admin — merakit course
- [ ] Sidebar KONTEN punya butir **Course** di atas Modul.
- [ ] `/admin/course`: daftar (kode, judul, unit, lesson, peserta, status) + **Course baru**.
- [ ] Detail: ubah judul/kode/ringkasan/cover → Simpan; DRAFT → LIVE → DRAFT → Pensiunkan sesuai aturan transisi.
- [ ] Tambah **unit topik**, lalu tambah **unit modul** — pemilih hanya menawarkan modul yang belum dipanggil course lain; modul yang baru dipakai hilang dari pemilih.
- [ ] ↑/↓ menggeser unit, nomor unit ikut berubah; ubah judul unit lewat tombol pensil.
- [ ] **Lepas unit** tanpa attempt → unit hilang, lesson-nya tetap ada di `/admin/content`; unit yang sudah dikerjakan karyawan → 409 "Unit sudah dikerjakan karyawan, tidak bisa dilepas".
- [ ] Tambahkan lesson yang sudah ada ke unit topik, lalu keluarkan lagi — soal tidak hilang.
- [ ] **Terbitkan semua isi** (course) dan **Terbitkan isi unit**: angka lesson/soal terbit muncul, soal cacat terdaftar di `rejected` dengan alasannya (mis. "Soal 1: pilihan ganda butuh 4 opsi").

## Admin — impor
- [ ] Halaman impor menautkan `template-soal-v2.xlsx` dan `contoh-course-v1.xlsx`; petunjuk menyebut tiga sheet.
- [ ] Unggah `contoh-course-v1.xlsx`: 0 error, angka **Course dibuat / Unit dibuat / Lesson dibuat / Item dibuat** terisi; course baru muncul DRAFT di `/admin/course`.
- [ ] Unggah file yang sama lagi: dibuat 0, diperbarui sesuai jumlahnya, tidak ada duplikat.
- [ ] Workbook lama tanpa sheet `Course` → error "Sheet 'Course' tidak ditemukan di berkas ini".
- [ ] Baris dengan `lesson_code` milik course lain → error baris yang menyebut nama course pemiliknya; baris lain tetap masuk.

## Dashboard manajemen
- [ ] Ringkasan: seksi **Course** (peserta, selesai, tidak aktif 7 hari) — "tidak aktif" = tanpa sesi apa pun, bukan hanya di course itu.
- [ ] Ringkasan: kartu "Kehabisan konten" memakai angka per pendaftaran ("X dari Y karyawan"), bukan per level.
- [ ] Tabel Karyawan: penyaring course menyaring daftarnya dan memunculkan kolom **Progres course**; CSV ikut membawa kolom itu.
- [ ] Klik nama course di Ringkasan → tabel Karyawan terbuka dengan penyaring course itu.
- [ ] Detail karyawan: tabel **Course yang diambil** (progres, tanggal mendaftar, tanggal selesai); karyawan tanpa pendaftaran → "Belum mendaftar course".
- [ ] Tidak ada ranking atau perbandingan skor antar orang di permukaan mana pun.

## Data lama (setelah deploy)
- [ ] Karyawan lama otomatis punya pendaftaran ke course hasil pemetaan dan langkah selesainya tetap ✓.
- [ ] `/progress`: "materi selesai" menjumlahkan langkah selesai di seluruh course yang didaftari.
- [ ] Lesson `DC-*` tidak muncul di Perjalanan mana pun, tapi riwayat & attempt-nya masih ada di admin.
