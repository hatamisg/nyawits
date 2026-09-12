import SwiftUI

/// Tandai dua kotak pada satu frame: wilayah kanopi dan wilayah kartu abu-abu.
///
/// Kartu abu-abu WAJIB terlihat di frame ini. Kanopi dan kartu harus berada di
/// foto yang sama supaya terkena faktor pengali iluminasi yang sama — itulah
/// yang membuat drift iluminasi batal persis saat dibagi. Memotret kartu sekali
/// di awal sesi membuang perlindungan itu.
///
/// Untuk frame RGB, SATU pasang kotak melayani ketiga kanal.
struct ROIPickerView: View {
    let frame: ImportedFrame
    let frameURL: URL
    var initialCanopy: ROIRect?
    var initialCard: ROIRect?
    let onConfirm: (ROIRect, ROIRect) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var canopy = ROIRect(x: 0.22, y: 0.26, width: 0.34, height: 0.34)
    @State private var card = ROIRect(x: 0.64, y: 0.62, width: 0.20, height: 0.20)
    @State private var selected: ROIBoxLayer.Box = .canopy
    @State private var preview: CGImage?
    @State private var isLoading = true
    @State private var loadFailed = false

    private let sampler = RawFrameSampler()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                frameArea
                controls
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(frame.role.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") {
                        onConfirm(canopy, card)
                        dismiss()
                    }
                    .disabled(!canopy.isValid || !card.isValid || loadFailed)
                }
            }
            .task { await loadPreview() }
        }
    }

    private var frameArea: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                if let preview {
                    let fitted = fittedSize(
                        image: CGSize(width: preview.width, height: preview.height),
                        container: proxy.size
                    )
                    ZStack(alignment: .topLeading) {
                        Image(decorative: preview, scale: 1)
                            .resizable()
                            .frame(width: fitted.width, height: fitted.height)
                        ROIBoxLayer(
                            canopy: $canopy,
                            card: $card,
                            selected: $selected,
                            imageSize: fitted
                        )
                    }
                    .frame(width: fitted.width, height: fitted.height)
                } else if isLoading {
                    ProgressView().tint(.white)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                        Text("Frame ini tidak dapat ditampilkan.")
                            .font(.callout)
                        Text("Pratinjau gagal dibuat. Periksa apakah berkasnya benar-benar RAW dari rig.")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.white)
                    .padding(24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Kotak", selection: $selected) {
                ForEach(ROIBoxLayer.Box.allCases) { box in
                    Text(box.title).tag(box)
                }
            }
            .pickerStyle(.segmented)

            Text(hint)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !frame.isRaw {
                Label(
                    "Berkas ini bukan RAW (.\(frame.sourceFormat)). Petak yang memakainya tidak akan dihitung.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private var hint: String {
        switch selected {
        case .canopy:
            frame.role == .rgb
                ? "Tandai daun tanaman. Satu pasang kotak ini melayani ketiga kanal RGB."
                : "Tandai daun tanaman, hindari tanah dan mulsa."
        case .card:
            "Tandai kartu abu-abu. Kartu wajib terlihat di frame ini juga — bukan difoto terpisah, karena kanopi dan kartu harus terkena cahaya yang sama."
        }
    }

    private func fittedSize(image: CGSize, container: CGSize) -> CGSize {
        guard image.width > 0, image.height > 0,
              container.width > 0, container.height > 0 else { return .zero }
        let scale = min(container.width / image.width, container.height / image.height)
        return CGSize(width: image.width * scale, height: image.height * scale)
    }

    private func loadPreview() async {
        if let initialCanopy { canopy = initialCanopy }
        if let initialCard { card = initialCard }
        let url = frameURL
        let image = sampler.previewImage(at: url)
        preview = image
        loadFailed = image == nil
        isLoading = false
    }
}
