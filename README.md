# JTSSloppySwiping

Drop-in UINavigationControllerDelegate that enables sloppy swiping (swiping from anywhere in the content view controller's view to start an interactive pop transition, rather than just from the screen edge). It works whether or not the navigation controller's navigation bar is hidden (unlike the default screen edge gesture).

## Requirements

Requires Swift 3.0 or later (older versions supported Swift 2.x and may still suit your needs).

## Usage

If you want to use the convenience navigation controller subclass:

```
let navController = JTSSloppyNavigationController(rootViewController: root)
```

If you need to use some other navigation controller class:

```
self.sloppySwiping = JTSSloppySwiping(navigationController: yourNavController)

// If you don't need another delegate, then:
yourNavController.delegate = self.sloppySwiping

// Otherwise forward the relevant navigation controller delegate methods
// to your sloppy swiping instance.
```
