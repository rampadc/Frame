import UIKit
import AVFoundation
import GCDWebServer
import CoreImage
import CoreImage.CIFilterBuiltins

class CameraViewController: UIViewController {
  // MARK: Properties
  @IBOutlet weak var remoteControlsLabel: UILabel!
  @IBOutlet weak var sendStreamButton: UIButton!
  @IBOutlet weak var metalView: MetalView!
  
//  private var previewLayer: AVCaptureVideoPreviewLayer!
  private var cameraCapture: CameraCapture?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    NDIControls.instance.delegate = self
    
    NotificationCenter.default.addObserver(self, selector: #selector(onNdiWebSeverDidStart(_:)), name: .ndiWebServerDidStart, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(onCameraDiscoveryCompleted(_:)), name: .cameraDiscoveryCompleted, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(onCameraSetupCompleted(_:)), name: .cameraSetupCompleted, object: nil)
    
    cameraCapture = CameraCapture(cameraPosition: .back, processingCallback: { (image) in
      guard let image = image else { return }
      
//      let filter = CIFilter.colorMonochrome()
//      filter.intensity = 1
//      filter.color = CIColor(red: 0.5, green: 0.5, blue: 0.5)
//      filter.inputImage = image
      self.metalView.image = image

//      guard let output = filter.outputImage else { return }
      NDIControls.instance.send(image: image)
    })
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    cameraCapture?.startCapture()
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    cameraCapture?.stopCapture()
  }
  
  @objc private func onNdiWebSeverDidStart(_ notification: Notification) {
    guard let serverUrl = notification.object as? String else { return }
    remoteControlsLabel.text = "Controls: \(serverUrl)"
  }
  
  @objc private func onCameraDiscoveryCompleted(_ notification: Notification) {
    // Start web server
    NDIControls.instance.startWebServer()
  }
  
  @objc private func onCameraSetupCompleted(_ notification: Notification) {
    print("Camera setup completed")
  }

  @IBAction func onSendButtonTapped(_ sender: UIButton) {
    let isSending = NDIControls.instance.isSending
    
    if !isSending {
      startNDI()
    } else {
      stopNDI()
    }
  }
}

extension CameraViewController: NDIControlsDelegate {
  func switchCamera(uniqueID: String) -> Bool {
    guard let cc = cameraCapture else { return false }
    return cc.switchCamera(uniqueID: uniqueID)
  }
  
  func zoom(factor: Float) -> Bool {
    guard let cc = cameraCapture else { return false }
    return cc.zoom(factor: factor)
  }
  
  func setExposure(exposeTime: CMTime, iso: Float) -> Bool {
    guard let cc = cameraCapture else { return false }
    return cc.setExposure(exposeTime: exposeTime, iso: iso)
  }
  
  func setExposureCompensation(bias: Float) -> Bool {
    guard let cc = cameraCapture else { return false }
    return cc.setExposureCompensation(bias: bias)
  }
  
  func autoExpose() -> Bool {
    guard let cc = cameraCapture else { return false }
    return cc.autoExpose()
  }
  
  func hideControls() -> Bool {
    DispatchQueue.main.async {
      self.remoteControlsLabel.isHidden = true
      self.sendStreamButton.isHidden = true
    }
    
    return true
  }
  
  func showControls() -> Bool {
    DispatchQueue.main.async {
      self.remoteControlsLabel.isHidden = false
      self.sendStreamButton.isHidden = false
    }
    return true
  }
  
  func startNDI() -> Bool {
    if !NDIControls.instance.isSending {
      DispatchQueue.main.async {
        self.sendStreamButton.setTitle("Sending...", for: .normal)
        self.sendStreamButton.backgroundColor = .blue
      }
      NDIControls.instance.start()
      return true
    }
    return false
  }
  
  func stopNDI() -> Bool {
    if NDIControls.instance.isSending {
      DispatchQueue.main.async {
        self.sendStreamButton.setTitle("Send", for: .normal)
        self.sendStreamButton.backgroundColor = .gray
      }
      NDIControls.instance.stop()
      return true
    }
    return false
  }

}
