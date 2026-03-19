module mp_fsm 
    import mylib::*;
(
    input  logic clk,
    input  logic rst,
    input  logic start,       
    output logic done,      

    // Tín hiệu điều khiển sang datapath
    output logic init_r,      
    output logic calc_inner,
    output logic find_max,    
    output logic update_coef, 
    output logic update_r,   

    // Tín hiệu đếm
    output logic [$clog2(NE)-1:0]   col_idx,
    output logic [$clog2(M+1)-1:0]  row_idx,
    output logic [$clog2(K)-1:0]    iter     
);

    typedef enum logic [3:0] {
        IDLE,
        INIT_R,       
        CALC_INNER,  
        FIND_MAX,     
        UPDATE_COEF, 
        UPDATE_R,     
        ITER_CHECK, 
        DONE
    } state_t;

    state_t state, next;

    // ── State register ───────────────────────────────────────────────
    always_ff @(posedge clk or posedge rst) begin
        if (rst) state <= IDLE;
        else     state <= next;
    end

    // ── Next state logic ─────────────────────────────────────────────
    always_comb begin
        next = state;
        case (state)
            IDLE:       if (start)              next = INIT_R;
            INIT_R:     if (row_idx == M)       next = CALC_INNER;
            CALC_INNER: if (col_idx == NE-1 &&
                            row_idx == M)       next = FIND_MAX;
            FIND_MAX:   if (col_idx == NE-1)    next = UPDATE_COEF;
            UPDATE_COEF:                        next = UPDATE_R;
            UPDATE_R:   if (row_idx == M)       next = ITER_CHECK;
            ITER_CHECK: if (iter == K-1)        next = DONE;
                        else                    next = CALC_INNER;
            DONE:                               next = IDLE;
            default:                            next = IDLE;
        endcase
    end

    // ── Output logic (control signals) ───────────────────────────────
    always_comb begin
        init_r      = 0;
        calc_inner  = 0;
        find_max    = 0;
        update_coef = 0;
        update_r    = 0;
        done        = 0;

        case (state)
            INIT_R:      init_r      = 1;
            CALC_INNER:  calc_inner  = 1;
            FIND_MAX:    find_max    = 1;
            UPDATE_COEF: update_coef = 1;
            UPDATE_R:    update_r    = 1;
            DONE:        done        = 1;
        endcase
    end

    // ── Counter logic ────────────────────────────────────────────────
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            row_idx <= 0;
            col_idx <= 0;
            iter    <= 0;
        end else case (state)
            INIT_R: 
                // đếm từ 0 → M (M+1 cycles), sau đó reset về 0
                row_idx <= (row_idx == M) ? 0 : row_idx + 1;

            CALC_INNER: begin
                // đếm hàng trong cột trước, rồi sang cột kế
                if (row_idx == M) begin
                    row_idx <= 0;
                    col_idx <= (col_idx == NE-1) ? 0 : col_idx + 1; // reset về 0 trước khi vào FIND_MAX
                end else
                    row_idx <= row_idx + 1;
            end

            FIND_MAX:
                // quét 0 → NE-1 rồi reset về 0
                col_idx <= (col_idx == NE-1) ? 0 : col_idx + 1;

            // UPDATE_COEF: không đếm gì

            UPDATE_R:
                // giống INIT_R, cần M+1 cycles
                row_idx <= (row_idx == M) ? 0 : row_idx + 1;

            ITER_CHECK: begin
                // reset counter chuẩn bị cho vòng lặp tiếp theo
                col_idx <= 0;
                row_idx <= 0;
                iter    <= iter + 1;
            end

            DONE: iter <= 0;
        endcase
    end

endmodule