import UIKit
import Flutter
import GestureRecognition

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var gestureRecognition: GestureRecognition?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    gestureRecognition = GestureRecognition()

    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "com.example.flutter/mediapipe",
                                      binaryMessenger: controller.binaryMessenger)

    channel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard call.method == "detectGesture" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.detectGesture(result: result)
    })

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func detectGesture(result: @escaping FlutterResult) {
    // Assume `sampleBuffer` is available from somewhere like AVCaptureSession
    gestureRecognition?.processSampleBuffer(sampleBuffer) { hands in
      if let hands = hands {
        result("Gesture detected with \(hands.count) hands")
      } else {
        result("No hands detected")
      }
    }
  }
}