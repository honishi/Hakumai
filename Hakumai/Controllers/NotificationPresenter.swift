//
//  NotificationPresenter.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/11/21.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import UserNotifications

protocol NotificationPresenterProtocol {
    func configure()
    func show(title: String?, body: String?)
}

final class NotificationPresenter: NSObject, NotificationPresenterProtocol {
    func configure() {
        guard #available(macOS 10.14, *) else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.sound, .alert]) {
            if let error = $1 {
                log.error(error)
                return
            }
            // No-op.
        }
    }

    func show(title: String?, body: String?) {
        DispatchQueue.main.async { self._show(title: title, body: body) }
    }

    func _show(title: String?, body: String?) {
        guard #available(macOS 10.14, *) else { return }
        let content = UNMutableNotificationContent.make(title: title, body: body)
        let uuidString = UUID().uuidString
        let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) {
            if let error = $0 {
                log.error(error)
                return
            }
            // No-op.
        }
    }
}

@available(macOS 10.14, *)
extension NotificationPresenter: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound])
    }
}

extension NotificationPresenter {
    static let `default` = NotificationPresenter()
}

@available(macOS 10.14, *)
private extension UNMutableNotificationContent {
    static func make(title: String?, body: String?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        if let title = title {
            content.title = title
        }
        if let body = body {
            content.body = body
        }
        if #available(macOS 12.0, *) {
            // content.interruptionLevel = .timeSensitive
        }
        return content
    }
}
