# Course — desain

Status: **disetujui** (4 November 2026)
Tanggal: 4 November 2026
Menggantikan sebagian: `2026-10-23-satu-perjalanan-design.md` (Perjalanan tunggal global → Perjalanan per-course)

---

## 1. Maksud & kenapa

Hari ini samitaGo punya **satu** deret materi untuk semua orang. Isinya disaring oleh
level yang dipilih user saat onboarding, dan dikelompokkan otomatis jadi "unit"
berdasarkan kolom `Lesson.topic`. Unit bukan benda — admin tidak bisa memberinya judul
atau mengatur urutannya.

Itu tidak cukup lagi. Konten yang masuk sekarang datang **per paket**: 5 PDF EFTL untuk
pemandu wisata, modul SKKNI untuk karyawan kantor. Tiap paket punya sasaran pembaca
sendiri. Karyawan hotel tidak perlu "Explaining Tourist Attractions"; pemandu wisata
tidak perlu "Membuat Lamaran Kerja". Memaksa semuanya ke satu deret bikin tiap orang
melewati materi yang bukan untuk dia.

Course menyelesaikan itu: paket materi yang punya nama, bisa dipilih, dan punya
perjalanan sendiri. Nama unit tidak lagi ditebak dari `topic` — admin yang menuliskannya,
persis seperti judul unit kompetensi di dokumen SKKNI klien.

**Pemicu langsung:** pemilik proyek ingin menurunkan tabel unit kompetensi SKKNI
(BHS.IS01.001.01 "Memberi Salam", BHS.IS01.006.01 "Percakapan Dasar di Tempat Kerja", dst.)
jadi struktur yang kelihatan di aplikasi — judul unit SKKNI = judul unit di app, elemen
kompetensi di bawahnya = materi.

---

## 2. Tujuan

- Karyawan bisa melihat katalog course dan mendaftar sendiri.
- Satu karyawan bisa terdaftar di beberapa course sekaligus.
- Tiap course punya perjalanannya sendiri: unit → langkah → soal.
- Admin bisa membuat satu course utuh dari **satu file Excel**.
- HR bisa melihat siapa mengambil course apa dan sudah sampai mana.

## 3. Bukan tujuan (tidak dibangun sekarang)

- **Sertifikat / tanda kelulusan.** Course selesai cukup ditandai selesai di katalog.
- **Penugasan oleh HR.** Modelnya dirancang supaya muat (lihat §5.3), tapi tombolnya
  tidak dibuat. Rilis ini hanya self-enroll.
- **Bab bacaan dari Excel.** Markdown satu bab tidak muat di sel spreadsheet. Course yang
  lahir dari template berisi unit soal saja.
- **Prasyarat antar-course.** Semua course di katalog terbuka; tidak ada course yang
  mengunci course lain.
- **Katalog berbeda per perusahaan.** Rilis 1 satu penyewa; semua orang melihat katalog
  yang sama.

## 4. Anti-tujuan (tanda fitur ini gagal walau jalan)

- **Beban harian naik karena jumlah pendaftaran.** Orang yang mendaftar 3 course tidak
  boleh punya PR 3×. Satu sesi sehari, titik.
- **Dua "lanjut" di Beranda.** Dua bulan lalu "Satu Perjalanan" dibuat justru untuk
  membuang itu. Course tidak boleh mengembalikannya.
- **Progres bocor antar course.** Langkah di course B tidak boleh tiba-tiba "selesai"
  gara-gara user pernah menjawab soal serupa di course A.
- **Orang ditinggal di tengah jalan.** Course yang ditarik admin tidak boleh memutus
  orang yang sedang mengerjakannya.

---

## 5. Keputusan

### 5.1 Susunan: Course → Unit → Langkah → Soal

**Unit punya dua rasa:**

| Rasa | Isinya | Dari mana |
|---|---|---|
| Unit lesson | daftar `Lesson` | baru, dibuat admin/importer |
| Unit modul | bab-bab sebuah `Module` (bacaan + kuis) | memanggil tabel `Module` yang sudah ada |

`Module` **tetap tabel sendiri**, tidak dilebur jadi unit. Course hanya memanggilnya.
Modul yang tidak dipanggil course mana pun tetap hidup di menu Modul sebagai bacaan bebas.

### 5.2 Satu lesson milik tepat satu course

Materi **tidak dibagi** antar course. Butuh materi serupa di course lain → disalin.

Alasannya bukan kerapian, tapi aturan fondasi: akurasi selalu dari percobaan pertama, dan
`attempt` menempel ke **soal**, bukan ke course. Kalau satu soal dipakai dua course, user
yang sudah menjawabnya di course A akan melihat langkah itu **langsung selesai** di course B
— padahal belum pernah membukanya, dan nilai akurasinya pinjaman. Bahaya kedua: admin
memperbaiki typo di course A, course B ikut berubah diam-diam.

Harga yang diterima: typo diperbaiki dua kali, dan user bertemu soal mirip dua kali (untuk
belajar bahasa ini justru menguntungkan).

**Turunannya:** satu modul hanya boleh dipanggil **satu** course. Mau dipakai di course
lain → duplikat modul berikut bab dan lesson-nya. *(Keputusan penulis desain, konsisten
dengan paragraf di atas.)*

### 5.3 Pendaftaran

- Karyawan mendaftar sendiri dari katalog. Gratis, tanpa persetujuan.
- Boleh terdaftar di berapa pun course sekaligus.
- **Keluar dari course** boleh kapan saja: `Enrollment.leftAt` diisi, course hilang dari
  Beranda dan dari daftar "course saya". `attempt` tidak pernah dihapus (aturan fondasi).
  Mendaftar lagi bulan depan → `leftAt` dikosongkan di baris yang sama, progres utuh, lanjut
  dari tempat terakhir. Tidak ada riwayat keluar-masuk; satu baris per pasangan user-course.
  Sesi yang sedang berjalan untuk course itu dibiarkan menggantung, tidak dibatalkan.
  Keluar **tidak** mengeluarkan soalnya dari kolam penguatan (§5.10).
- Tabel `Enrollment` sengaja berdiri sendiri (bukan kolom di `User`) supaya penugasan oleh
  HR nanti cukup menambah kolom `assignedBy`, tanpa membongkar apa pun.

### 5.4 Satu sesi sehari untuk semua course

Target harian dan streak tetap **global**, tidak per-course. Mengerjakan 1 sesi hari ini
memenuhi target hari ini, course mana pun sumbernya. Sesi kedua dan seterusnya tetap boleh
jalan: XP dapat, target tidak bertambah — persis perilaku yang sudah ada sekarang.

Memilih course bukan menambah pekerjaan, hanya memilih arah.

### 5.5 Beranda: kartu hero yang digeser

Hero Beranda jadi kartu yang bisa digeser antar course yang didaftari. Tiap kartu
menampilkan: nama course, unit dan langkah berikutnya, tombol **Mulai belajar**, serta
strip progres course itu.

- Kartu paling depan = course yang **terakhir dikerjakan** (`Enrollment.lastOpenedAt`).
- Menekan "Mulai belajar" membuat sesi untuk course di kartu yang sedang tampil, dan
  memperbarui `lastOpenedAt`.
- Sesi yang sedang berjalan (`IN_PROGRESS`) selalu menang: kartunya dibawa ke depan dan
  tombolnya berbunyi "Lanjutkan".
- Nol pendaftaran → hero diganti ajakan membuka katalog.

**Kunci lanjut sesi harian ikut bergeser.** Hari ini `getOrCreateToday` melanjutkan sesi
berdasarkan `(userId, tanggal, kind DAILY, IN_PROGRESS)`. Jadi
`(userId, tanggal, kind, courseId)`: tiap course boleh punya **satu** sesi harian terbuka
per hari, dan tiap kartu punya tombolnya sendiri. Ini tidak melanggar §5.4 — yang dihitung
ke target dan streak adalah sesi yang **selesai**, bukan yang terbuka. `SummaryView.openSession`
berubah dari satu objek jadi per-kartu. Kunci advisory lock per-user tetap, supaya dua
permintaan bersamaan tidak membuat sesi kembar.

### 5.6 Level dilepas

`User.level` berhenti menyaring apa pun. Course yang menentukan isi, bukan level.

- Langkah pilih level di onboarding **diganti** jadi pilih course pertama.
- Filter level di mesin sesi (harian dan latihan berbicara) diganti filter course.
- Kolom `Lesson.level` / `Lesson.cefr` / `Module.level` / `Module.cefr` **tetap ada**
  sebagai label di sampul dan di admin — tidak mengunci apa pun. Karena template tidak lagi
  mengisinya (§8.1), `Lesson.level` dan `Lesson.cefr` dibuat **nullable** di migrasi; lesson
  dari Excel lahir tanpa label, admin boleh mengisinya belakangan. Semua pembaca
  (`content.service.ts`, halaman konten admin, `EmployeeListItemView.level` di monitoring)
  harus tahan nilai null. Level tidak pindah ke `Course`: course tidak punya level.
- Katalog terbuka: semua course LIVE kelihatan oleh semua orang.
- `User.level` tetap di tabel (data historis), tidak dibaca lagi oleh logika mana pun.

### 5.7 Navigasi

Sekarang: Beranda · Perjalanan · Modul · Progress · Profil
Jadi: **Beranda · Course · Modul · Progress · Profil**

Menu **Perjalanan** hilang sebagai halaman global. Isinya pindah ke dalam course: dibuka
dari kartu course di menu Course, atau dari Beranda.

Menu **Modul** tetap ada, tapi isinya **hanya modul yang berdiri sendiri** — yang tidak
dipanggil course mana pun. Modul yang sudah dipanggil course hilang dari menu Modul dan
hanya bisa dibuka lewat course-nya.

Ini menutup pintu belakang. `moduleQuiz` hari ini hanya berkunci pada `chapterId`, tanpa
cek pendaftaran: kalau modul milik course tetap terbuka di menu Modul, orang yang belum
mendaftar bisa menumpuk `attempt` pada lesson course itu, lalu begitu mendaftar langkahnya
sudah ketandai selesai — persis anti-tujuan §4, lewat pintu modul alih-alih lewat lesson
bersama. Jadi `GET /modules`, halaman detail modul, dan `moduleQuiz` sama-sama menolak
modul yang punya `CourseUnit`.

### 5.8 Kuis modul yang berdiri sendiri

Modul di luar course boleh dibaca dan dikerjakan kuisnya kapan saja, rasanya **seperti
latihan ulang**:

- Lahir sebagai `kind: REPLAY` — jenis yang sudah ada dan memang di luar
  `COUNTED_SESSION_KINDS`. Tidak ada enum baru, tidak ada filter yang perlu diaudit ulang.
- `Session.courseId` null.
- XP hanya dari tiap jawaban benar. **Tanpa** `XP_SESSION_COMPLETE` dan **tanpa**
  `XP_PERFECT_SESSION` — `answer.service.ts` sudah berperilaku begitu untuk `REPLAY`.
- Satu pelonggaran: pintu REPLAY yang ada mensyaratkan lesson-nya sudah tuntas. Untuk kuis
  modul bebas syarat itu tidak berlaku — bab boleh dikerjakan pertama kali dari sini.

Alasannya anti-tujuan §4: target harian harus punya satu sumber, kalau tidak Beranda
kembali bingung menunjuk dua "lanjut".

### 5.9 Daur hidup course

| Kejadian | Yang terjadi |
|---|---|
| Admin menambah unit ke course berjalan | Langkah selesai tetap selesai; total bertambah (20/25 → 20/32). Tidak ada yang diulang. |
| Course → RETIRED | Hilang dari katalog, tidak bisa didaftari orang baru. Yang **sudah** terdaftar tetap bisa meneruskan sampai habis. |
| Course → DRAFT | Tidak muncul di katalog. Dipakai saat menyiapkan course baru. |
| Semua langkah selesai | Course ditandai **selesai** di katalog dan di kartu Beranda. Kartunya **diam**: centang selesai, tanpa tombol Mulai. Tanpa sertifikat, tanpa layar perayaan khusus. |

**Kalau SEMUA course yang didaftari sudah selesai**, Beranda tidak boleh jadi jalan buntu —
streak orang itu akan putus tanpa salahnya. Hero berganti jadi satu kartu penguatan lintas
course (`courseId` null, jenis `DAILY` supaya tetap menghitung target dan streak), diisi
`reinforcementItems` dari riwayat jawabannya. `SummaryView.contentExhausted` berarti
"semua course yang didaftari selesai **dan** kolam penguatan kosong", bukan sekadar kartu
terdepan selesai.

### 5.10 Penguatan tetap lintas course

Soal penguatan/review berbasis riwayat `attempt` dan `ReviewQueue` per-soal, **tidak**
disaring per course dan **tidak** disaring per pendaftaran. User yang pindah course — atau
yang sudah keluar dari sebuah course — tetap bertemu soal lama yang jatuh tempo. Ini
disengaja: ilmunya tidak ditinggal.

Praktisnya: `reinforcementItems` berhenti memakai `PATH_LESSON` dan cukup menyaring
`item.status = LIVE`. Kalau tidak, menyempitkan `PATH_LESSON` ke course yang didaftari
(§7) diam-diam membatalkan janji paragraf ini.

---

## 6. Model data

```
Course
  id, code @unique, slug @unique, title, summary, coverFile?, order,
  status: ContentStatus (DRAFT|LIVE|RETIRED), createdAt, updatedAt
  units: CourseUnit[]
  enrollments: Enrollment[]

CourseUnit
  id, courseId, order, title,
  moduleId? @unique        ← terisi = unit modul; null = unit lesson
  @@unique([courseId, order])

Enrollment
  userId, courseId, enrolledAt, lastOpenedAt, leftAt?
  @@id([userId, courseId])

Lesson   (perubahan)
  + unitId?        ← null = lesson tanpa rumah, tidak muncul di jalur mana pun
  - topic          ← dihapus setelah migrasi mengisi unit
  order            ← sekarang berarti urutan di dalam unit

Session  (perubahan)
  + courseId?      ← sesi dari course mana; null untuk REPLAY & modul berdiri sendiri
```

**Tidak ada tabel progres.** Progres course tetap diturunkan dari `attempt` saat request,
sama seperti modul hari ini. `Enrollment.lastOpenedAt` bukan progres — hanya urutan kartu.

Lesson unit modul **juga** mendapat `unitId` (supaya satu query cukup); urutannya di dalam
unit tetap mengikuti `ModuleChapter.order`, bukan `Lesson.order`.

**`Lesson.unitId` adalah invarian yang dijaga, bukan nilai turunan.** Yang menjaganya:

- Admin menambah bab berkuis ke modul yang dipanggil course (`admin-modules.service.ts`
  `createQuiz`) → lesson baru mewarisi `unitId` unit modul itu, di transaksi yang sama.
- Melepas unit dari course ditolak selama ada `attempt` pada lesson di dalamnya — langkah
  tidak boleh lenyap di tengah jalan (anti-tujuan §4). Unit tanpa progres boleh dilepas;
  `unitId` lesson-nya jadi null dan lesson itu hilang dari semua jalur.
- Modul yang dipanggil course lalu diset DRAFT/RETIRED → unitnya **tetap** di dalam course.
  Course yang memiliki posisi unit, bukan status modul. Status modul hanya menentukan apakah
  modul itu muncul di menu Modul. Ini menghapus dua cabang lama: fallback "modul non-LIVE
  jadi unit topik" di `path-order.ts` dan cabang "kuis jalur di level lain" di
  `journey.service.ts`.

---

## 7. Yang berubah di mesin yang sudah ada

`apps/api/src/common/content-scope.ts` dan `path-order.ts` tetap jadi satu-satunya sumber —
hanya isinya yang bergeser.

| Berkas | Sekarang | Jadi |
|---|---|---|
| `content-scope.ts` → `PATH_LESSON` | konstanta `Prisma.LessonWhereInput` statis | **fungsi** `pathLesson(courseId)` — lesson punya ≥1 item LIVE **dan** `unitId` yang unitnya milik course itu. Lima pemanggil ikut berubah; `reinforcementItems` justru berhenti memakainya (§5.10). |
| `path-order.ts` → `groupPath` | kelompokkan per `topic` / modul | kelompokkan per `CourseUnit`, urut `CourseUnit.order` |
| `session.service.ts` → `path(userId, level)` | saring per `level` | `path(userId, courseId)` — saring per course |
| `session.service.ts` → `nextLesson` | langkah pertama yang belum selesai di seluruh jalur | sama, tapi di dalam satu course |
| `journey.service.ts` → `get(userId)` | satu perjalanan | `get(userId, courseId)` |
| sesi SPEAKING | item UCAPAN dari level user | item UCAPAN dari course yang diminta |
| `summary.service.ts` | satu `nextLesson` | daftar kartu course (§5.5) |
| `monitoring.service.ts` | agregat per level | agregat per course (§9) |

`COUNTED_SESSION_KINDS` (`DAILY, SPEAKING, MODULE`) **tidak berubah** dan tidak ada nilai
enum baru. Yang berubah hanya jenis mana yang lahir dari pintu mana: kuis modul bebas lahir
sebagai `REPLAY` (§5.8), sementara kuis bab di dalam course tetap `MODULE` dan tetap
dihitung.

---

## 8. Sisi admin

### 8.1 Template Excel satu course

Satu file, tiga sheet: **`Petunjuk`**, **`Course`**, **`Soal`**. Contoh jadi ada di
`deliverables/contoh-course-v1.xlsx` — pakai itu sebagai kontrak, jangan mengarang nama
kolom.

`Petunjuk` hanya penjelasan untuk tim klien, tidak dibaca importer.

**Sheet `Course`** — identitas, satu baris per course. Header persis:
`course_code`, `course_title`, `ringkasan`

**Sheet `Soal`** — satu baris per soal. Header persis, berurutan:
`unit_order`, `unit_title`, `lesson_code`, `lesson_title`, `skill`, `item_order`, `type`,
`prompt`, `option_a`, `option_b`, `option_c`, `option_d`, `answer`, `accepted_answers`,
`explanation`, `media_file`, `passage`, `tts_text` — plus `course_code` bila file memuat
lebih dari satu course.

| Kolom | Status |
|---|---|
| `course_code` | **baru** — hanya perlu diisi kalau satu file memuat >1 course |
| `unit_order`, `unit_title` | **baru** — menggantikan `topic` |
| `lesson_code`, `lesson_title`, `skill`, `item_order`, `type`, `prompt`, `option_a..d`, `answer`, `accepted_answers`, `explanation`, `media_file`, `passage`, `tts_text` | tidak berubah |
| `level`, `cefr` | **dihapus** (§5.6) |

`tts_text` sudah ada sejak pekerjaan Audio TTS — itulah kolom teks-jadi-audio untuk soal
listening tanpa file rekaman. Tidak perlu kolom baru.

**Satu file satu course adalah kebiasaan, bukan larangan.** Importer melaporkan hasil
per-unggahan; file 500 baris berisi 3 course membuat daftar error sulit ditindaklanjuti.
Kolomnya tersedia untuk pemilik proyek yang sedang seeding borongan.

**Sifat impor tidak berubah:** create/update berdasarkan kode, tidak pernah menghapus.
Baris yang salah ditolak satu per satu dan dilaporkan; baris yang benar tetap masuk.

`parseWorkbook` hari ini mengambil sheet pertama yang namanya bukan "petunjuk" — itu akan
salah ambil sheet `Course`. Parser harus berpindah ke pemilihan sheet **berdasarkan nama**
(`Course` dan `Soal`), dan menolak file yang kekurangan salah satunya.

### 8.2 Aturan pencocokan saat impor ulang

File yang sama diunggah lagi setelah disunting. Aturannya:

| Hal | Dicocokkan dengan | Kalau sudah ada |
|---|---|---|
| Course | `course_code` | `course_title` & `ringkasan` ditimpa; `status`, `slug`, `order`, `coverFile` tidak disentuh |
| Course baru | — | dibuat dengan `status: DRAFT`, slug dari `course_code`, `order` = terbesar + 1 |
| Unit | `unit_order` **di dalam course itu** | `unit_title` ditimpa dari sheet |
| Lesson | `lesson_code` (global, sudah begitu sekarang) | judul/skill ditimpa; `unitId` diarahkan ke unit baris itu |
| Soal | `(lesson_code, item_order)` | isinya ditimpa, status kembali `DRAFT` |

Dua akibat yang harus dijelaskan di sheet `Petunjuk`:

1. **`unit_order` adalah identitas unit, bukan sekadar urutan.** Admin yang menggeser unit
   dengan ↑/↓ di halaman admin lalu mengunggah file lama akan menamai ulang unit yang salah.
   Impor ulang harus memakai file yang mencerminkan urutan terbaru.
2. **`lesson_code` yang sudah dimiliki course lain ditolak**, dengan pesan yang menyebut
   course pemiliknya. Memindahkan materi antar course lewat impor tidak diizinkan — itu
   melanggar §5.2 dan akan menarik `attempt` lama ikut pindah.

### 8.3 Halaman admin

- **Daftar course** — kode, judul, jumlah unit, jumlah peserta, status.
- **Detail course** — ubah judul/ringkasan/sampul/status; daftar unit dengan ↑/↓;
  tambah unit lesson atau unit modul (memilih dari modul yang belum dipanggil course lain);
  di dalam unit: daftar lesson dengan ↑/↓, tambah/lepas lesson.
- **Impor** — halaman impor yang ada menerima format baru.
- **Terbitkan borongan** — tombol "terbitkan semua soal" di tingkat unit dan di tingkat
  course. Tanpa ini tujuan §2 tidak tercapai: impor menaruh semua lesson dan soal di
  `DRAFT`, dan menerbitkan 96 soal CMP satu per satu berarti ~100 klik. Tombolnya
  mengubah `status` lesson dan item di bawahnya jadi `LIVE` dalam satu transaksi, dan
  menolak soal yang tidak lengkap dengan daftar alasan.

Admin untuk **memperbaiki**; template untuk **membuat**. Menyusun 7 unit lewat form itu
siksaan; memperbaiki satu judul unit lewat seeder juga siksaan.

---

## 9. Dashboard manajemen

Masuk di rilis ini. Aturan fondasi tetap berlaku: **tanpa ranking dan tanpa perbandingan
skor antar orang.**

- **Ringkasan** — seksi baru "Course": per course LIVE → jumlah peserta, jumlah yang sudah
  selesai, jumlah peserta yang tidak aktif 7 hari terakhir. **"Tidak aktif" berarti tidak
  mengerjakan sesi apa pun** — bukan tidak aktif di course itu saja. HR peduli orangnya
  berhenti belajar, bukan orangnya pindah course. Status karyawan yang sudah ada
  (`on_track` / `butuh_perhatian` / `belum_mulai`, `computeStatus`) tetap global dan
  berbasis jumlah sesi — tidak disentuh.
- **"Materi habis"** (`exhaustedMap`, `buildExhaustedByLevel`) berhenti dihitung per level
  dan jadi per pendaftaran: seseorang "habis" kalau **semua** course yang ia daftari sudah
  selesai. `/progress` → `lessonsDone` menjumlahkan langkah selesai di seluruh course yang
  didaftari.
- **Tabel Karyawan** — penyaring per course; kolom progres di course yang sedang disaring.
- **Detail per-orang** — daftar course yang diambil, progres masing-masing (x dari y
  langkah), tanggal mendaftar, tanggal selesai.

Angka "materi selesai / konten habis" yang sudah ada ikut berubah arti: dihitung dalam
lingkup course yang didaftari user, bukan seluruh level.

---

## 10. Migrasi konten yang sudah ada

| Kelompok | Tujuan |
|---|---|
| `EFT-*` (5 modul EFTL, 344 soal) | course **English for Tour Leaders** — 5 unit modul, urut Modul 1–5 |
| `CMP-*` (Making & Handling Complaints, 96 soal) | course **General English at Work** — satu unit modul |
| `DC-*` (konten demo development) | **tidak dipindahkan.** `unitId` dibiarkan null → otomatis hilang dari semua jalur, tetap terlihat di admin. |

Unit SKKNI lain di "General English at Work" belum ada isinya; diisi belakangan lewat
template.

**Akibat yang perlu disadari:** keenam modul yang ada semuanya jadi unit course, jadi
menurut §5.7 **menu Modul kosong** setelah migrasi. Itu bukan kesalahan — menu Modul
sekarang berarti "bacaan bebas di luar course", dan memang belum ada. Dua pilihan,
keduanya sah: biarkan menu itu dengan keadaan kosong yang ramah ("belum ada bacaan bebas"),
atau sembunyikan tabnya selama tidak ada modul bebas. Diserahkan ke pembangun.

**User yang sudah ada:** `User.level` berhenti dibaca; mereka berakhir dengan nol
pendaftaran. Saat membuka Beranda mereka diarahkan sekali ke katalog untuk memilih course.
Progres lama utuh — `attempt` menempel ke soal, jadi langkah yang pernah dikerjakan
langsung tampil selesai begitu course-nya didaftari.

---

## 11. Batasan yang mengikat

Dari `docs/superpowers/specs/2026-08-25-english-app-foundation-design.md`, tetap berlaku:

- `attempt` mencatat setiap jawaban, selamanya; akurasi selalu dari percobaan pertama.
- Soal `retired` tidak pernah dihapus. Course RETIRED mengikuti semangat yang sama (§5.9).
- Dashboard manajemen: aktivitas dan tren per-orang; tanpa ranking/rata-rata skor antar orang.
- Semua logika di BE; Next.js murni tampilan.
- Angka XP/limit di tabel `config`, bukan hardcode.
- Tanpa background job/cron.

---

## 12. Yang diserahkan ke pembangun

- Bentuk `GET /courses`, `GET /courses/:slug`, `POST /courses/:id/enroll`, dan sejenisnya.
- Cara kartu hero digeser di web (carousel, scroll-snap, atau lainnya) — yang penting
  satu kartu penuh per layar dan posisi kartu terbawa saat halaman dimuat ulang.
- Apakah `path()` menerima `courseId` atau `Enrollment`.
- Strategi migrasi Prisma: satu migrasi besar atau beberapa bertahap.
- Bentuk layar katalog dan kartu course (ikut `docs/design-system.md`).
- Apakah `Lesson.topic` dihapus di migrasi yang sama atau menyusul.
