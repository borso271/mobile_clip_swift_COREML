//
//  make_embeds.swift
//  Queryable
//
//  Created by Federico Borsotti on 08/08/2025.
//

import Foundation
import CoreML
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// ----- JSON I/O -----
struct LabelsInput: Codable {
    var model: String? = "mobileclip_s2"
    var prompt_template: String? = "a photo of a {}"
    let labels: [String]
}



struct LabelEmbeds: Codable {
    let model: String
    let embed_dim: Int
    let prompt_template: String
    let labels: [String]
    let embeddings: [[Float]]
}

func l2Normalized(_ v: [Float]) -> [Float] {
    var s: Float = 0; for x in v { s += x*x }
    let n = max(1e-12, sqrtf(s))
    return v.map { $0 / n }
}

func buildEmbedsFromLabelsTXT(
    baseURL: URL,
    labels: [String],
    promptTemplate: String = "a photo of a {}",
    modelTag: String = "mobileclip_s2",
    outputURL: URL
) throws -> URL {
    let encoder = try TextEncoder(resourcesAt: baseURL)

    var out: [[Float]] = []
    out.reserveCapacity(labels.count)
    var dim = 0

    for label in labels {
        let prompt = promptTemplate.replacingOccurrences(of: "{}", with: label)
        let shaped = try encoder.computeTextEmbedding(prompt: prompt)
        var vec = shaped.scalars.map { Float($0) }
        vec = l2Normalized(vec)
        if dim == 0 { dim = vec.count }
        out.append(vec)
    }

    let payload = LabelEmbeds(
        model: modelTag,
        embed_dim: dim,
        prompt_template: promptTemplate,
        labels: labels,
        embeddings: out
    )
    let data = try JSONEncoder().encode(payload)
    try data.write(to: outputURL, options: .atomic)
    return outputURL
}


func loadLabelsFromTXT(name: String = "prompts-1") throws -> [String] {
    guard let url = Bundle.main.url(forResource: name, withExtension: "txt") else {
        throw NSError(domain: "Embeds", code: 1,
                      userInfo: [NSLocalizedDescriptionKey:
                                 "Could not find \(name).txt in app bundle. Check Target Membership."])
    }
    let raw = try String(contentsOf: url, encoding: .utf8)
    return raw
        .split(whereSeparator: \.isNewline)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && !$0.hasPrefix("#") } // ignore blanks/comments
}

// Build embeddings using your existing TextEncoder
func buildLabelEmbeddings(baseURL: URL, labelsJSON: URL, outputJSON: URL) throws -> URL {
    // 1) Load input labels + template
    let data = try Data(contentsOf: labelsJSON)
    let input = try JSONDecoder().decode(LabelsInput.self, from: data)
    let tpl = input.prompt_template ?? "{}"

    // 2) Init your TextEncoder (you already have this type)
    let encoder = try TextEncoder(resourcesAt: baseURL)

    var embeddings = [[Float]]()
    embeddings.reserveCapacity(input.labels.count)
    var embedDim: Int = 0

    // 3) Encode each prompt and normalize
    for label in input.labels {
        let prompt = tpl.replacingOccurrences(of: "{}", with: label)
        let shaped = try encoder.computeTextEmbedding(prompt: prompt) // MLShapedArray<Float32>
        let vec = shaped.scalars.map { Float($0) } // flatten
        if embedDim == 0 { embedDim = vec.count }
        embeddings.append(l2Normalized(vec))
    }

    // 4) Write JSON
    let out = LabelEmbeds(
        model: input.model ?? "mobileclip_s2",
        embed_dim: embedDim,
        prompt_template: tpl,
        labels: input.labels,
        embeddings: embeddings
    )
    let outData = try JSONEncoder().encode(out)
    try outData.write(to: outputJSON, options: .atomic)

    return outputJSON
}

// Convenience: where to save + how to share
func exportEmbeddingsFromApp() {
    do {
        // Adjust to wherever you bundled the Core ML text model + vocab/merges
        // e.g. put them in a "MobileCLIPResources" folder in your app bundle.
        let baseURL = Bundle.main.resourceURL! // or .appendingPathComponent("MobileCLIPResources")
        let labelsURL = Bundle.main.url(forResource: "labels", withExtension: "json")! // provide this in your app bundle
        let outURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("labels_embeds.json")

        let finalURL = try buildLabelEmbeddings(baseURL: baseURL, labelsJSON: labelsURL, outputJSON: outURL)
        print("Wrote embeddings → \(finalURL.path)")

#if os(iOS)
        // Optional: share the file to your Mac via AirDrop/Files
        let vc = UIActivityViewController(activityItems: [finalURL], applicationActivities: nil)
        UIApplication.shared.windows.first?.rootViewController?.present(vc, animated: true)
#elseif os(macOS)
        // On macOS, just print the file location
        print("Embeddings saved to: \(finalURL.path)")
#endif

    } catch {
        print("Embedding export failed: \(error)")
    }
}
