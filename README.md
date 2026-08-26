# Fluen — Workspace

Platform belajar bahasa Inggris harian untuk karyawan: sesi pendek bergaya game (feedback instan, XP, streak) untuk membentuk kebiasaan belajar, plus dashboard admin untuk mengelola konten dan memantau aktivitas.

Repo ini adalah **workspace/orchestration** — berisi dokumen produk, spesifikasi, design system, deliverable klien, dan konfigurasi infrastruktur. **Kode aplikasi hidup di dua repo terpisah:**

| Repo | Isi | Stack |
|---|---|---|
| [ep-api](https://github.com/daffapraramadhana/ep-api) | Backend — seluruh logika bisnis (auth, importer soal, engine sesi, grading, XP/streak) | NestJS · Prisma · PostgreSQL |
| [ep-web](https://github.com/daffapraramadhana/ep-web) | Frontend — app user (`/`) + dashboard admin (`/admin`) | Next.js · Tailwind |

## Struktur

```
english-app/                  ← repo ini
├── docs/
│   ├── superpowers/specs/    ← spesifikasi produk (fondasi, UI/UX)
│   ├── superpowers/plans/    ← rencana implementasi per fase
│   ├── superpowers/verifikasi/ ← hasil checklist verifikasi
│   └── design-system.md      ← token, komponen, motion, ikon (sumber kebenaran visual)
├── deliverables/             ← template soal xlsx + petunjuk pengisian (untuk tim konten)
├── infra/                    ← docker-compose produksi, Caddyfile, backup, runbook
└── apps/                     ← (gitignored) tempat clone ep-web & ep-api
```

## Setup pengembangan

```bash
git clone https://github.com/daffapraramadhana/ep-workflow english-app
cd english-app
git clone https://github.com/daffapraramadhana/ep-api apps/api
git clone https://github.com/daffapraramadhana/ep-web apps/web
```

Lalu ikuti README masing-masing repo aplikasi (butuh Node 20+ dan PostgreSQL lokal). Deploy produksi: lihat [infra/README.md](infra/README.md).

## Dokumen kunci

- [Spec fondasi](docs/superpowers/specs/2026-08-25-english-app-foundation-design.md) — model data, engine sesi, prinsip grading
- [Spec UI/UX](docs/superpowers/specs/2026-08-25-user-app-uiux-design.md) — layar, interaksi, state
- [Design system](docs/design-system.md) — wajib dibaca sebelum menyentuh UI
- [Template soal](deliverables/petunjuk-pengisian.md) — cara tim konten mengisi bank soal

## Status

- ✅ **Fase 1** — fondasi & admin: skema DB, auth + undangan, importer soal/karyawan, media, CRUD konten, deploy + backup
- ✅ **Fase 2** — engine sesi & app user: sesi harian 3 tipe soal + media, XP/streak/review, perayaan, perjalanan, progress, profil, layout desktop
- 🔜 **Fase 3** — dashboard manajemen (pemantauan aktivitas, tren per-orang, laporan soal, export CSV)
