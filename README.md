# FPV Flight Controller (FC v2.9)

Open-source flight controller firmware and hardware architecture built on the **STM32F103C8 (Blue Pill)** microcontroller. Designed from first principles for maximum reliability, low-level firmware optimization, and robust long-range telemetry.

---

## 🚀 System Architecture & Hardware

The system relies on a modular, zero-dependency philosophy, integrating high-precision inertial measurement units and long-range communication protocols.

* **Main Microcontroller**: STM32F103C8T6 (Blue Pill)[span_0](start_span)[span_0](end_span)
* **IMU (Gyro/Accelerometer)**: MPU-6050 (connected via I2C at 100 kHz for high-vibration stability)[span_1](start_span)[span_1](end_span)
* **Telemetry & Radio**: E22 LoRa Module (Serial1 / UART1 at 19200 Baud)[span_2](start_span)[span_2](end_span)
* **Power & Sensing**: 4S LiPo (14.8V) with a custom voltage divider network for safe analog battery voltage monitoring (`V_batt` via `A/D PA4`)[span_3](start_span)[span_3](end_span)

---

## 📐 Component Layout & Pinout Reference

Below is the clean hardware component layout schematic (FC v2.9), detailing the physical placement of components and pin connections without overlapping traces.

