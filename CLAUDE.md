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

- [x] Spec fondasi — menunggu review user
- [ ] Spec UI/UX (terpisah, setelah fondasi disetujui)
- [ ] Rencana implementasi (via writing-plans)
- [ ] Pembuatan repo apps/web & apps/api (minggu 1 implementasi)
