//
//  Station.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import Foundation
import CoreLocation

struct StationModel: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let lines: [String]
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}
