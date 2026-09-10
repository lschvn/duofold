import AppKit

/// Original fixture: no captured personal windows, Apple wallpapers, or source-video assets.
enum DemoDesktop {
    static func make(width: Int = 1280, height: Int = 800) -> CGImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        let sx = Double(width)/1280, sy = Double(height)/800
        let transform = NSAffineTransform(); transform.scaleX(by: sx, yBy: sy); transform.concat()
        NSGradient(colors: [NSColor(red:0.12,green:0.25,blue:0.48,alpha:1), NSColor(red:0.38,green:0.49,blue:0.68,alpha:1), NSColor(red:0.79,green:0.63,blue:0.53,alpha:1)])!.draw(in: NSRect(x:0,y:0,width:1280,height:800), angle: -55)
        func rounded(_ rect: NSRect, _ color: NSColor, _ radius: Double = 16) {
            color.setFill(); NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
        }
        func text(_ string: String, _ x: Double, _ y: Double, _ size: Double, _ color: NSColor = .white, _ weight: NSFont.Weight = .regular) {
            (string as NSString).draw(at:NSPoint(x:x,y:y),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:weight),.foregroundColor:color])
        }
        rounded(NSRect(x:0,y:768,width:1280,height:32),NSColor(white:1,alpha:0.17),0)
        text("◈   Finder     File     Edit     View     Go     Window     Help",20,774,14)
        text("Wed 9 Sep   9:41",1110,774,14)
        // Sample application windows provide high-frequency details for blur inspection.
        rounded(NSRect(x:105,y:175,width:645,height:482),NSColor(white:0.98,alpha:0.96))
        rounded(NSRect(x:105,y:605,width:645,height:52),NSColor(white:0.89,alpha:1))
        for (i,c) in [NSColor.systemRed,.systemYellow,.systemGreen].enumerated() {
            c.setFill(); NSBezierPath(ovalIn:NSRect(x:124+i*22,y:626,width:12,height:12)).fill()
        }
        text("A little room to think",282,620,16,.darkGray,.medium)
        text("Make space.",144,523,44,.black,.bold)
        text("For the things you want to make.",145,489,21,.darkGray)
        for (i,line) in ["A quiet desktop. A fresh idea.","Close the lid, take a breath.","Everything will be here when you return."].enumerated() { text(line,145,421-Double(i)*37,20,.darkGray) }
        rounded(NSRect(x:145,y:234,width:246,height:48),NSColor(red:0.24,green:0.37,blue:0.66,alpha:1),10)
        text("Today’s notes",166,246,18,.white,.medium)
        rounded(NSRect(x:809,y:389,width:329,height:260),NSColor(white:0.12,alpha:0.88))
        text("WEDNESDAY",836,603,14,NSColor(white:0.8,alpha:1),.semibold)
        text("9",832,488,98,.white,.light)
        text("September",839,459,24,.white,.medium)
        text("Nothing on the calendar.",839,422,17,NSColor(white:0.8,alpha:1))
        rounded(NSRect(x:809,y:195,width:329,height:168),NSColor(white:1,alpha:0.21))
        text("DuoFold",838,304,24,.white,.semibold)
        text("Your desktop, in motion.",838,263,17)
        text("Original demo content",838,222,14,NSColor(white:1,alpha:0.7))
        rounded(NSRect(x:365,y:22,width:550,height:75),NSColor(white:1,alpha:0.3),22)
        for i in 0..<8 {
            let colors:[NSColor]=[.systemBlue,.systemOrange,.systemTeal,.systemPurple,.systemPink,.systemGreen,.systemIndigo,.gray]
            rounded(NSRect(x:387+i*65,y:35,width:49,height:49),colors[i],12)
            text(["F","N","S","M","P","C","D","⚙"][i],402+Double(i)*65,45,25,.white,.medium)
        }
        image.unlockFocus()
        return image.cgImage(forProposedRect:nil,context:nil,hints:nil)!
    }
}
