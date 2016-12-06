//
//  JTSSloppySwiping.swift
//  JTSSloppySwiping
//
//  Created by Jared Sinclair on 8/1/15.
//  Copyright © 2015 Nice Boy LLC. All rights reserved.
//

import UIKit

/// This is a convenience subclass, which relieves you of the burden of keeping 
/// a strong reference to the required SloppySwiping instance. You can use any
/// other navigation controller if you wish, but you'll be responsible for
/// initializing SloppySwiping instance, setting it as the navigation
/// controller's delegate (or forwarding the relevant methods from an existing
/// delegate), and keeping a strong reference to the SloppySwiping instance.
@objc(JTSSloppyNavigationController)
open class SloppyNavigationController: UINavigationController {
    
    // MARK: Private Properties
    
    private lazy var sloppySwiping: SloppySwiping = {
        return SloppySwiping(navigationController: self)
    }()
    
    // MARK: UIViewController
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        delegate = sloppySwiping
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        delegate = sloppySwiping
    }
    
    // MARK: UINavigationController
    
    public override init(navigationBarClass: AnyClass?, toolbarClass: AnyClass?) {
        super.init(navigationBarClass: navigationBarClass, toolbarClass: toolbarClass)
        delegate = sloppySwiping
    }
    
    public override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        delegate = sloppySwiping
    }
    
}

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
@objc(JTSSloppySwiping)
public final class SloppySwiping: NSObject {
    
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
        popRecognizer.addTarget(self, action: #selector(SloppySwiping.popRecognizerPanned(_:)))
        navigationController.view.addGestureRecognizer(popRecognizer)
    }
    
    // MARK: Fileprivate Properties
    
    fileprivate weak var navigationController: UINavigationController?
    fileprivate var isInteractivelyPopping: Bool = false
    fileprivate var interactivePopAnimator: InteractivePopAnimator
    fileprivate let popRecognizer: UIPanGestureRecognizer

    fileprivate var isAnimatingANonInteractiveTransition: Bool = false {
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
    
    public func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationControllerOperation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
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

fileprivate let defaultCancelPopDuration: TimeInterval = 0.16
fileprivate let maxBackViewTranslationPercentage: CGFloat = 0.30
fileprivate let minimumDismissalPercentage: CGFloat = 0.5
fileprivate let minimumThresholdVelocity: CGFloat = 100.0

@objc(JTSInteractivePopAnimator)
fileprivate final class InteractivePopAnimator: NSObject, UIViewControllerAnimatedTransitioning, UIViewControllerInteractiveTransitioning {
    
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
    
    fileprivate func shouldCancelForGestureEndingWithTranslation(_ translation: CGPoint, velocity: CGPoint) -> Bool {
        
        guard let transitionContext = activeContext else {
            return false
        }
        
        let container = transitionContext.containerView
        
        let percent = percentDismissedForTranslation(translation, container: container)
        
        return ((percent < minimumDismissalPercentage && velocity.x < 100.0) || velocity.x < 0)
    }
    
    fileprivate func cancelWithTranslation(_ translation: CGPoint, velocity: CGPoint, completion: @escaping () -> Void) {
        
        guard let transitionContext = activeContext,
            let fromView = transitionContext.view(forKey: UITransitionContextViewKey.from),
            let toView = transitionContext.view(forKey: UITransitionContextViewKey.to) else {
                return
        }
        
        let container = transitionContext.containerView
        
        let maxDistance = container.bounds.size.width
        let maxToViewOffset = maxDistance * maxBackViewTranslationPercentage
        let resolvedToViewOffset = -maxToViewOffset
        let duration: TimeInterval
        let options: UIViewAnimationOptions
        
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
            options = UIViewAnimationOptions()
            duration = defaultCancelPopDuration
        }
        
        activeDuration = duration
        
        activeContext?.cancelInteractiveTransition()
        
        UIView.animate(withDuration: duration,
                       delay: 0,
                       options: options,
                       animations: { () -> Void in
                        self.frontContainerView.transform = .identity
                        toView.transform = CGAffineTransform(translationX: resolvedToViewOffset, y: 0)
                        self.backOverlayView.alpha = 1.0
                        self.frontContainerView.dropShadowAlpha = 1.0
            },
                       completion: { (completed) -> Void in
                        toView.transform = .identity
                        container.addSubview(fromView)
                        self.backOverlayView.removeFromSuperview()
                        self.frontContainerView.removeFromSuperview()
                        self.activeContext?.completeTransition(false)
                        completion()
            }
        )
        
    }
    
    fileprivate func finishWithTranslation(_ translation: CGPoint, velocity: CGPoint, completion: @escaping () -> Void) {
        
        guard let transitionContext = activeContext,
            let fromView = transitionContext.view(forKey: UITransitionContextViewKey.from),
            let toView = transitionContext.view(forKey: UITransitionContextViewKey.to) else {
                return
        }
        
        let container = transitionContext.containerView
        
        let maxDistance = container.bounds.size.width
        let duration: TimeInterval
        
        // Like a push mower, this gesture completion feels more
        // comfortable with a little added velocity.
        var comfortVelocity = velocity
        comfortVelocity.x *= 2.0
        
        let options: UIViewAnimationOptions
        if abs(comfortVelocity.x) > 0 {
            options = .curveEaseOut
            duration = durationForDistance(distance: maxDistance, velocity: abs(comfortVelocity.x))
        }
        else {
            options = UIViewAnimationOptions()
            duration = defaultCancelPopDuration
        }
        
        activeDuration = duration
        
        activeContext?.finishInteractiveTransition()
        
        UIView.animate(withDuration: duration,
                       delay: 0,
                       options: options,
                       animations: { () -> Void in
                        self.frontContainerView.transform = CGAffineTransform(
                            translationX: maxDistance, y: 0
                        )
                        toView.transform = .identity
                        self.backOverlayView.alpha = 0.0
                        self.frontContainerView.dropShadowAlpha = 0.0
            },
                       completion: { (completed) -> Void in
                        fromView.removeFromSuperview()
                        self.frontContainerView.transform = .identity
                        self.frontContainerView.removeFromSuperview()
                        self.backOverlayView.removeFromSuperview()
                        self.activeContext?.completeTransition(true)
                        completion()
            }
        )
        
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
        toView.transform = CGAffineTransform(translationX: -maxOffset, y: 0)
        
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
        
        let container = transitionContext.containerView
        let maxDistance = container.bounds.size.width
        let percent = percentDismissedForTranslation(translation, container: container)

        let maxFromViewOffset = maxDistance

        let maxToViewOffset = maxDistance * maxBackViewTranslationPercentage
        let resolvedToViewOffset = -maxToViewOffset + (maxToViewOffset * percent)
        
        frontContainerView.transform = CGAffineTransform(translationX: maxFromViewOffset * percent, y: 0)
        frontContainerView.dropShadowAlpha = (1.0 - percent)
        toView.transform = CGAffineTransform(translationX: resolvedToViewOffset, y: 0)
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

@objc(JTSFrontContainerView)
fileprivate final class FrontContainerView: UIView {
    
    // MARK: Fileprivate Properties
    
    var dropShadowAlpha: CGFloat = 1 {
        didSet { dropShadowView.alpha = dropShadowAlpha }
    }
    
    // MARK: Private Properties
    
    private let dropShadowView: UIView
    
    // MARK: Init
    
    override init(frame: CGRect) {
        dropShadowView = FrontContainerView.newDropShadowView()
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        dropShadowView = FrontContainerView.newDropShadowView()
        super.init(coder: aDecoder)
        commonInit()
    }
    
    // MARK: Private Methods
    
    private func commonInit() {
        var dropShadowFrame = dropShadowView.frame
        dropShadowFrame.origin.x = 0 - dropShadowFrame.size.width
        dropShadowFrame.origin.y = 0
        dropShadowFrame.size.height = bounds.size.height
        dropShadowView.frame = dropShadowFrame
        addSubview(dropShadowView)
        clipsToBounds = false
        backgroundColor = UIColor.clear
    }
    
    private static func newDropShadowView() -> UIView {
        let w: CGFloat = 10.0
        
        let stretchableShadow = UIImageView(frame: CGRect(x: 0, y: 0, width: w, height: 1))
        stretchableShadow.backgroundColor = UIColor.clear
        stretchableShadow.alpha = 1.0
        stretchableShadow.contentMode = .scaleToFill
        stretchableShadow.autoresizingMask = [.flexibleHeight, .flexibleRightMargin]
        
        let contextSize = CGSize(width: w, height: 1)
        UIGraphicsBeginImageContextWithOptions(contextSize, false, 0)
        let context = UIGraphicsGetCurrentContext()
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors: [CGColor] = [
            UIColor(white: 0.0, alpha: 0.000).cgColor,
            UIColor(white: 0.0, alpha: 0.045).cgColor,
            UIColor(white: 0.0, alpha: 0.090).cgColor,
            UIColor(white: 0.0, alpha: 0.135).cgColor,
            UIColor(white: 0.0, alpha: 0.180).cgColor,
        ]
        let locations: [CGFloat] = [0.0, 0.34, 0.60, 0.80, 1.0]
        let options = CGGradientDrawingOptions()
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) {
            context?.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: w, y: 0), options: options)
            stretchableShadow.image = UIGraphicsGetImageFromCurrentImageContext()
        }
        UIGraphicsEndImageContext()
        
        return stretchableShadow
    }
    
}
