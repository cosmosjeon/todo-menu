import SwiftUI

struct ConfigurationView: View {
  @Bindable var model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      LabeledContent("Daily notes folder") {
        HStack {
          TextField("/path/to/daily-notes", text: $model.dailyNotesDirectoryText)
          Button("Choose…") { model.pickDailyNotesDirectory() }
        }
      }

      LabeledContent("Daily template") {
        HStack {
          TextField("Optional daily template file", text: $model.dailyScaffoldFileText)
          Button("Choose…") { model.pickDailyScaffoldFile() }
        }
      }

      Button("Save configuration") {
        model.saveConfiguration()
      }
      .buttonStyle(.borderedProminent)

      Text(model.statusMessage)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(width: 420)
    .padding()
  }
}
