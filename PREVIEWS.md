# Mengedit UI dengan Xcode Canvas

1. Buka file komponen di folder fitur yang ingin diedit.
2. Aktifkan **Editor → Canvas**, lalu tekan **Resume** bila preview dijeda.
3. Pilih preview di bagian bawah file. Card pemupukan dan aksi memiliki pilihan simulasi dan belum ada data; riwayat memiliki kondisi kosong dan berisi.
4. Edit tampilan di komponen aslinya. Ubah argumen di blok `#Preview` untuk mencoba teks, ukuran, dan kondisi lain.

Data contoh bersama ada di `nyawits/Shared/PreviewSupport/PreviewFixtures.swift`.
Repository preview hanya menyimpan perubahan di memori, tidak menyentuh data kebun di perangkat.
Helper dan preview baru dibatasi dengan `#if DEBUG`.

Heatmap menggunakan data simulasi lokal. Peta MapKit tetap membutuhkan koneksi untuk memuat citra peta, tetapi tidak meminta lokasi perangkat di Canvas.
Preview kamera hanya menampilkan UI; pengambilan foto, GPS, dan motion tidak dijalankan. Uji kamera/AR yang sesungguhnya tetap dilakukan di iPhone.

Komponen kecil dalam satu file (misalnya tombol dan material glass) ditampilkan bersama di preview file tersebut. Kontrol baris memakai state lokal agar nilai bisa diubah lewat preview interaktif.

Saat menambah komponen baru, tambahkan `#Preview` di file yang sama dan gunakan fixture lokal. Sertakan `NavigationStack` dan `.previewStores()` jika tampilan membutuhkannya. `previewStores()` menyuntikkan `FieldMappingStore`, `ScanSessionStore`, dan `ScheduleSettingsStore` sekaligus, jadi penambahan store baru cukup diubah di `PreviewFixtures.swift`.
