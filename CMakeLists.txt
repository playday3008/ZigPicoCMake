# Works with 3.19 and tested through 3.29
cmake_minimum_required(VERSION 3.19...3.29)

# Failsafe from automatic configuration by some IDEs
if(NOT DEFINED ENV{BUILD_FROM_ZIG})
    message(FATAL_ERROR "This CMakeLists.txt file is not meant to be run directly. Please run `zig build` instead.")
endif()

#set(PICO_BOARD "pico" CACHE STRING "Board Type")'

set(PROJECT_NAME "ZigPicoCMake" CACHE STRING "Project Name")
set(PROJECT_VERSION "0.0.1" CACHE STRING "Project Version")

set(ZIG_LIB ${CMAKE_SOURCE_DIR}/zig-out/${PROJECT_NAME}.o)

# Pull suitable toolchain
include(${CMAKE_CURRENT_LIST_DIR}/cmake/toolchain-import.cmake)

# Use Raspberry Pi Pico SDK (must be before project)
include(${CMAKE_CURRENT_LIST_DIR}/cmake/pico-sdk-import.cmake)

# Project name and a few useful settings. Other commands can pick up the results
project(
    ${PROJECT_NAME}
    VERSION ${PROJECT_VERSION}
    DESCRIPTION ${PROJECT_DESCRIPTION}
    HOMEPAGE_URL ${PROJECT_HOMEPAGE_URL}
    LANGUAGES C CXX ASM
)

# Initialize the Raspberry Pi Pico SDK
pico_sdk_init()

# If `ZIG_LIB` is not found, generate dummy C file with `main` function
add_executable(${PROJECT_NAME})

# Set Pico project properties
pico_set_program_name(${PROJECT_NAME} ${PROJECT_NAME})
if(DEFINED PROJECT_DESCRIPTION AND NOT PROJECT_DESCRIPTION STREQUAL "")
    pico_set_program_description(${PROJECT_NAME} ${PROJECT_DESCRIPTION})
endif()
if(DEFINED PROJECT_HOMEPAGE_URL AND NOT PROJECT_HOMEPAGE_URL STREQUAL "")
    pico_set_program_url(${PROJECT_NAME} ${PROJECT_HOMEPAGE_URL})
endif()
if(DEFINED PROJECT_VERSION AND NOT PROJECT_VERSION STREQUAL "")
    pico_set_program_version(${PROJECT_NAME} ${PROJECT_VERSION})
endif()

# Generate PIO headers (if any)
file(GLOB_RECURSE PIO_HEADERS CONFIGURE_DEPENDS "${CMAKE_CURRENT_LIST_DIR}/pio/*.pio")
foreach(PIO_HEADER ${PIO_HEADERS})
    pico_generate_pio_header(${TARGET_NAME} ${PIO_HEADER})
endforeach()

# Set stdio configuration
if(DEFINED PICO_STDIO_UART)
    pico_enable_stdio_uart(${PROJECT_NAME} ${PICO_STDIO_UART})
endif()
if(DEFINED PICO_STDIO_USB)
    pico_enable_stdio_usb(${PROJECT_NAME} ${PICO_STDIO_USB})
endif()
if(DEFINED PICO_STDIO_SEMIHOSTING)
    pico_enable_stdio_semihosting(${PROJECT_NAME} ${PICO_STDIO_SEMIHOSTING})
endif()
if(DEFINED PICO_STDIO_RTT)
    pico_enable_stdio_rtt(${PROJECT_NAME} ${PICO_STDIO_RTT})
endif()

# Adjust libraries as needed
target_link_libraries(${PROJECT_NAME}
    # Our Zig library
    ${ZIG_LIB}

    # Defined in `build.zig`
    ${TARGET_LINK_LIBS}
)

# Generate binary
pico_add_extra_outputs(${PROJECT_NAME})
