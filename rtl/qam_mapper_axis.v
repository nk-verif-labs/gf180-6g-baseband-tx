// ============================================================================
// Module: qam_mapper_axis
// Description: Configurable QAM Constellation Symbol Mapper (128-bit AXI4-Stream)
//              qam_mode:
//                2'b00 -> Raw 128-bit passthrough (6.4 Gbps @ 50 MHz)
//                2'b01 -> QPSK   (2 bits -> 8-bit I/Q packed, 16 symbols/beat)
//                2'b10 -> 16-QAM (4 bits -> 8-bit I/Q packed, 16 symbols/beat)
//                2'b11 -> 64-QAM (6 bits -> 8-bit I/Q packed, 16 symbols/beat)
// ============================================================================
`timescale 1ns / 1ps

module qam_mapper_axis (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         soft_rst,
    input  wire [1:0]   qam_mode,

    input  wire [127:0] s_tdata,
    input  wire         s_tvalid,
    output wire         s_tready,
    input  wire         s_tlast,

    output reg  [127:0] m_tdata,
    output reg          m_tvalid,
    input  wire         m_tready,
    output reg          m_tlast
);

    // Gray-coded 4-PAM signed 4-bit amplitude (-3, -1, +1, +3)
    function [3:0] pam4_map;
        input [1:0] bits;
        begin
            case (bits)
                2'b00: pam4_map = 4'sd13; // -3 in 4-bit two's complement (4'hD)
                2'b01: pam4_map = 4'sd15; // -1 (4'hF)
                2'b11: pam4_map = 4'sd1;  // +1 (4'h1)
                2'b10: pam4_map = 4'sd3;  // +3 (4'h3)
                default: pam4_map = 4'sd0;
            endcase
        end
    endfunction

    // Gray-coded 8-PAM signed 4-bit amplitude (-7, -5, -3, -1, +1, +3, +5, +7)
    function [3:0] pam8_map;
        input [2:0] bits;
        begin
            case (bits)
                3'b000: pam8_map = 4'h9; // -7
                3'b001: pam8_map = 4'hB; // -5
                3'b011: pam8_map = 4'hD; // -3
                3'b010: pam8_map = 4'hF; // -1
                3'b110: pam8_map = 4'h1; // +1
                3'b111: pam8_map = 4'h3; // +3
                3'b101: pam8_map = 4'h5; // +5
                3'b100: pam8_map = 4'h7; // +7
                default: pam8_map = 4'h0;
            endcase
        end
    endfunction

    reg [127:0] mapped_comb;
    integer idx;
    reg [3:0] i_val, q_val;

    assign s_tready = !m_tvalid || m_tready;

    always @(*) begin
        mapped_comb = s_tdata;
        if (qam_mode != 2'b00) begin
            for (idx = 0; idx < 16; idx = idx + 1) begin
                case (qam_mode)
                    2'b01: begin // QPSK: 2 bits/symbol -> {Q[3:0], I[3:0]}
                        i_val = s_tdata[idx*2]     ? 4'h1 : 4'hF;
                        q_val = s_tdata[idx*2 + 1] ? 4'h1 : 4'hF;
                    end
                    2'b10: begin // 16-QAM: 4 bits/symbol
                        i_val = pam4_map(s_tdata[idx*4 +: 2]);
                        q_val = pam4_map(s_tdata[idx*4 + 2 +: 2]);
                    end
                    2'b11: begin // 64-QAM: 6 bits/symbol (lower 96 bits -> 16 symbols)
                        i_val = pam8_map(s_tdata[idx*6 +: 3]);
                        q_val = pam8_map(s_tdata[idx*6 + 3 +: 3]);
                    end
                    default: begin
                        i_val = 4'h0;
                        q_val = 4'h0;
                    end
                endcase
                mapped_comb[idx*8 +: 8] = {q_val, i_val};
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n || soft_rst) begin
            m_tvalid <= 1'b0;
            m_tdata  <= 128'd0;
            m_tlast  <= 1'b0;
        end else if (s_tready) begin
            m_tvalid <= s_tvalid;
            m_tlast  <= s_tlast;
            if (s_tvalid) begin
                m_tdata <= mapped_comb;
            end
        end
    end

endmodule
