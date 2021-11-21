//
//  NotificationPresenter.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/11/21.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import AppKit
import Foundation
import UserNotifications
import Alamofire

private let userInfoLiveProgramIdKey = "userInfoLiveProgramIdKey"

protocol NotificationPresenterProtocol: AnyObject {
    var notificationClicked: ((_ liveProgramId: String) -> Void)? { get set }

    func configure()
    func show(title: String?, body: String?, liveProgramId: String?, jpegImageUrl: URL?)
}

final class NotificationPresenter: NSObject, NotificationPresenterProtocol {
    private lazy var session: Session = {
        let configuration = URLSessionConfiguration.af.default
        configuration.headers.add(.userAgent(commonUserAgentValue))
        return Session(configuration: configuration)
    }()

    var notificationClicked: ((_ liveProgramId: String) -> Void)?

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

    func show(title: String?, body: String?, liveProgramId: String?, jpegImageUrl: URL?) {
        guard let imageUrl = jpegImageUrl else {
            _show(title: title, body: body, liveProgramId: liveProgramId, imageData: nil)
            return
        }
        session.request(imageUrl)
            .cURLDescription(calling: { log.debug($0) })
            .validate()
            .responseData { [weak self] in
                switch $0.result {
                case .success(let data):
                    self?._show(
                        title: title,
                        body: body,
                        liveProgramId: liveProgramId,
                        // imageUrl.lastPathComponent is like "co5356526.jpg"
                        imageData: ImageData(data: data, identifier: imageUrl.lastPathComponent)
                    )
                case .failure(let error):
                    log.error(error)
                }
            }
    }
}

private struct ImageData {
    let data: Data
    let identifier: String
}

private extension NotificationPresenter {
    func _show(title: String?, body: String?, liveProgramId: String?, imageData: ImageData?) {
        guard #available(macOS 10.14, *) else { return }
        let content = UNMutableNotificationContent.make(
            title: title, body: body, liveProgramId: liveProgramId, imageData: imageData)
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

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        guard let liveProgramId = response.notification.request.content.userInfo[userInfoLiveProgramIdKey] as? String else {
            completionHandler()
            return
        }
        notificationClicked?(liveProgramId)
        completionHandler()
    }
}

extension NotificationPresenter {
    static let `default` = NotificationPresenter()
}

@available(macOS 10.14, *)
private extension UNMutableNotificationContent {
    static func make(title: String?, body: String?, liveProgramId: String?, imageData: ImageData?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        if let title = title {
            content.title = title
        }
        if let body = body {
            content.body = body
        }
        if let liveProgramId = liveProgramId {
            content.userInfo = [userInfoLiveProgramIdKey: liveProgramId]
        }
        if let imageData = imageData,
           let attachment = UNNotificationAttachment.create(imageData: imageData) {
            content.attachments = [attachment]
        }
        // content.interruptionLevel = .timeSensitive
        return content
    }
}

@available(macOS 10.14, *)
private extension UNNotificationAttachment {
    // Based on https://stackoverflow.com/a/39103096/13220031
    static func create(imageData: ImageData, options: [NSObject: AnyObject]? = nil) -> UNNotificationAttachment? {
        let fileManager = FileManager.default
        let tmpSubFolderName = ProcessInfo.processInfo.globallyUniqueString
        let tmpSubFolderUrl = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(tmpSubFolderName, isDirectory: true)
        do {
            try fileManager.createDirectory(
                at: tmpSubFolderUrl,
                withIntermediateDirectories: true,
                attributes: nil)
            let fileUrl = tmpSubFolderUrl.appendingPathComponent(imageData.identifier)
            log.debug(fileUrl)
            try imageData.data.write(to: fileUrl)
            let imageAttachment = try UNNotificationAttachment.init(
                identifier: imageData.identifier, url: fileUrl, options: options)
            return imageAttachment
        } catch {
            log.error(error.localizedDescription)
        }
        return nil
    }
}
