import Foundation

/// Pembaca berkas JSON di dalam bundle.
///
/// Project memakai `fileSystemSynchronizedGroups`, dan grup tersinkron sering
/// meratakan subfolder ke akar bundle alih-alih mempertahankannya. Karena itu
/// pencarian dicoba dua kali: dengan `subdirectory` dulu, lalu datar.
///
/// Tidak ada nilai default dan tidak ada fallback: berkas yang tidak ditemukan
/// atau tidak terbaca melempar error. Pemanggilnya wajib menolak menghitung dan
/// melaporkan kesalahan, bukan diam-diam memakai angka lama.
enum BundleJSONResource {
    enum LoadError: Error, Equatable {
        /// Berkas tidak ada di bundle, baik di dalam subfolder maupun di akar.
        case notFound(name: String, subdirectory: String?)
        /// Berkas ada tapi isinya tidak terbaca.
        case unreadable(name: String)

        /// Pesan berbahasa Indonesia yang bisa dibaca petani.
        var message: String {
            switch self {
            case let .notFound(name, _):
                "Berkas kalibrasi \(name).json tidak ditemukan di aplikasi. Perhitungan dihentikan."
            case let .unreadable(name):
                "Berkas kalibrasi \(name).json tidak dapat dibaca. Perhitungan dihentikan."
            }
        }
    }

    nonisolated static func data(
        named name: String,
        subdirectory: String?,
        bundle: Bundle = .main
    ) throws -> Data {
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: subdirectory)
            ?? bundle.url(forResource: name, withExtension: "json")
        guard let url else {
            throw LoadError.notFound(name: name, subdirectory: subdirectory)
        }
        guard let data = try? Data(contentsOf: url) else {
            throw LoadError.unreadable(name: name)
        }
        return data
    }
}
