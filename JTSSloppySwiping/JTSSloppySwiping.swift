//
//  JTSSloppyNavigationController.swift
//  JTSSloppyNavigationController
//
//  Created by Jared Sinclair on 8/1/15.
//  Copyright © 2015 Nice Boy LLC. All rights reserved.
//

import UIKit

/**
This is a convenience subclass, which relieves you of the burden of keeping a 
strong reference to the required JTSSloppySwiping instance. You can use any 
other navigation controller if you wish, but you'll be responsible for
initializing JTSSloppySwiping and keeping a reference to it.
*/
class JTSSloppyNavigationController: UINavigationController {
    
    private lazy var sloppySwiping: JTSSloppySwiping = {
        return JTSSloppySwiping(navigationController: self)
    }()
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
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
class JTSSloppySwiping: NSObject {
    
    init(navigationController: UINavigationController) {
        self.interactivePopAnimator = InteractivePopAnimator()
        self.popRecognizer = UIPanGestureRecognizer()
        self.navigationController = navigationController
        super.init()
        self.popRecognizer.addTarget(self, action: "popRecognizerPanned:")
        navigationController.view.addGestureRecognizer(self.popRecognizer)
    }
    
    // MARK: Private
    
    private weak var navigationController: UINavigationController?
    private var isInteractivelyPopping: Bool = false
    private var interactivePopAnimator: InteractivePopAnimator
    private let popRecognizer: UIPanGestureRecognizer

    private var isAnimatingANonInteractiveTransition: Bool = false {
        didSet {
            self.popRecognizer.enabled = !self.isAnimatingANonInteractiveTransition
        }
    }
    
    @objc private func popRecognizerPanned(recognizer: UIPanGestureRecognizer) {
        
        guard let navigationController = self.navigationController else {
            return
        }
        
        if (recognizer != self.popRecognizer) {
            return
        }
        
        switch (recognizer.state) {
            
        case .Began:
            if (!self.isAnimatingANonInteractiveTransition) {
                if (navigationController.viewControllers.count > 1) {
                    self.isInteractivelyPopping = true
                    self.navigationController?.popViewControllerAnimated(true)
                }
            }
            
        case .Changed:
            if (!self.isAnimatingANonInteractiveTransition
                && self.isInteractivelyPopping) {
                let view = navigationController.view
                let t = recognizer.translationInView(view)
                self.interactivePopAnimator.translation = t
            }
            
        case .Ended, .Cancelled:
            if (!self.isAnimatingANonInteractiveTransition
                && self.isInteractivelyPopping) {
                self.isAnimatingANonInteractiveTransition = true
                let animator = self.interactivePopAnimator
                let view = navigationController.view
                let t = recognizer.translationInView(view)
                let v = recognizer.velocityInView(view)
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

extension JTSSloppySwiping: UINavigationControllerDelegate {
    
    func navigationController(navigationController: UINavigationController, animationControllerForOperation operation: UINavigationControllerOperation, fromViewController fromVC: UIViewController, toViewController toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if (self.isInteractivelyPopping && operation == .Pop) {
            return self.interactivePopAnimator
        }
        return NonInteractiveAnimator(operation: operation)
    }
    
    func navigationController(navigationController: UINavigationController, interactionControllerForAnimationController animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        if (self.isInteractivelyPopping) {
            return self.interactivePopAnimator
        }
        return nil
    }
    
}

private let defaultPushPopDuration: NSTimeInterval = 0.33
private let defaultCancelPopDuration = defaultPushPopDuration / 2.0
private let maxBackViewTranslationPercentage: CGFloat = 0.25
private let minimumDismissalPercentage: CGFloat = 0.5
private let minimumThresholdVelocity: CGFloat = 100.0

private class NonInteractiveAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    
    let operation: UINavigationControllerOperation
    
    private let frontContainerView: FrontContainerView = {
        return FrontContainerView(frame: CGRectZero)
        }()
    
    init(operation: UINavigationControllerOperation) {
        self.operation = operation
    }

    // MARK: UIViewControllerAnimatedTransitioning
    
    @objc func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval {
        return defaultPushPopDuration
    }

    @objc func animateTransition(transitionContext: UIViewControllerContextTransitioning) {
        if (self.operation == .Push) {
            self.push(transitionContext)
        }
        else if (self.operation == .Pop) {
            self.pop(transitionContext)
        }
    }
    
    // MARK: Convenience
    
    func push(transitionContext: UIViewControllerContextTransitioning) {
        
        guard let container = transitionContext.containerView(),
            fromView = transitionContext.viewForKey(UITransitionContextFromViewKey),
            toView = transitionContext.viewForKey(UITransitionContextToViewKey) else {
                return
        }
        
        let containerBounds = container.bounds
        
        self.frontContainerView.frame = containerBounds
        
        let maxOffset = containerBounds.size.width * maxBackViewTranslationPercentage
        
        toView.frame = self.frontContainerView.bounds
        self.frontContainerView.addSubview(toView)
        self.frontContainerView.transform = CGAffineTransformMakeTranslation(containerBounds.size.width, 0)
        self.frontContainerView.dropShadowView.alpha = 0.0
        
        fromView.frame = containerBounds
        fromView.transform = CGAffineTransformIdentity
        
        let backOverlayView = UIView(frame: containerBounds)
        backOverlayView.alpha = 0
        
        container.addSubview(fromView)
        container.addSubview(backOverlayView)
        container.addSubview(self.frontContainerView)
        
        UIView.animateWithDuration(defaultPushPopDuration,
            animations: { () -> Void in
                backOverlayView.alpha = 1.0
                fromView.transform = CGAffineTransformMakeTranslation(-maxOffset, 0)
                self.frontContainerView.transform = CGAffineTransformIdentity
                self.frontContainerView.dropShadowView.alpha = 1.0
            }) { (completed) -> Void in
                fromView.transform = CGAffineTransformIdentity
                backOverlayView.removeFromSuperview()
                transitionContext.completeTransition(true)
        }
    }
    
    func pop(transitionContext: UIViewControllerContextTransitioning) {
        guard let container = transitionContext.containerView(),
            fromView = transitionContext.viewForKey(UITransitionContextFromViewKey),
            toView = transitionContext.viewForKey(UITransitionContextToViewKey) else {
                return
        }
        
        let containerBounds = container.bounds
        
        self.frontContainerView.frame = containerBounds
        
        let maxOffset = containerBounds.size.width * maxBackViewTranslationPercentage
        
        fromView.frame = self.frontContainerView.bounds
        self.frontContainerView.addSubview(fromView)
        self.frontContainerView.transform = CGAffineTransformIdentity
        
        toView.frame = containerBounds
        toView.transform = CGAffineTransformMakeTranslation(-maxOffset, 0)
        
        let backOverlayView = UIView(frame: containerBounds)
        backOverlayView.alpha = 1.0
        
        container.addSubview(toView)
        container.addSubview(backOverlayView)
        container.addSubview(self.frontContainerView)
        
        UIView.animateWithDuration(defaultPushPopDuration,
            animations: { () -> Void in
                backOverlayView.alpha = 0
                self.frontContainerView.transform = CGAffineTransformMakeTranslation(fromView.width, 0)
                toView.transform = CGAffineTransformIdentity
                self.frontContainerView.dropShadowView.alpha = 0.0
            }) { (completed) -> Void in
                self.frontContainerView.transform = CGAffineTransformIdentity
                self.frontContainerView.removeFromSuperview()
                fromView.removeFromSuperview()
                backOverlayView.removeFromSuperview()
                transitionContext.completeTransition(true)
        }
    }
    
}

private class InteractivePopAnimator: NSObject, UIViewControllerAnimatedTransitioning, UIViewControllerInteractiveTransitioning {
    
    var translation: CGPoint = CGPointZero {
        didSet {
            self.updateViewsWithTranslation(translation)
        }
    }
    
    private var activeContext: UIViewControllerContextTransitioning? = nil
    private var activeDuration: NSTimeInterval? = nil
    
    private let backOverlayView: UIView = {
        let backOverlayView = UIView(frame: CGRectZero)
        backOverlayView.backgroundColor = UIColor(white: 0.0, alpha: 0.1)
        backOverlayView.alpha = 1.0
        return backOverlayView
        }()
    
    private let frontContainerView: FrontContainerView = {
        return FrontContainerView(frame: CGRectZero)
    }()
    
    // MARK: UIViewControllerAnimatedTransitioning
    
    @objc func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval {
        if let duration = self.activeDuration {
            return duration
        }
        return defaultPushPopDuration
    }
    
    @objc func animateTransition(transitionContext: UIViewControllerContextTransitioning) {
        fatalError("this class should not be used for non-interactive transitions")
    }
    
    // MARK: UIViewControllerInteractiveTransitioning
    
    @objc func startInteractiveTransition(transitionContext: UIViewControllerContextTransitioning) {
        self.activeContext = transitionContext
        self.prepForPop()
    }

    // MARK: Private / Convenience
    
    func prepForPop() {
        
        guard let transitionContext = self.activeContext,
            container = transitionContext.containerView(),
            fromView = transitionContext.viewForKey(UITransitionContextFromViewKey),
            toView = transitionContext.viewForKey(UITransitionContextToViewKey) else {
                return
        }
        
        let containerBounds = container.bounds
        
        self.frontContainerView.frame = containerBounds
        
        let maxOffset = containerBounds.size.width * maxBackViewTranslationPercentage

        fromView.frame = self.frontContainerView.bounds
        self.frontContainerView.addSubview(fromView)
        self.frontContainerView.transform = CGAffineTransformIdentity
        
        toView.frame = containerBounds
        toView.transform = CGAffineTransformMakeTranslation(-maxOffset, 0)
        
        self.backOverlayView.frame = containerBounds
        
        container.addSubview(toView)
        container.addSubview(self.backOverlayView)
        container.addSubview(self.frontContainerView)
    }
    
    func updateViewsWithTranslation(translation: CGPoint) {
        
        guard let transitionContext = self.activeContext,
            container = transitionContext.containerView(),
            toView = transitionContext.viewForKey(UITransitionContextToViewKey) else {
                return
        }
        
        let maxDistance = container.bounds.size.width
        let percent = self.percentDismissedForTranslation(translation, container: container)

        let maxFromViewOffset = maxDistance

        let maxToViewOffset = maxDistance * maxBackViewTranslationPercentage
        let resolvedToViewOffset = -maxToViewOffset + (maxToViewOffset * percent)
        
        self.frontContainerView.transform = CGAffineTransformMakeTranslation(maxFromViewOffset * percent, 0)
        self.frontContainerView.dropShadowView.alpha = (1.0 - percent)
        toView.transform = CGAffineTransformMakeTranslation(resolvedToViewOffset, 0)
        self.backOverlayView.alpha = (1.0 - percent)
        
        self.activeContext?.updateInteractiveTransition(percent)
    }
    
    func shouldCancelForGestureEndingWithTranslation(translation: CGPoint, velocity: CGPoint) -> Bool {
        
        guard let transitionContext = self.activeContext,
            container = transitionContext.containerView() else {
                return false
        }
        
        let percent = self.percentDismissedForTranslation(translation, container: container)
        
        return ((percent < minimumDismissalPercentage && velocity.x < 100.0) || velocity.x < 0)
    }
    
    func cancelWithTranslation(translation: CGPoint, velocity: CGPoint, completion: () -> Void) {
        
        guard let transitionContext = self.activeContext,
            container = transitionContext.containerView(),
            fromView = transitionContext.viewForKey(UITransitionContextFromViewKey),
            toView = transitionContext.viewForKey(UITransitionContextToViewKey) else {
                return
        }
        
        let maxDistance = container.bounds.size.width
        let maxToViewOffset = maxDistance * maxBackViewTranslationPercentage
        let resolvedToViewOffset = -maxToViewOffset
        let duration: NSTimeInterval
        let options: UIViewAnimationOptions
        
        if abs(velocity.x) > minimumThresholdVelocity {
            options = .CurveEaseOut
            let naiveDuration = self.durationForDistance(distance: maxDistance, velocity: abs(velocity.x))
            let isFlickingShutEarly = translation.x < maxDistance * minimumDismissalPercentage
            if (naiveDuration > defaultCancelPopDuration && isFlickingShutEarly) {
                duration = defaultCancelPopDuration
            } else {
                duration = naiveDuration
            }
        }
        else {
            options = .CurveEaseInOut
            duration = defaultCancelPopDuration
        }
        
        self.activeDuration = duration
        
        UIView.animateWithDuration(duration,
            delay: 0,
            options: options,
            animations: { () -> Void in
                self.frontContainerView.transform = CGAffineTransformIdentity
                toView.transform = CGAffineTransformMakeTranslation(resolvedToViewOffset, 0)
                self.backOverlayView.alpha = 1.0
                self.frontContainerView.dropShadowView.alpha = 1.0
            },
            completion: { (completed) -> Void in
                toView.transform = CGAffineTransformIdentity
                container.addSubview(fromView)
                self.backOverlayView.removeFromSuperview()
                self.frontContainerView.removeFromSuperview()
                self.activeContext?.cancelInteractiveTransition()
                self.activeContext?.transitionWasCancelled()
                self.activeContext?.completeTransition(false)
                completion()
            }
        )
        
    }
    
    func finishWithTranslation(translation: CGPoint, velocity: CGPoint, completion: () -> Void) {
        
        guard let transitionContext = self.activeContext,
            container = transitionContext.containerView(),
            fromView = transitionContext.viewForKey(UITransitionContextFromViewKey),
            toView = transitionContext.viewForKey(UITransitionContextToViewKey) else {
                return
        }
        
        let maxDistance = container.bounds.size.width
        let duration: NSTimeInterval
        
        let options: UIViewAnimationOptions
        if abs(velocity.x) > 0 {
            options = .CurveEaseOut
            duration = self.durationForDistance(distance: maxDistance, velocity: abs(velocity.x))
        }
        else {
            options = .CurveEaseInOut
            duration = defaultPushPopDuration
        }
        
        self.activeDuration = duration
        
        UIView.animateWithDuration(duration,
            delay: 0,
            options: options,
            animations: { () -> Void in
                self.frontContainerView.transform = CGAffineTransformMakeTranslation(maxDistance, 0)
                toView.transform = CGAffineTransformIdentity
                self.backOverlayView.alpha = 0.0
                self.frontContainerView.dropShadowView.alpha = 0.0
            },
            completion: { (completed) -> Void in
                fromView.removeFromSuperview()
                self.frontContainerView.transform = CGAffineTransformIdentity
                self.frontContainerView.removeFromSuperview()
                self.backOverlayView.removeFromSuperview()
                self.activeContext?.finishInteractiveTransition()
                self.activeContext?.completeTransition(true)
                completion()
            }
        )
        
    }
    
    func percentDismissedForTranslation(translation: CGPoint, container: UIView) -> CGFloat {
        let maxDistance = container.bounds.size.width
        return (min(maxDistance, max(0, translation.x))) / maxDistance
    }
    
    func durationForDistance(distance d: CGFloat, velocity v: CGFloat) -> NSTimeInterval {
        let minDuration: CGFloat = 0.08
        let maxDuration: CGFloat = 0.5
        return (NSTimeInterval)(max(min(maxDuration, d / v), minDuration))
    }
    
}

private class FrontContainerView: UIView {
    
    private let dropShadowView: UIView = {
        
        let w: CGFloat = 10.0
        
        let stretchableShadow = UIImageView(frame: CGRectMake(0, 0, w, 1))
        stretchableShadow.backgroundColor = UIColor.clearColor()
        stretchableShadow.alpha = 1.0
        stretchableShadow.contentMode = .ScaleToFill
        stretchableShadow.autoresizingMask = [.FlexibleHeight, .FlexibleRightMargin]
        
        let contextSize = CGSizeMake(w, 1)
        UIGraphicsBeginImageContextWithOptions(contextSize, false, 0)
        let context = UIGraphicsGetCurrentContext()
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors: CFArray = [
            UIColor(white: 0.0, alpha: 0.000).CGColor,
            UIColor(white: 0.0, alpha: 0.045).CGColor,
            UIColor(white: 0.0, alpha: 0.090).CGColor,
            UIColor(white: 0.0, alpha: 0.135).CGColor,
            UIColor(white: 0.0, alpha: 0.180).CGColor,
        ]
        let locations: [CGFloat] = [0.0, 0.34, 0.60, 0.80, 1.0]
        let options = CGGradientDrawingOptions()
        if let gradient = CGGradientCreateWithColors(colorSpace, colors, locations) {
            CGContextDrawLinearGradient(context, gradient, CGPointMake(0, 0), CGPointMake(w, 0), options)
            stretchableShadow.image = UIGraphicsGetImageFromCurrentImageContext()
        }
        UIGraphicsEndImageContext()
        
        return stretchableShadow
        
        }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
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
        self.backgroundColor = UIColor.clearColor()
    }
}
