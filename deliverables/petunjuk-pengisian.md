# Petunjuk Pengisian Template Soal

Panduan ini menjelaskan cara mengisi `template-soal-v2.xlsx`. Contoh satu course yang sudah terisi ada di `contoh-course-v1.xlsx` — pakai itu sebagai contoh jadi. File ini akan diimpor langsung ke sistem, jadi ikuti aturan di bawah agar proses impor berjalan lancar.

## Tiga Sheet

| Sheet | Isi |
|---|---|
| `Petunjuk` | Catatan untuk tim konten. Tidak dibaca sistem. |
| `Course` | Identitas course — satu baris per course: `course_code`, `course_title`, `ringkasan`. |
| `Soal` | Satu baris per soal. |

Satu file sebaiknya memuat **satu course**. Kalau satu file memuat lebih dari satu course, kolom `course_code` di sheet `Soal` **wajib** diisi di setiap baris; kalau hanya satu course, kolom itu boleh dikosongkan (semua baris otomatis milik course itu).

## Course → Unit → Lesson → Soal

- **Course** = paket belajar yang didaftari karyawan (mis. "English for Tour Leaders").
- **Unit** = unit kompetensi di dalam course. Urutannya dari `unit_order` (1, 2, 3, …), namanya dari `unit_title`. Satu `unit_order` hanya boleh punya **satu** nama di dalam satu course.
- **Lesson** = satu kelompok **8–10 soal** di dalam unit. Semua baris dengan `lesson_code` yang **sama** digabung menjadi satu lesson; kolom `lesson_title`, `skill`, `unit_order`, dan `unit_title`-nya harus **konsisten**.
- **Soal** = satu baris. Nomori urutannya dengan `item_order`: 1, 2, 3, dst (unik di dalam satu lesson).

`level` dan `cefr` **tidak ada lagi**. Materi tidak lagi disaring per level; urutan belajar ditentukan oleh urutan unit di dalam course.

## 4 Tipe Soal

### 1. Pilihan Ganda (`pilihan_ganda`)
Soal dengan 4 pilihan jawaban. Kolom `option_a` s.d. `option_d` wajib diisi semua. Kolom `answer` diisi salah satu huruf: `A`, `B`, `C`, atau `D`.

Contoh:
| Kolom | Isi |
|---|---|
| prompt | What does "schedule" mean? |
| option_a–d | Jadwal / Pertemuan / Perjalanan / Tujuan |
| answer | A |
| explanation | "Schedule" berarti jadwal — daftar waktu kegiatan. |

### 2. Isian (`isian`)
Soal isi-kosong. Tulis `___` (3 garis bawah) di bagian yang harus diisi karyawan pada kolom `prompt`. Kolom `answer` diisi jawaban utama, dan `accepted_answers` diisi variasi jawaban lain yang juga dianggap benar, dipisah titik-koma (`;`).

Contoh:
| Kolom | Isi |
|---|---|
| prompt | Please ___ the report before Friday. |
| answer | submit |
| accepted_answers | submit;send;hand in |
| explanation | "Submit" = menyerahkan. Umum dipakai untuk laporan. |

### 3. Susun Kalimat (`susun_kalimat`)
Soal menyusun kata menjadi kalimat. Kolom `answer` diisi kalimat lengkap yang benar (minimal 3 kata).

Contoh:
| Kolom | Isi |
|---|---|
| prompt | Susun kalimat berikut: |
| answer | I will send the report tomorrow |
| explanation | Pola: Subject + will + verb. "Will" untuk rencana. |

### 4. Ucapan (`ucapan`)
Karyawan merekam suaranya membaca satu kalimat. Kolom `answer` diisi kalimat yang harus diucapkan (minimal 2 kata). `accepted_answers` diabaikan untuk tipe ini.

Contoh:
| Kolom | Isi |
|---|---|
| prompt | Ucapkan kalimat ini dengan jelas: |
| answer | Good morning, how can I help you? |
| explanation | Sapaan standar saat menyambut tamu. |

## Aturan Media (Audio/Gambar)

Jika soal butuh audio atau gambar (misalnya soal `listening`): **upload dulu file media ke admin**, baru tulis nama file-nya **persis sama** (termasuk huruf besar/kecil dan ekstensi) pada kolom `media_file`. Contoh: `audio_001.mp3`.

Jika soal tidak butuh media, kosongkan kolom ini. Jika nama file di kolom `media_file` belum diunggah ke sistem, baris tersebut akan gagal diimpor (error "belum diunggah").

## Audio Suara AI (`tts_text`)

Daripada merekam dan mengunggah file audio, Anda bisa menulis teks yang akan **dibacakan otomatis oleh suara AI** di kolom `tts_text`. Cocok untuk soal `listening`.

- **Satu suara (narasi):** tulis saja kalimatnya. Contoh: `Our first stop is the Sultan's Palace. We will arrive in about thirty minutes.`
- **Percakapan dua orang:** tulis satu kalimat per baris dengan format `Nama: kalimat` (tekan Alt+Enter di Excel untuk baris baru). Maksimal **2 pembicara**; masing-masing mendapat suara berbeda. Contoh:
  ```
  Rina: Good afternoon! How was your flight?
  Mr. Lee: It was long, but comfortable.
  ```
- Maksimal **600 karakter**.
- Untuk soal `ucapan`, audio contoh "Dengarkan contoh" dibuat otomatis dari kolom `answer`. Isi `tts_text` hanya bila bacaannya perlu berbeda dari tulisan.
- Jika kolom `media_file` juga diisi, file audio yang diunggah yang dipakai; `tts_text` diabaikan.
- Mengimpor ulang tanpa kolom `tts_text` **tidak** menghapus teks audio yang sudah ada. Kolom `tts_text` yang dikosongkan akan menghapusnya.

## Kolom Lain

- **skill**: pilih dari dropdown — `vocabulary` / `grammar` / `listening` / `reading` / `speaking`.
- **type**: pilih dari dropdown — `pilihan_ganda` / `isian` / `susun_kalimat` / `ucapan`.
- **explanation**: WAJIB diisi untuk semua soal — muncul ke karyawan saat mereka menjawab salah.
- **passage**: teks bacaan untuk soal `reading`. Kosongkan jika tidak ada.

## Larangan

**Jangan mengubah nama atau urutan kolom (header) pada baris pertama, dan jangan mengganti nama sheet `Course` / `Soal`.** Sistem membaca data berdasarkan nama sheet dan nama kolom persis seperti pada template.

## Boleh Dikirim Bertahap

File boleh dikirim bertahap (tidak perlu langsung lengkap semua lesson). Proses impor bersifat aman untuk diulang: course dicocokkan dengan `course_code`, unit dengan `unit_order` di dalam course itu, lesson dengan `lesson_code`, dan soal dengan pasangan `lesson_code` + `item_order`. Yang sudah ada **diperbarui** (bukan diduplikasi), yang baru ditambahkan, dan tidak ada yang dihapus. Baris yang salah ditolak satu per satu dan dilaporkan; baris yang benar tetap masuk.

Dua hal yang perlu diperhatikan saat mengirim ulang:

1. **`unit_order` adalah identitas unit, bukan sekadar urutan tampil.** Kalau admin sudah menggeser urutan unit dari halaman admin, mengunggah file lama akan menamai ulang unit yang salah. Pakai file yang mencerminkan urutan terbaru.
2. **`lesson_code` yang sudah dimiliki course lain akan ditolak**, dengan pesan yang menyebut course pemiliknya. Materi tidak bisa dipindahkan antar course lewat impor — setiap course punya salinan soalnya sendiri, dan riwayat jawaban karyawan menempel pada soal.
