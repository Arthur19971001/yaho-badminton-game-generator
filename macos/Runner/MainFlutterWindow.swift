import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Real OS-level fullscreen toggle (menu bar/dock hidden, a "slideshow"
    // presentation view) for the game full-view screen -- a couple of
    // lines of Swift instead of a whole window-management package.
    self.collectionBehavior.insert(.fullScreenPrimary)
    let fullscreenChannel = FlutterMethodChannel(
      name: "yaho_badminton_game_generator/fullscreen",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    fullscreenChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "toggleFullScreen":
        self.toggleFullScreen(nil)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    // The window's own green button / a trackpad fullscreen gesture / Esc
    // can all change fullscreen state without going through the channel
    // above, so the Dart side needs to hear about every change, not just
    // the ones it requested itself.
    NotificationCenter.default.addObserver(
      forName: NSWindow.didEnterFullScreenNotification, object: self, queue: .main
    ) { _ in
      fullscreenChannel.invokeMethod("fullScreenChanged", arguments: true)
    }
    NotificationCenter.default.addObserver(
      forName: NSWindow.didExitFullScreenNotification, object: self, queue: .main
    ) { _ in
      fullscreenChannel.invokeMethod("fullScreenChanged", arguments: false)
    }

    super.awakeFromNib()
  }
}
