import UIKit

/// To use this, just initialize it and keep a strong reference to it. You don't
/// actually have to make it your navigation controller's delegate if you need
/// to use a different class for that purpose. Just forward the relevant
/// delegate methods to your sloppy swiping instance.
///
/// SloppySwiping handles interactive pop animations. Programmatic pop
/// animations and push animations are unaffected. An interactive pop can begin
/// with a horizontal panning gesture from anywhere in the content view
/// controller's view, not just the screen edge.
///
/// SloppySwiping works whether or not the navigation controller's navigation
/// bar is hidden (unlike the default screen edge interactive pop animation).
///
/// - Warning: Right-to-left interface layouts are not currently supported.
@MainActor public final class SloppySwiping: NSObject {

    // MARK: Init

    /// Designated initializer.
    ///
    /// - parameter navigationController: The target navigation controller to
    /// be managed. SloppySwiping stores a weak reference to the navigation
    /// controller.
    ///
    /// The init method will **not** set `self` as `navigationController`'s
    /// delegate. Although this was considered, it seemed preferable for the
    /// caller to explicitly set the sloppy swiping instance as the navigation
    /// controller's delegate since there may be applications that need to
    /// swap among two or more delegates, or forward methods from an existing
    /// delegate to the relevant methods on the sloppy swiping instance.
    public init(navigationController: UINavigationController) {
        self.interactivePopAnimator = InteractivePopAnimator()
        self.popRecognizer = UIPanGestureRecognizer()
        self.navigationController = navigationController
        super.init()
        self.popRecognizer.maximumNumberOfTouches = 1
        popRecognizer.addTarget(self, action: #selector(SloppySwiping.popRecognizerPanned(_:)))
        navigationController.view.addGestureRecognizer(popRecognizer)
    }

    // MARK: Private Properties

    private weak var navigationController: UINavigationController?

    private var isInteractivelyPopping: Bool = false

    private var interactivePopAnimator: InteractivePopAnimator

    private let popRecognizer: UIPanGestureRecognizer

    private var isAnimatingANonInteractiveTransition: Bool = false {
        didSet {
            popRecognizer.isEnabled = !isAnimatingANonInteractiveTransition
        }
    }

    // MARK: Private Methods

    @objc private func popRecognizerPanned(_ recognizer: UIPanGestureRecognizer) {

        guard let navigationController = navigationController else {return}
        guard recognizer == popRecognizer else {return}

        switch (recognizer.state) {

        case .began:
            if (!isAnimatingANonInteractiveTransition) {
                if (navigationController.viewControllers.count > 1) {
                    isInteractivelyPopping = true
                    _ = self.navigationController?.popViewController(animated: true)
                }
            }

        case .changed:
            if (!isAnimatingANonInteractiveTransition
                && isInteractivelyPopping) {
                let view = navigationController.view
                let t = recognizer.translation(in: view)
                interactivePopAnimator.translation = t
            }

        case .ended, .cancelled:
            if (!isAnimatingANonInteractiveTransition
                && isInteractivelyPopping) {
                isAnimatingANonInteractiveTransition = true
                let animator = interactivePopAnimator
                let view = navigationController.view
                let t = recognizer.translation(in: view)
                let v = recognizer.velocity(in: view)
                if animator.shouldCancelForGestureEndingWithTranslation(t, velocity: v) {
                    animator.cancelWithTranslation(t, velocity: v) {
                        self.isInteractivelyPopping = false
                        self.isAnimatingANonInteractiveTransition = false
                    }
                } else {
                    animator.finishWithTranslation(t, velocity: v) {
                        self.isInteractivelyPopping = false
                        self.isAnimatingANonInteractiveTransition = false
                    }
                }
            }

        default: break

        }
    }

}

extension SloppySwiping: UINavigationControllerDelegate {

    // MARK: UINavigationControllerDelegate

    public func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if (isInteractivelyPopping && operation == .pop) {
            return interactivePopAnimator
        }
        return nil
    }

    public func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        if (isInteractivelyPopping) {
            return interactivePopAnimator
        }
        return nil
    }

}

