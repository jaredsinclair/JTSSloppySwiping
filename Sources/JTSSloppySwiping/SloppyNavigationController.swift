import UIKit

/// This is a convenience subclass, which relieves you of the burden of keeping 
/// a strong reference to the required SloppySwiping instance. You can use any
/// other navigation controller if you wish, but you'll be responsible for
/// initializing SloppySwiping instance, setting it as the navigation
/// controller's delegate (or forwarding the relevant methods from an existing
/// delegate), and keeping a strong reference to the SloppySwiping instance.
public final class SloppyNavigationController: UINavigationController {
    
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
