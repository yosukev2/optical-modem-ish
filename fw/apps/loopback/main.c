#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/gpio.h"

#define TX_GPIO 2   // Pico GP2 -> Tx Vin（あなたの配線に合わせて変えてOK）
#define RX_GPIO 3   // Rx Vout -> Pico GP3

int main() {
    stdio_init_all();
    sleep_ms(1500); // USBシリアルの接続待ち（無くても動くが便利）

    gpio_init(TX_GPIO);
    gpio_set_dir(TX_GPIO, GPIO_OUT);
    gpio_put(TX_GPIO, 0);

    gpio_init(RX_GPIO);
    gpio_set_dir(RX_GPIO, GPIO_IN);
    gpio_pull_down(RX_GPIO); // Rxが開放になった時の浮き対策（保険）

    printf("loopback start. TX=%d RX=%d\n", TX_GPIO, RX_GPIO);

    uint32_t n = 0;
    while (true) {
        int tx = (n & 1);
        gpio_put(TX_GPIO, tx);

        sleep_us(50); // まずはゆっくり（W2は速度を欲張らない）

        int rx = gpio_get(RX_GPIO);
        printf("n=%lu tx=%d rx=%d\n", (unsigned long)n, tx, rx);

        n++;
        sleep_ms(100);
    }
}
