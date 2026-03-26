module mp_top
    import mylib::*;
(
    input  logic clk,
    input  logic rst,
    input  logic start,
    output logic done,
    output logic signed [COEF_W-1:0] coef [0:NE-1]
);

    // ── Tín hiệu nối FSM → Datapath ────────────────────────────────
    logic init_r;
    logic calc_inner;
    logic find_max;
    logic update_coef;
    logic update_r;

    // ── Tín hiệu counter từ FSM → Datapath ─────────────────────────
    logic [$clog2(NE)-1:0] col_idx;
    logic [$clog2(M+1)-1:0]  row_idx;
    logic [$clog2(K)-1:0]  iter;

    // ── Instance FSM ────────────────────────────────────────────────
    mp_fsm u_fsm (
        .clk         (clk),
        .rst         (rst),
        .start       (start),
        .done        (done),
        .init_r      (init_r),
        .calc_inner  (calc_inner),
        .find_max    (find_max),
        .update_coef (update_coef),
        .update_r    (update_r),
        .col_idx     (col_idx),
        .row_idx     (row_idx),
        .iter        (iter)
    );

    // ── Instance Datapath ───────────────────────────────────────────
    mp_datapath u_datapath (
        .clk         (clk),
        .rst         (rst),
        .init_r      (init_r),
        .calc_inner  (calc_inner),
        .find_max    (find_max),
        .update_coef (update_coef),
        .update_r    (update_r),
        .col_idx     (col_idx),
        .row_idx     (row_idx),
        .coef        (coef)
    );

endmodule