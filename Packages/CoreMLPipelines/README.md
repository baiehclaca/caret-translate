# CoreMLPipelines
<p align="leading">
    <img src="https://img.shields.io/badge/macOS-15.0-blue" />
    <img src="https://img.shields.io/badge/iOS-18.0-blue" />

CoreMLPipelines is an experimental library for running pretrained [Core ML](https://developer.apple.com/documentation/coreml) models to perform different tasks. Currently, the following pipelines are supported:
- **Text Generation**: Generate text using a pretrained language model.

### Show me the code

```swift
import CoreMLPipelines

let pipeline = try await TextGenerationPipeline(model: .llama_3_2_1B_Instruct_4bit)

let stream = pipeline(
    messages: [[
        "role": "user",
        "content": "Write a poem about Ireland"
    ]]
)

for try await text in stream {
    print(text, terminator: "")
}
```

### CLI

![CLI Demo](https://github.com/user-attachments/assets/4b72fa50-7e47-4171-9d98-791661d25dcc)

#### Generate text
```
USAGE: coremltoolkit-cli generate-text [--model <model>] [<prompt>] [--max-new-tokens <max-new-tokens>]

ARGUMENTS:
  <prompt>                (default: Hello)

OPTIONS:
  --model <model>         Hugging Face repo ID (e.g. 'finnvoorhees/coreml-Llama-3.2-1B-Instruct-4bit') 
  --max-new-tokens <max-new-tokens>
```

#### Chat
```
USAGE: coremltoolkit-cli chat [--model <model>]

OPTIONS:
  --model <model>         Hugging Face repo ID (e.g. 'finnvoorhees/coreml-Llama-3.2-1B-Instruct-4bit')
```
