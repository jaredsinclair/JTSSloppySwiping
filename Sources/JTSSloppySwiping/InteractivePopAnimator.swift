import UIKit

let defaultCancelPopDuration: TimeInterval = 0.16
let maxBackViewTranslationPercentage: CGFloat = 0.30
let minimumDismissalPercentage: CGFloat = 0.5
let minimumThresholdVelocity: CGFloat = 100.0

@MainActor final class InteractivePopAnimator: NSObject, UIViewControllerAnimatedTransitioning, UIViewControllerInteractiveTransitioning {

    // MARK: Fileprivate Properties

    var translation: CGPoint = CGPoint.zero {
        didSet {
            updateViewsWithTranslation(translation)
        }
    }

    // MARK: Private Properties

    private var activeContext: UIViewControllerContextTransitioning? = nil
    private var activeDuration: TimeInterval? = nil

    private let backOverlayView: UIView = {
        let backOverlayView = UIView(frame: CGRect.zero)
        backOverlayView.backgroundColor = UIColor(white: 0.0, alpha: 0.1)
        backOverlayView.alpha = 1.0
        return backOverlayView
        }()

    private let frontContainerView: FrontContainerView = {
        return FrontContainerView(frame: CGRect.zero)
    }()

    // MARK: UIViewControllerAnimatedTransitioning

    @objc func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        if let duration = activeDuration {
            return duration
        }
        return 0
    }

    @objc func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        fatalError("this class should not be used for non-interactive transitions")
    }

    // MARK: UIViewControllerInteractiveTransitioning

    @objc func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning) {
        activeContext = transitionContext
        prepForPop()
    }

    // MARK: File Private Methods

    func shouldCancelForGestureEndingWithTranslation(_ translation: CGPoint, velocity: CGPoint) -> Bool {

        guard let transitionContext = activeContext else {
            return false
        }

        let velocity = RTL ? velocity.flippingX : velocity
        let translation = RTL ? translation.flippingX : translation

        let container = transitionContext.containerView
        let percent = percentDismissedForTranslation(translation, container: container)

        return ((percent < minimumDismissalPercentage && velocity.x < 100.0) || velocity.x < 0)
    }

    func cancelWithTranslation(_ translation: CGPoint, velocity: CGPoint, completion: @escaping () -> Void) {

        guard let transitionContext = activeContext,
            let fromView = transitionContext.view(forKey: UITransitionContextViewKey.from),
            let toView = transitionContext.view(forKey: UITransitionContextViewKey.to) else {
                return
        }

        let velocity = RTL ? velocity.flippingX : velocity
        let translation = RTL ? translation.flippingX : translation

        let container = transitionContext.containerView

        let maxDistance = container.bounds.size.width
        let maxToViewOffset = maxDistance * maxBackViewTranslationPercentage
        let resolvedToViewOffset = min(0, -maxToViewOffset) // Damn you, AutoLayout!
        let duration: TimeInterval
        let options: UIView.AnimationOptions

        if abs(velocity.x) > minimumThresholdVelocity {
            options = .curveEaseOut
            let naiveDuration = durationForDistance(distance: maxDistance, velocity: abs(velocity.x))
            let isFlickingShutEarly = translation.x < maxDistance * minimumDismissalPercentage
            if (naiveDuration > defaultCancelPopDuration && isFlickingShutEarly) {
                duration = defaultCancelPopDuration
            } else {
                duration = naiveDuration
            }
        }
        else {
            options = UIView.AnimationOptions()
            duration = defaultCancelPopDuration
        }

        activeDuration = duration

        activeContext?.cancelInteractiveTransition()

        UIView.animate(withDuration: duration, delay: 0, options: options, animations: { () -> Void in
            self.frontContainerView.transform = .identity
            let translationX = RTL ? -resolvedToViewOffset : resolvedToViewOffset
            toView.transform = CGAffineTransform(translationX: translationX, y: 0)
            self.backOverlayView.alpha = 1.0
            self.frontContainerView.dropShadowAlpha = 1.0
        }, completion: { completed -> Void in
            toView.transform = .identity
            toView.left = 0 // Damn you, AutoLayout!
            container.addSubview(fromView)
            self.backOverlayView.removeFromSuperview()
            self.frontContainerView.removeFromSuperview()
            self.activeContext?.completeTransition(false)
            completion()
        })

    }

    func finishWithTranslation(_ translation: CGPoint, velocity: CGPoint, completion: @escaping () -> Void) {

        guard let transitionContext = activeContext,
            let fromView = transitionContext.view(forKey: UITransitionContextViewKey.from),
            let toView = transitionContext.view(forKey: UITransitionContextViewKey.to) else {
                return
        }

        let velocity = RTL ? velocity.flippingX : velocity
        let _ = RTL ? translation.flippingX : translation

        let container = transitionContext.containerView

        let maxDistance = container.bounds.size.width
        let duration: TimeInterval

        // Like a push mower, this gesture completion feels more
        // comfortable with a little added velocity.
        var comfortVelocity = velocity
        comfortVelocity.x *= 2.0

        let options: UIView.AnimationOptions
        if abs(comfortVelocity.x) > 0 {
            options = .curveEaseOut
            duration = durationForDistance(distance: maxDistance, velocity: abs(comfortVelocity.x))
        }
        else {
            options = UIView.AnimationOptions()
            duration = defaultCancelPopDuration
        }

        activeDuration = duration

        activeContext?.finishInteractiveTransition()

        UIView.animate(withDuration: duration, delay: 0, options: options, animations: { () -> Void in
            let translationX = RTL ? -maxDistance : maxDistance
            self.frontContainerView.transform = CGAffineTransform(
                translationX: translationX, y: 0
            )
            toView.transform = .identity
            toView.left = 0 // Damn you, AutoLayout!
            self.backOverlayView.alpha = 0.0
            self.frontContainerView.dropShadowAlpha = 0.0
        }, completion: { completed -> Void in
            fromView.removeFromSuperview()
            self.frontContainerView.transform = .identity
            self.frontContainerView.removeFromSuperview()
            self.backOverlayView.removeFromSuperview()
            self.activeContext?.completeTransition(true)
            completion()
        })

    }

    // MARK: Private Methods

    private func prepForPop() {

        guard let transitionContext = activeContext,
            let fromView = transitionContext.view(forKey: UITransitionContextViewKey.from),
            let toView = transitionContext.view(forKey: UITransitionContextViewKey.to) else {
                return
        }

        let container = transitionContext.containerView
        let containerBounds = container.bounds

        frontContainerView.frame = containerBounds

        let maxOffset = containerBounds.size.width * maxBackViewTranslationPercentage

        fromView.frame = frontContainerView.bounds
        frontContainerView.addSubview(fromView)
        frontContainerView.transform = CGAffineTransform.identity

        toView.frame = containerBounds
        let translationX = RTL ? maxOffset : -maxOffset
        toView.transform = CGAffineTransform(translationX: translationX, y: 0)

        backOverlayView.frame = containerBounds

        container.addSubview(toView)
        container.addSubview(backOverlayView)
        container.addSubview(frontContainerView)
    }

    private func updateViewsWithTranslation(_ translation: CGPoint) {

        guard let transitionContext = activeContext,
            let toView = transitionContext.view(forKey: UITransitionContextViewKey.to) else {
                return
        }

        let translation = RTL ? translation.flippingX : translation

        let container = transitionContext.containerView
        let maxDistance = container.bounds.size.width
        let percent = percentDismissedForTranslation(translation, container: container)

        let maxFromViewOffset = maxDistance

        let maxToViewOffset = maxDistance * maxBackViewTranslationPercentage
        let frontTranslationX = (RTL ? -maxFromViewOffset : maxFromViewOffset) * percent
        let resolvedToViewOffset = -maxToViewOffset + (maxToViewOffset * percent)
        let backTranslationX = RTL ? -resolvedToViewOffset : resolvedToViewOffset

        frontContainerView.transform = CGAffineTransform(translationX: frontTranslationX, y: 0)
        frontContainerView.dropShadowAlpha = (1.0 - percent)
        toView.transform = CGAffineTransform(translationX: backTranslationX, y: 0)
        backOverlayView.alpha = (1.0 - percent)

        activeContext?.updateInteractiveTransition(percent)
    }

    private func percentDismissedForTranslation(_ translation: CGPoint, container: UIView) -> CGFloat {
        let maxDistance = container.bounds.size.width
        return (min(maxDistance, max(0, translation.x))) / maxDistance
    }

    private func durationForDistance(distance d: CGFloat, velocity v: CGFloat) -> TimeInterval {
        let minDuration: CGFloat = 0.08
        let maxDuration: CGFloat = 0.4
        return (TimeInterval)(max(min(maxDuration, d / v), minDuration))
    }

}
