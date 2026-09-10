import AppKit
import MetalKit
import FoldCore

/// Runs the shipping shader on a real GPU; no screen permission or personal pixels.
@MainActor enum RenderChecks {
    static func run() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw RenderError.unavailable }
        let renderer = try FoldRenderer(device: device)
        let width = 640, height = 400
        guard let fixture = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw RenderError.texture }
        for x in stride(from: 0, to: width, by: 4) {
            fixture.setFillColor(CGColor(gray: x % 8 == 0 ? 1 : 0, alpha: 1))
            fixture.fill(CGRect(x: x, y: 0, width: 4, height: height))
        }
        guard let source = fixture.makeImage() else { throw RenderError.texture }
        try renderer.setImage(source)
        var config = FoldConfiguration()
        config.perspective = 0; config.shadow = 0; config.blur = 1
        func pixels(_ image: CGImage) throws -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            let ok = bytes.withUnsafeMutableBytes { buffer -> Bool in
                guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height)); return true
            }
            guard ok else { throw RenderError.texture }; return bytes
        }
        func check(_ condition: Bool, _ message: String) throws {
            if !condition { throw NSError(domain: "RenderChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
            print("PASS: \(message)")
        }
        renderer.update(config: config, progress: 0)
        let open = try pixels(renderer.renderImage(width: width, height: height))
        let original = try pixels(source)
        let error = zip(open, original).enumerated().reduce(0.0) { sum, item in
            sum + (item.offset % 4 == 3 ? 0 : abs(Double(item.element.0) - Double(item.element.1)))
        } / Double(width * height * 3)
        try check(error < 2, "Open endpoint preserves the source (mean error \(error))")
        renderer.update(config: config, progress: 1)
        let closed = try pixels(renderer.renderImage(width: width, height: height))
        try check(closed.enumerated().allSatisfy { $0.offset % 4 == 3 || $0.element == 0 }, "Closed endpoint is black")
        renderer.update(config: config, progress: 0.5)
        let folded = try pixels(renderer.renderImage(width: width, height: height))
        func contrast(_ row: Int) -> Double {
            let values = (32..<(width-32)).map { Double(folded[(row * width + $0) * 4]) }
            let mean = values.reduce(0,+) / Double(values.count)
            return values.reduce(0) { $0 + pow($1-mean, 2) } / Double(values.count)
        }
        let a = contrast(20), b = contrast(height-21)
        try check(max(a,b) > 4 * max(1,min(a,b)), "Defocus varies across the surface (variances \(a), \(b))")
    }
}
