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
  /// Add
  internal static let add = L10n.tr("Localizable", "add")
  /// Add to Mute User
  internal static let addToMuteUser = L10n.tr("Localizable", "add_to_mute_user")
  /// Always On Top
  internal static let alwaysOnTop = L10n.tr("Localizable", "always_on_top")
  /// Bring All to Front
  internal static let bringAllToFront = L10n.tr("Localizable", "bring_all_to_front")
  /// Cancel
  internal static let cancel = L10n.tr("Localizable", "cancel")
  /// Capitalize
  internal static let capitalize = L10n.tr("Localizable", "capitalize")
  /// Check
  internal static let check = L10n.tr("Localizable", "check")
  /// Check Document Now
  internal static let checkDocumentNow = L10n.tr("Localizable", "check_document_now")
  /// Check for Updates...
  internal static let checkForUpdate = L10n.tr("Localizable", "check_for_update")
  /// Check Grammar With Spelling
  internal static let checkGrammarWithSpelling = L10n.tr("Localizable", "check_grammar_with_spelling")
  /// Check Spelling While Typing
  internal static let checkSpellingWhileTyping = L10n.tr("Localizable", "check_spelling_while_typing")
  /// Comments
  internal static let commentCount = L10n.tr("Localizable", "comment_count")
  /// Comment Speaking
  internal static let commentSpeaking = L10n.tr("Localizable", "comment_speaking")
  /// ⌘N (Empty ⏎ to scroll to bottom)
  internal static let commentTextFieldPlaceholder = L10n.tr("Localizable", "comment_text_field_placeholder")
  /// Community Id
  internal static let communityId = L10n.tr("Localizable", "community_id")
  /// Community Name
  internal static let communityName = L10n.tr("Localizable", "community_name")
  /// Connected to live.
  internal static let connectedToLive = L10n.tr("Localizable", "connected_to_live")
  /// Copy
  internal static let copy = L10n.tr("Localizable", "copy")
  /// Copy Comment
  internal static let copyComment = L10n.tr("Localizable", "copy_comment")
  /// Correct Spelling Automatically
  internal static let correctSpellingAutomatically = L10n.tr("Localizable", "correct_spelling_automatically")
  /// Cut
  internal static let cut = L10n.tr("Localizable", "cut")
  /// Data Detectors
  internal static let dataDetectors = L10n.tr("Localizable", "data_detectors")
  /// Default Zoom
  internal static let defaultZoom = L10n.tr("Localizable", "default_zoom")
  /// Delete
  internal static let delete = L10n.tr("Localizable", "delete")
  /// Direct Login (Not Recommended)
  internal static let directLogin = L10n.tr("Localizable", "direct_login")
  /// Edit
  internal static let edit = L10n.tr("Localizable", "edit")
  /// Elapsed Time
  internal static let elapsedTime = L10n.tr("Localizable", "elapsed_time")
  /// Enable 184
  internal static let enable184 = L10n.tr("Localizable", "enable_184")
  /// Enable Mute User Ids
  internal static let enableMuteUserIds = L10n.tr("Localizable", "enable_mute_user_ids")
  /// Enable Mute Words
  internal static let enableMuteWords = L10n.tr("Localizable", "enable_mute_words")
  /// Enter Mute User Id / Word
  internal static let enterMuteUserIdWord = L10n.tr("Localizable", "enter_mute_user_id_word")
  /// Failed
  internal static let failed = L10n.tr("Localizable", "failed")
  /// Failed to comment.
  internal static let failedToComment = L10n.tr("Localizable", "failed_to_comment")
  /// Failed to prepare live. (%@)
  internal static func failedToPrepareLive(_ p1: Any) -> String {
    return L10n.tr("Localizable", "failed_to_prepare_live", String(describing: p1))
  }
  /// File
  internal static let file = L10n.tr("Localizable", "file")
  /// Google Chrome
  internal static let googleChrome = L10n.tr("Localizable", "google_chrome")
  /// Grab URL from Browser
  internal static let grabUrlFromBrowser = L10n.tr("Localizable", "grab_url_from_browser")
  /// Hakumai Help
  internal static let hakumaiHelp = L10n.tr("Localizable", "hakumai_help")
  /// Handle Name
  internal static let handleName = L10n.tr("Localizable", "handle_name")
  /// Help
  internal static let help = L10n.tr("Localizable", "help")
  /// Hide Hakumai
  internal static let hideHakumai = L10n.tr("Localizable", "hide_hakumai")
  /// Hide Others
  internal static let hideOthers = L10n.tr("Localizable", "hide_others")
  /// Live closed.
  internal static let liveClosed = L10n.tr("Localizable", "live_closed")
  /// Live Title
  internal static let liveTitle = L10n.tr("Localizable", "live_title")
  /// ⌘L (Live URL, Live#)
  internal static let liveUrlTextFieldPlaceholder = L10n.tr("Localizable", "live_url_text_field_placeholder")
  /// Mail Address
  internal static let mailAddress = L10n.tr("Localizable", "mail_address")
  /// Make Lower Case
  internal static let makeLowerCase = L10n.tr("Localizable", "make_lower_case")
  /// Make Upper Case
  internal static let makeUpperCase = L10n.tr("Localizable", "make_upper_case")
  /// Minimize
  internal static let minimize = L10n.tr("Localizable", "minimize")
  /// New Comment
  internal static let newComment = L10n.tr("Localizable", "new_comment")
  /// Open Security & Privacy
  internal static let openSecurityPrivacy = L10n.tr("Localizable", "open_security_privacy")
  /// Open URL
  internal static let openUrl = L10n.tr("Localizable", "open_url")
  /// Open URL in Comment
  internal static let openUrlInComment = L10n.tr("Localizable", "open_url_in_comment")
  /// Open User Page
  internal static let openUserPage = L10n.tr("Localizable", "open_user_page")
  /// Password
  internal static let password = L10n.tr("Localizable", "password")
  /// Paste
  internal static let paste = L10n.tr("Localizable", "paste")
  /// Preferences...
  internal static let preferences = L10n.tr("Localizable", "preferences")
  /// Prepared live as user %@.
  internal static func preparedLive(_ p1: Any) -> String {
    return L10n.tr("Localizable", "prepared_live", String(describing: p1))
  }
  /// Quit Hakumai
  internal static let quitHakumai = L10n.tr("Localizable", "quit_hakumai")
  /// Reconnecting...
  internal static let reconnecting = L10n.tr("Localizable", "reconnecting")
  /// Remove Handle Name
  internal static let removeHandleName = L10n.tr("Localizable", "remove_handle_name")
  /// Report as NG User
  internal static let reportAsNgUser = L10n.tr("Localizable", "report_as_ng_user")
  /// Safari
  internal static let safari = L10n.tr("Localizable", "safari")
  /// To retrieve the cookie from Safari, please open the "Security & Privacy" in the "System Preference”, go to the "Privacy" tab and give the "Full Disk Access" right to Hakumai app.
  internal static let safariCookieAlertDescription = L10n.tr("Localizable", "safari_cookie_alert_description")
  /// No Safari Cookie found
  internal static let safariCookieAlertTitle = L10n.tr("Localizable", "safari_cookie_alert_title")
  /// Select All
  internal static let selectAll = L10n.tr("Localizable", "select_all")
  /// Services
  internal static let services = L10n.tr("Localizable", "services")
  /// Session Management
  internal static let sessionManagement = L10n.tr("Localizable", "session_management")
  /// Set
  internal static let `set` = L10n.tr("Localizable", "set")
  /// Set Handle Name
  internal static let setHandleName = L10n.tr("Localizable", "set_handle_name")
  /// Set/Update Handle Name
  internal static let setUpdateHandleName = L10n.tr("Localizable", "set_update_handle_name")
  /// Show All
  internal static let showAll = L10n.tr("Localizable", "show_all")
  /// Show Spelling and Grammar
  internal static let showSpellingAndGrammar = L10n.tr("Localizable", "show_spelling_and_grammar")
  /// Show Substitutions
  internal static let showSubstitutions = L10n.tr("Localizable", "show_substitutions")
  /// Smart Copy/Paste
  internal static let smartCopyPaste = L10n.tr("Localizable", "smart_copy_paste")
  /// Smart Dashes
  internal static let smartDashes = L10n.tr("Localizable", "smart_dashes")
  /// Smart Links
  internal static let smartLinks = L10n.tr("Localizable", "smart_links")
  /// Smart Quotes
  internal static let smartQuotes = L10n.tr("Localizable", "smart_quotes")
  /// Speak
  internal static let speak = L10n.tr("Localizable", "speak")
  /// Speak
  internal static let speakComment = L10n.tr("Localizable", "speak_comment")
  /// Speak Comments (Requires macOS 10.14-)
  internal static let speakComments = L10n.tr("Localizable", "speak_comments")
  /// Speak Volume
  internal static let speakVolume = L10n.tr("Localizable", "speak_volume")
  /// Speech
  internal static let speech = L10n.tr("Localizable", "speech")
  /// Spelling and Grammar
  internal static let spellingAndGrammar = L10n.tr("Localizable", "spelling_and_grammar")
  /// Start Speaking
  internal static let startSpeaking = L10n.tr("Localizable", "start_speaking")
  /// Status
  internal static let status = L10n.tr("Localizable", "status")
  /// Stop Speaking
  internal static let stopSpeaking = L10n.tr("Localizable", "stop_speaking")
  /// Substitutions
  internal static let substitutions = L10n.tr("Localizable", "substitutions")
  /// Success
  internal static let success = L10n.tr("Localizable", "success")
  /// Text Replacement
  internal static let textReplacement = L10n.tr("Localizable", "text_replacement")
  /// Transformations
  internal static let transformations = L10n.tr("Localizable", "transformations")
  /// User ID
  internal static let userId = L10n.tr("Localizable", "user_id")
  /// User Name
  internal static let userName = L10n.tr("Localizable", "user_name")
  /// View
  internal static let view = L10n.tr("Localizable", "view")
  /// Visitors
  internal static let visitorCount = L10n.tr("Localizable", "visitor_count")
  /// Window
  internal static let window = L10n.tr("Localizable", "window")
  /// Zoom
  internal static let zoom = L10n.tr("Localizable", "zoom")
  /// Zoom In
  internal static let zoomIn = L10n.tr("Localizable", "zoom_in")
  /// Zoom Out
  internal static let zoomOut = L10n.tr("Localizable", "zoom_out")
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
