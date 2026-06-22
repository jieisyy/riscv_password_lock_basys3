`timescale 1ns / 1ps

module uart_event_sender #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD     = 115200
)(
    input  wire       clk,
    input  wire       resetn,
    input  wire       event_valid,
    input  wire [7:0] event_code,   // 'P', 'F', 'L'
    input  wire [1:0] user_id,
    output wire       tx,
    output wire       busy
);

    reg [7:0] uart_data;
    reg       uart_start;
    wire      uart_busy;

    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD(BAUD)
    ) u_uart_tx (
        .clk(clk),
        .resetn(resetn),
        .start(uart_start),
        .data(uart_data),
        .tx(tx),
        .busy(uart_busy)
    );

    reg [2:0] state;
    reg [3:0] index;
    reg [7:0] event_latched;
    reg [1:0] user_latched;

    localparam S_IDLE      = 3'd0;
    localparam S_LOAD      = 3'd1;
    localparam S_START     = 3'd2;
    localparam S_WAIT_BUSY = 3'd3;
    localparam S_WAIT_DONE = 3'd4;

    assign busy = (state != S_IDLE) || uart_busy;

    function [7:0] get_char;
        input [3:0] idx;
        input [7:0] evt;
        input [1:0] uid;
        begin
            case (idx)
                4'd0: get_char = "U";
                4'd1: get_char = "S";
                4'd2: get_char = "E";
                4'd3: get_char = "R";
                4'd4: get_char = 8'h30 + {6'd0, uid}; // '0'~'3'
                4'd5: get_char = " ";

                4'd6: begin
                    if (evt == "P")      get_char = "P";
                    else if (evt == "F") get_char = "F";
                    else                 get_char = "L";
                end

                4'd7: begin
                    if (evt == "P")      get_char = "A";
                    else if (evt == "F") get_char = "A";
                    else                 get_char = "O";
                end

                4'd8: begin
                    if (evt == "P")      get_char = "S";
                    else if (evt == "F") get_char = "I";
                    else                 get_char = "C";
                end

                4'd9: begin
                    if (evt == "P")      get_char = "S";
                    else if (evt == "F") get_char = "L";
                    else                 get_char = "K";
                end

                4'd10: get_char = 8'h0D; // carriage return
                4'd11: get_char = 8'h0A; // newline
                default: get_char = " ";
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (!resetn) begin
            state         <= S_IDLE;
            index         <= 4'd0;
            uart_data     <= 8'd0;
            uart_start    <= 1'b0;
            event_latched <= 8'd0;
            user_latched  <= 2'd0;
        end else begin
            uart_start <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (event_valid && !uart_busy) begin
                        event_latched <= event_code;
                        user_latched  <= user_id;
                        index         <= 4'd0;
                        state         <= S_LOAD;
                    end
                end

                S_LOAD: begin
                    if (!uart_busy) begin
                        uart_data  <= get_char(index, event_latched, user_latched);
                        state      <= S_START;
                    end
                end

                S_START: begin
                    uart_start <= 1'b1;
                    state      <= S_WAIT_BUSY;
                end

                S_WAIT_BUSY: begin
                    if (uart_busy) begin
                        state <= S_WAIT_DONE;
                    end
                end

                S_WAIT_DONE: begin
                    if (!uart_busy) begin
                        if (index == 4'd11) begin
                            state <= S_IDLE;
                        end else begin
                            index <= index + 1'b1;
                            state <= S_LOAD;
                        end
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule