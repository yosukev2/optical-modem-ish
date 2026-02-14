add_executable(loopback
  main.c
)

target_link_libraries(loopback pico_stdlib hardware_gpio)

pico_enable_stdio_usb(loopback 1)
pico_enable_stdio_uart(loopback 0)

pico_add_extra_outputs(loopback)
