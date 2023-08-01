//
//  CameraViewBody.swift
//  multiCameraView
//
//  Created by DiegoGuarin on 7/17/23.
//

import SwiftUI
import AVFoundation
import Photos

class CameraView: UIViewController, AVCaptureFileOutputRecordingDelegate {

    //MARK - Variables
    var previewView: UIView!
    var captureSession: AVCaptureSession!
    var microphone: AVCaptureDevice!
    var microphoneInput: AVCaptureDeviceInput!
    var videoDevice: AVCaptureDevice!
    var videoDeviceInput: AVCaptureDeviceInput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var videoOutput: AVCaptureVideoDataOutput!
    var movieFileOutput: AVCaptureMovieFileOutput!
    var selectedMovieMode10BitDeviceFormat: AVCaptureDevice.Format?
    var backgroundRecordingID: UIBackgroundTaskIdentifier?
    
//    var currentTime: CMTime?
    var startingFrame: CMTime! =  nil
    var minutes: Int!
    var seconds: Int!
    var totalSeconds: Int!

    
    let sessionQueue = DispatchQueue(label: "session queue")
  
    
    //variable that is binded to another view
    @Binding var desiredResolution: String
    @Binding var desiredFPS: String
    @Binding var desiredExtension: String
    @Binding var desiredCodec: String
    init(desiredResolution: Binding<String>, desiredFPS: Binding<String>, desiredExtension: Binding<String>, desiredCodec: Binding<String>){
        _desiredResolution = desiredResolution
        _desiredFPS = desiredFPS
        _desiredCodec = desiredCodec
        _desiredExtension = desiredExtension
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK - Components
    let recordButton : UIButton = {
        let button = UIButton()
        button.backgroundColor = .red
        button.tintColor = .white
        button.alpha = 0.5
        button.isOpaque=true
        button.layer.borderColor = UIColor.black.cgColor
        button.layer.borderWidth = 5
        button.layer.cornerRadius = 40
        button.translatesAutoresizingMaskIntoConstraints = false
        return button

    }()
    
    let counterLabel : UILabel = {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 30))
        label.center = CGPoint(x: UIScreen.main.bounds.size.width/2, y: UIScreen.main.bounds.size.height-150)
        label.textAlignment = .center
        label.text = "00:00"
        label.font = UIFont.boldSystemFont(ofSize: 30)
        label.textColor = UIColor.white
        label.backgroundColor = UIColor.red
        label.isHidden = true
        return label
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkPermissions()
        setupAndStartCaptureSession()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        captureSession.stopRunning()
    }
    
    //set up camera session
    func setupAndStartCaptureSession() {
        //send to othe process
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
    }
    func setupVideoInputs(){
        //default camera is front, go to back if front not available
        var defaultVideoDevice : AVCaptureDevice? = nil
        
        if let frontCameraDevice =  AVCaptureDevice.default(.builtInWideAngleCamera,for: .video, position: .front) {
            defaultVideoDevice = frontCameraDevice
        } else if let frontCameraDevice =  AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front) {
            defaultVideoDevice = frontCameraDevice
        } else if let backCameraDevice = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) {
            defaultVideoDevice = backCameraDevice
        } else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            defaultVideoDevice = backCameraDevice
        }
        
        
        guard let videoDevice = defaultVideoDevice else {
            fatalError("Default video device is unavailable.")
        }
        
        
        guard let vDevInput = try? AVCaptureDeviceInput(device: videoDevice) else {fatalError("could not create input device from back camera")}
        videoDeviceInput = vDevInput
        if captureSession.canAddInput(videoDeviceInput) {
            captureSession.addInput(videoDeviceInput)
        } else {
            fatalError("Could not add video device input to the session")
        }
        

        do {
            try videoDeviceInput.device.lockForConfiguration()
            let fps60 = CMTimeMake(value: 1, timescale: Int32(desiredFPS)!)
            videoDeviceInput.device.activeFormat = formatPicker(videoDeviceInput:videoDeviceInput, desiredResolution: desiredResolution, desiredFPS: desiredFPS)!
            videoDeviceInput.device.activeVideoMinFrameDuration = fps60;
            videoDeviceInput.device.activeVideoMaxFrameDuration = fps60;
            videoDeviceInput.device.unlockForConfiguration()
        } catch {
            print("Could not set up a format with 60 FPS: \(error)")
        }
    }
    func setupAudioInput(){
        
        if let device = AVCaptureDevice.default(for: AVMediaType.audio) {
            microphone = device
        } else {
            //handle error
            fatalError("no microphone")
        }
        guard let mInput = try? AVCaptureDeviceInput(device: microphone) else {fatalError("could not create input device from microphone")}
        microphoneInput = mInput
        if captureSession.canAddInput(microphoneInput) {
            captureSession.addInput(microphoneInput)
        } else {
            fatalError("could not add audio device to capture session")
        }
             
        
    }
    func setupPreviewLayer(){
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
        previewLayer.frame = self.view.layer.frame
    }
    func setupOutput(){
        videoOutput = AVCaptureVideoDataOutput()
        let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInteractive)
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        } else {
            fatalError("could not add video output")
        }
        
        videoOutput.connections.first?.videoOrientation = .portrait
    }
    func setupVideoOutput(){
        movieFileOutput = AVCaptureMovieFileOutput()
        movieFileOutput.movieFragmentInterval = CMTime.invalid
        
        if captureSession.canAddOutput(movieFileOutput) {
//            captureSession.beginConfiguration()
            captureSession.addOutput(movieFileOutput)
            
            selectedMovieMode10BitDeviceFormat = tenBitVariantOfFormat(activeFormat: videoDeviceInput.device.activeFormat)
            
            if selectedMovieMode10BitDeviceFormat != nil {
                do {
                    try videoDeviceInput.device.lockForConfiguration()
                    videoDeviceInput.device.activeFormat = selectedMovieMode10BitDeviceFormat!
                    print("Setting 'x420' format \(String(describing: selectedMovieMode10BitDeviceFormat)) for video recording")
                    videoDeviceInput.device.unlockForConfiguration()
                    print(desiredResolution)
                } catch {
                    print("Could not lock device for configuration: \(error)")
                    
                    
                }
            }
            
            if let connection = movieFileOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
               }
            
//            captureSession.commitConfiguration()
        }
    }
    
    /// - Tag: DidStartRecording
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        // Enable the Record button to let the user stop recording.
        DispatchQueue.main.async {
            self.recordButton.isEnabled = true
            self.recordButton.layer.borderColor = UIColor.white.cgColor
            self.recordButton.layer.borderWidth = 10
            self.counterLabel.isHidden = false
        }
    }
    
    /// - Tag: DidFinishRecording
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        // Note: Because we use a unique file path for each recording, a new recording won't overwrite a recording mid-save.
        func cleanup() {
            let path = outputFileURL.path
            if FileManager.default.fileExists(atPath: path) {
                do {
                    try FileManager.default.removeItem(atPath: path)
                } catch {
                    print("Could not remove file at url: \(outputFileURL)")
                }
            }
            
            if let currentBackgroundRecordingID = backgroundRecordingID {
                backgroundRecordingID = UIBackgroundTaskIdentifier.invalid
                
                if currentBackgroundRecordingID != UIBackgroundTaskIdentifier.invalid {
                    UIApplication.shared.endBackgroundTask(currentBackgroundRecordingID)
                }
            }
        }
        
        var success = true
        
        if error != nil {
            print("Movie file finishing error: \(String(describing: error))")
            success = (((error! as NSError).userInfo[AVErrorRecordingSuccessfullyFinishedKey] as AnyObject).boolValue)!
        }
      
        
        if success {
            // Check the authorization status.
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized {
                    // Save the movie file to the photo library and cleanup.
                    PHPhotoLibrary.shared().performChanges({
                        let options = PHAssetResourceCreationOptions()
                        options.shouldMoveFile = true
                        let creationRequest = PHAssetCreationRequest.forAsset()
                        creationRequest.addResource(with: .video, fileURL: outputFileURL, options: options)
                        
                        // Specify the location the movie was recoreded
                        // removed, but it might be good to add
                        // creationRequest.location = self.locationManager.location
                    }, completionHandler: { success, error in
                        if !success {
                            print("couldn't save the movie to your photo library: \(String(describing: error))")
                        }
                        cleanup()
                    }
                    )
                } else {
                    cleanup()
                }
            }
        } else {
            cleanup()
        }
        
        // Enable the Camera and Record buttons to let the user switch camera and start another recording.
        DispatchQueue.main.async {
            // Only enable the ability to change camera if the device has more than one camera.
            self.recordButton.isEnabled = true
            self.recordButton.layer.borderColor = UIColor.black.cgColor
            self.recordButton.layer.borderWidth = 5
            self.startingFrame = nil
            self.counterLabel.text = "00:00"
            self.counterLabel.isHidden = true
        }
    }
    
    
    
    
    @objc func onClickRecordButton(_ sender: UIButton) {
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
                
                
               
                
            } else {
                
                movieFileOutput.stopRecording()
                
            }
            
        }
    }
    
}

extension CameraView: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
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
            }
        }
        
    }
    
}

extension CameraView {
    //MARK - Setup View
    func setupView() {
        
//        previewView = UIView(frame: CGRect(x: 0,
//                                           y: 0,
//                                           width: UIScreen.main.bounds.size.width,
//                                           height: UIScreen.main.bounds.size.height))
//        previewView.contentMode = UIView.ContentMode.scaleAspectFit
//        view.addSubview(previewView)
        
        view.backgroundColor = .black
        view.addSubview(recordButton)
        view.addSubview(counterLabel)
        
        NSLayoutConstraint.activate([
        
            recordButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            recordButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            recordButton.widthAnchor.constraint(equalToConstant: 80),
            recordButton.heightAnchor.constraint(equalToConstant: 80),
            
//            counterLabel.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
//            counterLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            
            
        ])
        
        recordButton.addTarget(self, action: #selector(onClickRecordButton(_:)), for: .touchUpInside)
        
        
        
    }
    
    //MARK:- Permissions
    func checkPermissions() {
        let cameraAuthStatus =  AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        switch cameraAuthStatus {
          case .authorized:
            return
          case .denied:
            abort()
          case .notDetermined:
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler:
            { (authorized) in
              if(!authorized){
                abort()
              }
            })
          case .restricted:
            abort()
          @unknown default:
            fatalError()
        }
        
        let microphoneAuthStatus =  AVCaptureDevice.authorizationStatus(for: AVMediaType.audio)
        switch microphoneAuthStatus {
          case .authorized:
            return
          case .denied:
            abort()
          case .notDetermined:
            AVCaptureDevice.requestAccess(for: AVMediaType.audio, completionHandler:
            { (authorized) in
              if(!authorized){
                abort()
              }
            })
          case .restricted:
            abort()
          @unknown default:
            fatalError()
        }
    }
}

extension CameraView {
    func tenBitVariantOfFormat(activeFormat: AVCaptureDevice.Format) -> AVCaptureDevice.Format? {
        let formats = self.videoDeviceInput.device.formats
        
        let formatIndex = formats.firstIndex(of: activeFormat)!
        
        let activeDimensions = CMVideoFormatDescriptionGetDimensions(activeFormat.formatDescription)
        let activeMaxFrameRate = activeFormat.videoSupportedFrameRateRanges.last?.maxFrameRate
        let activePixelFormat = CMFormatDescriptionGetMediaSubType(activeFormat.formatDescription)
        
        /*
         AVCaptureDeviceFormats are sorted from smallest to largest in resolution and frame rate.
         For each resolution and max frame rate there's a cluster of formats that only differ in pixelFormatType.
         Here, we're looking for an 'x420' variant of the current activeFormat.
         */
        if activePixelFormat != kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange {
            // Current activeFormat is not a 10-bit HDR format, find its 10-bit HDR variant.
            for index in formatIndex + 1..<formats.count {
                let format = formats[index]
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                let maxFrameRate = format.videoSupportedFrameRateRanges.last?.maxFrameRate
                let pixelFormat = CMFormatDescriptionGetMediaSubType(format.formatDescription)
                
                // Don't advance beyond the current format cluster
                if activeMaxFrameRate != maxFrameRate || activeDimensions.width != dimensions.width || activeDimensions.height != dimensions.height {
                    break
                }
                
                if pixelFormat == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange {
                    return format
                }
            }
        } else {
            return activeFormat
        }
        
        return nil
    }
    
    
    func formatPicker(videoDeviceInput:AVCaptureDeviceInput, desiredResolution:String, desiredFPS:String) -> AVCaptureDevice.Format? {
        
        //Pick the format that has 60fps only
        let formats = videoDeviceInput.device.formats
              
        var arrayOfFormats: [listingFormats] = [];
        
        for (index, format) in formats.enumerated(){
            let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            
            arrayOfFormats.append(listingFormats(index:Int(index), width: size.width, height: size.height, maxFPS: Float(format.videoSupportedFrameRateRanges.first!.maxFrameRate)))
            //            print(format,width,height,maxFPS)
        }
        
        let desiredWidth = desiredResolution.split(separator: "x")[0]

        let formatsWith60FPS = arrayOfFormats.filter{$0.width>=1280 && $0.maxFPS>=30}
        //pick the format with dimensions desired dimensions and fps, if it doesn't exists, pick the format with dimensions 1280x720 at 30fps
        let selectedFormat: listingFormats? = formatsWith60FPS.first(where: {$0.width==Int32(desiredWidth) && $0.maxFPS==Float(desiredFPS)}) ?? formatsWith60FPS.first(where: {$0.width==1280 && $0.maxFPS==30})
        
        return formats[selectedFormat!.index]
    }
    
    struct listingFormats: Identifiable {
        var id = UUID()
        var index : Int
        var width : Int32
        var height : Int32
        var maxFPS : Float
    }
}

extension CameraView {
    func stringFromInt (minutes:Int, seconds:Int) -> String {
        if minutes<10 && seconds<10 {
            return "0\(minutes):0\(seconds)"
        } else if minutes<10 && seconds>=10 {
            return "0\(minutes):\(seconds)"
        } else if minutes>=10 && seconds<10 {
            return "\(minutes):0\(seconds)"
        } else {
            return "\(minutes):\(seconds)"
        }
    }
}
//#Preview {
//    CameraView() as! any View
//}
