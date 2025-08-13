//
//  UIDevice+Extensions.swift
//  swift_tests_clip
//

import Foundation

#if os(iOS)
import UIKit

extension UIDevice {
    static func chipIsA13OrLater() -> Bool {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        let model = String(cString: machine)
        
        // iPhone models with A13 or later
        let a13OrLaterPhones = [
            "iPhone12,1", // iPhone 11
            "iPhone12,3", // iPhone 11 Pro
            "iPhone12,5", // iPhone 11 Pro Max
            "iPhone13,1", // iPhone 12 mini
            "iPhone13,2", // iPhone 12
            "iPhone13,3", // iPhone 12 Pro
            "iPhone13,4", // iPhone 12 Pro Max
            "iPhone14,2", // iPhone 13 Pro
            "iPhone14,3", // iPhone 13 Pro Max
            "iPhone14,4", // iPhone 13 mini
            "iPhone14,5", // iPhone 13
            "iPhone14,6", // iPhone SE (3rd generation)
            "iPhone14,7", // iPhone 14
            "iPhone14,8", // iPhone 14 Plus
            "iPhone15,2", // iPhone 14 Pro
            "iPhone15,3", // iPhone 14 Pro Max
            "iPhone15,4", // iPhone 15
            "iPhone15,5", // iPhone 15 Plus
            "iPhone16,1", // iPhone 15 Pro
            "iPhone16,2", // iPhone 15 Pro Max
            "iPhone17,1", // iPhone 16
            "iPhone17,2", // iPhone 16 Plus
            "iPhone17,3", // iPhone 16 Pro
            "iPhone17,4"  // iPhone 16 Pro Max
        ]
        
        // iPad models with A13 equivalent or later
        let a13OrLaterIpads = [
            "iPad13,1",  // iPad Air (4th generation) - A14
            "iPad13,2",  // iPad Air (4th generation) - A14
            "iPad13,4",  // iPad Pro 11-inch (3rd generation) - M1
            "iPad13,5",  // iPad Pro 11-inch (3rd generation) - M1
            "iPad13,6",  // iPad Pro 11-inch (3rd generation) - M1
            "iPad13,7",  // iPad Pro 11-inch (3rd generation) - M1
            "iPad13,8",  // iPad Pro 12.9-inch (5th generation) - M1
            "iPad13,9",  // iPad Pro 12.9-inch (5th generation) - M1
            "iPad13,10", // iPad Pro 12.9-inch (5th generation) - M1
            "iPad13,11", // iPad Pro 12.9-inch (5th generation) - M1
            "iPad12,1",  // iPad (9th generation) - A13
            "iPad12,2",  // iPad (9th generation) - A13
            "iPad14,1",  // iPad mini (6th generation) - A15
            "iPad14,2",  // iPad mini (6th generation) - A15
            "iPad13,16", // iPad Air (5th generation) - M1
            "iPad13,17", // iPad Air (5th generation) - M1
            "iPad14,3",  // iPad Pro 11-inch (4th generation) - M2
            "iPad14,4",  // iPad Pro 11-inch (4th generation) - M2
            "iPad14,5",  // iPad Pro 12.9-inch (6th generation) - M2
            "iPad14,6",  // iPad Pro 12.9-inch (6th generation) - M2
            "iPad13,18", // iPad (10th generation) - A14
            "iPad13,19", // iPad (10th generation) - A14
            "iPad14,8",  // iPad Air 11-inch (M2)
            "iPad14,9",  // iPad Air 11-inch (M2)
            "iPad14,10", // iPad Air 13-inch (M2)
            "iPad14,11"  // iPad Air 13-inch (M2)
        ]
        
        return a13OrLaterPhones.contains(model) || a13OrLaterIpads.contains(model)
    }
}
#endif