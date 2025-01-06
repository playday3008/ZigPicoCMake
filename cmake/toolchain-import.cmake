# => means input
# <= means output
#
# HOST_OS:STRING       => "linux" or "macos" or "windows" or ...
# HOST_ARCH:STRING     => "x86_64" or "aarch64" or ...
# PICO_ARCH:STRING     => "ARM" or "RISC-V"
# PICO_PLATFORM:STRING => "rp2040" or "rp2350-arm-s" or "rp2350-arm-ns"
#
# PICO_TOOLCHAIN_PATH:PATH <= Path to chosen toolchain
# PICO_COMPILER:STRING     <= "pico_arm_gcc" or "pico_arm_clang" // `arm` inside doesn't matter, works for RISC-V too
# PICO_CLIB:STRING         <= "auto" or "llvm_libc" or "newlib" or "picolibc"
#

include(FetchContent)

#[[json
{
  "$schema": "./toolchain-schema.json",
  "<PICO_ARCH>": [
    {
      "libc": "auto", // => <PICO_CLIB>
      "<LLVM or GNU>": [ // => PICO_COMPILER
        {
          "<HOST_OS>": {
            "<HOST_ARCH>": {
              "url": "<URL>", // Download toolchain from URL and => PICO_TOOLCHAIN_PATH
              "hash": {
                "type": "<SHA256>",
                "value": "<HASH>"
              }
            },
            ...
          }
        },
        ...
      ]
    },
    ...
  ],
  ...
}
]]

# Sanity checks
if(NOT DEFINED HOST_OS)
    message(FATAL_ERROR "HOST_OS not defined")
endif()
if(NOT DEFINED HOST_ARCH)
    message(FATAL_ERROR "HOST_ARCH not defined")
endif()
if(NOT DEFINED PICO_ARCH)
    message(FATAL_ERROR "PICO_ARCH not defined")
endif()

# Read toolchain.json
file(READ "${CMAKE_CURRENT_LIST_DIR}/toolchain.json" JSON_TOOLCHAIN)

# Get toolchain for <PICO_ARCH>
string(JSON JSON_PICO_ARCH GET "${JSON_TOOLCHAIN}" "${PICO_ARCH}")

# Get compilers for <PICO_ARCH>
# Iterate over compilers
string(JSON JSON_FAMILY_LENGTH LENGTH "${JSON_PICO_ARCH}")
math(EXPR JSON_FAMILY_LENGTH "${JSON_FAMILY_LENGTH}-1")
foreach(I RANGE ${JSON_FAMILY_LENGTH})
    # Get compiler family
    string(JSON JSON_FAMILY GET "${JSON_PICO_ARCH}" ${I})
    string(JSON JSON_LIBC GET "${JSON_FAMILY}" "libc")

    # Get compiler object
    foreach(J RANGE 0 1)
        string(JSON JSON_COMPILER_NAME MEMBER "${JSON_FAMILY}" ${J})
        string(JSON JSON_COMPILER_TYPE TYPE "${JSON_FAMILY}" "${JSON_COMPILER_NAME}")
        if(JSON_COMPILER_TYPE STREQUAL "OBJECT")
            break()
        endif()
    endforeach()
    string(JSON JSON_COMPILER GET "${JSON_FAMILY}" "${JSON_COMPILER_NAME}")

    # Get OS
    string(JSON JSON_OS ERROR_VARIABLE JSON_OS_ERROR GET "${JSON_COMPILER}" "${HOST_OS}")
    if(NOT JSON_OS_ERROR STREQUAL "NOTFOUND")
        continue()
    endif()

    # Get arch
    string(JSON JSON_ARCH ERROR_VARIABLE JSON_ARCH_ERROR GET "${JSON_OS}" "${HOST_ARCH}")
    if(NOT JSON_ARCH_ERROR STREQUAL "NOTFOUND")
        continue()
    endif()

    # Get URL
    string(JSON JSON_URL GET "${JSON_ARCH}" "url")

    # Get hash
    string(JSON JSON_HASH GET "${JSON_ARCH}" "hash")
    string(JSON JSON_HASH_TYPE GET "${JSON_HASH}" "type")
    string(JSON JSON_HASH_VALUE GET "${JSON_HASH}" "value")

    break()
endforeach()

# Sanity check
if(NOT DEFINED JSON_URL)
    message(FATAL_ERROR "Toolchain for host (${HOST_OS}, ${HOST_ARCH}) not found")
endif()

# Get toolchain URL
set(PICO_TOOLCHAIN_URL "${JSON_URL}")

# Get compiler
# Keep in sync with Pico SDK compiler detection
if(JSON_COMPILER_NAME MATCHES "^LLVM")
    if(PICO_PLATFORM MATCHES "^rp2040")
        if(PICO_ARCH STREQUAL "ARM")
            set(PICO_COMPILER "pico_arm_cortex_m0plus_clang")
        else()
            message(FATAL_ERROR "Unsupported PICO_ARCH")
        endif()
    elseif(PICO_PLATFORM MATCHES "^rp2350")
        if(PICO_ARCH STREQUAL "ARM")
            set(PICO_COMPILER "pico_arm_cortex_m33_clang")
        elseif(PICO_ARCH STREQUAL "RISC-V")
            message(FATAL_ERROR "Pico SDK does not support RISC-V with LLVM")
        else()
            message(FATAL_ERROR "Unknown PICO_ARCH")
        endif()
    else()
        message(FATAL_ERROR "Unsupported PICO_PLATFORM")
    endif()
elseif(JSON_COMPILER_NAME MATCHES "^GNU")
    if(PICO_PLATFORM MATCHES "^rp2040")
        if(PICO_ARCH STREQUAL "ARM")
            set(PICO_COMPILER "pico_arm_cortex_m0plus_gcc")
        else()
            message(FATAL_ERROR "Unsupported PICO_ARCH")
        endif()
    elseif(PICO_PLATFORM MATCHES "^rp2350")
        if(PICO_ARCH STREQUAL "ARM")
            set(PICO_COMPILER "pico_arm_cortex_m33_gcc")
        elseif(PICO_ARCH STREQUAL "RISC-V")
            set(PICO_COMPILER "pico_riscv_gcc") # or pico_riscv_gcc_zcb_zcmp
        else()
            message(FATAL_ERROR "Unknown PICO_ARCH")
        endif()
    else()
        message(FATAL_ERROR "Unsupported PICO_PLATFORM")
    endif()
else()
    message(FATAL_ERROR "Unknown compiler family")
endif()

# Get libc
if(NOT JSON_LIBC STREQUAL "auto")
    set(PICO_CLIB "${JSON_LIBC}")
endif()

# Report
message(STATUS "Toolchain family: ${JSON_COMPILER_NAME}")
message(STATUS "Toolchain URL:    ${PICO_TOOLCHAIN_URL}")
message(STATUS "Toolchain hash:   ${JSON_HASH_TYPE}:${JSON_HASH_VALUE}")
message(STATUS "Toolchain libc:   ${JSON_LIBC}")

# Fetch toolchain
message(STATUS "Downloading toolchain...")
FetchContent_Declare(
    pico_toolchain
    URL "${PICO_TOOLCHAIN_URL}"
    URL_HASH "${JSON_HASH_TYPE}=${JSON_HASH_VALUE}"
    SOURCE_DIR toolchain
)
FetchContent_MakeAvailable(pico_toolchain)

set(PICO_TOOLCHAIN_PATH "${pico_toolchain_SOURCE_DIR}")
