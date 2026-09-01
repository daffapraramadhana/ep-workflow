# English App — Workspace

Repo ini adalah **workspace/orchestration**, bukan repo aplikasi. Isinya: spec, plan, keputusan produk, dan instruksi agent. Kode aplikasi hidup di repo git terpisah di dalam `apps/` (di-ignore oleh repo ini).

## Struktur

```
english-app/        ← repo workspace (ini)
  docs/superpowers/specs/   ← spec & plan; baca spec fondasi dulu
  apps/web/         ← repo sendiri: Next.js (user app di /, admin di /admin)
  apps/api/         ← repo sendiri: NestJS + Prisma + Postgres
```

- Jangan commit apa pun di `apps/` ke repo workspace — masing-masing punya git sendiri.
- Tanpa submodule. Repo anak berdampingan biasa.
- Kontrak API (DTO) hidup di `apps/api`, di-copy tipis / digenerate ke `apps/web`. Bukan package npm terpisah.

## Konteks produk (ringkas)

**Fluen** — platform belajar bahasa Inggris harian untuk karyawan. Rilis 1: Rp 8 jt fixed, 40 hari kerja / 8 minggu, solo. Pilot 20–50 user. Konten (soal) dari tim klien via template spreadsheet + importer.

Keputusan fondasi lengkap ada di `docs/superpowers/specs/2026-08-25-english-app-foundation-design.md`. Intinya yang tidak boleh dilanggar:

- Tabel `attempt` mencatat setiap jawaban, selamanya; akurasi selalu dari percobaan pertama saja.
- Soal `retired` tidak pernah dihapus.
- Dashboard manajemen: aktivitas + tren per-orang; tanpa ranking/rata-rata skor antar-orang.
- Semua logika (grading, XP, sesi, importer) di BE; Next.js murni tampilan.
- Angka XP/limit di tabel `config`, bukan hardcode.
- Tanpa background job/cron di Rilis 1.

## Status

- [x] Spec fondasi — disetujui
- [x] Rencana implementasi Fase 1 (docs/superpowers/plans/2026-08-25-fase-1-fondasi-dan-admin.md)
- [x] **Fase 1 SELESAI** (25 Agu 2026): apps/api (schema 10 tabel, auth+undangan, importer soal+karyawan, media local/S3, CRUD admin, Dockerfile, seed-on-boot) + apps/web (login/guard/invite + 4 halaman admin, Dockerfile) + deliverables (template-soal-v1.xlsx + petunjuk, teruji round-trip) + infra (compose prod, Caddy, backup harian, runbook). Suite api: 43 unit + 36 e2e hijau.
- [x] Spec UI/UX + design system (docs/design-system.md — token, komponen, motion, bunyi, Lucide 2.25, mimic guide admin)
- [x] **Fase 2 SELESAI** (26 Agu 2026): BE session engine (perakitan sesi beku + replay + penguatan, grading 3 tipe, XP config-driven + cap review, SM-2 post-increment, streak + freeze lazy WIB, journey/progress/report) + app user lengkap (onboarding, beranda hero, sesi chip-kata/feedback-sheet/media, perayaan, perjalanan, progress, profil) + admin restyle. Suite api: 55 unit + 85 e2e hijau. Verifikasi manual viewport = milik pemilik proyek (checklist: docs/superpowers/verifikasi/2026-fase2-checklist.md).
- [x] **Fase 3 SELESAI** (26 Agu 2026): dashboard manajemen — sidebar admin dua seksi (PEMANTAUAN/KONTEN), Ringkasan (5 angka + grafik SVG 28 hari + kesehatan konten), tabel Karyawan (status prioritas, panah tren 14h-vs-14h, CSV) + detail per-orang (kalender 56 hari, skill, riwayat), antrean Laporan Soal (resolve optimistik). Landing admin → /admin/ringkasan. Suite api: 70 unit + 95 e2e.
- [x] **Speaking Drill SELESAI** (1 Sep 2026): tipe soal `UCAPAN` + skill `SPEAKING` — rekam via MediaRecorder (webm, fallback m4a iOS) → POST /session/:id/speak (multipart) → simpan permanen di storage `speech/{session}/{item}/{ts}-{rand}.{ext}` → Groq STT `whisper-large-v3-turbo` (fetch, tanpa SDK) → transcript = attempt.answer → grading fuzzy word-recall (`wordOverlapRatio`, ambang `SPEAKING_MATCH_THRESHOLD`=70 di config). Consent UU PDP wajib (`User.voiceConsentAt`, checkbox onboarding; speak 403 tanpa consent, sekali-set permanen). Konten: importer + template terima `ucapan` (min 2 kata), editor admin UCAPAN. Suite api: 99 unit + 112 e2e. Plan: docs/superpowers/plans/2026-09-01-speaking-drill.md.
- [x] **Menu Berbicara SELESAI** (1 Sep 2026): sesi khusus `kind: 'SPEAKING'` — kartu "Latihan Berbicara" di Home (ikon Mic) → POST /session/speaking → `/session?speaking=1`; berisi item UCAPAN dari lesson level user yang **belum tuntas** (`lessonCompletionInternal`; 409 "Belum ada latihan berbicara baru untuk levelmu" bila habis). Sesi ini dihitung **sama seperti sesi biasa**: target harian, streak, XP, bonus sesi-lengkap/perfect (`answer.service` gate dilebarkan). Filter `kind: 'DAILY'` → `kind IN ('DAILY','SPEAKING')` di 10 titik (summary×2, streak×2, progress×1, monitoring×5); resume `getOrCreateToday` tetap DAILY-only supaya MULAI tak menimpa sesi speaking. Seed demo: UCAPAN tambahan di DC-101 & DC-103 (DASAR total 35 soal). Suite api: 99 unit + 118 e2e. Plan: docs/superpowers/plans/2026-09-01-speaking-drill.md.
- [ ] Todo kecil tersisa: label nilai sumbu-y grafik masih <text> di SVG stretched (pindahkan ke overlay HTML seperti x-label, ±3 baris di activity-chart.tsx)
- [ ] Checklist manual speaking (butuh browser + mik + `GROQ_API_KEY` di env): buat item UCAPAN via admin → ikut sesi → rekam → submit → feedback tampil transcript; consent checkbox wajib; iOS Safari pakai m4a; rekaman tersimpan di storage `speech/...`.
- [ ] Backlog hardening: ValidationPipe penuh, throttler /items/:id/report, freeze race di summary.service, isolasi DB test e2e, PWA/dark mode, keputusan spec: REPLAY dihitung untuk "butuh perhatian"?
- [ ] Backlog speaking: hapus-rekaman atas permintaan (UU PDP, admin manual; keputusan hard vs soft delete), urutan-kata scoring, filter admin tipe UCAPAN, TTS contoh ucapan, Tier 2 (feedback LLM) / Tier 3 (voice agent).

Catatan penting yang tidak boleh "dirapikan": `prisma` sengaja di dependencies (runtime butuh `migrate deploy` di container); belum pernah `docker build` di mesin ini (Docker tak terpasang) — build image pertama kali = verifikasi wajib sebelum deploy beneran.
