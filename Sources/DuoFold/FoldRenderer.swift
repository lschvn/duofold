import AppKit
import MetalKit
import MetalPerformanceShaders
import CoreVideo
import FoldCore

struct ShaderParameters {
    var progress: Float = 0, perspective: Float = 0.65, blur: Float = 0.65, shadow: Float = 0.45
    var style: Float = 0, width: Float = 0, height: Float = 0, pad: Float = 0
}

enum RenderError: LocalizedError {
    case unavailable, shaderMissing, texture
    var errorDescription: String? { switch self {
        case .unavailable: return "Metal rendering is unavailable on this Mac."
        case .shaderMissing: return "The bundled fold shader is missing. Rebuild or reinstall DuoFold."
        case .texture: return "Could not allocate a desktop texture."
    } }
}

final class FoldRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private var cache: CVMetalTextureCache?
    private var source: MTLTexture?
    private var retainedFrame: CVMetalTexture?
    private var retainedPixelBuffer: CVPixelBuffer?
    private var blurTextures: [MTLTexture] = []
    private var kernels: [MPSImageGaussianBlur] = []
    private var needsBlur = true
    private let inFlight = DispatchSemaphore(value: 3)
    var parameters = ShaderParameters()
    var beforeDraw: (() -> Void)?
    var onFailure: ((String) -> Void)?
    var onPresented: (() -> Void)?
    var hasFrame: Bool { source != nil }

    init(device: MTLDevice) throws {
        self.device = device
        guard let queue = device.makeCommandQueue() else { throw RenderError.unavailable }
        commandQueue = queue
        guard let url = (Bundle.main.url(forResource: "Fold", withExtension: "metal") ?? Bundle.module.url(forResource: "Fold", withExtension: "metal")) else { throw RenderError.shaderMissing }
        let library = try device.makeLibrary(source: String(contentsOf: url), options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "foldVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "foldFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        super.init()
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache)
    }
    func configure(view: MTKView) {
        view.device = device; view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColorMake(0, 0, 0, 1)
        view.framebufferOnly = true; view.preferredFramesPerSecond = 60
        view.isPaused = true; view.enableSetNeedsDisplay = false
        view.delegate = self
    }
    func update(config: FoldConfiguration, progress: Double) {
        parameters.progress = Float(progress); parameters.perspective = Float(config.perspective)
        parameters.blur = Float(config.blur); parameters.shadow = Float(config.shadow); parameters.style = config.style.index
    }
    func setFrame(_ buffer: CVPixelBuffer) {
        guard let cache else { return }
        var wrapped: CVMetalTexture?
        guard CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, cache, buffer, nil, .bgra8Unorm,
                CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer), 0, &wrapped) == kCVReturnSuccess,
              let wrapped, let texture = CVMetalTextureGetTexture(wrapped) else { return }
        retainedFrame = wrapped; retainedPixelBuffer = buffer; setTexture(texture)
    }
    func setImage(_ image: CGImage) throws {
        let width = image.width, height = image.height
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width*4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let bytes = context.data else { throw RenderError.texture }
        context.draw(image, in: CGRect(x:0,y:0,width:width,height:height))
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead]; descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else { throw RenderError.texture }
        texture.replace(region: MTLRegionMake2D(0,0,width,height), mipmapLevel: 0, withBytes: bytes, bytesPerRow: width*4)
        retainedFrame = nil; retainedPixelBuffer = nil; setTexture(texture)
    }
    private func setTexture(_ texture: MTLTexture) {
        source = texture; needsBlur = true
        if blurTextures.first?.width != texture.width || blurTextures.first?.height != texture.height {
            blurTextures = []; kernels = []
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: texture.width, height: texture.height, mipmapped: false)
            descriptor.usage = [.shaderRead, .shaderWrite]; descriptor.storageMode = .private
            for sigma in [2.5, 9.0, 28.0] {
                guard let t = device.makeTexture(descriptor: descriptor) else { return }
                blurTextures.append(t)
                let kernel = MPSImageGaussianBlur(device: device, sigma: Float(sigma * Double(texture.width)/1600))
                kernel.edgeMode = .clamp; kernels.append(kernel)
            }
        }
    }
    func clear() {
        source = nil; retainedFrame = nil; retainedPixelBuffer = nil; blurTextures = []; kernels = []
        if let cache { CVMetalTextureCacheFlush(cache, 0) }
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    func draw(in view: MTKView) {
        beforeDraw?()
        guard hasFrame, let drawable = view.currentDrawable, let pass = view.currentRenderPassDescriptor else { return }
        guard inFlight.wait(timeout: .now()) == .success else { return }
        guard let command = commandQueue.makeCommandBuffer() else { inFlight.signal(); return }
        encode(command: command, pass: pass)
        command.present(drawable)
        let retained = (retainedFrame, retainedPixelBuffer)
        command.addCompletedHandler { [weak self, inFlight] command in
            withExtendedLifetime(retained) {}
            inFlight.signal()
            if command.status == .completed { DispatchQueue.main.async { self?.onPresented?() } }
            if command.status == .error { DispatchQueue.main.async { self?.onFailure?("The GPU could not render the fold. The desktop has been restored.") } }
        }
        command.commit()
    }
    private func encode(command: MTLCommandBuffer, pass: MTLRenderPassDescriptor) {
        guard let source, blurTextures.count == 3 else { return }
        if needsBlur {
            for i in 0..<3 { kernels[i].encode(commandBuffer: command, sourceTexture: source, destinationTexture: blurTextures[i]) }
            needsBlur = false
        }
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
        var p = parameters; p.width = Float(source.width); p.height = Float(source.height)
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBytes(&p, length: MemoryLayout<ShaderParameters>.stride, index: 0)
        encoder.setFragmentBytes(&p, length: MemoryLayout<ShaderParameters>.stride, index: 0)
        encoder.setFragmentTexture(source, index: 0)
        for i in 0..<3 { encoder.setFragmentTexture(blurTextures[i], index: i+1) }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 32*64*6)
        encoder.endEncoding()
    }
    /// Uses the exact production shader for documentation and deterministic GPU checks.
    func renderImage(width: Int, height: Int) throws -> CGImage {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        d.usage = [.renderTarget]; d.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: d), let command = commandQueue.makeCommandBuffer() else { throw RenderError.texture }
        let pass = MTLRenderPassDescriptor(); pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0,0,0,1)
        encode(command: command, pass: pass); command.commit(); command.waitUntilCompleted()
        if let error = command.error { throw error }
        var bytes = [UInt8](repeating: 0, count: width*height*4)
        texture.getBytes(&bytes, bytesPerRow: width*4, from: MTLRegionMake2D(0,0,width,height), mipmapLevel: 0)
        let data = Data(bytes) as CFData
        guard let provider = CGDataProvider(data: data), let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width*4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue), provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { throw RenderError.texture }
        return image
    }
}
