vlib work
vlog RX.v rx_tb.v TX.v tx_tb.v
vsim -voptargs=+acc work.uart_tx_tb
add wave *
run -all
#quit -sim