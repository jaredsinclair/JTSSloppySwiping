//
//  JTSSloppySwiping.swift
//  JTSSloppySwiping
//
//  Created by Jared Sinclair on 8/1/15.
//  Copyright © 2015 Nice Boy LLC. All rights reserved.
//

import UIKit

/**
This is a convenience subclass, which relieves you of the burden of keeping a 
strong reference to the required SloppySwiping instance. You can use any 
other navigation controller if you wish, but you'll be responsible for
initializing SloppySwiping and keeping a reference to it.
*/
@objc(JTSSloppyNavigationController)
class SloppyNavigationController: UINavigationController {
    
    fileprivate lazy var sloppySwiping: SloppySwiping = {
        return SloppySwiping(navigationController: self)
    }()
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.delegate = self.sloppySwiping
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.delegate = self.sloppySwiping
    }
    
    override init(navigationBarClass: AnyClass?, toolbarClass: AnyClass?) {
        super.init(navigationBarClass: navigationBarClass, toolbarClass: toolbarClass)
        self.delegate = self.sloppySwiping
    }
    
    override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        self.delegate = self.sloppySwiping
    }
    
}

/**
To use this, just initialize it and keep a strong reference to it. You don't 
actually have to make it your navigation controller's delegate if you need to
use a different class for that purpose. Just forward the relevant delegate
methods to your sloppy swiping instance.
*/
@objc(JTSSloppySwiping)
class SloppySwiping: NSObject {
    
    init(navigationController: UINavigationController) {
        self.interactivePopAnimator = InteractivePopAnimator()
        self.popRecognizer = UIPanGestureRecognizer()
        self.navigationController = navigationController
        super.init()
        self.popRecognizer.addTarget(self, action: #selector(SloppySwiping.popRecognizerPanned(_:)))
        navigationController.view.addGestureRecognizer(self.popRecognizer)
    }
    
    // MARK: Private
    
    fileprivate weak var navigationController: UINavigationController?
    fileprivate var isInteractivelyPopping: Bool = false
    fileprivate var interactivePopAnimator: InteractivePopAnimator
    fileprivate let popRecognizer: UIPanGestureRecognizer

    fileprivate var isAnimatingANonInteractiveTransition: Bool = false {
        didSet {
            self.popRecognizer.isEnabled = !self.isAnimatingANonInteractiveTransition
        }
    }
    
    @objc fileprivate func popRecognizerPanned(_ recognizer: UIPanGestureRecognizer) {
        
        guard let navigationController = self.navigationController else {
            return
        }
        
        if (recognizer != self.popRecognizer) {
            return
        }
        
        switch (recognizer.state) {
            
        case .began:
            if (!self.isAnimatingANonInteractiveTransition) {
                if (navigationController.viewControllers.count > 1) {
                    self.isInteractivelyPopping = true
                    _ = self.navigationController?.popViewController(animated: true)
                }
            }
            
        case .changed:
            if (!self.isAnimatingANonInteractiveTransition
                && self.isInteractivelyPopping) {
                let view = navigationController.view
                let t = recognizer.translation(in: view)
                self.interactivePopAnimator.translation = t
            }
            
        case .ended, .cancelled:
            if (!self.isAnimatingANonInteractiveTransition
                && self.isInteractivelyPopping) {
                self.isAnimatingANonInteractiveTransition = true
                let animator = self.interactivePopAnimator
                let view = navigationController.view
                let t = recognizer.translation(in: view)
                let v = recognizer.velocity(in: view)
                if animator.shouldCancelForGestureEndingWithTranslation(t, velocity: v) {
                    animator.cancelWithTranslation(t, velocity: v, completion: { () -> Void in
                        self.isInteractivelyPopping = false
                        self.isAnimatingANonInteractiveTransition = false
                    })
                } else {
                    animator.finishWithTranslation(t, velocity: v, completion: { () -> Void in
                        self.isInteractivelyPopping = false
                        self.isAnimatingANonInteractiveTransition = false
                    })
                }
            }
            
        default: break
            
        }
    }
    
}

extension SloppySwiping: UINavigationControllerDelegate {
    
    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationControllerOperation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if (self.isInteractivelyPopping && operation == .pop) {
            return self.interactivePopAnimator
        }
        return nil
    }
    
    func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        if (self.isInteractivelyPopping) {
            return self.interactivePopAnimator
        }
        return nil
    }
    
}

private let defaultCancelPopDuration: TimeInterval = 0.16
private let maxBackViewTranslationPercentage: CGFloat = 0.30
private let minimumDismissalPercentage: CGFloat = 0.5
private let minimumThresholdVelocity: CGFloat = 100.0

private class InteractivePopAnimator: NSObject, UIViewControllerAnimatedTransitioning, UIViewControllerInteractiveTransitioning {
    
    var translation: CGPoint = CGPoint.zero {
        didSet {
            self.updateViewsWithTranslation(translation)
        }
    }
    
    fileprivate var activeContext: UIViewControllerContextTransitioning? = nil
    fileprivate var activeDuration: TimeInterval? = nil
    
    fileprivate let backOverlayView: UIView = {
        let backOverlayView = UIView(frame: CGRect.zero)
        backOverlayView.backgroundColor = UIColor(white: 0.0, alpha: 0.1)
        backOverlayView.alpha = 1.0
        return backOverlayView
        }()
    
    fileprivate let frontContainerView: FrontContainerView = {
        return FrontContainerView(frame: CGRect.zero)
    }()
    
    // MARK: UIViewControllerAnimatedTransitioning
    
    @objc func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        if let duration = self.activeDuration {
            return duration
        }
        return 0
    }
    
    @objc func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        fatalError("this class should not be used for non-interactive transitions")
    }
    
    // MARK: UIViewControllerInteractiveTransitioning
    
    @objc func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning) {
        self.activeContext = transitionContext
        self.prepForPop()
    }

    // MARK: Private / Convenience
    
    func prepForPop() {
        
        guard let transitionContext = self.activeContext,
            let fromView = transitionContext.view(forKey: UITransitionContextViewKey.from),
            let toView = transitionContext.view(forKey: UITransitionContextViewKey.to) else {
                return
        }
        
        let container = transitionContext.containerView
        let containerBounds = container.bounds
        
        self.frontContainerView.frame = containerBounds
        
        let maxOffset = containerBounds.size.width * maxBackViewTranslationPercentage

        fromView.frame = self.frontContainerView.bounds
        self.frontContainerView.addSubview(fromView)
        self.frontContainerView.transform = CGAffineTransform.identity
        
        toView.frame = containerBounds
        toView.transform = CGAffineTransform(translationX: -maxOffset, y: 0)
        
        self.backOverlayView.frame = containerBounds
        
        container.addSubview(toView)
        container.addSubview(self.backOverlayView)
        container.addSubview(self.frontContainerView)
    }
    
    func updateViewsWithTranslation(_ translation: CGPoint) {
        
        guard let transitionContext = self.activeContext,
            let toView = transitionContext.view(forKey: UITransitionContextViewKey.to) else {
                return
        }
        
        let container = transitionContext.containerView
        let maxDistance = container.bounds.size.width
        let percent = self.percentDismissedForTranslation(translation, container: container)

        let maxFromViewOffset = maxDistance

        let maxToViewOffset = maxDistance * maxBackViewTranslationPercentage
        let resolvedToViewOffset = -maxToViewOffset + (maxToViewOffset * percent)
        
        self.frontContainerView.transform = CGAffineTransform(translationX: maxFromViewOffset * percent, y: 0)
        self.frontContainerView.dropShadowView.alpha = (1.0 - percent)
        toView.transform = CGAffineTransform(translationX: resolvedToViewOffset, y: 0)
        self.backOverlayView.alpha = (1.0 - percent)
        
        self.activeContext?.updateInteractiveTransition(percent)
    }
    
    func shouldCancelForGestureEndingWithTranslation(_ translation: CGPoint, velocity: CGPoint) -> Bool {
        
        guard let transitionContext = self.activeContext else {
            return false
        }
        
        let container = transitionContext.containerView
        
        let percent = self.percentDismissedForTranslation(translation, container: container)
        
        return ((percent < minimumDismissalPercentage && velocity.x < 100.0) || velocity.x < 0)
    }
    
    func cancelWithTranslation(_ translation: CGPoint, velocity: CGPoint, completion: @escaping () -> Void) {
        
        guard let transitionContext = self.activeContext,
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
            let naiveDuration = self.durationForDistance(distance: maxDistance, velocity: abs(velocity.x))
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
        
        self.activeDuration = duration
        
        self.activeContext?.cancelInteractiveTransition()
        
        UIView.animate(withDuration: duration,
            delay: 0,
            options: options,
            animations: { () -> Void in
                self.frontContainerView.transform = CGAffineTransform.identity
                toView.transform = CGAffineTransform(translationX: resolvedToViewOffset, y: 0)
                self.backOverlayView.alpha = 1.0
                self.frontContainerView.dropShadowView.alpha = 1.0
            },
            completion: { (completed) -> Void in
                toView.transform = CGAffineTransform.identity
                container.addSubview(fromView)
                self.backOverlayView.removeFromSuperview()
                self.frontContainerView.removeFromSuperview()
                self.activeContext?.completeTransition(false)
                completion()
            }
        )
        
    }
    
    func finishWithTranslation(_ translation: CGPoint, velocity: CGPoint, completion: @escaping () -> Void) {
        
        guard let transitionContext = self.activeContext,
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
            duration = self.durationForDistance(distance: maxDistance, velocity: abs(comfortVelocity.x))
        }
        else {
            options = UIViewAnimationOptions()
            duration = defaultCancelPopDuration
        }
        
        self.activeDuration = duration
        
        self.activeContext?.finishInteractiveTransition()
        
        UIView.animate(withDuration: duration,
            delay: 0,
            options: options,
            animations: { () -> Void in
                self.frontContainerView.transform = CGAffineTransform(translationX: maxDistance, y: 0)
                toView.transform = CGAffineTransform.identity
                self.backOverlayView.alpha = 0.0
                self.frontContainerView.dropShadowView.alpha = 0.0
            },
            completion: { (completed) -> Void in
                fromView.removeFromSuperview()
                self.frontContainerView.transform = CGAffineTransform.identity
                self.frontContainerView.removeFromSuperview()
                self.backOverlayView.removeFromSuperview()
                self.activeContext?.completeTransition(true)
                completion()
            }
        )
        
    }
    
    func percentDismissedForTranslation(_ translation: CGPoint, container: UIView) -> CGFloat {
        let maxDistance = container.bounds.size.width
        return (min(maxDistance, max(0, translation.x))) / maxDistance
    }
    
    func durationForDistance(distance d: CGFloat, velocity v: CGFloat) -> TimeInterval {
        let minDuration: CGFloat = 0.08
        let maxDuration: CGFloat = 0.4
        return (TimeInterval)(max(min(maxDuration, d / v), minDuration))
    }
    
}

private class FrontContainerView: UIView {
    
    fileprivate let dropShadowView: UIView
    
    override init(frame: CGRect) {
        self.dropShadowView = FrontContainerView.newDropShadowView()
        super.init(frame: frame)
        self.commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        self.dropShadowView = FrontContainerView.newDropShadowView()
        super.init(coder: aDecoder)
        self.commonInit()
    }
    
    func commonInit() {
        var dropShadowFrame = self.dropShadowView.frame
        dropShadowFrame.origin.x = 0 - dropShadowFrame.size.width
        dropShadowFrame.origin.y = 0
        dropShadowFrame.size.height = self.bounds.size.height
        self.dropShadowView.frame = dropShadowFrame
        self.addSubview(self.dropShadowView)
        self.clipsToBounds = false
        self.backgroundColor = UIColor.clear
    }
    
    static func newDropShadowView() -> UIView {
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
