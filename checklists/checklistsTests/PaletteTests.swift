@testable import checklists
import Testing
import UIKit

/// The palette's light and dark values, and the contrast each text and icon pairing has to keep.
/// `core-docs/accessibility-spec.md` §Status by axis (Dark Mode) describes the palette.
@Suite("Palette")
struct PaletteTests {
  private struct Value {
    let name: String
    let color: UIColor
    let light: String
    let dark: String
    /// Under Increase Contrast. `nil` means the colorset has no high-contrast entry, so the
    /// standard value is expected.
    var lightHigh: String?
    var darkHigh: String?
  }

  /// Text needs 4.5:1; icons 3:1.
  private struct Pair {
    let name: String
    let foreground: UIColor
    let background: UIColor
    let minimum: Double
  }

  private static let light = UITraitCollection(userInterfaceStyle: .light)
  private static let dark = UITraitCollection(userInterfaceStyle: .dark)
  private static let lightHigh = light.modifyingTraits { $0.accessibilityContrast = .high }
  private static let darkHigh = dark.modifyingTraits { $0.accessibilityContrast = .high }
  private static let toastError = UIColor(resource: .toastError)
  private static let surface = UIColor(resource: .surface)
  private static let panelForeground = UIColor(resource: .panelForeground)
  private static let success = UIColor(resource: .success)
  private static let warning = UIColor(resource: .warning)

  private static func components(_ color: UIColor, _ traits: UITraitCollection) -> [CGFloat] {
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    color.resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return [red, green, blue]
  }

  private static func hex(_ color: UIColor, _ traits: UITraitCollection) -> String {
    components(color, traits).map { String(format: "%02X", Int(($0 * 255).rounded())) }.joined()
  }

  /// WCAG 2 contrast ratio.
  private static func contrast(_ pair: Pair, _ traits: UITraitCollection) -> Double {
    func luminance(_ color: UIColor) -> Double {
      let linear = components(color, traits).map { channel in
        let value = Double(channel)
        return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
      }
      return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }
    let lighter = max(luminance(pair.foreground), luminance(pair.background))
    let darker = min(luminance(pair.foreground), luminance(pair.background))
    return (lighter + 0.05) / (darker + 0.05)
  }

  private static let values = [
    Value(name: "defaultBackground", color: Colors.defaultBackground, light: "F5F5F5", dark: "0F171E"),
    Value(name: "panelForeground", color: panelForeground, light: "F5F5F5", dark: "F5F5F5"),
    Value(name: "darkBlueGray", color: Colors.darkBlueGray, light: "336E91", dark: "24506A"),
    Value(name: "surface", color: surface, light: "FFFFFF", dark: "1D2A35"),
    Value(name: "primaryText", color: Colors.primaryText, light: "000000", dark: "E4ECF1"),
    Value(name: "inactiveText", color: Colors.inactiveText, light: "636363", dark: "8799A6"),
    Value(name: "placeholderText", color: Colors.placeholderText, light: "707070", dark: "80919E"),
    Value(name: "accent", color: Colors.accent, light: "2E7A80", dark: "5FC4CB"),
    Value(name: "salmonRed", color: Colors.destructive, light: "ED6664", dark: "FF7C76", lightHigh: "BD3A3D", darkHigh: "FF7C76"),
    Value(name: "accentFill", color: Colors.accentFill, light: "2E7A80", dark: "2E7D83"),
    Value(name: "destructiveFill", color: Colors.destructiveFill, light: "ED6664", dark: "C94A47", lightHigh: "BD3A3D", darkHigh: "C94A47"),
    Value(name: "toastError", color: toastError, light: "ED6664", dark: "FF7C76"),
    Value(name: "success", color: success, light: "34C759", dark: "3DD68C"),
    Value(name: "warning", color: warning, light: "FF9500", dark: "FFAA33"),
    Value(name: "shadow", color: UIColor(resource: .shadow), light: "8E8E93", dark: "000000"),
  ]

  @Test("each colorset resolves to its light and dark value, at standard and high contrast")
  func resolvedValues() {
    for value in Self.values {
      #expect(Self.hex(value.color, Self.light) == value.light, "\(value.name) in light")
      #expect(Self.hex(value.color, Self.dark) == value.dark, "\(value.name) in dark")
      #expect(Self.hex(value.color, Self.lightHigh) == value.lightHigh ?? value.light, "\(value.name) in light, high contrast")
      #expect(Self.hex(value.color, Self.darkHigh) == value.darkHigh ?? value.dark, "\(value.name) in dark, high contrast")
    }
  }

  private static let pairs = [
    Pair(name: "text on the page", foreground: Colors.primaryText, background: Colors.defaultBackground, minimum: 4.5),
    Pair(name: "checked items and captions on the page", foreground: Colors.inactiveText, background: Colors.defaultBackground, minimum: 4.5),
    Pair(name: "placeholders on the page", foreground: Colors.placeholderText, background: Colors.defaultBackground, minimum: 4.5),
    Pair(name: "text in a Form row", foreground: Colors.primaryText, background: surface, minimum: 4.5),
    Pair(name: "secondary text in a Form row", foreground: Colors.inactiveText, background: surface, minimum: 4.5),
    Pair(name: "placeholders in a Form row", foreground: Colors.placeholderText, background: surface, minimum: 4.5),
    Pair(name: "text on toasts", foreground: panelForeground, background: Colors.darkBlueGray, minimum: 4.5),
    Pair(name: "accent text on the page", foreground: Colors.accent, background: Colors.defaultBackground, minimum: 4.5),
    Pair(name: "accent text in a Form row", foreground: Colors.accent, background: surface, minimum: 4.5),
    Pair(name: "the Duplicate swipe glyph", foreground: .white, background: Colors.accentFill, minimum: 3),
    Pair(name: "the Delete swipe glyph", foreground: .white, background: Colors.destructiveFill, minimum: 3),
  ]

  /// Pairs that fail in light today; Increase Contrast (#345) owns them.
  private static let darkOnlyPairs = [
    Pair(name: "the success toast icon", foreground: success, background: Colors.darkBlueGray, minimum: 3),
    Pair(name: "the warning toast icon", foreground: warning, background: Colors.darkBlueGray, minimum: 3),
    Pair(name: "the error toast icon", foreground: toastError, background: Colors.darkBlueGray, minimum: 3),
    Pair(name: "destructive text on the page", foreground: Colors.destructive, background: Colors.defaultBackground, minimum: 4.5),
    Pair(name: "the iCloud synced icon", foreground: success, background: surface, minimum: 3),
    Pair(name: "the iCloud warning icon", foreground: warning, background: surface, minimum: 3),
  ]

  /// Pairs that fail in light at standard contrast but pass with Increase Contrast on.
  private static let highContrastPairs = [
    Pair(name: "destructive text on the page", foreground: Colors.destructive, background: Colors.defaultBackground, minimum: 4.5),
  ]

  @Test("text and essential icons meet their contrast minimum in both appearances")
  func contrastBothAppearances() {
    for pair in Self.pairs {
      for (appearance, traits) in [("light", Self.light), ("dark", Self.dark)] {
        let ratio = Self.contrast(pair, traits)
        #expect(ratio >= pair.minimum, "\(pair.name) in \(appearance): \(ratio)")
      }
    }
  }

  @Test("status and destructive colors meet their contrast minimum in dark")
  func contrastDark() {
    for pair in Self.darkOnlyPairs {
      let ratio = Self.contrast(pair, Self.dark)
      #expect(ratio >= pair.minimum, "\(pair.name): \(ratio)")
    }
  }

  @Test("text and essential icons meet their contrast minimum at high contrast in both appearances")
  func contrastHigh() {
    for pair in Self.pairs + Self.highContrastPairs {
      for (appearance, traits) in [("light", Self.lightHigh), ("dark", Self.darkHigh)] {
        let ratio = Self.contrast(pair, traits)
        #expect(ratio >= pair.minimum, "\(pair.name) in \(appearance), high contrast: \(ratio)")
      }
    }
  }
}
