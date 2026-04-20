import SwiftUI

@main
struct TodoMenuApp: App {
  @State private var model = AppModel()

  var body: some Scene {
    MenuBarExtra("Todo Menu", systemImage: "checklist") {
      MenuBarContentView(model: model)
    }
    .menuBarExtraStyle(.window)

    Settings {
      ConfigurationView(model: model)
    }
  }

  init() {
    model.start()
  }
}
