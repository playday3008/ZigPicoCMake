/// Load base header, so we can have compiler definitions
const pico = @cImport({
    @cInclude("pico.h");
});

pub usingnamespace @cImport({
    @cInclude("pico/stdlib.h");
    // Pico W devices use a GPIO on the WIFI chip for the LED,
    // so when building for Pico W, CYW43_WL_GPIO_LED_PIN will be defined
    if (@hasDecl(pico, "CYW43_WL_GPIO_LED_PIN")) {
        @cInclude("pico/cyw43_arch.h");
    }
});

// Workaround for this: https://github.com/ziglang/zig/issues/18537

fn gpioc_bit_oe_put(pin: c_uint, val: bool) callconv(.C) void {
    asm volatile (
        \\mcrr p0, #4, %[src1], %[src2], c4
        :
        : [src1] "r" (pin),
          [src2] "r" (val),
    );
}

fn gpioc_bit_out_put(pin: c_uint, val: bool) callconv(.C) void {
    asm volatile (
        \\mcrr p0, #4, %[src1], %[src2], c0
        :
        : [src1] "r" (pin),
          [src2] "r" (val),
    );
}

comptime {
    if (@hasDecl(@This(), "PICO_USE_GPIO_COPROCESSOR")) {
        @export(gpioc_bit_oe_put, .{
            .name = "gpioc_bit_oe_put",
        });
        @export(gpioc_bit_out_put, .{
            .name = "gpioc_bit_out_put",
        });
    }
}

// Workaround of abscence of translation `__FILE__` and `__LINE__` in Zig

// Basically a reimplementation of:
// <Pico SDK>/src/common/pico_base_headers/include/pico/assert.h:hard_assert()
extern fn hard_assertion_failure() callconv(.C) void;
pub fn hardAssert(ok: bool, ...) callconv(.C) void {
    if (!ok) {
        if (@hasDecl(@This(), "NDEBUG")) {
            hard_assertion_failure();
        } else {
            const std = @import("std");
            std.debug.panic("assertion failed", .{});
        }
    }
}
