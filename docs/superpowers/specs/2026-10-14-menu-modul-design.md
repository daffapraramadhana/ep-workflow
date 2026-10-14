# Menu Modul — Spec Desain

**Tanggal:** 14 Oktober 2026 · **Status:** menunggu review
**Fondasi:** `2026-08-25-english-app-foundation-design.md` — spec ini TIDAK mengubah keputusan di sana (attempt selamanya, akurasi percobaan pertama, retired tak dihapus, logika di BE, angka di `config`, tanpa cron).
**UI/UX:** `2026-08-25-user-app-uiux-design.md` + `docs/design-system.md` — tidak ada gaya visual baru.
**Mockup acuan (disetujui 14 Okt):** `.superpowers/brainstorm/modul/modul-mockup.html` (user, 4 layar) · `.superpowers/brainstorm/modul/modul-admin-mockup.html` (admin, 3 layar). Folder `.superpowers/` di-ignore git — mockup hanya acuan lokal.
**Di luar spec ini:** importer PDF/sumber lain (spec terpisah sesudah fitur ini jalan — lihat §10).

---

## 1. Tujuan

Karyawan sekarang hanya bisa *latihan soal*. Materi bacaan (penjelasan, frasa kunci, contoh percakapan) — seperti isi modul SKKNI "Membuat dan Menangani Keluhan" — tidak punya tempat. Menu **Modul** memberi pola **"pelajari → coba"**: bab bacaan pendek, ditutup kuis singkat yang memakai mesin sesi yang sudah ada.

Sukses = karyawan bisa membuka modul, membaca bab dalam ±5 menit, mengerjakan kuisnya, dan usaha itu dihitung ke target harian/streak seperti sesi biasa; admin bisa menulis/mengubah bab tanpa developer.

## 2. Keputusan terkunci

| # | Keputusan | Pilihan |
|---|---|---|
| 1 | Bentuk modul | Bab bacaan + kuis per bab (kuis = Lesson biasa yang ditautkan) |
| 2 | Hitungan ritme harian | Kuis bab yang belum tuntas = sesi `MODULE`: masuk target harian, streak, XP + bonus selesai/perfect (pola SPEAKING) |
| 3 | Navigasi | Tab ke-3 sendiri **Modul** (`BookOpenText`) — nav jadi 5 tab |
| 4 | Visibilitas | Semua modul LIVE terlihat semua user; yang level-nya sama dengan user disorot "Cocok untukmu" |
| 5 | Jalan di dalam modul | Bebas lompat; bab berikutnya hanya disorot. Tanpa ambang lulus |
| 6 | Format konten | **Markdown sebagai sumber kebenaran**, BE mem-parse → blok bertipe (cache) — FE hanya merender blok |
| 7 | Netral-sumber | Model konten tidak mengikuti struktur PDF SKKNI; importer apa pun nanti cukup menghasilkan Markdown + soal DRAFT |
| 8 | CMP-201..211 | Dipindah ke modul "Making & Handling Complaints" sebagai kuis bab; hilang dari Perjalanan |
| 9 | Yang DITOLAK sadar | Penugasan modul ke orang/grup, bab terkunci berurutan, ambang lulus kuis, editor blok drag-and-drop, statistik per-modul di Ringkasan (semua backlog bila diminta) |

## 3. Model data

### Tabel baru

```prisma
model Module {
  id        String @id @default(cuid())
  slug      String @unique
  title     String
  summary   String          // 1 kalimat
  level     Level
  cefr      Cefr
  coverFile String?         // nama file di storage Media; null = ikon default
  order     Int
  status    ContentStatus @default(DRAFT)
  chapters  ModuleChapter[]
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

model ModuleChapter {
  id         String @id @default(cuid())
  moduleId   String
  module     Module @relation(fields: [moduleId], references: [id])
  order      Int
  title      String
  estMinutes Int
  body       String          // Markdown — sumber kebenaran
  blocks     Json            // hasil parse BE (cache), selalu sinkron dgn body
  lessonId   String? @unique // kuis bab; null = bab bacaan saja
  lesson     Lesson? @relation(fields: [lessonId], references: [id])
  sessions   Session[]
  createdAt  DateTime @default(now())
  updatedAt  DateTime @updatedAt
  @@unique([moduleId, order])
}
```

### Perubahan tabel lama

- `enum SessionKind` + `MODULE`.
- `Session.moduleChapterId String?` (+ relasi). Hanya untuk resume & mengarahkan tombol kembali — **bukan** sumber status selesai.
- `Lesson` mendapat relasi balik `moduleChapter ModuleChapter?`. Tidak ada kolom baru di `Lesson`/`Item`.

Bab tidak punya status sendiri: tampil bila modulnya LIVE. Modul/bab tidak pernah dihapus (modul di-RETIRE; bab dihapus hanya bila modul masih DRAFT dan bab belum pernah punya sesi).

## 4. Format bab (Markdown → blok)

### Sintaks

Markdown biasa (CommonMark + tabel GFM): heading `##`/`###`, paragraf, **tebal**, *miring*, `kode`, daftar, tabel, tautan http(s), gambar. Tiga blok khusus (container directive):

```md
:::phrases
- Could you tell me what happened? | Boleh ceritakan apa yang terjadi?
- May I have the order number? | Boleh saya minta nomor pesanannya? | catatan opsional
:::

:::dialog
Rina (Finance): The vendor invoice still shows the wrong amount.
Kamu (IT Support): I'm sorry about that. Which invoice is it?
:::

:::tip
"Could you…" terdengar lebih sopan daripada "Can you…".
:::
```

- `phrases`: tiap baris `EN | ID [| catatan]`. EN wajib, ID wajib.
- `dialog`: tiap baris `Nama (peran opsional): teks`. Maks 2 pembicara berbeda per blok — pembicara pertama tampil kiri, kedua kanan.
- `tip`: isi = Markdown inline/paragraf.
- Media: `![alt](media:nama-file.png)` untuk gambar; `![audio](media:nama-file.mp3)` (ekstensi audio) → blok audio. Merujuk file di storage Media yang sudah ada.

### Blok hasil parse (kontrak API)

```ts
type Inline = { t: string; b?: true; i?: true; code?: true; href?: string }[];
type Block =
  | { type: 'heading'; level: 2 | 3; text: Inline }
  | { type: 'paragraph'; text: Inline }
  | { type: 'list'; ordered: boolean; items: Inline[] }
  | { type: 'table'; head: Inline[]; rows: Inline[][] }
  | { type: 'image'; url: string; alt: string }
  | { type: 'audio'; url: string }
  | { type: 'phrases'; items: { en: string; id: string; note?: string }[] }
  | { type: 'dialog'; lines: { speaker: string; role?: string; side: 'left' | 'right'; text: string }[] }
  | { type: 'tip'; text: Inline[] };   // satu Inline per paragraf
```

### Parser (BE)

- Lib: `markdown-it` (`html: false`) + `markdown-it-container` — CommonJS, cocok dengan build api (`module: nodenext`, CJS); unified/remark ESM-only sengaja dihindari.
- Fungsi murni `parseChapter(body, mediaExists) → { blocks } | { errors: {line, message}[] }`. Dipakai oleh simpan **dan** pratinjau admin — satu jalur.
- Ditolak dengan nomor baris: container tidak ditutup, directive tak dikenal, baris `phrases` tanpa `|` / sisi kosong, baris `dialog` tanpa `:`, pembicara ke-3 dalam satu dialog, `media:` yang file-nya tidak ada, tautan non-http(s), body kosong.
- HTML mentah tidak pernah dirender (escape). Heading `#` (h1) diturunkan ke h2 — judul bab sudah dari field `title`.
- `url` media di blok = URL publik storage yang sama dengan yang dipakai `mediaFile` soal.

## 5. Aturan inti (BE)

1. **Bab selesai = lesson kuisnya tuntas** menurut definisi yang sudah ada (`lessonCompletionInternal`: semua item LIVE pernah dijawab benar), lewat sesi apa pun. Progres lama di Perjalanan otomatis terbawa. Butuh varian helper per-`lessonId` (tidak difilter level user, karena modul boleh beda level).
2. **Bab "Bacaan"** = `lessonId` null **atau** lesson-nya punya 0 item LIVE. Tidak punya status selesai; tidak dihitung di progres modul.
3. **Progres modul** = bab selesai / bab berkuis. Diturunkan saat request, tidak disimpan. Modul "sedang berjalan" = ≥1 bab selesai dan belum semua.
4. **`POST /session/module {chapterId}`**, dalam `$transaction` + `pg_advisory_xact_lock(hashtext(userId))` (pola `getOrCreateToday`):
   - sesi IN_PROGRESS untuk bab itu (kind MODULE/REPLAY, `moduleChapterId` sama) → kembalikan (resume);
   - lesson belum tuntas → sesi `kind: 'MODULE'` berisi item LIVE lesson, urut `order`, source `LESSON`, **tanpa** review yang diselipkan;
   - lesson sudah tuntas → sesi `kind: 'REPLAY'` (semantik ulangan yang ada: tanpa bonus, tak menambah target);
   - 0 item LIVE → 409 "Kuis bab ini belum tersedia"; modul tidak LIVE → 404.
5. **`COUNTED_SESSION_KINDS = ['DAILY','SPEAKING','MODULE']`** — satu konstanta menggantikan `kind IN ('DAILY','SPEAKING')` di ±10 titik (summary, streak, progress, monitoring) dan gate bonus di `answer.service`. Resume `getOrCreateToday` tetap DAILY-only.
6. **Lesson milik bab dikecualikan** (`moduleChapter: null`) dari: `/journey`, `nextLesson` (sesi harian), sesi Latihan Berbicara, `reinforcementItems`, dan hitungan "materi selesai" yang berbasis Perjalanan (summary/progress/monitoring). Review SM-2 atas item kuis bab **tetap** jalan (item yang salah boleh muncul di review sesi harian — itu fitur, bukan dobel).
7. Attempt dari kuis bab tercatat seperti biasa (akurasi percobaan pertama, SM-2, XP config-driven). Tidak ada angka baru di `config`.

## 6. API

### User (JWT)

| Endpoint | Isi |
|---|---|
| `GET /modules` | `{ inProgress: ModuleCard \| null, forYou: ModuleCard[], others: ModuleCard[] }` — hanya LIVE & punya ≥1 bab; urut `order`. `ModuleCard = {slug,title,summary,level,cefr,coverUrl,chapterCount,quizChapterCount,doneCount,estMinutes}` |
| `GET /modules/:slug` | modul + `chapters: [{order,title,estMinutes,kind:'quiz'\|'reading',done,accuracy?,itemCount}]` + `nextOrder` (bab berkuis pertama yang belum selesai) |
| `GET /modules/:slug/chapters/:order` | `{title,order,estMinutes,blocks,quiz:{itemCount,estXp,done}\|null,prevOrder?,nextOrder?,chapterCount}` |
| `POST /session/module` | `{chapterId}` → `SessionView` (aturan §5.4). `SessionView` menambah `moduleSlug?` + `chapterOrder?` untuk tombol kembali |
| `GET /me/summary` | + `moduleInProgress: {slug,title,nextOrder,nextTitle} \| null` untuk kartu Beranda |

`accuracy` per bab = akurasi percobaan pertama atas item lesson itu (definisi yang sama dengan node Perjalanan).

### Admin (role ADMIN)

| Endpoint | Isi |
|---|---|
| `GET/POST /admin/modules`, `PATCH /admin/modules/:id` | CRUD metadata + status + order; slug unik |
| `GET /admin/modules/:id` | modul + bab (`lesson` ringkas: code, liveItemCount, draftItemCount) |
| `POST /admin/modules/:id/chapters`, `PATCH /admin/chapters/:id` | simpan bab: parse → 400 `{errors:[{line,message}]}` bila gagal, tidak ada yang tersimpan |
| `DELETE /admin/chapters/:id` | hanya bila modul DRAFT **dan** bab belum pernah punya sesi; selain itu 409. Lesson tertaut tidak ikut terhapus (hanya dilepas) |
| `POST /admin/chapters/:id/move` | `{direction:'up'\|'down'}` — tukar `order` dalam satu transaksi |
| `POST /admin/modules/preview` | `{body}` → `{blocks}` atau `{errors}`; tanpa menyimpan |
| `POST /admin/chapters/:id/quiz` | buat Lesson baru tertaut: code `MOD-<slug>-<order>` (unik; suffix bila bentrok), level/cefr dari modul, topic = judul modul, skill `VOCABULARY` (bisa diubah di editor lesson), status DRAFT |
| `PATCH /admin/chapters/:id/quiz` | `{lessonId \| null}` — tautkan lesson yang belum tertaut ke bab lain / lepas tautan |
| `GET /admin/lessons` | + `moduleChapter: {moduleTitle, order} \| null` untuk badge di daftar Soal |

## 7. Tampilan user

Detail visual = mockup user. Ringkasan:

- **Nav:** Beranda · Perjalanan · **Modul** · Progress · Profil. Item aktif = pill dengan label (pola sekarang). Rail desktop ikut.
- **`/modules`:** heading (eyebrow "Belajar per topik") → kartu "Sedang kamu pelajari" (progress bar + LANJUTKAN) bila ada → seksi "Cocok untukmu · <Level>" → seksi "Modul lainnya". Kartu modul: cover/ikon, judul, ringkasan 1 baris, chip CEFR, meta "n bab · ±m mnt", chip "Selesai" bila semua bab berkuis selesai. Kosong → kartu tenang "Modul sedang disiapkan" + tautan ke Beranda. Skeleton & error/retry meniru Perjalanan.
- **`/modules/[slug]`:** ← Modul · cover · judul · ringkasan · chip level·CEFR + menit · progress "x dari y bab" · satu CTA "LANJUTKAN BAB n"/"MULAI BAB 1"/"ULANGI DARI BAB 1" · daftar bab (✓ hijau + akurasi / "Berikutnya" disorot brand / nomor abu / ikon buku = Bacaan). Tap bab mana pun → pembaca.
- **`/modules/[slug]/[order]`** (gulir satu halaman): top bar tipis (← Kembali · "Bab n dari N" · garis progres baca, murni visual) → eyebrow + judul → blok. `phrases` = kartu frasa + tombol 🔊; `dialog` = gelembung kiri (putih) / kanan (brand), tiap baris 🔊; `tip` = kotak `--brand-soft` + `Lightbulb`. 🔊 memakai Web Speech API (`en-US`, rate 0.85) — helper yang sama dengan "Dengarkan contoh", tanpa asset audio. Di akhir: kartu "Kuis Bab n" (n soal · ±menit · +XP · "dihitung ke target harian" bila belum tuntas) → `POST /session/module` → `/session?module=<chapterId>`; sudah tuntas → "Ulangi kuis"; bab Bacaan → "Bab berikutnya". Pager ← Bab sebelumnya · Bab berikutnya →.
- **Sesi:** layar sesi yang ada, tanpa perubahan tipe soal. `use-session` mengenali `?module=` (seperti `?replay=`). Selesai → layar perayaan yang sama; tombol lanjut kembali ke `/modules/[slug]`.
- **Beranda:** kartu kecil "Lanjutkan modul" (`BookOpenText`, judul modul + "Bab n berikutnya") di bawah kartu Lanjutkan Belajar, hanya bila `moduleInProgress`. MULAI tetap satu-satunya CTA besar.

## 8. Tampilan admin

Detail visual = mockup admin. Sidebar KONTEN: **Modul** (`BookOpenText`) di urutan pertama.

- **`/admin/modul`:** tabel (#, judul + slug, level·CEFR, bab "n · x berkuis · y bacaan/belum ada kuis", status pill, diubah, Buka) + filter level/status + "Modul baru". Modul LIVE tanpa bab diberi catatan "tidak tampil walau LIVE". RETIRED butuh konfirmasi (pola daftar lesson).
- **`/admin/modul/[id]`:** form metadata (judul, slug, level, CEFR, ringkasan, cover via pemilih Media) + tabel bab (↑/↓, judul, menit, chip kuis "CODE · n soal LIVE" / kuning "0 soal LIVE → tampil sebagai Bacaan" / abu "Bacaan saja", Edit) + "Bab baru".
- **`/admin/modul/[id]/bab/[chapterId]`:** judul + menit di atas; kiri textarea Markdown bernomor baris; kanan pratinjau 375px dari `POST /admin/modules/preview` (debounce ±500 ms) memakai **komponen render blok yang sama** dengan app user; error → baris disorot merah + bar error di bawah textarea + Simpan nonaktif, pratinjau menampilkan versi valid terakhir. Tombol "Sintaks" membuka cheatsheet (pola `petunjuk-modal`). Panel "Kuis bab": lesson tertaut (code, judul, n LIVE · m DRAFT) + "Kelola soal →" ke `/admin/content/[lessonId]` + "Ganti / lepas"; tanpa kuis → "Buat kuis" / "Tautkan lesson yang ada". Ctrl/Cmd+S = simpan.
- **`/admin/content`:** lesson tertaut bab mendapat badge "Kuis modul: <judul> · Bab n".

## 9. Konten awal — modul "Making & Handling Complaints"

- Seeder baru `apps/api/prisma/seed-module-complaints.ts` (`npm run seed:module-complaints`), **create-only** (modul by slug, bab by moduleId+order dilewati bila sudah ada — edit admin aman; pola sama dengan `seed-complaints.ts`).
- 1 modul MENENGAH·B1, LIVE, 11 bab sesuai alur CMP: kosakata → menyampaikan keluhan → formal vs nonformal → menggali informasi → minta maaf & empati → terima kasih → janji tindakan → konfirmasi penyelesaian → email (reading) → telepon (listening) → ucapan.
- Bab n ditautkan ke lesson `CMP-20n`/`CMP-21n` yang sudah ada (by code; dilewati dengan peringatan bila lesson tidak ditemukan). Akibatnya ke-11 lesson keluar dari Perjalanan Menengah (tersisa WC-201..204) — **disengaja**.
- Isi bacaan tiap bab (pengantar, `phrases`, `tip`, `dialog`) ditulis ulang dalam konteks kerja umum; ungkapan boleh diambil dari modul SKKNI BHS.IS03.004.01, teks dialog/penjelasan modul **tidak disalin**. Body di-parse dengan `parseChapter` yang sama; seeder gagal keras bila ada error parse.
- Seeder dijalankan sesudah `seed:complaints`.

## 10. Prinsip untuk importer (spec berikutnya)

Agar importer nanti tidak memaksa perubahan desain ini:
- Keluaran importer apa pun (PDF SKKNI, PDF lain, DOCX, teks tempel, URL) = **draf**: `Module` DRAFT + bab (Markdown valid menurut §4) + opsional Lesson/Item DRAFT untuk kuis.
- Importer tidak pernah menulis LIVE; admin selalu review di editor §8.
- Validasi akhir selalu lewat `parseChapter` dan validator soal yang sudah ada — tidak ada jalur validasi kedua.

## 11. Error & kasus tepi

| Situasi | Perilaku |
|---|---|
| Markdown tidak valid | 400 + `{errors:[{line,message}]}`; tidak ada yang tersimpan |
| `media:` tak ada di storage | Ditolak saat simpan ("File media tidak ditemukan: …") |
| Modul DRAFT/RETIRED dibuka user via URL | 404 |
| Modul LIVE tanpa bab | Tidak muncul di `/modules` |
| Kuis dimulai saat lesson 0 item LIVE | 409 "Kuis bab ini belum tersedia" (UI menyembunyikan tombolnya) |
| Lesson ditautkan ke 2 bab | Ditolak (409, `lessonId` unik) |
| Lesson tertaut di-RETIRE / semua item retired | Bab jadi Bacaan; attempt & progres lama tidak hilang |
| Sesi kuis bab ditinggal | Resume saat kuis bab dibuka lagi |
| Sesi kuis bab yatim (item hilang) | Ditangani seperti `getOrCreateToday`: hapus bila tanpa attempt, tutup bila ada |
| Admin memindah urutan bab saat user membaca | Pembaca memakai `order`; 404 lembut → kembali ke halaman modul |

## 12. Testing

- **Unit — `parseChapter`:** setiap tipe blok; inline bold/italic/code/link; h1 → h2; container tak ditutup; directive tak dikenal; `phrases` tanpa `|`/sisi kosong; `dialog` tanpa `:` dan pembicara ke-3; side kiri/kanan; `media:` ada/tidak; tautan `javascript:` ditolak; HTML mentah di-escape; nomor baris error akurat.
- **E2E user:** `/modules` (pengelompokan forYou/others/inProgress, hanya LIVE berbab, progres turunan) · DRAFT → 404 · `POST /session/module` → MODULE → selesai → target harian & streak naik + bonus XP · lesson sudah tuntas → REPLAY tanpa bonus · resume · 409 kuis kosong · lesson tuntas via Perjalanan sebelum ditautkan → bab langsung ✓ · lesson tertaut **tidak** muncul di `/journey`, sesi harian, sesi berbicara, penguatan · `moduleInProgress` di summary.
- **E2E admin:** CRUD modul; simpan bab invalid → 400 dengan baris, valid → `blocks` tersimpan; preview tanpa simpan; move up/down; buat kuis → lesson `MOD-…` DRAFT; tautkan/lepas; tautan ganda → 409; badge di `/admin/lessons`.
- **Regresi:** seluruh suite yang ada tetap hijau setelah `COUNTED_SESSION_KINDS` menggantikan filter lama.
- **Seeder:** jalankan dua kali → run kedua 0 dibuat; body semua bab lolos parse.
- **Manual (pemilik proyek):** checklist viewport mobile/desktop 4 layar user + 3 layar admin, 🔊 di iOS Safari, perayaan → kembali ke modul.
