# AXI Stream Machine

This project captures AXI4-Stream packets of varying sizes from two slave channels, processes them, and sends the combined data to a single AXI4-Stream master.

---

## 📦 System Overview

The design supports two operational modes:
- **Non-Interleaved Mode**: Channels are processed sequentially.
- **Interleaved Mode**: Channels are merged and interleaved during output.

The architecture consists of multiple blocks as shown below:

![System Diagram](https://github.com/user-attachments/assets/89bafd98-bf38-4200-9749-0bc495d99658)

---

## 🔧 Modules

### `1.stream_processor`
- Top-level DUT that integrates all submodules.
- Controls the output mux logic between interleaved and non-interleaved data.
- Selects mode using `config_mode`:
  - `0`: Non-Interleaved
  - `1`: Interleaved
- Implements a two-stage register pipeline for both interleaved and non-interleaved data paths.

### `2.sync_fifo`
- Synchronous FIFO used for buffering AXI4-Stream input data.
- Two instances are used for the two input channels.

### `3.non_inter_machine`
- Processes non-interleaved data from one channel at a time.
- Accepts 3-byte input from FIFO and stores into 3 registers (each 8 bytes).
- Stops reading on `tlast` and sends stored data sequentially via round-robin logic.
![non_in drawio](https://github.com/user-attachments/assets/3a4636fc-c9bb-436b-98bc-808b5ab55f98)

### `4.inter_machine`
- Processes interleaved data from both channels.
- Accepts two 3-byte inputs (6 bytes total) and stores into three 8-byte registers.
- Similar output control as `non_inter_machine`.
![inter drawio](https://github.com/user-attachments/assets/aca4c1e7-94ec-4044-ade0-eb7493710550)

### `5.all_pkg`
- Contains shared `typedef`s, `enum`s, and parameters used across modules.

### `6.stream_processor_tb`
- Testbench module to simulate and validate DUT.
- Currently supports basic directed tests.
- Designed to be extended into a full UVM testbench in the future.

---

## ✅ Features

- Interleaved and Non-Interleaved AXI-Stream processing
- Dual-channel input handling with configurable logic
- Multi-stage pipelined buffering for high throughput
- AXI4-Stream-compliant handshaking (`tvalid`, `tready`, `tlast`)
- Modular and reusable RTL architecture

## The state machine that handles reading from the FIFO:

![st2 drawio](https://github.com/user-attachments/assets/abc549ad-7946-4db2-8af7-8fd91fe0a601)



---

## 🔬 Test Status

The included testbench:
- Sends packets from both channels
- Verifies correct reassembly and output
- Displays all output beats with proper `tlast` indication

> Note: Output data is observed in simulation logs and can be extended with assertions and scoreboards.
