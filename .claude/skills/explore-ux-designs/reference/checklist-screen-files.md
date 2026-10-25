# `ChecklistScreen` file map

| File | Owns visually |
|---|---|
| `Screens/ChecklistScreen.swift` | SwiftUI host: safe-area handling, background colour, the embedded `UINavigationController`. **Always copy this** — it is the preview's entry point. |
| `ViewControllers/ChecklistViewController.swift` | The screen: table, nav-bar buttons, scroll-driven title, keyboard avoidance, drag-reorder, Reorder Items mode, and the rows' VoiceOver move actions. **Almost always copy this.** |
| `ViewControllers/ChecklistViewController+Menu.swift`, `ViewControllers/ChecklistViewController+Strings.swift`, `ViewControllers/ChecklistViewController+BarHost.swift` | Extensions holding the trailing bar items, overflow menu, the screen's copy, and the hand-off of the bar items to the SwiftUI bar. **Copy all three whenever you copy the controller** — the controller calls into them. |
| `Views/ChecklistInfoHeaderView.swift` | The table header's layout: status ring, name field, notes, history caption. Copy for header redesigns. |
| `Views/ChecklistHistoryCaption.swift` | The "Last updated / Last completed" caption under the notes. |
| `Views/ItemContentView.swift` | One item row's interior: checkbox, name, notes, row height animation. Copy for row redesigns. |
| `Views/ItemTableViewCell.swift` | The cell wrapper pinning `ItemContentView` to `contentView`. Copy only if the cell's own constraints change. |
| `Views/CircularPercentStatusIcon.swift` | The circular percent ring (`.header` and `.row` sizes), drawn with `CAShapeLayer`. |
| `Views/CheckboxButton.swift` | The per-item check control. |
| `Views/CLTextField.swift` | The checklist-name field's styling. |
| `Views/CLTextView.swift` | The notes view and its placeholder; also used inside item rows. |
| `Views/AddItemButtonTableFooterView.swift` | The "add item" footer button. |
| `Views/Colors.swift` | Palette. **Do not copy** — to change colours in one variant, set them inline in that variant's own code. Copying the palette makes every variant's diff unreadable. |

For a screen not in this table, derive the set by grepping the screen's file for the custom types it
constructs, then repeat one level down.
