from machine import Pin, PWM
import utime

pwm = PWM(Pin(2))
pwm.freq(100)
pwm.duty_u16(32768)

rx = Pin(3, Pin.IN)

edges = 0
def on_edge(pin):
    global edges
    edges += 1

rx.irq(trigger=Pin.IRQ_RISING | Pin.IRQ_FALLING, handler=on_edge)

print("IRQ edge count, expected ~200 edges/sec")

while True:
    utime.sleep(1)
    print("edges_per_sec =", edges)
    edges = 0
