//
//  Logger+extension.swift
//
//  Created by Corey Baker on 7/4/21.
//  Copyright © 2021 Network Reconnaissance Lab. All rights reserved.
//

import Foundation
import os.log

@available(iOS 14.0, *)
@available(macOS 11.0, *)
extension Logger {
  private static var subsystem      = Bundle.main.bundleIdentifier!
  static let category               = "Carter"

  static let subscriber             = Logger(subsystem: subsystem, category: "\(category).subscriber")

}
