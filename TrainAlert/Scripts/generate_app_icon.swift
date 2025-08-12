#!/usr/bin/env swift

import CoreGraphics
import UIKit

// アイコンサイズの定義
let iconSizes: [(name: String, size: Int, scale: Int)] = [
    ("iphone-20x20", 20, 2),
    ("iphone-20x20", 20, 3),
    ("iphone-29x29", 29, 2),
    ("iphone-29x29", 29, 3),
    ("iphone-40x40", 40, 2),
    ("iphone-40x40", 40, 3),
    ("iphone-60x60", 60, 2),
    ("iphone-60x60", 60, 3),
    ("ipad-20x20", 20, 1),
    ("ipad-20x20", 20, 2),
    ("ipad-29x29", 29, 1),
    ("ipad-29x29", 29, 2),
    ("ipad-40x40", 40, 1),
    ("ipad-40x40", 40, 2),
    ("ipad-76x76", 76, 1),
    ("ipad-76x76", 76, 2),
    ("ipad-83.5x83.5", 83.5, 2),
    ("ios-marketing-1024x1024", 1_024, 1)
]

// アイコン生成関数
func generateIcon(size: CGSize) -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    
    guard let context = CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    ) else {
        return nil
    }
    
    let rect = CGRect(origin: .zero, size: size)
    
    // 背景グラデーション
    let colors = [
        CGColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 1.0),
        CGColor(red: 0.85, green: 0.85, blue: 0.95, alpha: 1.0)
    ] as CFArray
    let locations: [CGFloat] = [0.0, 1.0]
    
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
        context.drawLinearGradient(
            gradient,
            start: CGPoint.zero,
            end: CGPoint(x: size.width, y: size.height),
            options: []
        )
    }
    
    // 電車（寝ている）
    let trainRect = CGRect(
        x: rect.width * 0.15,
        y: rect.height * 0.55,
        width: rect.width * 0.7,
        height: rect.height * 0.25
    )
    
    // 電車本体
    context.setFillColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0)
    let trainPath = CGPath(roundedRect: trainRect, cornerWidth: trainRect.height * 0.3, cornerHeight: trainRect.height * 0.3, transform: nil)
    context.addPath(trainPath)
    context.fillPath()
    
    // 電車の窓
    context.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.8)
    let windowWidth = trainRect.width * 0.18
    let windowHeight = trainRect.height * 0.4
    let windowY = trainRect.midY - windowHeight / 2
    
    for i in 0..<3 {
        let windowX = trainRect.minX + trainRect.width * 0.2 + CGFloat(i) * (windowWidth + trainRect.width * 0.1)
        let windowRect = CGRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight)
        let windowPath = CGPath(roundedRect: windowRect, cornerWidth: windowHeight * 0.2, cornerHeight: windowHeight * 0.2, transform: nil)
        context.addPath(windowPath)
        context.fillPath()
    }
    
    // Zzz... テキスト
    context.saveGState()
    context.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    let zzzX = trainRect.maxX - size.width * 0.1
    let zzzY = trainRect.minY - size.height * 0.05
    context.translateBy(x: zzzX, y: zzzY)
    context.rotate(by: 15 * .pi / 180)
    
    // 簡単な "Z" を3つ描画
    let fontSize = size.width * 0.06
    for i in 0..<3 {
        let x = CGFloat(i) * fontSize * 0.7
        
        // Z の描画
        context.move(to: CGPoint(x: x, y: 0))
        context.addLine(to: CGPoint(x: x + fontSize * 0.5, y: 0))
        context.addLine(to: CGPoint(x: x, y: fontSize))
        context.addLine(to: CGPoint(x: x + fontSize * 0.5, y: fontSize))
        context.setLineWidth(fontSize * 0.15)
        context.setStrokeColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        context.strokePath()
    }
    context.restoreGState()
    
    // 目覚まし時計
    let alarmSize = size.width * 0.35
    let alarmCenter = CGPoint(x: rect.width * 0.5, y: rect.height * 0.25)
    
    // 時計の外枠（オレンジ）
    context.setFillColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0)
    context.fillEllipse(in: CGRect(
        x: alarmCenter.x - alarmSize / 2,
        y: alarmCenter.y - alarmSize / 2,
        width: alarmSize,
        height: alarmSize
    ))
    
    // 時計の内側（白）
    context.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    let innerSize = alarmSize * 0.84
    context.fillEllipse(in: CGRect(
        x: alarmCenter.x - innerSize / 2,
        y: alarmCenter.y - innerSize / 2,
        width: innerSize,
        height: innerSize
    ))
    
    // 時計の針
    context.setStrokeColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
    context.setLineWidth(size.width * 0.01)
    
    // 長針
    context.move(to: alarmCenter)
    let longHandLength = innerSize * 0.35
    context.addLine(to: CGPoint(
        x: alarmCenter.x + longHandLength * cos(-60 * .pi / 180 - .pi / 2),
        y: alarmCenter.y + longHandLength * sin(-60 * .pi / 180 - .pi / 2)
    ))
    context.strokePath()
    
    // 短針
    context.move(to: alarmCenter)
    let shortHandLength = innerSize * 0.25
    context.addLine(to: CGPoint(
        x: alarmCenter.x + shortHandLength * cos(30 * .pi / 180 - .pi / 2),
        y: alarmCenter.y + shortHandLength * sin(30 * .pi / 180 - .pi / 2)
    ))
    context.strokePath()
    
    // ベル（左右）
    context.setFillColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0)
    let bellSize = alarmSize * 0.2
    
    // 左ベル
    context.saveGState()
    context.translateBy(x: alarmCenter.x - alarmSize * 0.35, y: alarmCenter.y - alarmSize * 0.65)
    context.rotate(by: -15 * .pi / 180)
    context.fillEllipse(in: CGRect(x: -bellSize / 2, y: -bellSize / 2, width: bellSize, height: bellSize))
    context.restoreGState()
    
    // 右ベル
    context.saveGState()
    context.translateBy(x: alarmCenter.x + alarmSize * 0.35, y: alarmCenter.y - alarmSize * 0.65)
    context.rotate(by: 15 * .pi / 180)
    context.fillEllipse(in: CGRect(x: -bellSize / 2, y: -bellSize / 2, width: bellSize, height: bellSize))
    context.restoreGState()
    
    return context.makeImage()
}

// メイン処理
print("Generating app icons...")

for (name, baseSize, scale) in iconSizes {
    let actualSize = CGFloat(baseSize) * CGFloat(scale)
    let size = CGSize(width: actualSize, height: actualSize)
    
    guard let image = generateIcon(size: size) else {
        print("Failed to generate icon for \(name)@\(scale)x")
        continue
    }
    
    // CGImageをPNGデータに変換
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    
    guard let context = CGContext(
        data: nil,
        width: Int(actualSize),
        height: Int(actualSize),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    ) else {
        continue
    }
    
    context.draw(image, in: CGRect(origin: .zero, size: size))
    
    guard let newImage = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(
            URL(fileURLWithPath: "icon-\(baseSize)x\(baseSize)@\(scale)x.png") as CFURL,
            kUTTypePNG,
            1,
            nil
          ) else {
        continue
    }
    
    CGImageDestinationAddImage(destination, newImage, nil)
    
    if CGImageDestinationFinalize(destination) {
        print("Generated: icon-\(baseSize)x\(baseSize)@\(scale)x.png")
    }
}

print("Icon generation complete!")

