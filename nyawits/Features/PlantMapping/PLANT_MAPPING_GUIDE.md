# Paket Heatmap + Kamera

Folder ini adalah area kerja pemetaan tanaman: mengambil foto, menampilkan titik
tanaman/NDRE, dan membuka detail hasil pengambilan.

## Pilih file sesuai perubahan

| Mau mengubah | Buka |
| --- | --- |
| Kartu heatmap, angka luas/baris/NDRE, tombol mulai foto | Heatmap/UI/FieldMappingCard.swift |
| Gambar batas, baris, titik tanaman, tap titik | Heatmap/UI/Components/FieldOverviewMap.swift |
| Warna NDRE dan legenda | Heatmap/UI/Components/NDREPalette.swift |
| Proyeksi koordinat menjadi posisi gambar | Heatmap/Presentation/FieldOverviewGeometry.swift |
| Susunan layar kamera, navigasi, lifecycle | Capture/UI/PlantCaptureView.swift |
| Tombol foto, lewati, undo, pemilihan sisi | Capture/UI/Components/CaptureControls.swift |
| Bingkai panduan foto | Capture/UI/Components/CaptureFramingGuide.swift |
| Indikator tracking/GPS/kestabilan | Capture/UI/Components/CaptureStatusBar.swift |
| Proses capture, sesi AR, progres, penentuan posisi | Capture/Presentation/PlantCaptureViewModel.swift |
| Tampilan sesi ARKit dalam SwiftUI | Capture/Camera/ARCameraPreview.swift |
| Daftar hasil tanaman | Plants/UI/FieldPlantListView.swift |
| Foto, NDRE dan metadata satu tanaman | Plants/UI/PlantObservationDetailView.swift |

## Alur

Home menampilkan FieldMappingCard → tombol melanjutkan capture diteruskan melalui
closure onContinue → Home membuka PlantCaptureView → PlantCaptureViewModel
menyimpan progres melalui FieldMappingStore → store menerbitkan data baru →
FieldMappingCard menggambar ulang heatmap.

Mengetuk titik membuka PlantObservationDetailView. Tombol jelajahi/detail membuka
FieldPlantListView. Demo menampilkan data simulasi, bukan pengukuran NDRE nyata.
Riwayat pemetaan di Home juga menggunakan renderer heatmap yang sama.

## File bersama yang berhubungan

- Domain/Models/PlantMappingModels.swift: MappedField, PlantObservation, MappedRow.
- Domain/Services/PlantSpatialReference.swift: estimasi posisi tanaman.
- Application/FieldMappingStore.swift: simpan progres, seleksi, edit, riwayat.
- Domain/Repositories/FieldRepository.swift: kontrak penyimpanan.
- Data/Repositories/LocalFieldRepository.swift: JSON dan file foto.
- Shared/PreviewData/NDREDemoFactory.swift: data heatmap simulasi.

Path di daftar ini relatif terhadap folder nyawits, bukan PlantMapping.
Diskusikan perubahan model tersimpan dengan tim agar JSON lama tetap terbaca.
UI tidak menulis JSON atau mengubah format foto langsung.

## Cara kerja tanpa mengganggu fitur teman

Untuk edit tampilan heatmap/kamera, cukup bekerja di folder ini. Pemupukan berada
di Features/Fertilization, Aksi di Features/FieldActions.
Home hanya perlu berubah jika kamu mengganti kontrak FieldMappingCard atau
PlantCaptureView. Nama tipe dan callback lama dipertahankan pada pemisahan ini.

Untuk menambahkan pengukuran NDRE asli, buat kontrak pengukuran dan adapter sensor
terlebih dahulu. Kamera RGB saat ini tidak otomatis menghasilkan nilai NDRE aktual.

## Checklist setelah perubahan

1. Build scheme nyawits.
2. Buka demo; tap titik; buka daftar/detail tanaman.
3. Pada iPhone, mulai/lanjutkan foto, ganti baris/sisi, undo/lewati, simpan.
4. Buka ulang kebun dan cek progres serta titiknya.
5. Bila mengubah penyimpanan, jalankan scripts/test-architecture.sh dari root repo.

Build saja belum memverifikasi ARKit/GPS. Gunakan perangkat untuk langkah kamera.
