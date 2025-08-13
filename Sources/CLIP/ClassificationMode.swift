import Foundation
import CoreML

// MARK: - Errors

enum ClassificationError: LocalizedError {
    case precomputedEmbeddingsNotFound(String)
    case invalidMode(String)
    case missingArgument(String)
    
    var errorDescription: String? {
        switch self {
        case .precomputedEmbeddingsNotFound(let path):
            return "Precomputed embeddings file not found at: \(path)"
        case .invalidMode(let mode):
            return "Invalid mode '\(mode)'. Valid modes: \(ClassificationMode.allCases.map { $0.rawValue }.joined(separator: ", "))"
        case .missingArgument(let arg):
            return "Missing required argument: \(arg)"
        }
    }
}

// MARK: - Classification Modes

/// Defines the two modes for text embedding handling
enum ClassificationMode: String, CaseIterable {
    case runtime = "runtime"
    case precomputed = "precomputed"
    
    var description: String {
        switch self {
        case .runtime:
            return "Runtime mode: Computes text embeddings on-demand using TextEncoder model"
        case .precomputed:
            return "Precomputed mode: Uses pre-saved text embeddings from JSON file"
        }
    }
}

// MARK: - Data Structures

/// Structure for storing precomputed embeddings in JSON format
struct PrecomputedEmbeddings: Codable {
    let version: String
    let model: String
    let promptTemplate: String
    let embeddingDimension: Int
    let embeddings: [LabelEmbedding]
    let createdAt: String
    
    struct LabelEmbedding: Codable {
        let label: String
        let embedding: [Float]
    }
}

/// Configuration for the image classifier
struct ClassifierConfig {
    let mode: ClassificationMode
    let promptTemplate: String
    
    static let `default` = ClassifierConfig(
        mode: .runtime,
        promptTemplate: "a photo of a"
    )
}

// MARK: - Precomputed Embeddings Manager

struct PrecomputedEmbeddingsManager {
    
    /// Generate precomputed embeddings file from labels
    static func generateEmbeddings(
        labels: [String], 
        textEncoder: TextEncoder,
        promptTemplate: String = "a photo of a",
        outputURL: URL
    ) async throws {
        print("Generating precomputed embeddings for \(labels.count) labels...")
        
        var labelEmbeddings: [PrecomputedEmbeddings.LabelEmbedding] = []
        
        for (index, label) in labels.enumerated() {
            let prompt = "\(promptTemplate) \(label)"
            let embedding = try textEncoder.computeTextEmbedding(prompt: prompt)
            let embeddingArray = Array(embedding.scalars)
            
            labelEmbeddings.append(PrecomputedEmbeddings.LabelEmbedding(
                label: label,
                embedding: embeddingArray
            ))
            
            if (index + 1) % 10 == 0 {
                print("Processed \(index + 1)/\(labels.count) labels")
            }
        }
        
        let precomputedEmbeddings = PrecomputedEmbeddings(
            version: "1.0",
            model: "MobileCLIP-S2",
            promptTemplate: promptTemplate,
            embeddingDimension: labelEmbeddings.first?.embedding.count ?? 512,
            embeddings: labelEmbeddings,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(precomputedEmbeddings)
        try data.write(to: outputURL)
        
        print("✅ Precomputed embeddings saved to: \(outputURL.path)")
        print("   - Labels: \(labels.count)")
        print("   - Embedding dimension: \(precomputedEmbeddings.embeddingDimension)")
        print("   - File size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
    }
    
    /// Load precomputed embeddings from JSON file
    static func loadEmbeddings(from url: URL) throws -> [(String, MLShapedArray<Float32>)] {
        print("Loading precomputed embeddings from: \(url.lastPathComponent)")
        
        let data = try Data(contentsOf: url)
        let precomputedEmbeddings = try JSONDecoder().decode(PrecomputedEmbeddings.self, from: data)
        
        print("✅ Loaded precomputed embeddings:")
        print("   - Version: \(precomputedEmbeddings.version)")
        print("   - Model: \(precomputedEmbeddings.model)")  
        print("   - Prompt template: \"\(precomputedEmbeddings.promptTemplate)\"")
        print("   - Labels: \(precomputedEmbeddings.embeddings.count)")
        print("   - Embedding dimension: \(precomputedEmbeddings.embeddingDimension)")
        print("   - Created: \(precomputedEmbeddings.createdAt)")
        
        var labelEmbeddings: [(String, MLShapedArray<Float32>)] = []
        
        for labelEmbedding in precomputedEmbeddings.embeddings {
            let mlArray = try MLMultiArray(shape: [1, NSNumber(value: labelEmbedding.embedding.count)], dataType: .float32)
            for (index, value) in labelEmbedding.embedding.enumerated() {
                mlArray[[0, NSNumber(value: index)]] = NSNumber(value: value)
            }
            let shapedArray = MLShapedArray<Float32>(converting: mlArray)
            labelEmbeddings.append((labelEmbedding.label, shapedArray))
        }
        
        return labelEmbeddings
    }
}