# ZigPicoCMake

This repository provides a Zig-based build system for the Raspberry Pi Pico SDK, leveraging the CMake integration with Zig. It is designed to be compatible with both ARM and RISC-V architectures.

## Build

To build the project, follow these steps:

1. Clone the repository:

   ```bash
   git clone https://github.com/playday3008/ZigPicoCMake
   ```

2. Navigate to the project directory:

   ```bash
   cd ZigPicoCMake
   ```

3. Run `zig build`

   ```bash
   zig build
   ```

   flags are:

   - `-Dboard <board>` - Specify the board to build for. Default is `pico_w`, check valid boards in `pico.zig`
   - `-Dbuild_dir <build_dir>` - Specify the build directory. Default is `./build/<board>`.

   Check `zig build --help` for more options.

## Supported commands

- `zig build` - Build the project
- `zig build uf2` - Build the project and generate a UF2 file (default)
- `zig build clean` - Clean the build directory

## Quirks

- Building of code which depends on functions that uses inline volatile assembly isn't working because zig can't currently translate it, tracking issue: [ziglang/zig#18537](https://github.com/ziglang/zig/issues/18537)
- Hazard3 isn't completely supported, currently using SiFive E21 as a workaround.
- ZLS seems to can't figure out `@cImport`s (sometimes), so, use your [Sixth sense](https://en.wikipedia.org/wiki/Sixth_sense) or [Pico SDK Documentation](https://www.raspberrypi.com/documentation/pico-sdk/) to find the right headers with right functions.
- Clean reconfiguration is not supported, you need to manually remove `build` directory and re-run `zig build` with the desired options.

## Contributing

Contributions are welcome! Feel free to open an issue or a pull request.
Feedback is also appreciated. As I'm still learning Zig, I'm open to suggestions on how to improve the codebase.

## Acknowledgements

Tools:

- [Zig](https://ziglang.org)
- [CMake](https://cmake.org)

Codebases:

- [zig-pico-cmake](https://github.com/nemuibanila/zig-pico-cmake) - Initial inspiration
- [Pico SDK](https://github.com/raspberrypi/pico-sdk) - Original SDK

Toolchains:

- ARM
  - [ARM LLVM Toolchain](https://github.com/ARM-software/LLVM-embedded-toolchain-for-Arm)
  - [ARM GNU Toolchain](https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads)
- RISC-V
  - [Embecosm CORE-V GNU Toolchain](https://buildbot.embecosm.com/search/?q=corev-gcc)
  - [Embecosm LLVM Toolchain](https://buildbot.embecosm.com/search/?q=riscv32-clang)
  - [Embecosm GNU Toolchain](https://buildbot.embecosm.com/search/?q=riscv32-gcc)
