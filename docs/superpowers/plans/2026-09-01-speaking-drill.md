# Speaking Drill (Tier 1) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Tipe soal baru `UCAPAN` — karyawan membaca kalimat bahasa Inggris dengan lantang, aplikasi merekam, transcribe via Groq, menilai dengan fuzzy match, dan menyimpan rekaman permanen. Satu endpoint baru di BE, satu komponen jawaban baru di web, nol dependensi baru, dan tanpa mengubah tulang punggung `attempt`.

**Architecture:** Semua logika di `apps/api` (NestJS). Web (`apps/web`, Next.js 15) murni tampilan: rekam via `MediaRecorder` native → upload multipart → tampilkan hasil. STT = Groq `whisper-large-v3-turbo` lewat `fetch` (Node 22 global, tanpa SDK baru). Alur nilai data:

```
audio (browser) → POST /session/:id/speak → simpan permanen → Groq STT → transcript
  → gradeAnswer(item, transcript) → attempt.answer = transcript, attempt.audioFile = nama file
```

Transcript adalah `attempt.answer`. `Attempt` yang sudah ada tidak berubah strukturnya kecuali satu kolom nullable. `gradeAnswer` (fungsi murni) menangani `UCAPAN` sebagai kasus baru. XP/SM-2/streak/akurasi first-try jalan tanpa disentuh.

**Tech Stack:** sama seperti proyek (NestJS 11 + Prisma 6 + Next.js 15 + Tailwind v4 + Jest) + **Groq STT API** (fetch, tanpa SDK). Env baru: `GROQ_API_KEY`.

**Spec:** `docs/superpowers/specs/2026-08-25-english-app-foundation-design.md`. Eksekutor WAJIB membaca bagian 3 (model data) sebelum Task 1.

## Keputusan desain (sudah disepakati saat brainstorming)

- **Tier 1** — drill ucapan, bukan voice agent realtime. Perkiraan biaya: ~Rp 3–4rb/bulan untuk 50 user (4,6 jam audio/bulan @ Groq $0.04/jam). Tidak butuh opex klien.
- **Audio disimpan permanen** (keputusan user) di storage yang sudah ada (`StorageService` local/S3/MinIO). Naming: `speech/{sessionId}/{itemId}/{timestamp}-{rand}.{ext}`.
- **Consent wajib**: rekaman suara = data pribadi (UU PDP). User harus menyetujui sebelum bisa pakai fitur; endpoint `speak` menolak tanpa consent. Consent tercatat sebagai fakta DB (`User.voiceConsentAt`), bukan checkbox ephemeral.
- **Penilaian = word-recall fuzzy match** (rasio kata referensi yang muncul di transcript, ambang dari tabel `config`). Bukan Azure phoneme — tidak perlu per-fonem untuk pilot.
- **iOS Safari**: `MediaRecorder` modern mendukung `audio/mp4`. Deteksi `isTypeSupported('audio/webm')` → fallback `audio/mp4`. Bila keduanya tak didukung → pesan tidak mendukung, bukan crash.

### Dua mismatch kontrak yang diputuskan di awal (temuan eksplorasi)

1. **Payload jawaban JSON string** (`{itemId, answer}`) tidak muat audio biner. Solusi: endpoint baru `POST /session/:id/speak` (multipart `itemId` + `file`), dipilih web saat `answer` adalah `Blob`. Kontrak `onReady` diubah dari `string | null` menjadi `string | Blob | null` — tiga komponen lama tetap kirim string, tidak berubah.
2. **Whitelist ekstensi `.mp3/.m4a`** (media-block.tsx:24 & media.controller.ts:20) menolak format recorder. Solusi: endpoint `speak` punya validasi ekstensi sendiri (`.webm` `.m4a` `.mp4`), TIDAK lewat `MediaController`. Rekaman preview diputar dari Blob lokal (URL.createObjectURL), bukan lewat `mediaUrl` — `media-block.tsx` tidak perlu diubah untuk v1.

## Global Constraints (tambahan untuk rencana ini)

- Repo `apps/web` dan `apps/api` adalah repo git **terpisah** — commit task dilakukan di repo tempat file berubah; jangan pernah `git add` isi `apps/` dari workspace root.
- Semua logika (STT, grading, consent gate) di `apps/api`. Web tidak menghitung apa pun.
- `attempt` append-only; soal `RETIRED` tidak dihapus. `Attempt.audioFile` nullable — hanya terisi untuk `UCAPAN`.
- Angka konfigurasi di tabel `config`: `SPEAKING_MATCH_THRESHOLD` (0–100, default 70).
- Tanpa cron/queue/background job. Consent hapus-rekaman = endpoint admin manual (keluar scope, dicatat sebagai backlog).
- STT tidak boleh dipanggil saat test e2e — lewat token DI `STT_TRANSCRIBER` (pola sama seperti `STREAK_EVALUATOR` di answer.service.ts), di-override dengan fake.
- `gradeAnswer` tetap fungsi murni: `threshold` opsional lewat `GradableItem`, bukan membaca config sendiri.

---

### Task 1: Schema & seed (apps/api)

**Files:**
- Edit: `apps/api/prisma/schema.prisma`
- Edit: `apps/api/prisma/seed.ts`
- Edit: `apps/api/.env.example`
- Create: `apps/api/prisma/migrations/<ts>_speaking_drill/migration.sql`
- Test: `apps/api/test/schema-phase2.e2e-spec.ts` (atau spec schema yang ada)

**Interfaces:**
- Prisma: `ItemType` += `UCAPAN`; `SkillTag` += `SPEAKING`; `Attempt.audioFile String?`; `User.voiceConsentAt DateTime?`.
- `Config` key baru: `SPEAKING_MATCH_THRESHOLD: '70'`.
- Env: `GROQ_API_KEY` (di `.env.example` dan compose prod/infra).

- [x] **Step 1: Enum & kolom schema**

`schema.prisma`:
```prisma
enum ItemType {
  PILIHAN_GANDA
  ISIAN
  SUSUN_KALIMAT
  UCAPAN
}

enum SkillTag {
  VOCABULARY
  GRAMMAR
  LISTENING
  READING
  SPEAKING
}
```
`model Attempt` += `audioFile String?` (komentar: hanya terisi untuk tipe UCAPAN).
`model User` += `voiceConsentAt DateTime?`.

`npx prisma migrate dev --name speaking_drill` → commit migration.sql.

- [x] **Step 2: Config seed**

`prisma/seed.ts` CONFIG += `SPEAKING_MATCH_THRESHOLD: '70'`.

- [x] **Step 3: Env**

`.env.example` += `GROQ_API_KEY="ganti-di-produksi"`.
`infra/docker-compose.prod.yml` (workspace root) service api environment += `GROQ_API_KEY=${GROQ_API_KEY:-}`.

- [x] **Step 4: Schema e2e menyala**

Jalankan suite schema/phase e2e; tambahkan assertion kolom baru bila ada pola yang sudah ada.

---

### Task 2: Grading & kontrak sesi (apps/api)

**Files:**
- Edit: `apps/api/src/session/grading.ts`
- Edit: `apps/api/src/session/grading.spec.ts`
- Edit: `apps/api/src/session/session.types.ts`
- Edit: `apps/api/src/session/session.service.ts` (`view()`)

**Interfaces:**
- `grading.ts`: fungsi murni `wordOverlapRatio(reference, transcript): number` (0–1); `GradableItem` += `threshold?: number`; `gradeAnswer` += `case 'UCAPAN'`.
- `session.types.ts`: `SessionItemView.type` += `'UCAPAN'`; += `targetText: string | null`.
- `view()`: untuk `UCAPAN`, `targetText = item.answerKey` (kalimat yang dibaca — TIDAK rahasia untuk tipe ini; komentar eksplisit kenapa bocor di sini).

- [x] **Step 1: Fungsi murni di grading.ts**

```ts
/** Normalisasi: huruf kecil, buang tanda baca, pecah kata. */
function words(s: string): string[] { ... }

/**
 * Rasio kata referensi yang muncul di transcript (bag-per-kata, urutan
 * diabaikan). Filler ("uh", "um", pengulangan) tidak menurunkan skor.
 * ponytail: urutan kata & presisi (kata tambahan) bisa ditambahkan bila
 * laporan pilot menunjukkan false-positive — cukup ubah fungsi ini.
 */
export function wordOverlapRatio(reference: string, transcript: string): number { ... }

export interface GradableItem {
  type: string;
  answerKey: string;
  acceptedAnswers: string[];
  threshold?: number; // UCAPAN: 0-100, default 70
}
```

`case 'UCAPAN':` → `wordOverlapRatio(item.answerKey, answer) * 100 >= (item.threshold ?? 70)`.

- [x] **Step 2: Unit test grading.spec.ts**

- `wordOverlapRatio`: kalimat identik = 1; hilang 1 kata = 2/3; urutan beda = 1 (urutan diabaikan); filler tidak menurunkan.
- `gradeAnswer` UCAPAN: transcript pas > ambang → benar; hilang banyak kata < ambang → salah; threshold custom (mis. 100) → hanya kalimat identik benar.

- [x] **Step 3: SessionItemView + view()**

`session.types.ts` union += `'UCAPAN'`; `targetText: string | null`.
`view()` map: `targetText: item.type === 'UCAPAN' ? item.answerKey : null`.

---

### Task 3: Modul speech + endpoint speak (apps/api)

**Files:**
- Create: `apps/api/src/speech/speech.module.ts`
- Create: `apps/api/src/speech/groq-stt.service.ts`
- Create: `apps/api/src/speech/groq-stt.service.spec.ts`
- Edit: `apps/api/src/app.module.ts` (import SpeechModule)
- Edit: `apps/api/src/session/answer.service.ts` (refactor + submitSpeech)
- Edit: `apps/api/src/session/session.controller.ts` (endpoint speak)
- Edit: `apps/api/src/session/session.module.ts` (provider DI token)
- Test: `apps/api/test/session-speak.e2e-spec.ts`

**Interfaces:**
- `STT_TRANSCRIBER` symbol provider (pola identik `STREAK_EVALUATOR` di answer.service.ts) — override-able di e2e.
- `GroqSttService.transcribe(buffer: Buffer, mimeType: string): Promise<string>` — fetch ke `https://api.groq.com/openai/v1/audio/transcriptions`, model `whisper-large-v3-turbo`, `language: 'en'`.
- `POST /session/:id/speak` — multipart `itemId` + `file`; respons `AnswerResult` + `transcript`.

- [x] **Step 1: GroqSttService**

```ts
export const STT_TRANSCRIBER = Symbol('STT_TRANSCRIBER');

@Injectable()
export class GroqSttService implements SttTranscriber {
  async transcribe(buffer: Buffer, mimeType: string): Promise<string> {
    const form = new FormData();
    form.append('model', 'whisper-large-v3-turbo');
    form.append('language', 'en');
    form.append('file', new Blob([buffer], { type: mimeType }), 'record');
    const res = await fetch('https://api.groq.com/openai/v1/audio/transcriptions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${process.env.GROQ_API_KEY}` },
      body: form,
    });
    if (!res.ok) throw new Error(`Groq STT ${res.status}: ${await res.text()}`);
    const json = (await res.json()) as { text?: string };
    return (json.text ?? '').trim();
  }
}
```
Tanpa SDK baru. Interface `SttTranscriber` + provider `{ provide: STT_TRANSCRIBER, useClass: GroqSttService }` di `speech.module.ts`. Unit test: mock global `fetch`, pastikan multipart dikirim & text diekstrak; non-ok → throw.

- [x] **Step 2: Refactor AnswerService — ekstrak `commitAttempt`**

Ekstrak isi transaksi `submit()` (guard sesi/soal/already-correct → buat attempt → review queue → completion → summary) menjadi private method:

```ts
private async commitAttempt(
  userId: string, sessionId: string, itemId: string,
  answer: string, audioFile?: string,
): Promise<AnswerResult>
```
- `submit()` menjadi: guard `typeof answer === 'string'` → `return this.commitAttempt(userId, sessionId, itemId, answer)`.
- `commitAttempt` membaca config XP + `SPEAKING_MATCH_THRESHOLD`, dan untuk `UCAPAN` meneruskan threshold ke `gradeAnswer` + menulis `audioFile` di `attempt.create`.
- Perilaku `submit()` HOLD identik (e2e yang ada adalah jaring pengamannya). `correctAnswer` untuk UCAPAN = `item.answerKey`.

- [x] **Step 3: submitSpeech + consent gate**

```ts
async submitSpeech(userId, sessionId, itemId, file: { buffer, mimetype, originalname }): Promise<AnswerResult> {
  // 1. consent wajib
  const user = await this.prisma.user.findUnique({ where: { id: userId } });
  if (!user?.voiceConsentAt) throw new ForbiddenException('Konsen rekaman suara belum diberikan');

  // 2. pre-check murah sebelum STT (hindari buang call Groq saat sudah benar/aneh)
  //    session milik user + IN_PROGRESS + item.type === 'UCAPAN' + belum ada attempt benar
  //    (re-check ulang di dalam transaksi commitAttempt untuk race-safety)

  // 3. simpan permanen dulu
  const ext = path.extname(file.originalname).toLowerCase() || this.extFromMime(file.mimetype);
  const name = `speech/${sessionId}/${itemId}/${Date.now()}-${crypto.randomUUID().slice(0,8)}${ext}`;
  await this.storage.put(name, file.buffer);

  // 4. STT
  const transcript = await this.stt.transcribe(file.buffer, file.mimetype);
  if (!transcript) return gradeAnswer(...) => salah (transcript kosong = salah, tanpa throw)

  // 5. commit (threshold dibaca commitAttempt utk UCAPAN)
  return this.commitAttempt(userId, sessionId, itemId, transcript, name);
}
```
Multer: `FileInterceptor('file', { limits: { fileSize: 10 * 1024 * 1024 } })`. Validasi ekstensi `.webm/.m4a/.mp4` + mimetype audio/* di controller (tolak selain itu = 400).

- [x] **Step 4: Controller**

`session.controller.ts`:
```ts
@Post(':id/speak')
@UseInterceptors(FileInterceptor('file', { limits: { fileSize: 10 * 1024 * 1024 } }))
async speak(@Param('id') id, @CurrentUser() user, @UploadedFile() file, @Body('itemId') itemId) {
  if (!file) throw new BadRequestException('file wajib diupload');
  return this.answerService.submitSpeech(user.sub, id, itemId, file);
}
```

- [x] **Step 5: e2e `session-speak.e2e-spec.ts`**

Buat user + lesson + item UCAPAN + sesi. Override `STT_TRANSCRIBER` dengan fake (`transcribe` → string tertentu). Kasus:
- Tanpa consent → 403.
- Setelah `PATCH /me { voiceConsent: true }` → upload audio webm → 201, `correct` sesuai transcript fake, `attempt.answer` = transcript, `attempt.audioFile` terisi, `answerResult.transcript` terisi.
- Transcript kosong (fake return `''`) → salah, tanpa throw 500.
- Sesi sudah selesai / item bukan UCAPAN / sudah dijawab benar → 400/404.
- `file` tidak ada → 400.

---

### Task 4: Jalur konten (apps/api + deliverable)

**Files:**
- Edit: `apps/api/src/content/import/row-validator.ts`
- Edit: `apps/api/src/content/import/row-validator.spec.ts`
- Edit: `apps/api/prisma/seed-demo.ts`
- Edit: `deliverables/template-soal-v1.xlsx` + `apps/web/public/template-soal-v1.xlsx`
- Test: `apps/api/test/import.e2e-spec.ts`

**Interfaces:**
- Validator: `TYPES` += `ucapan: 'UCAPAN'`; `SKILLS` += `speaking: 'SPEAKING'`; `NormalizedRow.type`/`skill` union diperluas.
- Template: contoh baris `ucapan` (prompt = instruksi, answer = kalimat referensi) + nilai `speaking` di kolom skill.

- [x] **Step 1: row-validator**

Tambah `ucapan`/`speaking` ke map. Untuk `UCAPAN`, `accepted_answers` diabaikan (opsional), `answer` = kalimat referensi. Tidak ada aturan baru yang wajib (prompt + answer sudah di REQUIRED). Unit test: baris `ucapan` valid → `type: 'UCAPAN'`; skill `speaking` diterima.

- [x] **Step 2: seed-demo**

Tambah 1–2 item UCAPAN di lesson VOCABULARY (atau lesson skill SPEAKING baru) supaya dev punya data demo.

- [x] **Step 3: Template xlsx + petunjuk**

Perbarui `deliverables/template-soal-v1.xlsx` (dan salinan `apps/web/public/`): tambah baris contoh `ucapan` (isian `answer` = kalimat utuh; `prompt` = instruksi membaca; `accepted_answers` kosong), nilai `speaking` pada daftar skill. Update petunjuk: aturan isian untuk `ucapan` (audio dari penulis opsional via `media_file`; referensi diucapkan = kolom `answer`). Verifikasi round-trip: jalankan import e2e dengan baris contoh.

- [x] **Step 4: e2e import**

Tambahkan kasus import baris `ucapan` → item tersimpan dengan `type: 'UCAPAN'`, `answerKey` = kalimat.

---

### Task 5: Web — app user (apps/web)

**Files:**
- Edit: `apps/web/src/lib/api-types.ts`
- Create: `apps/web/src/components/session/answer-speak.tsx`
- Edit: `apps/web/src/app/(user)/session/page.tsx`
- Edit: `apps/web/src/components/session/use-session.ts`
- Edit: `apps/web/src/components/session/feedback-sheet.tsx` (tampilkan transcript)
- Edit: `apps/web/src/app/(user)/onboarding/page.tsx` (step consent)
- Edit: `apps/web/src/lib/use-me.ts` atau `api-types.ts` (MeView += voiceConsentAt)
- Edit: `apps/web/src/app/globals.css` (kls rekam)

**Interfaces:**
- `api-types.ts`: `SessionItemView.type` += `'UCAPAN'`, += `targetText: string | null`; `AnswerResult` += `transcript?: string`; `ItemType` (:274) += `UCAPAN`; `MeView` += `voiceConsentAt: string | null`.
- Kontrak jawaban: `onReady: (answer: string | Blob | null) => void`.
- `answer-speak.tsx`: render `item.targetText` + tombol rekam; `onReady(Blob)` setelah stop; `onReady(null)` saat belum/batal.
- Submit: saat `answer` adalah `Blob` → FormData ke `/session/${id}/speak`.

- [x] **Step 1: api-types.ts**

Salin perubahan tipe dari Task 2/3 (header api-types.ts mewajibkan salinan verbatim dari sumber API).

- [x] **Step 2: answer-speak.tsx**

Implement kontrak `{ item, disabled, result, onReady }`:
- `item.targetText` ditampilkan sebagai kalimat yang harus diucapkan.
- `navigator.mediaDevices.getUserMedia({ audio: true })` → `MediaRecorder`.
- Pilih MIME: `isTypeSupported('audio/webm')` → webm; else `audio/mp4` (iOS); else kedua → pesan "Perangkat tidak mendukung perekaman" + `onReady(null)`.
- Tombol rekam (gaya `.media-audio-play`): mulai → stop; preview `<audio src={URL.createObjectURL(blob)}>`; Rekam Ulang membatalkan dan `onReady(null)`.
- `onReady(blob)` saat rekaman siap; tombol PERIKSA aktif.
- Cleanup: `stream.getTracks().forEach(t => t.stop())` saat unmount.
- `result?.transcript` (saat sudah ter-submit) ditampilkan sebagai "Yang terdeteksi: ..." — kunci feedback speaking.

- [x] **Step 3: session/page.tsx**

- `typeLabel()` (`:241-246`) += `UCAPAN: 'Ucapan'`.
- `SessionBody` tambah conditional: `item.type === 'UCAPAN'` → `<AnswerSpeak ... />`.
- Widening state jawaban: `string | Blob | null` (page.tsx:109-112 handleSubmit meneruskan).

- [x] **Step 4: use-session.ts submit()**

`submit(item, answer: string | Blob)`:
```ts
if (typeof answer === 'string') {
  // endpoint /answer — tidak berubah
} else {
  const fd = new FormData();
  fd.append('itemId', item.itemId);
  fd.append('file', answer, answer.type === 'audio/mp4' ? 'record.m4a' : 'record.webm');
  const result = await api<AnswerResult>(`/session/${view.id}/speak`, { method: 'POST', body: fd });
}
```
Mutasi queue / error handling / submittingRef TIDAK berubah.

- [x] **Step 5: feedback-sheet**

Tampilkan `result.transcript` bila ada (baris "Yang terdeteksi").

- [x] **Step 6: Onboarding consent**

`onboarding/page.tsx`: tambah checkbox wajib (gaya `.choice-card`) — teks menandai: "Saya setuju rekaman suara saya disimpan untuk keperluan penilaian latihan berbicara." Checkbox menyala di step 1 atau step 2; `finish()` (`:62-75`) menambah `voiceConsent: true` ke body PATCH /me dan menolak lanjut bila belum dicentang. Dot progres tetap 2 langkah (checkbox di dalam step, bukan step baru).

- [x] **Step 7: CSS**

`globals.css`: blok `.rec-btn` + wave (reuse `.media-audio-*` :1026-1071), state `[data-recording]`.

---

### Task 6: `/me` consent + admin editor (apps/api + apps/web)

**Files:**
- Edit: `apps/api/src/me/me.controller.ts`
- Edit: `apps/api/src/me/me.controller.spec.ts` (bila ada)
- Edit: `apps/web/src/app/admin/content/[lessonId]/page.tsx` (form edit UCAPAN)
- Test: `apps/api/test/me.e2e-spec.ts`

**Interfaces:**
- `PATCH /me` body += `voiceConsent?: boolean` → set `voiceConsentAt` (sekali set, permanen — tidak bisa dicabut lewat endpoint ini; hapus-rekaman = backlog admin manual).
- `MeView` += `voiceConsentAt`; web `use-me` cache propagasi otomatis.

- [x] **Step 1: me.controller.ts**

`PatchMeBody` += `voiceConsent?: boolean`; guard `typeof !== 'boolean'` → 400 (pola I5). Update data += `...(body.voiceConsent && !existing.voiceConsentAt ? { voiceConsentAt: new Date() } : {})`. `toMeView` += `voiceConsentAt`.

- [x] **Step 2: Admin editor UCAPAN**

`content/[lessonId]/page.tsx`: seksi edit untuk `UCAPAN` — field `prompt` (instruksi) + `answer` (kalimat referensi), tanpa `options`/`accepted_answers`. Patch → `answerKey = answer`, `acceptedAnswers = []`.

- [x] **Step 3: Test**

e2e `PATCH /me` + `voiceConsent: true` → `voiceConsentAt` terisi sekali; body tak valid → 400.

---

### Task 7: Verifikasi & checklist manual

- [x] **Suite API hijau**: unit + e2e (termasuk yang baru) di `apps/api`.
- [x] **Build web**: `npm run build` di `apps/web`.
- [ ] **Checklist manual** (bila app bisa dijalankan): buat item UCAPAN via admin → ikut sesi → rekam → submit → feedback muncul dengan transcript; consent checkbox wajib; iOS Safari pakai m4a; rekaman tersimpan di storage `speech/...`.
- [x] Update `CLAUDE.md` status: tambah entri fitur speaking + todo tersisa (hapus-rekaman atas permintaan, urutan-kata scoring, filter admin, TTS contoh).

## Backlog (sengaja TIDAK dikerjakan sekarang)

- **Hapus rekaman atas permintaan** (UU PDP): endpoint admin manual untuk menghapus `attempt.audioFile` per user. Butuh keputusan: hard-delete vs soft.
- **Presisi & urutan kata** dalam penilaian (ponytail di `wordOverlapRatio`).
- **TTS contoh ucapan** per soal (tambahan, cost ~nol, media di-cache).
- **Review rekaman di dashboard admin** (pemutaran `audioFile`).
- **Tier 2** (feedback LLM) / **Tier 3** (voice agent) — hanya setelah komitmen opex klien.
