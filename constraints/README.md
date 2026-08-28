# Constraints Directory

This directory stores target board timing and physical constraints:

- `nexys_a7.xdc`: Digilent Nexys A7 (XC7A100T-1CSG324C / XC7A50T) constraint file.
- `arty_s7.xdc`: Digilent Arty S7 constraint file (secondary/backup platform).

> **Important**: Pin mappings must be verified against the authoritative board reference manual before bitstream generation.

---

## Target Board Constraint Topology

```mermaid
flowchart LR
    classDef board fill:#1e293b,stroke:#38bdf8,stroke-width:2px,color:#f8fafc;
    classDef pin fill:#78350f,stroke:#fbbf24,stroke-width:2px,color:#f8fafc;
    classDef fpga fill:#064e3b,stroke:#34d399,stroke-width:2px,color:#f8fafc;

    subgraph BOARD ["Target FPGA Board (Digilent Nexys A7 / Arty S7)"]
        CLK_OSC["100 MHz System Oscillator<br/>(Pin E3)"]:::board
        RST_BTN["CPU Reset Pushbutton<br/>(Pin C12 - Active-Low)"]:::board
        UART_PINS["FTDI USB-UART Bridge<br/>RX (Pin C4) / TX (Pin D4)"]:::board
        LEDS["Board User LEDs<br/>(Pins H17, K15, J13...)"]:::board
    end

    subgraph XDC ["XDC Timing & Pin Constraints (.xdc)"]
        PIN_MAP["create_clock -period 10.000<br/>set_property PACKAGE_PIN<br/>set_property IOSTANDARD LVCMOS33"]:::pin
    end

    subgraph CORE_TOP ["aes_axi_top FPGA Design"]
        CLK_IN["clk (100 MHz clock domain)"]:::fpga
        RST_IN["rst_n / aresetn"]:::fpga
        UART_PORT["UART / AXI-MM Interface"]:::fpga
        STATUS_PORT["Status Flags (Busy, Done, Error)"]:::fpga
    end

    CLK_OSC --> PIN_MAP --> CLK_IN
    RST_BTN --> PIN_MAP --> RST_IN
    UART_PINS <==> PIN_MAP <==> UART_PORT
    STATUS_PORT --> PIN_MAP --> LEDS
```
