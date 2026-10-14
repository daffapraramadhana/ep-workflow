# Checklist manual — Menu Modul (Okt 2026)

Butuh: api + web jalan, DB sudah `seed:complaints` + `seed:module-complaints`, 1 akun user Menengah baru, 1 admin.

## User (mobile 375px & desktop ≥1024px)
- [ ] Nav 5 tab; tab Modul aktif berlabel; pill tidak terpotong di 375px.
- [ ] /modules: "Cocok untukmu · Menengah" berisi Making & Handling Complaints; modul level lain di "Modul lainnya".
- [ ] Halaman modul: 11 bab, Bab 1 "Berikutnya", CTA "MULAI BAB 1".
- [ ] Pembaca Bab 4: kartu frasa + 🔊 bersuara (Chrome & iOS Safari), dialog kiri/kanan, tip, pager.
- [ ] Bab 3: tabel terbaca tanpa geser horizontal halaman.
- [ ] Kuis Bab 1 → sesi → perayaan → kembali ke halaman modul; Bab 1 ✓ + akurasi; target harian Beranda +1; streak hidup.
- [ ] ✕ di tengah kuis → halaman modul; buka kuis lagi → melanjutkan soal yang sama.
- [ ] Ulangi kuis Bab 1 → label "ULANGI KUIS", XP tanpa bonus, target tidak bertambah.
- [ ] Beranda: kartu "Lanjutkan modul · Bab 2 berikutnya".
- [ ] Perjalanan Menengah tidak lagi memuat CMP-201..211.
- [ ] URL modul DRAFT / bab tak ada → kartu "tidak ditemukan" dengan tombol kembali.

## Admin
- [ ] Sidebar KONTEN: Modul paling atas.
- [ ] Buat modul, ubah metadata & cover, terbitkan/tarik/pensiunkan.
- [ ] Editor: error bernomor baris muncul < 1 dtk, Simpan terkunci saat error, pratinjau = tampilan user.
- [ ] Buat kuis → lesson MOD-… DRAFT → tambah soal → terbitkan lesson → bab tampil "berkuis" di user.
- [ ] Soal & Lesson: badge "Kuis modul: … · Bab n".
