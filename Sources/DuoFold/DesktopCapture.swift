import AppKit
import ScreenCaptureKit
import CoreMedia

final class DesktopCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    var onFrame: ((CVPixelBuffer) -> Void)?
    var onFailure: ((String) -> Void)?
    var onSuspended: (() -> Void)?
    private(set) var running = false
    static var builtInScreen: NSScreen? {
        NSScreen.screens.first { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return false }
            return CGDisplayIsBuiltin(id) != 0
        }
    }
    @MainActor func start() async throws {
        guard stream == nil else { return }
        guard let screen = Self.builtInScreen,
              let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            throw NSError(domain: "DuoFold", code: 1, userInfo: [NSLocalizedDescriptionKey: "Connect and open the MacBook’s built-in display. External displays are left alone."])
        }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw NSError(domain: "DuoFold", code: 2, userInfo: [NSLocalizedDescriptionKey: "The built-in display is not available for capture."])
        }
        let ownApp = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        guard !ownApp.isEmpty else {
            throw NSError(domain: "DuoFold", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not exclude DuoFold from capture. Reopen the app and try again."])
        }
        // Exclude the entire process, including windows created after the stream starts.
        let filter = SCContentFilter(display: display, excludingApplications: ownApp, exceptingWindows: [])
        let config = SCStreamConfiguration()
        let nativeWidth = Double(CGDisplayPixelsWide(displayID))
        let nativeHeight = Double(CGDisplayPixelsHigh(displayID))
        let scale = min(1, 2560/nativeWidth)
        config.width = Int(nativeWidth*scale); config.height = Int(nativeHeight*scale)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.queueDepth = 3; config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false; config.capturesAudio = false
        config.colorSpaceName = CGColorSpace.sRGB
        let candidate = SCStream(filter: filter, configuration: config, delegate: self)
        try candidate.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
        stream = candidate
        do { try await candidate.startCapture(); running = true }
        catch { stream = nil; throw error }
    }
    @MainActor func stop() async {
        running = false
        let old = stream; stream = nil
        try? await old?.stopCapture()
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard stream === self.stream, type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let status = attachments.first?[.status] as? Int else { return }
        if status == SCFrameStatus.blank.rawValue || status == SCFrameStatus.suspended.rawValue || status == SCFrameStatus.stopped.rawValue {
            onSuspended?(); return
        }
        guard status == SCFrameStatus.complete.rawValue, let buffer = sampleBuffer.imageBuffer else { return }
        onFrame?(buffer)
    }
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard stream === self?.stream else { return }
            self?.running = false
            self?.onFailure?("Screen capture stopped: \(error.localizedDescription)")
        }
    }
}
