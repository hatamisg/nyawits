import ARKit
import SwiftUI

struct ARCameraPreview: UIViewRepresentable {
    let session: ARSession

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.session = session
        view.automaticallyUpdatesLighting = true
        view.rendersCameraGrain = true
        return view
    }

    func updateUIView(_ view: ARSCNView, context: Context) {
        if view.session !== session {
            view.session = session
        }
    }
}
