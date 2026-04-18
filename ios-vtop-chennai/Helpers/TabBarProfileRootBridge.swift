import SwiftUI
import UIKit

/// When the Profile tab is selected (including re-tapping while already selected), calls `onSelectProfileTab` so the profile root can reset navigation (e.g. `.id` bump on `ProfileTabView`).
struct TabBarProfileRootBridge: UIViewRepresentable {
    let profileTabIndex: Int
    let onSelectProfileTab: () -> Void

    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        v.isUserInteractionEnabled = false
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.profileTabIndex = profileTabIndex
        context.coordinator.onSelectProfileTab = onSelectProfileTab
        context.coordinator.attachIfPossible(from: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UITabBarControllerDelegate {
        var profileTabIndex: Int = 3
        var onSelectProfileTab: () -> Void = {}
        private weak var tabBarController: UITabBarController?
        private weak var previousDelegate: UITabBarControllerDelegate?

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
                  idx == profileTabIndex else { return true }
            let action = onSelectProfileTab
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
