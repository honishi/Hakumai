// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
internal enum L10n {
  /// About Hakumai
  internal static let aboutHakumai = L10n.tr("Localizable", "about_hakumai")
  /// Active Users
  internal static let activeUser = L10n.tr("Localizable", "active_user")
  /// Add Handle Name
  internal static let addHandleName = L10n.tr("Localizable", "add_handle_name")
  /// Add to Mute User
  internal static let addToMuteUser = L10n.tr("Localizable", "add_to_mute_user")
  /// Check for Updates...
  internal static let checkForUpdate = L10n.tr("Localizable", "check_for_update")
  /// Comments
  internal static let commentCount = L10n.tr("Localizable", "comment_count")
  /// ⌘N (Empty ⏎ to scroll to bottom)
  internal static let commentTextFieldPlaceholder = L10n.tr("Localizable", "comment_text_field_placeholder")
  /// Community Id
  internal static let communityId = L10n.tr("Localizable", "community_id")
  /// Community Name
  internal static let communityName = L10n.tr("Localizable", "community_name")
  /// Copy
  internal static let copy = L10n.tr("Localizable", "copy")
  /// Copy Comment
  internal static let copyComment = L10n.tr("Localizable", "copy_comment")
  /// Cut
  internal static let cut = L10n.tr("Localizable", "cut")
  /// Delete
  internal static let delete = L10n.tr("Localizable", "delete")
  /// Edit
  internal static let edit = L10n.tr("Localizable", "edit")
  /// Elapsed Time
  internal static let elapsedTime = L10n.tr("Localizable", "elapsed_time")
  /// Enable 184
  internal static let enable184 = L10n.tr("Localizable", "enable_184")
  /// File
  internal static let file = L10n.tr("Localizable", "file")
  /// Grab URL from Browser
  internal static let grabUrlFromBrowser = L10n.tr("Localizable", "grab_url_from_browser")
  /// Help
  internal static let help = L10n.tr("Localizable", "help")
  /// Hide Hakumai
  internal static let hideHakumai = L10n.tr("Localizable", "hide_hakumai")
  /// Hide Others
  internal static let hideOthers = L10n.tr("Localizable", "hide_others")
  /// Live Title
  internal static let liveTitle = L10n.tr("Localizable", "live_title")
  /// ⌘L (Live URL, Live#)
  internal static let liveUrlTextFieldPlaceholder = L10n.tr("Localizable", "live_url_text_field_placeholder")
  /// New Comment
  internal static let newComment = L10n.tr("Localizable", "new_comment")
  /// Open URL
  internal static let openUrl = L10n.tr("Localizable", "open_url")
  /// Open URL in Comment
  internal static let openUrlInComment = L10n.tr("Localizable", "open_url_in_comment")
  /// Open User Page
  internal static let openUserPage = L10n.tr("Localizable", "open_user_page")
  /// Paste
  internal static let paste = L10n.tr("Localizable", "paste")
  /// Preferences...
  internal static let preferences = L10n.tr("Localizable", "preferences")
  /// Quit Hakumai
  internal static let quitHakumai = L10n.tr("Localizable", "quit_hakumai")
  /// Remove Handle Name
  internal static let removeHandleName = L10n.tr("Localizable", "remove_handle_name")
  /// Report as NG User
  internal static let reportAsNgUser = L10n.tr("Localizable", "report_as_ng_user")
  /// Select All
  internal static let selectAll = L10n.tr("Localizable", "select_all")
  /// Services
  internal static let services = L10n.tr("Localizable", "services")
  /// Show All
  internal static let showAll = L10n.tr("Localizable", "show_all")
  /// Speak
  internal static let speak = L10n.tr("Localizable", "speak")
  /// Speak
  internal static let speakComment = L10n.tr("Localizable", "speak_comment")
  /// View
  internal static let view = L10n.tr("Localizable", "view")
  /// Visitors
  internal static let visitorCount = L10n.tr("Localizable", "visitor_count")
  /// Window
  internal static let window = L10n.tr("Localizable", "window")
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
