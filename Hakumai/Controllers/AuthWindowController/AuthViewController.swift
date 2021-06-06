//
//  AuthViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/20.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Cocoa
import WebKit

private let hakumaiAppUrlScheme = "hakumai"
private let accessTokenParameterName = "response"

final class AuthViewController: NSViewController {
    // MARK: - Properties
    @IBOutlet private weak var webView: WKWebView!

    private var authManager: AuthManagerProtocol!
}

extension AuthViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        authManager = AuthManager.shared
    }
}

extension AuthViewController {
    func startAuthorization() {
        let request = URLRequest(url: authManager.authWebUrl)
        webView.load(request)
    }
}

extension AuthViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { return }
        // log.debug(url)
        if url.scheme == hakumaiAppUrlScheme {
            extractCallbackResponse(from: url)
            decisionHandler(.cancel)
            closeWindow()
            return
        }
        decisionHandler(.allow)
    }
}

private extension AuthViewController {
    func configureView() {
        webView.navigationDelegate = self
    }

    func extractCallbackResponse(from url: URL) {
        guard let response = url.queryValue(for: accessTokenParameterName) else { return }
        // log.debug(response)
        authManager.extractCallbackResponseAndSaveToken(response: response) {
            log.debug($0)
            switch $0 {
            case .success(_):
                // TODO: Notify token completion to caller.
                break
            case .failure(let error):
                log.error(error)
            }
        }
    }

    func closeWindow() {
        view.window?.close()
    }
}

private extension URL {
    // https://qiita.com/shtnkgm/items/0f69d8000f10bdf7cbe2
    func queryValue(for key: String) -> String? {
        let queryItems = URLComponents(string: absoluteString)?.queryItems
        return queryItems?.filter { $0.name == key }.compactMap { $0.value }.first
    }
}
