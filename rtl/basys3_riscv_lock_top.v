`timescale 1ns / 1ps

// Basys 3 RISC-V multi-user password lock SoC.
// Requires picorv32.v in the Vivado project.
module basys3_riscv_lock_top(
    input  wire        clk,      // Basys 3 100 MHz clock
    input  wire [15:0] sw,
    input  wire        btnC,
    input  wire        btnU,     // hardware reset, active high
    output wire [15:0] led,
    output wire [6:0]  seg,
    output wire [3:0]  an,
    output wire        uart_txd
);
    reg [19:0] reset_cnt = 20'd0;
    reg resetn_reg = 1'b0;

    always @(posedge clk) begin
        if (btnU) begin
            reset_cnt  <= 20'd0;
            resetn_reg <= 1'b0;
        end else begin
            if (reset_cnt != 20'hFFFFF) begin
                reset_cnt  <= reset_cnt + 1'b1;
                resetn_reg <= 1'b0;
            end else begin
                resetn_reg <= 1'b1;
            end
        end
    end

    wire resetn = resetn_reg;

    // PicoRV32 native memory interface
    wire        mem_valid;
    wire        mem_instr;
    reg         mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    reg  [31:0] mem_rdata;
    wire        trap;

    picorv32 #(
        .ENABLE_COUNTERS(0),
        .ENABLE_COUNTERS64(0),
        .ENABLE_REGS_16_31(1),
        .ENABLE_REGS_DUALPORT(1),
        .TWO_STAGE_SHIFT(0),
        .BARREL_SHIFTER(0),
        .COMPRESSED_ISA(0),
        .ENABLE_MUL(0),
        .ENABLE_DIV(0),
        .PROGADDR_RESET(32'h0000_0000),
        .STACKADDR(32'h0001_0400)
    ) cpu (
        .clk(clk),
        .resetn(resetn),
        .trap(trap),
        .mem_valid(mem_valid),
        .mem_instr(mem_instr),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata)
    );

    // 16 KB instruction memory: 0x0000_0000 - 0x0000_3FFF
    reg [31:0] instr_mem [0:4095];
    initial begin
        $readmemh("D:/FPGA_projects/riscv_lock_test/firmware.hex", instr_mem);
    end

    // 1 KB data memory: 0x0001_0000 - 0x0001_03FF
    reg [31:0] data_mem [0:255];

    // I/O registers
    reg [15:0] led_reg;
    reg [15:0] sevenseg_reg;
    reg [7:0]  uart_event_code;
    reg        uart_event_valid;
    wire       uart_busy;

    assign led = led_reg;

    sevenseg_status u_7seg(
        .clk(clk),
        .resetn(resetn),
        .value(sevenseg_reg),
        .seg(seg),
        .an(an)
    );

    uart_event_sender #(
        .CLK_FREQ(100_000_000),
        .BAUD(115200)
    ) u_uart_event_sender (
        .clk(clk),
        .resetn(resetn),
        .event_valid(uart_event_valid),
        .event_code(uart_event_code),
        .user_id(sw[9:8]),
        .tx(uart_txd),
        .busy(uart_busy)
    );

    // Address decode
    wire sel_instr = (mem_addr[31:16] == 16'h0000); // 0x0000_xxxx
    wire sel_data  = (mem_addr[31:16] == 16'h0001); // 0x0001_xxxx
    wire sel_io    = (mem_addr[31:16] == 16'h4000); // 0x4000_xxxx

    wire write_en = mem_valid && (|mem_wstrb);

    function [31:0] apply_wstrb;
        input [31:0] old_data;
        input [31:0] new_data;
        input [3:0]  wstrb;
        begin
            apply_wstrb[7:0]   = wstrb[0] ? new_data[7:0]   : old_data[7:0];
            apply_wstrb[15:8]  = wstrb[1] ? new_data[15:8]  : old_data[15:8];
            apply_wstrb[23:16] = wstrb[2] ? new_data[23:16] : old_data[23:16];
            apply_wstrb[31:24] = wstrb[3] ? new_data[31:24] : old_data[31:24];
        end
    endfunction

    integer i;
    always @(posedge clk) begin
        if (!resetn) begin
            mem_ready    <= 1'b0;
            mem_rdata    <= 32'd0;
            led_reg      <= 16'd0;
            sevenseg_reg <= 16'h0000;
            uart_event_code <= 8'd0;
            uart_event_valid   <= 1'b0;
            for (i = 0; i < 256; i = i + 1) data_mem[i] <= 32'd0;
        end else begin
            mem_ready  <= mem_valid;  // one-cycle simple memory response
            uart_event_valid <= 1'b0;

            // default read data
            if (sel_instr) begin
                mem_rdata <= instr_mem[mem_addr[13:2]];
            end else if (sel_data) begin
                mem_rdata <= data_mem[mem_addr[9:2]];
            end else if (sel_io) begin
                case (mem_addr[7:0])
                    8'h00: mem_rdata <= {16'd0, sw};
                    8'h04: mem_rdata <= {31'd0, btnC};
                    8'h08: mem_rdata <= {16'd0, led_reg};
                    8'h0C: mem_rdata <= {16'd0, sevenseg_reg};
                    8'h14: mem_rdata <= {31'd0, uart_busy}; // bit0: 1 = busy
                    default: mem_rdata <= 32'd0;
                endcase
            end else begin
                mem_rdata <= 32'd0;
            end

            // writes
            if (write_en) begin
                if (sel_data) begin
                    data_mem[mem_addr[9:2]] <= apply_wstrb(data_mem[mem_addr[9:2]], mem_wdata, mem_wstrb);
                end else if (sel_io) begin
                    case (mem_addr[7:0])
                        8'h08: led_reg <= mem_wdata[15:0];
                        8'h0C: sevenseg_reg <= mem_wdata[15:0];
                        8'h10: begin
                            if (!uart_busy) begin
                                uart_event_code <= mem_wdata[7:0];
                                uart_event_valid <= 1'b1;
                            end
                        end
                        default: ;
                    endcase
                end
            end
        end
    end
endmodule
