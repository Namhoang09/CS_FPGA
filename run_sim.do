# Xóa và tạo lại thư mục work
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# ── Compile theo thứ tự phụ thuộc ──────────────────────────────
# 1. Package trước
vlog -sv rtl/mylib.sv

# 2. Module dùng chung
vlog -sv rtl/sync_bram.sv

# 3. FSM và Datapath
vlog -sv rtl/mp_fsm.sv
vlog -sv rtl/mp_datapath.sv

# 4. Top level
vlog -sv rtl/mp_top.sv

# 5. Testbench cuối cùng
vlog -sv sim/tb_mp_top.sv

# ── Chạy simulation ─────────────────────────────────────────────
vsim -t 1ps work.tb_mp_top

# Thêm tất cả signal vào waveform
add wave -recursive *

# Chạy đến khi $finish
run -all