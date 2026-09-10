import AppKit
let output=URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
for size in [16,32,64,128,256,512,1024] {
    let image=NSImage(size:NSSize(width:size,height:size))
    image.lockFocus()
    let rect=NSRect(x:Double(size)*0.05,y:Double(size)*0.05,width:Double(size)*0.9,height:Double(size)*0.9)
    NSColor(red:0.12,green:0.17,blue:0.28,alpha:1).setFill()
    NSBezierPath(roundedRect:rect,xRadius:Double(size)*0.20,yRadius:Double(size)*0.20).fill()
    if let symbol=NSImage(systemSymbolName:"macbook",accessibilityDescription:nil)?.withSymbolConfiguration(.init(pointSize:Double(size)*0.53,weight:.light)) {
        let tinted=NSImage(size:symbol.size);tinted.lockFocus();symbol.draw(at:.zero,from:.zero,operation:.sourceOver,fraction:1)
        NSColor(red:0.65,green:0.8,blue:1,alpha:1).setFill();NSRect(origin:.zero,size:symbol.size).fill(using:.sourceAtop);tinted.unlockFocus()
        tinted.draw(in:NSRect(x:Double(size)*0.19,y:Double(size)*0.27,width:Double(size)*0.62,height:Double(size)*0.46))
    }
    image.unlockFocus()
    let data=NSBitmapImageRep(data:image.tiffRepresentation!)!.representation(using:.png,properties:[:])!
    if size<=512 {try data.write(to:output.appendingPathComponent("icon_\(size)x\(size).png"))}
    if size>=32 {try data.write(to:output.appendingPathComponent("icon_\(size/2)x\(size/2)@2x.png"))}
}
