//
//  AuthViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 2021/05/20.
//  Copyright © 2021 Hiroyuki Onishi. All rights reserved.
//

import Cocoa
import WebKit

private let hakumaiClientId = "FYtgnF18kxhSwNY2"
private let authWebBaseUrl = "https://oauth.nicovideo.jp"
private let authWebPath = "/oauth2/authorize?response_type=code&client_id=\(hakumaiClientId)"
private let hakumaiUrlScheme = "hakumai"
private let accessTokenParameterName = "response"

final class AuthViewController: NSViewController {
    // MARK: - Properties
    @IBOutlet private weak var webView: WKWebView!
}

extension AuthViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }
}

extension AuthViewController {
    func startAuthorization() {
        guard let url = URL(string: authWebBaseUrl + authWebPath) else { return }
        let request = URLRequest(url: url)
        webView.load(request)
    }
}

extension AuthViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { return }
        // log.debug(url)
        if url.scheme == hakumaiUrlScheme {
            extractAccessToken(url: url)
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

    func extractAccessToken(url: URL) {
        guard let response = url.queryValue(for: accessTokenParameterName) else { return }
        log.debug(response)
        // TODO: extract response value and store
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
