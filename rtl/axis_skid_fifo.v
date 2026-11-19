// ============================================================================
// Module: axis_skid_fifo
// Description: 128-bit AXI4-Stream Synchronous Frame FIFO (16-deep)
//              Provides backpressure isolation and zero-bubble streaming.
// ============================================================================
`timescale 1ns / 1ps

module axis_skid_fifo #(
    parameter DATA_W = 128,
    parameter DEPTH  = 16
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              soft_rst,

    // Slave AXI4-Stream
    input  wire [DATA_W-1:0] s_axis_tdata,
    input  wire              s_axis_tvalid,
    output wire              s_axis_tready,
    input  wire              s_axis_tlast,

    // Master AXI4-Stream
    output wire [DATA_W-1:0] m_axis_tdata,
    output wire              m_axis_tvalid,
    input  wire              m_axis_tready,
    output wire              m_axis_tlast,

    output wire              fifo_full,
    output wire              fifo_empty
);

    localparam ADDR_W = 4; // log2(16)

    reg [DATA_W:0] mem [0:DEPTH-1]; // {tlast, tdata}
    reg [ADDR_W:0] wr_ptr;
    reg [ADDR_W:0] rd_ptr;

    wire full  = (wr_ptr[ADDR_W] != rd_ptr[ADDR_W]) && (wr_ptr[ADDR_W-1:0] == rd_ptr[ADDR_W-1:0]);
    wire empty = (wr_ptr == rd_ptr);

    assign fifo_full  = full;
    assign fifo_empty = empty;

    assign s_axis_tready = !full;
    assign m_axis_tvalid = !empty;

    wire [DATA_W:0] rd_entry = mem[rd_ptr[ADDR_W-1:0]];
    assign m_axis_tdata = rd_entry[DATA_W-1:0];
    assign m_axis_tlast = rd_entry[DATA_W];

    wire do_wr = s_axis_tvalid && s_axis_tready;
    wire do_rd = m_axis_tvalid && m_axis_tready;

    always @(posedge clk) begin
        if (!rst_n || soft_rst) begin
            wr_ptr <= {(ADDR_W+1){1'b0}};
            rd_ptr <= {(ADDR_W+1){1'b0}};
        end else begin
            if (do_wr) begin
                mem[wr_ptr[ADDR_W-1:0]] <= {s_axis_tlast, s_axis_tdata};
                wr_ptr <= wr_ptr + 1'b1;
            end
            if (do_rd) begin
                rd_ptr <= rd_ptr + 1'b1;
            end
        end
    end

endmodule
