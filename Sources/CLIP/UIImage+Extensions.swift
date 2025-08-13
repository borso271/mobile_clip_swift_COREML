//
//  UIImage+Extensions.swift
//  swift_tests_clip
//

import Foundation
import CoreML
import CoreVideo
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if os(macOS)
extension NSImage {
    convenience init?(cgImage: CGImage) {
        self.init(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    
    var cgImage: CGImage? {
        return self.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
#endif

#if os(iOS)
extension UIImage {
    func resizeImageTo(size: CGSize) throws -> UIImage? {
        #if os(iOS)
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        self.draw(in: CGRect(origin: CGPoint.zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
        #elseif os(macOS)
        let resizedImage = NSImage(size: size)
        resizedImage.lockFocus()
        let context = NSGraphicsContext.current
        context?.imageInterpolation = .high
        self.draw(in: NSRect(origin: .zero, size: size), from: NSRect(origin: .zero, size: self.size), operation: .copy, fraction: 1.0)
        resizedImage.unlockFocus()
        return resizedImage
        #endif
    }
    
    func convertToBuffer() -> CVPixelBuffer? {
        guard let cgImage = self.cgImage else {
            return nil
        }
        
        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            cgImage.width,
            cgImage.height,
            kCVPixelFormatType_32ARGB,
            attributes,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: pixelData,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return buffer
    }
}
#endif

#if os(macOS)
extension NSImage {
    func resizeImageTo(size: CGSize) throws -> NSImage? {
        guard let cgImage = self.cgImage else { return nil }
        
        // Create a new bitmap context with the desired size
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        // Set the interpolation quality
        context.interpolationQuality = .high
        
        // Draw the image scaled to the new size
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        
        // Create a new CGImage from the context
        guard let resizedCGImage = context.makeImage() else { return nil }
        
        // Convert back to NSImage
        return NSImage(cgImage: resizedCGImage)
    }
    
    func convertToBuffer() -> CVPixelBuffer? {
        guard let cgImage = self.cgImage else {
            return nil
        }
        
        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            cgImage.width,
            cgImage.height,
            kCVPixelFormatType_32ARGB,
            attributes,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: pixelData,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return buffer
    }
}
#endif