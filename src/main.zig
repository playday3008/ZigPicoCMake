const sdk = @import("sdk.zig");

const std = @import("std");

const morse = @import("morse.zig");

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

export fn main() callconv(.C) c_int {
    const rc = picoLedInit();
    sdk.hardAssert(rc == sdk.PICO_OK);
    while (true) {
        morse.putMorseString("Hello World");
        sdk.sleep_ms(1000);
    }
}
