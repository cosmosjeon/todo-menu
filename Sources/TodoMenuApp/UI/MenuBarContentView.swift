import SwiftUI

struct MenuBarContentView: View {
  @Bindable var model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if model.configuration == nil {
        Text("No configuration yet.")
          .font(.subheadline)
        Text("Open Settings to choose your daily notes folder and templates.")
          .font(.caption)
          .foregroundStyle(.secondary)
        SettingsLink {
          Label("Open Settings", systemImage: "gearshape")
        }
        .buttonStyle(.borderedProminent)
      } else {
        HStack(alignment: .top, spacing: 16) {
          ScrollView {
            VStack(alignment: .leading, spacing: 4) {
              Text("Today")
                .font(.subheadline.weight(.semibold))
              ForEach(displayedSections, id: \.id) { section in
                VStack(alignment: .leading, spacing: 6) {
                  Text(section.section.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                  if section.items.isEmpty {
                    Text("No todos")
                      .font(.caption)
                      .foregroundStyle(.tertiary)
                  } else {
                    ForEach(section.items) { item in
                      Button {
                        _ = model.toggleItem(reference: item.reference)
                      } label: {
                        HStack(alignment: .top, spacing: 8) {
                          Image(systemName: item.isChecked ? "checkmark.square.fill" : "square")
                            .foregroundStyle(item.isChecked ? Color.accentColor : Color.secondary)
                          Text(item.text)
                            .foregroundStyle(.primary)
                            .strikethrough(item.isChecked)
                          Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                      }
                      .buttonStyle(.plain)
                    }
                  }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
          .frame(maxWidth: .infinity, maxHeight: 280, alignment: .topLeading)

          Divider()
            .frame(maxHeight: .infinity)

          VStack(alignment: .leading, spacing: 10) {
            Text("Quick add")
              .font(.subheadline.weight(.semibold))

            Picker("Section", selection: $model.quickAddSection) {
              ForEach(ManagedSection.defaultOrder, id: \.self) { section in
                Text(section.rawValue).tag(section)
              }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            TextField("Add a todo", text: $model.quickAddText)
              .textFieldStyle(.roundedBorder)
              .onSubmit { model.addQuickItem() }

            Button("Add") { model.addQuickItem() }
              .buttonStyle(.borderedProminent)
              .disabled(isQuickAddDisabled)

            Spacer(minLength: 0)
          }
          .frame(width: 180, alignment: .topLeading)
        }

        Text(model.statusMessage)
          .font(.caption)
          .foregroundStyle(.secondary)

        HStack {
          Button("Refresh") { model.refreshTodayFile() }
          Button("Open file") { model.openTodayFile() }
          Button("Reveal folder") { model.revealDailyDirectory() }
          SettingsLink {
            Image(systemName: "gearshape")
          }
        }

      }
    }
    .frame(minWidth: 440, idealWidth: 460)
    .padding()
    .onAppear {
      model.refreshTodayFile()
    }
  }

  private var isQuickAddDisabled: Bool {
    model.quickAddText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var displayedSections: [TodayTodoSection] {
    let sections = ManagedSection.defaultOrder.map { managedSection in
      model.todaySections.first(where: { $0.section == managedSection })
        ?? TodayTodoSection(section: managedSection, items: [])
    }
    let nonEmptySections = sections.filter { !$0.items.isEmpty }
    return nonEmptySections.isEmpty ? sections : nonEmptySections
  }
}
