//
//  ContentView.swift
//  nyawits
//
//  Created by Hatami Sugandi on 04/09/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store: FieldMappingStore

    init() {
        #if DEBUG
        let previewRoot = ProcessInfo.processInfo.arguments.contains("--mapping-camera-preview")
            ? FileManager.default.temporaryDirectory.appendingPathComponent("MappingCameraPreview") : nil
        _store = StateObject(wrappedValue: FieldMappingStore(storageRoot: previewRoot))
        #else
        _store = StateObject(wrappedValue: FieldMappingStore())
        #endif
    }

    var body: some View {
        Group {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--mapping-camera-preview") {
                let demo = NDREDemoFactory.makeField()
                PlantCaptureView(fieldID: demo.id, fieldName: "Uji kamera", plan: demo.plan,
                                 existingField: store.field(id: demo.id))
            } else {
                FieldHomeView()
            }
            #else
            FieldHomeView()
            #endif
        }
        .environmentObject(store)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
