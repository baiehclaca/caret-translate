#if defined(CT2_HELPER_STANDALONE)

#import <Foundation/Foundation.h>
#include <algorithm>
#include <chrono>
#include <cctype>
#include <future>
#include <iostream>
#include <unordered_map>
#include <vector>
#include <ctranslate2/translator.h>
#include <sentencepiece_processor.h>

namespace {

struct HelperConfig {
    std::string model_path;
    std::string tokenizer_path;
    int max_decoding_length = 256;
    int beam_size = 1;
    int timeout_ms = 30000;
};

/// Reads an environment variable into a std::string.
std::string read_env(const char* key) {
    const char* value = std::getenv(key);
    if (value == nullptr) {
        return "";
    }
    return std::string(value);
}

/// Returns true if a path exists and is readable.
bool is_readable_path(NSString *path, bool require_directory) {
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    if (![manager fileExistsAtPath:path isDirectory:&isDirectory]) {
        return false;
    }
    if (require_directory && !isDirectory) {
        return false;
    }
    if (access([path fileSystemRepresentation], R_OK) != 0) {
        return false;
    }
    return true;
}

/// Resolves the default model path.
std::string resolve_default_model_path() {
    NSString *base = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/CaretTranslate/models/nllb-200-distilled-600M-ct2-int8"];
    return std::string([base fileSystemRepresentation]);
}

/// Finds the sentencepiece model file under the model directory.
std::string resolve_tokenizer_path(const std::string& model_path) {
    NSString *modelDir = [NSString stringWithUTF8String:model_path.c_str()];
    NSArray<NSString *> *candidates = @[
        @"sentencepiece.bpe.model",
        @"sentencepiece.model",
        @"spm.model"
    ];
    for (NSString *candidate in candidates) {
        NSString *fullPath = [modelDir stringByAppendingPathComponent:candidate];
        if (is_readable_path(fullPath, false)) {
            return std::string([fullPath fileSystemRepresentation]);
        }
    }
    return "";
}

/// Builds the helper configuration from environment variables and defaults.
HelperConfig load_config() {
    HelperConfig config;
    config.model_path = read_env("NLLB_MODEL_PATH");
    if (config.model_path.empty()) {
        config.model_path = resolve_default_model_path();
    }

    std::string timeout_override = read_env("NLLB_REQUEST_TIMEOUT_MS");
    if (!timeout_override.empty()) {
        config.timeout_ms = std::max(1000, std::atoi(timeout_override.c_str()));
    }

    std::string max_len_override = read_env("NLLB_MAX_DECODING_LENGTH");
    if (!max_len_override.empty()) {
        config.max_decoding_length = std::max(8, std::atoi(max_len_override.c_str()));
    }

    return config;
}

/// Writes a JSON response to stdout.
void write_response(NSDictionary *payload) {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];
    if (data == nil) {
        NSString *fallback = [NSString stringWithFormat:@"{\"error\":\"JSON serialization failed: %@\"}\n", error.localizedDescription];
        fwrite(fallback.UTF8String, 1, fallback.lengthOfBytesUsingEncoding:NSUTF8StringEncoding, stdout);
        fflush(stdout);
        return;
    }
    fwrite(data.bytes, 1, data.length, stdout);
    fwrite("\n", 1, 1, stdout);
    fflush(stdout);
}

/// Emits a structured error response.
void write_error(NSString *message, NSString *code) {
    write_response(@{ @"error": message ?: @"Unknown error", @"code": code ?: @"unknown" });
}

/// Resolves an NLLB code for an ISO language string.
std::string resolve_lang_code(const std::string& code) {
    static const std::unordered_map<std::string, std::string> mapping = {
        {"sv", "swe_Latn"}, {"no", "nob_Latn"}, {"da", "dan_Latn"},
        {"fi", "fin_Latn"}, {"is", "isl_Latn"},
        {"cs", "ces_Latn"}, {"hu", "hun_Latn"}, {"ro", "ron_Latn"},
        {"bg", "bul_Cyrl"}, {"el", "ell_Grek"}, {"sr", "srp_Cyrl"},
        {"hr", "hrv_Latn"}, {"sk", "slk_Latn"},
        {"he", "heb_Hebr"}, {"ca", "cat_Latn"}, {"lv", "lvs_Latn"},
        {"lt", "lit_Latn"}, {"et", "est_Latn"},
        {"bn", "ben_Beng"}, {"ta", "tam_Taml"}, {"tl", "tgl_Latn"}, {"fil", "tgl_Latn"},
        {"ms", "zsm_Latn"}, {"my", "mya_Mymr"},
        {"sw", "swh_Latn"}, {"am", "amh_Ethi"}, {"yo", "yor_Latn"},
        {"fa", "pes_Arab"}, {"ur", "urd_Arab"},
        {"af", "afr_Latn"}, {"sq", "als_Latn"}, {"hy", "hye_Armn"},
        {"az", "azj_Latn"}, {"eu", "eus_Latn"}, {"be", "bel_Cyrl"},
        {"bs", "bos_Latn"}, {"cy", "cym_Latn"}, {"eo", "epo_Latn"},
        {"gl", "glg_Latn"}, {"ka", "kat_Geor"}, {"gu", "guj_Gujr"},
        {"ha", "hau_Latn"}, {"kn", "kan_Knda"}, {"kk", "kaz_Cyrl"},
        {"km", "khm_Khmr"}, {"lo", "lao_Laoo"}, {"mk", "mkd_Cyrl"},
        {"ml", "mal_Mlym"}, {"mr", "mar_Deva"}, {"mn", "khk_Cyrl"},
        {"ne", "npi_Deva"}, {"pa", "pan_Guru"}, {"si", "sin_Sinh"},
        {"sl", "slv_Latn"}, {"so", "som_Latn"}, {"te", "tel_Telu"},
        {"uz", "uzn_Latn"}, {"zu", "zul_Latn"},
        {"ar", "arb_Arab"}, {"zh-hans", "zho_Hans"}, {"zh-hant", "zho_Hant"},
        {"nl", "nld_Latn"}, {"en", "eng_Latn"}, {"fr", "fra_Latn"},
        {"de", "deu_Latn"}, {"hi", "hin_Deva"}, {"id", "ind_Latn"},
        {"it", "ita_Latn"}, {"ja", "jpn_Jpan"}, {"ko", "kor_Hang"},
        {"pl", "pol_Latn"}, {"pt", "por_Latn"}, {"ru", "rus_Cyrl"},
        {"es", "spa_Latn"}, {"th", "tha_Thai"}, {"tr", "tur_Latn"},
        {"uk", "ukr_Cyrl"}, {"vi", "vie_Latn"}
    };

    std::string lower;
    lower.reserve(code.size());
    for (char c : code) {
        lower.push_back(static_cast<char>(std::tolower(static_cast<unsigned char>(c))));
    }

    auto it = mapping.find(lower);
    if (it != mapping.end()) {
        return it->second;
    }
    return code;
}

/// Loads the sentencepiece model with explicit error handling.
bool load_sentencepiece(sentencepiece::SentencePieceProcessor& processor, const std::string& path, NSString **errorMessage) {
    auto status = processor.Load(path);
    if (!status.ok()) {
        if (errorMessage) {
            *errorMessage = [NSString stringWithFormat:@"SentencePiece load failed: %s", status.ToString().c_str()];
        }
        return false;
    }
    return true;
}

/// Encodes text into sentencepiece tokens with language prefix and EOS.
std::vector<std::string> encode_with_language(sentencepiece::SentencePieceProcessor& processor,
                                              const std::string& text,
                                              const std::string& src_lang) {
    std::vector<std::string> pieces;
    processor.Encode(text, &pieces);
    std::vector<std::string> tokens;
    tokens.reserve(pieces.size() + 2);
    tokens.push_back(src_lang);
    tokens.insert(tokens.end(), pieces.begin(), pieces.end());
    tokens.push_back("</s>");
    return tokens;
}

/// Decodes tokens to text, filtering special tokens.
std::string decode_tokens(sentencepiece::SentencePieceProcessor& processor,
                          std::vector<std::string> tokens,
                          const std::string& tgt_lang) {
    if (!tokens.empty() && tokens.front() == tgt_lang) {
        tokens.erase(tokens.begin());
    }
    tokens.erase(std::remove(tokens.begin(), tokens.end(), "</s>"), tokens.end());
    tokens.erase(std::remove(tokens.begin(), tokens.end(), "<s>"), tokens.end());
    std::string output;
    processor.Decode(tokens, &output);
    return output;
}

} // namespace

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        HelperConfig config = load_config();

        NSString *modelPath = [NSString stringWithUTF8String:config.model_path.c_str()];
        if (!is_readable_path(modelPath, true)) {
            write_error([NSString stringWithFormat:@"Model directory not accessible: %@", modelPath], @"model_not_found");
            return 1;
        }

        config.tokenizer_path = resolve_tokenizer_path(config.model_path);
        if (config.tokenizer_path.empty()) {
            write_error(@"Tokenizer model not found in model directory.", @"tokenizer_missing");
            return 1;
        }

        sentencepiece::SentencePieceProcessor tokenizer;
        NSString *tokenizerError = nil;
        if (!load_sentencepiece(tokenizer, config.tokenizer_path, &tokenizerError)) {
            write_error(tokenizerError, @"tokenizer_load_failed");
            return 1;
        }

        ctranslate2::Translator translator(config.model_path, ctranslate2::Device::CPU);

        write_response(@{ @"status": @"ready" });

        std::string lineBuffer;
        while (std::getline(std::cin, lineBuffer)) {
            @autoreleasepool {
                if (lineBuffer.empty()) {
                    continue;
                }
                NSString *line = [NSString stringWithUTF8String:lineBuffer.c_str()];

                NSError *jsonError = nil;
                NSData *trimmed = [line dataUsingEncoding:NSUTF8StringEncoding];
                id object = [NSJSONSerialization JSONObjectWithData:trimmed options:0 error:&jsonError];
                if (!object || ![object isKindOfClass:[NSDictionary class]]) {
                    write_error([NSString stringWithFormat:@"Invalid JSON: %@", jsonError.localizedDescription ?: @"unknown"], @"invalid_json");
                    continue;
                }

                NSDictionary *request = (NSDictionary *)object;
                NSString *text = request[@"text"];
                NSString *source = request[@"source"];
                NSString *target = request[@"target"];

                if (![text isKindOfClass:[NSString class]] || text.length == 0) {
                    write_error(@"Empty text", @"empty_text");
                    continue;
                }
                if (![source isKindOfClass:[NSString class]] || ![target isKindOfClass:[NSString class]]) {
                    write_error(@"Missing source or target language", @"missing_language");
                    continue;
                }

                std::string src_lang = resolve_lang_code(std::string([source UTF8String]));
                std::string tgt_lang = resolve_lang_code(std::string([target UTF8String]));
                std::string input_text = std::string([text UTF8String]);

                auto tokens = encode_with_language(tokenizer, input_text, src_lang);
                std::vector<std::vector<std::string>> batch = { tokens };
                std::vector<std::vector<std::string>> prefixes = { { tgt_lang } };

                ctranslate2::TranslationOptions options;
                options.beam_size = config.beam_size;
                options.max_decoding_length = config.max_decoding_length;

                std::vector<ctranslate2::TranslationResult> results;
                auto future = std::async(std::launch::async, [&]() {
                    return translator.translate_batch(batch, prefixes, options);
                });

                if (future.wait_for(std::chrono::milliseconds(config.timeout_ms)) != std::future_status::ready) {
                    write_error(@"Translation timed out", @"timeout");
                    continue;
                }

                results = future.get();
                if (results.empty() || results[0].hypotheses.empty()) {
                    write_error(@"Empty translation result", @"empty_result");
                    continue;
                }

                std::vector<std::string> output_tokens = results[0].hypotheses[0];
                std::string translation = decode_tokens(tokenizer, output_tokens, tgt_lang);

                write_response(@{ @"translation": [NSString stringWithUTF8String:translation.c_str()] });
            }
        }
    }
    return 0;
}

#endif
