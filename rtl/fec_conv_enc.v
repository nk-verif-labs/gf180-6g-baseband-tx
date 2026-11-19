// ============================================================================
// Module: fec_conv_enc
// Description: Parallel Rate-1/2 Convolutional FEC Encoder (K=7, G0=171o, G1=133o)
//              Processes 64 payload bits -> 128 coded bits per beat when enabled,
//              or passes 128 bits straight through in bypass mode (6.4 Gbps).
// ============================================================================
`timescale 1ns / 1ps

module fec_conv_enc (
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

    reg [5:0]   shift_q;
    reg [5:0]   shift_tmp;
    reg [127:0] coded_comb;
    integer     i;
    reg [6:0]   win;
    reg         g0, g1;

    assign s_tready = !m_tvalid || m_tready;

    // Rate-1/2 (K=7) convolutional encoding of lower 64 bits -> 128 coded bits
    // G0 = 7'b1111001 (171 octal), G1 = 7'b1011011 (133 octal)
    always @(*) begin
        shift_tmp  = shift_q;
        coded_comb = 128'd0;
        for (i = 0; i < 64; i = i + 1) begin
            win = {s_tdata[i], shift_tmp};
            g0  = ^(win & 7'b1111001);
            g1  = ^(win & 7'b1011011);
            coded_comb[2*i]     = g0;
            coded_comb[2*i + 1] = g1;
            shift_tmp = {s_tdata[i], shift_tmp[5:1]};
        end
    end

    always @(posedge clk) begin
        if (!rst_n || soft_rst) begin
            shift_q  <= 6'd0;
            m_tvalid <= 1'b0;
            m_tdata  <= 128'd0;
            m_tlast  <= 1'b0;
        end else if (s_tready) begin
            m_tvalid <= s_tvalid;
            m_tlast  <= s_tlast;
            if (s_tvalid) begin
                m_tdata <= bypass ? s_tdata : coded_comb;
                shift_q <= s_tlast ? 6'd0 : shift_tmp;
            end
        end
    end

endmodule
