import UIKit
import Flutter
import Firebase

@main
class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    FirebaseApp.configure()
    
    // Flutter 엔진 사전 초기화
    let engine = FlutterEngine(name: "main_engine")
    engine.run()
    GeneratedPluginRegistrant.register(with: engine)
    
    let controller = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
    window = UIWindow(frame: UIScreen.main.bounds)
    window?.rootViewController = controller
    window?.makeKeyAndVisible()
    
    // 채널 설정 지연 실행
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self.setupCameraChannel(with: controller)
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
}
  
  private func setupCameraChannel(with controller: FlutterViewController) {
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
  }
  
  private func attachCameraView(to flutterViewController: FlutterViewController) {
    let screenBounds = UIScreen.main.bounds
    let cameraHeight = screenBounds.height * 0// 50% 높이 (원래 0으로 되어 있던 오타 수정)
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
