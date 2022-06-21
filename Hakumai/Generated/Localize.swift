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
  /// Active unique users in last 5 minutes / Max active unique users
  internal static let activeUserDescription = L10n.tr("Localizable", "active_user_description")
  /// History of active unique users in last 20 minutes
  internal static let activeUserHistoryDescription = L10n.tr("Localizable", "active_user_history_description")
  /// Advertise
  internal static let adPoints = L10n.tr("Localizable", "ad_points")
  /// Add
  internal static let add = L10n.tr("Localizable", "add")
  /// Add to Mute User
  internal static let addToMuteUser = L10n.tr("Localizable", "add_to_mute_user")
  /// Always On Top
  internal static let alwaysOnTop = L10n.tr("Localizable", "always_on_top")
  /// Auto URL
  internal static let autoUrl = L10n.tr("Localizable", "auto_url")
  /// Auto enter URL from browser.
  internal static let autoUrlDescription = L10n.tr("Localizable", "auto_url_description")
  /// Bring All to Front
  internal static let bringAllToFront = L10n.tr("Localizable", "bring_all_to_front")
  /// Browser to be Integrate With
  internal static let browserInUse = L10n.tr("Localizable", "browser_in_use")
  /// Cancel
  internal static let cancel = L10n.tr("Localizable", "cancel")
  /// Capitalize
  internal static let capitalize = L10n.tr("Localizable", "capitalize")
  /// Check Document Now
  internal static let checkDocumentNow = L10n.tr("Localizable", "check_document_now")
  /// Check for Updates...
  internal static let checkForUpdate = L10n.tr("Localizable", "check_for_update")
  /// Check Grammar With Spelling
  internal static let checkGrammarWithSpelling = L10n.tr("Localizable", "check_grammar_with_spelling")
  /// Check Spelling While Typing
  internal static let checkSpellingWhileTyping = L10n.tr("Localizable", "check_spelling_while_typing")
  /// Close Inactive Windows/Tabs
  internal static let closeInactiveWindows = L10n.tr("Localizable", "close_inactive_windows")
  /// Close Window/Tab
  internal static let closeWindow = L10n.tr("Localizable", "close_window")
  /// Comments
  internal static let commentCount = L10n.tr("Localizable", "comment_count")
  /// Comment Speech (Requires macOS 10.14-)
  internal static let commentSpeaking = L10n.tr("Localizable", "comment_speaking")
  /// ⌘O (Empty ⏎ to scroll to bottom)
  internal static let commentTextFieldPlaceholder = L10n.tr("Localizable", "comment_text_field_placeholder")
  /// Community Id
  internal static let communityId = L10n.tr("Localizable", "community_id")
  /// Community Name
  internal static let communityName = L10n.tr("Localizable", "community_name")
  /// Connected to the live.
  internal static let connectedToLive = L10n.tr("Localizable", "connected_to_live")
  /// Copy
  internal static let copy = L10n.tr("Localizable", "copy")
  /// Copy All Comments
  internal static let copyAllComments = L10n.tr("Localizable", "copy_all_comments")
  /// Copy Comment
  internal static let copyComment = L10n.tr("Localizable", "copy_comment")
  /// Copy URL in Comment
  internal static let copyUrlInComment = L10n.tr("Localizable", "copy_url_in_comment")
  /// Copy
  internal static let copyUserId = L10n.tr("Localizable", "copy_user_id")
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
  /// Edit
  internal static let edit = L10n.tr("Localizable", "edit")
  /// Elapsed Time
  internal static let elapsedTime = L10n.tr("Localizable", "elapsed_time")
  /// Enable 184
  internal static let enable184 = L10n.tr("Localizable", "enable_184")
  /// Enable debug message in main window
  internal static let enableDebugMessage = L10n.tr("Localizable", "enable_debug_message")
  /// Show emotion
  internal static let enableEmotionMessage = L10n.tr("Localizable", "enable_emotion_message")
  /// Enable notifications for live connection
  internal static let enableLiveNotification = L10n.tr("Localizable", "enable_live_notification")
  /// Enable Mute User Ids
  internal static let enableMuteUserIds = L10n.tr("Localizable", "enable_mute_user_ids")
  /// Enable Mute Words
  internal static let enableMuteWords = L10n.tr("Localizable", "enable_mute_words")
  /// Enter Mute User Id / Word
  internal static let enterMuteUserIdWord = L10n.tr("Localizable", "enter_mute_user_id_word")
  /// Failed to open message server.
  internal static let errorFailedToOpenMessageServer = L10n.tr("Localizable", "error_failed_to_open_message_server")
  /// Internal Error.
  internal static let errorInternal = L10n.tr("Localizable", "error_internal")
  /// Live not started.
  internal static let errorLiveNotStarted = L10n.tr("Localizable", "error_live_not_started")
  /// Failed to load live info.
  internal static let errorNoLiveInfo = L10n.tr("Localizable", "error_no_live_info")
  /// Failed to load message server info.
  internal static let errorNoMessageServerInfo = L10n.tr("Localizable", "error_no_message_server_info")
  /// Failed to comment.
  internal static let failedToComment = L10n.tr("Localizable", "failed_to_comment")
  /// Failed to connect to the live. [%@]
  internal static func failedToPrepareLive(_ p1: Any) -> String {
    return L10n.tr("Localizable", "failed_to_prepare_live", String(describing: p1))
  }
  /// File
  internal static let file = L10n.tr("Localizable", "file")
  /// Gift
  internal static let giftPoints = L10n.tr("Localizable", "gift_points")
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
  /// Closed the live.
  internal static let liveClosed = L10n.tr("Localizable", "live_closed")
  /// Live Title
  internal static let liveTitle = L10n.tr("Localizable", "live_title")
  /// ⌘L (Live URL, Live#)
  internal static let liveUrlTextFieldPlaceholder = L10n.tr("Localizable", "live_url_text_field_placeholder")
  /// Login
  internal static let login = L10n.tr("Localizable", "login")
  /// Login completed.
  internal static let loginCompleted = L10n.tr("Localizable", "login_completed")
  /// Logout
  internal static let logout = L10n.tr("Localizable", "logout")
  /// Logout completed.
  internal static let logoutCompleted = L10n.tr("Localizable", "logout_completed")
  /// Make Lower Case
  internal static let makeLowerCase = L10n.tr("Localizable", "make_lower_case")
  /// Make Upper Case
  internal static let makeUpperCase = L10n.tr("Localizable", "make_upper_case")
  /// Max Active Users
  internal static let maxActiveUserCount = L10n.tr("Localizable", "max_active_user_count")
  /// Minimize
  internal static let minimize = L10n.tr("Localizable", "minimize")
  /// Misc
  internal static let misc = L10n.tr("Localizable", "misc")
  /// New Comment
  internal static let newComment = L10n.tr("Localizable", "new_comment")
  /// New Live
  internal static let newLive = L10n.tr("Localizable", "new_live")
  /// Open New Tab
  internal static let openNewTab = L10n.tr("Localizable", "open_new_tab")
  /// Open New Window
  internal static let openNewWindow = L10n.tr("Localizable", "open_new_window")
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
  /// Retrieved the live info as user "%@".
  internal static func preparedLive(_ p1: Any) -> String {
    return L10n.tr("Localizable", "prepared_live", String(describing: p1))
  }
  /// Quit Hakumai
  internal static let quitHakumai = L10n.tr("Localizable", "quit_hakumai")
  /// Chikuran Rank (Show only when ranked in top 500)
  internal static let rankingDescription = L10n.tr("Localizable", "ranking_description")
  /// Received %d comments.
  internal static func receivedComments(_ p1: Int) -> String {
    return L10n.tr("Localizable", "received_comments", p1)
  }
  /// Receiving comments... (%d)
  internal static func receivingComments(_ p1: Int) -> String {
    return L10n.tr("Localizable", "receiving_comments", p1)
  }
  /// Reconnected.
  internal static let reconnected = L10n.tr("Localizable", "reconnected")
  /// Reconnecting...
  internal static let reconnecting = L10n.tr("Localizable", "reconnecting")
  /// Remove Handle Name
  internal static let removeHandleName = L10n.tr("Localizable", "remove_handle_name")
  /// Remove User Color
  internal static let removeUserColor = L10n.tr("Localizable", "remove_user_color")
  /// Safari
  internal static let safari = L10n.tr("Localizable", "safari")
  /// Press to scroll down / long press to scroll to bottom
  internal static let scrollDownButton = L10n.tr("Localizable", "scroll_down_button")
  /// Press to scroll up / long press to scroll to top
  internal static let scrollUpButton = L10n.tr("Localizable", "scroll_up_button")
  /// Select All
  internal static let selectAll = L10n.tr("Localizable", "select_all")
  /// Services
  internal static let services = L10n.tr("Localizable", "services")
  /// Set
  internal static let `set` = L10n.tr("Localizable", "set")
  /// Set Handle Name
  internal static let setHandleName = L10n.tr("Localizable", "set_handle_name")
  /// Set/Update Handle Name
  internal static let setUpdateHandleName = L10n.tr("Localizable", "set_update_handle_name")
  /// Set User Color
  internal static let setUserColor = L10n.tr("Localizable", "set_user_color")
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
  /// Comment Speech
  internal static let speak = L10n.tr("Localizable", "speak")
  /// Speech
  internal static let speakComment = L10n.tr("Localizable", "speak_comment")
  /// Speak comments. VOICEVOX app is used if available.
  internal static let speakCommentDescription = L10n.tr("Localizable", "speak_comment_description")
  /// Speech Volume
  internal static let speakVolume = L10n.tr("Localizable", "speak_volume")
  /// Sample
  internal static let speakerSample = L10n.tr("Localizable", "speaker_sample")
  /// Speech
  internal static let speech = L10n.tr("Localizable", "speech")
  /// Spelling and Grammar
  internal static let spellingAndGrammar = L10n.tr("Localizable", "spelling_and_grammar")
  /// Start Speaking
  internal static let startSpeaking = L10n.tr("Localizable", "start_speaking")
  /// Stop Speaking
  internal static let stopSpeaking = L10n.tr("Localizable", "stop_speaking")
  /// Substitutions
  internal static let substitutions = L10n.tr("Localizable", "substitutions")
  /// Sync window and tab selection state when auto url is enabled
  internal static let syncBrowserTabSelection = L10n.tr("Localizable", "sync_browser_tab_selection")
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
  /// VOICEVOX Not Found
  internal static let voicevoxNotFound = L10n.tr("Localizable", "voicevox_not_found")
  /// Speaker (VOICEVOX)
  internal static let voicevoxSpeaker = L10n.tr("Localizable", "voicevox_speaker")
  /// VOICEVOX Website
  internal static let voicevoxWebsite = L10n.tr("Localizable", "voicevox_website")
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
