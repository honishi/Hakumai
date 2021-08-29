// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

// swiftlint:disable sorted_imports
import Foundation
import AppKit

// swiftlint:disable superfluous_disable_command
// swiftlint:disable file_length implicit_return

// MARK: - Storyboard Scenes

// swiftlint:disable explicit_type_interface identifier_name line_length type_body_length type_name
internal enum StoryboardScene {
  internal enum AuthWindowController: StoryboardType {
    internal static let storyboardName = "AuthWindowController"

    internal static let authWindowController = SceneType<Hakumai.AuthWindowController>(storyboard: AuthWindowController.self, identifier: "AuthWindowController")
  }
  internal enum MainWindowController: StoryboardType {
    internal static let storyboardName = "MainWindowController"

    internal static let handleNameAddViewController = SceneType<Hakumai.HandleNameAddViewController>(storyboard: MainWindowController.self, identifier: "HandleNameAddViewController")

    internal static let mainWindowController = SceneType<Hakumai.MainWindowController>(storyboard: MainWindowController.self, identifier: "MainWindowController")
  }
  internal enum PreferenceWindowController: StoryboardType {
    internal static let storyboardName = "PreferenceWindowController"

    internal static let initialScene = InitialSceneType<Hakumai.PreferenceWindowController>(storyboard: PreferenceWindowController.self)

    internal static let generalViewController = SceneType<Hakumai.GeneralViewController>(storyboard: PreferenceWindowController.self, identifier: "GeneralViewController")

    internal static let muteAddViewController = SceneType<Hakumai.MuteAddViewController>(storyboard: PreferenceWindowController.self, identifier: "MuteAddViewController")

    internal static let muteViewController = SceneType<Hakumai.MuteViewController>(storyboard: PreferenceWindowController.self, identifier: "MuteViewController")

    internal static let preferenceWindowController = SceneType<Hakumai.PreferenceWindowController>(storyboard: PreferenceWindowController.self, identifier: "PreferenceWindowController")
  }
  internal enum UserWindowController: StoryboardType {
    internal static let storyboardName = "UserWindowController"

    internal static let initialScene = InitialSceneType<Hakumai.UserWindowController>(storyboard: UserWindowController.self)

    internal static let userWindowController = SceneType<Hakumai.UserWindowController>(storyboard: UserWindowController.self, identifier: "UserWindowController")
  }
}
// swiftlint:enable explicit_type_interface identifier_name line_length type_body_length type_name

// MARK: - Implementation Details

internal protocol StoryboardType {
  static var storyboardName: String { get }
}

internal extension StoryboardType {
  static var storyboard: NSStoryboard {
    let name = NSStoryboard.Name(self.storyboardName)
    return NSStoryboard(name: name, bundle: BundleToken.bundle)
  }
}

internal struct SceneType<T> {
  internal let storyboard: StoryboardType.Type
  internal let identifier: String

  internal func instantiate() -> T {
    let identifier = NSStoryboard.SceneIdentifier(self.identifier)
    guard let controller = storyboard.storyboard.instantiateController(withIdentifier: identifier) as? T else {
      fatalError("Controller '\(identifier)' is not of the expected class \(T.self).")
    }
    return controller
  }

  @available(macOS 10.15, *)
  internal func instantiate(creator block: @escaping (NSCoder) -> T?) -> T where T: NSViewController {
    let identifier = NSStoryboard.SceneIdentifier(self.identifier)
    return storyboard.storyboard.instantiateController(identifier: identifier, creator: block)
  }

  @available(macOS 10.15, *)
  internal func instantiate(creator block: @escaping (NSCoder) -> T?) -> T where T: NSWindowController {
    let identifier = NSStoryboard.SceneIdentifier(self.identifier)
    return storyboard.storyboard.instantiateController(identifier: identifier, creator: block)
  }
}

internal struct InitialSceneType<T> {
  internal let storyboard: StoryboardType.Type

  internal func instantiate() -> T {
    guard let controller = storyboard.storyboard.instantiateInitialController() as? T else {
      fatalError("Controller is not of the expected class \(T.self).")
    }
    return controller
  }

  @available(macOS 10.15, *)
  internal func instantiate(creator block: @escaping (NSCoder) -> T?) -> T where T: NSViewController {
    guard let controller = storyboard.storyboard.instantiateInitialController(creator: block) else {
      fatalError("Storyboard \(storyboard.storyboardName) does not have an initial scene.")
    }
    return controller
  }

  @available(macOS 10.15, *)
  internal func instantiate(creator block: @escaping (NSCoder) -> T?) -> T where T: NSWindowController {
    guard let controller = storyboard.storyboard.instantiateInitialController(creator: block) else {
      fatalError("Storyboard \(storyboard.storyboardName) does not have an initial scene.")
    }
    return controller
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
