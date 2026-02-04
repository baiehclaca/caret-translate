# coremlpipelinestools

```
uv run CausalLM.py
```

```
usage: CausalLM.py [-h] [--model MODEL] [--quantize] [--half] [--compile] [--context-size CONTEXT_SIZE] [--batch-size BATCH_SIZE] [--upload]

Convert a Causal LM to Core ML model

options:
  -h, --help            show this help message and exit
  --model MODEL         Model ID
  --quantize            Linear quantize model
  --half                Load model as float16
  --compile             Save the model as a .mlmodelc
  --context-size CONTEXT_SIZE
                        Context size
  --batch-size BATCH_SIZE
                        Batch size
  --upload              Upload the model to Hugging Face
```