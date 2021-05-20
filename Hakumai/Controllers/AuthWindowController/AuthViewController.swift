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
        // guard let url = navigationAction.request.url else { return }
        // log.debug(url)
        decisionHandler(.allow)
    }
}

private extension AuthViewController {
    func configureView() {
        webView.navigationDelegate = self
    }
}
