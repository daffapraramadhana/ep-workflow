# Design System — Daily English Learning Platform

**Status:** disetujui via mockup v2 (25 Agu 2026) · **Berlaku untuk:** app user (`apps/web` area `/`) dan admin dashboard (`/admin`)
**Referensi visual:** mockup interaktif di `.superpowers/brainstorm/*/content/user-app-mockup-v2.html` (buka file-nya langsung di browser bila server companion mati)

Arah: **playful-professional** — struktur dan interaksi bergaya game (chunky, bulat, feedback instan), kulit tetap pantas dipresentasikan ke manajemen. Tanpa maskot, tanpa ilustrasi karakter; kepribadian datang dari **warna, gerak, dan bunyi**.

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
  --navy:        #1E1B4B;  /* hero gelap, nav mengambang */
  --navy-2:      #312E81;  /* gradien hero: navy → navy-2 → #4338CA */

  /* Semantik */
  --good:        #22C55E;  --good-dark: #15803D;  --good-soft: #F0FDF4;
  --bad:         #EF4444;  --bad-dark:  #B91C1C;  --bad-soft:  #FEF2F2;
  --warn:        #F59E0B;  /* streak, XP, perhatian */
  --warn-soft:   #FFFBEB;  --warn-border: #FDE68A;

  /* Netral */
  --ink:  #1F2937;  --muted: #6B7280;  --line: #E5E7EB;  --bg: #F8FAFC;

  /* Identitas per-skill (progress, ikon skill) */
  --skill-vocabulary: #4F46E5;  /* indigo */
  --skill-grammar:    #0EA5E9;  /* sky   */
  --skill-listening:  #F59E0B;  /* amber */
  --skill-reading:    #EC4899;  /* pink  */
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
Border : kartu 1.5px var(--line); elemen interaktif 2px
Shadow : lembut & rendah — 0 2px 10px rgba(30,27,75,.05) untuk kartu;
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

Putih, radius 20-24, border tipis, shadow lembut. Struktur: eyebrow label → judul → meta-chips → aksi.

### Pill & chip

- **Stat pill** (hero gelap): latar `rgba(255,255,255,.12)`, border `rgba(255,255,255,.16)`, radius 999. Varian `hot` (streak): tint amber.
- **Meta-chip** (di kartu): latar `--brand-soft` atau `--warn-soft`, radius 10, ikon + teks 12.5px w900.
- **Chip kata** (susun kalimat): seperti tombol mini — border 2px, border-bottom 4px, tekan-turun; saat terpasang di zona jawaban: tint brand.

### Progress

- **Ring** (target harian, % skill): SVG stroke-linecap round; ring target di hero memakai stroke amber `#FBBF24` di atas track `rgba(255,255,255,.18)`.
- **Segmen sesi**: satu segmen per soal (bukan bar kontinu), tinggi 12px, radius 6, terisi `--good` dengan easing spring.
- **Bar skill**: baris berwarna penuh per skill (warna dari token skill) + ikon di kiri + ring % putih di kanan.

### Feedback sheet (khusus app user)

Naik dari bawah (280ms, spring), menutupi area tombol. Latar `--good-soft`/`--bad-soft`, border-top 2.5px warna semantik. Isi: judul besar → penjelasan (dari kolom `explanation` soal) → tombol LANJUT sewarna.

### Navigasi

- **App user:** bottom nav mengambang — pill navy, radius 999, melayang 16px dari bawah, ikon + label 8.5px; item aktif = lingkaran brand. **Disembunyikan saat sesi berlangsung.** 4 item: Beranda · Perjalanan · Progress · Profil. Desktop: nav yang sama menjadi sidebar kiri.
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

## 5. Ikon

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
| Kartu + eyebrow label + meta-chip | Hero gelap penuh (cukup header putih dengan stat pill versi terang) |
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
