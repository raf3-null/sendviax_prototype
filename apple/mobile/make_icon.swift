// Code-drawn app icon matching the web mark; no third-party image assets.
import AppKit
let destination=URL(fileURLWithPath:CommandLine.arguments[1])
let size=1024
let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:size,pixelsHigh:size,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
let background=NSBezierPath(rect:NSRect(x:0,y:0,width:size,height:size))
NSGradient(starting:NSColor(red:0.38,green:0.30,blue:0.86,alpha:1),ending:NSColor(red:0.60,green:0.53,blue:1,alpha:1))!.draw(in:background,angle:70)
let bolt=NSBezierPath()
let points:[NSPoint]=[.init(x:575,y:830),.init(x:285,y:470),.init(x:489,y:470),.init(x:429,y:201),.init(x:750,y:597),.init(x:541,y:597)]
bolt.move(to:points[0]);points.dropFirst().forEach{bolt.line(to:$0)};bolt.close();bolt.lineWidth=42;bolt.lineJoinStyle = .round;NSColor.white.setStroke();bolt.stroke()
NSGraphicsContext.restoreGraphicsState()
try FileManager.default.createDirectory(at:destination,withIntermediateDirectories:true)
try bitmap.representation(using:.png,properties:[:])!.write(to:destination.appendingPathComponent("AppIcon.png"))
try """
{"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
""".write(to:destination.appendingPathComponent("Contents.json"),atomically:true,encoding:.utf8)
