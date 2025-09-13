`timescale 1ns/1ps

module uart_tx_tb;

  // Parameters
  parameter CLK_FREQ   = 50_000_000;   // 50 MHz
  parameter BAUD_RATE  = 9600;
  parameter BAUD_VAL   = CLK_FREQ / BAUD_RATE;

  // DUT signals
  reg        clk, rst;
  reg        tx_start;
  reg [7:0]  tx_data;
  wire       tx;
  wire       busy, done;

  // DUT instance
  uart_tx #(
    .DATA_BITS(8),
    .STOP_BITS(1)
  ) DUT (
    .clk(clk),
    .rst(rst),
    .tx_start(tx_start),
    .tx_data(tx_data),
    .baud_val(BAUD_VAL),
    .tx(tx),
    .busy(busy),
    .done(done)
  );

  // Clock generation (50 MHz → 20ns)
  initial clk = 0;
  always #10 clk = ~clk;

  // Stimulus
  initial begin
    rst = 1;
    tx_start = 0;
    tx_data = 8'h00;
    #(100);
    rst = 0;

    // Case 1: Send 0x55
    @(negedge clk);
    tx_data = 8'h55;
    tx_start = 1;
    @(negedge clk);
    tx_start = 0;

    wait(done);
    $display("TX DONE: Sent 0x55");

    // Case 2: Send 0xA3
    @(negedge clk);
    tx_data = 8'hA3;
    tx_start = 1;
    @(negedge clk);
    tx_start = 0;

    wait(done);
    $display("TX DONE: Sent 0xA3");

    $display("TX test finished");
    $stop;
  end

endmodule
