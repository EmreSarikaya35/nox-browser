// Kullanım: Scripts/make-icon.sh  (Scripts/logo.jpg'den 1024px ana ikonu üretir)
// Logo, macOS ikon ızgarasına göre kenar boşluklu yuvarlak köşeli kareye kırpılır.
import AppKit

let src = CommandLine.arguments[1], out = CommandLine.arguments[2]
guard let logo = NSImage(contentsOfFile: src) else { fatalError("logo okunamadı: \(src)") }
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high

let rect = NSRect(x: 100, y: 100, width: 824, height: 824)
NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185).addClip()
logo.draw(in: rect, from: .zero, operation: .copy, fraction: 1)

try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
