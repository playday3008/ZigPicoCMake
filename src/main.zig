const p = @cImport({
    @cInclude("pico/stdlib.h");
});

const cyw43 = @cImport({
    // Pico W devices use a GPIO on the WIFI chip for the LED,
    // so when building for Pico W, CYW43_WL_GPIO_LED_PIN will be defined
    if (@hasDecl(p, "CYW43_WL_GPIO_LED_PIN")) {
        @cInclude("pico/cyw43_arch.h");
    }
});

const std = @import("std");

const LED_DELAY_MS = blk: {
    if (@hasDecl(p, "LED_DELAY_MS")) {
        break :blk p.LED_DELAY_MS;
    } else {
        break :blk 250;
    }
};

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
    // Workaround for this: https://github.com/ziglang/zig/issues/18537
    if (@hasDecl(p, "PICO_USE_GPIO_COPROCESSOR")) {
        @export(gpioc_bit_oe_put, .{
            .name = "gpioc_bit_oe_put",
        });
        @export(gpioc_bit_out_put, .{
            .name = "gpioc_bit_out_put",
        });
    }
}

/// Perform initialisation
fn picoLedInit() c_int {
    if (@hasDecl(p, "PICO_DEFAULT_LED_PIN")) {
        // A device like Pico that uses a GPIO for the LED will define PICO_DEFAULT_LED_PIN
        // so we can use normal GPIO functionality to turn the led on and off
        p.gpio_init(p.PICO_DEFAULT_LED_PIN);
        p.gpio_set_dir(p.PICO_DEFAULT_LED_PIN, p.GPIO_OUT != 0);
        return p.PICO_OK;
    } else if (@hasDecl(p, "CYW43_WL_GPIO_LED_PIN")) {
        // For Pico W devices we need to initialise the driver etc
        return cyw43.cyw43_arch_init();
    }
}

/// Turn the led on or off
fn picoSetLed(led_on: bool) void {
    if (@hasDecl(p, "PICO_DEFAULT_LED_PIN")) {
        // Just set the GPIO on or off
        p.gpio_put(p.PICO_DEFAULT_LED_PIN, led_on);
    } else if (@hasDecl(p, "CYW43_WL_GPIO_LED_PIN")) {
        // Ask the wifi "driver" to set the GPIO on or off
        cyw43.cyw43_arch_gpio_put(p.CYW43_WL_GPIO_LED_PIN, led_on);
    }
}

export fn main() c_int {
    const rc = picoLedInit();
    hardAssert(rc == p.PICO_OK);
    while (true) {
        picoSetLed(true);
        p.sleep_ms(LED_DELAY_MS);
        picoSetLed(false);
        p.sleep_ms(LED_DELAY_MS);
    }
}

/// Pico SDK `hard_assert` can't be used in Zig, so we define our own
fn hardAssert(condition: bool, ...) callconv(.C) void {
    if (@hasDecl(p, "NDEBUG")) {
        if (!condition) {
            @panic("hard assert failed");
        }
    } else {
        std.debug.assert(condition);
    }
}
