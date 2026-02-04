public extension TextGenerationPipeline {
    enum Model: String, CaseIterable {
        // MARK: - Llama

        case llama_3_2_1B_Instruct_4bit = "finnvoorhees/coreml-Llama-3.2-1B-Instruct-4bit"
        case llama_3_2_3B_Instruct_4bit = "finnvoorhees/coreml-Llama-3.2-3B-Instruct-4bit"

        // MARK: - Qwen

        case qwen2_5_0_5B_Instruct_4bit = "finnvoorhees/coreml-Qwen2.5-0.5B-Instruct-4bit"
        case qwen2_5_3B_Instruct_4bit = "finnvoorhees/coreml-Qwen2.5-3B-Instruct-4bit"
        case qwen2_5_Coder_0_5B_Instruct_4bit = "finnvoorhees/coreml-Qwen2.5-Coder-0.5B-Instruct-4bit"
        case qwen2_5_Coder_1_5B_Instruct_4bit = "finnvoorhees/coreml-Qwen2.5-Coder-1.5B-Instruct-4bit"

        // MARK: - SmolLM2

        case smolLM2_135M_Instruct_4bit = "finnvoorhees/coreml-SmolLM2-135M-Instruct-4bit"
        case smolLM2_135M_Instruct_8bit = "finnvoorhees/coreml-SmolLM2-135M-Instruct-8bit"
        case smolLM2_1_7B_Instruct_4bit = "finnvoorhees/coreml-SmolLM2-1.7B-Instruct-4bit"
        case smolLM2_360M_Instruct_4bit = "finnvoorhees/coreml-SmolLM2-360M-Instruct-4bit"
        case smolLM2_360M_Instruct_8bit = "finnvoorhees/coreml-SmolLM2-360M-Instruct-8bit"
        case smolLM2_1_7B_Instruct_8bit = "finnvoorhees/coreml-SmolLM2-1.7B-Instruct-8bit"

        // MARK: - DeepSeek R1

        case deepSeek_R1_Distill_Qwen_1_5B_4bit = "finnvoorhees/coreml-DeepSeek-R1-Distill-Qwen-1.5B-4bit"
    }
}
