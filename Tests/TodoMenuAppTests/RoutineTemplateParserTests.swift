import Testing

@testable import TodoMenuApp

struct RoutineTemplateParserTests {
  @Test func parseChecklistItemsOnly() {
    let parser = RoutineTemplateParser()
    let text = """
      # Routine
      - [ ] Stretch
      notes that should be ignored
      - [x] Inbox zero
      """

    let items = parser.parseItems(from: text)

    #expect(items.count == 2)
    #expect(items[0].text == "Stretch")
    #expect(items[0].isChecked == false)
    #expect(items[1].text == "Inbox zero")
    #expect(items[1].isChecked == true)
  }
}
