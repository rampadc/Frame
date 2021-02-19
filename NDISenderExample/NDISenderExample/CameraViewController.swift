import UIKit
import AVFoundation
import GCDWebServer

class CameraViewController: UIViewController, GCDWebServerDelegate {
  // MARK: Properties
  @IBOutlet weak var remoteControlsLabel: UILabel!
  @IBOutlet weak var sendStreamButton: UIButton!
  @IBOutlet weak var metalView: MetalView!
  
//  private var previewLayer: AVCaptureVideoPreviewLayer!
  private var cameraCapture: CameraCapture?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    cameraCapture = CameraCapture(cameraPosition: .back, processingCallback: { (image) in
      guard let image = image else { return }
      self.metalView.image = image
    })
    
    // Disable UI, only enable if NDI is initialised and session starts running
    NDIControls.startWebServer()
    NDIControls.webServer.delegate = self
    
//    guard let session = cameraCapture?.session else { fatalError("Cannot create a preview") }
//    previewLayer = AVCaptureVideoPreviewLayer(session: session)
//    previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
//    previewLayer.connection?.videoOrientation = .landscapeRight
//    previewLayer.frame = view.frame
//    view.layer.insertSublayer(previewLayer, at: 0)
    
    sendStreamButton.backgroundColor = .gray
    sendStreamButton.layer.masksToBounds = true
    sendStreamButton.setTitle("Send", for: .normal)
    sendStreamButton.layer.cornerRadius = 18
    sendStreamButton.layer.position = CGPoint(x: view.bounds.width / 2, y: view.bounds.height - 60)
    sendStreamButton.addTarget(self, action: #selector(sendStreamButton_action(sender:)), for: .touchUpInside)
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    cameraCapture?.startCapture()
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    cameraCapture?.stopCapture()
  }
  
  @objc private func sendStreamButton_action(sender: UIButton!) {
    let isSending = self.cameraCapture?.isSending ?? false
    
    if !isSending {
      cameraCapture?.startNDIStream()
      sendStreamButton.setTitle("Sending...", for: .normal)
      sendStreamButton.backgroundColor = .blue
    } else {
      sendStreamButton.setTitle("Send", for: .normal)
      sendStreamButton.backgroundColor = .gray
      cameraCapture?.stopNDIStream()
    }
  }
  
  func webServerDidStart(_ server: GCDWebServer) {
    remoteControlsLabel.text = "Control: \(server.serverURL?.absoluteString ?? "Unknown")"
  }
}
