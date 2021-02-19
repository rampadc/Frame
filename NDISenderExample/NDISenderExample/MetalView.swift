import MetalKit
import CoreImage

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
    
    try! ciContext?.startTask(toRender: image, to: destination)
    commandBuffer?.present(currentDrawable!)
    commandBuffer?.commit()
    draw()
  }
}
