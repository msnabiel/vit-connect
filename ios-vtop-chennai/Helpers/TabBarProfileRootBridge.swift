import SwiftUI
import UIKit

/// When the user **re-taps** a tab that is already selected, runs that tab’s handler (e.g. bump `.id` to pop `NavigationStack` to root).
struct TabBarReselectBridge: UIViewRepresentable {
    /// Tab index → action (Home = 0, Profile = 3, etc.).
    let handlers: [Int: () -> Void]

    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        v.isUserInteractionEnabled = false
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.handlers = handlers
        context.coordinator.attachIfPossible(from: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(handlers: handlers)
    }

    final class Coordinator: NSObject, UITabBarControllerDelegate {
        var handlers: [Int: () -> Void]
        private weak var tabBarController: UITabBarController?
        private weak var previousDelegate: UITabBarControllerDelegate?

        init(handlers: [Int: () -> Void]) {
            self.handlers = handlers
        }

        deinit {
            tabBarController?.delegate = previousDelegate
        }

        func attachIfPossible(from view: UIView) {
            guard let tab = Self.findTabBar(from: view) else { return }
            tabBarController = tab
            if tab.delegate !== self {
                previousDelegate = tab.delegate as? UITabBarControllerDelegate
                tab.delegate = self
            }
        }

        private static func findTabBar(from view: UIView) -> UITabBarController? {
            if let root = view.window?.rootViewController {
                return findTabBar(in: root)
            }
            return nil
        }

        private static func findTabBar(in root: UIViewController?) -> UITabBarController? {
            guard let root else { return nil }
            if let t = root as? UITabBarController { return t }
            for child in root.children {
                if let t = findTabBar(in: child) { return t }
            }
            if let presented = root.presentedViewController {
                return findTabBar(in: presented)
            }
            return nil
        }

        func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
            let inner = previousDelegate?.tabBarController?(tabBarController, shouldSelect: viewController) ?? true
            guard inner else { return false }
            guard let idx = tabBarController.viewControllers?.firstIndex(of: viewController),
                  tabBarController.selectedViewController === viewController,
                  let action = handlers[idx] else { return true }
            DispatchQueue.main.async {
                action()
            }
            return true
        }

        func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
            previousDelegate?.tabBarController?(tabBarController, didSelect: viewController)
        }
    }
}
