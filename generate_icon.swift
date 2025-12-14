import Cocoa
import CoreGraphics

func createBoltIcon(size: CGSize, scale: CGFloat, filename: String) {
    let width = parseInt(size.width * scale)
    let height = parseInt(size.height * scale)
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    
    guard let context = CGContext(data: nil,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: 0,
                                space: colorSpace,
                                bitmapInfo: bitmapInfo) else {
        print("Failed to create context")
        return
    }
    
    // Clear background (make it transparent)
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    
    // Scale context so we can draw in logical points
    context.scaleBy(x: scale, y: scale)
    
    // Draw Bolt Path
    // Bolt shape roughly centered in 60x60 canvas
    let path = CGMutablePath()
    // Points for a lightning bolt shape
    path.move(to: CGPoint(x: 32, y: 5))
    path.addLine(to: CGPoint(x: 18, y: 35))
    path.addLine(to: CGPoint(x: 28, y: 35))
    path.addLine(to: CGPoint(x: 22, y: 55))
    path.addLine(to: CGPoint(x: 42, y: 25))
    path.addLine(to: CGPoint(x: 32, y: 25))
    path.closeSubpath()
    
    context.addPath(path)
    context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1)) // Black color
    context.fillPath()
    
    // Create Image
    guard let cgImage = context.makeImage() else { return }
    let imageRep = NSBitmapImageRep(cgImage: cgImage)
    
    // Save to file
    guard let data = imageRep.representation(using: .png, properties: [:]) else { return }
    let url = URL(fileURLWithPath: filename)
    try? data.write(to: url)
    print("Created \(filename)")
}

func parseInt(_ float: CGFloat) -> Int {
    return Int(float)
}

// Generate icons
let outputDir = "/Users/onuryurdusever/moments/project/jolt/JoltActionExtension/Media.xcassets/ActionIcon.imageset/"
let baseSize = CGSize(width: 60, height: 60)

createBoltIcon(size: baseSize, scale: 1.0, filename: outputDir + "icon_60x.png")
createBoltIcon(size: baseSize, scale: 2.0, filename: outputDir + "icon_120x.png")
createBoltIcon(size: baseSize, scale: 3.0, filename: outputDir + "icon_180x.png")
