import UIKit

final class FrontContainerView: UIView {

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
        if RTL {
            dropShadowFrame.origin.x = bounds.width
        } else {
            dropShadowFrame.origin.x = 0 - dropShadowFrame.size.width
        }
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
        let orientedLocations = RTL ? locations.reversed() : locations
        let options = CGGradientDrawingOptions()
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: orientedLocations) {
            context?.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: w, y: 0), options: options)
            stretchableShadow.image = UIGraphicsGetImageFromCurrentImageContext()
        }
        UIGraphicsEndImageContext()

        return stretchableShadow
    }

}
