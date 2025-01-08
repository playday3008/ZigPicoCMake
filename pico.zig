const std = @import("std");
const target = std.Target;

/// Hazard3 RISC-V cores used in RP2350
/// Zig does not have a built-in definition for Hazard3
///
/// [RP2350 Datasheet](https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf)
///
/// [RP2350 Hazard3 LLVM](https://github.com/llvm/llvm-project/blob/df4a615c988f3ae56f7e68a7df86acb60f16493a/llvm/lib/Target/RISCV/RISCVProcessors.td#L562)
//const cpu_hazard3 = target.Cpu.Model{
//    .name = "hazard3",
//    .llvm_name = "rp2350-hazard3",
//    .features = target.riscv.featureSet(&[_]target.riscv.Feature{
//        .@"32bit",
//        .i,
//        .m,
//        .a,
//        .c,
//        .zicsr,
//        .zifencei,
//        .zba,
//        .zbb,
//        .zbs,
//        .zbkb,
//        .zcb,
//        .zcmp,
//        // Not available
//        //.xh3power,
//        //.xh3bextm,
//        //.xh3irq,
//        //.xh3pmpm,
//    }),
//};
const cpu_hazard3 = target.riscv.cpu.sifive_e21;

/// Raspberry Pi Microcontroller Chip
const Chip = enum {
    RP2040,
    RP2350,

    pub inline fn str(self: Chip) [:0]const u8 {
        return @tagName(self);
    }
};

/// Architecture of the Chip
const Arch = enum {
    ARM,
    RISCV,

    pub inline fn arch(self: Arch) target.Cpu.Arch {
        return switch (self) {
            .ARM => .thumb,
            .RISCV => .riscv32,
        };
    }

    pub inline fn abi(self: Arch) target.Abi {
        return switch (self) {
            .ARM => .eabi,
            .RISCV => .gnuilp32, // TODO: should be `ilp32`, but not available in Zig 0.13.0
        };
    }

    pub inline fn str(self: Arch) [:0]const u8 {
        return switch (self) {
            .ARM => "ARM",
            .RISCV => "RISC-V",
        };
    }
};

/// Combination of Chip and Architecture
const Platform = struct {
    chip: Chip,
    arch: Arch,

    pub inline fn model(self: Platform) target.Query.CpuModel {
        return .{
            .explicit = switch (self.chip) {
                .RP2040 => switch (self.arch) {
                    .ARM => &target.arm.cpu.cortex_m0plus,
                    .RISCV => @panic("RP2040 does not support RISC-V"),
                },
                .RP2350 => switch (self.arch) {
                    .ARM => &target.arm.cpu.cortex_m33,
                    .RISCV => &cpu_hazard3,
                },
            },
        };
    }

    pub inline fn str(self: Platform) [:0]const u8 {
        // This must be compatible with CMake definitions
        return switch (self.chip) {
            .RP2040 => "rp2040" ++ switch (self.arch) {
                .ARM => .{},
                .RISCV => @panic("RP2040 does not support RISC-V"),
            },
            .RP2350 => "rp2350" ++ switch (self.arch) {
                .ARM => "-arm-s",
                .RISCV => "-riscv",
            },
        };
    }

    pub inline fn init(chip: Chip, comptime arch: Arch) Platform {
        // Sanity check
        switch (chip) {
            .RP2040 => switch (arch) {
                .ARM => {},
                .RISCV => @panic("RP2040 does not support RISC-V"),
            },
            .RP2350 => switch (arch) {
                .ARM => {},
                .RISCV => {},
            },
        }
        return .{
            .chip = chip,
            .arch = arch,
        };
    }
};

/// Have wireless capabilities
const Wireless = enum {
    None,
    CYW43439,
};

/// Raspberry Pi Pico boards
const Board = struct {
    name: [:0]const u8,
    cmake_name: ?[:0]const u8 = null,
    platform: Platform,
    wireless: Wireless,
};

/// Raspberry Pi Pico
pub const Pico = Board{
    .name = "pico",
    .platform = Platform.init(.RP2040, .ARM),
    .wireless = Wireless.None,
};
/// Raspberry Pi Pico W(H)
pub const PicoW = Board{
    .name = Pico.name ++ "_w",
    .platform = Pico.platform,
    .wireless = Wireless.CYW43439,
};
/// Raspberry Pi Pico 2
pub const Pico2 = Board{
    .name = "pico2",
    .platform = Platform.init(.RP2350, .ARM),
    .wireless = Wireless.None,
};
/// Raspberry Pi Pico 2 W
pub const Pico2W = Board{
    .name = Pico2.name ++ "_w",
    .platform = Pico2.platform,
    .wireless = Wireless.CYW43439,
};
/// Raspberry Pi Pico 2 (RISC-V)
pub const Pico2Riscv = Board{
    .name = "pico2-riscv",
    .cmake_name = "pico2",
    .platform = Platform.init(.RP2350, .RISCV),
    .wireless = Wireless.None,
};
/// Raspberry Pi Pico 2 W (RISC-V)
pub const Pico2RiscvW = Board{
    .name = Pico2Riscv.name ++ "_w",
    .cmake_name = Pico2Riscv.cmake_name.? ++ "_w",
    .platform = Pico2Riscv.platform,
    .wireless = Wireless.CYW43439,
};

pub const Boards = &[_]Board{
    Pico,
    PicoW,
    Pico2,
    Pico2W,
    Pico2Riscv,
    Pico2RiscvW,
};

/// Standard I/O configuration
///
/// Uses meta programming, don't change this
pub const Stdio = struct {
    UART: bool = false,
    USB: bool = false,
    SEMIHOSTING: bool = false,
    RTT: bool = false,
};

/// Library to link
pub const Lib = struct {
    name: [:0]const u8,
    // Null means it doesn't matter
    chip: ?Chip = null,
    arch: ?Arch = null,
};

// zig fmt: off
/// Libraries
pub const api = .{
    // Hardware APIs
    .hardware = .{
        .adc                  = Lib{ .name = "hardware_adc",                  .chip = null,    .arch = null   },
        .base                 = Lib{ .name = "hardware_base",                 .chip = null,    .arch = null   },
        .claim                = Lib{ .name = "hardware_claim",                .chip = null,    .arch = null   },
        .clocks               = Lib{ .name = "hardware_clocks",               .chip = null,    .arch = null   },
        .divider              = Lib{ .name = "hardware_divider",              .chip = null,    .arch = null   },
        .dcp                  = Lib{ .name = "hardware_dcp",                  .chip = .RP2350, .arch = null   },
        .dma                  = Lib{ .name = "hardware_dma",                  .chip = null,    .arch = null   },
        .exception            = Lib{ .name = "hardware_exception",            .chip = null,    .arch = null   },
        .flash                = Lib{ .name = "hardware_flash",                .chip = null,    .arch = null   },
        .gpio                 = Lib{ .name = "hardware_gpio",                 .chip = null,    .arch = null   },
        .hazard3              = Lib{ .name = "hardware_hazard3",              .chip = null,    .arch = .RISCV },
        .i2c                  = Lib{ .name = "hardware_i2c",                  .chip = null,    .arch = null   },
        .interp               = Lib{ .name = "hardware_interp",               .chip = null,    .arch = null   },
        .irq                  = Lib{ .name = "hardware_irq",                  .chip = null,    .arch = null   },
        .pio                  = Lib{ .name = "hardware_pio",                  .chip = null,    .arch = null   },
        .pll                  = Lib{ .name = "hardware_pll",                  .chip = null,    .arch = null   },
        .powman               = Lib{ .name = "hardware_powman",               .chip = .RP2350, .arch = null   },
        .pwm                  = Lib{ .name = "hardware_pwm",                  .chip = null,    .arch = null   },
        .resets               = Lib{ .name = "hardware_resets",               .chip = null,    .arch = null   },
        .riscv                = Lib{ .name = "hardware_riscv",                .chip = null,    .arch = .RISCV },
        .riscv_platform_timer = Lib{ .name = "hardware_riscv_platform_timer", .chip = null,    .arch = .RISCV },
        .rtc                  = Lib{ .name = "hardware_rtc",                  .chip = .RP2040, .arch = null   },
        .rcp                  = Lib{ .name = "hardware_rcp",                  .chip = .RP2350, .arch = null   },
        .spi                  = Lib{ .name = "hardware_spi",                  .chip = null,    .arch = null   },
        .sha256               = Lib{ .name = "hardware_sha256",               .chip = .RP2350, .arch = null   },
        .sync                 = Lib{ .name = "hardware_sync",                 .chip = null,    .arch = null   },
        .ticks                = Lib{ .name = "hardware_ticks",                .chip = null,    .arch = null   },
        .timer                = Lib{ .name = "hardware_timer",                .chip = null,    .arch = null   },
        .uart                 = Lib{ .name = "hardware_uart",                 .chip = null,    .arch = null   },
        .vreg                 = Lib{ .name = "hardware_vreg",                 .chip = null,    .arch = null   },
        .watchdog             = Lib{ .name = "hardware_watchdog",             .chip = null,    .arch = null   },
        .xip_cache            = Lib{ .name = "hardware_xip_cache",            .chip = null,    .arch = null   },
        .xosc                 = Lib{ .name = "hardware_xosc",                 .chip = null,    .arch = null   },
    },
    // High Level APIs
    .high_level = .{
        .aon_timer                = Lib{ .name = "pico_aon_timer",                .chip = null,    .arch = null   },
        .async_context            = Lib{ .name = "pico_async_context",            .chip = null,    .arch = null   },
        .bootsel_via_double_reset = Lib{ .name = "pico_bootsel_via_double_reset", .chip = null,    .arch = null   },
        .flash                    = Lib{ .name = "pico_flash",                    .chip = null,    .arch = null   },
        .i2c_slave                = Lib{ .name = "pico_i2c_slave",                .chip = null,    .arch = null   },
        .multicore                = Lib{ .name = "pico_multicore",                .chip = null,    .arch = null   },
        .rand                     = Lib{ .name = "pico_rand",                     .chip = null,    .arch = null   },
        .sha256                   = Lib{ .name = "pico_sha256",                   .chip = .RP2350, .arch = null   },
        .stdlib                   = Lib{ .name = "pico_stdlib",                   .chip = null,    .arch = null   },
        .sync                     = Lib{ .name = "pico_sync",                     .chip = null,    .arch = null   },
        .time                     = Lib{ .name = "pico_time",                     .chip = null,    .arch = null   },
        .unique_id                = Lib{ .name = "pico_unique_id",                .chip = null,    .arch = null   },
        .util                     = Lib{ .name = "pico_util",                     .chip = null,    .arch = null   },
    },
    // Third-party Libraries
    .third_party = .{
        .tinyusb = .{
            .device = Lib{ .name = "tinyusb_device", .chip = null,    .arch = null   },
            .host =   Lib{ .name = "tinyusb_host",   .chip = null,    .arch = null   },
        },
    },
    // Networking Libraries
    .network = .{
        .btstack = Lib{ .name = "pico_btstack", .chip = null,    .arch = null   },
        .lwip = .{
            .core       = Lib{ .name = "pico_lwip_core",       .chip = null,    .arch = null   },
            .core4      = Lib{ .name = "pico_lwip_core4",      .chip = null,    .arch = null   },
            .core6      = Lib{ .name = "pico_lwip_core6",      .chip = null,    .arch = null   },
            .netif      = Lib{ .name = "pico_lwip_netif",      .chip = null,    .arch = null   },
            .sixlowpan  = Lib{ .name = "pico_lwip_sixlowpan",  .chip = null,    .arch = null   },
            .ppp        = Lib{ .name = "pico_lwip_ppp",        .chip = null,    .arch = null   },
            .api        = Lib{ .name = "pico_lwip_api",        .chip = null,    .arch = null   },
            .snmp       = Lib{ .name = "pico_lwip_snmp",       .chip = null,    .arch = null   },
            .http       = Lib{ .name = "pico_lwip_http",       .chip = null,    .arch = null   },
            .makefsdata = Lib{ .name = "pico_lwip_makefsdata", .chip = null,    .arch = null   },
            .iperf      = Lib{ .name = "pico_lwip_iperf",      .chip = null,    .arch = null   },
            .smtp       = Lib{ .name = "pico_lwip_smtp",       .chip = null,    .arch = null   },
            .sntp       = Lib{ .name = "pico_lwip_sntp",       .chip = null,    .arch = null   },
            .mdns       = Lib{ .name = "pico_lwip_mdns",       .chip = null,    .arch = null   },
            .netbios    = Lib{ .name = "pico_lwip_netbios",    .chip = null,    .arch = null   },
            .tftp       = Lib{ .name = "pico_lwip_tftp",       .chip = null,    .arch = null   },
            .mbedtls    = Lib{ .name = "pico_lwip_mbedtls",    .chip = null,    .arch = null   },
            .mqtt       = Lib{ .name = "pico_lwip_mqtt",       .chip = null,    .arch = null   },
        },
        .cyw43_driver = Lib{ .name = "pico_cyw43_driver", .chip = null,    .arch = null   },
        .cyw43_arch = .{
            .lwip_poll                  = Lib{ .name = "pico_cyw43_arch_lwip_poll",                  .chip = null,    .arch = null   },
            .lwip_threadsafe_background = Lib{ .name = "pico_cyw43_arch_lwip_threadsafe_background", .chip = null,    .arch = null   },
            .lwip_sys_freertos          = Lib{ .name = "pico_cyw43_arch_lwip_sys_freertos",          .chip = null,    .arch = null   },
            .none                       = Lib{ .name = "pico_cyw43_arch_none",                       .chip = null,    .arch = null   },
        },
    },
    // Runtime Infrastructure
    .runtime = .{
        .boot = .{
            .stage2 = Lib{ .name = "boot_stage2", .chip = null,    .arch = null   },
        },
        .pico = .{
            .atomic               = Lib{ .name = "pico_atomic",               .chip = null,    .arch = null   },
            .base                 = Lib{ .name = "pico_base",                 .chip = null,    .arch = null   },
            .binary_info          = Lib{ .name = "pico_binary_info",          .chip = null,    .arch = null   },
            .bootrom              = Lib{ .name = "pico_bootrom",              .chip = null,    .arch = null   },
            .bit_ops              = Lib{ .name = "pico_bit_ops",              .chip = null,    .arch = null   },
            .cxx_options          = Lib{ .name = "pico_cxx_options",          .chip = null,    .arch = null   },
            .clib_interface       = Lib{ .name = "pico_clib_interface",       .chip = null,    .arch = null   },
            .crt0                 = Lib{ .name = "pico_crt0",                 .chip = null,    .arch = null   },
            .divider              = Lib{ .name = "pico_divider",              .chip = null,    .arch = null   },
            .double               = Lib{ .name = "pico_double",               .chip = null,    .arch = null   },
            .float                = Lib{ .name = "pico_float",                .chip = null,    .arch = null   },
            .int64_ops            = Lib{ .name = "pico_int64_ops",            .chip = null,    .arch = null   },
            .malloc               = Lib{ .name = "pico_malloc",               .chip = null,    .arch = null   },
            .mem_ops              = Lib{ .name = "pico_mem_ops",              .chip = null,    .arch = null   },
            .platform             = Lib{ .name = "pico_platform",             .chip = null,    .arch = null   },
            .printf               = Lib{ .name = "pico_printf",               .chip = null,    .arch = null   },
            .runtime              = Lib{ .name = "pico_runtime",              .chip = null,    .arch = null   },
            .runtime_init         = Lib{ .name = "pico_runtime_init",         .chip = null,    .arch = null   },
            .stdio                = Lib{ .name = "pico_stdio",                .chip = null,    .arch = null   },
            .standard_binary_info = Lib{ .name = "pico_standard_binary_info", .chip = null,    .arch = null   },
            .standard_link        = Lib{ .name = "pico_standard_link",        .chip = null,    .arch = null   },
        },
    },
    // External API Headers
    .external = .{
        .boot = .{
            .picobin_headers  = Lib{ .name = "boot_picobin_headers",  .chip = null,    .arch = null   },
            .picoboot_headers = Lib{ .name = "boot_picoboot_headers", .chip = null,    .arch = null   },
            .uf2_headers      = Lib{ .name = "boot_uf2_headers",      .chip = null,    .arch = null   },
        },
        .pico = .{
            .usb_reset_interface_headers = Lib{ .name = "pico_usb_reset_interface_headers", .chip = null,    .arch = null   },
        },
    },
};
// zig fmt: on
