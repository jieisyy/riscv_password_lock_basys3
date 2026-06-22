`timescale 1ns / 1ps

// Display status words on Basys 3 4-digit seven-segment display.
// value = 16'h1111 -> PASS
// value = 16'h2222 -> FAIL
// value = 16'h9999 -> LOCK (K is approximated on 7-seg)
// Otherwise display hex value, compatible with original sevenseg_hex behavior.
module sevenseg_status(
    input  wire        clk,
    input  wire        resetn,
    input  wire [15:0] value,
    output reg  [6:0]  seg,   // active-low: {CA,CB,CC,CD,CE,CF,CG}
    output reg  [3:0]  an     // active-low
);
    reg [15:0] refresh;
    wire [1:0] digit_sel = refresh[15:14];
    reg [7:0] char_code;
    reg [3:0] nibble;

    localparam [7:0] CH_P = "P";
    localparam [7:0] CH_A = "A";
    localparam [7:0] CH_S = "S";
    localparam [7:0] CH_F = "F";
    localparam [7:0] CH_I = "I";
    localparam [7:0] CH_L = "L";
    localparam [7:0] CH_O = "O";
    localparam [7:0] CH_C = "C";
    localparam [7:0] CH_K = "K";
    localparam [7:0] CH_HEX = 8'hFF;

    always @(posedge clk) begin
        if (!resetn) refresh <= 16'd0;
        else         refresh <= refresh + 1'b1;
    end

    always @(*) begin
        case (digit_sel)
            2'd0: begin an = 4'b1110; nibble = value[3:0];   end // rightmost
            2'd1: begin an = 4'b1101; nibble = value[7:4];   end
            2'd2: begin an = 4'b1011; nibble = value[11:8];  end
            default: begin an = 4'b0111; nibble = value[15:12]; end // leftmost
        endcase

        char_code = CH_HEX;

        if (value == 16'h1111) begin
            // Left to right: P A S S
            case (digit_sel)
                2'd0: char_code = CH_S;
                2'd1: char_code = CH_S;
                2'd2: char_code = CH_A;
                default: char_code = CH_P;
            endcase
        end else if (value == 16'h2222) begin
            // Left to right: F A I L
            case (digit_sel)
                2'd0: char_code = CH_L;
                2'd1: char_code = CH_I;
                2'd2: char_code = CH_A;
                default: char_code = CH_F;
            endcase
        end else if (value == 16'h9999) begin
            // Left to right: L O C K, K is approximated on a 7-seg display
            case (digit_sel)
                2'd0: char_code = CH_K;
                2'd1: char_code = CH_C;
                2'd2: char_code = CH_O;
                default: char_code = CH_L;
            endcase
        end

        if (char_code == CH_HEX) begin
            case (nibble)
                4'h0: seg = 7'b1000000;
                4'h1: seg = 7'b1111001;
                4'h2: seg = 7'b0100100;
                4'h3: seg = 7'b0110000;
                4'h4: seg = 7'b0011001;
                4'h5: seg = 7'b0010010;
                4'h6: seg = 7'b0000010;
                4'h7: seg = 7'b1111000;
                4'h8: seg = 7'b0000000;
                4'h9: seg = 7'b0010000;
                4'hA: seg = 7'b0001000;
                4'hB: seg = 7'b0000011;
                4'hC: seg = 7'b1000110;
                4'hD: seg = 7'b0100001;
                4'hE: seg = 7'b0000110;
                4'hF: seg = 7'b0001110;
                default: seg = 7'b1111111;
            endcase
        end else begin
            case (char_code)
                CH_P: seg = 7'b0001100; // P
                CH_A: seg = 7'b0001000; // A
                CH_S: seg = 7'b0010010; // S, same as 5
                CH_F: seg = 7'b0001110; // F
                CH_I: seg = 7'b1111001; // I, approximated as 1
                CH_L: seg = 7'b1000111; // L
                CH_O: seg = 7'b1000000; // O, same as 0
                CH_C: seg = 7'b1000110; // C
                CH_K: seg = 7'b0001001; // K/H-like approximation
                default: seg = 7'b1111111;
            endcase
        end
    end
endmodule
