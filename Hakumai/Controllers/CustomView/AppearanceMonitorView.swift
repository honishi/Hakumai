//
//  AppearanceMonitorView.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2022/01/05.
//  Copyright © 2022 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

// Based on https://qiita.com/hituziando/items/f870e67dfb41e0b3b7bb .
final class AppearanceMonitorView: NSView {
    private var onAppearanceChanged: (() -> Void)?

    public static func make(onAppearanceChanged: @escaping () -> Void) -> AppearanceMonitorView {
        let view = AppearanceMonitorView(frame: .zero)
        view.onAppearanceChanged = onAppearanceChanged
        return view
    }

    override func viewDidMoveToSuperview() {
        let added = superview != nil
        log.debug("[\(self.className)] Monitoring \(added ? "started" : "stopped").")
    }

    @available(OSX 10.14, *)
    override func viewDidChangeEffectiveAppearance() {
        onAppearanceChanged?()
    }
}
