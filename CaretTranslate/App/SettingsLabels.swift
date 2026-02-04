import Foundation

extension ShortcutMode {
    var label: String {
        switch self {
        case .doubleTap:
            return "Double-tap Tab"
        case .hotkey:
            return "Custom Hotkey"
        }
    }
}

/// Languages supported by the application (Apple Translation + NLLB).
enum SupportedLanguages {
    /// Apple Translation languages (fastest, on-device).
    static let appleLanguages: [LanguageOption] = [
        LanguageOption(code: "ar", name: "Arabic"),
        LanguageOption(code: "zh-Hans", name: "Chinese (Simplified)"),
        LanguageOption(code: "zh-Hant", name: "Chinese (Traditional)"),
        LanguageOption(code: "nl", name: "Dutch"),
        LanguageOption(code: "en", name: "English"),
        LanguageOption(code: "fr", name: "French"),
        LanguageOption(code: "de", name: "German"),
        LanguageOption(code: "hi", name: "Hindi"),
        LanguageOption(code: "id", name: "Indonesian"),
        LanguageOption(code: "it", name: "Italian"),
        LanguageOption(code: "ja", name: "Japanese"),
        LanguageOption(code: "ko", name: "Korean"),
        LanguageOption(code: "pl", name: "Polish"),
        LanguageOption(code: "pt", name: "Portuguese"),
        LanguageOption(code: "ru", name: "Russian"),
        LanguageOption(code: "es", name: "Spanish"),
        LanguageOption(code: "th", name: "Thai"),
        LanguageOption(code: "tr", name: "Turkish"),
        LanguageOption(code: "uk", name: "Ukrainian"),
        LanguageOption(code: "vi", name: "Vietnamese"),
    ]

    /// Extended languages via NLLB (requires model download).
    static let nllbLanguages: [LanguageOption] = [
        // Scandinavian
        LanguageOption(code: "sv", name: "Swedish"),
        LanguageOption(code: "no", name: "Norwegian"),
        LanguageOption(code: "da", name: "Danish"),
        LanguageOption(code: "fi", name: "Finnish"),
        LanguageOption(code: "is", name: "Icelandic"),
        // Eastern European
        LanguageOption(code: "cs", name: "Czech"),
        LanguageOption(code: "hu", name: "Hungarian"),
        LanguageOption(code: "ro", name: "Romanian"),
        LanguageOption(code: "bg", name: "Bulgarian"),
        LanguageOption(code: "el", name: "Greek"),
        LanguageOption(code: "sr", name: "Serbian"),
        LanguageOption(code: "hr", name: "Croatian"),
        LanguageOption(code: "sk", name: "Slovak"),
        LanguageOption(code: "sl", name: "Slovenian"),
        // Other European
        LanguageOption(code: "he", name: "Hebrew"),
        LanguageOption(code: "ca", name: "Catalan"),
        LanguageOption(code: "lv", name: "Latvian"),
        LanguageOption(code: "lt", name: "Lithuanian"),
        LanguageOption(code: "et", name: "Estonian"),
        LanguageOption(code: "af", name: "Afrikaans"),
        LanguageOption(code: "sq", name: "Albanian"),
        LanguageOption(code: "hy", name: "Armenian"),
        LanguageOption(code: "az", name: "Azerbaijani"),
        LanguageOption(code: "eu", name: "Basque"),
        LanguageOption(code: "be", name: "Belarusian"),
        LanguageOption(code: "bs", name: "Bosnian"),
        LanguageOption(code: "cy", name: "Welsh"),
        LanguageOption(code: "gl", name: "Galician"),
        LanguageOption(code: "ka", name: "Georgian"),
        LanguageOption(code: "mk", name: "Macedonian"),
        // South Asian
        LanguageOption(code: "bn", name: "Bengali"),
        LanguageOption(code: "ta", name: "Tamil"),
        LanguageOption(code: "gu", name: "Gujarati"),
        LanguageOption(code: "kn", name: "Kannada"),
        LanguageOption(code: "ml", name: "Malayalam"),
        LanguageOption(code: "mr", name: "Marathi"),
        LanguageOption(code: "ne", name: "Nepali"),
        LanguageOption(code: "pa", name: "Punjabi"),
        LanguageOption(code: "si", name: "Sinhala"),
        LanguageOption(code: "te", name: "Telugu"),
        LanguageOption(code: "ur", name: "Urdu"),
        // Southeast Asian
        LanguageOption(code: "tl", name: "Tagalog"),
        LanguageOption(code: "ms", name: "Malay"),
        LanguageOption(code: "my", name: "Burmese"),
        LanguageOption(code: "km", name: "Khmer"),
        LanguageOption(code: "lo", name: "Lao"),
        // Central Asian
        LanguageOption(code: "kk", name: "Kazakh"),
        LanguageOption(code: "mn", name: "Mongolian"),
        LanguageOption(code: "uz", name: "Uzbek"),
        // Middle Eastern
        LanguageOption(code: "fa", name: "Persian"),
        // African
        LanguageOption(code: "sw", name: "Swahili"),
        LanguageOption(code: "am", name: "Amharic"),
        LanguageOption(code: "yo", name: "Yoruba"),
        LanguageOption(code: "ha", name: "Hausa"),
        LanguageOption(code: "so", name: "Somali"),
        LanguageOption(code: "zu", name: "Zulu"),
    ]

    /// All supported languages combined.
    static let all: [LanguageOption] = {
        var languages = [LanguageOption.auto]
        languages.append(contentsOf: appleLanguages.sorted())
        languages.append(contentsOf: nllbLanguages.sorted())
        return languages
    }()
}