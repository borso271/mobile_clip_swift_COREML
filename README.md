# Swift CLIP Image Classifier

A Swift command-line tool that uses CLIP (Contrastive Language-Image Pre-training) models to classify images against a predefined set of labels. This project leverages MobileCLIP models for efficient on-device inference on macOS.

> **Note**: This project builds upon the excellent work from [Queryable](https://github.com/mazzzystar/Queryable) by mazzzystar, adapting the CLIP implementation for command-line usage.

## Features

- **Zero-shot image classification** using CLIP embeddings
- **Cross-platform support** (iOS and macOS with conditional compilation)
- **Pre-computed text embeddings** for fast inference
- **Batch processing** of multiple images
- **Cosine similarity matching** between image and text embeddings
- **Terminal-based output** with similarity scores

## Requirements

- **macOS 13.0+** (due to Core ML and URL path APIs)
- **Swift 5.7+** 
- **Xcode 14.0+** (for development)
- Or **Swiftly** for command-line Swift development

## Project Structure

```
Sources/
├── main.swift                          # Main entry point and classification logic
├── labels.txt                          # List of classification labels (97 categories)
├── images/                             # Input images to classify (.jpeg, .jpg, .png)
│   ├── 1753438310777.jpeg
│   ├── 1753438328054.jpeg
│   └── ...
├── models/                             # Pre-trained CLIP models
│   ├── ImageEncoder_mobileCLIP_s2.mlmodelc/     # Image encoder model
│   ├── TextEncoder_mobileCLIP_s2.mlmodelc/      # Text encoder model
│   ├── vocab.json                      # BPE tokenizer vocabulary
│   └── merges.txt                      # BPE tokenizer merge rules
└── CLIP/                               # CLIP implementation components
    ├── ImgEncoder.swift                # Image encoding logic
    ├── TextEncoder.swift               # Text encoding logic
    ├── UIImage+Extensions.swift        # Image processing utilities
    ├── UIDevice+Extensions.swift       # iOS device compatibility
    └── Tokenizer/                      # BPE tokenization
        ├── BPETokenizer.swift
        ├── BPETokenizer+Reading.swift
        └── Embedding.swift
```

## Installation & Setup

1. **Clone or download** the project to your local machine

2. **Download the required models**: The MobileCLIP models are not included in the repository due to their size. Download them from mazzzystar's Google Drive:
   
   **📥 [Download Models Here](https://drive.google.com/drive/folders/12ze3UcqrXt9qeySGh_j_zWE-PWRDTzJv)**
   
   Place the following files in the `Sources/models/` directory:
   - `ImageEncoder_mobileCLIP_s2.mlmodelc/` (complete folder)
   - `TextEncoder_mobileCLIP_s2.mlmodelc/` (complete folder)
   - `vocab.json`
   - `merges.txt`

3. **Add your images**: Place images to classify in the `Sources/images/` directory (supports JPEG and PNG formats)

4. **Customize labels** (optional): Edit `Sources/labels.txt` to modify the classification categories

## Usage

The classifier supports two modes for optimal performance across different deployment scenarios:

### 📊 Classification Modes

#### 1. **Runtime Mode** (Default)
Computes text embeddings on-demand using the TextEncoder model at startup.
- **Best for**: Development, experimentation, custom prompts
- **Memory**: ~400MB (both ImageEncoder + TextEncoder models)
- **Startup**: Slower (computes embeddings for 97 labels)

#### 2. **Precomputed Mode** 
Uses pre-saved text embeddings from JSON file, avoiding TextEncoder model loading.
- **Best for**: Production, mobile deployment, faster startup
- **Memory**: ~200MB (ImageEncoder model only) 
- **Startup**: Faster (loads embeddings from JSON)

### 🚀 Quick Start

```bash
# Navigate to project directory
cd swift_tests_clip

# Build the project
swift build

# Run with default settings (runtime mode)
swift run

# Or specify mode explicitly
swift run swift_tests_clip --mode runtime
swift run swift_tests_clip --mode precomputed
```

### 📋 Command Line Options

```bash
# Show help
swift run swift_tests_clip --help

# Generate precomputed embeddings (run this first for precomputed mode)
swift run swift_tests_clip --generate-embeddings

# Use precomputed mode (faster, less memory)
swift run swift_tests_clip --mode precomputed

# Custom prompt template
swift run swift_tests_clip --prompt "an image of a"

# Runtime mode with custom prompt
swift run swift_tests_clip --mode runtime --prompt "a picture of a"
```

### 🔧 Setting Up Precomputed Mode

To use the faster precomputed mode:

1. **Generate embeddings** (one-time setup):
   ```bash
   swift run swift_tests_clip --generate-embeddings
   ```

2. **Use precomputed mode**:
   ```bash
   swift run swift_tests_clip --mode precomputed
   ```

The precomputed embeddings file (`precomputed_embeddings.json`) will be saved in the project and can be used for faster classification without loading the TextEncoder model.

### Sample Output

#### Runtime Mode
```
Starting image classification...
Mode: Runtime mode: Computes text embeddings on-demand using TextEncoder model
Loaded 97 labels
Computing text embeddings for labels...
Computed embeddings for 20/97 labels
Computed embeddings for 40/97 labels
Computed embeddings for 60/97 labels
Computed embeddings for 80/97 labels
Processing 5 images...
1753438310777.jpeg: rosemary (similarity: 0.333)
1753438392407.jpeg: oven mitt (similarity: 0.296)
1753438341684.jpeg: bottle opener (similarity: 0.316)
1753438328054.jpeg: high chair (similarity: 0.301)
1753438408699.jpeg: coffee machine (similarity: 0.263)
```

#### Precomputed Mode
```
Starting image classification...
Mode: Precomputed mode: Uses pre-saved text embeddings from JSON file
Loading precomputed embeddings from: precomputed_embeddings.json
✅ Loaded precomputed embeddings:
   - Version: 1.0
   - Model: MobileCLIP-S2
   - Prompt template: "a photo of a"
   - Labels: 97
   - Embedding dimension: 512
   - Created: 2025-08-13T14:23:34Z
Processing 5 images...
1753438310777.jpeg: rosemary (similarity: 0.333)
1753438392407.jpeg: oven mitt (similarity: 0.296)
1753438341684.jpeg: bottle opener (similarity: 0.316)
1753438328054.jpeg: high chair (similarity: 0.301)
1753438408699.jpeg: coffee machine (similarity: 0.263)
```

## How It Works

### Runtime Mode Workflow
1. **Label Processing**: Loads classification labels from `labels.txt`
2. **Model Loading**: Loads both ImageEncoder and TextEncoder models
3. **Text Embedding**: Computes CLIP text embeddings for each label using TextEncoder
4. **Image Processing**: Loads and processes images from the `images/` directory
5. **Image Embedding**: Generates CLIP image embeddings using ImageEncoder
6. **Classification**: Computes cosine similarity between image and text embeddings
7. **Results**: Outputs the best matching label with similarity score for each image

### Precomputed Mode Workflow  
1. **Precomputed Loading**: Loads pre-saved text embeddings from JSON file
2. **Model Loading**: Loads only ImageEncoder model (50% memory reduction)
3. **Image Processing**: Loads and processes images from the `images/` directory  
4. **Image Embedding**: Generates CLIP image embeddings using ImageEncoder
5. **Classification**: Computes cosine similarity between image and precomputed text embeddings
6. **Results**: Outputs the best matching label with similarity score for each image

## 📱 Mobile Deployment Benefits

The **precomputed mode** is specifically designed for mobile and production deployment scenarios:

### Memory Optimization
- **50% reduction**: ~200MB vs ~400MB (ImageEncoder only vs both models)
- **Faster app launch**: No need to load and initialize TextEncoder model
- **Battery efficient**: Reduced computational overhead during startup

### Performance Benefits  
- **Instant startup**: Text embeddings loaded from JSON (milliseconds vs seconds)
- **Consistent results**: Identical classification accuracy as runtime mode
- **Offline ready**: No dependency on TextEncoder model after embeddings generation

### Mobile Integration
For iOS/macOS app integration:
```swift
// Only load ImageEncoder in precomputed mode
let imageEncoder = try ImgEncoder(resourcesAt: modelsURL)
let labelEmbeddings = try PrecomputedEmbeddingsManager.loadEmbeddings(from: embeddingsURL)
// TextEncoder not needed - saves ~200MB memory
```

## Model Architecture

This project uses **MobileCLIP-S2** models optimized for mobile/edge deployment:

- **Image Encoder**: Processes 256×256 RGB images → 512-dimensional embeddings
- **Text Encoder**: Processes tokenized text → 512-dimensional embeddings
- **Tokenizer**: BPE (Byte-Pair Encoding) tokenization compatible with CLIP
- **Similarity**: Cosine similarity between normalized embeddings

## Customization

### Adding New Labels

Edit `Sources/labels.txt` and add one label per line:

```
your_new_label_1
your_new_label_2
custom_category
```

### Changing Images

Simply add/remove images in the `Sources/images/` directory. Supported formats:
- JPEG (.jpeg, .jpg)
- PNG (.png)

### Modifying Prompt Template

In `main.swift`, change the prompt template:

```swift
let embedding = try textEncoder.computeTextEmbedding(prompt: "a photo of a \(label)")
```

To:

```swift
let embedding = try textEncoder.computeTextEmbedding(prompt: "an image showing \(label)")
```

## Technical Details

### Platform Compatibility

- **macOS**: Full support with NSImage and Core ML
- **iOS**: Conditional compilation support (requires UIKit)
- **Cross-platform**: Uses `#if os()` directives for platform-specific code

### Performance Considerations

- Text embeddings are pre-computed once for all labels
- Image processing happens sequentially
- Models run on device (no network required)
- Memory usage scales with number of images processed

### Dependencies

- **Foundation**: Core Swift functionality
- **Core ML**: On-device model inference
- **Core Video**: Image buffer processing
- **AppKit/UIKit**: Image handling (platform-dependent)

## Troubleshooting

### Common Issues

**Build Errors**: Ensure you're using macOS 13.0+ and Swift 5.7+

**Model Loading Errors**: Verify model files exist in `Sources/models/`

**Image Size Errors**: The model requires exactly 256×256 pixel images (handled automatically)

**No Output**: Check that images exist in `Sources/images/` directory

### Debug Tips

- Enable verbose output by adding print statements in the classification loop
- Check image file formats are supported
- Verify labels.txt is properly formatted (one label per line)

## License

This project contains CLIP model implementations and may be subject to various licenses. Check individual model and component licenses before commercial use.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly on macOS
5. Submit a pull request

## Acknowledgments

- **[mazzzystar](https://github.com/mazzzystar)**: Creator of [Queryable](https://github.com/mazzzystar/Queryable), whose CLIP implementation and MobileCLIP models form the foundation of this project
- **OpenAI CLIP**: Original CLIP research and methodology  
- **MobileCLIP**: Efficient mobile-optimized CLIP models
- **Apple Core ML**: On-device machine learning framework

## Model Credits

The MobileCLIP models used in this project are provided by mazzzystar through the Queryable project:
- **Models Source**: [Google Drive](https://drive.google.com/drive/folders/12ze3UcqrXt9qeySGh_j_zWE-PWRDTzJv)
- **Original Project**: [Queryable - AI-powered photo search for macOS](https://github.com/mazzzystar/Queryable)