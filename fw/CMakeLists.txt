cmake_minimum_required(VERSION 3.13)

# SDKの場所（環境変数が無ければ repo内の external を見る）
if (NOT DEFINED ENV{PICO_SDK_PATH})
  set(ENV{PICO_SDK_PATH} "${CMAKE_CURRENT_LIST_DIR}/../external/pico-sdk")
endif()

include($ENV{PICO_SDK_PATH}/external/pico_sdk_import.cmake)

project(optical_modem_fw C CXX ASM)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

add_subdirectory(apps/blink)
add_subdirectory(apps/loopback)
