# Aksi — mulai di sini

- UI/FieldActionsFeature.swift: pintu masuk fitur, menerima fieldID dan isDemo.
- UI/Components/FieldActionCard.swift: tampilan rekomendasi tindakan dan `FieldActionPlantStrip` untuk sebaran tanaman ringkas.
- Domain/FieldActionContent.swift: isi rekomendasi, `FieldActionFocus`, dan indikator tanaman yang dibutuhkan UI.
- Data/FieldActionFixtures.swift: contoh drainase dan keadaan belum tersedia.

Saat ini belum ada diagnosis, backend, atau pencatatan tindakan selesai.
fieldID disiapkan untuk mengambil rekomendasi per kebun.

Untuk implementasi nyata:
1. Tambahkan model rekomendasi ber-ID, prioritas, lokasi baris/mulsa, dan status di Domain fitur.
2. Tambahkan protokol penyedia rekomendasi di Domain; implementasinya di Data.
3. Buat Presentation/FieldActionsViewModel.swift untuk loading/error dan aksi pengguna.
4. Hubungkan ViewModel melalui FieldActionsFeature dengan dependency injection.
5. Uji pergantian kebun, data kosong, kegagalan jaringan, dan status selesai.

Tampilan menerima data lewat content; jangan menaruh hasil diagnosis hard-coded di UI.
`FieldActionFocus` berisi judul, baris, area/sisi, indikator tanaman, dan label aksi.
Ia sengaja tidak memakai koordinat peta atau mengubah model kebun; layanan rekomendasi
nanti cukup mengisi kontrak ini. `onAction` pada kartu disediakan untuk navigasi saat
alur tindakan nyata sudah dibuat.

Warna indikator menggunakan `PlantHealthPalette` yang sama dengan heatmap. Nilai `ndre`
menentukan warna; `needsAttention` tetap menjadi status rekomendasi untuk judul dan aksesibilitas.
Model fitur tetap di folder ini; pindahkan ke Domain pusat hanya jika benar-benar
dipakai lintas fitur. Perubahan kontrak bersama dibahas dengan anggota tim lain.
