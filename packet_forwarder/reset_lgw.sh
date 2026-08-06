#!/bin/sh
#
# SX1302/SX1303 (WM1302/WM1303) reset helper for SenseCAP M1 (RPi4)
# Compatible with:
#   - libgpiod 1.x (Raspberry Pi OS Bookworm / Debian 12)
#   - libgpiod 2.x (Raspberry Pi OS Trixie  / Debian 13)
#
# Usage: ./reset_lgw.sh {start|stop}
#

# GPIO mapping for Seeed WM1302/WM1303 on Raspberry Pi 4 header
GPIO_CHIP=gpiochip0
GPIO_PIN_SX1302_RESET=17     # SX1302/SX1303 reset
GPIO_PIN_SX1302_POWER_EN=18  # SX1302/SX1303 power enable
GPIO_PIN_SX1261_RESET=5      # SX1261 reset (LBT / Spectral Scan)
GPIO_PIN_AD5338R_RESET=13    # AD5338R reset (full-duplex CN490 reference design)

HOLD_US=100000
HOLD_MS=100ms

if ! command -v gpioset > /dev/null 2>&1; then
    echo "gpiod tools are not installed."
    echo "Install with: sudo apt update && sudo apt install -y gpiod"
    exit 1
fi

# Detect libgpiod CLI generation (v2 introduces --hold-period / -c)
if gpioset -h 2>&1 | grep -q -- '--hold-period'; then
    GPIOD_V2=1
else
    GPIOD_V2=0
fi

# Set a GPIO line to value and hold briefly (pulse), then release.
# RPi kernel typically retains the last driven level after release.
gpio_set() {
    pin="$1"
    val="$2"

    if [ "$GPIOD_V2" = "1" ]; then
        # libgpiod 2.x (Debian Trixie / RPi OS Trixie)
        # -c chip, --hold-period duration, -t0 exit after hold
        gpioset -c "$GPIO_CHIP" --hold-period "$HOLD_MS" -t0 "$pin=$val" 2>/dev/null
    else
        # libgpiod 1.x (Debian Bookworm / RPi OS Bookworm)
        gpioset -m time -u "$HOLD_US" "$GPIO_CHIP" "$pin=$val" 2>/dev/null
    fi
}

init() {
    echo "CoreCell power enable on through GPIO$GPIO_PIN_SX1302_POWER_EN..."
    gpio_set "$GPIO_PIN_SX1302_POWER_EN" 1
}

reset() {
    echo "CoreCell reset through GPIO$GPIO_PIN_SX1302_RESET..."
    gpio_set "$GPIO_PIN_SX1302_RESET" 1
    gpio_set "$GPIO_PIN_SX1302_RESET" 0

    echo "SX1261 reset through GPIO$GPIO_PIN_SX1261_RESET..."
    gpio_set "$GPIO_PIN_SX1261_RESET" 0
    gpio_set "$GPIO_PIN_SX1261_RESET" 1

    echo "CoreCell ADC reset through GPIO$GPIO_PIN_AD5338R_RESET..."
    gpio_set "$GPIO_PIN_AD5338R_RESET" 0
    gpio_set "$GPIO_PIN_AD5338R_RESET" 1
}

term() {
    echo "CoreCell power enable off through GPIO$GPIO_PIN_SX1302_POWER_EN..."
    gpio_set "$GPIO_PIN_SX1302_POWER_EN" 0
}

case "$1" in
    start)
        init
        reset
        ;;
    stop)
        reset
        term
        ;;
    *)
        echo "Usage: $0 {start|stop}"
        exit 1
        ;;
esac

exit 0
