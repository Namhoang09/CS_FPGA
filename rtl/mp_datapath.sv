module mp_datapath
    import mylib::*;
(
    input  logic clk,
    input  logic rst,

    // Tín hiệu điều khiển từ FSM
    input  logic init_r,
    input  logic calc_inner,
    input  logic find_max,
    input  logic update_coef,
    input  logic update_r,

    // Tín hiệu đếm từ FSM
    input  logic [$clog2(NE)-1:0]   col_idx,
    input  logic [$clog2(M+1)-1:0]  row_idx,

    // Output
    output logic signed [COEF_W-1:0] coef [0:NE-1]
);

    // ── Delay 1 cycle để bù BRAM latency ────────────────────────────
    logic [$clog2(M+1)-1:0] row_idx_d1;
    logic [$clog2(NE)-1:0]  col_idx_d1;
    logic                   calc_inner_d1;  // delay 1 cycle để lọc cycle đầu tiên
    logic                   update_r_d1;

    always_ff @(posedge clk) begin
        row_idx_d1      <= row_idx;
        col_idx_d1      <= col_idx;
        calc_inner_d1   <= calc_inner;
        update_r_d1     <= update_r;
    end

    // ── BRAM địa chỉ ────────────────────────────────────────────────
    logic [$clog2(NE*M)-1:0]   theta_addr;
    logic [$clog2(M)-1:0]      po_addr;
    logic signed [THETA_W-1:0] theta_dout;
    logic signed [PO_W-1:0]    po_dout;

    // ── BRAM instances ───────────────────────────────────────────────
    sync_bram #(
        .DATA_W    (PO_W),
        .DEPTH     (M),
        .INIT_FILE ("data/po_vector.txt")
    ) bram_po (
        .clk  (clk),
        .we   (1'b0),
        .addr (po_addr),
        .din  ('0),
        .dout (po_dout)
    );

    sync_bram #(
        .DATA_W    (THETA_W),
        .DEPTH     (NE * M),
        .INIT_FILE ("data/theta_matrix.txt")
    ) bram_theta (
        .clk  (clk),
        .we   (1'b0),
        .addr (theta_addr),
        .din  ('0),
        .dout (theta_dout)
    );

    // ── Registers nội bộ ───────────────────────────────────────────
    logic signed [ACC_W-1:0]   r            [0:M-1];   // residual
    logic signed [ACC_W-1:0]   inner_acc;              // tích lũy 1 cột
    logic signed [ACC_W-1:0]   inner_result [0:NE-1];  // kết quả tất cả cột
    logic [$clog2(NE)-1:0]     best_col;               // cột tốt nhất
    logic signed [ACC_W-1:0]   best_val;               // giá trị abs lớn nhất
    logic signed [COEF_W-1:0]  alpha;                  // hệ số cập nhật

    // Khi UPDATE_R: dùng best_col làm địa chỉ cột
    // Các state khác: dùng col_idx bình thường
    assign theta_addr = update_r ? (best_col * M + row_idx[$clog2(M)-1:0]) : (col_idx  * M + row_idx[$clog2(M)-1:0]);

    // Dùng row_idx trực tiếp để đưa địa chỉ sớm nhất có thể
    assign po_addr = row_idx[$clog2(M)-1:0];

    // Tính abs ngay trong cycle hiện tại, không cần delay
    logic signed [ACC_W-1:0] abs_val;
    assign abs_val = inner_result[col_idx][ACC_W-1] ? -inner_result[col_idx] :  inner_result[col_idx];

    // ── Toàn bộ logic sequential trong 1 khối ──────────────────────
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int i = 0; i < M;  i++) r[i]               <= '0;
            for (int i = 0; i < NE; i++) coef[i]            <= '0;
            for (int i = 0; i < NE; i++) inner_result[i]    <= '0;
            inner_acc <= '0;
            best_col  <= '0;
            best_val  <= '0;
            alpha     <= '0;

        end else begin

            // ── INIT_R ───────────────────────────────────────────────
            // Điều kiện: init_r=1 VÀ không phải cycle đầu (row_idx != 0)
            // Cycle đầu: row_idx=0 → po_dout còn rác, chưa ghi
            // Từ cycle 2 trở đi: row_idx_d1 là index đúng, po_dout là data đúng
            if (init_r && row_idx != 0)
                r[row_idx_d1[$clog2(M)-1:0]] <= {{(ACC_W-PO_W){po_dout[PO_W-1]}}, po_dout};
                // sign-extend PO_W → ACC_W

            // ── CALC_INNER ────────────────────────────────────────────────────────
            // Điều kiện tích lũy:
            //   calc_inner_d1 == 1 : bỏ cycle đầu (BRAM còn data của state trước)
            //   row_idx_d1 < M     : bỏ cycle flush giữa các cột (row_d1 == M)
            if (calc_inner && calc_inner_d1 && row_idx_d1 < M) begin

                if (row_idx_d1 == 0)
                    // Bắt đầu cột mới: reset accumulator
                    inner_acc <= ACC_W'(signed'(theta_dout)) * r[0];
                else
                    // Cộng dồn các hàng tiếp theo
                    inner_acc <= inner_acc + ACC_W'(signed'(theta_dout)) * r[row_idx_d1[$clog2(M)-1:0]];

                // Lưu kết quả khi tích lũy xong hàng cuối
                // Phải tính tổng cuối explicit vì inner_acc chưa được cập nhật
                // (non-blocking: inner_acc vẫn là giá trị CŨ tại đây)
                if (row_idx_d1 == M-1)
                    inner_result[col_idx_d1] <= inner_acc + ACC_W'(signed'(theta_dout)) * r[M-1];
            end

            // ── FIND_MAX ──────────────────────────────────────────────────────────
            if (find_max) begin
                if (col_idx == 0) begin
                    // Khởi tạo bằng cột 0
                    best_col <= 0;
                    best_val <= inner_result[0][ACC_W-1] ? -inner_result[0] :  inner_result[0];
                end else if (abs_val > best_val) begin
                    // Cập nhật nếu tìm được giá trị lớn hơn
                    best_val <= abs_val;
                    best_col <= col_idx[$clog2(NE)-1:0];
                end
            end

            // ── UPDATE_COEF ───────────────────────────────────────────────────────
            if (update_coef) begin
                // Tính alpha và lưu lại để UPDATE_R dùng
                alpha <= COEF_W'(inner_result[best_col] >>> NORM_SHIFT);

                // Cập nhật coef — tính lại expression vì alpha chưa cập nhật (non-blocking)
                coef[best_col] <= coef[best_col] + COEF_W'(inner_result[best_col] >>> NORM_SHIFT);
            end

            // ── UPDATE_R ─────────────────────────────────────────────
            // update_r_d1: lọc cycle đầu (BRAM data cũ)
            // row_idx_d1 < M: lọc cycle flush cuối
            if (update_r && update_r_d1 && row_idx_d1 < M)
                r[row_idx_d1[$clog2(M)-1:0]] <= r[row_idx_d1[$clog2(M)-1:0]] - ACC_W'(signed'(alpha)) * ACC_W'(signed'(theta_dout));

        end
    end

endmodule