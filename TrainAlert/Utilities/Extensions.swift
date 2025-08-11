//
//  Extensions.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import Foundation
import SwiftUI
import CoreLocation


// MARK: - View Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - CLLocation Extensions

extension CLLocation {
    /// Calculate the bearing to another location in degrees
    func bearing(to destination: CLLocation) -> Double {
        let lat1 = self.coordinate.latitude.degreesToRadians
        let lon1 = self.coordinate.longitude.degreesToRadians
        
        let lat2 = destination.coordinate.latitude.degreesToRadians
        let lon2 = destination.coordinate.longitude.degreesToRadians
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        let radiansBearing = atan2(y, x)
        
        return radiansBearing.radiansToDegrees.normalized()
    }
    
    /// Check if this location is within a certain radius of another location
    func isWithin(_ radius: CLLocationDistance, of location: CLLocation) -> Bool {
        return self.distance(from: location) <= radius
    }
    
    /// Get formatted distance string
    func distanceString(from location: CLLocation) -> String {
        let distance = self.distance(from: location)
        
        if distance < 1000 {
            return String(format: "%.0fm", distance)
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
}

// MARK: - Double Extensions

extension Double {
    var degreesToRadians: Double { return self * .pi / 180 }
    var radiansToDegrees: Double { return self * 180 / .pi }
    
    /// Normalize angle to 0-360 degrees
    func normalized() -> Double {
        let angle = self.truncatingRemainder(dividingBy: 360)
        return angle < 0 ? angle + 360 : angle
    }
}

// MARK: - CLLocationCoordinate2D Extensions

extension CLLocationCoordinate2D {
    /// Create a CLLocation from coordinate
    var location: CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    /// Check if coordinate is valid
    var isValid: Bool {
        return CLLocationCoordinate2DIsValid(self)
    }
}

// MARK: - CLAuthorizationStatus Extensions

extension CLAuthorizationStatus {
    /// Human readable description
    var description: String {
        switch self {
        case .notDetermined:
            return "位置情報の許可が未設定"
        case .denied:
            return "位置情報の利用が拒否されています"
        case .restricted:
            return "位置情報の利用が制限されています"
        case .authorizedWhenInUse:
            return "アプリ使用中のみ位置情報の利用が許可されています"
        case .authorizedAlways:
            return "常に位置情報の利用が許可されています"
        @unknown default:
            return "不明な許可状態"
        }
    }
    
    /// Check if location services are available
    var isAuthorized: Bool {
        return self == .authorizedWhenInUse || self == .authorizedAlways
    }
    
    /// Check if always authorization is granted
    var isAlwaysAuthorized: Bool {
        return self == .authorizedAlways
    }
}

// MARK: - Date Extensions

extension Date {
    /// Get formatted time string for notifications
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: self)
    }
    
    /// Check if date is within the last specified minutes
    func isWithinLast(minutes: Int) -> Bool {
        let timeInterval = TimeInterval(minutes * 60)
        return Date().timeIntervalSince(self) <= timeInterval
    }
}

// MARK: - String Extensions

extension String {
    /// Truncate string to specified length
    func truncated(to length: Int) -> String {
        if self.count <= length {
            return self
        }
        return String(self.prefix(length)) + "..."
    }
}
