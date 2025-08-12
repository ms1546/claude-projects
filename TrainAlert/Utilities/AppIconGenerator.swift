//
//  AppIconGenerator.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import SwiftUI
import UIKit

struct AppIconGenerator {
    static func generateIcon(size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            
            // 背景グラデーション
            let gradient = CAGradientLayer()
            gradient.frame = rect
            gradient.colors = [
                UIColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 1.0).cgColor,
                UIColor(red: 0.85, green: 0.85, blue: 0.95, alpha: 1.0).cgColor
            ]
            gradient.startPoint = CGPoint.zero
            gradient.endPoint = CGPoint(x: 1, y: 1)
            gradient.render(in: context.cgContext)
            
            // 電車（寝ている）
            let trainRect = CGRect(
                x: rect.width * 0.15,
                y: rect.height * 0.55,
                width: rect.width * 0.7,
                height: rect.height * 0.25
            )
            
            // 電車本体
            let trainPath = UIBezierPath(roundedRect: trainRect, cornerRadius: trainRect.height * 0.3)
            context.cgContext.saveGState()
            context.cgContext.addPath(trainPath.cgPath)
            context.cgContext.clip()
            
            // 電車のグラデーション
            let trainGradient = CAGradientLayer()
            trainGradient.frame = trainRect
            trainGradient.colors = [
                UIColor(red: 0.0, green: 0.4, blue: 0.8, alpha: 1.0).cgColor,
                UIColor(red: 0.0, green: 0.3, blue: 0.7, alpha: 1.0).cgColor
            ]
            trainGradient.startPoint = CGPoint(x: 0.5, y: 0)
            trainGradient.endPoint = CGPoint(x: 0.5, y: 1)
            trainGradient.render(in: context.cgContext)
            context.cgContext.restoreGState()
            
            // 電車の窓
            let windowWidth = trainRect.width * 0.18
            let windowHeight = trainRect.height * 0.4
            let windowY = trainRect.midY - windowHeight / 2
            
            for i in 0..<3 {
                let windowX = trainRect.minX + trainRect.width * 0.2 + CGFloat(i) * (windowWidth + trainRect.width * 0.1)
                let windowRect = CGRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight)
                let windowPath = UIBezierPath(roundedRect: windowRect, cornerRadius: windowHeight * 0.2)
                UIColor.white.withAlphaComponent(0.8).setFill()
                windowPath.fill()
            }
            
            // Zzz... (寝ている表現)
            let zzzFont = UIFont.systemFont(ofSize: size.width * 0.08, weight: .bold)
            let zzzAttributes: [NSAttributedString.Key: Any] = [
                .font: zzzFont,
                .foregroundColor: UIColor.white
            ]
            let zzzText = "Zzz..."
            let zzzSize = zzzText.size(withAttributes: zzzAttributes)
            let zzzRect = CGRect(
                x: trainRect.maxX - zzzSize.width * 0.3,
                y: trainRect.minY - zzzSize.height * 1.2,
                width: zzzSize.width,
                height: zzzSize.height
            )
            
            context.cgContext.saveGState()
            context.cgContext.translateBy(x: zzzRect.midX, y: zzzRect.midY)
            context.cgContext.rotate(by: 15 * .pi / 180)
            context.cgContext.translateBy(x: -zzzRect.midX, y: -zzzRect.midY)
            zzzText.draw(in: zzzRect, withAttributes: zzzAttributes)
            context.cgContext.restoreGState()
            
            // 目覚まし時計
            let alarmSize = size.width * 0.35
            let alarmCenter = CGPoint(
                x: rect.width * 0.5,
                y: rect.height * 0.25
            )
            
            // 時計の外枠
            let alarmOuterRadius = alarmSize * 0.5
            let alarmOuterPath = UIBezierPath(
                arcCenter: alarmCenter,
                radius: alarmOuterRadius,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            )
            UIColor.orange.setFill()
            alarmOuterPath.fill()
            
            // 時計の内側（白）
            let alarmInnerRadius = alarmSize * 0.42
            let alarmInnerPath = UIBezierPath(
                arcCenter: alarmCenter,
                radius: alarmInnerRadius,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            )
            UIColor.white.setFill()
            alarmInnerPath.fill()
            
            // 時計の針
            context.cgContext.setStrokeColor(UIColor.black.cgColor)
            context.cgContext.setLineWidth(size.width * 0.01)
            
            // 長針
            context.cgContext.move(to: alarmCenter)
            let longHandEnd = CGPoint(
                x: alarmCenter.x + alarmInnerRadius * 0.7 * cos(-60 * .pi / 180 - .pi / 2),
                y: alarmCenter.y + alarmInnerRadius * 0.7 * sin(-60 * .pi / 180 - .pi / 2)
            )
            context.cgContext.addLine(to: longHandEnd)
            context.cgContext.strokePath()
            
            // 短針
            context.cgContext.move(to: alarmCenter)
            let shortHandEnd = CGPoint(
                x: alarmCenter.x + alarmInnerRadius * 0.5 * cos(30 * .pi / 180 - .pi / 2),
                y: alarmCenter.y + alarmInnerRadius * 0.5 * sin(30 * .pi / 180 - .pi / 2)
            )
            context.cgContext.addLine(to: shortHandEnd)
            context.cgContext.strokePath()
            
            // ベル（左）
            let bellSize = alarmSize * 0.25
            let leftBellCenter = CGPoint(
                x: alarmCenter.x - alarmOuterRadius * 0.7,
                y: alarmCenter.y - alarmOuterRadius * 0.9
            )
            
            context.cgContext.saveGState()
            context.cgContext.translateBy(x: leftBellCenter.x, y: leftBellCenter.y)
            context.cgContext.rotate(by: -15 * .pi / 180)
            
            let leftBellPath = UIBezierPath()
            leftBellPath.move(to: CGPoint(x: 0, y: -bellSize * 0.3))
            leftBellPath.addCurve(
                to: CGPoint(x: 0, y: bellSize * 0.3),
                controlPoint1: CGPoint(x: -bellSize * 0.4, y: -bellSize * 0.2),
                controlPoint2: CGPoint(x: -bellSize * 0.4, y: bellSize * 0.2)
            )
            leftBellPath.addCurve(
                to: CGPoint(x: 0, y: -bellSize * 0.3),
                controlPoint1: CGPoint(x: bellSize * 0.4, y: bellSize * 0.2),
                controlPoint2: CGPoint(x: bellSize * 0.4, y: -bellSize * 0.2)
            )
            UIColor.orange.setFill()
            leftBellPath.fill()
            
            context.cgContext.restoreGState()
            
            // ベル（右）
            let rightBellCenter = CGPoint(
                x: alarmCenter.x + alarmOuterRadius * 0.7,
                y: alarmCenter.y - alarmOuterRadius * 0.9
            )
            
            context.cgContext.saveGState()
            context.cgContext.translateBy(x: rightBellCenter.x, y: rightBellCenter.y)
            context.cgContext.rotate(by: 15 * .pi / 180)
            
            let rightBellPath = UIBezierPath()
            rightBellPath.move(to: CGPoint(x: 0, y: -bellSize * 0.3))
            rightBellPath.addCurve(
                to: CGPoint(x: 0, y: bellSize * 0.3),
                controlPoint1: CGPoint(x: -bellSize * 0.4, y: -bellSize * 0.2),
                controlPoint2: CGPoint(x: -bellSize * 0.4, y: bellSize * 0.2)
            )
            rightBellPath.addCurve(
                to: CGPoint(x: 0, y: -bellSize * 0.3),
                controlPoint1: CGPoint(x: bellSize * 0.4, y: bellSize * 0.2),
                controlPoint2: CGPoint(x: bellSize * 0.4, y: -bellSize * 0.2)
            )
            UIColor.orange.setFill()
            rightBellPath.fill()
            
            context.cgContext.restoreGState()
        }
    }
    
    static func saveIconToFile() {
        guard let icon = generateIcon(size: CGSize(width: 1_024, height: 1_024)) else {
            print("Failed to generate icon")
            return
        }
        
        guard let data = icon.pngData() else {
            print("Failed to convert icon to PNG data")
            return
        }
        
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        let fileURL = documentsDirectory.appendingPathComponent("AppIcon-1024.png")
        
        do {
            try data.write(to: fileURL)
            print("Icon saved to: \(fileURL.path)")
        } catch {
            print("Failed to save icon: \(error)")
        }
    }
}

