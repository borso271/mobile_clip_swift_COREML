import Foundation
import CoreML
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ImageClassifier {
    func classifyImages() async {
        do {
            print("Starting image classification...")
            
            // Get resource bundle
            guard let resourceBundle = Bundle.module.resourceURL else {
                print("Error: Could not find resource bundle")
                return
            }
            
            // Load labels
            let labelsURL = resourceBundle.appendingPathComponent("labels.txt")
            let labels = try loadLabels(from: labelsURL)
            print("Loaded \(labels.count) labels")
            
            // Initialize encoders
            let modelsURL = resourceBundle.appendingPathComponent("models")
            let imageEncoder = try ImgEncoder(resourcesAt: modelsURL)
            let textEncoder = try TextEncoder(resourcesAt: modelsURL)
            
            // Pre-compute text embeddings for all labels
            print("Computing text embeddings for labels...")
            var labelEmbeddings: [(String, MLShapedArray<Float32>)] = []
            for label in labels {
                let embedding = try textEncoder.computeTextEmbedding(prompt: "a photo of a \(label)")
                labelEmbeddings.append((label, embedding))
            }
            
            // Process images
            let imagesURL = resourceBundle.appendingPathComponent("images")
            let imageFiles = try FileManager.default.contentsOfDirectory(at: imagesURL, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension.lowercased() == "jpeg" || $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "png" }
            
            print("Processing \(imageFiles.count) images...")
            
            for imageURL in imageFiles {
                try await classifyImage(at: imageURL, imageEncoder: imageEncoder, labelEmbeddings: labelEmbeddings)
            }
            
        } catch {
            print("Error: \(error)")
        }
    }
    
    func loadLabels(from url: URL) throws -> [String] {
        let content = try String(contentsOf: url)
        return content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    func classifyImage(at imageURL: URL, imageEncoder: ImgEncoder, labelEmbeddings: [(String, MLShapedArray<Float32>)]) async throws {
#if os(iOS)
        guard let image = UIImage(contentsOfFile: imageURL.path) else {
            print("Failed to load image: \(imageURL.lastPathComponent)")
            return
        }
#elseif os(macOS)
        guard let image = NSImage(contentsOf: imageURL) else {
            print("Failed to load image: \(imageURL.lastPathComponent)")
            return
        }
#endif
        
        // Get image embedding
        let imageEmbedding = try await imageEncoder.computeImgEmbedding(img: image)
        
        // Compute similarities with all labels
        var bestMatch = ""
        var bestSimilarity: Float = -1.0
        
        for (label, labelEmbedding) in labelEmbeddings {
            let similarity = cosineSimilarity(imageEmbedding, labelEmbedding)
            if similarity > bestSimilarity {
                bestSimilarity = similarity
                bestMatch = label
            }
        }
        
        print("\(imageURL.lastPathComponent): \(bestMatch) (similarity: \(String(format: "%.3f", bestSimilarity)))")
    }
    
    func cosineSimilarity(_ a: MLShapedArray<Float32>, _ b: MLShapedArray<Float32>) -> Float {
        let aData = a.scalars
        let bData = b.scalars
        
        guard aData.count == bData.count else { return 0.0 }
        
        var dotProduct: Float = 0.0
        var normA: Float = 0.0
        var normB: Float = 0.0
        
        for i in 0..<aData.count {
            dotProduct += aData[i] * bData[i]
            normA += aData[i] * aData[i]
            normB += bData[i] * bData[i]
        }
        
        let magnitude = sqrt(normA) * sqrt(normB)
        return magnitude > 0 ? dotProduct / magnitude : 0.0
    }
}

// Main entry point
import Foundation

Task {
    let classifier = ImageClassifier()
    await classifier.classifyImages()
    exit(0)
}

RunLoop.main.run()