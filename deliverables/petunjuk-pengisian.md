# Petunjuk Pengisian Template Soal

Panduan ini menjelaskan cara mengisi `template-soal-v1.xlsx`. File ini akan diimpor langsung ke sistem, jadi ikuti aturan di bawah agar proses impor berjalan lancar.

## Konsep Lesson

Satu **lesson** = satu topik pembelajaran, terdiri dari **8–10 soal**.

Semua baris dengan `lesson_code` yang **sama** akan digabung menjadi satu lesson. Contoh: baris dengan `lesson_code` `BUS-01` (ada 3 baris pada template) semuanya menjadi bagian dari lesson "Email Perkenalan" yang sama. Kolom `lesson_title`, `topic`, `level`, `cefr`, dan `skill` harus **konsisten** untuk kode lesson yang sama.

Gunakan `item_order` untuk menomori urutan soal di dalam satu lesson: 1, 2, 3, dst.

## 3 Tipe Soal

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

## Aturan Media (Audio/Gambar)

Jika soal butuh audio atau gambar (misalnya soal `listening`): **upload dulu file media ke admin**, baru tulis nama file-nya **persis sama** (termasuk huruf besar/kecil dan ekstensi) pada kolom `media_file`. Contoh: `audio_001.mp3`.

Jika soal tidak butuh media, kosongkan kolom ini. Jika nama file di kolom `media_file` belum diunggah ke sistem, baris tersebut akan gagal diimpor (error "belum diunggah").

## Kolom Lain

- **level**: pilih dari dropdown — `dasar` / `menengah` / `mahir`.
- **cefr**: pilih dari dropdown — `A1`–`C2`.
- **skill**: pilih dari dropdown — `vocabulary` / `grammar` / `listening` / `reading`.
- **explanation**: WAJIB diisi untuk semua soal — muncul ke karyawan saat mereka menjawab salah.
- **passage**: teks bacaan untuk soal `reading`. Kosongkan jika tidak ada.

## Larangan

**Jangan mengubah nama atau urutan kolom (header) pada baris pertama.** Sistem membaca data berdasarkan nama kolom persis seperti pada template.

## Boleh Dikirim Bertahap

File boleh dikirim bertahap (tidak perlu langsung lengkap semua lesson). Proses impor bersifat aman untuk diulang: jika file yang sama atau file lanjutan diimpor ulang, soal yang sudah ada akan diperbarui (bukan diduplikasi), dan soal baru akan ditambahkan.
