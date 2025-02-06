import AVFoundation
import MediaPipeTasksVision
import UIKit

class CameraViewController: UIViewController {

  // MARK: - Constants
  private struct Constants {
    static let edgeOffset: CGFloat = 2.0
  }

  // MARK: - Public/External Delegates
  weak var inferenceResultDeliveryDelegate: InferenceResultDeliveryDelegate?
  weak var interfaceUpdatesDelegate: InterfaceUpdatesDelegate?

  // MARK: - UI Elements
  private var previewView: UIView!
  private var cameraUnavailableLabel: UILabel!
  private var resumeButton: UIButton!
  private var overlayView: OverlayView!

  // MARK: - States
  private var isSessionRunning = false
  private var isObserving = false

  // MARK: - Queues
  private let backgroundQueue = DispatchQueue(label: "com.google.mediapipe.cameraController.backgroundQueue")

  // MARK: - CameraFeedService
  private lazy var cameraFeedService = CameraFeedService(previewView: previewView)

  // MARK: - HandLandmarkerService (Thread-safe access)
  private let handLandmarkerServiceQueue = DispatchQueue(
    label: "com.google.mediapipe.cameraController.handLandmarkerServiceQueue",
    attributes: .concurrent
  )
  private var _handLandmarkerService: HandLandmarkerService?
  private var handLandmarkerService: HandLandmarkerService? {
    get {
      handLandmarkerServiceQueue.sync { _handLandmarkerService }
    }
    set {
      handLandmarkerServiceQueue.async(flags: .barrier) {
        self._handLandmarkerService = newValue
      }
    }
  }

  // MARK: - Gesture Detection Stored Properties
  /// 스와이프를 판별하기 위해 최근 일정 시간 동안의 (손끝 좌표, 시각)을 보관
  private var positionsBuffer = [(CGPoint, TimeInterval)]()
  /// 마지막으로 스와이프를 인식한 시각 (쿨타임용)
  private var lastSwipeTime: TimeInterval = 0

  // ----- 스와이프 파라미터 튜닝 -----
  /// 스와이프가 되려면, 최근 maxSwipeInterval 이내에 minSwipeDistance 이상 이동해야 함.
  private let minSwipeDistance: CGFloat = 0.2     // 0.2 = 20% 화면 폭
  private let maxSwipeInterval: TimeInterval = 0.5 // 0.5초 이내
  private let detectionCooldown: TimeInterval = 1.0 // 한 번 스와이프 후 1초 대기

  // MARK: - Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    setupUI()

    // CameraFeedService에서 발생하는 이벤트를 받을 수 있도록 delegate 설정
    cameraFeedService.delegate = self
  }

  /// 뷰가 나타날 때 카메라 시작
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
        // 필요 시 권한 안내 팝업 등 처리

      case .failed:
        print("Camera Configuration Failed - 카메라 설정 실패")
      }
    }
  }

  /// 뷰가 사라질 때 카메라 세션 중지
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    cameraFeedService.stopSession()
  }

  /// 레이아웃 변경 시점에 맞춰 카메라 프리뷰/오버레이 크기 조정
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    cameraFeedService.updateVideoPreviewLayer(toFrame: self.view.bounds)
    previewView.frame = view.bounds
    overlayView.frame = view.bounds
  }

  // MARK: - UI Setup
  private func setupUI() {
    // 1) previewView
    previewView = UIView(frame: view.bounds)
    view.addSubview(previewView)

    // 2) 카메라Unavailable Label
    cameraUnavailableLabel = UILabel()
    cameraUnavailableLabel.frame = CGRect(x: 20, y: 80, width: 200, height: 40)
    cameraUnavailableLabel.text = "Camera Unavailable"
    cameraUnavailableLabel.textAlignment = .center
    cameraUnavailableLabel.isHidden = true
    self.view.addSubview(cameraUnavailableLabel)

    // 3) resumeButton
    resumeButton = UIButton(type: .system)
    resumeButton.frame = CGRect(x: 20, y: 140, width: 80, height: 40)
    resumeButton.setTitle("Resume", for: .normal)
    resumeButton.addTarget(self, action: #selector(onClickResume), for: .touchUpInside)
    resumeButton.isHidden = true
    self.view.addSubview(resumeButton)

    // 4) overlayView
    overlayView = OverlayView(frame: self.view.bounds)
    self.view.addSubview(overlayView)
  }

  @objc private func onClickResume(_ sender: Any) {
    // 세션 재개 시도
    cameraFeedService.resumeInterruptedSession { [weak self] isSessionRunning in
      if isSessionRunning {
        self?.resumeButton.isHidden = true
        self?.cameraUnavailableLabel.isHidden = true
      }
    }
  }

  // MARK: - HandLandmarker 초기화
  private func initializeHandLandmarkerServiceOnSessionResumption() {
    clearAndInitializeHandLandmarkerService()
    startObserveConfigChanges()
  }

  @objc private func clearAndInitializeHandLandmarkerService() {
    // 1) 기존 서비스 제거
    handLandmarkerService = nil

    // 2) 새로 생성
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
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(clearAndInitializeHandLandmarkerService),
      name: InferenceConfigurationManager.notificationName,
      object: nil
    )
    isObserving = true
  }

  private func stopObserveConfigChanges() {
    if isObserving {
      NotificationCenter.default.removeObserver(
        self,
        name: InferenceConfigurationManager.notificationName,
        object: nil
      )
    }
    isObserving = false
  }
}

// MARK: - CameraFeedServiceDelegate
extension CameraViewController: CameraFeedServiceDelegate {
  func didOutput(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation) {
    // 각 프레임마다 배경큐에서 비동기로 감지
    let currentTimeMs = Date().timeIntervalSince1970 * 1000
    backgroundQueue.async { [weak self] in
      self?.handLandmarkerService?.detectAsync(
        sampleBuffer: sampleBuffer,
        orientation: orientation,
        timeStamps: Int(currentTimeMs)
      )
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
      guard let self = self else { return }

      // 1) 필요 시 inferenceResultDeliveryDelegate로 알림
      self.inferenceResultDeliveryDelegate?.didPerformInference(result: result)

      // 2) 손 랜드마커 결과가 없으면 종료
      guard let handLandmarkerResult = result?.handLandmarkerResults.first as? HandLandmarkerResult else { return }

      // 3) 이미지 사이즈
      let imageSize = self.cameraFeedService.videoResolution

      // 4) 오버레이 렌더링
      let handOverlays = OverlayView.handOverlays(
        fromMultipleHandLandmarks: handLandmarkerResult.landmarks,
        inferredOnImageOfSize: imageSize,
        ovelayViewSize: self.overlayView.bounds.size,
        imageContentMode: self.overlayView.imageContentMode,
        andOrientation: UIImage.Orientation.from(deviceOrientation: UIDevice.current.orientation)
      )

      self.overlayView.draw(
        handOverlays: handOverlays,
        inBoundsOfContentImageOfSize: imageSize,
        imageContentMode: .scaleAspectFill
      )

      // 5) 제스처 감지 → Flutter로 전달
      if let direction = self.detectSwipeDirection(landmarks: handLandmarkerResult.landmarks) {
        let channel = FlutterMethodChannel(
          name: "com.example.mediapipe2/gesture",
          binaryMessenger: (self.view.window?.rootViewController as! FlutterViewController).binaryMessenger
        )
        channel.invokeMethod("swipe", arguments: direction)
      }
    }
  }

  // MARK: - Swipe Detection (Improved)
  private func detectSwipeDirection(landmarks: [[NormalizedLandmark]]) -> String? {
    guard let hand = landmarks.first else { return nil }

    // 현재 시각
    let now = Date().timeIntervalSince1970

    // 최근 스와이프 후 쿨타임(detectionCooldown) 미만이면 무시
    if now - lastSwipeTime < detectionCooldown {
      return nil
    }

    // 검지손가락 끝(indexTip) 위치 (0~1 사이 normalized 좌표)
    let indexTip = hand[8]
    let currentPos = CGPoint(x: CGFloat(indexTip.x), y: CGFloat(indexTip.y))

    // positionsBuffer에 (현재 좌표, 현재 시각) 추가
    positionsBuffer.append((currentPos, now))

    // 너무 오래된 프레임(> maxSwipeInterval 초 이전)은 제거
    while let first = positionsBuffer.first,
          (now - first.1) > maxSwipeInterval {
      positionsBuffer.removeFirst()
    }

    // 버퍼의 첫 위치와 마지막 위치를 비교해 스와이프 판단
    guard let first = positionsBuffer.first else {
      return nil
    }
    let firstPos = first.0
    let deltaX = currentPos.x - firstPos.x

    // 충분히 많이 이동했는지 검사
    if abs(deltaX) >= minSwipeDistance {
      // 빠른 시간 안(<= maxSwipeInterval)에 이 정도 이동이면 스와이프 성공
      // 쿨타임 시작
      lastSwipeTime = now
      // 버퍼 비우기
      positionsBuffer.removeAll()

      return (deltaX > 0) ? "right" : "left"
    }

    // 아직 기준치 미달이면 스와이프 미인식
    return nil
  }
}