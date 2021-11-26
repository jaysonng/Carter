//
//  CarterError.swift
//  
//
//  Created by Jayson Ng on 11/26/21.
//

import Foundation

public enum CarterError: Error, CustomStringConvertible {
    
    case invalidURL
    case failedToGetURLInformation
    case noInternetConnection
    
    public var description: String {
        switch self {
        case .invalidURL:                         return "Invalid URL!"
        case .failedToGetURLInformation:          return "Failed to get URL Information."
        case .noInternetConnection:               return "There seems to be a problem with your connection."
        }
    }
}
