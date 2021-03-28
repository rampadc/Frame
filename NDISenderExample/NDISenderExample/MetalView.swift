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
  
  required init(coder: NSCoder) {
    super.init(coder: coder)
    
    device = MTLCreateSystemDefaultDevice()
    framebufferOnly = false
    colorPixelFormat = .bgra8Unorm
    
    commandQueue = device!.makeCommandQueue()
    Config.shared.ciContext = CIContext(mtlDevice: self.device!)
  }
  
  private func renderImage() {
    guard let image = image else { return }
    
    let commandBuffer = commandQueue?.makeCommandBuffer()
    let destination = CIRenderDestination(width: Int(drawableSize.width), height: Int(drawableSize.height), pixelFormat: .bgra8Unorm, commandBuffer: commandBuffer) { () -> MTLTexture in
      return self.currentDrawable!.texture
    }
    
    let imageWidth = CGFloat(image.extent.width)
    let imageHeight = CGFloat(image.extent.height)
    
    var scale: CGFloat = 0
    if imageWidth > imageHeight {
      if imageWidth < drawableSize.width {
        scale = drawableSize.width / imageWidth
      } else {
        scale = imageWidth / drawableSize.width
      }
    } else {
      if imageHeight < drawableSize.height {
        scale = drawableSize.height / imageHeight
      } else {
        scale = imageHeight / drawableSize.height
      }
    }
    
    try! Config.shared.ciContext?.startTask(
      toRender: image.transformed(by: CGAffineTransform(scaleX: scale, y: scale)), to: destination)
    commandBuffer?.present(currentDrawable!)
    commandBuffer?.commit()
    draw()
  }
}
