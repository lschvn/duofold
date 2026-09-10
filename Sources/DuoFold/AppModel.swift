import AppKit
import SwiftUI
import MetalKit
import Carbon
import FoldCore

@MainActor final class AppModel: ObservableObject {
    @Published var config = FoldConfiguration() { didSet { save(); refreshPreview() } }
    @Published var lidAngle = 110.0
    @Published var sensorAvailable = false
    @Published var sensorStatus = "Looking for the lid sensor…"
    @Published var enabled = false
    @Published var busy = false
    @Published var message = "Preview the effect, then enable it for your desktop."
    @Published var manualAngle = 65.0 { didSet { refreshPreview() } }
    @Published var followLid = false { didSet { refreshPreview() } }
    @Published var playing = false
    @Published var sound = UserDefaults.standard.bool(forKey: "sound") { didSet { UserDefaults.standard.set(sound,forKey:"sound") } }
    @Published var respectReduceMotion = true
    let sensor = LidSensor()
    var previewRenderer: FoldRenderer?
    weak var previewView: MTKView?
    private var capture: DesktopCapture?
    private var overlay: NSPanel?
    private var overlayView: MTKView?
    private var renderer: FoldRenderer?
    private var displayClock: FoldDisplayClock?
    private var spring = FoldSpring()
    private var previewSpring = FoldSpring()
    private var lastTick = CACurrentMediaTime()
    private var lastPreviewTick = CACurrentMediaTime()
    private var generation = 0
    private var lastFrame = Date.distantPast
    private var observers: [NSObjectProtocol] = []
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var overlayWasVisible = false
    private var demoStart: TimeInterval?
    private var previewStart: TimeInterval?
    private var resumeAfterSystemPause = false
    private var resumeTask: Task<Void, Never>?

    init() {
        if let data=UserDefaults.standard.data(forKey:"foldConfiguration"),let saved=try? JSONDecoder().decode(FoldConfiguration.self,from:data) { config=saved }
        sensor.onAngle = { [weak self] angle in
            guard let self else {return}; if self.lidAngle != angle { self.lidAngle=angle; self.refreshPreview() }
        }
        sensor.onStatus = { [weak self] status, available in
            guard let self else {return}; if self.sensorStatus != status { self.sensorStatus=status }; if self.sensorAvailable != available { self.sensorAvailable=available }
            if !available && self.enabled { self.disable(reason:status) }
        }
        sensor.start()
        let center=NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName:NSWorkspace.willSleepNotification,object:nil,queue:.main) { [weak self] _ in
            Task { @MainActor in self?.suspendForSystem(); self?.sensor.stop() }
        })
        observers.append(center.addObserver(forName:NSWorkspace.screensDidSleepNotification,object:nil,queue:.main) { [weak self] _ in
            Task { @MainActor in self?.suspendForSystem() }
        })
        observers.append(center.addObserver(forName:NSWorkspace.didWakeNotification,object:nil,queue:.main) { [weak self] _ in
            Task { @MainActor in self?.resumeFromSystem() }
        })
        observers.append(NotificationCenter.default.addObserver(forName:NSApplication.didChangeScreenParametersNotification,object:nil,queue:.main) { [weak self] _ in
            Task { @MainActor in self?.suspendForSystem(); self?.resumeFromSystem() }
        })
        observers.append(center.addObserver(forName:NSWorkspace.screensDidWakeNotification,object:nil,queue:.main) { [weak self] _ in
            Task { @MainActor in self?.resumeFromSystem() }
        })
        // Carbon hotkeys require neither Accessibility nor keyboard event monitoring.
        var type=EventTypeSpec(eventClass:OSType(kEventClassKeyboard),eventKind:UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let model=Unmanaged<AppModel>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in model.disable(reason:"Paused with Escape.") }
            return noErr
        },1,&type,Unmanaged.passUnretained(self).toOpaque(),&eventHandler)
    }
    private func suspendForSystem() {
        let resume = resumeAfterSystemPause || (enabled && demoStart == nil)
        disable(reason:"Paused while the display sleeps. Will reconnect when it wakes.")
        resumeAfterSystemPause = resume
    }
    private func resumeFromSystem() {
        resumeTask?.cancel()
        resumeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled, let self else { return }
            self.sensor.start()
            if self.resumeAfterSystemPause {
                self.resumeAfterSystemPause = false
                self.enable()
            }
        }
    }
    private func save() {
        if let data=try? JSONEncoder().encode(config) { UserDefaults.standard.set(data,forKey:"foldConfiguration") }
    }
    func attachPreview(_ view: MTKView) {
        do {
            guard let device=MTLCreateSystemDefaultDevice() else {throw RenderError.unavailable}
            let r=try FoldRenderer(device:device); r.configure(view:view)
            try r.setImage(DemoDesktop.make())
            previewRenderer=r;previewView=view
            r.beforeDraw = { [weak self] in self?.tickPreview() }
            view.isPaused=false
        } catch { message=error.localizedDescription }
    }
    private func tickPreview() {
        var angle = followLid && sensorAvailable ? lidAngle : manualAngle
        if let start=previewStart {
            let t=(CACurrentMediaTime()-start)/4.5
            if t>=1 {previewStart=nil;playing=false;angle=manualAngle}
            else { angle=105-90*(0.5-0.5*cos(t*2*Double.pi)) }
        }
        let target=config.progress(angle:angle)
        let now = CACurrentMediaTime(), dt = now - lastPreviewTick
        lastPreviewTick = now
        let p=previewSpring.step(target:target,dt:dt,response:config.response)
        previewRenderer?.update(config:config,progress:p)
    }
    func refreshPreview() { previewView?.isPaused=false }
    func playPreview() { followLid=false;playing=true;previewStart=CACurrentMediaTime();refreshPreview() }
    func resetSettings() { config=FoldConfiguration() }
    func calibrate() { if sensorAvailable { config.clearAngle=max(30,min(140,lidAngle-3)) } }
    func requestPermission() {
        if CGPreflightScreenCaptureAccess() { message="Permission is ready. Enable the desktop effect." }
        else {
            _ = CGRequestScreenCaptureAccess()
            message="Allow DuoFold in Screen Recording, then quit and reopen the app if macOS asks."
        }
    }
    func openPermissionSettings() {
        NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }
    func enable(demo: Bool = false) {
        guard !busy else {return}
        if enabled {disable();return}
        guard CGPreflightScreenCaptureAccess() else { requestPermission();return }
        guard sensorAvailable || demo else {message="No lid sensor is available. Use the sample preview instead.";return}
        if respectReduceMotion && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            message="Reduce Motion is enabled in macOS. Turn off ‘Respect Reduce Motion’ here to preview the effect.";return
        }
        generation+=1; let token=generation; busy=true
        Task {
            let c=DesktopCapture()
            do {
                guard let device=MTLCreateSystemDefaultDevice() else {throw RenderError.unavailable}
                let r=try FoldRenderer(device:device)
                c.onFrame = { [weak self, weak r] buffer in
                    guard let self,self.generation==token else {return}
                    self.lastFrame=Date();r?.setFrame(buffer)
                }
                c.onSuspended = { [weak self] in
                    guard let self,self.generation==token else { return }; self.suspendForSystem()
                }
                c.onFailure = { [weak self] error in
                    guard let self,self.generation==token else {return};self.disable(reason:error)
                }
                try await c.start()
                guard generation==token else {await c.stop();return}
                guard let screen=DesktopCapture.builtInScreen else {throw RenderError.unavailable}
                let panel=NSPanel(contentRect:screen.frame,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
                panel.level=NSWindow.Level(rawValue:Int(CGWindowLevelForKey(.screenSaverWindow))-1)
                panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.ignoresCycle,.stationary]
                panel.isOpaque=true;panel.backgroundColor = .black;panel.hasShadow=false
                panel.ignoresMouseEvents=true;panel.hidesOnDeactivate=false;panel.isReleasedWhenClosed=false
                let view=MTKView(frame:NSRect(origin:.zero,size:screen.frame.size));r.configure(view:view)
                view.autoresizingMask=[.width,.height];panel.contentView=view
                r.onFailure = { [weak self] error in
                    guard let self,self.generation==token else { return }; self.disable(reason:error)
                }
                r.onPresented = { [weak self, weak panel] in
                    guard let self,self.generation==token,self.overlayWasVisible else { return }
                    panel?.alphaValue = 1
                }
                capture=c;renderer=r;overlay=panel;overlayView=view
                enabled=true;busy=false;spring.reset();lastTick=CACurrentMediaTime()
                demoStart=demo ? CACurrentMediaTime() : nil
                lastFrame=Date()
                message=demo ? "Desktop demo · restores automatically after five seconds. Escape stops it." : "Following the lid. Escape pauses the effect."
                displayClock = FoldDisplayClock(screen: screen) { [weak self] in self?.tick() }

            } catch {
                await c.stop()
                guard generation==token else {return}
                busy=false;message=error.localizedDescription;hideOverlay()
            }
        }
    }
    private func tick() {
        guard enabled,let renderer,let view=overlayView else {return}
        let now=CACurrentMediaTime(),dt=now-lastTick;lastTick=now
        if respectReduceMotion && NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { disable(reason:"Paused because Reduce Motion is enabled.");return }
        var angle=lidAngle
        if let start=demoStart {
            let t=(now-start)/5
            if t>=1 {disable(reason:"Desktop demo finished.");return}
            angle=105-85*(0.5-0.5*cos(t*2*Double.pi))
        }
        let p=spring.step(target:config.progress(angle:angle),dt:dt,response:config.response)
        renderer.update(config:config,progress:p)
        guard renderer.hasFrame else {
            if Date().timeIntervalSince(lastFrame)>3 { disable(reason:"No desktop frames arrived. Check Screen Recording permission.") }
            return
        }
        if p>0.0005 {
            if !overlayWasVisible {
                guard eventHandler != nil,
                      RegisterEventHotKey(UInt32(kVK_Escape),0,EventHotKeyID(signature:0x44554F46,id:1),GetApplicationEventTarget(),0,&hotKey) == noErr else {
                    disable(reason:"Escape is reserved by another app. The desktop effect was paused."); return
                }
                // Reveal only after a captured frame has completed on the GPU.
                overlay?.alphaValue=0;overlay?.orderFrontRegardless();overlayWasVisible=true
            }
            view.draw()
        } else if overlayWasVisible {
            hideOverlay()
            if sound {NSSound(named:"Pop")?.play()}
        }
    }
    private func hideOverlay() {
        overlay?.orderOut(nil);overlayView?.isPaused=true;overlayWasVisible=false
        if let hotKey {UnregisterEventHotKey(hotKey)};hotKey=nil
    }
    func disable(reason: String = "Paused. Your desktop is back to normal.") {
        resumeTask?.cancel();resumeTask=nil;resumeAfterSystemPause=false
        generation+=1;enabled=false;busy=false;demoStart=nil
        displayClock?.stop();displayClock=nil;hideOverlay()
        overlay?.close();overlay=nil;overlayView=nil
        renderer?.clear();renderer=nil;spring.reset()
        let c=capture;capture=nil;Task {await c?.stop()}
        message=reason
    }
    func shutdown() {disable();sensor.stop();if let eventHandler {RemoveEventHandler(eventHandler)}}
}
