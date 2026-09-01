# Talking Agent — Percakapan Suara Dua Arah Real-Time (Fase Terpisah, BUKAN Rilis 1)

> **STATUS: KONSEP ARSITEKTUR, BUKAN RENCANA EKSEKUSI AKTIF.** Fitur ini secara eksplisit
> di luar scope Rilis 1 (Rp 8jt fixed, 40 hari, sedang berjalan). Dokumen ini disiapkan
> supaya keputusan arsitektur sudah matang SEBELUM pemilik produk commit ke opex baru
> (ElevenLabs credits, dibayar per menit panggilan) — bukan untuk dieksekusi task-by-task
> sekarang. Butuh: (1) keputusan pemilik produk untuk lanjut, (2) line item budget
> terpisah (bulanan, bukan fixed-price), (3) pilihan tier ElevenLabs (lihat §8).
>
> Kalau/ketika disetujui: dokumen ini cukup matang untuk dipecah jadi Task 1..N bergaya
> `2026-09-01-speaking-drill.md` tanpa riset ulang — pilihan arsitektur di bawah sudah
> final, bukan menu opsi.

**Goal:** User punya dialog suara langsung dengan AI (bukan baca satu kalimat seperti
UCAPAN) — "Ngobrol dengan AI", terpisah dari menu "Latihan Berbicara" yang sudah ada.
Provider: **ElevenLabs Conversational AI** (sudah diputuskan, lihat §0).

## §0. Kenapa arsitektur ini beda total dari Speaking Drill

Speaking Drill (UCAPAN) dan Menu Berbicara (`kind:'SPEAKING'`) adalah **request/response**:
browser upload audio → BE panggil Groq STT → BE grading → BE respons — BE ada di dalam
setiap langkah, synchronous, satu HTTP request per soal.

Talking Agent adalah **WebSocket dua arah, langsung antara browser dan ElevenLabs** — BE
TIDAK ada di jalur panggilan sama sekali. BE cuma di dua ujung:
- **Sebelum**: mint kredensial sekali-pakai (browser tidak pernah pegang API key kita).
- **Sesudah**: terima webhook `post_call_transcription` dari ElevenLabs (async, server-to-
  server, tanpa client dalam loop) beberapa detik–menit setelah panggilan selesai.

Konsekuensi arsitektur:
1. BE **tidak bisa** menegakkan batas durasi panggilan secara real-time (tidak ada
   koneksi ke BE selama call). Batas durasi = setting di dashboard agent ElevenLabs
   sendiri, bukan kode kita. Config table kita hanya menyimpan angka ini untuk
   dokumentasi/konsistensi, BUKAN untuk enforcement.
2. Model data `Session`/`SessionItem`/`Attempt` (satu row per jawaban per soal konten)
   tidak cocok — percakapan bebas topik tidak punya "item" untuk digradasi satu-satu, dan
   dinilai belakangan secara holistik dari transcript, bukan per-jawaban.
3. Grading terjadi async lewat webhook publik — endpoint publik PERTAMA di codebase ini
   (lihat §3), butuh model kepercayaan sendiri.

---

## §1. Data Model — `VoiceConversation` (model baru, BUKAN reuse SessionKind)

**Keputusan: model baru + enum status baru sendiri. TIDAK menambah `SessionKind`.**

Alasan: `SessionKind` (`DAILY|REPLAY|SPEAKING`) melekat pada semantik "kumpulan
`SessionItem` yang merujuk `Item` konten nyata dari importer." Memaksakan percakapan
bebas-topik ke situ berarti mengarang `Item`/`Lesson` palsu supaya `Attempt` (yang FK ke
`itemId` nyata) bisa dibuat — mencemari tabel konten yang datang dari spreadsheet klien
dengan row hantu, dan bikin layar admin/laporan konten bingung. Ditolak — bukan trade-off
yang worth it dibanding satu tabel baru yang jujur soal bentuknya sendiri.

```prisma
enum VoiceConversationStatus {
  PENDING // kredensial diminta, panggilan mungkin belum/sedang berlangsung, webhook belum datang
  GRADED  // webhook sudah diproses — passed + xpAwarded final (xpAwarded bisa 0 kalau tidak lolos aturan MVP)
}

model VoiceConversation {
  id                       String @id @default(cuid())
  userId                   String
  user                     User @relation(fields: [userId], references: [id])
  // ID sisi ElevenLabs — null sampai webhook datang; disimpan cuma untuk
  // ketertelusuran/dukungan (cari di dashboard ElevenLabs), BUKAN kunci lookup utama
  // (lihat §3 — lookup pakai `id` kita sendiri via dynamic_variables).
  elevenlabsConversationId String? @unique
  status                   VoiceConversationStatus @default(PENDING)
  durationSecs             Int?     // data.metadata.call_duration_secs
  userTurnCount            Int?     // count(transcript[].role === 'user')
  costCredits              Int?     // data.metadata.cost
  // Transcript verbatim (array {role, message, time_in_call_secs, ...}) — filosofi
  // append-only sama seperti `attempt`: tidak pernah dihapus, jadi bahan mentah siap
  // pakai untuk Fase C (LLM quality feedback) tanpa perlu ambil ulang dari ElevenLabs
  // (webhook = push sekali, tidak bisa di-replay).
  transcript               Json?
  passed                   Boolean?
  xpAwarded                Int @default(0)
  createdAt                DateTime @default(now()) // = waktu mint token
  gradedAt                 DateTime?
  @@index([userId, createdAt])
}
```

`User` += `voiceConversations VoiceConversation[]` (relasi balik).

Field yang SENGAJA tidak disimpan: raw webhook payload penuh (tool_calls/tool_results,
deletion_settings) — Fase A tidak pakai Webhook Tools, jadi field itu kosong; transcript +
metadata inti sudah subset yang berguna. `ponytail: kalau Fase C butuh field lain dari
payload yang tidak diekstrak di sini, tambah kolom saat itu — webhook tidak reusable untuk
backfill, jadi keputusan ini HANYA aman kalau kita percaya field di atas cukup untuk semua
kebutuhan MVP+Fase B; risikonya rendah karena Fase A/B tidak butuh apa pun di luar itu.`

---

## §2. Endpoint mint kredensial — `POST /voice-conversation/start`

Modul baru `src/voice-conversation/`, controller ber-`@UseGuards(JwtAuthGuard)` (pola sama
seperti `SessionController`).

```ts
@Controller('voice-conversation')
@UseGuards(JwtAuthGuard)
export class VoiceConversationController {
  constructor(private svc: VoiceConversationService) {}

  @Post('start')
  start(@CurrentUser() user: AuthUser) {
    return this.svc.start(user.sub);
  }

  @Get(':id')
  status(@Param('id') id: string, @CurrentUser() user: AuthUser) {
    return this.svc.status(user.sub, id);
  }
}
```

`VoiceConversationService.start(userId)`:
1. **Consent gate** — reuse persis pola `answer.service.ts`: `if (!user?.voiceConsentAt)
   throw new ForbiddenException(...)`. Rekaman suara dua arah = data pribadi yang sama
   sensitifnya (UU PDP) — consent yang SUDAH wajib diisi user saat onboarding (untuk
   UCAPAN) otomatis meng-cover fitur ini juga. **Tidak perlu layar consent baru.**
2. **Cap gate** (kontrol biaya, §6/§8) — hitung `VoiceConversation` milik user hari ini
   (WIB, pakai `todayWIB()`) dan minggu ini (pakai `weekStartWIB()`, keduanya sudah ada di
   `common/wib.ts`, reuse langsung). Lebih dari `VOICE_DAILY_CAP`/`VOICE_WEEKLY_CAP` →
   429 dengan pesan "Batas ngobrol harian/mingguan sudah tercapai."
3. **Mint signed URL** — lewat DI token yang bisa di-swap di e2e (pola identik
   `STT_TRANSCRIBER` di `groq-stt.service.ts` — jangan pernah panggil ElevenLabs asli saat
   test):
   ```ts
   export const ELEVENLABS_CLIENT = Symbol('ELEVENLABS_CLIENT');
   export interface ElevenLabsClient {
     getSignedUrl(agentId: string): Promise<string>;
   }
   @Injectable()
   export class ElevenLabsService implements ElevenLabsClient {
     async getSignedUrl(agentId: string): Promise<string> {
       const res = await fetch(
         `https://api.elevenlabs.io/v1/convai/conversation/get-signed-url?agent_id=${agentId}`,
         { headers: { 'xi-api-key': process.env.ELEVENLABS_API_KEY! } },
       );
       if (!res.ok) throw new Error(`ElevenLabs ${res.status}: ${(await res.text()).slice(0,200)}`);
       const json = (await res.json()) as { signed_url: string };
       return json.signed_url;
     }
   }
   ```
   Fetch mentah, tanpa SDK baru di BE — konsisten dengan `GroqSttService` (lazy: tidak ada
   alasan tambah dependency untuk satu GET request).
4. **Buat row `PENDING`** — `userId`, `createdAt=now()`. Ini terjadi SEBELUM panggilan
   benar-benar mulai (user bisa saja batal/browser tolak izin mic) — row tetap dibuat
   (boleh "orphan" PENDING selamanya, sama filosofinya dengan attempt/orphan speech file:
   append-only, tidak ada cleanup job di skala pilot 20–50 user).
5. **Respons**:
   ```ts
   {
     signedUrl: string,
     conversationRecordId: string, // row.id — dipakai client buat polling status
     dynamicVariables: {
       fluen_conversation_id: string, // = row.id — kunci lookup webhook (§3)
       fluen_user_id: string,         // cross-check tambahan, defense-in-depth
     },
   }
   ```

**`VoiceConversationService.status(userId, id)`** — `GET /voice-conversation/:id`: ambil
row, 404 kalau `row.userId !== userId` (pola ownership check sama seperti `session.view()`
— jangan cuma percaya `id` di URL). Balikkan `{ status, passed, xpAwarded, durationSecs }`
— **transcript TIDAK dikirim ke client** (data pribadi, tidak perlu di v1).

---

## §3. Webhook receiver — endpoint publik PERTAMA di codebase ini

**Ini butuh perhatian ekstra — bukan pola yang sudah ada di repo, dan salah verifikasi
signature di sini berarti siapa pun di internet bisa POST payload palsu dan memicu
pemberian XP.** Tulis dengan hati-hati, jangan dipersingkat saat implementasi nanti.

**Controller terpisah** dari `VoiceConversationController` (`voice-conversation-
webhook.controller.ts`), sengaja file/class sendiri walau satu modul — supaya route publik
ini SECARA VISUAL tidak pernah bercampur dengan route yang di-guard JWT. Tidak ada
`@UseGuards` sama sekali di class ini (dan memang tidak ada `APP_GUARD` global di
`main.ts`/`app.module.ts` yang bisa "menyusup" — sudah dikonfirmasi lewat eksplorasi kode,
jadi ini aman secara default, tapi tetap catat eksplisit di komentar kode kenapa controller
ini publik dengan sengaja).

**Route**: `POST /voice-conversation/webhook/elevenlabs`.

**Verifikasi signature** (`ElevenLabs-Signature` header, HMAC):
- Butuh BYTES MENTAH body, bukan objek yang sudah di-parse Nest — HMAC di atas JSON yang
  di-serialize ulang bisa mismatch byte-for-byte dengan apa yang ElevenLabs kirim.
- Pilihan: bind middleware `express.raw({ type: 'application/json' })` HANYA ke path ini
  di `main.ts`, sebelum Nest punya kesempatan parse JSON secara global untuk route lain —
  blast radius kecil (tidak mengubah body-parsing app-wide), lebih "boring" dibanding pakai
  opsi `rawBody: true` bawaan Nest 11 yang mengubah perilaku global.
- `crypto.createHmac('sha256', process.env.ELEVENLABS_WEBHOOK_SECRET).update(rawBuf).digest('hex')`,
  bandingkan pakai `crypto.timingSafeEqual` (BUKAN `===` — perbandingan string biasa bocor
  info lewat timing attack; stdlib `crypto` sudah punya primitive yang benar, pakai itu).
- Signature tidak valid → 401, JANGAN proses body.
- **VERIFY DI WAKTU IMPLEMENTASI** (bukan blocker rencana ini, tapi wajib dicek sebelum
  merge): format header persis (`t=...,v0=...` gaya Stripe, atau format lain), apakah
  timestamp ikut di-hash, dan test end-to-end pakai fitur "send test webhook" dashboard
  ElevenLabs (kalau ada) sebelum dipercaya di prod.

**Resolusi user & idempotency** — setelah signature valid:
1. Parse body, ambil `data.conversation_initiation_client_data.dynamic_variables
   .fluen_conversation_id` → ini `id` row kita sendiri (bukan `elevenlabsConversationId`
   — kita generate `id` ini SENDIRI saat mint token, sebelum panggilan mulai, jadi ini
   yang paling bisa dipercaya sebagai kunci lookup).
2. `findUnique({ where: { id: fluenConversationId } })`. Tidak ketemu → log warning, 200
   ack (retry ElevenLabs tidak akan memperbaiki row yang memang tidak pernah kita buat —
   bukan kasus yang layak di-retry-storm).
3. Cross-check `dynamic_variables.fluen_user_id === row.userId` — kalau mismatch, log
   sebagai mencurigakan, JANGAN beri XP, 200 ack tanpa update (defense-in-depth murah;
   secara praktis `id` cuid sudah unguessable — sama level kepercayaan dengan `sessionId`
   yang juga dipakai sebagai bearer-capability di tempat lain di codebase ini — jadi risiko
   riil rendah, tapi cek ini nyaris gratis untuk ditambahkan).
4. **Idempotency tanpa transaksi/advisory-lock** — cukup satu `updateMany` bersyarat:
   ```ts
   const { count } = await this.prisma.voiceConversation.updateMany({
     where: { id: row.id, status: 'PENDING' }, // guard: cuma proses sekali
     data: { status: 'GRADED', elevenlabsConversationId, durationSecs, userTurnCount,
             costCredits, transcript, passed, xpAwarded, gradedAt: new Date() },
   });
   if (count === 0) { /* sudah pernah digradasi — webhook retry, no-op, 200 */ }
   ```
   `UPDATE ... WHERE status='PENDING'` atomik di level row lock Postgres — retry webhook
   yang datang dua kali (ElevenLabs docs bilang webhook BISA retry) otomatis jadi no-op
   begitu row pertama sudah `GRADED`. Tidak butuh `pg_advisory_xact_lock` seperti
   `getOrCreateToday` — pola itu ada untuk race CREATE ganda; di sini kita UPDATE dengan
   WHERE-guard, race-safe secara alami tanpa lock eksplisit. **Ini lebih simpel dari pola
   session yang ada — sengaja, bukan kelalaian.**
5. Selalu respons 200 begitu signature valid diverifikasi (bahkan untuk kasus "row tidak
   ketemu"/"sudah pernah digradasi") — hanya signature invalid yang boleh non-200, supaya
   ElevenLabs tidak retry-storm kasus yang memang tidak akan pernah berhasil.

**Penghitungan `passed`/`xpAwarded`** — lihat §7 (aturan grading MVP).

**Streak/XP — keputusan sentral (opsi a, DIPILIH)**:

Tiga opsi dari brief: (a) jalur standalone minimal yang menduplikasi secukupnya, (b)
ekstrak helper bersama, (c) paksa jadi Session/Attempt palsu satu-item. **(c) ditolak**
(lihat §1 — mencemari model konten). **(b) ditolak** — logika XP di `commitAttempt` sudah
menyatu erat dengan bookkeeping penyelesaian sesi (session.xpAwarded, accuracyFirstTry,
dst) yang tidak relevan sama sekali di sini; "helper bersama" yang diekstrak ujungnya
cuma akan berisi satu baris (`config.getInt` + tulis angka), jadi tidak ada DRY nyata yang
didapat, cuma indirection.

**Dipilih: (a) — jalur standalone, TANPA menyentuh `Session`/`Attempt`/`StreakService`
sama sekali.** Webhook handler langsung baca `XP_VOICE_CONVERSATION` dari config, hitung
`passed`, tulis `xpAwarded` ke row `VoiceConversation` sendiri. Tidak ada duplikasi logika
XP yang berarti — cuma satu angka dari config, ditulis satu kali, dengan idempotency guard
di atas.

**Konsekuensi yang harus eksplisit disadari**: karena tidak menyentuh `Session`, percakapan
suara **TIDAK ikut menghitung target sesi harian / streak** di v1 — beda dari Menu
Berbicara yang eksplisit "dihitung sama seperti sesi biasa." Ini keputusan v1 yang
disengaja (scope minimal untuk fitur yang sudah ditandai deferred), bukan kelalaian:
- **XP tetap masuk ke `xpTotal`** — lihat §1 poin baru di `summary.service.ts` /
  `progress.service.ts` / `monitoring.service.ts`: ketiganya sudah punya pola identik
  `xpTotal = attemptXpSum + sessionXpSum` (dua `aggregate({_sum:{xpAwarded}})` yang
  dijumlah) — tambah `voiceConversationXpSum` sebagai suku ketiga di tiga tempat itu, pola
  yang sama, bukan sesuatu yang baru (mirip precedent "10 titik filter `kind`" untuk Menu
  Berbicara di CLAUDE.md).
- **OPEN QUESTION** (keputusan produk, bukan arsitektur): apakah Fase B/C nanti perlu
  bikin percakapan suara ikut menghitung streak/target harian juga? Kalau ya, itu berarti
  menyentuh `StreakService.compute()` (query `session.count` dengan `kind: {in:[...]}}`)
  dan target harian — expansion yang genuinely lebih besar (banyak titik sentuh, seperti
  precedent Menu Berbicara), sengaja TIDAK dikerjakan sekarang. Rekomendasi default: biarkan
  XP-only selamanya kecuali ada alasan produk kuat — menghubungkan "harus ngobrol sama AI
  tiap hari" ke streak berlawanan dengan pesan kontrol biaya (cap harian/mingguan) yang
  justru membatasi frekuensi pemakaian.

---

## §4. UX async: client tahu kapan grading selesai

Tidak perlu endpoint "call ended" terpisah (row `VoiceConversation` sudah dibuat `PENDING`
sejak mint token di §2 — lebih sederhana dari pola yang diajukan brief, karena tidak perlu
langkah "flip ke PENDING" belakangan).

Alur:
1. User tekan "MULAI NGOBROL" → `POST /voice-conversation/start` → dapat `signedUrl` +
   `conversationRecordId` + `dynamicVariables`.
2. `Conversation.startSession({ signedUrl, dynamicVariables })` (`@elevenlabs/client`) —
   panggilan berjalan, browser ↔ ElevenLabs langsung, BE sama sekali tidak di jalur ini.
3. User tekan "SELESAI" (atau agent akhiri sendiri) → `conversation.endSession()` →
   callback `onDisconnect` client mulai **polling** `GET /voice-conversation/:id` tiap
   ±2 detik, tampilkan "Menilai percakapanmu...".
4. Webhook ElevenLabs datang (independen, detik–menit kemudian) → status jadi `GRADED`.
5. Poll berikutnya lihat `GRADED` → stop polling, tampilkan hasil (lolos/tidak + XP).
6. **Timeout client-side** (mis. 60 detik tanpa `GRADED`) → stop polling, tampilkan pesan
   "Sedang diproses, XP akan muncul nanti" — TIDAK infinite-loop. Row tetap `PENDING`
   selamanya kalau webhook memang tidak pernah datang (append-only, tidak ada cron
   pembersih di skala pilot ini — sama filosofi dengan orphan speech file).

---

## §5. Web — halaman & entry point baru

**Dependency baru**: `@elevenlabs/client` (`Conversation.startSession(...)`). Ini
dependency NPM PERTAMA yang ditambah ke `apps/web` sejak fondasi (deps saat ini cuma
`lucide-react`, `next`, `react`) — layak, karena tidak ada alternatif stdlib/native untuk
klien protokol WebSocket voice ElevenLabs; bukan kasus untuk dihindari.

**Halaman baru**: `src/app/(user)/talk/page.tsx` (slug Inggris, konsisten dengan
`/session`, `/onboarding` — URL Inggris + copy UI Indonesia, pola yang sudah ada).

**Entry point Home** — kartu KETIGA terpisah, judul **"Ngobrol dengan AI"** (instruksi
eksplisit pemilik produk: terpisah dari "Latihan Berbicara"), reuse `Card`/`ChunkyButton`
dari `@/components/ui` persis pola kartu `startSpeaking()` yang sudah ada di
`home/page.tsx` (ikon `lucide-react` baru, mis. `Bot` — cek versi lucide terpasang di
implementasi). **Gated di belakang Config flag** (`VOICE_AGENT_ENABLED`, 0/1, dibaca via
`config.getInt` yang sudah ada — 0/1 valid sebagai int, tidak perlu extend
`AppConfigService`), diekspos lewat `SummaryView.voiceAgentEnabled: boolean` (dihitung di
BE, bukan env var di web — menjaga aturan "semua logika di BE, Next.js murni tampilan").
Ini mekanisme soft-launch murah: bisa dinyalakan untuk subset pilot tanpa deploy.

**Consent**: TIDAK ada layar baru — `voiceConsentAt` sudah wajib diisi di onboarding untuk
semua fitur suara, sudah meng-cover ini (lihat §2 poin 1).

**Komponen**: satu file `talk/page.tsx` untuk v1 — belum ada alasan ekstrak komponen
terpisah (tidak dipakai di tempat lain). `ponytail: kalau UI panggilan (indikator
bicara/mendengar, dst) membengkak >150 baris, pecah jadi src/components/talk/*.tsx saat
itu, bukan sekarang.`

Penanganan izin mikrofon: `@elevenlabs/client` akan minta `getUserMedia` sendiri saat
`startSession` — tangkap error penolakan izin dengan nada sama seperti dance
`isTypeSupported` di `answer-speak.tsx` (pesan jelas, bukan crash).

---

## §6. Config baru (tabel `config`, semua integer — `AppConfigService.getInt` sudah cukup,
tidak perlu extend method baru)

| Key | Arti | Default usulan |
|---|---|---|
| `VOICE_DAILY_CAP` | Maks percakapan/user/hari WIB | `1` |
| `VOICE_WEEKLY_CAP` | Maks percakapan/user/minggu WIB | `4` |
| `VOICE_MIN_DURATION_SECS` | Aturan grading MVP §7 | `60` |
| `VOICE_MIN_USER_TURNS` | Aturan grading MVP §7 | `4` |
| `XP_VOICE_CONVERSATION` | XP saat `passed=true` | usulan 2× `XP_SESSION_COMPLETE` (angka final = keputusan bisnis, tunable via config, bukan arsitektur) |
| `VOICE_AGENT_ENABLED` | 0/1 — toggle kartu Home | `0` (mati by default, dinyalakan manual saat siap) |

**Batas durasi panggilan itu sendiri BUKAN row config kita** — itu setting di dashboard
agent ElevenLabs (BE tidak di jalur panggilan, tidak bisa menegakkannya — lihat §0).

---

## §7. Aturan grading MVP (v1) — murah, tanpa LLM

```
passed = durationSecs >= VOICE_MIN_DURATION_SECS
      && userTurnCount >= VOICE_MIN_USER_TURNS
xpAwarded = passed ? XP_VOICE_CONVERSATION : 0
```

- `durationSecs` = `data.metadata.call_duration_secs` (langsung dari payload, tidak perlu
  hitung sendiri).
- `userTurnCount` = `data.transcript.filter(t => t.role === 'user').length`.

Tidak ada scoring kualitas percakapan (grammar, fluency, relevansi) di v1 — itu eksplisit
Fase C (LLM judge), lihat §10. Aturan ini cuma "apakah user benar-benar mengobrol cukup
lama", bukan "apakah bagus" — cukup untuk anti-abuse cap XP murah, sesuai instruksi.

---

## §8. Kontrol biaya

**Estimasi tier ElevenLabs untuk pilot 20–50 user**: dengan `VOICE_DAILY_CAP=1`,
realistis user aktif ngobrol ~2–3×/minggu (bukan tiap hari, tidak semua 50 user pilot aktif
tiap hari — baseline realistis, beda dari worst-case teoretis), rata-rata call ±4 menit →
kira-kira 50 user × 3/minggu × 4 menit × 4 minggu ≈ 2.400 menit/bulan **kalau semua 50 user
maksimal** — angka ini TIDAK punya baseline historis sama sekali (beda dari Speaking Drill
yang punya angka "4,6 jam/bulan" dari pola pemakaian rekaman pendek per-kalimat; percakapan
dua arah adalah pola pemakaian baru sepenuhnya). Rekomendasi mulai dari **tier Pro
($99/1238 menit)** untuk pilot dengan headroom testing, TURUN ke Creator ($22/275 menit)
kalau setelah 2–4 minggu data riil pemakaian jauh di bawah cap. Starter ($6/75 menit) cuma
cukup untuk alpha tertutup (~5–10 orang, testing sporadis), bukan pilot penuh 20–50 user.

**Lever utama**: cap harian/mingguan per-user (§6, ditegakkan di §2 poin 2) — ini yang
membatasi worst-case spend secara keras, independen dari tier plan.

**Backstop wajib** (bukan sekadar nice-to-have): hard spend-limit/kill-switch di level akun
ElevenLabs sendiri (dashboard billing). **Alasan ini WAJIB, bukan opsional**: cap kita di
BE cuma mencegah panggilan BARU dimulai — begitu satu panggilan sudah jalan, BE sama sekali
tidak bisa memotongnya kalau, misalnya, agent "nyangkut" merespons diri sendiri atau
koneksi memanjang tak terduga (§0 — BE tidak di jalur panggilan). **VERIFIKASI SEBELUM
DINYALAKAN UNTUK USER NYATA**: konfirmasi kapabilitas ini benar-benar ada di dashboard
billing ElevenLabs (belum dicek — di luar 2 verifikasi WebFetch yang sudah dilakukan untuk
plan ini) — treat sebagai prasyarat wajib sebelum Fase A live, bukan catatan kaki.

---

## §9. Daftar file (BE + Web)

### BE (`apps/api`)
- **Baru**: `src/voice-conversation/voice-conversation.module.ts`,
  `voice-conversation.service.ts` (start/status/cap-check), `voice-conversation.controller.ts`
  (`start`/`:id`, JWT-guarded), `voice-conversation-webhook.controller.ts` (publik, HMAC),
  `elevenlabs-client.service.ts` (DI token `ELEVENLABS_CLIENT`, pola `STT_TRANSCRIBER`),
  plus `*.spec.ts` untuk service + webhook signature verify (unit) dan
  `test/voice-conversation-start.e2e-spec.ts` + `test/voice-conversation-webhook.e2e-spec.ts`
  (e2e, override `ELEVENLABS_CLIENT` dengan fake — jangan pernah panggil ElevenLabs asli
  saat test, pola identik `STT_TRANSCRIBER`).
- **Edit**: `prisma/schema.prisma` (model + enum §1), `prisma/migrations/<ts>_.../migration.sql`
  (generated), `prisma/seed.ts` (config baru §6), `.env.example` (+
  `ELEVENLABS_API_KEY`, `ELEVENLABS_AGENT_ID`, `ELEVENLABS_WEBHOOK_SECRET`), `src/app.module.ts`
  (import module baru), `src/main.ts` (raw-body middleware di path webhook — lihat §3),
  `src/me/summary.service.ts` + `src/progress/progress.service.ts` +
  `src/monitoring/monitoring.service.ts` (masing-masing: tambah suku ketiga
  `voiceConversationXpSum` ke pola `xpTotal` yang sudah identik di tiga file ini — pola
  repetitif, sudah ada precedent-nya, tidak perlu dijabarkan per baris).

### Web (`apps/web`)
- **Baru**: `src/app/(user)/talk/page.tsx`.
- **Edit**: `package.json` (+ `@elevenlabs/client`), `src/lib/api-types.ts` (tipe respons
  `start`/`status`, + `SummaryView.voiceAgentEnabled: boolean`), `src/app/(user)/home/page.tsx`
  (kartu ketiga "Ngobrol dengan AI", gated `summary.voiceAgentEnabled`).

---

## §10. Fase dalam fitur ini sendiri

**Fase A** (MVP, di atas): satu percakapan bebas topik, agent generik (system prompt
"latihan ngobrol bahasa Inggris" di dashboard ElevenLabs, tidak ditemplat), grading
durasi+giliran (§7), rollout manual lewat `VOICE_AGENT_ENABLED`, QA manual.

**Fase B**: topik terikat konten pelajaran. `POST /voice-conversation/start` terima
`lessonId` opsional, BE ambil judul/kosakata lesson itu, kirim sebagai dynamic variable
tambahan (mis. `topic`), system prompt agent di dashboard ditemplat `{{topic}}` supaya
percakapan terarah ke materi yang sedang dipelajari user. Penambahan kecil di atas
plumbing Fase A (satu field tambahan di request + dynamic variable) — tidak butuh
perubahan model data.

**Fase C**: feedback kualitas berbasis LLM (Tier 2 di terminologi backlog CLAUDE.md yang
sudah ada). `VoiceConversation.transcript` (sudah tersimpan lengkap sejak Fase A) adalah
input persis yang dibutuhkan — data model TIDAK perlu berubah untuk fase ini. Baru di sini
cron/job async (boleh, karena fitur ini sudah di luar batas "tanpa cron" Rilis 1) yang
kirim transcript ke LLM (Groq atau LLM ElevenLabs sendiri) untuk feedback grammar/fluency,
disurfacekan belakangan ke user. Sengaja TIDAK didesain detail di sini per instruksi —
hanya dicatat sebagai extension point yang sudah siap pakai.

---

## Open Questions (butuh keputusan produk, bukan arsitektur)

1. Apakah percakapan suara yang lolos grading harus ikut menghitung target sesi
   harian/streak (seperti Menu Berbicara), atau tetap XP-only selamanya? Default v1: XP-only
   (§3). Perlu keputusan eksplisit kalau mau diperluas di Fase B/C.
2. Angka final `XP_VOICE_CONVERSATION` dan cap harian/mingguan — usulan di §6 cuma starting
   point, keputusan bisnis pemilik produk (mudah diubah, hidup di `config`).
3. Verifikasi kapabilitas hard spend-limit di dashboard billing ElevenLabs (§8) — prasyarat
   sebelum Fase A live untuk user nyata.
