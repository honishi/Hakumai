// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
internal enum L10n {
  /// Active Users
  internal static let activeUser = L10n.tr("Localizable", "active_user")
  /// Comments
  internal static let commentCount = L10n.tr("Localizable", "comment_count")
  /// ⌘N (Empty ⏎ to scroll to bottom)
  internal static let commentTextFieldPlaceholder = L10n.tr("Localizable", "comment_text_field_placeholder")
  /// Community Id
  internal static let communityId = L10n.tr("Localizable", "community_id")
  /// Community Name
  internal static let communityName = L10n.tr("Localizable", "community_name")
  /// Elapsed Time
  internal static let elapsedTime = L10n.tr("Localizable", "elapsed_time")
  /// Live Title
  internal static let liveTitle = L10n.tr("Localizable", "live_title")
  /// ⌘L (Live URL, Live#)
  internal static let liveUrlTextFieldPlaceholder = L10n.tr("Localizable", "live_url_text_field_placeholder")
  /// Speak
  internal static let speakComment = L10n.tr("Localizable", "speak_comment")
  /// Visitors
  internal static let visitorCount = L10n.tr("Localizable", "visitor_count")
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension L10n {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    let format = BundleToken.bundle.localizedString(forKey: key, value: nil, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
