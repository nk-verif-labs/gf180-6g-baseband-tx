// ============================================================================
// Module: scrambler_128b
// Description: 128-bit Parallel Additive LFSR Scrambler (x^31 + x^28 + 1)
//              Single-cycle throughput @ 50 MHz -> 6.4 Gbps data whitening.
// ============================================================================
`timescale 1ns / 1ps

module scrambler_128b (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         soft_rst,
    input  wire         bypass,

    input  wire [127:0] s_tdata,
    input  wire         s_tvalid,
    output wire         s_tready,
    input  wire         s_tlast,

    output reg  [127:0] m_tdata,
    output reg          m_tvalid,
    input  wire         m_tready,
    output reg          m_tlast
);

    localparam [30:0] SEED = 31'h5A5A_3C3C;

    reg  [30:0] lfsr_q;
    reg  [30:0] lfsr_next;
    reg [127:0] mask_comb;
    integer i;
    reg fb;

    assign s_tready = !m_tvalid || m_tready;

    // Unroll 128 bits of LFSR: x^31 + x^28 + 1
    always @(*) begin
        lfsr_next = lfsr_q;
        mask_comb = 128'd0;
        for (i = 0; i < 128; i = i + 1) begin
            fb = lfsr_next[30] ^ lfsr_next[27];
            mask_comb[i] = fb;
            lfsr_next = {lfsr_next[29:0], fb};
        end
    end

    always @(posedge clk) begin
        if (!rst_n || soft_rst) begin
            lfsr_q   <= SEED;
            m_tvalid <= 1'b0;
            m_tdata  <= 128'd0;
            m_tlast  <= 1'b0;
        end else if (s_tready) begin
            m_tvalid <= s_tvalid;
            m_tlast  <= s_tlast;
            if (s_tvalid) begin
                m_tdata <= bypass ? s_tdata : (s_tdata ^ mask_comb);
                // Re-seed LFSR at frame boundary (tlast), else advance
                lfsr_q  <= s_tlast ? SEED : lfsr_next;
            end
        end
    end

endmodule
