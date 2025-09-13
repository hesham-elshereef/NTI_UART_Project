`timescale 1ns/1ps

module uart_tx #(
  parameter DATA_BITS = 8,
  parameter STOP_BITS = 1
)(
  input              clk,        // System clock
  input              rst,        // Synchronous reset (active high)
  input              tx_start,   // Start transmission
  input  [7:0]       tx_data,    // Data to send
  input  [15:0]      baud_val,   // Baud rate divisor (CLK_FREQ/BAUD)
  output reg         tx,         // UART line
  output reg         busy,       // Transmitter busy
  output reg         done        // Transmission finished
);

  // FSM states
  localparam IDLE  = 3'b000,
             START = 3'b001,
             DATA  = 3'b010,
             STOP  = 3'b011,
             DONE  = 3'b100;

  reg [2:0] state, next_state;
  reg [15:0] baud_cnt;
  reg [3:0]  bit_idx;
  reg [7:0]  shift_reg;

  // Baud counter
  always @(posedge clk or posedge rst) begin
    if (rst) 
      baud_cnt <= 0;
    else if (state != IDLE) begin
      if (baud_cnt == 0)
        baud_cnt <= baud_val;
      else
        baud_cnt <= baud_cnt - 1;
    end else
      baud_cnt <= baud_val;
  end

  wire baud_tick = (baud_cnt == 0);

  // FSM state register
  always @(posedge clk or posedge rst) begin
    if (rst)
      state <= IDLE;
    else
      state <= next_state;
  end

  // FSM next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE:  if (tx_start) next_state = START;
      START: if (baud_tick) next_state = DATA;
      DATA:  if (baud_tick && bit_idx == DATA_BITS-1) next_state = STOP;
      STOP:  if (baud_tick && STOP_BITS==1) next_state = DONE;
      DONE:  next_state = IDLE;
    endcase
  end

  // FSM outputs
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      tx       <= 1'b1; // idle is HIGH
      busy     <= 0;
      done     <= 0;
      shift_reg<= 0;
      bit_idx  <= 0;
    end else begin
      done <= 0; // default

      case (state)
        IDLE: begin
          tx   <= 1'b1;
          busy <= 0;
          if (tx_start) begin
            shift_reg <= tx_data;
            busy <= 1;
          end
        end

        START: if (baud_tick) tx <= 1'b0;  // Start bit

        DATA: if (baud_tick) begin
          tx <= shift_reg[0];
          shift_reg <= shift_reg >> 1;
          bit_idx <= bit_idx + 1;
        end

        STOP: if (baud_tick) tx <= 1'b1;   // Stop bit(s)

        DONE: begin
          done <= 1;
          busy <= 0;
        end
      endcase
    end
  end

endmodule