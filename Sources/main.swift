import Foundation
import CoreML
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ImageClassifier {
    let config: ClassifierConfig
    
    init(config: ClassifierConfig = .default) {
        self.config = config
    }
    
    func classifyImages() async {
        do {
            print("Starting image classification...")
            print("Mode: \(config.mode.description)")
            
            // Get resource bundle
            guard let resourceBundle = Bundle.module.resourceURL else {
                print("Error: Could not find resource bundle")
                return
            }
            
            // Initialize image encoder (always needed)
            let modelsURL = resourceBundle.appendingPathComponent("models")
            let imageEncoder = try ImgEncoder(resourcesAt: modelsURL)
            
            // Get label embeddings based on mode
            let labelEmbeddings: [(String, MLShapedArray<Float32>)]
            
            switch config.mode {
            case .runtime:
                labelEmbeddings = try await computeRuntimeEmbeddings(resourceBundle: resourceBundle, modelsURL: modelsURL)
            case .precomputed:
                labelEmbeddings = try loadPrecomputedEmbeddings(resourceBundle: resourceBundle)
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
    
    /// Compute embeddings at runtime using TextEncoder
    func computeRuntimeEmbeddings(resourceBundle: URL, modelsURL: URL) async throws -> [(String, MLShapedArray<Float32>)] {
        // Load labels
        let labelsURL = resourceBundle.appendingPathComponent("labels.txt")
        let labels = try loadLabels(from: labelsURL)
        print("Loaded \(labels.count) labels")
        
        // Initialize text encoder
        let textEncoder = try TextEncoder(resourcesAt: modelsURL)
        
        // Compute text embeddings for all labels
        print("Computing text embeddings for labels...")
        var labelEmbeddings: [(String, MLShapedArray<Float32>)] = []
        for (index, label) in labels.enumerated() {
            let prompt = "\(config.promptTemplate) \(label)"
            let embedding = try textEncoder.computeTextEmbedding(prompt: prompt)
            labelEmbeddings.append((label, embedding))
            
            if (index + 1) % 20 == 0 {
                print("Computed embeddings for \(index + 1)/\(labels.count) labels")
            }
        }
        
        return labelEmbeddings
    }
    
    /// Load precomputed embeddings from JSON file
    func loadPrecomputedEmbeddings(resourceBundle: URL) throws -> [(String, MLShapedArray<Float32>)] {
        let embeddingsURL = resourceBundle.appendingPathComponent("CLIP/precomputed_embeddings.json")
        
        guard FileManager.default.fileExists(atPath: embeddingsURL.path) else {
            throw ClassificationError.precomputedEmbeddingsNotFound(embeddingsURL.path)
        }
        
        return try PrecomputedEmbeddingsManager.loadEmbeddings(from: embeddingsURL)
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

// MARK: - Command Line Interface

struct CommandLineInterface {
    static func parseArguments() throws -> ClassifierConfig {
        let arguments = CommandLine.arguments
        
        // Default configuration
        var mode = ClassificationMode.runtime
        var promptTemplate = "a photo of a"
        
        // Parse arguments
        var i = 1 // Skip program name
        while i < arguments.count {
            let arg = arguments[i]
            
            switch arg {
            case "--mode", "-m":
                guard i + 1 < arguments.count else {
                    throw ClassificationError.missingArgument("mode")
                }
                let modeString = arguments[i + 1]
                guard let parsedMode = ClassificationMode(rawValue: modeString) else {
                    throw ClassificationError.invalidMode(modeString)
                }
                mode = parsedMode
                i += 2
                
            case "--prompt", "-p":
                guard i + 1 < arguments.count else {
                    throw ClassificationError.missingArgument("prompt template")
                }
                promptTemplate = arguments[i + 1]
                i += 2
                
            case "--help", "-h":
                printUsage()
                exit(0)
                
            case "--generate-embeddings":
                // Special mode to generate precomputed embeddings
                return ClassifierConfig(mode: .runtime, promptTemplate: "GENERATE_EMBEDDINGS")
                
            default:
                print("Unknown argument: \(arg)")
                printUsage()
                exit(1)
            }
        }
        
        return ClassifierConfig(mode: mode, promptTemplate: promptTemplate)
    }
    
    static func printUsage() {
        let usage = """
        Swift CLIP Image Classifier
        
        USAGE:
            swift run [OPTIONS]
        
        OPTIONS:
            -m, --mode <MODE>           Classification mode (default: runtime)
                                        runtime:     Compute embeddings at runtime (requires TextEncoder)
                                        precomputed: Use pre-saved embeddings (faster, TextEncoder not needed)
            
            -p, --prompt <TEMPLATE>     Prompt template for text embeddings (default: "a photo of a")
            
            --generate-embeddings       Generate precomputed embeddings file and exit
            
            -h, --help                  Show this help message
        
        EXAMPLES:
            swift run                                    # Use runtime mode with default prompt
            swift run --mode precomputed                 # Use precomputed embeddings
            swift run --mode runtime --prompt "an image of a"  # Custom prompt template
            swift run --generate-embeddings             # Generate precomputed embeddings file
        
        MODES:
            runtime:     Loads TextEncoder model and computes text embeddings for each label at startup.
                        Requires both ImageEncoder and TextEncoder models (~400MB total).
                        
            precomputed: Loads pre-computed text embeddings from JSON file.
                        Only requires ImageEncoder model (~200MB) - ideal for mobile deployment.
                        You must first generate embeddings using --generate-embeddings.
        """
        print(usage)
    }
}

// MARK: - Main Entry Point

Task {
    do {
        let config = try CommandLineInterface.parseArguments()
        
        // Special case: generate embeddings
        if config.promptTemplate == "GENERATE_EMBEDDINGS" {
            await generatePrecomputedEmbeddings()
            exit(0)
        }
        
        // Normal classification
        let classifier = ImageClassifier(config: config)
        await classifier.classifyImages()
        exit(0)
        
    } catch {
        print("Error: \(error)")
        print("\nUse --help for usage information.")
        exit(1)
    }
}

/// Generate precomputed embeddings file
func generatePrecomputedEmbeddings() async {
    do {
        print("Generating precomputed embeddings...")
        
        guard let resourceBundle = Bundle.module.resourceURL else {
            print("Error: Could not find resource bundle")
            return
        }
        
        // Load labels
        let labelsURL = resourceBundle.appendingPathComponent("labels.txt")
        let labelsContent = try String(contentsOf: labelsURL)
        let labels = labelsContent.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Initialize text encoder
        let modelsURL = resourceBundle.appendingPathComponent("models")
        let textEncoder = try TextEncoder(resourcesAt: modelsURL)
        
        // Output path
        let outputURL = resourceBundle.appendingPathComponent("CLIP/precomputed_embeddings.json")
        
        // Generate embeddings
        try await PrecomputedEmbeddingsManager.generateEmbeddings(
            labels: labels,
            textEncoder: textEncoder,
            promptTemplate: "a photo of a",
            outputURL: outputURL
        )
        
        print("\n✅ Precomputed embeddings generated successfully!")
        print("You can now use '--mode precomputed' for faster classification without the TextEncoder model.")
        
    } catch {
        print("Error generating embeddings: \(error)")
    }
}

RunLoop.main.run()