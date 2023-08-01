//
//  CameraViewHands.swift
//  multiCameraView
//
//  Created by DiegoGuarin on 7/17/23.
//

import SwiftUI
import AVFoundation
import Photos
import Vision


class CameraViewHands: CameraView {

    //Adding a variable that will carry the chirality
    var chirality : Int32 //chirality = 1 for Right and -1 for left
    var handPoseRequest = VNDetectHumanHandPoseRequest()
    var imageHandlerRequest: VNImageRequestHandler?
    
    
    var handInPosition = false
    var isRecording = false
    
    var boundaryTopLeft: [CGFloat]?
    var boundaryBottomRight: [CGFloat]?
    
    
    var handsInPositionCounterStartingTime:Date? =  nil
    var handsInPositionCounter:Double? = 0
    var handsOutPositionCounterStartingTime:Date? = nil
    var handsOutPositionCounter:Double? = 0
    
    
    var handDetectionFeedback : UIButton = {
        //        let label = UILabel(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width/2, height: view.bounds.size.width/2))
        //            label.center = CGPoint(x: view.center.x, y: view.center.y)
        let button = UIButton()
        button.backgroundColor = .none
        //        button.tintColor = .none
        button.layer.borderColor = UIColor.red.cgColor
        button.layer.borderWidth = 10
        button.layer.cornerRadius = 10
        button.isOpaque = true
        button.alpha = 0.5
        button.isHidden = false
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .center
        button.setTitleColor(UIColor.black, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 36, weight: .bold)
        return button
    }()
    
    var handDetectionLabel : UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.backgroundColor = UIColor(red:CGFloat(0/255.0), green:CGFloat(33.0/255.0), blue:CGFloat(165.0/255.0), alpha:CGFloat(1))
        label.textColor = .white
        label.isHidden = true
        label.text = "Test Text"
        label.font = .systemFont(ofSize: 36, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.layer.cornerRadius = 5
        label.widthAnchor.constraint(equalToConstant: 300.0).isActive = true
        return label
    }()
    
    
    
    
    init(desiredResolution: Binding<String>, desiredFPS: Binding<String>, desiredExtension: Binding<String>, desiredCodec: Binding<String>, chilarity:String){
        self.chirality = chilarity=="Right" ? 1 : -1 //chirality = 1for Right and -1 for left
        super.init(desiredResolution: desiredResolution, desiredFPS: desiredFPS, desiredExtension: desiredExtension, desiredCodec: desiredCodec)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        newSetupView()
        
        //        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(timerAction), userInfo: nil, repeats: true)
        
        
    }
    
    //set up camera session
    //override this function to include storing the position of the feedback frame
    override func setupAndStartCaptureSession() {
        //send to other process
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession = AVCaptureSession()
            //configure capture session
            self.captureSession.beginConfiguration()
            self.captureSession.automaticallyConfiguresCaptureDeviceForWideColor = true
            
            self.setupVideoInputs()
            DispatchQueue.main.async {
                self.setupPreviewLayer()
            }
            
            self.setupAudioInput()
            
            self.setupOutput()
            self.setupVideoOutput()
            self.captureSession.commitConfiguration()
            
            //start session
            self.captureSession.startRunning()
        }
        
        //position of the feedback frame normalized to PreviewLayer Size
        boundaryTopLeft = [handDetectionFeedback.frame.minX / view.bounds.width, handDetectionFeedback.frame.maxY / view.bounds.height]
        boundaryBottomRight = [handDetectionFeedback.frame.maxX / view.bounds.width, handDetectionFeedback.frame.minY / view.bounds.height]
        
        print(boundaryTopLeft!, boundaryBottomRight! )
    }
    
    func newSetupView() {
        
        //        previewView = UIView(frame: CGRect(x: 0,
        //                                           y: 0,
        //                                           width: UIScreen.main.bounds.size.width,
        //                                           height: UIScreen.main.bounds.size.height))
        //        previewView.contentMode = UIView.ContentMode.scaleAspectFit
        //        view.addSubview(previewView)
        
        view.backgroundColor = .black
        view.addSubview(recordButton)
        view.addSubview(counterLabel)
        view.addSubview(handDetectionFeedback)
        view.addSubview(handDetectionLabel)
        
        
        NSLayoutConstraint.activate([
            
            recordButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            recordButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            recordButton.widthAnchor.constraint(equalToConstant: 80),
            recordButton.heightAnchor.constraint(equalToConstant: 80),
            
            handDetectionFeedback.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            handDetectionFeedback.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            handDetectionFeedback.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.75),
            handDetectionFeedback.heightAnchor.constraint(equalTo: view.heightAnchor , multiplier: 0.5),
            
            handDetectionLabel.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            //            handDetectionLabel.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            handDetectionLabel.topAnchor.constraint(equalTo: handDetectionFeedback.topAnchor, constant: 10)
            
        ])
        
        recordButton.addTarget(self, action: #selector(onClickRecordButton(_:)), for: .touchUpInside)
        
        
        
        
    }
    
    
    //override the captureOutput function to implement custom handling of frames
    
    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        if movieFileOutput.isRecording { //if recording, count and show the time
            if (startingFrame == nil) {
                startingFrame = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            } else {
                totalSeconds = Int(CMTimeGetSeconds(CMTimeSubtract(CMSampleBufferGetPresentationTimeStamp(sampleBuffer), startingFrame!)))
                let _:Int = Int(totalSeconds / 3600)
                minutes = Int(totalSeconds % 3600 / 60)
                seconds = Int((totalSeconds % 3600) % 60)
                
                
                DispatchQueue.main.async() {
                    self.counterLabel.text = self.stringFromInt(minutes: self.minutes, seconds:self.seconds)
                }
                
                if seconds > 15 {
                    //reset counter
                    resetTimerandLabel()
                    //if it was recording (isRecording) stop recording
                    if isRecording{stopRecordingWithTimer()}
                }
            }
        }
        
        
        imageHandlerRequest = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        
        do {
            try imageHandlerRequest?.perform([handPoseRequest])
            
            guard let observation = handPoseRequest.results else {
                //if handPoseRequest retuns an error, reset counter
                resetTimerandLabel()
                //if it was recording (isRecording) stop recording
                if isRecording{stopRecordingWithTimer()}
                return
            }
            
            if (observation.count == 0) { //no hands detected
                //reset counter
                resetTimerandLabel()
                //if it was recording (isRecording) stop recording
                if isRecording{stopRecordingWithTimer()}
                return
            } else if (observation.count == 1) || (observation.count == 2) { //only move forward if hands are detected
                let handPose = observation.first! //take the hand closest to the screen
                if(handPose.chirality.rawValue  == self.chirality)  { //check if that hand matches the desired hand
                    
                    let handBoundingBox = computeHandBoudingBox(handPose:handPose)
                    
                    if (handBoundingBox.topLeft[0] > boundaryTopLeft![0]) && (handBoundingBox.topLeft[1]<boundaryTopLeft![1]) && (handBoundingBox.bottomRight[0] < boundaryBottomRight![0]) && (handBoundingBox.bottomRight[1] > boundaryBottomRight![1]) {
                        //hands are in desired area, start a counter
                        
                        
                        if !isRecording
                        {//go here only if not recording
                            if (handsInPositionCounterStartingTime ==  nil) {// if no counter, then start the counter
                                handsInPositionCounterStartingTime = Date()// save current time
                                handsInPositionCounter = 0
                            } else {//increase the counter
                                handsInPositionCounter = -handsInPositionCounterStartingTime!.timeIntervalSinceNow
                                //update text in label and display it
                                DispatchQueue.main.async()
                                {
                                    self.handDetectionLabel.isHidden = false
                                    self.handDetectionLabel.text = "Recording in \(3-Int(self.handsInPositionCounter!))"

                                }
                                
                            }
                            
                            if handsInPositionCounter! >= 3
                            {   //the counter reached to 3s
                                //remove label, change box color, and trigger recording
                                DispatchQueue.main.async()
                                {
                                    
                                    self.isRecording = true //update the property that carries the isRecording information
                                    self.handDetectionFeedback.layer.borderColor = UIColor(red:CGFloat(0/255.0), green:CGFloat(100/255.0), blue:CGFloat(0/255.0), alpha:CGFloat(1)).cgColor
                                    self.handDetectionLabel.isHidden=true
                                    self.triggerRecording()
                                }
                            }
                            
                            
                            
                        } else { //is recording
                            handsOutPositionCounterStartingTime = nil
                            handsOutPositionCounter = 0
                        }
                        
                        
                    } else
                    { //hands leave the desired area, reset the counter
                        resetTimerandLabel()
                        //isRecording and hands leave the area
                        if isRecording{stopRecordingWithTimer()}
                    }
                } else { //wrong hand is closest to the screen, stop recording
                    //reset counter
                    resetTimerandLabel()
                    //if it was recording (isRecording) stop recording
                    if isRecording{stopRecordingWithTimer()}
                }
                
            }
            
            
        } catch { //imagehandlerrequest failed
            //reset counter
            resetTimerandLabel()
            //if it was recording (isRecording) stop recording
            if isRecording{stopRecordingWithTimer()}
            return
        }
        
    }
    
    func triggerRecording () {
        guard let movieFileOutput = self.movieFileOutput else {return}
        recordButton.isEnabled = false
        sessionQueue.async {
            if !movieFileOutput.isRecording {
                if UIDevice.current.isMultitaskingSupported {
                    self.backgroundRecordingID = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
                }
                
                let movieFileOutputConnection = movieFileOutput.connection(with: .video)
                movieFileOutputConnection?.videoOrientation = .portrait

                let availableVideoCodecTypes = movieFileOutput.availableVideoCodecTypes
                
                
                if self.desiredCodec.contains("h.264") {
                    if availableVideoCodecTypes.contains(.h264) {
                        movieFileOutput.setOutputSettings([AVVideoCodecKey : AVVideoCodecType.h264], for: movieFileOutputConnection!)
                    }
                } else {
                    if availableVideoCodecTypes.contains(.hevc) {
                        movieFileOutput.setOutputSettings([AVVideoCodecKey : AVVideoCodecType.hevc], for: movieFileOutputConnection!)
                    }
                }
                //change to hvec if recording videos encoded with hvec apple codec
                
                // Start recording video to a temporary file.
                let outputFileName = NSUUID().uuidString
                if self.desiredExtension.contains("mp4") {
                    let outputFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mp4")!)
                    movieFileOutput.startRecording(to: URL(fileURLWithPath: outputFilePath), recordingDelegate: self)
                } else {
                    let outputFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mov")!)
                    movieFileOutput.startRecording(to: URL(fileURLWithPath: outputFilePath), recordingDelegate: self)
                }
                
            } 
            
        }
                
    }
    
    func stopRecordingWithTimer () {
        
        if (handsOutPositionCounterStartingTime ==  nil) {// if no counter, then start the counter
            handsOutPositionCounterStartingTime = Date()// save current time
            handsOutPositionCounter = 0
        } else {//increase the counter
            handsOutPositionCounter = -handsOutPositionCounterStartingTime!.timeIntervalSinceNow
        }
        
        if handsOutPositionCounter! > 1 {
            //hands have been out of area for more than one second, stop recording and reset all timers
            isRecording = false
            handsOutPositionCounterStartingTime = nil
            handsOutPositionCounter = 0
            movieFileOutput.stopRecording()
            DispatchQueue.main.async()
            {
                self.handDetectionFeedback.layer.borderColor = UIColor.red.cgColor
                //return to previous screen??
                
            }
            
        }
        
    }
    
    func resetTimerandLabel () {
        handsInPositionCounterStartingTime = nil
        handsInPositionCounter = 0
        DispatchQueue.main.async()
        {
            self.handDetectionLabel.isHidden=true
        }
    }
    
}

extension CameraViewHands {
    
    func computeHandBoudingBox (handPose: VNHumanHandPoseObservation) -> (topLeft:[Double], bottomRight:[Double]) {
        
        let thumbPoints = try! handPose.recognizedPoints(VNHumanHandPoseObservation.JointsGroupName.thumb)
        let indexFingerPoints = try! handPose.recognizedPoints(VNHumanHandPoseObservation.JointsGroupName.indexFinger)
        let middleFingerPoints = try! handPose.recognizedPoints(VNHumanHandPoseObservation.JointsGroupName.middleFinger)
        let ringFingerPoints = try! handPose.recognizedPoints(VNHumanHandPoseObservation.JointsGroupName.ringFinger)
        let littleFingerPoints = try! handPose.recognizedPoints(VNHumanHandPoseObservation.JointsGroupName.littleFinger)
        let wristPoint = try! handPose.recognizedPoint(VNHumanHandPoseObservation.JointName.wrist)
        
        //get the tip of each finger
        let thumbTipPoint = thumbPoints[.thumbTip]
        let indexTipPoint = indexFingerPoints[.indexTip]
        let middleTipPoint = middleFingerPoints[.middleTip]
        let ringTipPoint = ringFingerPoints[.ringTip]
        let littleTipPoint = littleFingerPoints[.littleTip]
        
        //                    var max_x: [Float] = []
        let maxX = [wristPoint.x, thumbTipPoint!.x, indexTipPoint!.x, middleTipPoint!.x, ringTipPoint!.x, littleTipPoint!.x].max()!
        let minX = [wristPoint.x, thumbTipPoint!.x, indexTipPoint!.x, middleTipPoint!.x, ringTipPoint!.x, littleTipPoint!.x].min()!
        let maxY = [wristPoint.y, thumbTipPoint!.y, indexTipPoint!.y, middleTipPoint!.y, ringTipPoint!.y, littleTipPoint!.y].max()!
        let minY = [wristPoint.y, thumbTipPoint!.y, indexTipPoint!.y, middleTipPoint!.y, ringTipPoint!.y, littleTipPoint!.y].min()!
        let topLeft = [1-maxX, maxY]
        let bottomRight = [1-minX, minY]
        
        return (topLeft, bottomRight)
    }
}


