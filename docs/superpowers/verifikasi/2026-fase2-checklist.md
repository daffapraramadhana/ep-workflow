# Verifikasi Fase 2 — Session Engine & App User

Tanggal: 2026-08-25
Dijalankan: Task 16 (verifikasi lintas-alur + viewport mobile)

Akun uji: `verif.test.fase2@example.com` (invite via admin CSV) — level Menengah, target harian **Serius (2 sesi/hari)**.
Konten seed: `deliverables/template-soal-v1.xlsx` (BUS-01/Email Perkenalan 3 item, LIS-01/Sapaan di Telepon 1 item + audio_001.mp3, RD-01/Memo Kantor 1 item + passage) — semua item & lesson di-publish LIVE via admin API.

Legenda: ✓ sesuai ekspektasi · ✗ ada masalah (lihat catatan) · ⚠ concern besar (tidak diperbaiki diam-diam, lihat bagian Concern di akhir)

---

## 1. Onboarding → Beranda

- [x] 1a. ✓ Login via invite (set password) → redirect ke `/login` dengan copy "Akun aktif — silakan masuk"
- [x] 1b. ✓ Login → onboarding step 1 (level: Menengah dipilih) → step 2 (target harian: Serius/2 sesi dipilih)
- [x] 1c. ✓/✗ Beranda menampilkan angka nyata (streak 0, 0 XP, 0/2 sesi, freeze pill 1). **Ditemukan & diperbaiki**: `hero.tsx` `statusMessage()` hardcode "Satu sesi lagi..." untuk `sessionsCompletedToday===0` tanpa memperhitungkan `dailyTarget`. Dengan target Serius (2 sesi), pesan salah menyatakan tinggal 1 padahal streak butuh 2 sesi penuh (`streak.service.ts` — `met()` pakai `count >= target`, bukan `count >= 1`). Diperbaiki agar dinamis: "N sesi lagi..." saat N>1, tetap "Satu sesi lagi..." saat N=1.

## 2. Sesi hari-1 (ketiga tipe + audio, retry, celebration)

- [x] 2a. ✓ Sesi hari-1 (lesson BUS-01, target Serius) menampilkan pilihan_ganda, isian, susun_kalimat. Chip susun_kalimat terverifikasi **ter-shuffle** (`report will send the I tomorrow` bukan urutan asli). Listening (audio) diuji di lesson LIS-01 terpisah — lihat catatan di bawah.
- [x] 2b. ✓ Item "schedule" (pilihan_ganda) dijawab salah 2x (percobaan 1 & 2) → requeue ke akhir sesi tiap kali, baru diterima di percobaan ke-3. Item isian & susun_kalimat masing2 salah 1x → requeue → benar di retry. Perilaku sesuai ekspektasi §2b.
- [x] 2c. ✓/⚠ Perayaan menampilkan "Kerja bagus!", confetti, kartu XP=20, AKURASI=0% (akurasi 0% benar karena semua first-try sengaja salah). **Concern (tidak diperbaiki, lihat bagian Concern)**: kartu XP menampilkan `summary.xpSession` yang backend definisikan HANYA sebagai bonus penyelesaian sesi (`XP_SESSION_COMPLETE` + `XP_PERFECT_SESSION` jika perfect), TIDAK termasuk XP per-item (first-try/retry) yang diperoleh selama sesi itu. Total real yang masuk ke akun user setelah sesi ini = 26 XP (`GET /me/summary` xpTotal 0→26, dikonfirmasi psql), tapi kartu perayaan hanya menunjukkan 20. Pengguna melihat angka yang lebih kecil dari yang sebenarnya didapat.
- [x] 2d. ✓ Beranda ter-update: XP pill 26, ring 1/2, pesan "Tinggal 1 sesi lagi...", kartu lanjutkan belajar berpindah ke lesson berikutnya (Memo Kantor/RD-01) — next-lesson recommendation bekerja.

## 3. Simulasi lintas-hari (psql)

- [x] 3a. ✓ Memundurkan `ReviewQueue.dueDate` 3 item ke hari ini (psql) → `GET /me/summary.reviewsDue` naik 0→3 (Beranda punya kartu "N soal menunggu diulang", kode ada di `home/page.tsx:126-137`). Logika interleave review-ke-sesi (`session.service.ts` splice acak review ke `rows` saat `lesson` next masih ada) diverifikasi via pembacaan kode — path ini tidak tereksekusi penuh via UI karena akun uji sudah content-exhausted di kedua level nyata (Menengah selesai; Dasar hanya py LIS-01) sehingga sesi baru jatuh ke jalur "Sesi Penguatan" (reinforcement, semua item ber-source REVIEW tapi BUKAN dari review-due queue — pool terpisah `reinforcementItems()`). Tidak masalah bagi task ini, hanya dicatat sebagai keterbatasan cakupan.
- [x] 3b. ✓ Memundurkan 2 sesi (psql) ke tanggal 2026-08-23 (Minggu, dailyTarget diset 1 via Profil dulu) sehingga polanya: 23 Ags selesai → 24 Ags (Senin) bolong → 25 Ags (hari ini, Selasa) selesai. `GET /me/summary` → `streak: 3` (benar, freeze otomatis menutup hari bolong).
- [x] 3c. ✓ Kalender Progress ("Kalender streak" minggu ini) menampilkan 🧊 tepat di sel SEN (24 Ags, hari bolong) dan 🔥 di SEL (25 Ags/hari ini); legenda "🧊 = streak diselamatkan token pembeku" tampil. Streak utuh (3) dan "Streak terpanjang" = 3 cocok. **Lihat Concern #4** (race condition `freezeAvailableThisWeek`) ditemukan selama pengujian butir ini.

## 4. Journey

- [x] 4a. ✓ Node states benar: "Email Perkenalan" (BUS-01) dan "Memo Kantor" (RD-01) tampil checkmark hijau (selesai) dengan badge akurasi ("Selesai · 0%" dan "Selesai · 100%" — cocok ground truth first-try). Dikelompokkan per topic (BUSINESS ENGLISH 1/1, OFFICE ENGLISH 1/1).
- [x] 4b. ✓ Tap node done → dialog konfirmasi "Ulangi lesson ini? XP dihitung sebagai ulangan." → sesi replay BUS-01 berjalan penuh (3 tipe soal, semua benar first-try kali ini), chip susun_kalimat di-shuffle ULANG dengan seed berbeda dari sesi pertama (benar, seed = sessionId+itemId, sesi baru = seed baru). Perayaan tampil, akurasi 100%, **XP kartu = 0** — konsisten dengan Concern #1 (kartu hanya menampilkan bonus sesi, dan replay memang tidak dapat bonus `XP_SESSION_COMPLETE`/`PERFECT`), tapi tiap item replay tetap dapat `xpAwarded=XP_RETRY(2)` di backend (`firstTry=false` karena sudah pernah dijawab) — tidak tercermin di kartu, sama seperti Concern #1. Juga mengonfirmasi ulang **Concern #2**: layar perayaan replay ini tetap menampilkan "🔥 Streak jadi 3 hari!" walau streak tidak berubah — bug `streakChanged` ternyata muncul di SEMUA jenis penyelesaian sesi (bukan cuma sesi DAILY ekstra), karena `evaluateAfterSession` dipanggil tanpa syarat saat `sessionCompleted`.

## 5. Progress

- [x] 5a. ✓ Baris skill cocok ground truth psql: Vocabulary 3 soal/0% (3 first-try semua salah, sesuai skenario 2b), Listening 1 soal/100%, Reading 1 soal/100%, Grammar "Belum ada data" (tidak ada item grammar di seed).
- [x] 5b. ✓ Kalender cocok (lihat 3c).
- [x] 5c. ✓ Total XP=116 (cocok psql SUM Attempt.xpAwarded 26 + SUM Session.xpAwarded 90), Lesson selesai=2 (BUS-01+RD-01, di-scope ke level Menengah saat ini — LIS-01/Dasar tidak dihitung di sini, tampaknya by-design karena progress per-level), Streak terpanjang=3.

## 6. Profil

- [x] 6a. ✓ Ganti target harian (Serius→Santai) via Profil — PATCH langsung tanpa dialog konfirmasi (sesuai desain, beda dgn ganti level). Persisten setelah reload.
- [x] 6a-bonus. ✓ Ganti **level** (Menengah→Dasar→Menengah) — dialog konfirmasi "Ganti level? Progress lesson level lama tetap tersimpan" muncul & berfungsi; progress Menengah (BUS-01/RD-01 selesai) tetap tersimpan setelah pindah balik.
- [x] 6b. ✓ Toggle suara (aktif→dimatikan), ikon & label berubah, persisten setelah reload (localStorage + `PATCH /me soundOn`).
- [x] 6c. ✓ Logout (`KELUAR`) → redirect ke `/login`, token dihapus. Login lagi dgn kredensial sama → Beranda tampil state benar (streak 3, XP 122 = 116+6 XP retry dari replay, target 1/1 tercapai, kartu Sesi Penguatan) — sesi tidak "nyangkut", tidak perlu re-onboarding.

## 7. Viewport (375px & Desktop)

- [ ] 7a. Beranda — nav pill (mobile) vs sidebar (desktop), tanpa horizontal scroll
- [ ] 7b. Sesi — idem
- [ ] 7c. Journey — idem
- [ ] 7d. Progress — idem

---

## Temuan kecil yang diperbaiki

(diisi selama verifikasi)

## Concern besar (tidak diperbaiki)

1. **Kartu XP di layar perayaan tidak mencerminkan total XP sesi (celebrate.tsx + answer.service.ts).**
   `AnswerResult.summary.xpSession` (dikembalikan `session/answer.service.ts` baris ~254) didefinisikan HANYA sebagai bonus penyelesaian sesi (`XP_SESSION_COMPLETE` + `XP_PERFECT_SESSION` bila perfect), TIDAK termasuk XP per-item (first-try +10/retry +2) yang didapat selama sesi tsb. Dikonfirmasi 2x:
   - Sesi 1 (BUS-01, 0% first-try, semua retry benar): kartu tampil **20 XP**, tapi `xpTotal` di `/me/summary` naik 0→**26** (20 bonus + 3×2 retry).
   - Sesi 2 (RD-01, 1 soal, 100% first-try/perfect): kartu tampil **35 XP**, tapi `xpTotal` naik 26→**71** (delta **45** = 20+15 bonus + 10 first-try item).
   Pengguna secara konsisten melihat angka XP lebih kecil dari yang benar-benar masuk ke akunnya. Tidak diperbaiki karena `xpSession` adalah bagian dari tipe kontrak `AnswerResult` yang dipakai lintas T3/T4 (BE) dan T10-T12 (FE) — perlu keputusan desain (apakah kartu harus tampilkan total sesi atau backend perlu field baru) sebelum diubah.

2. **`evaluateAfterSession` (`streak.service.ts`) menandai `streakChanged: true` berulang kali untuk sesi ekstra di hari yang sama setelah target tercapai.**
   Diverifikasi dengan target Serius (2 sesi/hari): sesi ke-2 (yang menuntaskan target) benar menampilkan "🔥 Streak jadi 1 hari!" — tapi sesi ke-3 di hari yang sama (mis. "Sesi Penguatan" atau lesson level lain) **juga** menampilkan pesan streak yang sama, padahal streak tidak benar-benar berubah lagi. Akar masalah: `changed = withToday.streak > withoutToday.streak` membandingkan "hari ini dihitung" vs "hari ini dikecualikan total" — perbandingan ini benar untuk sesi PERTAMA yang menuntaskan target, tapi tetap `true` untuk setiap sesi berikutnya di hari yang sama karena `withoutToday` selalu mengecualikan seluruh hari ini (bukan sesi spesifik ini), jadi hasilnya identik tiap kali dipanggil ulang di hari itu selama target sudah pernah tercapai. Berdampak nyata pada pengguna dengan target ≥2 sesi/hari atau yang mengambil sesi tambahan (penguatan) — bukan cuma edge-case dari setup pengujian saya. Tidak diperbaiki karena menyentuh logika inti streak (T5) yang dipakai lintas beberapa endpoint (`/session/:id/answer`, `/me/summary`, progress).

3. **Database dev bersama sudah terpolusi data uji dari task-task sebelumnya (bukan disebabkan task ini) — sempat memicu bug nyata yang terlihat user.**
   Baseline sebelum task ini: 213 dari 214 user, dan 117+ lesson level DASAR (kode `P2C-DONE-*`, `P2C-NEXT-*`, `P2C-SUM-*`, `P2A-L1/L2/L3-*`) adalah fixture otomatis (kemungkinan dari e2e-spec yang jalan ke DB dev sungguhan, bukan DB test terisolasi/rollback). Beberapa punya `order=-1000/-999` sehingga SELALU muncul duluan di rekomendasi "Lanjutkan Belajar". Ini menyebabkan bug nyata yang saya temukan: saat user level DASAR (untuk uji tipe listening), Beranda merekomendasikan lesson sampah berjudul **"Selesai"** topik **"x"** alih-alih konten asli — bukan bug kode, murni akibat data kotor yang lolos ke rekomendasi. Saya TIDAK menghapus data ini (bukan milik task 16, berisiko mengganggu task/tes lain, volume besar) — hanya menaikkan sementara `order` LIS-01 (konten saya sendiri) untuk melewatinya saat menguji, lalu mengembalikannya (`901`) setelah selesai. Perlu keputusan tim: apakah e2e suite `apps/api/test/*.e2e-spec.ts` perlu diarahkan ke DB test terisolasi + teardown, dan/atau dijadwalkan pembersihan data `P2A-*`/`P2C-*` dari DB dev.

4. **Race condition di `summary.service.ts`: `freezeAvailableThisWeek` bisa salah tepat di momen freeze baru dipakai.**
   `SummaryService.get()` memanggil `this.streak.evaluate(userId)` (bisa lazily INSERT baris `StreakFreeze` saat pertama kali mendeteksi hari bolong terisolasi) BERSAMAAN (`Promise.all`) dengan query terpisah `streakFreeze.findUnique(...)` untuk field `freezeAvailableThisWeek`. Direproduksi: setelah memundurkan tanggal sesi via psql (pola hari-1 selesai / hari-2 bolong / hari-3=hari ini selesai), panggilan **pertama** ke `GET /me/summary` (yang men-trigger pembuatan freeze) mengembalikan `streak:3` (benar) tapi `freezeAvailableThisWeek:true` (salah — freeze minggu ini baru saja dipakai untuk menutup hari-2). Panggilan **kedua** (tanpa perubahan apa pun) mengembalikan `freezeAvailableThisWeek:false` yang benar, karena baris freeze sudah tersimpan sebelum query paralel jalan. Dampak: pill freeze di Beranda/Profil bisa sempat menampilkan "tersedia" padahal baru saja terpakai, sampai request berikutnya me-refresh. Tidak diperbaiki karena berpotensi ada pola `Promise.all` serupa di endpoint lain yang perlu diaudit bersamaan, bukan tambal satu titik saja.

---

## Addendum (26 Agu 2026 — pasca fix-wave final)

Status concern di atas setelah gelombang perbaikan review final:

1. ✅ **DIPERBAIKI** — `xpSession` kini = sum(attempt.xpAwarded sesi) + bonus (api `d961306`); kartu perayaan = delta xpTotal.
2. ✅ **DIPERBAIKI** — `streakChanged` di-gate `completedToday === dailyTarget` (api `d961306`); sesi ekstra di hari sama tidak memicu ulang pesan streak/milestone. Ada e2e regresi.
3. ✅ **DIBERSIHKAN** — 219 user + 144 lesson fixture dihapus (pattern-scoped, admin & akun verifikasi dipertahankan). Isolasi DB test → backlog Fase 3.
4. ⏳ **MASIH TERBUKA (minor)** — race `freezeAvailableThisWeek` di summary.service (self-corrects di request berikutnya); pola perbaikan sudah ada di progress.service, dijadwalkan Fase 3.

Bagian 7 (viewport 375px/desktop) belum dijalankan — verifikasi manual oleh pemilik proyek.
