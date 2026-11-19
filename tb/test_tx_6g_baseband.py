import random
import zlib
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles


# ---------------------------------------------------------------------------
# Golden Reference Models (Python)
# ---------------------------------------------------------------------------
def golden_scrambler_128b(word: int, lfsr_state: int = 0x5A5A3C3C & 0x7FFFFFFF):
    mask = 0
    s = lfsr_state
    for i in range(128):
        fb = ((s >> 30) ^ (s >> 27)) & 1
        mask |= (fb << i)
        s = ((s << 1) | fb) & 0x7FFFFFFF
    return word ^ mask, s


def golden_crc32_128b(words: list[int]) -> int:
    raw = b"".join(w.to_bytes(16, "little") for w in words)
    return zlib.crc32(raw) & 0xFFFFFFFF


def golden_fec_rate12(word: int, shift_q: int = 0):
    coded = 0
    s = shift_q
    for i in range(64):
        bit = (word >> i) & 1
        win = (bit << 6) | s
        g0 = bin(win & 0b1111001).count("1") & 1
        g1 = bin(win & 0b1011011).count("1") & 1
        coded |= (g0 << (2 * i)) | (g1 << (2 * i + 1))
        s = ((bit << 5) | (s >> 1)) & 0x3F
    return coded, s


def golden_qam_16(word: int) -> int:
    pam4 = {0b00: 0xD, 0b01: 0xF, 0b11: 0x1, 0b10: 0x3}
    out = 0
    for idx in range(16):
        b_i = (word >> (idx * 4)) & 0x3
        b_q = (word >> (idx * 4 + 2)) & 0x3
        sym = (pam4[b_q] << 4) | pam4[b_i]
        out |= sym << (idx * 8)
    return out


# ---------------------------------------------------------------------------
# Bus Helpers (AXI4-Lite & AXI4-Stream)
# ---------------------------------------------------------------------------
async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.s_axil_awaddr.value = 0
    dut.s_axil_awvalid.value = 0
    dut.s_axil_wdata.value = 0
    dut.s_axil_wstrb.value = 0
    dut.s_axil_wvalid.value = 0
    dut.s_axil_bready.value = 1
    dut.s_axil_araddr.value = 0
    dut.s_axil_arvalid.value = 0
    dut.s_axil_rready.value = 1
    dut.s_axis_tdata.value = 0
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0
    dut.m_axis_tready.value = 1
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)


async def axil_write(dut, addr: int, data: int):
    dut.s_axil_awaddr.value = addr
    dut.s_axil_awvalid.value = 1
    dut.s_axil_wdata.value = data
    dut.s_axil_wstrb.value = 0xF
    dut.s_axil_wvalid.value = 1
    dut.s_axil_bready.value = 1

    aw_done = False
    w_done = False
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.s_axil_awready.value:
            aw_done = True
            dut.s_axil_awvalid.value = 0
        if dut.s_axil_wready.value:
            w_done = True
            dut.s_axil_wvalid.value = 0
        if aw_done and w_done and dut.s_axil_bvalid.value:
            break
    await RisingEdge(dut.clk)


async def axil_read(dut, addr: int) -> int:
    dut.s_axil_araddr.value = addr
    dut.s_axil_arvalid.value = 1
    dut.s_axil_rready.value = 1
    val = 0
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.s_axil_arready.value:
            dut.s_axil_arvalid.value = 0
        if dut.s_axil_rvalid.value:
            val = int(dut.s_axil_rdata.value)
            break
    await RisingEdge(dut.clk)
    return val


async def send_frame(dut, beats: list[int]):
    for idx, word in enumerate(beats):
        dut.s_axis_tdata.value = word
        dut.s_axis_tvalid.value = 1
        dut.s_axis_tlast.value = 1 if (idx == len(beats) - 1) else 0
        while True:
            await RisingEdge(dut.clk)
            if dut.s_axis_tready.value:
                break
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0


async def recv_frame(dut, num_beats: int, backpressure: bool = False) -> list[int]:
    out = []
    while len(out) < num_beats:
        if backpressure:
            dut.m_axis_tready.value = random.choice([0, 1, 1])
        else:
            dut.m_axis_tready.value = 1
        await RisingEdge(dut.clk)
        if dut.m_axis_tvalid.value and dut.m_axis_tready.value:
            out.append(int(dut.m_axis_tdata.value))
            if len(out) == num_beats:
                assert int(dut.m_axis_tlast.value) == 1, "Expected tlast on final beat"
            else:
                assert int(dut.m_axis_tlast.value) == 0, "Unexpected early tlast"
    dut.m_axis_tready.value = 1
    return out


# ---------------------------------------------------------------------------
# Cocotb Tests
# ---------------------------------------------------------------------------
@cocotb.test()
async def test_csr_and_raw_passthrough(dut):
    """Verify AXI4-Lite CSRs and 128-bit raw 6.4 Gbps bypass with backpressure."""
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    await reset_dut(dut)

    # CTRL: enable=1, soft_rst=0, bypass_scram=1, bypass_fec=1, qam_mode=00 -> 0x0D
    await axil_write(dut, 0x00, 0x0D)
    ctrl_rd = await axil_read(dut, 0x00)
    assert (ctrl_rd & 0x3D) == 0x0D, f"CTRL mismatch: {hex(ctrl_rd)}"

    beats = [random.getrandbits(128) for _ in range(8)]
    rx_task = cocotb.start_soon(recv_frame(dut, len(beats), backpressure=True))
    await send_frame(dut, beats)
    rx = await rx_task

    assert rx == beats, "Raw passthrough data mismatch"
    pkt_cnt = await axil_read(dut, 0x08)
    assert pkt_cnt == 1, f"Expected PKT_CNT=1, got {pkt_cnt}"
    last_crc = await axil_read(dut, 0x0C)
    exp_crc = golden_crc32_128b(beats)
    assert last_crc == exp_crc, f"CRC mismatch: got {hex(last_crc)}, exp {hex(exp_crc)}"


@cocotb.test()
async def test_full_6g_baseband_pipeline(dut):
    """Verify Scrambler + CRC-32 + Rate-1/2 FEC + 16-QAM mapper end-to-end."""
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    await reset_dut(dut)

    # CTRL: enable=1, bypass_scram=0, bypass_fec=0, qam_mode=10 (16-QAM) -> 0x21
    await axil_write(dut, 0x00, 0x21)

    beats = [random.getrandbits(128) for _ in range(4)]

    # Compute expected pipeline outputs
    lfsr = 0x5A5A3C3C & 0x7FFFFFFF
    fec_s = 0
    scram_beats = []
    expected_out = []
    for w in beats:
        sw, lfsr = golden_scrambler_128b(w, lfsr)
        scram_beats.append(sw)
        fw, fec_s = golden_fec_rate12(sw, fec_s)
        qw = golden_qam_16(fw)
        expected_out.append(qw)

    rx_task = cocotb.start_soon(recv_frame(dut, len(beats), backpressure=False))
    await send_frame(dut, beats)
    rx = await rx_task

    assert rx == expected_out, "Full 6G baseband pipeline output mismatch"
    last_crc = await axil_read(dut, 0x0C)
    assert last_crc == golden_crc32_128b(scram_beats), "CRC-32 on scrambled frame mismatch"
