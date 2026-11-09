import AppKit
// usage: swift compose.swift mask-1024.png render-1024.png out-1024.png
// 外形（透明度）取 mask（上游图标，系统的连续圆角），颜色取 render 的亮度（白线），其余为黑。
// 黑底的蓝通道加 1/255：纯黑白的图会被 actool 存成灰度（Monochrome），
// macOS 26+ 认不出灰度图标的外形，会给它套一圈浅灰底板。
let a = CommandLine.arguments
let mask = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: a[1])))!
let art = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: a[2])))!
let w = mask.pixelsWide, h = mask.pixelsHigh
let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let tint: CGFloat = 1.0 / 255
for y in 0..<h { for x in 0..<w {
    let m = mask.colorAt(x: x, y: y)!.alphaComponent
    let c = art.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
    let v = c.alphaComponent > 0 ? (c.redComponent + c.greenComponent + c.blueComponent) / 3 * c.alphaComponent : 0
    out.setColor(NSColor(deviceRed: v, green: v, blue: min(1, v + tint), alpha: m), atX: x, y: y)
} }
try! out.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[3]))
print("ok")
