import SwiftUI
import UIKit

/// Hosts the SwiftUI share sheet. Phase 6 turns shared links, addresses and
/// text into events and list items.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let root = ShareRootView { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }
}

struct ShareRootView: View {
    let done: () -> Void

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Add to Family", systemImage: "house")
            } description: {
                Text("Saving shared links and text to your family calendar and lists is coming soon.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark", role: .cancel, action: done)
                }
            }
        }
    }
}
