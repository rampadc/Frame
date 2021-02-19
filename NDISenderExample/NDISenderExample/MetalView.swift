import MetalKit
import CoreImage
import UIKit

class MetalView: MTKView {
  var image: CIImage? {
    didSet {
      renderImage()
    }
  }
  
  private var commandQueue: MTLCommandQueue?
  private var ciContext: CIContext?
  
  required init(coder: NSCoder) {
    super.init(coder: coder)
    
    device = MTLCreateSystemDefaultDevice()
    framebufferOnly = false
    colorPixelFormat = .bgra8Unorm
    
    commandQueue = device!.makeCommandQueue()
    ciContext = CIContext(mtlDevice: self.device!)
  }
  
  private func renderImage() {
    guard let image = image else { return }
    
    let commandBuffer = commandQueue?.makeCommandBuffer()
    let destination = CIRenderDestination(width: Int(drawableSize.width), height: Int(drawableSize.height), pixelFormat: .bgra8Unorm, commandBuffer: commandBuffer) { () -> MTLTexture in
      return self.currentDrawable!.texture
    }
    
    let imageWidth = CGFloat(image.extent.width)
    let imageHeight = CGFloat(image.extent.height)
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height

    var scaleX = imageWidth / screenWidth
    var scaleY = imageHeight / screenHeight
    
    // TODO: Solve scaling issue
    if scaleX > scaleY {
      scaleY = scaleX / scaleY
      scaleX = 1.0
    } else {
      scaleX = scaleY / scaleX
      scaleY = 1.0
    }
    
    try! ciContext?.startTask(
      toRender: image.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY)), to: destination)
    commandBuffer?.present(currentDrawable!)
    commandBuffer?.commit()
    draw()
  }
}
