//
//  ContentView.swift
//  nyawits
//
//  Created by Hatami Sugandi on 04/09/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store: FieldMappingStore
    @StateObject private var scanStore: ScanSessionStore
    @StateObject private var scheduleStore: ScheduleSettingsStore

    init() {
        #if DEBUG
        let previewRoot = ProcessInfo.processInfo.arguments.contains("--mapping-camera-preview")
            ? FileManager.default.temporaryDirectory.appendingPathComponent("MappingCameraPreview") : nil
        _store = StateObject(wrappedValue: FieldMappingStore(storageRoot: previewRoot))
        _scanStore = StateObject(wrappedValue: ScanSessionStore(storageRoot: previewRoot))
        _scheduleStore = StateObject(wrappedValue: ScheduleSettingsStore(storageRoot: previewRoot))
        #else
        _store = StateObject(wrappedValue: FieldMappingStore())
        _scanStore = StateObject(wrappedValue: ScanSessionStore())
        _scheduleStore = StateObject(wrappedValue: ScheduleSettingsStore())
        #endif
    }

    var body: some View {
        Group {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--mapping-camera-preview") {
                let demo = VigorDemoFactory.makeField()
                PlantCaptureView(fieldID: demo.id, fieldName: "Uji kamera", plan: demo.plan,
                                 existingField: store.field(id: demo.id))
            } else if ProcessInfo.processInfo.arguments.contains("--mulch-row-setup-preview") {
                let demo = VigorDemoFactory.makeField()
                MulchRowSetupView(boundary: demo.plan.boundary, initialRowCount: 10)
            } else {
                FieldHomeView()
            }
            #else
            FieldHomeView()
            #endif
        }
        .environmentObject(store)
        .environmentObject(scanStore)
        .environmentObject(scheduleStore)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
