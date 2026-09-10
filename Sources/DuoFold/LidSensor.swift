import Foundation
import IOKit.hid
import FoldCore

/// Only the orientation collection is opened. No keyboard monitoring or root access.
final class LidSensor {
    var onAngle: ((Double) -> Void)?
    var onStatus: ((String, Bool) -> Void)?
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private var fallback: Timer?
    private var watchdog: Timer?
    private var receivedInput = false
    private var failedReads = 0

    func start() {
        stop()
        let m = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        manager = m
        IOHIDManagerSetDeviceMatching(m, [kIOHIDVendorIDKey: 0x05ac, kIOHIDDeviceUsagePageKey: 0x20, kIOHIDDeviceUsageKey: 0x8a] as CFDictionary)
        guard IOHIDManagerOpen(m, 0) == kIOReturnSuccess,
              let devices = IOHIDManagerCopyDevices(m) as? Set<IOHIDDevice>,
              let d = devices.first, IOHIDDeviceOpen(d, 0) == kIOReturnSuccess else {
            onStatus?("No accessible lid sensor. Manual preview is available.", false); return
        }
        device = d
        receivedInput = false
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputValueCallback(d, { context, result, _, value in
            guard result == kIOReturnSuccess, let context else { return }
            let owner = Unmanaged<LidSensor>.fromOpaque(context).takeUnretainedValue()
            let element = IOHIDValueGetElement(value)
            guard IOHIDElementGetUsagePage(element) == 0x20, IOHIDElementGetUsage(element) == 0x047f else { return }
            let angle = Double(IOHIDValueGetIntegerValue(value))
            guard (0...180).contains(angle) else { return }
            owner.receivedInput = true
            owner.fallback?.invalidate(); owner.fallback = nil
            owner.watchdog?.invalidate(); owner.watchdog = nil
            owner.failedReads = 0
            owner.onStatus?("Lid sensor · event driven", true)
            owner.onAngle?(angle)
        }, context)
        IOHIDDeviceRegisterRemovalCallback(d, { context, _, _ in
            guard let context else { return }
            let owner = Unmanaged<LidSensor>.fromOpaque(context).takeUnretainedValue()
            owner.stop()
            owner.onStatus?("Lid sensor disconnected", false)
        }, context)
        IOHIDDeviceScheduleWithRunLoop(d, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        readFeature()
        onStatus?("Lid sensor connected", true)
        // Older sensors expose feature reports only. Never describe that fallback as no polling.
        let timer = Timer(timeInterval: 1.0, repeats: false) { [weak self] _ in
            guard let self, self.device != nil, !self.receivedInput else { return }
            self.onStatus?("Lid sensor · 60 Hz compatibility mode", true)
            let t = Timer(timeInterval: 1/60, repeats: true) { [weak self] _ in self?.readFeature() }
            self.fallback = t
            RunLoop.main.add(t, forMode: .common)
        }
        watchdog = timer; RunLoop.main.add(timer, forMode: .common)
    }
    private func readFeature() {
        guard let device else { return }
        var report = [UInt8](repeating: 0, count: 8), length = 8
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &report, &length)
        guard result == kIOReturnSuccess, let angle = LidReport.angle(bytes: Array(report.prefix(length))) else {
            failedReads += 1
            if failedReads == 30 { onStatus?("Lid sensor stopped responding", false) }
            return
        }
        failedReads = 0; onAngle?(angle)
    }
    func stop() {
        watchdog?.invalidate(); watchdog = nil
        fallback?.invalidate(); fallback = nil
        if let d = device {
            IOHIDDeviceUnscheduleFromRunLoop(d, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDDeviceRegisterInputValueCallback(d, nil, nil)
            IOHIDDeviceRegisterRemovalCallback(d, nil, nil)
            IOHIDDeviceClose(d, 0)
        }
        device = nil
        if let m = manager { IOHIDManagerClose(m, 0) }; manager = nil
    }
    deinit { stop() }
}
