// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

#if os(macOS)
  import AppKit
#elseif os(iOS)
  import UIKit
#elseif os(tvOS) || os(watchOS)
  import UIKit
#endif

// Deprecated typealiases
@available(*, deprecated, renamed: "ImageAsset.Image", message: "This typealias will be removed in SwiftGen 7.0")
internal typealias AssetImageTypeAlias = ImageAsset.Image

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Asset Catalogs

// swiftlint:disable identifier_name line_length nesting type_body_length type_name
internal enum Asset {
  internal static let defaultLiveThumbnailImage = ImageAsset(name: "DefaultLiveThumbnailImage")
  internal static let defaultUserImage = ImageAsset(name: "DefaultUserImage")
  internal static let adPoints = ImageAsset(name: "ad_points")
  internal static let commentCount = ImageAsset(name: "comment_count")
  internal static let giftPoints = ImageAsset(name: "gift_points")
  internal static let visitorCount = ImageAsset(name: "visitor_count")
  internal static let linkBlack = ImageAsset(name: "link_black")
  internal static let militaryTechBlack = ImageAsset(name: "military_tech_black")
  internal static let peopleBlack = ImageAsset(name: "people_black")
  internal static let playArrowBlack = ImageAsset(name: "play_arrow_black")
  internal static let scheduleBlack = ImageAsset(name: "schedule_black")
  internal static let stopBlack = ImageAsset(name: "stop_black")
  internal static let premiumIppan = ImageAsset(name: "PremiumIppan")
  internal static let premiumMisc = ImageAsset(name: "PremiumMisc")
  internal static let premiumPremium = ImageAsset(name: "PremiumPremium")
  internal static let arrowDownwardBlack = ImageAsset(name: "arrow_downward_black")
  internal static let arrowUpwardBlack = ImageAsset(name: "arrow_upward_black")
  internal static let handleNameOver184Id = ImageAsset(name: "HandleNameOver184Id")
  internal static let handleNameOverRawId = ImageAsset(name: "HandleNameOverRawId")
  internal static let userId184Id = ImageAsset(name: "UserId184Id")
  internal static let userIdRawId = ImageAsset(name: "UserIdRawId")
}
// swiftlint:enable identifier_name line_length nesting type_body_length type_name

// MARK: - Implementation Details

internal struct ImageAsset {
  internal fileprivate(set) var name: String

  #if os(macOS)
  internal typealias Image = NSImage
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  internal typealias Image = UIImage
  #endif

  @available(iOS 8.0, tvOS 9.0, watchOS 2.0, macOS 10.7, *)
  internal var image: Image {
    let bundle = BundleToken.bundle
    #if os(iOS) || os(tvOS)
    let image = Image(named: name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    let name = NSImage.Name(self.name)
    let image = (bundle == .main) ? NSImage(named: name) : bundle.image(forResource: name)
    #elseif os(watchOS)
    let image = Image(named: name)
    #endif
    guard let result = image else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }

  #if os(iOS) || os(tvOS)
  @available(iOS 8.0, tvOS 9.0, *)
  internal func image(compatibleWith traitCollection: UITraitCollection) -> Image {
    let bundle = BundleToken.bundle
    guard let result = Image(named: name, in: bundle, compatibleWith: traitCollection) else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }
  #endif
}

internal extension ImageAsset.Image {
  @available(iOS 8.0, tvOS 9.0, watchOS 2.0, *)
  @available(macOS, deprecated,
    message: "This initializer is unsafe on macOS, please use the ImageAsset.image property")
  convenience init?(asset: ImageAsset) {
    #if os(iOS) || os(tvOS)
    let bundle = BundleToken.bundle
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    self.init(named: NSImage.Name(asset.name))
    #elseif os(watchOS)
    self.init(named: asset.name)
    #endif
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
