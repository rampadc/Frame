import UIKit
import AVFoundation
import GCDWebServer

class CameraViewController: UIViewController, GCDWebServerDelegate {
  
  private var ndiWrapper: NDIWrapper?
  private var captureSession = AVCaptureSession()
  private var captureDeviceInput: AVCaptureDeviceInput!
  private var videoDataOutput: AVCaptureVideoDataOutput!
  private var device: AVCaptureDevice!
  private var isSending: Bool = false
  
  private var previewLayer: AVCaptureVideoPreviewLayer!
  
  // MARK: Properties
  @IBOutlet weak var remoteControlsLabel: UILabel!
  @IBOutlet weak var sendStreamButton: UIButton!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Disable UI, only enable if NDI is initialised and session starts running
    NDIControls.startWebServer()
    NDIControls.webServer.delegate = self
    
    ndiWrapper = NDIWrapper()
    
    //captureSession.sessionPreset = .hd1280x720
    //captureSession.sessionPreset = .iFrame960x540
    captureSession.sessionPreset = .hd1920x1080
    
    device = AVCaptureDevice.default(for: .video)
    device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 30)
    
    captureDeviceInput = try! AVCaptureDeviceInput(device: device)
    if captureSession.canAddInput(captureDeviceInput) {
      captureSession.addInput(captureDeviceInput)
    }
    
    videoDataOutput = AVCaptureVideoDataOutput()
    videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey :  kCVPixelFormatType_32BGRA] as [String : Any]
    videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
    videoDataOutput.alwaysDiscardsLateVideoFrames = true
    if captureSession.canAddOutput(videoDataOutput) {
      captureSession.addOutput(videoDataOutput)
    }
    
    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
    previewLayer.connection?.videoOrientation = .landscapeRight
    previewLayer.frame = view.frame
    view.layer.insertSublayer(previewLayer, at: 0)
    
    sendStreamButton.backgroundColor = .gray
    sendStreamButton.layer.masksToBounds = true
    sendStreamButton.setTitle("Send", for: .normal)
    sendStreamButton.layer.cornerRadius = 18
    sendStreamButton.layer.position = CGPoint(x: view.bounds.width / 2, y: view.bounds.height - 60)
    sendStreamButton.addTarget(self, action: #selector(sendStreamButton_action(sender:)), for: .touchUpInside)
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    captureSession.startRunning()
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    captureSession.stopRunning()
  }
  
  private func startSending() {
    guard let ndiWrapper = self.ndiWrapper else { return }
    ndiWrapper.start(UIDevice.current.name)
  }
  
  private func stopSending() {
    guard let ndiWrapper = self.ndiWrapper else { return }
    ndiWrapper.stop()
  }
  
  @objc private func sendStreamButton_action(sender: UIButton!) {
    if !isSending {
      startSending()
      isSending = true
      sendStreamButton.setTitle("Sending...", for: .normal)
      sendStreamButton.backgroundColor = .blue
    } else {
      isSending = false
      sendStreamButton.setTitle("Send", for: .normal)
      sendStreamButton.backgroundColor = .gray
      stopSending()
    }
  }
  
  func webServerDidStart(_ server: GCDWebServer) {
    remoteControlsLabel.text = "Control: \(server.serverURL?.absoluteString ?? "Unknown")"
  }
}

extension CameraViewController : AVCaptureVideoDataOutputSampleBufferDelegate {
  
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    
    let processedFrame = processVideo(sampleBuffer)
    guard let ndiWrapper = self.ndiWrapper, isSending else { return }
    ndiWrapper.send(processedFrame)
  }
  
  func processVideo(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer {
    guard let videoPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
          let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
      return sampleBuffer
    }
    
    // use `var` when start to modify finalVideoPixelBuffer, using let` to suppress warnings for now
    let finalVideoPixelBuffer = videoPixelBuffer
    
    // TODO: apply various filter transformations on videoPixelBuffer
    
    // create a sample buffer from processed finalVideoPixelBuffer
    var timing = CMSampleTimingInfo()
    var copiedSampleBuffer: CMSampleBuffer?
    CMSampleBufferCreateReadyWithImageBuffer(
      allocator: kCFAllocatorDefault,
      imageBuffer: finalVideoPixelBuffer,
      formatDescription: formatDescription,
      sampleTiming: &timing,
      sampleBufferOut: &copiedSampleBuffer)
    return copiedSampleBuffer!
  }
}
