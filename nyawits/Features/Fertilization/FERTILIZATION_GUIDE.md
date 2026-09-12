# Pemupukan — mulai di sini

- UI/FertilizationFeature.swift: pintu masuk fitur, menerima fieldID dan isDemo dari Home.
- UI/Components/FertilizationCard.swift: desain kartu, tanggal, dan detail jadwal.
- Domain/FertilizationContent.swift: kontrak data yang ditampilkan kartu.
- Data/FertilizationFixtures.swift: data simulasi; jangan dipakai sebagai keputusan aktual.

Saat ini fieldID sudah diteruskan tetapi belum dipakai mengambil data. Tidak ada
integrasi cuaca atau perhitungan boleh/tunda.

Untuk implementasi nyata:
1. Tambahkan model prakiraan dan status boleh/tunda/belum diketahui ke Domain fitur.
2. Definisikan protokol sumber prakiraan di Domain dan implementasi API di Data.
3. Buat Presentation/FertilizationViewModel.swift untuk loading, error, serta aturan
   pemilihan jadwal. Suntikkan sumber data agar bisa diuji tanpa jaringan.
4. Hubungkan ViewModel di FertilizationFeature. Muat ulang berdasarkan fieldID,
   batalkan request lama ketika kebun berganti.
5. Ubah kartu agar status tersedia ditentukan oleh data, bukan isSimulation.
   Saat ini tanggal hanya ditampilkan pada demo. isSimulation adalah label asal data,
   bukan pengganti status boleh/tunda.

Pertahankan keadaan belum tersedia untuk kebun asli sampai data nyata tersedia.
Jangan menyimpulkan boleh pupuk hanya karena API gagal atau tidak ada hujan terlapor.
Home hanya perlu diedit jika kontrak input fitur berubah.
