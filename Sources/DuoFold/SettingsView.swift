import SwiftUI
import MetalKit
import FoldCore

struct MetalPreview: NSViewRepresentable {
    @ObservedObject var model: AppModel
    func makeNSView(context: Context) -> MTKView {
        let view=MTKView(); model.attachPreview(view);return view
    }
    func updateNSView(_ nsView: MTKView, context: Context) {}
    static func dismantleNSView(_ nsView: MTKView, coordinator: ()) { nsView.isPaused=true;nsView.delegate=nil }
}
struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var tab=0
    private let accent=Color(red:0.61,green:0.76,blue:1)
    var body: some View {
        VStack(spacing:0) {
            HStack(spacing:13) {
                Image(systemName:"macbook").font(.system(size:29,weight:.light)).foregroundStyle(accent)
                    .frame(width:53,height:53).background(accent.opacity(0.12),in:RoundedRectangle(cornerRadius:15))
                VStack(alignment:.leading,spacing:3) {
                    Text("DuoFold").font(.system(size:25,weight:.semibold))
                    Text("A little magic in the hinge.").foregroundStyle(.secondary).font(.system(size:13))
                }
                Spacer()
                Button { model.enabled ? model.disable() : model.enable() } label: {
                    Label(model.busy ? "Connecting…" : model.enabled ? "Pause effect" : "Enable effect",systemImage:model.enabled ? "pause.fill" : "power")
                        .padding(.horizontal,7).padding(.vertical,4)
                }.buttonStyle(.borderedProminent).tint(accent).foregroundStyle(.black).disabled(model.busy)
            }.padding(24)
            Picker("Settings",selection:$tab) {Text("Appearance").tag(0);Text("General").tag(1)}
                .pickerStyle(.segmented).frame(width:270).padding(.bottom,20)
            Divider()
            if tab==0 {appearance} else {general}
            Spacer(minLength:0)
            Divider()
            HStack(alignment:.top,spacing:10) {
                Image(systemName:model.enabled ? "waveform.path" : "info.circle").foregroundStyle(accent)
                Text(model.message).font(.system(size:12)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                Spacer()
                Text("0.1.0 · Preview").font(.system(size:11)).foregroundStyle(.tertiary)
            }.padding(18)
        }.frame(width:820,height:710).background(Color(nsColor:.windowBackgroundColor))
            .preferredColorScheme(.dark)
    }
    private var appearance: some View {
        HStack(alignment:.top,spacing:25) {
            VStack(alignment:.leading,spacing:18) {
                HStack {
                    Text("PREVIEW").font(.system(size:11,weight:.semibold)).tracking(1.5).foregroundStyle(.secondary)
                    Spacer()
                    Text("Sample desktop").font(.system(size:11)).foregroundStyle(.tertiary)
                }
                MetalPreview(model:model).aspectRatio(1.6,contentMode:.fit)
                    .clipShape(RoundedRectangle(cornerRadius:10))
                    .overlay(RoundedRectangle(cornerRadius:10).stroke(.white.opacity(0.15),lineWidth:1))
                    .accessibilityLabel("Animated desktop preview. Use the lid angle slider to adjust the fold.")
                HStack {
                    Text("Lid angle").font(.system(size:13))
                    Spacer()
                    Text("\(Int(model.followLid ? model.lidAngle : model.manualAngle))°").monospacedDigit().foregroundStyle(accent)
                }
                Slider(value:$model.manualAngle,in:8...120).disabled(model.followLid || model.playing).accessibilityLabel("Preview lid angle")
                HStack {
                    Text("Closed");Spacer();Text("Open")
                }.font(.system(size:11)).foregroundStyle(.tertiary)
                HStack {
                    Toggle("Follow the lid",isOn:$model.followLid).toggleStyle(.switch).controlSize(.small).disabled(!model.sensorAvailable)
                    Spacer()
                    Button {model.playPreview()} label: {Label("Play",systemImage:"play.fill")}.disabled(model.playing)
                }.font(.system(size:12))
                Divider()
                HStack(spacing:7) {
                    Image(systemName:model.sensorAvailable ? "sensor.tag.radiowaves.forward.fill" : "sensor.tag.radiowaves.forward")
                    Text(model.sensorStatus)
                }.font(.system(size:11)).foregroundStyle(.secondary)
                Button("Try on my desktop for 5 seconds") {model.enable(demo:true)}.disabled(model.enabled || model.busy)
                    .help("Requires Screen Recording. Escape restores your desktop immediately.")
            }.frame(width:435)
            VStack(alignment:.leading,spacing:20) {
                Text("MAKE IT YOURS").font(.system(size:11,weight:.semibold)).tracking(1.5).foregroundStyle(.secondary)
                Picker("Style",selection:$model.config.style) {
                    ForEach(FoldStyle.allCases,id:\.self) {Text($0.rawValue).tag($0)}
                }.pickerStyle(.segmented)
                Text(styleDescription).font(.system(size:12)).foregroundStyle(.secondary).frame(height:35,alignment:.top)
                control("Perspective",value:$model.config.perspective)
                control("Progressive blur",value:$model.config.blur)
                control("Shadow",value:$model.config.shadow)
                VStack(alignment:.leading,spacing:7) {
                    HStack {Text("Clears at");Spacer();Text("\(Int(model.config.clearAngle))°").monospacedDigit().foregroundStyle(.secondary)}
                    Slider(value:$model.config.clearAngle,in:30...130).accessibilityLabel("Clear angle")
                    Button("Use current lid position") {model.calibrate()}.font(.system(size:11)).disabled(!model.sensorAvailable)
                }.font(.system(size:12))
                Button("Reset appearance") {model.resetSettings()}.buttonStyle(.link).font(.system(size:12))
            }.frame(maxWidth:.infinity)
        }.padding(25)
    }
    private var styleDescription: String {
        switch model.config.style {
        case .silk:return "A soft perspective fold with gradual defocus."
        case .shade:return "Deeper shadows. A clearer, quieter fold."
        case .frost:return "More diffusion, like lifting a sheet of frosted glass."
        }
    }
    private func control(_ title:String,value:Binding<Double>) -> some View {
        VStack(spacing:7) {
            HStack {Text(title);Spacer();Text("\(Int(value.wrappedValue*100))%").monospacedDigit().foregroundStyle(.secondary)}
            Slider(value:value,in:0...1).accessibilityLabel(title)
        }.font(.system(size:12))
    }
    private var general: some View {
        Form {
            Section("Screen access") {
                Text("DuoFold uses Screen Recording to render your live desktop. Frames stay in memory on your Mac. Audio is never captured.").font(.system(size:13)).foregroundStyle(.secondary)
                HStack {
                    Button("Allow Screen Recording") {model.requestPermission()}
                    Button("Open Privacy Settings") {model.openPermissionSettings()}
                }
            }
            Section("Behavior") {
                Toggle("Play a soft sound when the desktop clears",isOn:$model.sound)
                Toggle("Respect macOS Reduce Motion",isOn:$model.respectReduceMotion)
                HStack {
                    Text("Motion response")
                    Slider(value:$model.config.response,in:0.02...0.12).accessibilityLabel("Motion response")
                    Text("\(Int(model.config.response*1000)) ms").monospacedDigit().frame(width:55)
                }
                Text("Lower values follow the hinge more closely. Higher values soften sensor steps. Escape pauses an active desktop effect.").font(.system(size:12)).foregroundStyle(.secondary)
            }
            Section("About this recreation") {
                Text("An independent, open-source macOS interpretation of the iPhone Duo fold. The bottom edge is the hinge. Only the built-in screen is affected.").font(.system(size:13))
                Text("Requires macOS 14 or later, Metal, and an accessible lid-angle sensor. Sensor support varies by Mac. No account, analytics, or network connection.").font(.system(size:12)).foregroundStyle(.secondary)
                Link("Animation research and source code",destination:URL(string:"https://github.com/lschvn/duofold")!)
            }
        }.formStyle(.grouped).padding(.horizontal,16)
    }
}
