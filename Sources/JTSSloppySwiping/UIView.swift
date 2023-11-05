import UIKit

extension UIView {

    var transformSafeFrame: CGRect {
        let left = self.left
        let top = self.top
        let width = self.width
        let height = self.height
        return CGRect(x: left, y: top, width: width, height: height)
    }

    var top: CGFloat {
        get {
            return self.center.y - self.halfHeight
        }
        set {
            var center = self.center
            center.y = newValue + self.halfHeight
            self.center = center
        }
    }

    var left: CGFloat {
        get {
            return self.center.x - self.halfWidth
        }
        set {
            var center = self.center
            center.x = newValue + self.halfWidth
            self.center = center
        }
    }

    var bottom: CGFloat {
        get {
            return self.center.y + self.halfHeight
        }
        set {
            var center = self.center
            center.y = newValue - self.halfHeight
            self.center = center
        }
    }

    var right: CGFloat {
        get {
            return self.center.x + self.halfWidth
        }
        set {
            var center = self.center
            center.x = newValue - self.halfWidth
            self.center = center
        }
    }

    var height: CGFloat {
        get {
            return self.bounds.height
        }
        set {
            var bounds = self.bounds
            let previousHeight = bounds.height
            bounds.size.height = newValue
            self.bounds = bounds

            let delta = previousHeight - newValue
            var center = self.center
            center.y += delta / 2.0
            self.center = center
        }
    }

    var width: CGFloat {
        get {
            return self.bounds.width
        }
        set {
            var bounds = self.bounds
            let previousWidth = bounds.width
            bounds.size.width = newValue
            self.bounds = bounds

            let delta = previousWidth - newValue
            var center = self.center
            center.x += delta / 2.0
            self.center = center
        }
    }

    var internalCenter: CGPoint {
        return CGPoint(x: self.halfWidth, y: self.halfHeight)
    }

    private var halfHeight: CGFloat {
        return self.bounds.height / 2.0
    }

    private var halfWidth: CGFloat {
        return self.bounds.width / 2.0
    }

}
