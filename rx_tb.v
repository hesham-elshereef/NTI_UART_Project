`timescale 1ns/1ps

module uart_rx_tb;

  // Parameters
  parameter CLK_FREQ   = 50_000_000;
  parameter BAUD_RATE  = 9600;
  parameter BAUD_VAL   = CLK_FREQ / BAUD_RATE;

  // DUT signals
  reg        clk, rst;
  reg        rx;
  wire [7:0] data;
  wire       done, err, busy;

  // DUT instance
  uart_rx #(
    .DATA_BITS(8)
  ) DUT (
    .clk(clk),
    .rst(rst),
    .rx(rx),
    .baud_val(BAUD_VAL),
    .data(data),
    .done(done),
    .err(err),
    .busy(busy)
  );

  // Clock
  initial clk = 0;
  always #10 clk = ~clk;

  // UART frame sender task
  task send_uart_frame;
    input [7:0] tx_data;
    integer i;
    begin
      // Start bit
      rx = 0;
      repeat (BAUD_VAL) @(posedge clk);

      // Data bits (LSB first)
      for (i=0; i<8; i=i+1) begin
        rx = tx_data[i];
        repeat (BAUD_VAL) @(posedge clk);
      end

      // Stop bit
      rx = 1;
      repeat (BAUD_VAL) @(posedge clk);
    end
  endtask

  integer i, j ;
  initial begin
    rx = 1;
    rst = 1;
    #(100);
    rst = 0;

    // Case 1: Receive 0x55
    $display("Sending 0x55...");
    send_uart_frame(8'h55);
    wait(done);
    if (data == 8'h55 && !err)
      $display("PASS: Received 0x55 correctly");
    else
      $display("FAIL: Wrong RX data");

    // Case 2: Receive 0xA3
    $display("Sending 0xA3...");
    send_uart_frame(8'hA3);
    wait(done);
    if (data == 8'hA3 && !err)
      $display("PASS: Received 0xA3 correctly");
    else
      $display("FAIL: Wrong RX data");

    // Case 3: Framing error
    $display("Sending 0xF0 with bad stop bit...");
    // Start
    rx = 0; repeat (BAUD_VAL) @(posedge clk);
    // Data bits
    for ( j=0; j<8; j=j+1) begin
      rx = (8'hF0 >> j) & 1'b1;
      repeat (BAUD_VAL) @(posedge clk);
    end
    // Bad stop bit
    rx = 0; repeat (BAUD_VAL) @(posedge clk);

    wait(done);
    if (err)
      $display("PASS: Framing error detected");
    else
      $display("FAIL: Missed framing error");

    $display("RX test finished");
    $stop;
  end

endmodule
