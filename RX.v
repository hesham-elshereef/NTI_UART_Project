module uart_rx #(
    parameter DATA_BITS = 8,
    parameter BAUD_CNT_WIDTH = 16
)(
    input                         clk,
    input                         rst,       // sync reset
    input                        arst_n,    // async reset active low
    input                        rx,        // serial input
    input                        rx_en,     // enable receiver
    input   [BAUD_CNT_WIDTH-1:0] baud_val, // baud counter load value

    output reg  [DATA_BITS-1:0] data,
    output reg                  done,
    output reg                  err,
    output reg                  busy
);

    // ===============================
    // State Encoding
    // ===============================
    localparam IDLE  = 3'b000;
    localparam START = 3'b001;
    localparam DATA  = 3'b010;
    localparam DONEs = 3'b011;
    localparam ERRs  = 3'b100;

    reg [2:0] cs, ns;

    reg [BAUD_CNT_WIDTH-1:0] baud_cnt;
    wire                     baud_done;
    reg [3:0]                bit_cnt;

    reg rx_sync, rx_prev;
    wire start_edge;

    reg [DATA_BITS-1:0] shift_reg;

    // ===============================
    // Edge Detector (falling edge)
    // ===============================
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            rx_sync <= 1'b1;
            rx_prev <= 1'b1;
        end else begin
            rx_sync <= rx;
            rx_prev <= rx_sync;
        end
    end

    assign start_edge = (rx_prev == 1'b1 && rx_sync == 1'b0);

    // ===============================
    // Baud Counter
    // ===============================
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            baud_cnt <= 0;
        end else if (rst) begin
            baud_cnt <= 0;
        end else if (cs == IDLE || baud_done) begin
            baud_cnt <= baud_val;
        end else begin
            baud_cnt <= baud_cnt - 1;
        end
    end

    assign baud_done = (baud_cnt == 0);

    // ===============================
    // FSM Sequential
    // ===============================
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            cs <= IDLE;
        end else if (rst) begin
            cs <= IDLE;
        end else begin
            cs <= ns;
        end
    end

    // ===============================
    // FSM Combinational
    // ===============================
    always @(*) begin
        ns = cs;
        done = 1'b0;
        err  = 1'b0;
        busy = 1'b1;

        case (cs)
            IDLE: begin
                busy = 1'b0;
                if (rx_en && start_edge) ns = START;
            end

            START: begin
                if (baud_done)           ns = DATA; 
            end

            DATA: begin
                if (baud_done) begin
                    if (bit_cnt == DATA_BITS) begin
                        if (rx_sync == 1'b1)
                            ns = DONEs;
                        else
                            ns = ERRs;
                    end
                end
            end

            DONEs: begin
                done = 1'b1;
                ns = IDLE;
            end

            ERRs: begin
                err = 1'b1;
                ns = IDLE;
            end
        endcase
    end

    // ===============================
    // Bit Counter
    // ===============================
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            bit_cnt <= 0;
        end else if (rst) begin
            bit_cnt <= 0;
        end else if (cs == IDLE) begin
            bit_cnt <= 0;
        end else if (cs == DATA && baud_done) begin
            bit_cnt <= bit_cnt + 1;
        end
    end

    // ===============================
    // SIPO Shift Register
    // ===============================
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            shift_reg <= 0;
        end else if (rst) begin
            shift_reg <= 0;
        end else if (cs == DATA && baud_done && bit_cnt < DATA_BITS) begin
            shift_reg <= {rx_sync, shift_reg[DATA_BITS-1:1]}; 
        end
    end

    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            data <= 0;
        end else if (rst) begin
            data <= 0;
        end else if (cs == DONEs) begin
            data <= shift_reg;
        end
    end

endmodule
