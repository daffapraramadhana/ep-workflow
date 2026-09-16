# Design System — Velora

**Status:** disetujui via mockup v2 (25 Agu 2026) · **Berlaku untuk:** app user (`apps/web` area `/`) dan admin dashboard (`/admin`)
**Referensi visual:** mockup interaktif di `.superpowers/brainstorm/*/content/user-app-mockup-v2.html` (buka file-nya langsung di browser bila server companion mati)

Arah: **playful-professional** — struktur dan interaksi bergaya game (chunky, bulat, feedback instan), kulit tetap pantas dipresentasikan ke manajemen. Kepribadian datang dari **maskot Velora, warna, gerak, dan bunyi**.

## Pembaruan learner — 14 September 2026

Arah terbaru: **simple, mature, character-led**. Ketentuan di bagian ini menggantikan chrome/nav dan hero learner lama di bawah; admin dan auth tetap memakai fondasi sebelumnya. Implementasi override ada di `apps/web/src/app/learner.css`, dibatasi `.learner-ui`.

- Beranda memiliki satu kartu belajar utama: materi berikutnya/sesi tertunda, satu CTA, maskot, dan target harian. Latihan berbicara serta percakapan AI menjadi pilihan sekunder.
- Maskot resmi ditampilkan tanpa bingkai berat. Warna karakter memberi kehangatan di atas latar netral `#f8f9fc`, ink `#25273b`, muted `#686c80`, dan garis `#e6e8ef`. Indigo tetap warna aksi; hijau hanya untuk keberhasilan.
- XP, streak, target, dan kalender menggunakan data API. Tidak menambahkan leaderboard, hadiah, atau progres rekaan. Setelah target tercapai, latihan tambahan bersifat opsional.
- Mobile (revisi 15 September 2026): kembali ke navigasi pill mengambang sebelumnya, label hanya pada tab aktif, dengan jarak safe-area dan target sentuh minimal 44px. Desktop tetap sidebar putih 216px, konten utama maksimal 700px; rail 260px mulai viewport 1200px.
- Animasi pill mobile: highlight bergeser dan segmen aktif melebar dalam 180ms ease-out, label fade 120ms, feedback tekan ikon 120ms. Lebar luar tetap agar navigasi tidak meloncat. State mengikuti pathname (termasuk Back), tanpa animasi geser halaman. Reduced motion menonaktifkan seluruh transisi ini.
- Revisi 15 September 2026: rail kanan hanya di Beranda. Perjalanan dan Profil memakai satu kolom terpusat; kalender streak dan total pencapaian tampil langsung di halaman Progress pada semua ukuran layar.
- Perjalanan dan Progress memakai `LearningCompanion`: maskot resmi, bubble pendamping, kartu lavender ringan, serta ringkasan data asli. Perjalanan menampilkan materi berikutnya dan daftar langkah berurutan per topik; status selesai/aktif/terkunci tetap mengikuti API. Progress memakai kartu kemampuan putih dengan bar indigo, label akurasi jawaban pertama, jumlah sampel, kalender mingguan, dan ringkasan percakapan. Data kosong tidak diganti persentase palsu. Angka XP, materi selesai, dan streak terbaik tampil satu kali di hero Progress.
- Identitas produk menjadi **Velora**; nama tampilan dan metadata memakai `src/lib/brand.ts`. Bentuk logo serta maskot dipertahankan. Nama repository, database, dan field `fluen_*` pada kontrak integrasi suara tetap kompatibel dengan konfigurasi lama.
- Onboarding memakai pilihan radio native, consent eksplisit, dan maskot pendamping. Selebrasi memakai ringkasan hasil nyata, confetti satu kali, serta penghormatan pada reduced motion.
- Fokus keyboard terlihat, target sentuh CTA minimal 52px, progres memakai elemen native, dan kondisi gagal/menunggu/kosong tetap menyediakan petunjuk yang jelas.

Acuan prinsip: [Duolingo home screen](https://blog.duolingo.com/new-duolingo-home-screen-design/) untuk satu langkah belajar yang jelas dan [brand imagery](https://design.duolingo.com/identity/imagery) untuk karakter yang mendukung pengalaman, bukan menyalin visual produk.

---

## 1. Tokens

Didefinisikan sebagai CSS variables di `globals.css`, dipetakan ke Tailwind via `@theme`. Satu sumber untuk kedua area app.

### Warna

```css
:root {
  /* Brand */
  --brand:       #4F46E5;  /* indigo — aksi utama, aksen */
  --brand-dark:  #3730A3;  /* border-bottom tombol, hover */
  --brand-soft:  #EEF2FF;  /* latar chip/seleksi */
  --navy:        #1E1B4B;  /* login & chrome desktop (sidebar) */
  --navy-2:      #312E81;  /* gradien login/chrome: navy → navy-2 → #4338CA */

  /* Semantik */
  --good:        #22C55E;  --good-dark: #15803D;  --good-soft: #F0FDF4;
  --bad:         #EF4444;  --bad-dark:  #B91C1C;  --bad-soft:  #FEF2F2;
  --warn:        #F59E0B;  /* streak, XP, perhatian */
  --warn-soft:   #FFFBEB;  --warn-border: #FDE68A;

  /* Netral */
  --ink:  #1F2937;  --muted: #6B7280;  --line: #E5E7EB;  --bg: #F8FAFC;

  /* Identitas per-skill (chip/aksen di latar terang) */
  --skill-vocabulary: #4F46E5;  /* indigo */
  --skill-grammar:    #0EA5E9;  /* sky   */
  --skill-listening:  #F59E0B;  /* amber */
  --skill-reading:    #EC4899;  /* pink  */
  /* Varian -deep: WAJIB untuk latar penuh-warna ber-teks putih (kontras ≥4.5:1, §7) */
  --skill-vocabulary-deep: #4F46E5;  /* 6.3:1 */
  --skill-grammar-deep:    #0369A1;  /* sky-700, ±5.9:1 */
  --skill-listening-deep:  #B45309;  /* amber-700, ±4.85:1 */
  --skill-reading-deep:    #BE185D;  /* pink-700, ±6.6:1 */
}
```

Aturan: warna semantik **tidak boleh** dipakai dekoratif (hijau hanya untuk benar/selesai, merah hanya untuk salah/bahaya). `--warn` amber punya dua peran sah: streak/XP dan status perhatian.

**Mode:** light only. Dark mode ditunda (`color-scheme: light` dipaksa di globals.css — jangan dihapus tanpa mendesain dark palette penuh).

### Tipografi

```
Font   : Nunito (Google Fonts) — weight 600 / 800 / 900; fallback system-ui
Body   : 14–16px · w600-700
Judul  : 19–24px · w900
Angka gamifikasi (XP, streak, %) : w900, selalu lebih besar dari label di sekitarnya
Label kecil (eyebrow) : 11px · w800 · uppercase · letter-spacing 1px · warna brand/muted
```

### Bentuk & elevasi

```
Radius : kartu 20-24px · tombol/input 12-16px · pill 999px · node path 50%
Border : kartu 1px var(--line); elemen interaktif 2px
Shadow : lembut & rendah — 0 1px 6px rgba(30,27,75,.04) untuk kartu;
         0 10px 26px rgba(30,27,75,.4) hanya untuk elemen mengambang (nav pill)
```

### Spacing

Skala 4px. Padding kartu 16-18px, padding layar 20px, jarak antar kartu 12-14px.

---

## 2. Komponen inti

### Tombol chunky (signature komponen — CTA utama di kedua app)

```css
.btn {
  font-weight: 900; font-size: 17px; letter-spacing: .5px;
  color: #fff; background: var(--brand);
  border-radius: 16px; padding: 15px;
  border-bottom: 4px solid var(--brand-dark);
  transition: all .06s;
}
.btn:active { transform: translateY(3px); border-bottom-width: 1px; }
```

Varian: `good` (hijau, konfirmasi/lanjut-setelah-benar), `danger` (merah), `ghost` (putih + border, aksi sekunder). **Efek tekan-turun wajib di semua varian** — inilah 20% usaha yang memberi 80% rasa "game".

### Kartu

Putih, radius 20-24, border tipis, shadow lembut. Struktur: eyebrow label → judul → meta → aksi. Meta default = satu baris teks muted dengan pemisah `·` (`.card-meta`); meta-chip berwarna hanya bila butuh penekanan khusus — aksen warna disimpan untuk aksi.

### Pill & chip

- **Stat pill hero** (Beranda terang): pill soft tanpa border, radius 999 — streak/XP latar `--warn-soft` (ikon amber + angka ink 13px w800), freeze latar sky-soft `#E0F2FE` (ikon sky-700).
- **Meta-chip** (di kartu): latar `--brand-soft` atau `--warn-soft`, radius 10, ikon + teks 12.5px w900.
- **Chip kata** (susun kalimat): seperti tombol mini — border 2px, border-bottom 4px, tekan-turun; saat terpasang di zona jawaban: tint brand.

### Progress

- **Tile target harian** (hero Beranda): kotak rounded 20 latar `--brand-soft`, angka besar `--brand-dark` + label `--brand` + bar tipis putih/`--brand` (teks = shade latarnya sendiri, bukan abu). Target tercapai → varian tint hijau (`--good-soft`/`--good-dark`).
- **Ring** (% skill, mini sidebar): SVG stroke-linecap round; ring % skill putih di baris skill, ring mini sidebar desktop amber di atas navy.
- **Segmen sesi**: satu segmen per soal (bukan bar kontinu), tinggi 12px, radius 6, terisi `--good` dengan easing spring.
- **Bar skill**: baris berwarna penuh per skill (warna dari token skill) + ikon di kiri + ring % putih di kanan.

### Feedback sheet (khusus app user)

Naik dari bawah (280ms, spring), menutupi area tombol. Latar `--good-soft`/`--bad-soft`, border-top 2.5px warna semantik. Isi: judul besar → penjelasan (dari kolom `explanation` soal) → tombol LANJUT sewarna.

### Navigasi

- **App user (mobile):** bottom nav mengambang — bar PUTIH radius 999, border 1px `--line`, shadow lembut, melayang 16px dari bawah. Item aktif = pill `--brand-soft` dengan ikon + label `--brand-dark`; item lain ikon `--muted` tanpa label. **Disembunyikan saat sesi berlangsung.** 4 item: Beranda · Perjalanan · Progress · Profil. Desktop: nav yang sama menjadi sidebar navy kiri (chrome gelap dipertahankan di desktop).
- **Admin:** sidebar putih klasik (sudah ada) — adopsi token warna/radius/font, TIDAK memakai nav mengambang.

### Path node (Perjalanan)

Lingkaran 64px (aktif: 78px + pulse ring), border-bottom 5px gelap (rasa 3D sama dengan tombol). Status: done (hijau + ✓) · now (brand + ▶ + pulse) · locked (abu + 🔒, tap → shake 300ms). Konektor antar node: batang 6×26px, hijau bila sudah dilewati. Header topic: pill penuh warna, sticky.

---

## 3. Gerak (motion)

| Kejadian | Durasi | Easing |
|---|---|---|
| Tombol ditekan | 60ms | linear |
| Feedback sheet naik | 280ms | cubic-bezier(.3,1.3,.5,1) — spring ringan |
| Segmen progress terisi | 500ms | cubic-bezier(.3,1.4,.5,1) |
| Ring target terisi | 1s | ease |
| Node pulse | 1.6s loop | ease |
| Shake (terkunci/invalid) | 300ms | keyframe ±5px |
| XP count-up | ~700ms | interval linear |
| Confetti | 2.6s | linear fall + rotate |

Aturan: gerak hanya untuk **umpan balik dan perayaan**, tidak pernah untuk dekorasi idle (kecuali pulse node aktif). Hormati `prefers-reduced-motion`: matikan confetti, pulse, dan count-up (tampilkan nilai akhir langsung).

## 4. Bunyi (khusus app user)

WebAudio sintesis (tanpa file aset): benar = ding dua nada (660→880Hz, 300ms) · salah = nada rendah lembut (220Hz square, 250ms) · sesi selesai = arpeggio C-E-G-C. Volume kecil (gain ≤ .15).

Aturan: **aktif default**, tombol mute selalu terlihat di header sesi, pilihan disimpan (localStorage + kolom preferensi user). Tidak ada bunyi di luar sesi. Admin app: tanpa bunyi sama sekali.

## 5. Logo & ikon

### Maskot

Maskot Velora adalah buku terbuka 3D bertoga emas dengan dua sayap gelembung percakapan. Ia berperan sebagai pendamping belajar, bukan kontrol UI: tampil pada sapaan Beranda, perkenalan onboarding, serta momen perayaan/empty state yang relevan. Jangan memakai maskot sebagai ikon tombol, status, atau menggantikan ikon Lucide.

Sumber aset resmi: `public/mascot/velora-mascot.webp`, selalu dipanggil melalui `src/components/mascot.tsx`. Gaya aset turunan wajib tetap 3D lembut, pencahayaan studio hangat dari kiri-atas, dan palet logo. Gunakan latar transparan, jangan menambah teks ke dalam gambar, jangan meregangkan proporsi, dan jangan mencampur pose dari keluarga ilustrasi lain.

### Logo (brand mark)

**Velora** — toga + buku terbuka + dua gelembung percakapan. Warna mark berdiri sendiri, di luar palet token: emas `#CBA62D`/`#C09A22`, hijau `#7CAB4E`, oranye `#DD5B21`, teal `#1D6A8C`, ungu `#7B3F9D`.

Garis putih antar bentuk adalah **bagian dari mark**, bukan latar — jadi logo selalu berdiri di atas permukaan terang. Di atas navy (sidebar desktop) wajib memakai tile putih radius 11–12; teal & ungu terlalu gelap untuk berdiri langsung di sana.

Sumber: `src/components/logo.tsx` (komponen React) dan `src/app/icon.svg` (favicon, versi dengan latar putih membulat) — **duplikat yang harus diubah bersamaan**. Setelah mengubah `icon.svg`, regenerate `favicon.ico` (16/32/48) + `apple-icon.png` (180) dengan sharp; lihat `apps/web/README.md`.

### Ikon UI

**Library: [Lucide](https://lucide.dev) (`lucide-react`).** Satu library untuk kedua app — jangan campur dengan library lain.

```tsx
import { Home, Map, ChartColumn, User, Flame, Star, Snowflake,
         BookOpen, Pencil, Headphones, FileText, Clock, X, Volume2, VolumeX,
         Check, Lock, Play, AlarmClock, Upload, Users, Table2, LogOut } from 'lucide-react';
// Default: size={20} strokeWidth={2.25}  ← stroke tebal = selaras gaya chunky
```

Pemetaan tetap (konsisten di seluruh produk):

| Konsep | Ikon | | Konsep | Ikon |
|---|---|---|---|---|
| Beranda | `Home` | | Streak | `Flame` (amber) |
| Perjalanan | `Map` | | XP | `Star` (amber) |
| Progress | `ChartColumn` | | Freeze token | `Snowflake` (sky) |
| Profil | `User` | | Review due | `AlarmClock` |
| Vocabulary | `BookOpen` | | Grammar | `Pencil` |
| Listening | `Headphones` | | Reading | `FileText` |
| Selesai | `Check` | | Terkunci | `Lock` |
| Mulai/lanjut | `Play` | | Mute | `Volume2`/`VolumeX` |

Emoji di mockup (🔥⭐🧊🎉) boleh dipertahankan **hanya** untuk momen perayaan & kalender streak; elemen UI struktural memakai Lucide.

---

## 6. Penerapan di Admin Dashboard (mimic guide)

Admin **mengadopsi fondasi, bukan teatrikalnya**:

| Diadopsi | Tidak diadopsi |
|---|---|
| Semua token warna, radius, font Nunito, spacing | Bottom nav mengambang |
| Tombol chunky untuk CTA utama (Import, Simpan, Terbitkan) | Bunyi & confetti |
| Kartu + eyebrow label + meta-chip | Hero typographic Beranda (admin cukup heading halaman biasa) |
| Pill status: DRAFT abu · LIVE hijau-soft · RETIRED merah-soft | Feedback sheet (admin pakai inline alert biasa) |
| Ikon Lucide, stroke 2.25 | Path node |
| Baris tabel: hover `--brand-soft`, radius pada container | |

Prioritas retrofit admin (murah → mahal): (1) font + token warna + radius, (2) tombol chunky di CTA, (3) pill status di tabel soal, (4) stat cards di halaman ringkasan. Cukup untuk terasa satu produk.

## 7. Aksesibilitas

- Kontras teks ≥ 4.5:1 (teks putih di brand/navy/good/bad lolos; **jangan** teks putih di amber — pakai `#B45309` di latar `--warn-soft`).
- Status tidak boleh dikomunikasikan oleh warna saja: benar/salah selalu disertai ikon (✓/✕) + teks.
- Target sentuh minimal 44×44px (node path, chip, opsi sudah memenuhi).
- `prefers-reduced-motion` dihormati (lihat §3); mute bunyi tersedia permanen.
- Fokus keyboard: ring fokus 2px `--brand` offset 2px pada semua elemen interaktif.
