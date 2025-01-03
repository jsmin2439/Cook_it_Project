import Foundation
import UIKit
import AVFoundation
import MediaPipeTasksVision

class GestureRecognition {
    private var handDetector: HandDetector?

    init() {
        setupHandDetector()
    }

    private func setupHandDetector() {
        let options = HandDetectorOptions()
        options.maxNumHands = 2
        handDetector = HandDetector(options: options)
    }

    func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, completion: @escaping ([Hand]?) -> Void) {
        guard let handDetector = handDetector else {
            completion(nil)
            return
        }

        handDetector.process(sampleBuffer) { hands, error in
            guard error == nil else {
                print("Hand detection error: \(error!.localizedDescription)")
                completion(nil)
                return
            }
            completion(hands)
        }
    }
}