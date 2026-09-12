# Paket Heatmap + Kamera

Folder ini adalah area kerja pemetaan tanaman: mengambil foto, menampilkan titik
tanaman berwarna, dan membuka detail hasil pengambilan.

## Pilih file sesuai perubahan

| Mau mengubah | Buka |
| --- | --- |
| Kartu heatmap, angka luas/baris/skor, tombol mulai foto | Heatmap/UI/FieldMappingCard.swift |
| Gambar batas, baris, titik tanaman, tap titik | Heatmap/UI/Components/FieldOverviewMap.swift |
| Warna skor vigor dan legenda | Heatmap/UI/Components/VigorPalette.swift |
| Proyeksi koordinat menjadi posisi gambar | Heatmap/Presentation/FieldOverviewGeometry.swift |
| Susunan layar kamera, navigasi, lifecycle | Capture/UI/PlantCaptureView.swift |
| Tombol foto, lewati, undo, pemilihan sisi | Capture/UI/Components/CaptureControls.swift |
| Bingkai panduan foto | Capture/UI/Components/CaptureFramingGuide.swift |
| Indikator tracking/GPS/kestabilan | Capture/UI/Components/CaptureStatusBar.swift |
| Proses capture, sesi AR, progres, penentuan posisi | Capture/Presentation/PlantCaptureViewModel.swift |
| Tampilan sesi ARKit dalam SwiftUI | Capture/Camera/ARCameraPreview.swift |
| Daftar hasil tanaman | Plants/UI/FieldPlantListView.swift |
| Foto, skor lama dan metadata satu tanaman | Plants/UI/PlantObservationDetailView.swift |

## Alur

Home menampilkan FieldMappingCard → tombol melanjutkan capture diteruskan melalui
closure onContinue → Home membuka PlantCaptureView → PlantCaptureViewModel
menyimpan progres melalui FieldMappingStore → store menerbitkan data baru →
FieldMappingCard menggambar ulang heatmap.

Mengetuk titik membuka PlantObservationDetailView. Tombol jelajahi/detail membuka
FieldPlantListView. Demo menampilkan data simulasi, bukan hasil pengukuran.
Riwayat pemetaan di Home juga menggunakan renderer heatmap yang sama.

## File bersama yang berhubungan

- Domain/Models/PlantMappingModels.swift: MappedField, PlantObservation, MappedRow.
- Domain/Services/PlantSpatialReference.swift: estimasi posisi tanaman.
- Application/FieldMappingStore.swift: simpan progres, seleksi, edit, riwayat.
- Domain/Repositories/FieldRepository.swift: kontrak penyimpanan.
- Data/Repositories/LocalFieldRepository.swift: JSON dan file foto.
- Shared/PreviewData/VigorDemoFactory.swift: data heatmap simulasi.

Path di daftar ini relatif terhadap folder nyawits, bukan PlantMapping.
Diskusikan perubahan model tersimpan dengan tim agar JSON lama tetap terbaca.
UI tidak menulis JSON atau mengubah format foto langsung.

## Cara kerja tanpa mengganggu fitur teman

Untuk edit tampilan heatmap/kamera, cukup bekerja di folder ini. Pemupukan berada
di Features/Fertilization, Aksi di Features/FieldActions.
Home hanya perlu berubah jika kamu mengganti kontrak FieldMappingCard atau
PlantCaptureView. Nama tipe dan callback lama dipertahankan pada pemisahan ini.

Pengukuran sungguhan TIDAK tinggal di folder ini. Ia ada di Features/ScanSession:
tiga frame dari rig Raspberry Pi per petak, ROI manual, dan skor vigor yang baru
muncul setelah sesi ditutup. Kamera perangkat Apple tidak bisa memberi band
spektralnya -- IR-cut filter menempel permanen di tumpukan sensor.

## Checklist setelah perubahan

### Komponen heatmap per baris

- `Heatmap/UI/Components/FieldHeatmapRow.swift`: garis satu baris dan titik tanaman di kedua sisinya. Edit warna, ukuran titik, dan garis di sini. Preview tersedia di file yang sama.
- `Heatmap/UI/Components/FieldHeatmapRowStrip.swift`: versi lurus untuk kartu ringkas. Ia menampilkan urutan `plantSequence` dari satu baris dan satu sisi, tanpa memakai atau mengubah rotasi/geometri kebun. Preview tersedia di file yang sama.
- `Heatmap/UI/Components/FieldOverviewMap.swift`: menggabungkan baris, batas kebun, legenda, dan pemilihan titik.
- `visibleRowNumbers` memfilter tampilan saja, bukan isi `MappedField`. Nomor mengacu ke `MappedRow.number`, bukan indeks array. Hubungan tanaman tetap memakai `rowID`.

```swift
// Semua baris (perilaku default yang sudah ada)
FieldOverviewMap(field: field)

// Hanya baris 3
FieldOverviewMap(field: field, visibleRowNumbers: [3])

// Beberapa baris
FieldOverviewMap(field: field, visibleRowNumbers: [2, 5])
```

`nil` berarti semua baris, `[]` berarti tanpa baris. Nomor yang tidak ditemukan tidak menghasilkan titik. Batas dan skala kebun tetap sama agar koordinat tidak bergeser saat filter berubah. Jumlah titik, tap, dan VoiceOver mengikuti baris yang terlihat; statistik kebun di luar peta tetap mencakup seluruh kebun. Filter belum ditambahkan sebagai kontrol baru di homescreen.

Untuk kartu ringkas (misalnya Aksi), pilih baris dan sisi dari logika rekomendasi lalu gunakan `FieldHeatmapRowStrip`. Komponen ini hanya menerima dan mengurutkan observasi yang sudah tersimpan; ia tidak melakukan konversi koordinat atau pembaruan model.

### Verifikasi

1. Build scheme nyawits.
2. Buka demo; tap titik; buka daftar/detail tanaman.
3. Pada iPhone, mulai/lanjutkan foto, ganti baris/sisi, undo/lewati, simpan.
4. Buka ulang kebun dan cek progres serta titiknya.
5. Bila mengubah penyimpanan, jalankan scripts/test-architecture.sh dari root repo.

Build saja belum memverifikasi ARKit/GPS. Gunakan perangkat untuk langkah kamera.
