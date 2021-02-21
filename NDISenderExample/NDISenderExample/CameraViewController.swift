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
    
    NotificationCenter.default.addObserver(self, selector: #selector(onNdiWebSeverDidStart(_:)), name: .ndiWebServerDidStart, object: nil)
    
    cameraCapture = CameraCapture(cameraPosition: .back, processingCallback: { (image) in
      guard let image = image else { return }
      
      let filter = CIFilter.thermal()
      filter.inputImage = image
      self.metalView.image = filter.outputImage
      
      guard let output = filter.outputImage else { return }
      NDIControls.instance.send(image: output)
    })
    
    // Disable UI, only enable if NDI is initialised and session starts running
    NDIControls.instance.startWebServer()
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
    print("Prior good")
    guard let serverUrl = notification.object as? String else { return }
    print("All good")
    print(serverUrl)
    remoteControlsLabel.text = "Controls: \(serverUrl)"
  }

  @IBAction func onSendButtonTapped(_ sender: UIButton) {
    let isSending = NDIControls.instance.isSending
    
    if !isSending {
      NDIControls.instance.start()
      sendStreamButton.setTitle("Sending...", for: .normal)
      sendStreamButton.backgroundColor = .blue
    } else {
      sendStreamButton.setTitle("Send", for: .normal)
      sendStreamButton.backgroundColor = .gray
      NDIControls.instance.stop()
    }
  }
}
