import UIKit
import Flutter

@main
class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = FlutterViewController()
    window = UIWindow(frame: UIScreen.main.bounds)
    window?.rootViewController = controller
    window?.makeKeyAndVisible()

    let cameraChannel = FlutterMethodChannel(
      name: "com.example.mediapipe2/camera",
      binaryMessenger: controller.binaryMessenger
    )

    cameraChannel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "startCamera" {
        self?.attachCameraView(to: controller)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func attachCameraView(to flutterViewController: FlutterViewController) {
      // 전체 화면에서 카메라 뷰는 하단 50%를 차지하도록 설정
      let screenBounds = UIScreen.main.bounds
      let cameraHeight = screenBounds.height * 0.5  // 50% 높이
      let cameraFrame = CGRect(
        x: 0,
        y: screenBounds.height - cameraHeight,
        width: screenBounds.width,
        height: cameraHeight
      )

      let cameraVC = CameraViewController()
      cameraVC.view.frame = cameraFrame
      cameraVC.view.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]

      flutterViewController.addChild(cameraVC)
      flutterViewController.view.addSubview(cameraVC.view)
      cameraVC.didMove(toParent: flutterViewController)
  }
}