//
//  ViewController.swift
//  RPSGame
//
//  Created by João Paulo de Oliveira Sabino on 04/07/19.
//  Copyright © 2019 João Paulo de Oliveira Sabino. All rights reserved.
//

import UIKit
import CoreML
import AVFoundation
import Vision

class ViewController: UIViewController, UIGestureRecognizerDelegate {

    @IBOutlet weak var videoPreview: UIView!
    @IBOutlet weak var timerLabel: UILabel!
    
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var targetLabel: UILabel!
    
    var videoCapture: VideoCapture!
    
    var gameManager = GameManager.shared
    
    var gesture: UITapGestureRecognizer!
    var gameIsRunning = false
    var remainingTime: Int = 30 {
        didSet {
            timerLabel.text = "\(remainingTime)s"
        }
    }
    
    lazy var classificationRequest: VNCoreMLRequest = {
        do {
            /*
             Use the Swift class `MobileNet` Core ML generates from the model.
             To use a different Core ML classifier model, add it to the project
             and replace `MobileNet` with that model's generated Swift class.
             */
            let model = try VNCoreMLModel(for: HandSigns().model)
            
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processClassifications(for: request, error: error)
            })
            
            request.imageCropAndScaleOption = .centerCrop
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        timerLabel.text = "Touch to Start"
        scoreLabel.text = "Score: 0"
        videoPreview.isUserInteractionEnabled = true
        videoPreview.target(forAction: #selector(start), withSender: nil)
        
        gesture = UITapGestureRecognizer(target: self, action:#selector(handleTap(recognizer:)))
        gesture.delegate = self
        
        videoPreview.addGestureRecognizer(gesture)
        setUpCamera()
        
        //start()
        gameManager.setNew()
        targetLabel.text = gameManager.current.rawValue
        
        
    }
    
    @objc func handleTap(recognizer: UITapGestureRecognizer) {
        self.start()
        videoPreview.removeGestureRecognizer(gesture)
    }

    @objc func start() {
        gameIsRunning = true
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { (timer) in
            self.remainingTime -= 1
            if self.remainingTime <= 0 {
                timer.invalidate()
                self.gameIsRunning = false
                let yourScore = self.gameManager.score
                var highscore = UserDefaults.standard.integer(forKey: "highscore")
                
                if yourScore > highscore {
                    highscore = yourScore
                }
                
                let alert = UIAlertController(title: "Seu Score: \(yourScore)", message: "HighScore: \(highscore)", preferredStyle: .alert)

                let restartAction = UIAlertAction(title: "Restart", style: .default) { (_) in
                    self.start()
                }
                alert.addAction(restartAction)
                
                self.present(alert, animated: true, completion: nil)
                
                
                //UserDefaults
                let defaults = UserDefaults.standard
                defaults.set(yourScore, forKey: "highscore")
                
                self.remainingTime = 30
                self.gameManager.score = 0
                
                self.timerLabel.text = "30s"
                self.scoreLabel.text = "Score: 0"
                
                
            }
        }
        
    }

    

    
    
    func processClassifications(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results else {
                if let error = error {
                    print("Unable to classify image.\n\(error.localizedDescription)")
                    //self.targetLabel.text = "Unable to classify image.\n\(error.localizedDescription)"
                }
                return
            }
            // The `results` will always be `VNClassificationObservation`s, as specified by the Core ML model in this project.
            let classifications = results as! [VNClassificationObservation]
            
            if classifications.isEmpty {
                self.targetLabel.text = "Nothing recognized."
            } else {
                // Display top classifications ranked by confidence in the UI.
                if let classification = classifications.first, self.gameIsRunning {

                    if self.gameManager.verify(input: classification.identifier) && classification.confidence >= 0.8 {
                        self.gameManager.setNew()
                        self.targetLabel.text = "\(self.gameManager.current.rawValue)"
                        
                        self.scoreLabel.text = "Score: \(self.gameManager.score)"
                    }
                    

                }
                
            }
        }
    }
    
    func updateClassifications(for image: CIImage) {

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(ciImage: image)
            do {
                try handler.perform([self.classificationRequest])
            } catch {
                print("Failed to perform classification.\n\(error.localizedDescription)")
            }
        }
    }
    
    func setUpCamera() {
        videoCapture = VideoCapture()
        videoCapture.delegate = self
        videoCapture.fps = 30
        videoCapture.setUp { (success) in
            if success {
                // add preview view on the layer
                if let previewLayer = self.videoCapture.previewLayer {
                    self.videoPreview.layer.addSublayer(previewLayer)
                    //resize preview layer
                    self.videoCapture.previewLayer?.frame = self.videoPreview.bounds
                }
                
                // start video preview when setup is done
                self.videoCapture.start()
            }
        }
    }
}

extension ViewController: VideoCaptureDelegate {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame: CVPixelBuffer?, timestamp: CMTime) {
        if let pixelBuffer = didCaptureVideoFrame {
            updateClassifications(for: CIImage(cvPixelBuffer: pixelBuffer))
            
        }
    }
}

