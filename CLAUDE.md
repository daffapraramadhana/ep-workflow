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

Daily English Learning Platform untuk karyawan — Rilis 1: Rp 8 jt fixed, 40 hari kerja / 8 minggu, solo. Pilot 20–50 user. Konten (soal) dari tim klien via template spreadsheet + importer.

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
- [ ] Fase 3 (belum direncanakan): dashboard manajemen + CSV export (minggu 7 jadwal klien), hardening backlog (ValidationPipe penuh, throttler report, freeze race di summary, isolasi DB test, PWA/dark mode)

Catatan penting yang tidak boleh "dirapikan": `prisma` sengaja di dependencies (runtime butuh `migrate deploy` di container); belum pernah `docker build` di mesin ini (Docker tak terpasang) — build image pertama kali = verifikasi wajib sebelum deploy beneran.
