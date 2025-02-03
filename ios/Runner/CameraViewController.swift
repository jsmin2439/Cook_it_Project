import AVFoundation
import MediaPipeTasksVision
import UIKit

class CameraViewController: UIViewController {
  private struct Constants {
    static let edgeOffset: CGFloat = 2.0
  }

  weak var inferenceResultDeliveryDelegate: InferenceResultDeliveryDelegate?
  weak var interfaceUpdatesDelegate: InterfaceUpdatesDelegate?

  private var previewView: UIView!
  private var cameraUnavailableLabel: UILabel!
  private var resumeButton: UIButton!
  private var overlayView: OverlayView!

  private var isSessionRunning = false
  private var isObserving = false
  private let backgroundQueue = DispatchQueue(label: "com.google.mediapipe.cameraController.backgroundQueue")

  // 카메라 세션 관리
  private lazy var cameraFeedService = CameraFeedService(previewView: previewView)

  // HandLandmarkerService를 동시성 큐로 감싸는 구조
  private let handLandmarkerServiceQueue = DispatchQueue(
    label: "com.google.mediapipe.cameraController.handLandmarkerServiceQueue",
    attributes: .concurrent)

  private var _handLandmarkerService: HandLandmarkerService?
  private var handLandmarkerService: HandLandmarkerService? {
    get {
      handLandmarkerServiceQueue.sync {
        return _handLandmarkerService
      }
    }
    set {
      handLandmarkerServiceQueue.async(flags: .barrier) {
        self._handLandmarkerService = newValue
      }
    }
  }

  // MARK: - View Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    setupUI()
    cameraFeedService.delegate = self
  }

  /// **중요**: 여기서 카메라 세션을 실제로 시작!
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    cameraFeedService.startLiveCameraSession { [weak self] status in
      guard let self = self else { return }
      switch status {
      case .success:
        // 카메라 세션이 성공적으로 시작되면 HandLandmarker 초기화
        self.initializeHandLandmarkerServiceOnSessionResumption()
      case .permissionDenied:
        print("Camera Permission Denied - 권한이 거부됨")
        // 권한 안내 팝업 등을 띄워줄 수 있음
      case .failed:
        print("Camera Configuration Failed - 카메라 설정 실패")
      }
    }
  }

  /// 화면에서 사라질 때 세션 정리
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    cameraFeedService.stopSession()
  }

override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    // 카메라 피드 레이어와 오버레이가 현재 컨테이너(view.bounds)에 맞춰지도록 설정
    cameraFeedService.updateVideoPreviewLayer(toFrame: self.view.bounds)
    previewView.frame = view.bounds
    overlayView.frame = view.bounds
}

  // MARK: - UI Setup

  private func setupUI() {
    // previewView
    previewView = UIView(frame: view.bounds)
    view.addSubview(previewView)

    // 카메라Unavailable Label
    cameraUnavailableLabel = UILabel()
    cameraUnavailableLabel.frame = CGRect(x: 20, y: 80, width: 200, height: 40)
    cameraUnavailableLabel.text = "Camera Unavailable"
    cameraUnavailableLabel.textAlignment = .center
    cameraUnavailableLabel.isHidden = true
    self.view.addSubview(cameraUnavailableLabel)

    // resumeButton
    resumeButton = UIButton(type: .system)
    resumeButton.frame = CGRect(x: 20, y: 140, width: 80, height: 40)
    resumeButton.setTitle("Resume", for: .normal)
    resumeButton.addTarget(self, action: #selector(onClickResume), for: .touchUpInside)
    resumeButton.isHidden = true
    self.view.addSubview(resumeButton)

    // overlayView
    overlayView = OverlayView(frame: self.view.bounds)
    self.view.addSubview(overlayView)
  }

  @objc private func onClickResume(_ sender: Any) {
    cameraFeedService.resumeInterruptedSession { [weak self] isSessionRunning in
      if isSessionRunning {
        self?.resumeButton.isHidden = true
        self?.cameraUnavailableLabel.isHidden = true
      }
    }
  }

  // MARK: - HandLandmarker 초기화 관련

  /// 카메라 세션이 재개/성공한 후 HandLandmarkerService 세팅
  private func initializeHandLandmarkerServiceOnSessionResumption() {
    clearAndInitializeHandLandmarkerService()
    startObserveConfigChanges()
  }

  @objc private func clearAndInitializeHandLandmarkerService() {
    handLandmarkerService = nil
    handLandmarkerService = HandLandmarkerService.liveStreamHandLandmarkerService(
      modelPath: InferenceConfigurationManager.sharedInstance.modelPath,
      numHands: InferenceConfigurationManager.sharedInstance.numHands,
      minHandDetectionConfidence: InferenceConfigurationManager.sharedInstance.minHandDetectionConfidence,
      minHandPresenceConfidence: InferenceConfigurationManager.sharedInstance.minHandPresenceConfidence,
      minTrackingConfidence: InferenceConfigurationManager.sharedInstance.minTrackingConfidence,
      liveStreamDelegate: self,
      delegate: InferenceConfigurationManager.sharedInstance.delegate
    )
  }

  private func clearhandLandmarkerServiceOnSessionInterruption() {
    stopObserveConfigChanges()
    handLandmarkerService = nil
  }

  private func startObserveConfigChanges() {
    NotificationCenter.default
      .addObserver(self,
                   selector: #selector(clearAndInitializeHandLandmarkerService),
                   name: InferenceConfigurationManager.notificationName,
                   object: nil)
    isObserving = true
  }

  private func stopObserveConfigChanges() {
    if isObserving {
      NotificationCenter.default
        .removeObserver(self,
                        name: InferenceConfigurationManager.notificationName,
                        object: nil)
    }
    isObserving = false
  }
}

// MARK: - CameraFeedServiceDelegate
extension CameraViewController: CameraFeedServiceDelegate {
  func didOutput(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation) {
    let currentTimeMs = Date().timeIntervalSince1970 * 1000
    backgroundQueue.async { [weak self] in
      self?.handLandmarkerService?.detectAsync(
        sampleBuffer: sampleBuffer,
        orientation: orientation,
        timeStamps: Int(currentTimeMs))
    }
  }

  func sessionWasInterrupted(canResumeManually resumeManually: Bool) {
    if resumeManually {
      resumeButton.isHidden = false
    } else {
      cameraUnavailableLabel.isHidden = false
    }
    clearhandLandmarkerServiceOnSessionInterruption()
  }

  func sessionInterruptionEnded() {
    cameraUnavailableLabel.isHidden = true
    resumeButton.isHidden = true
    initializeHandLandmarkerServiceOnSessionResumption()
  }

  func didEncounterSessionRuntimeError() {
    resumeButton.isHidden = false
    clearhandLandmarkerServiceOnSessionInterruption()
  }
}

// MARK: - HandLandmarkerServiceLiveStreamDelegate
extension CameraViewController: HandLandmarkerServiceLiveStreamDelegate {
  func handLandmarkerService(
    _ handLandmarkerService: HandLandmarkerService,
    didFinishDetection result: ResultBundle?,
    error: Error?)
  {
      DispatchQueue.main.async { [weak self] in
          guard let weakSelf = self else { return }
          weakSelf.inferenceResultDeliveryDelegate?.didPerformInference(result: result)

          guard let handLandmarkerResult = result?.handLandmarkerResults.first as? HandLandmarkerResult else { return }
          let imageSize = weakSelf.cameraFeedService.videoResolution

          // 1. 오버레이 렌더링
          let handOverlays = OverlayView.handOverlays(
            fromMultipleHandLandmarks: handLandmarkerResult.landmarks,
            inferredOnImageOfSize: imageSize,
            ovelayViewSize: weakSelf.overlayView.bounds.size,
            imageContentMode: weakSelf.overlayView.imageContentMode,
            andOrientation: UIImage.Orientation.from(deviceOrientation: UIDevice.current.orientation)
          )

          weakSelf.overlayView.draw(
            handOverlays: handOverlays,
            inBoundsOfContentImageOfSize: imageSize,
            imageContentMode: .scaleAspectFill
          )

          // 2. 제스처 감지 및 Flutter 통신
          let direction = self?.detectSwipeDirection(landmarks: handLandmarkerResult.landmarks)
          if let direction = direction {
              let channel = FlutterMethodChannel(
                  name: "com.example.mediapipe2/gesture",
                  binaryMessenger: (self?.view.window?.rootViewController as! FlutterViewController).binaryMessenger
              )
              channel.invokeMethod("swipe", arguments: direction)
          }
      }
  }

  // 3. 제스처 감지 로직
  private func detectSwipeDirection(landmarks: [[NormalizedLandmark]]) -> String? {
      guard let hand = landmarks.first else { return nil }
      let indexTip = hand[8]

      if indexTip.x > 0.6 { return "left" }
      else if indexTip.x < 0.4 { return "right" }
      return nil
  }
}