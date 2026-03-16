quit -sim
puts "--- BAT DAU CHAY SCRIPT ---"

if {[file exists work]} {
    vdel -lib work -all
}
vlib work

vlog -sv ./rtl/sync_bram.sv
vlog -sv ./rtl/mp_fsm.sv
vlog -sv ./rtl/mp_datapath.sv
vlog -sv ./rtl/mp_top.sv
vlog -sv ./sim/tb_mp_top.sv

vsim -voptargs="+acc" work.tb_mp_top

view wave
add wave -position insertpoint sim:/tb_mp_top/dut/*
add wave -position insertpoint sim:/tb_mp_top/dut/u_fsm/current_state
add wave -position insertpoint sim:/tb_mp_top/dut/u_datapath/iter_cnt

run -all