import SwiftUI

@main
struct FanControlApp: App {
    @StateObject private var model = FanModel()

    var body: some Scene {
        MenuBarExtra {
            ContentView().environmentObject(model)
        } label: {
            Image(systemName: model.cooling ? "fanblades.fill" : "fanblades")
        }
        .menuBarExtraStyle(.window)
    }
}
