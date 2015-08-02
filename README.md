# JTSSloppySwiping
Drop-in UINavigationControllerDelegate that enables sloppy swiping.

## Requirements

Requires Swift 2.0.

## Usage

If you want to use the convenience navigation controller subclass:

```
self.sloppyNavController = JTSSloppyNavigationController(rootViewController: root)
```

If you need to use some other navigation controller class:

```
self.sloppySwiping = JTSSloppySwiping(navigationController: yourNavController)

// If you don't need another delegate, then:
yourNavController.delegate = self.sloppySwiping

// Otherwise forward the relevant navigation controller delegate methods
// to your sloppy swiping instance.
```
