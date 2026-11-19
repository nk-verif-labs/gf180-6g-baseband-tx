// ============================================================================
// Module: csr_regs
// Description: AXI4-Lite Slave Control & Status Registers for tx_6g_baseband_top
// Address Map (Byte-addressed, 32-bit aligned):
//   0x00 CTRL    : [0] enable, [1] soft_rst, [2] bypass_scram,
//                  [3] bypass_fec, [5:4] qam_mode (00=Bypass/Raw, 01=QPSK, 10=16QAM, 11=64QAM)
//   0x04 STATUS  : [0] tx_busy, [1] fifo_full, [2] fifo_empty (RO)
//   0x08 PKT_CNT : 32-bit transmitted packet counter (RO)
//   0x0C LAST_CRC: 32-bit last computed IEEE 802.3 CRC-32 (RO)
// ============================================================================
`timescale 1ns / 1ps

module csr_regs (
    input  wire        clk,
    input  wire        rst_n,

    // AXI4-Lite Slave Interface
    input  wire [3:0]  s_axil_awaddr,
    input  wire        s_axil_awvalid,
    output reg         s_axil_awready,
    input  wire [31:0] s_axil_wdata,
    input  wire [3:0]  s_axil_wstrb,
    input  wire        s_axil_wvalid,
    output reg         s_axil_wready,
    output reg  [1:0]  s_axil_bresp,
    output reg         s_axil_bvalid,
    input  wire        s_axil_bready,

    input  wire [3:0]  s_axil_araddr,
    input  wire        s_axil_arvalid,
    output reg         s_axil_arready,
    output reg  [31:0] s_axil_rdata,
    output reg  [1:0]  s_axil_rresp,
    output reg         s_axil_rvalid,
    input  wire        s_axil_rready,

    // Control Outputs
    output reg         ctrl_enable,
    output reg         ctrl_soft_rst,
    output reg         ctrl_bypass_scram,
    output reg         ctrl_bypass_fec,
    output reg  [1:0]  ctrl_qam_mode,

    // Status Inputs
    input  wire        stat_tx_busy,
    input  wire        stat_fifo_full,
    input  wire        stat_fifo_empty,
    input  wire [31:0] stat_pkt_cnt,
    input  wire [31:0] stat_last_crc
);

    reg        aw_en;
    reg [3:0]  awaddr_reg;
    reg        aw_captured;
    reg [31:0] wdata_reg;
    reg [3:0]  wstrb_reg;
    reg        w_captured;

    // Write channel handshaking
    always @(posedge clk) begin
        if (!rst_n) begin
            s_axil_awready <= 1'b0;
            s_axil_wready  <= 1'b0;
            s_axil_bvalid  <= 1'b0;
            s_axil_bresp   <= 2'b00;
            aw_en          <= 1'b1;
            aw_captured    <= 1'b0;
            w_captured     <= 1'b0;
            awaddr_reg     <= 4'd0;
            wdata_reg      <= 32'd0;
            wstrb_reg      <= 4'd0;
            ctrl_enable       <= 1'b1;
            ctrl_soft_rst     <= 1'b0;
            ctrl_bypass_scram <= 1'b0;
            ctrl_bypass_fec   <= 1'b0;
            ctrl_qam_mode     <= 2'b00;
        end else begin
            // Default self-clearing soft reset
            ctrl_soft_rst <= 1'b0;

            // AWREADY
            if (!s_axil_awready && s_axil_awvalid && !aw_captured && aw_en) begin
                s_axil_awready <= 1'b1;
                awaddr_reg     <= s_axil_awaddr;
                aw_captured    <= 1'b1;
            end else begin
                s_axil_awready <= 1'b0;
            end

            // WREADY
            if (!s_axil_wready && s_axil_wvalid && !w_captured && aw_en) begin
                s_axil_wready <= 1'b1;
                wdata_reg     <= s_axil_wdata;
                wstrb_reg     <= s_axil_wstrb;
                w_captured    <= 1'b1;
            end else begin
                s_axil_wready <= 1'b0;
            end

            // Execute write when both AW and W captured
            if (aw_captured && w_captured && !s_axil_bvalid) begin
                aw_captured <= 1'b0;
                w_captured  <= 1'b0;
                aw_en       <= 1'b0;
                s_axil_bvalid <= 1'b1;
                s_axil_bresp  <= 2'b00; // OKAY

                if (awaddr_reg[3:2] == 2'b00) begin
                    if (wstrb_reg[0]) begin
                        ctrl_enable       <= wdata_reg[0];
                        ctrl_soft_rst     <= wdata_reg[1];
                        ctrl_bypass_scram <= wdata_reg[2];
                        ctrl_bypass_fec   <= wdata_reg[3];
                        ctrl_qam_mode     <= wdata_reg[5:4];
                    end
                end
            end else if (s_axil_bvalid && s_axil_bready) begin
                s_axil_bvalid <= 1'b0;
                aw_en         <= 1'b1;
            end
        end
    end

    // Read channel handshaking
    always @(posedge clk) begin
        if (!rst_n) begin
            s_axil_arready <= 1'b0;
            s_axil_rvalid  <= 1'b0;
            s_axil_rresp   <= 2'b00;
            s_axil_rdata   <= 32'd0;
        end else begin
            if (!s_axil_arready && s_axil_arvalid && !s_axil_rvalid) begin
                s_axil_arready <= 1'b1;
                s_axil_rvalid  <= 1'b1;
                s_axil_rresp   <= 2'b00;
                case (s_axil_araddr[3:2])
                    2'b00: s_axil_rdata <= {26'd0, ctrl_qam_mode, ctrl_bypass_fec, ctrl_bypass_scram, 1'b0, ctrl_enable};
                    2'b01: s_axil_rdata <= {29'd0, stat_fifo_empty, stat_fifo_full, stat_tx_busy};
                    2'b10: s_axil_rdata <= stat_pkt_cnt;
                    2'b11: s_axil_rdata <= stat_last_crc;
                    default: s_axil_rdata <= 32'd0;
                endcase
            end else begin
                s_axil_arready <= 1'b0;
                if (s_axil_rvalid && s_axil_rready) begin
                    s_axil_rvalid <= 1'b0;
                end
            end
        end
    end

endmodule
