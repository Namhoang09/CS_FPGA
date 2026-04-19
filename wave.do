# ── Xóa wave window cũ nếu có ───────────────────────────────────────
delete wave *

# ── Nhóm 1: Clock & Control ─────────────────────────────────────────
add wave -divider "Clock & Reset"
add wave -label clk    sim:/tb_mp_top/clk
add wave -label rst    sim:/tb_mp_top/rst
add wave -label start  sim:/tb_mp_top/start
add wave -label done   sim:/tb_mp_top/done

# ── Nhóm 2: FSM State ───────────────────────────────────────────────
add wave -divider "FSM"
add wave -radix symbolic -label state   sim:/tb_mp_top/u_dut/u_fsm/state
add wave -radix unsigned -label iter    sim:/tb_mp_top/u_dut/u_fsm/iter
add wave -radix unsigned -label col_idx sim:/tb_mp_top/u_dut/u_fsm/col_idx
add wave -radix unsigned -label row_idx sim:/tb_mp_top/u_dut/u_fsm/row_idx

# ── Nhóm 3: Tín hiệu điều khiển ─────────────────────────────────────
add wave -divider "Control signals"
add wave -label init_r      sim:/tb_mp_top/u_dut/u_fsm/init_r
add wave -label calc_inner  sim:/tb_mp_top/u_dut/u_fsm/calc_inner
add wave -label find_max    sim:/tb_mp_top/u_dut/u_fsm/find_max
add wave -label update_coef sim:/tb_mp_top/u_dut/u_fsm/update_coef
add wave -label update_r    sim:/tb_mp_top/u_dut/u_fsm/update_r

# ── Nhóm 4: Datapath — tích lũy coef ────────────────────────────────
add wave -divider "Datapath"
add wave -radix decimal  -label inner_acc sim:/tb_mp_top/u_dut/u_datapath/inner_acc
add wave -radix unsigned -label best_col  sim:/tb_mp_top/u_dut/u_datapath/best_col
add wave -radix decimal  -label best_val  sim:/tb_mp_top/u_dut/u_datapath/best_val
add wave -radix decimal  -label alpha     sim:/tb_mp_top/u_dut/u_datapath/alpha

# ── Nhóm 5: Coef output ──────────────────────────────────────────────
add wave -divider "Coef tich luy (best_col)"
add wave -radix decimal -label "coef(0)"  sim:/tb_mp_top/u_dut/u_datapath/coef(0)
add wave -radix decimal -label "coef(19)" sim:/tb_mp_top/u_dut/u_datapath/coef(19)
add wave -radix decimal -label "coef(21)" sim:/tb_mp_top/u_dut/u_datapath/coef(21)

# Chạy đến khi $finish
run -all