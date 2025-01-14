const sdk = @import("sdk.zig");

const std = @import("std");

const DOT_PERIOD_MS = 100;

const morse_letters = &[_][:0]const u8{
    ".-", // A
    "-...", // B
    "-.-.", // C
    "-..", // D
    ".", // E
    "..-.", // F
    "--.", // G
    "....", // H
    "..", // I
    ".---", // J
    "-.-", // K
    ".-..", // L
    "--", // M
    "-.", // N
    "---", // O
    ".--.", // P
    "--.-", // Q
    ".-.", // R
    "...", // S
    "-", // T
    "..-", // U
    "...-", // V
    ".--", // W
    "-..-", // X
    "-.--", // Y
    "--..", // Z
};

/// Perform initialisation
fn picoLedInit() c_int {
    if (@hasDecl(sdk, "PICO_DEFAULT_LED_PIN")) {
        // A device like Pico that uses a GPIO for the LED will define PICO_DEFAULT_LED_PIN
        // so we can use normal GPIO functionality to turn the led on and off
        sdk.gpio_init(sdk.PICO_DEFAULT_LED_PIN);
        sdk.gpio_set_dir(sdk.PICO_DEFAULT_LED_PIN, sdk.GPIO_OUT != 0); // Cast to bool by: <int> != 0
        return sdk.PICO_OK;
    } else if (@hasDecl(sdk, "CYW43_WL_GPIO_LED_PIN")) {
        // For Pico W devices we need to initialise the driver etc
        return sdk.cyw43_arch_init();
    }
}

/// Turn the led on or off
fn picoSetLed(led_on: bool) void {
    if (@hasDecl(sdk, "PICO_DEFAULT_LED_PIN")) {
        // Just set the GPIO on or off
        sdk.gpio_put(sdk.PICO_DEFAULT_LED_PIN, led_on);
    } else if (@hasDecl(sdk, "CYW43_WL_GPIO_LED_PIN")) {
        // Ask the wifi "driver" to set the GPIO on or off
        sdk.cyw43_arch_gpio_put(sdk.CYW43_WL_GPIO_LED_PIN, led_on);
    }
}

inline fn putMorseLetter(pattern: [:0]const u8) void {
    for (pattern) |value| {
        picoSetLed(true);
        if (value == '.') {
            sdk.sleep_ms(DOT_PERIOD_MS);
        } else {
            sdk.sleep_ms(DOT_PERIOD_MS * 3);
        }
        picoSetLed(false);
        sdk.sleep_ms(DOT_PERIOD_MS);
    }
    sdk.sleep_ms(DOT_PERIOD_MS * 2);
}

pub inline fn putMorseString(comptime str: [:0]const u8) void {
    for (str) |value| {
        if (value >= 'A' and value <= 'Z') {
            putMorseLetter(morse_letters[value - 'A']);
        } else if (value >= 'a' and value <= 'z') {
            putMorseLetter(morse_letters[value - 'a']);
        } else if (value == ' ') {
            sdk.sleep_ms(DOT_PERIOD_MS * 4);
        }
    }
    _ = sdk.printf(str ++ "\n");
}
