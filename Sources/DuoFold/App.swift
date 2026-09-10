import AppKit
import SwiftUI
import MetalKit
import ImageIO
import UniformTypeIdentifiers
import FoldCore

@main enum DuoFoldMain {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--export-demo") {
            do {try DemoExport.run();exit(0)} catch {fputs("DuoFold: \(error)\n",stderr);exit(1)}
        }
        if CommandLine.arguments.contains("--self-test-render") {
            do {try RenderChecks.run();exit(0)} catch {fputs("Render check: \(error)\n",stderr);exit(1)}
        }
        if CommandLine.arguments.contains("--probe-sensor") {
            let sensor=LidSensor()
            sensor.onStatus={status,_ in print(status)}
            sensor.onAngle={angle in print("Angle: \(angle)°")}
            sensor.start();RunLoop.main.run(until:Date(timeIntervalSinceNow:3));sensor.stop();return
        }
        let app=NSApplication.shared
        let delegate=AppDelegate()
        app.delegate=delegate
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var item: NSStatusItem!
    private var window: NSWindow?
    func applicationDidFinishLaunching(_ notification:Notification) {
        model=AppModel()
        item=NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        item.button?.image=NSImage(systemSymbolName:"macbook",accessibilityDescription:"DuoFold")
        let menu=NSMenu()
        menu.addItem(withTitle:"DuoFold Settings…",action:#selector(showSettings),keyEquivalent:",").target=self
        menu.addItem(withTitle:"Enable / Pause",action:#selector(toggle),keyEquivalent:"p").target=self
        menu.addItem(.separator())
        menu.addItem(withTitle:"Quit DuoFold",action:#selector(quit),keyEquivalent:"q").target=self
        item.menu=menu
        showSettings()
    }
    @objc func showSettings() {
        if window==nil {
            let controller=NSHostingController(rootView:SettingsView(model:model))
            let w=NSWindow(contentViewController:controller)
            w.title="DuoFold";w.styleMask=[.titled,.closable,.miniaturizable,.fullSizeContentView]
            w.titlebarAppearsTransparent=true;w.isReleasedWhenClosed=false
            w.setContentSize(NSSize(width:820,height:710));w.center();window=w
        }
        window?.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
    }
    @objc func toggle() {model.enabled ? model.disable() : model.enable()}
    @objc func quit() {NSApp.terminate(nil)}
    func applicationWillTerminate(_ notification:Notification) {model.shutdown()}
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool)->Bool {showSettings();return true}
}

@MainActor enum DemoExport {
    static func run() throws {
        guard let device=MTLCreateSystemDefaultDevice() else {throw RenderError.unavailable}
        let renderer=try FoldRenderer(device:device)
        try renderer.setImage(DemoDesktop.make(width:960,height:600))
        let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("docs/media")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let config=FoldConfiguration()
        for (name,p) in [("open",0.0),("half-fold",0.5),("closed",1.0)] {
            renderer.update(config:config,progress:p)
            let cg=try renderer.renderImage(width:960,height:600)
            let data=NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:])!
            try data.write(to:root.appendingPathComponent("\(name).png"))
        }
        let url=root.appendingPathComponent("fold-demo.gif")
        guard let gif=CGImageDestinationCreateWithURL(url as CFURL,UTType.gif.identifier as CFString,90,nil) else {throw RenderError.texture}
        CGImageDestinationSetProperties(gif,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
        for i in 0..<90 {
            let t=Double(i)/89
            let p=0.83*(0.5-0.5*cos(2*Double.pi*t))
            renderer.update(config:config,progress:p)
            let frame=try renderer.renderImage(width:640,height:400)
            CGImageDestinationAddImage(gif,frame,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/30]] as CFDictionary)
        }
        guard CGImageDestinationFinalize(gif) else {throw RenderError.texture}
        print("Exported production Metal renderer demo to docs/media")
    }
}
