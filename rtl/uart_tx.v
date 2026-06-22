`timescale 1ns / 1ps

module uart_tx #(
    parameter integer CLK_FREQ = 100_000_000,
    parameter integer BAUD     = 115200
)(
    input  wire       clk,
    input  wire       resetn,
    input  wire       start,
    input  wire [7:0] data,
    output reg        tx,
    output wire       busy
);
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD;
    localparam integer CNT_W = $clog2(CLKS_PER_BIT);

    reg [CNT_W-1:0] clk_cnt;
    reg [3:0]       bit_idx;
    reg [9:0]       shifter; // {stop, data[7:0], start}
    reg             active;

    assign busy = active;

    always @(posedge clk) begin
        if (!resetn) begin
            tx      <= 1'b1;
            clk_cnt <= {CNT_W{1'b0}};
            bit_idx <= 4'd0;
            shifter <= 10'b1111111111;
            active  <= 1'b0;
        end else begin
            if (!active) begin
                tx <= 1'b1;
                if (start) begin
                    shifter <= {1'b1, data, 1'b0}; // stop, data, start
                    clk_cnt <= {CNT_W{1'b0}};
                    bit_idx <= 4'd0;
                    active  <= 1'b1;
                    tx      <= 1'b0; // start bit immediately
                end
            end else begin
                if (clk_cnt == CLKS_PER_BIT-1) begin
                    clk_cnt <= {CNT_W{1'b0}};
                    shifter <= {1'b1, shifter[9:1]};
                    bit_idx <= bit_idx + 1'b1;
                    tx      <= shifter[1];
                    if (bit_idx == 4'd9) begin
                        active <= 1'b0;
                        tx     <= 1'b1;
                    end
                end else begin
                    clk_cnt <= clk_cnt + 1'b1;
                end
            end
        end
    end
endmodule
