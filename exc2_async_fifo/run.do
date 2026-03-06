vlog "C:/intelFPGA_lite/20.1/quartus/eda/sim_lib/altera_mf.v"
vlog rtl/mem.v
vlog -sv rtl/async_fifo.sv
vlog -sv tb/tb_async_fifo.sv
vsim tb_async_fifo
run -all