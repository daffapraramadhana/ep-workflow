# Checklist manual — Satu Perjalanan (Okt 2026)

Butuh: api + web dari branch `feat/satu-perjalanan`, migrasi `20261023090000_satu_perjalanan` sudah diterapkan, browser desktop + lebar 375px.

## Perjalanan
- [ ] `/journey` user DASAR: unit topik ("Unit 01") lalu unit modul EFTL ("Unit 0N · Modul") dengan bab bernomor "Bab N".
- [ ] Header "X dari N langkah selesai" — bab bacaan (bila ada) tidak ikut dihitung dan tidak pernah terkunci.
- [ ] User MENENGAH: unit "Making & Handling Complaints" ada di **akhir** (setelah Workplace Communication, Guest Complaint Handling, Explaining Tourist Attractions).
- [ ] Tap bab `now` / bab selesai → halaman bab `/modules/{slug}/{order}`; tap langkah terkunci → toast.
- [ ] Lebar 375px: tanpa scroll horizontal.

## Beranda
- [ ] Hanya satu kartu lanjut; kartu "Lanjutkan modul" tidak ada.
- [ ] Bila langkah berikutnya bab modul: hero "Bab N · {judul}", deskripsi "Unit N · {modul}. Baca materinya dulu, lalu kerjakan kuis bab.", tombol → halaman bab.
- [ ] Mulai kuis bab, kembali ke Beranda → "Lanjutkan sesimu" dengan judul bab; tombol kembali ke kuis yang sama.

## Data staging/produksi (setelah deploy)
- [ ] Karyawan MENENGAH yang sudah mengerjakan EFTL 3/5 tidak ditarik mundur: langkah berikutnya sama seperti sebelum deploy, langkah EFTL yang selesai tetap ✓.
- [ ] Karyawan yang dulu mengerjakan bab Complaints lewat menu Modul melihat unit Complaints sebagian selesai.
- [ ] Admin → detail modul: toggle "Tampilkan kuis di Perjalanan" sudah tidak ada; Simpan tetap berhasil.
- [ ] Dashboard Ringkasan/Karyawan: angka "materi selesai" MENENGAH bergeser (lesson Complaints kini dihitung) — disengaja.
