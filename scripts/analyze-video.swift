// Local research only. This script does not download or redistribute source footage.
// swift scripts/analyze-video.swift movie.mp4 output.png [start] [end]
import AppKit
import AVFoundation
let args=CommandLine.arguments
let asset=AVURLAsset(url:URL(fileURLWithPath:args[1]))
let gen=AVAssetImageGenerator(asset:asset)
gen.appliesPreferredTrackTransform=true
gen.requestedTimeToleranceBefore = .zero; gen.requestedTimeToleranceAfter = .zero
let start=args.count>3 ? Double(args[3])! : 0
let end=args.count>4 ? Double(args[4])! : CMTimeGetSeconds(asset.duration)
let size=NSSize(width:1600,height:1000)
let image=NSImage(size:size)
image.lockFocus();NSColor(white:0.12,alpha:1).setFill();NSRect(origin:.zero,size:size).fill()
for i in 0..<20 {
 let time=start+(end-start)*Double(i)/20
 if let cg=try? gen.copyCGImage(at:CMTime(seconds:time,preferredTimescale:60000),actualTime:nil) {
  let scale=min(400/Double(cg.width),176/Double(cg.height))
  let w=Double(cg.width)*scale,h=Double(cg.height)*scale
  let x=Double(i%4)*400,y=Double(4-i/4)*200
  NSImage(cgImage:cg,size:.zero).draw(in:NSRect(x:x+(400-w)/2,y:y+24,width:w,height:h))
  NSString(string:String(format:"%.3f s",time)).draw(at:NSPoint(x:x+12,y:y+4),withAttributes:[.font:NSFont.monospacedDigitSystemFont(ofSize:14,weight:.regular),.foregroundColor:NSColor.white])
 }
}
image.unlockFocus()
try NSBitmapImageRep(data:image.tiffRepresentation!)!.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:args[2]))
print("Saved \(args[2]); sampled \(start)...\(end) s")
