# gf180-6g-baseband-tx

**6.4 Gbps On-Chip 6G Baseband & High-Throughput Data-Transfer Engine** targeting **GlobalFoundries GF180MCU (`gf180mcuD`)** via **LibreLane**.

## Architecture Overview
- **Top Module:** `tx_6g_baseband_top`
- **Clock & Throughput:** `50 MHz` (`20.0 ns` period) × `128-bit` AXI4-Stream datapath = **`6.4 Gbps`** peak internal data-transfer bandwidth.
- **Pipeline Stages:**
  1. `csr_regs` — AXI4-Lite slave (`0x00 CTRL`, `0x04 STATUS`, `0x08 PKT_CNT`, `0x0C LAST_CRC`)
  2. `axis_skid_fifo` — 128-bit × 16-deep synchronous AXI4-Stream FIFO for backpressure isolation
  3. `scrambler_128b` — 128-bit parallel LFSR scrambler ($x^{31} + x^{28} + 1$)
  4. `crc32_128b` — 128-bit parallel IEEE 802.3 CRC-32 generator (16 bytes/cycle)
  5. `fec_conv_enc` — Parallel Rate-1/2 convolutional FEC encoder ($K=7$, $G_0=171_8$, $G_1=133_8$) with bypass
  6. `qam_mapper_axis` — Configurable QPSK / 16-QAM / 64-QAM Gray-coded I/Q symbol mapper or raw 128-bit passthrough

## Quick Start (Local Ubuntu 24.04 + `~/.venvs/cocotb19`)

### 1. Run Cocotb Verification (Icarus / Verilator)
```bash
source ~/.venvs/cocotb19/bin/activate
cd tb
make SIM=icarus
make SIM=verilator
```

### 2. Run LibreLane RTL-to-GDSII (`gf180mcuD`)
```bash
librelane --pdk gf180mcuD librelane/config.json
```
