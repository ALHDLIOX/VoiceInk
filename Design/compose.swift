import AppKit
// args: maskPNG artPNG outPNG —— 外形（透明度）取 mask，颜色取 art 的亮度（白线），其余为黑
let a = CommandLine.arguments
let mask = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: a[1])))!
let art = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: a[2])))!
let w = mask.pixelsWide, h = mask.pixelsHigh
let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
for y in 0..<h { for x in 0..<w {
    let m = mask.colorAt(x: x, y: y)!.alphaComponent
    let c = art.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
    let v = c.alphaComponent > 0 ? (c.redComponent + c.greenComponent + c.blueComponent) / 3 * c.alphaComponent : 0
    out.setColor(NSColor(deviceRed: v, green: v, blue: v, alpha: m), atX: x, y: y)
} }
try! out.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[3]))
print("ok")
