# Audio TTS Natural — Spec Desain

**Tanggal:** 16 Oktober 2026 · **Status:** menunggu persetujuan pemilik
**Fondasi:** `2026-08-25-english-app-foundation-design.md` — spec ini TIDAK mengubah keputusan di sana (logika di BE, angka di `config`, tanpa cron/background job).
**Terkait:** `2026-10-14-menu-modul-design.md` (blok `phrases`/`dialog`), Speaking Drill (tombol "Dengarkan contoh").
**Asal keputusan:** percakapan 16 Okt — pemilik proyek memilih "langsung tulis spec" tanpa sesi tanya-jawab; keputusan di bawah yang tidak diucapkan pemilik ditandai *(keputusan penulis)*.

---

## 1. Tujuan

Semua audio bahasa Inggris di app saat ini terdengar robotik:

| Sumber | Dipakai di | Mesin sekarang |
|---|---|---|
| Audio listening hasil seeder | soal skill LISTENING (CMP-210, EFT-109, demo) | macOS `say -v Samantha` (`prisma/seed-audio.ts`) |
| "Dengarkan contoh" | soal UCAPAN (`answer-speak.tsx`) | Web Speech API browser |
| 🔊 per frasa/baris dialog | bab modul (`chapter-blocks.tsx` `SpeakButton`) | Web Speech API browser |

Suara browser tergantung perangkat user (Android/Windows lama paling buruk); suara `say` hanya bisa dibuat di Mac. **Sukses** = setiap soal/bab — dari seeder, importer spreadsheet, maupun editor admin, sekarang dan ke depan — otomatis punya audio neural yang natural dan **sama di semua perangkat**, tanpa langkah manual per soal, dan gratis.

**Prinsip:** audio adalah *aset konten* yang dibuat sekali di server, disimpan sebagai file, dan diputar apa adanya — bukan suara yang disintesis di perangkat user.

## 2. Keputusan terkunci

| # | Keputusan | Pilihan |
|---|---|---|
| 1 | Mesin TTS | **Kokoro-82M** (model Apache-2.0, gratis; catatan lisensi phonemizer di §3) via npm `kokoro-js`, `dtype: 'q8'`, CPU, **di dalam proses API** — tanpa layanan baru, tanpa API key |
| 2 | Bisa diganti | Mesin di balik token DI `TTS_ENGINE` (pola `ELEVENLABS_CLIENT` / `STT_TRANSCRIBER`) — ganti ke Google/ElevenLabs = provider baru, tanpa ubah pemanggil; test memakai engine palsu |
| 3 | Alamat file | **Content-addressed**: id = hash(versi mesin + suara + teks). Teks berubah → id berubah → audio baru otomatis; tidak ada audio basi |
| 4 | Kapan dibuat | **Saat pertama diputar** (lazy) + skrip pemanasan `tts:backfill` yang dijalankan manual. Tanpa cron/queue (aturan fondasi) |
| 5 | Keamanan | Endpoint audio hanya bisa menyintesis id yang **sudah terdaftar** oleh BE dari konten — tidak pernah teks bebas dari klien |
| 6 | Cadangan | Kalau file gagal dimuat → suara browser (perilaku sekarang), dengan pemilihan suara terbaik yang tersedia |
| 7 | File rekaman manusia | Tetap menang: `Item.mediaFile` yang diunggah admin tidak pernah ditimpa/diganti TTS |

## 3. Bukti kelayakan (spike 16 Okt, Mac Apple Silicon)

- `kokoro-js@1.2.1` → `@huggingface/transformers@^3.5.1` → `onnxruntime-node` (binary prebuilt **glibc saja**; tidak jalan di Alpine/musl) + `phonemizer` (espeak-ng WASM, pure JS).
- **Lisensi:** model Kokoro & `kokoro-js` Apache-2.0, tetapi `phonemizer@1.2.1` (berlabel Apache-2.0) membundel **eSpeak NG yang GPL-3.0** dalam bentuk WASM. Untuk layanan yang hanya di-host (bukan didistribusikan) umumnya tidak memicu kewajiban GPL; bila kode/image diserahkan ke pihak lain, kewajiban GPL bisa berlaku. **Keputusan pemilik (16 Okt):** aplikasi hanya di-host pemilik; kode/image tidak diserahkan ke klien → Kokoro aman dipakai. Bila suatu saat kode/image akan diserahkan, tinjau ulang lisensi sebelumnya.
- Unduh model pertama kali ±80 dtk; muat ulang dari cache 0,26 dtk.
- Sintesis: kalimat pendek ("How was your flight here?") 0,8 dtk; kalimat 9,6 dtk audio → 3,9 dtk. Server VPS diperkirakan 2–4× lebih lambat.
- **RAM (RSS proses Node, diukur):** kosong 33 MB → library dimuat 79 MB → model termuat 334 MB → puncak saat sintesis 516 MB → stabil ±500 MB setelah 7 klip (tidak bocor). Artinya proses api bertambah **±450 MB selama model termuat**.
- `node_modules` spike ±500 MB (termasuk cache model & binary onnxruntime semua platform).
- Kualitas: sampel `af_heart` / `am_michael` / `bf_emma` vs `say Samantha` dikirim ke pemilik untuk didengar.

## 4. Model data

### Tabel baru

```prisma
model TtsClip {
  id          String    @id            // 32 hex pertama sha256(ENGINE_ID + JSON(segments))
  segments    Json                     // [{ voice: string, text: string }] — teks SUDAH dinormalisasi (§6)
  fileName    String?                  // null = belum digenerate; "tts-{id}.mp3"
  durationMs  Int?
  createdAt   DateTime  @default(now())
  generatedAt DateTime?
}
```

- Satu kalimat = 1 segmen. Dialog = beberapa segmen, digabung dengan jeda senyap ±350 ms.
- `ENGINE_ID` = konstanta, mis. `kokoro-82m-v1.0-q8`. Naik versi model/dtype → semua id berubah → audio dibuat ulang secara lazy. File lama dibiarkan (pembersihan = non-goal).
- Baris didaftarkan dengan `createMany({ skipDuplicates: true })` — murah, idempoten.

### Kolom baru

```prisma
model Item {
  // ...
  ttsText String?   // teks yang dibacakan mesin untuk soal ini (lihat §5)
}
```

### Config (tabel `config`, int)

| Key | Default | Arti |
|---|---|---|
| `TTS_ENABLED` | 1 | 0 = **berhenti menyintesis klip baru**: URL hanya dikirim untuk klip yang filenya sudah ada; yang belum → `null` (web pakai suara browser untuk frasa/contoh UCAPAN). Klip yang sudah jadi tetap dilayani, `mediaFile` unggahan tidak terpengaruh. Saklar darurat bila CPU server bermasalah *(keputusan penulis)* |
| `TTS_MAX_PARALLEL` | 1 | Batas sintesis bersamaan di proses API (semaphore) |
| `TTS_IDLE_UNLOAD_MINUTES` | 10 | Model dilepas dari memori setelah N menit tanpa sintesis (keputusan pemilik: 10 menit) |

Suara tidak di `config` (config hanya int) — konstanta kode *(keputusan penulis)*: narator `af_heart` (perempuan, US); dialog sisi kiri `af_heart`, sisi kanan `am_michael`. Ganti suara = ubah konstanta → id berubah → dibuat ulang otomatis.

## 5. Teks apa yang dapat audio

| Konten | Teks yang dibacakan | Dikirim ke web sebagai |
|---|---|---|
| Soal UCAPAN | `ttsText` bila diisi, selain itu `answerKey` | `SessionItemView.targetAudioUrl` (baru) |
| Soal dengan `ttsText` & tanpa `mediaFile` (umumnya skill LISTENING) | `ttsText` | `mediaUrl` (field lama) → `/tts/{id}.mp3` |
| Soal dengan `mediaFile` | — (file unggahan dipakai, `ttsText` diabaikan untuk `mediaUrl`) | `mediaUrl` seperti sekarang |
| Bab modul: tiap item `phrases` | `en` | `audioUrl` per item (ditambahkan saat resolve blok, seperti URL gambar) |
| Bab modul: tiap baris `dialog` | `text`, suara menurut `side` | `audioUrl` per baris |

**Format dialog di `ttsText`:** bila *semua* baris tak-kosong berbentuk `Nama: kalimat`, teks dibaca sebagai dialog — pembicara pertama suara kiri, kedua suara kanan, maks 2 pembicara (aturan sama dengan `:::dialog`). Selain itu dibaca sebagai narasi satu suara. Ini membuat soal listening percakapan terdengar seperti dua orang.

**Validasi `ttsText`** (importer + PATCH admin, lewat `row-validator`): opsional; maks 600 karakter *(keputusan penulis)*; format dialog dengan >2 pembicara → error baris.

Yang **tidak** dibacakan: prompt soal, opsi, penjelasan, paragraf bab (lihat Non-goal).

## 6. Normalisasi teks

Fungsi murni `speakableText(s)` di BE (unit-test), dijalankan sebelum hashing — sehingga perbedaan kosmetik tidak membuat file baru:

- trim, rapikan spasi;
- ` / ` (alternatif, mis. "Hey! / Hi there!") → `, ` (jeda, bukan dibaca "slash");
- buang penanda Markdown inline (`**`, `*`, `` ` ``);
- `…` → `...`.

Daftar aturan boleh ditambah builder bila sampel konten nyata memerlukannya; setiap aturan baru wajib punya unit test. Pengecualian pelafalan per kata (lexicon) = non-goal.

## 7. Alur & endpoint

### Pendaftaran (saat membangun tampilan)

`TtsService.urlsFor(specs[])` → hitung id per spec → `createMany skipDuplicates` → kembalikan `/tts/{id}.mp3` per spec (atau `null` bila `TTS_ENABLED=0`). Dipanggil di:

1. `session.service` saat membangun item view (UCAPAN + item ber-`ttsText`) — termasuk sesi SPEAKING/MODULE/REPLAY;
2. `modules.service` saat menyajikan bab ke user;
3. `admin-modules.service` saat menyajikan detail bab yang **tersimpan**;
4. halaman editor soal admin (item tersimpan);
5. skrip `tts:backfill`.

**Pratinjau Markdown admin (`POST admin/modules/preview`) TIDAK mendaftarkan** — dipanggil tiap 500 ms saat mengetik, akan menumpuk baris sampah. Di pratinjau, tombol 🔊 untuk teks yang belum tersimpan memakai suara browser; setelah simpan, audio TTS tersedia. *(keputusan penulis)*

Membangun tampilan **tidak pernah menyintesis** — respons sesi/bab tidak boleh menunggu Kokoro.

### `GET /tts/:id.mp3` (publik, tanpa JWT)

Publik karena `<audio src>` tidak bisa mengirim header Bearer — sama dengan `GET /media/:name` sekarang. Perilaku:

1. id tidak terdaftar → **404**;
2. file sudah ada → layani seperti `media.controller` (local: `sendFile`; s3/minio: 302 ke `getUrl`);
3. belum ada → sintesis (dedupe per id: dua request bersamaan menunggu promise yang sama; dibatasi semaphore `TTS_MAX_PARALLEL`) → encode MP3 → `storage.put` → isi `fileName/durationMs/generatedAt` → layani;
4. sintesis gagal, atau melewati batas tunggu 30 dtk *(keputusan penulis)* → **503** (web jatuh ke suara browser; untuk soal listening, `AudioPlayer` menampilkan tombol coba lagi), error dicatat di log. Sintesis yang melewati batas tunggu tetap diselesaikan di belakang supaya request berikutnya mendapat file.

Header: `Cache-Control: public, max-age=31536000, immutable` (file content-addressed tidak pernah berubah).

**Siklus hidup model** (keputusan pemilik): dimuat **lazy** pada sintesis pertama (boot API tidak melambat), lalu **dilepas dari memori setelah `TTS_IDLE_UNLOAD_MINUTES` (10) menit tanpa sintesis** — setiap sintesis mereset penghitung. Karena audio content-addressed dan hampir semua pemutaran hanya mengambil file, model sebagian besar waktu tidak termuat; RAM ±450 MB hanya terpakai sebentar saat backfill atau saat klip baru pertama kali diputar. Pelepasan memanggil `dispose()` pada sesi ONNX (bukan sekadar membuang referensi) dan tidak boleh terjadi selagi ada sintesis berjalan; memuat ulang dari cache lokal ±0,3 dtk. Unit/e2e: engine palsu memverifikasi muat → lepas setelah idle → muat ulang saat request berikutnya.

### Format file

MP3 mono, sample rate asli Kokoro (24 kHz), ±48–64 kbps — ±8 KB/detik (satu modul ±100 klip ≈ 3 MB). Encode dengan encoder **pure-JS** (mis. keluarga `lamejs`, LGPL-3.0, dipakai sebagai library tanpa modifikasi) — tanpa ffmpeg. MinIO sudah memetakan `.mp3`; driver S3 perlu diberi `ContentType` untuk `.mp3`. `media-block.tsx` sudah mengenali `.mp3`.

Catatan storage: semua driver meratakan key ke basename, jadi nama file harus unik datar → `tts-{id}.mp3`.

## 8. Web

- Helper baru `playAudio(url, fallbackText)` di `src/lib/` — satu `HTMLAudioElement` global (memutar yang baru menghentikan yang lama); `error`/`stalled` → `speakEn(fallbackText)`.
- **"Dengarkan contoh" (UCAPAN):** pakai `item.targetAudioUrl` bila ada, selain itu `speakEn` seperti sekarang.
- **🔊 bab modul:** `SpeakButton` pakai `audioUrl` bila ada; tombol tetap tampil walau `canSpeak()` false asalkan `audioUrl` ada.
- **Soal listening:** tidak berubah — `mediaUrl` sudah diputar `AudioPlayer`.
- **Blok `audio` di bab:** `<audio src>` sekarang tidak diberi prefix `NEXT_PUBLIC_API_URL` (URL relatif lokal salah origin) — perbaiki sekalian dengan `resolveUrl` yang sama dengan `media-block`.
- **Cadangan `speakEn`:** pilih suara terbaik yang tersedia (prioritas nama berisi `Natural`, `Premium`, `Enhanced`, `Google`, lalu `Samantha`; bahasa `en-US`/`en-GB`), fallback ke default.
- Kecepatan: audio dibuat pada kecepatan normal. "Dengarkan contoh" boleh diputar dengan `playbackRate` sedikit lebih lambat (sekarang 0.85) — nilai tepatnya keputusan builder.

## 9. Admin

- **Editor soal** (`admin/content/[lessonId]`): textarea "Teks audio (TTS)" untuk `ttsText` + keterangan format dialog; pemutar audio untuk item tersimpan (`mediaFile` bila ada, selain itu klip TTS).
- **Editor bab:** tidak ada UI baru; pratinjau detail bab tersimpan otomatis memakai audio TTS.
- **Importer & template:** kolom baru `tts_text` di `template-soal` (+ petunjuk) dan `row-validator`. Reimport: bila **kolomnya tidak ada** di sheet (template v1 lama) → `ttsText` dibiarkan; bila kolom ada tapi sel kosong → `ttsText` dikosongkan. *(keputusan penulis)*
- **Prasyarat — bug yang sudah ada:** edit soal UCAPAN/SPEAKING lewat `PATCH admin/items/:id` gagal sekarang, karena `TYPE_TO_TEMPLATE`/`SKILL_TO_TEMPLATE` di `content.service.ts` tidak punya `UCAPAN`→`ucapan` dan `SPEAKING`→`speaking` (sel `type` kosong → ditolak validator). Perbaiki dulu (dengan e2e) sebelum menambah `ttsText` ke editor.
- **Konten baru di produksi:** tim konten tidak punya akses shell untuk `tts:backfill`. Klip konten baru dibuat saat pertama diputar — termasuk saat admin mendengarkan pratinjau bab/soal tersimpan sebelum LIVE, yang sekaligus "memanaskan" cache. Tidak ada tombol "siapkan audio" di Rilis ini. *(keputusan penulis)*

## 10. Seeder & data lama

- `seed-module-kit.ts`, `seed-complaints.ts`, `seed-demo.ts`: field `tts` pada definisi soal disimpan ke `Item.ttsText` (bukan lagi `makeAudio` → `mediaFile`). `seed-audio.ts` (macOS `say`) pensiun.
- **Adopsi data lama** — skrip sekali jalan `tts:adopt-seed-audio`: untuk soal ber-`mediaFile` yang dibuat seeder (nama `{kode}-{nn}.m4a` **atau** `.wav` senyap dari mesin non-Mac, dari `seed-module-kit` [EFT-109 via `seed-eftl-1.ts`], `seed-complaints`, dan pola nama `seed-demo`) **dan** `ttsText` null → isi `ttsText` dari definisi seeder, **sintesis klipnya saat itu juga**, dan baru setelah file berhasil tersimpan kosongkan `mediaFile`. Soal yang sintesisnya gagal dibiarkan memakai file lama (dilaporkan). Dengan begitu soal yang dulu punya audio tidak pernah bisu. Butuh seeder mengekspor definisinya (jalankan `main()` hanya bila dipanggil langsung). File unggahan admin (nama lain) tidak disentuh. Idempoten.
- Rerun seeder: kit & complaints tetap create-only; `seed-demo` tetap upsert seperti sekarang (mengisi `ttsText`, bukan `mediaFile`).

## 11. Skrip `tts:backfill`

Enumerasi semua soal LIVE+DRAFT yang punya teks TTS (§5) dan semua bab dari modul non-RETIRED → daftarkan → sintesis yang belum punya file, berurutan → cetak ringkasan (`N terdaftar, M dibuat, K gagal`). Idempoten; dijalankan manual setelah seed/import/deploy. Harus bisa dijalankan **di container produksi** (dari `dist/`, bukan `ts-node`) — `docker compose exec api …`, dicatat di runbook.

## 12. Deploy

- **Image api pindah dari `node:22-alpine` ke `node:22-bookworm-slim`** — `onnxruntime-node` tidak menyediakan binary musl. Semua stage disesuaikan (`apt` untuk build bcrypt & openssl Prisma). *(keputusan penulis — alternatif WASM backend lebih lambat dan belum terbukti di Node)*
- **Model dipanggang ke image saat build** (unduh ke direktori cache transformers.js yang ditetapkan lewat env) — runtime tidak perlu internet dan tidak ada jeda 80 dtk di request pertama.
- Image bertambah ±300–500 MB. RAM: VPS produksi **≥ 4 GB** (konfirmasi pemilik 16 Okt) — cukup untuk Postgres + Next + api + ±450 MB model saat termuat. Builder memverifikasi RSS di container Linux (termasuk bahwa RSS benar-benar turun setelah pelepasan idle) dan mencatatnya di runbook.
- Docker belum pernah di-build di mesin ini (catatan CLAUDE.md) → `docker build` + uji `GET /tts` di container = **verifikasi wajib** sebelum deploy.

## 13. Pengujian

- **Unit:** `speakableText`, hitung id (stabil, berubah bila suara/versi/teks berubah), parse dialog `ttsText` (≤2 pembicara), validasi `ttsText` di `row-validator`, penggabungan segmen + jeda.
- **e2e** (engine palsu lewat override `TTS_ENGINE` — tidak memuat model di test): `GET /tts` id tak dikenal 404; id terdaftar → file dibuat sekali (dua request paralel → satu sintesis) lalu dilayani dengan header cache; `TTS_ENABLED=0` → URL null; session view UCAPAN berisi `targetAudioUrl`; item `ttsText` tanpa `mediaFile` → `mediaUrl` `/tts/…`; item dengan `mediaFile` → tidak berubah; bab user berisi `audioUrl` per frasa/baris; pratinjau admin tidak menambah baris `TtsClip`; importer menerima/menolak `tts_text`.
- **Manual (pemilik proyek):** dengar sampel tiap jenis (frasa, dialog dua suara, listening, contoh UCAPAN) di HP Android + iPhone; matikan jaringan audio (blokir `/tts`) → cadangan suara browser berbunyi.

## 14. Non-goal

- Membacakan prompt, opsi, penjelasan, atau paragraf bab.
- Pilihan suara/aksen per soal, per modul, atau per user.
- Lexicon/kamus pelafalan per kata, SSML.
- Pembersihan file TTS yatim (versi lama).
- Tombol "buat ulang" di admin (output deterministik — tidak berguna); ganti teks atau versi mesin bila perlu suara baru.
- Streaming audio sebagian.
- TTS untuk talking agent (sudah ElevenLabs).

## 15. Anti-goal (gagal walau "jalan")

- Respons sesi atau bab menunggu sintesis.
- Endpoint mana pun yang menyintesis teks bebas dari klien.
- Audio rekaman yang diunggah admin tergantikan TTS.
- Soal yang dulu punya audio jadi bisu (adopsi data lama wajib lengkap; uji CMP-210 & EFT-109).
- Test e2e memuat model sungguhan (lambat, butuh unduhan).

## 16. Diserahkan ke builder

Struktur modul Nest (`tts/`), nama method, pustaka encoder MP3 pure-JS yang tepat, cara menyimpan durasi, jeda antar-segmen yang terdengar wajar, `playbackRate` contoh UCAPAN, lokasi cache model di image, dan urutan pengerjaan.

## 17. Keputusan pemilik di luar sesi tanya-jawab (16 Okt)

1. VPS produksi ≥ 4 GB → Kokoro tetap di proses api, model dilepas setelah 10 menit idle (§7, §12).
2. Aplikasi hanya di-host pemilik, tidak diserahkan ke klien → lisensi GPL eSpeak NG bukan penghalang (§3).
3. Apakah produksi sudah dipakai learner belum dijawab → builder **menganggap sudah live** *(keputusan penulis)*: pindah image Alpine→Debian, migrasi, adopsi audio lama, dan backfill diurutkan supaya tidak ada jeda layanan atau soal bisu, dengan langkah balik (rollback) yang tertulis di runbook.
