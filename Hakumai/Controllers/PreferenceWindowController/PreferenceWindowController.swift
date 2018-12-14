//
//  PreferenceWindowController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/9/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

// constant value for storyboard
private let kStoryboardNamePreferenceWindowController = "PreferenceWindowController"
private let kStoryboardIdPreferenceWindowController = "PreferenceWindowController"

private let kToolbarItemIdentifierGeneral = "GeneralToolbarItem"
private let kToolbarItemIdentifierMute = "MuteToolbarItem"

class PreferenceWindowController: NSWindowController {
    // MARK: - Properties
    static let shared = PreferenceWindowController.generateInstance()

    @IBOutlet weak var toolbar: NSToolbar!

    // MARK: Properties for Singleton
    static func generateInstance() -> PreferenceWindowController {
        let storyboard = NSStoryboard(name: kStoryboardNamePreferenceWindowController, bundle: nil)
        let preferenceWindowController = storyboard.instantiateController(withIdentifier: kStoryboardIdPreferenceWindowController) as! PreferenceWindowController

        preferenceWindowController.window?.center()

        return preferenceWindowController
    }

    // MARK: - Object Lifecycle
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        logger.debug("")
    }

    // MARK: - NSObject Overrides
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    // MARK: - NSWindowController Overrides
    override func windowDidLoad() {
        changeContent(viewController: GeneralViewController.shared, itemIdentifier: kToolbarItemIdentifierGeneral)

        window?.center()
        window?.makeKey()
    }

    // MARK: - NSToolbar Handlers
    @IBAction func changeViewController(_ sender: AnyObject) {
        let toolbarItem = (sender as! NSToolbarItem)
        var viewController: NSViewController?

        switch convertFromNSToolbarItemIdentifier(toolbarItem.itemIdentifier) {
        case kToolbarItemIdentifierGeneral:
            viewController = GeneralViewController.shared

        case kToolbarItemIdentifierMute:
            viewController = MuteViewController.shared

        default:
            break
        }

        if let controller = viewController {
            changeContent(viewController: controller, itemIdentifier: convertFromNSToolbarItemIdentifier(toolbarItem.itemIdentifier))
        }
    }

    // MARK: - Internal Functions

    // MARK: Content View Utility
    // based on this implementation;
    // https://github.com/sequelpro/sequelpro/blob/fd3ff51dc624be5ce645ce25eb72d03e5a359416/Source/SPPreferenceController.m#L248
    private func changeContent(viewController: NSViewController, itemIdentifier: String) {
        if let subViews = window?.contentView?.subviews {
            for subView in subViews {
                subView.removeFromSuperview()
            }
        }

        window?.contentView?.addSubview(viewController.view)
        resizeWindowForContentView(view: viewController.view)

        toolbar.selectedItemIdentifier = convertToOptionalNSToolbarItemIdentifier(itemIdentifier)
    }

    private func resizeWindowForContentView(view: NSView) {
        let viewSize = view.frame.size
        var frame = window!.frame

        let titleHeight: CGFloat = 22
        let resizedHeight = viewSize.height + titleHeight + toolbarHeight()

        frame.origin.y += frame.size.height - resizedHeight
        frame.size.height = resizedHeight
        frame.size.width = viewSize.width

        window?.setFrame(frame, display: true, animate: true)
    }

    private func toolbarHeight() -> CGFloat {
        var toolbarHeight: CGFloat = 0

        if toolbar != nil && toolbar.isVisible {
            let windowFrame = NSWindow.contentRect(forFrameRect: window!.frame, styleMask: window!.styleMask)
            toolbarHeight = windowFrame.height - NSHeight(window!.contentView!.frame)
        }

        return toolbarHeight
    }
}

// Helper function inserted by Swift 4.2 migrator.
private func convertFromNSToolbarItemIdentifier(_ input: NSToolbarItem.Identifier) -> String {
    return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
private func convertToOptionalNSToolbarItemIdentifier(_ input: String?) -> NSToolbarItem.Identifier? {
    guard let input = input else { return nil }
    return NSToolbarItem.Identifier(rawValue: input)
}
