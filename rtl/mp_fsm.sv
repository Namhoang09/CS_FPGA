`timescale 1ns/1ps

module mp_fsm (
    input  logic clk,
    input  logic rst_n,
    input  logic start,         // Tín hiệu bắt đầu từ hệ thống

    // --- Tín hiệu trạng thái (Status Flags) nhận từ Datapath ---
    input  logic corr_done,     // Báo hiệu đã tính xong toàn bộ ma trận tương quan
    input  logic argmax_done,   // Báo hiệu đã tìm xong j* lớn nhất
    input  logic resid_done,    // Báo hiệu đã cập nhật xong phần dư r
    input  logic iter_done,     // Báo hiệu đã chạy đủ K vòng lặp

    // --- Tín hiệu điều khiển (Control Signals) gửi sang Datapath ---
    output logic clr_all,       // Xóa bộ đếm và thanh ghi khi bắt đầu
    output logic ena_corr,      // Cho phép khối tính tương quan hoạt động
    output logic ena_argmax,    // Cho phép khối tìm max hoạt động
    output logic ena_alpha,     // Chốt giá trị alpha
    output logic ena_coef,      // Kích hoạt cập nhật hệ số coef[j*]
    output logic ena_resid,     // Cho phép khối tính phần dư hoạt động
    output logic iter_inc,      // Tăng bộ đếm vòng lặp
    output logic done           // Báo hiệu thuật toán đã hoàn thành
);

    // Định nghĩa các trạng thái của FSM
    typedef enum logic [2:0] {
        IDLE_ST      = 3'd0,
        CORR_ST      = 3'd1,
        ARGMAX_ST    = 3'd2,
        ALPHA_ST     = 3'd3,
        COEF_UPD_ST  = 3'd4,
        RESID_ST     = 3'd5,
        NEXT_ITER_ST = 3'd6,
        DONE_ST      = 3'd7
    } state_t;

    state_t current_state, next_state;

    // Khối 1: Cập nhật trạng thái hiện tại
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE_ST;
        end else begin
            current_state <= next_state;
        end
    end

    // Khối 2: Logic chuyển trạng thái (Next State Logic)
    always_comb begin
        // Mặc định giữ nguyên trạng thái nếu không có điều kiện rẽ nhánh
        next_state = current_state; 

        case (current_state)
            IDLE_ST: begin
                if (start) next_state = CORR_ST;
            end

            CORR_ST: begin
                // Ở lại CORR cho đến khi Datapath báo cáo tính xong (corr_done = 1)
                if (corr_done) next_state = ARGMAX_ST;
            end

            ARGMAX_ST: begin
                // Tìm max xong thì chuyển sang tính Alpha
                if (argmax_done) next_state = ALPHA_ST;
            end

            ALPHA_ST: begin
                // Bước này chỉ tốn 1 chu kỳ để gán alpha
                next_state = COEF_UPD_ST;
            end

            COEF_UPD_ST: begin
                // Cập nhật coef cũng chỉ tốn 1 chu kỳ
                next_state = RESID_ST;
            end

            RESID_ST: begin
                // Chờ cập nhật xong mảng dư r
                if (resid_done) next_state = NEXT_ITER_ST;
            end

            NEXT_ITER_ST: begin
                // Kiểm tra xem đã đủ K vòng chưa
                if (iter_done) next_state = DONE_ST;
                else           next_state = CORR_ST; // Lặp lại
            end

            DONE_ST: begin
                // Xong xuôi, quay về IDLE chờ lệnh start mới
                next_state = IDLE_ST;
            end

            default: next_state = IDLE_ST;
        endcase
    end

    // Khối 3: Logic điều khiển đầu ra (Moore FSM)
    always_comb begin
        // Mặc định tất cả các tín hiệu điều khiển đều bằng 0
        clr_all    = 1'b0;
        ena_corr   = 1'b0;
        ena_argmax = 1'b0;
        ena_alpha  = 1'b0;
        ena_coef   = 1'b0;
        ena_resid  = 1'b0;
        iter_inc   = 1'b0;
        done       = 1'b0;

        case (current_state)
            IDLE_ST: begin
                if (start) clr_all = 1'b1; // Khởi tạo lại hệ thống khi có lệnh start
            end

            CORR_ST:      ena_corr   = 1'b1; // Bật cờ cho Datapath chạy đếm m, j
            ARGMAX_ST:    ena_argmax = 1'b1; 
            ALPHA_ST:     ena_alpha  = 1'b1;
            COEF_UPD_ST:  ena_coef   = 1'b1;
            RESID_ST:     ena_resid  = 1'b1;
            
            NEXT_ITER_ST: begin
                if (!iter_done) iter_inc = 1'b1; // Bật xung tăng bộ đếm vòng lặp K
            end

            DONE_ST:      done = 1'b1; // Kéo cờ done báo cho khối Top biết đã xong
        endcase
    end
endmodule
