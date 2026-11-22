import UIKit
import WebKit

/// 智学伴 iOS 壳：WKWebView 加载线上站点。
/// 与 Android 壳对齐：同一地址、同一 UA 标识（ZhiXueBanApp），
/// 前端据此加 .zxb-app class（压 PC 壳 + iPad 走手机布局）。
class MainViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {

    static let appURL = "https://xue.zhijiyy.com/"
    /// iOS 用 /7 与安卓 /6 区分；前端只匹配 ZhiXueBanApp 前缀，行为一致
    static let uaSuffix = " ZhiXueBanApp/7 (iOS)"

    private var webView: WKWebView!
    private var progressView: UIProgressView!
    private var progressObs: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        let config = WKWebViewConfiguration()
        // 允许 inline 播放（课件视频），允许 JS 打开新窗由本壳接管
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        // UA 追加 APP 标识：前端据此进入 APP 模式
        webView.customUserAgent = defaultUA() + Self.uaSuffix

        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        // 顶部加载进度条
        progressView = UIProgressView(progressViewStyle: .bar)
        progressView.progressTintColor = UIColor(red: 0.11, green: 0.55, blue: 0.35, alpha: 1)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressView)
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2)
        ])
        progressObs = webView.observe(\.estimatedProgress, options: .new) { [weak self] _, _ in
            guard let self = self else { return }
            self.progressView.progress = Float(self.webView.estimatedProgress)
            self.progressView.isHidden = self.webView.estimatedProgress >= 1.0
        }

        loadFresh()
    }

    /// 与 Android freshUrl() 对齐：加时间戳绕开缓存，服务端改前端后立即可见
    private func loadFresh() {
        let sep = Self.appURL.contains("?") ? "&" : "?"
        let url = Self.appURL + sep + "_t=" + String(Int(Date().timeIntervalSince1970))
        webView.load(URLRequest(url: URL(string: url)!))
    }

    private func defaultUA() -> String {
        // 取一个标准 Safari UA 作为基底，再追加标识
        let ver = UIDevice.current.systemVersion
        let model = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        return "Mozilla/5.0 (\(model); CPU \(model) OS \(ver.replacingOccurrences(of: ".", with: "_")) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(ver) Mobile/15E148 Safari/604.1"
    }

    // MARK: - 外链拦截：站内继续在壳内打开，站外跳系统浏览器
    private func isInternal(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        return host == "xue.zhijiyy.com" || host.hasSuffix(".zhijiyy.com")
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow); return
        }
        if url.scheme == "http" || url.scheme == "https" {
            if isInternal(url) {
                decisionHandler(.allow)
            } else {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                decisionHandler(.cancel)
            }
        } else if url.scheme == "tel" || url.scheme == "mailto" {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    /// target=_blank / window.open 的弹窗：站内直接在当前 WebView 打开
    func webView(_ webView: WKWebView,
                 createWebViewWithConfiguration configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url, isInternal(url) {
            webView.load(URLRequest(url: url))
        } else if let url = navigationAction.request.url {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progressView.isHidden = true
    }

    // JS 弹窗（alert/confirm）转成原生，避免 WKWebView 默认不显示
    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let ac = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "好", style: .default) { _ in completionHandler() })
        present(ac, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let ac = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in completionHandler(false) })
        ac.addAction(UIAlertAction(title: "确定", style: .default) { _ in completionHandler(true) })
        present(ac, animated: true)
    }

    override var prefersStatusBarHidden: Bool { return false }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { return .all }
}
