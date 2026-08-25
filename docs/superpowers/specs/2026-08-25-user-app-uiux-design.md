# User App UI/UX — Spec Desain (Fase 2)

**Tanggal:** 25 Agustus 2026 · **Status:** menunggu review
**Fondasi:** `2026-08-25-english-app-foundation-design.md` (engine, model data) — spec ini TIDAK mengubah keputusan di sana.
**Design system:** `docs/design-system.md` (tokens, komponen, motion, bunyi, ikon Lucide) — bagian dari spec ini by reference.
**Mockup acuan:** `.superpowers/brainstorm/*/content/user-app-mockup-v2.html` (interaktif; disetujui 25 Agu).

---

## 1. Keputusan yang sudah dikunci

| # | Keputusan | Pilihan |
|---|---|---|
| 1 | Engagement kit | Semua wajib: feedback sheet hijau/merah, chip kata (tap, bukan drag), perayaan XP count-up + confetti, bunyi WebAudio (default on, mute persisten) |
| 2 | Arah visual | Playful-professional: tanpa maskot/ilustrasi; kepribadian dari warna+gerak+bunyi |
| 3 | Peta belajar | Path 1 kolom per topic (bukan zigzag berilustrasi) |
| 4 | Navigasi | Bottom nav mengambang (mobile), jadi sidebar di desktop; hilang saat sesi |
| 5 | Yang DITOLAK sadar | Timer soal (tekanan waktu merusak habit), sistem hearts/lives (menghukum), leaderboard (di luar Rilis 1 + tidak valid dgn level pilih-sendiri), maskot |
| 6 | Ikon | Lucide `strokeWidth 2.25`; emoji hanya untuk perayaan & kalender streak |

## 2. Peta layar & navigasi

```
/            → redirect: !login → /login · login & !onboarded → /onboarding · else /home
/login, /invite/[token]   (sudah ada — restyle ke design system)
/onboarding  → 2 langkah, sekali seumur akun
/home        → Beranda
/journey     → Perjalanan (path)
/session     → Sesi (fullscreen, tanpa nav)
/progress    → Progress
/profile     → Profil & pengaturan
```

- `onboarded` = user punya `level` + `dailyTargetSessions` terisi (kolom sudah ada).
- Tab nav: Beranda `Home` · Perjalanan `Map` · Progress `ChartColumn` · Profil `User`.
- Desktop (≥1024px): konten kolom tengah max-w 480px (pengalaman tetap "app"), nav jadi sidebar kiri. Tidak ada layout desktop khusus yang berbeda — satu desain, dua penempatan nav.

## 3. Onboarding (2 langkah, < 60 detik)

1. **Pilih level** — 3 kartu besar (Dasar/Menengah/Mahir) dengan 1 kalimat deskripsi berbahasa manusia ("Baru mulai / percakapan sederhana" dst.) + catatan kecil "bisa diubah kapan pun di Profil". Tanpa istilah CEFR di permukaan.
2. **Target harian** — 2 kartu: Santai (1 sesi/hari) · Serius (2 sesi/hari), estimasi menit di tiap kartu. Default tersorot: Santai.

Simpan → langsung `/home`. Tidak ada tur/coach-mark: layar Beranda didesain cukup jelas tanpa itu.

## 4. Beranda

Struktur (atas→bawah), sesuai mockup v2:

1. **Hero gelap** (gradien navy→indigo, radius bawah 30): baris stat pill (`Flame` streak · `Star` XP total · `Snowflake` token freeze) → sapaan berdasarkan jam + satu kalimat motivasi kontekstual → ring target harian (amber, N/target) + pesan status.
2. **Kartu Lanjutkan Belajar**: eyebrow → judul lesson berikutnya → meta-chips (topic · ±menit dari jumlah soal · +XP) → tombol MULAI (chunky, satu-satunya CTA besar di layar).
3. **Kartu review** (hanya jika ada `review_queue` due): `AlarmClock` + "N soal menunggu diulang" — tap = mulai sesi juga (review sudah otomatis diselipkan engine).
4. **Mode habis-konten**: semua lesson level selesai → kartu MULAI berganti "Sesi Penguatan — perkuat yang lama" (perilaku engine §5.1 fondasi).

Pesan hero berdasar state: belum sesi hari ini / target tercapai ("Sampai jumpa besok ✅") / streak dalam bahaya kemarin diselamatkan freeze ("🧊 kemarin menyelamatkanmu — jaga hari ini").

## 5. Perjalanan (path)

- Per topic: header pill sticky penuh warna (`--brand`, topic ke-2 `--skill-grammar` sky, siklus 4 warna skill) + "n/total".
- Node per lesson (urut kolom `urutan`): done (hijau ✓, sub-teks "Selesai · akurasi%") · now (78px, pulse, ▶) · locked (abu 🔒; tap → shake + toast "Selesaikan lesson sebelumnya dulu").
- Tap node done → **sesi ulangan lesson itu** (XP tarif percobaan-ulang; endpoint sesi menerima `lessonId` opsional).
- Data: `GET /journey` → `[{topic, lessons:[{id,judul,urutan,status(user),akurasi}]}]` — endpoint baru ringan, read-only.

## 6. Sesi — anatomi lengkap

**Header:** ✕ kiri (keluar; sesi beku, tanpa dialog konfirmasi — kembali kapan pun melanjutkan) · **segmen progress** (1 segmen per soal, terisi hijau saat dijawab benar-final) · mute kanan.

**Kerangka soal:** eyebrow tipe soal → media (jika ada) → prompt → area jawab → spacer → tombol PERIKSA (disabled sampai ada jawaban).

### Per tipe

- **Pilihan ganda:** opsi ≤ 12 karakter semua → grid 2 kolom; selain itu → daftar 1 kolom. Pilih = tint brand; PERIKSA → benar: opsi hijau; salah: opsi merah + opsi benar ikut ditandai hijau.
- **Isian:** prompt dengan `___` dirender sebagai kotak input inline (auto-width, min 80px). Keyboard "Enter" = PERIKSA. Penilaian case/space-insensitive terhadap `accepted_answers` (di BE, sudah ada).
- **Susun kalimat:** zona jawaban (garis bawah) + bank chip teracak. Tap chip → pindah ke zona (chip asal jadi ghost); tap chip di zona → kembali. PERIKSA aktif saat semua chip terpasang.

### Lapisan media (menempel ke tipe apa pun)

- **Audio:** kartu player besar di atas prompt — tombol play bulat 56px + waveform statis dekoratif; bisa diputar ulang tanpa batas; auto-play sekali saat soal muncul (kecuali mute).
- **Gambar:** di atas prompt, radius 16, max-height 200px.
- **Passage:** kartu bacaan ber-scroll sendiri (max-height 40vh) di atas prompt.

### Alur jawab (dari fondasi, kini dengan UI)

Jawab → **feedback sheet** naik (280ms): benar = hijau + "Benar!" + explanation singkat; salah = merah + "Belum tepat" + explanation + jawaban benar. LANJUT → soal berikutnya. Soal salah kembali di akhir sesi (segmennya baru terisi saat benar). `attempt` dicatat per jawaban (BE, sudah ada).

### Perayaan (`/session/done`)

Confetti + 🎉 → "Kerja bagus!" → kartu XP (count-up) + kartu Akurasi (percobaan-pertama) → baris streak ("Streak jadi N hari!" — hanya jika sesi ini yang memenuhi target) → LANJUT ke Beranda (ring terisi animasi, pill streak ter-update). Milestone streak (7/30/100): confetti lebih lebat + copy khusus.

## 7. Progress

1. **4 baris skill berwarna penuh** (token warna skill + ikon Lucide + "n soal dijawab" + ring % akurasi percobaan-pertama). Skill tanpa data → baris abu "belum ada data". **Tanpa Speaking** (keputusan fondasi).
2. **Kartu Minggu Ini**: 7 hari, 🔥 aktif · 🧊 diselamatkan freeze · titik kosong; + keterangan freeze.
3. **Kartu ringkas**: total lesson selesai · total XP · streak terpanjang.

## 8. Profil

Nama & email (read-only) · ubah level (dialog konfirmasi: "Progress lesson level lama tetap tersimpan") · ubah target harian · toggle bunyi · tombol Keluar. Di bawah: versi app. Tanpa foto profil (YAGNI).

## 9. State sistem & error

- **Loading:** skeleton (kartu abu berdenyut) untuk Beranda/Perjalanan/Progress; sesi memuat semua soal di awal (satu fetch) — spinner satu kali.
- **Koneksi putus saat menjawab:** jawaban dikirim per-soal; gagal → sheet tetap muncul dari penilaian lokal? **TIDAK** — penilaian selalu di BE (aturan fondasi). Gagal kirim → toast "Koneksi terputus" + tombol coba lagi di tempat PERIKSA; jawaban user tidak hilang (state lokal). Maksimal kehilangan: 1 jawaban (sesuai fondasi §7).
- **Sesi kedaluwarsa lintas-hari:** sesi `berjalan` dari kemarin tetap dilanjutkan (keputusan fondasi: sesi beku); sesi baru dibuat setelah selesai.
- **404/error API:** halaman error ramah + tombol "Kembali ke Beranda".

## 10. Penilaian sisi-mana

Tegas, mengikat implementasi: **semua penilaian, XP, streak, review-queue dihitung BE.** FE hanya: merender hasil, animasi, dan validasi bentuk (mis. semua chip terpasang) — bukan kebenaran. Endpoint sesi (Fase 2 BE): `POST /session/today` (buat/lanjut) · `GET /session/:id` · `POST /session/:id/answer {itemId, answer}` → `{benar, explanation, jawabanBenar?, xp, selesai?, ringkasan?}`.

## 11. Aksesibilitas & kualitas

Per design-system §7 (kontras, bukan-warna-saja, 44px, `prefers-reduced-motion`, fokus keyboard). Tambahan: isian & chip bisa dioperasikan penuh via keyboard; audio player punya label ARIA; feedback sheet = `role="status"` agar terbaca screen reader.

## 12. Di luar cakupan spec ini

Dark mode · PWA/offline penuh · notifikasi/reminder (rilis lanjut) · animasi Lottie/ilustrasi · halaman lapor-soal tersendiri (tombol "Laporkan soal" kecil di feedback sheet → dialog 1 field, endpoint `item_report` sudah ada di skema; UI-nya masuk, halamannya tidak).

## 13. Dampak jadwal (cek kewarasan)

Minggu 3 (kerangka + Beranda + onboarding + nav) · Minggu 4 (sesi: 3 tipe + media + sheet) · sisipan minggu 5 (perayaan) & minggu 6 (Perjalanan + Progress + Profil, bersama XP/streak BE). Path & perayaan ±3 hari ekstra dari rencana semula — tertutup oleh: tanpa timer, tanpa hearts, tanpa dark mode, tanpa halaman lapor tersendiri. Layak, karena kit inilah nilai jual demo.
