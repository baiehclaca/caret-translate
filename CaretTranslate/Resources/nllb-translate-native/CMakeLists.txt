cmake_minimum_required(VERSION 3.18)
project(nllb_translate_native LANGUAGES CXX OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(ctranslate2 REQUIRED)
find_package(sentencepiece REQUIRED)

add_executable(translate-ct2 ct2_translate.mm)

target_compile_definitions(translate-ct2 PRIVATE CT2_HELPER_STANDALONE=1)

target_link_libraries(translate-ct2
    PRIVATE
        ctranslate2::ctranslate2
        sentencepiece::sentencepiece
        "-framework Foundation"
)
