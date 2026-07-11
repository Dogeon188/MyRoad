//
//  ShareViewController.swift
//  ImportJson
//
//  Created by Dogeon on 2026/7/11.
//
//  Not based on RSIShareViewController: that base class classifies attachments
//  by iterating image/video/text/url/file in that order, and JSON (and other
//  text-conformant) files match "public.text" before "public.file-url" -
//  which silently drops the share instead of importing it. It's also built on
//  SLComposeServiceViewController, which always shows a text box + Post
//  button; we want the file handed straight to the host app with no prompt.

import UIKit
import UniformTypeIdentifiers
import receive_sharing_intent

class ShareViewController: UIViewController {
    private lazy var hostAppBundleIdentifier: String = {
        let id = Bundle.main.bundleIdentifier ?? ""
        guard let lastDot = id.lastIndex(of: ".") else { return id }
        return String(id[..<lastDot])
    }()

    private lazy var appGroupId: String = {
        (Bundle.main.object(forInfoDictionaryKey: kAppGroupIdKey) as? String)
            ?? "group.\(hostAppBundleIdentifier)"
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        importSharedFile()
    }

    private func importSharedFile() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachment = item.attachments?.first,
              attachment.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        else {
            complete()
            return
        }
        attachment.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { [weak self] data, error in
            guard let self, error == nil, let url = data as? URL else {
                self?.complete()
                return
            }
            self.saveAndRedirect(fileAt: url)
        }
    }

    private func saveAndRedirect(fileAt url: URL) {
        guard
            let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupId
            )
        else {
            complete()
            return
        }

        let destination = container.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: destination)
        guard (try? FileManager.default.copyItem(at: url, to: destination)) != nil else {
            complete()
            return
        }

        let mediaType: SharedMediaType =
            url.pathExtension.lowercased() == "png" ? .image : .file
        let file = SharedMediaFile(
            path: destination.absoluteString.removingPercentEncoding ?? destination.path,
            mimeType: url.mimeType(),
            type: mediaType
        )
        let encoded = try? JSONEncoder().encode([file])
        UserDefaults(suiteName: appGroupId)?.set(encoded, forKey: kUserDefaultsKey)

        complete(shouldRedirect: true)
    }

    private func complete(shouldRedirect: Bool = false) {
        if shouldRedirect,
            let url = URL(string: "\(kSchemePrefix)-\(hostAppBundleIdentifier):share")
        {
            var responder: UIResponder? = self
            if #available(iOS 18.0, *) {
                while responder != nil {
                    if let application = responder as? UIApplication {
                        application.open(url, options: [:], completionHandler: nil)
                    }
                    responder = responder?.next
                }
            } else {
                let openSelector = sel_registerName("openURL:")
                while responder != nil {
                    if responder?.responds(to: openSelector) == true {
                        _ = responder?.perform(openSelector, with: url)
                    }
                    responder = responder?.next
                }
            }
        }
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
