# Infra runbook — English App (single VPS)

This directory is the whole production deploy: `docker-compose.prod.yml`
(db + api + web + caddy), `Caddyfile` (reverse proxy + automatic TLS),
and `backup.sh` (daily DB backup to S3-compatible object storage).

`apps/api` and `apps/web` are separate git repos checked out side by
side with this workspace repo (see the root `CLAUDE.md`); this repo
tracks only `infra/`.

```
english-app/
  infra/                 ← this directory (workspace repo)
  apps/api/               ← own repo, has Dockerfile
  apps/web/               ← own repo, has Dockerfile
```

## 1. Provisioning the VPS

- A Linux VPS with Docker Engine + the Docker Compose plugin installed
  (`docker compose version` should work — this is the v2 plugin, not
  the standalone `docker-compose` binary).
- DNS: `app.<DOMAIN>` and `api.<DOMAIN>` both pointing at the VPS's
  public IP (A/AAAA records). Caddy needs port 80 **and** 443 reachable
  from the internet to complete the ACME (Let's Encrypt) challenge.
- Clone the three repos onto the VPS in the layout shown above (or copy
  `apps/api`, `apps/web`, and this workspace's `infra/` however you
  prefer — the compose file only cares that `../apps/api` and
  `../apps/web` resolve relative to `infra/`).
- Create `/opt/english-app` (or wherever you place the checkout) and
  `/var/backups` (owned by whichever user runs cron/backup.sh).

## 2. Environment: `infra/.env.prod`

Not committed (secrets). Create it next to `docker-compose.prod.yml`:

```bash
cp .env.prod.example .env.prod   # if you keep a template; otherwise create by hand
chmod 600 .env.prod
```

Required variables:

| Variable | Used by | Notes |
|---|---|---|
| `DATABASE_URL` | api | `postgresql://app:<POSTGRES_PASSWORD>@db:5432/english_app` — host **must** be `db` (the compose service name), and the password must match `POSTGRES_PASSWORD` below. |
| `POSTGRES_PASSWORD` | db | Bootstraps the `app` Postgres role. **Not part of the app's own env contract** — added here because the official `postgres` image needs its own credential to initialize the database and there is no safe way to derive it from the opaque `DATABASE_URL` string inside a compose file. Keep it identical to the password embedded in `DATABASE_URL` above. |
| `JWT_SECRET` | api | Long random string. Rotating it invalidates all sessions (see §5). |
| `ADMIN_EMAIL` | api, caddy | Seeded admin login; also used as the Let's Encrypt account contact email in `Caddyfile`. |
| `ADMIN_PASSWORD` | api | Seeded admin login. |
| `STORAGE_DRIVER` | api | Set to `s3` in production. If left `local` (or unset), uploaded media is written under the api container's `/app/storage`, which is persisted via the `mediadata` named volume declared in `docker-compose.prod.yml` (see §3). |
| `S3_ENDPOINT` | api, backup.sh | e.g. `https://<accountid>.r2.cloudflarestorage.com` (Cloudflare R2) or any S3-compatible endpoint. |
| `S3_BUCKET` | api | Bucket for uploaded media. |
| `S3_ACCESS_KEY` | api, backup.sh | Mapped by `backup.sh` into `AWS_ACCESS_KEY_ID` for the `aws` CLI. |
| `S3_SECRET_KEY` | api, backup.sh | Mapped by `backup.sh` into `AWS_SECRET_ACCESS_KEY`. |
| `S3_PUBLIC_URL` | api | Public base URL media links are built from: `getUrl(name) = "${S3_PUBLIC_URL}/${name}"`. |
| `GROQ_API_KEY` | api | Speech-to-text (speaking drill, tipe soal `UCAPAN`). Wajib bila fitur speaking dipakai; tanpa ini endpoint `/session/:id/speak` gagal. |
| `WEB_ORIGIN` | api | `https://app.<DOMAIN>` — used for the API's CORS allow-list. |
| `DOMAIN` | web (build arg), caddy | Bare domain, e.g. `example.com`. Caddy serves `app.<DOMAIN>` and `api.<DOMAIN>`. |
| `BACKUP_BUCKET` | backup.sh | Bucket (can be the same as `S3_BUCKET` or separate) backups are pushed to, under `db/`. |

`aws` CLI: install it on the VPS host (used by `backup.sh`, run from
cron on the host, not inside a container) — e.g. `apt install awscli`
or the official `aws/install` bundle.

## 3. Deploy

```bash
cd /opt/english-app/infra
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --build
```

`--env-file .env.prod` is required on every invocation (build, up,
down, logs, exec, …) — Compose only auto-loads a file literally named
`.env`, and we deliberately named ours `.env.prod` to keep it visually
distinct from any dev `.env`.

The `api` container's entrypoint (`apps/api/docker-entrypoint.sh`) runs
`prisma migrate deploy` and then the seed script (`node
dist/prisma/seed.js`) before starting the server, so every deploy —
including the very first one — both applies pending migrations and
bootstraps the `Config` rows plus the `ADMIN_EMAIL`/`ADMIN_PASSWORD`
admin login automatically. The seed is idempotent (upserts), so running
it on every boot is safe; it also rotates the admin's password hash if
`ADMIN_PASSWORD` changed since the last deploy. `db` has a healthcheck
(`pg_isready`) and `api` waits for it (`condition: service_healthy`)
before starting.

Uploaded media (when `STORAGE_DRIVER=local`) persists across
`up -d --build` via the `mediadata` named volume mounted at
`/app/storage` in the `api` service (see §2).

**Verify after the first deploy**: confirm the seed actually ran by
logging in with `ADMIN_EMAIL`/`ADMIN_PASSWORD` against the live API —
e.g. `curl -X POST https://api.<DOMAIN>/auth/login -H 'Content-Type:
application/json' -d '{"email":"<ADMIN_EMAIL>","password":"<ADMIN_PASSWORD>"}'`
should return a 201 with an `accessToken` and `"role":"ADMIN"`. If it
403/401s, check `docker compose ... logs api` for errors from the seed
step before assuming the deploy itself failed.

Redeploy after a code change:

```bash
git -C ../apps/api pull   # or ../apps/web
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --build
```

Logs:

```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml logs -f api
```

## 4. Daily backup

`backup.sh`: `pg_dump` (run inside the `db` container via `docker
compose exec`) → `gzip` → `/var/backups/english-app-<date>.sql.gz` →
`aws s3 cp` to `s3://$BACKUP_BUCKET/db/` → deletes local `.sql.gz`
files older than 30 days.

Install on the VPS host once, as root or the deploy user:

```bash
chmod +x /opt/english-app/infra/backup.sh
crontab -e
# add:
0 2 * * * /opt/english-app/infra/backup.sh >> /var/log/english-app-backup.log 2>&1
```

This is an **OS-level cron job for infra backup only** — it is
separate from, and does not conflict with, the product rule "no
background jobs/cron in Release 1," which applies to application
logic (grading, XP, session engine), not to ops/infra scheduling.

### Restoring a backup (production, via docker compose)

```bash
gunzip -c /var/backups/english-app-2026-08-25.sql.gz | \
  docker compose --env-file .env.prod -f docker-compose.prod.yml exec -T db \
  psql -U app -d english_app
```

To restore into a **fresh/empty** database instead of overwriting the
live one (e.g. disaster recovery onto a new VPS): bring up just `db`,
create the target database, then pipe the dump in the same way,
substituting the target db name for `english_app`.

### Restoring a backup (manual/dev — no Docker on this machine)

Useful for local verification without docker-compose (used to test
this exact backup file locally on 2026-08-25 with Docker unavailable):

```bash
# Dump directly from a local Postgres instance instead of via
# `docker compose exec`:
export PGPASSWORD=app
pg_dump -h localhost -U app -d english_app | gzip > english-app-2026-08-25.sql.gz

# Restore into a throwaway database, verify, then drop it:
createdb -h localhost -U app english_app_restore_test
gunzip -c english-app-2026-08-25.sql.gz | \
  psql -h localhost -U app -d english_app_restore_test -v ON_ERROR_STOP=1

psql -h localhost -U app -d english_app_restore_test -tAc \
  "select count(*) from information_schema.tables where table_schema='public';"

dropdb -h localhost -U app english_app_restore_test
```

**This was run for real as part of Task 15** against the local dev
Postgres (`english_app`, 11 tables): dump succeeded, restore into
`english_app_restore_test` completed with `ON_ERROR_STOP=1` and no
errors, `information_schema.tables` count matched (11 = 11) between
source and restored database, and the scratch database was dropped
afterward. A backup that has never been restored isn't a backup — this
confirms the dump/gzip/restore path is sound end to end (the S3 upload
leg itself, `aws s3 cp` against a real R2/S3 bucket, was **not**
exercised in this environment — no bucket/credentials available here;
review that leg's success via the cron log / S3 bucket listing after
the first real production run).

## 5. Rotating `JWT_SECRET`

1. Generate a new secret (e.g. `openssl rand -base64 48`).
2. Update `JWT_SECRET` in `infra/.env.prod`.
3. Redeploy just the api service so it picks up the new value:
   ```bash
   docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --build api
   ```
4. All existing JWTs (issued with the old secret) stop verifying
   immediately — every logged-in user is signed out and must log in
   again. There's no dual-secret grace period in this design; rotate
   during a low-traffic window and expect a wave of re-logins.

## 5b. Audio TTS (Kokoro) — rilis pertama & pemeliharaan

Audio bahasa Inggris (listening, "Dengarkan contoh", 🔊 di bab modul) adalah
file MP3 yang dibuat server dengan Kokoro (spec
`docs/superpowers/specs/2026-10-16-audio-tts-design.md`). Model dipanggang ke
image saat `docker build` (`TTS_MODEL_DIR=/app/tts-models`), jadi runtime tidak
butuh internet. Image api kini `node:22-bookworm-slim` (bukan Alpine).

**Rilis pertama (anggap produksi sudah dipakai learner):**

1. Backup DB dulu (`./backup.sh`, lihat §4).
2. `docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --build api`
   — entrypoint menjalankan migrasi (`TtsClip`, `Item.ttsText`) dan seed config
   (`TTS_ENABLED=1`, `TTS_MAX_PARALLEL=1`, `TTS_IDLE_UNLOAD_MINUTES=10`).
3. Adopsi audio seeder lama (sekali saja):
   ```bash
   docker compose --env-file .env.prod -f docker-compose.prod.yml exec api node dist/src/tts/cli/adopt-seed-audio.js
   ```
   Harus berakhir `0 dipertahankan (gagal)`. Soal yang gagal tetap memakai file
   `.m4a` lamanya — tidak ada soal yang jadi bisu. Jalankan ulang aman.
4. Buat semua audio di muka:
   ```bash
   docker compose --env-file .env.prod -f docker-compose.prod.yml exec api node dist/src/tts/cli/backfill.js
   ```
   Harus berakhir `0 gagal`. (Lokal: 208 klip ±5 menit di Mac M-series; VPS
   bisa 2–4× lebih lambat.)
5. Pantau RAM: `docker stats` saat backfill — proses api naik ±450 MB selama
   model termuat, lalu turun lagi ±10 menit setelah sintesis terakhir.
   **Catat angka RSS nyata di sini setelah rilis pertama.**
   Perintah `exec … backfill.js` / `adopt-seed-audio.js` berjalan di proses
   Node **terpisah** yang memuat modelnya sendiri: selama CLI jalan, RAM bisa
   naik ±450 MB lagi di atas proses api.
6. Cek image: `docker compose … exec api ls node_modules/onnxruntime-node/bin/napi-v3/linux/x64`
   tidak boleh berisi `libonnxruntime_providers_cuda.so` (Dockerfile memasang
   `ONNXRUNTIME_NODE_INSTALL_CUDA=skip`). Catat ukuran image di sini.

**Rollback / saklar darurat:**

- Masalah CPU/RAM: set config `TTS_ENABLED=0` (tabel `Config`). Klip yang sudah
  jadi tetap diputar; frasa/contoh ucapan yang belum punya file jatuh ke suara
  browser. Berlaku ≤60 dtk (cache config). Catatan: soal listening yang klipnya
  **belum** pernah dibuat tidak punya cadangan suara browser (bisu) — jalankan
  backfill sebelum mematikan saklar bila memungkinkan.
- Kembali ke image lama **tanpa** kehilangan data learner: image lama tetap jalan
  dengan kolom `Item.ttsText` dan tabel `TtsClip` tambahan (diabaikan). Yang perlu
  dipulihkan hanya `mediaFile` soal yang diadopsi — file `.m4a` lama tidak dihapus
  adopsi. Jalankan di Postgres:
  ```sql
  UPDATE "Item" i
  SET "mediaFile" = lower(l.code) || '-' || lpad(i."order"::text, 2, '0') || '.m4a'
  FROM "Lesson" l
  WHERE l.id = i."lessonId"
    AND i."ttsText" IS NOT NULL AND i."mediaFile" IS NULL
    AND l.code IN ('DC-104','WC-204','PE-304','CMP-210','EFT-109');
  ```
  (Daftar kode = lesson seeder yang punya audio lama; cek dulu dengan `SELECT`
  yang sama. Soal yang `ttsText`-nya diisi admin sendiri tidak punya `.m4a` lama
  — jangan ikut di-update.)
- **Restore DB penuh dari backup langkah 1 hanya pilihan terakhir**: semua
  attempt, sesi, streak, dan XP sejak deploy ikut hilang — bertentangan dengan
  aturan fondasi "attempt dicatat selamanya".

**Kapan menjalankan backfill lagi:** setelah impor spreadsheet besar atau seed
modul baru. Tanpa backfill pun audio tetap dibuat saat pertama diputar (user
pertama menunggu ±1–3 dtk per kalimat). Bisa dibatasi:
`node dist/src/tts/cli/backfill.js --code EFT-2` (prefix kode lesson) atau
`--slug eftl-2` (prefix slug modul).

## 6. Known limitations / honest verification notes (Task 15)

- Docker is not installed in the environment this stack was authored
  in. Both Dockerfiles (`apps/api/Dockerfile`, `apps/web/Dockerfile`)
  and `docker-compose.prod.yml` were verified by careful inspection
  (stage-by-stage, matching each `COPY --from=` to what the previous
  stage actually produces) rather than an actual `docker build` /
  `docker compose up`. `hadolint` was also not available in this
  environment (`which hadolint` → not found), so no automated
  Dockerfile linting ran either — treat both Dockerfiles as
  inspection-reviewed, not build-verified, until the first real deploy.
- **Audio TTS (16 Okt 2026):** image api pindah ke `node:22-bookworm-slim` dan
  memanggang model Kokoro saat build — juga belum pernah di-`docker build`.
  Verifikasi wajib sebelum deploy: `docker build` api sukses (langkah
  `prefetch-model.js` mengunduh ±90 MB dari Hugging Face), lalu di container
  `GET /tts/<id>.mp3` → 200 `audio/mpeg`, dan ukur RSS saat/sesudah backfill.
  Di mesin dev sudah terbukti: `npm run build` + `prefetch-model.js` ke
  `TTS_MODEL_DIR` kosong → sukses (88 MB, 24 kHz).
- The S3 driver (`apps/api/src/storage/s3.storage.ts`) was verified by
  type-checking, and by a unit test on the driver-selection logic
  (`storage.module.spec.ts`); it was never exercised against a real S3
  / R2 bucket (none available here). The local driver's existing media
  e2e suite (`apps/api/test/media.e2e-spec.ts`) still passes unchanged.
  `GET /media/:name` now branches on the active driver
  (`MediaController#serve`, `apps/api/src/media/media.controller.ts`):
  local still serves the file straight off disk; S3 redirects (302) to
  `storage.getUrl(name)` instead of trying to read local disk. The
  redirect branch is unit-tested with a mocked `StorageService`
  (`apps/api/src/media/media.controller.spec.ts`) since there is no S3
  bucket to exercise it against for real here.
- The backup **dump/restore** path was tested for real against the
  local dev Postgres (see §4). The **S3 upload** leg of `backup.sh` was
  not — verify it on the first real production backup run.
