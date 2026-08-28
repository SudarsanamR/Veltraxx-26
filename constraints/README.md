# Constraints Directory

This directory stores target board timing and physical constraints:

- `nexys_a7.xdc`: Digilent Nexys A7 (XC7A100T-1CSG324C) master constraint file.

> **Important**: Pin mappings must be verified against the authoritative board reference manual before bitstream generation.

---

## Target Board Constraint Topology

```mermaid
flowchart LR
    classDef board fill:#1e293b,stroke:#38bdf8,stroke-width:2px,color:#f8fafc;
    classDef pin fill:#78350f,stroke:#fbbf24,stroke-width:2px,color:#f8fafc;
    classDef fpga fill:#064e3b,stroke:#34d399,stroke-width:2px,color:#f8fafc;

    subgraph BOARD ["Digilent Nexys A7 (XC7A100T-1CSG324C)"]
        CLK_OSC["100 MHz System Oscillator<br/>(Pin E3)"]:::board
        RST_BTN["CPU Reset Pushbutton<br/>(Pin C12 - Active-Low)"]:::board
        UART_PINS["FTDI USB-UART Bridge<br/>RX (Pin C4) / TX (Pin D4)"]:::board
        LEDS["16 User LEDs<br/>(Pins H17, K15, J13...)"]:::board
        SEG7["8-Digit 7-Segment Display<br/>(Anodes + Cathodes CA..CG)"]:::board
        BTNS["Pushbuttons<br/>BTNC (Pin N17)"]:::board
        SW["Switches SW[1:0]<br/>(Word Select)"]:::board
    end

    subgraph XDC ["XDC Timing & Pin Constraints (nexys_a7.xdc)"]
        PIN_MAP["create_clock -period 10.000<br/>set_property PACKAGE_PIN<br/>set_property IOSTANDARD LVCMOS33"]:::pin
    end

    subgraph CORE_TOP ["nexys_a7_uart_top FPGA Design"]
        CLK_IN["clk (100 MHz clock domain)"]:::fpga
        RST_IN["reset_n (Active-Low)"]:::fpga
        UART_PORT["USB-UART RX/TX (115200 Baud)"]:::fpga
        STATUS_PORT["Status LEDs (Busy/Done/Mode/Error)"]:::fpga
        DISPLAY["7-Segment Hex Display (32-bit output)"]:::fpga
        BTN_PORT["Pushbutton Input (NIST Test)"]:::fpga
        SW_PORT["Switch Input (Word Select)"]:::fpga
    end

    CLK_OSC --> PIN_MAP --> CLK_IN
    RST_BTN --> PIN_MAP --> RST_IN
    UART_PINS <==> PIN_MAP <==> UART_PORT
    STATUS_PORT --> PIN_MAP --> LEDS
    DISPLAY --> PIN_MAP --> SEG7
    BTNS --> PIN_MAP --> BTN_PORT
    SW --> PIN_MAP --> SW_PORT
```

---

## Mapped Peripherals

| Peripheral | Nexys A7 Pin(s) | FPGA Port | IOSTANDARD |
|:-----------|:----------------|:----------|:-----------|
| 100 MHz Clock | E3 | `clk` | LVCMOS33 |
| CPU Reset (Active-Low) | C12 | `reset_n` | LVCMOS33 |
| UART RX (from PC) | C4 | `uart_rx` | LVCMOS33 |
| UART TX (to PC) | D4 | `uart_tx` | LVCMOS33 |
| 16 LEDs | H17, K15, J13, ... | `led[15:0]` | LVCMOS33 |
| 7-Seg Anodes (8 digits) | J17, J18, T9, ... | `an[7:0]` | LVCMOS33 |
| 7-Seg Cathodes | T10, R10, K16, ... | `seg[6:0]`, `dp` | LVCMOS33 |
| Center Button | N17 | `btn_c` | LVCMOS33 |
| Switches | J15, L16 | `sw[1:0]` | LVCMOS33 |
