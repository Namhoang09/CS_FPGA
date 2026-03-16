`timescale 1ns/1ps

module mp_datapath #(
    parameter int M         = 20,   // Số hàng (số mẫu PD)
    parameter int NE        = 200,  // Số cột (cửa sổ phơi sáng)
    parameter int K         = 7,    // Số vòng lặp tối đa
    parameter int THETA_W   = 32,   // Độ rộng bit Theta
    parameter int PO_W      = 32,   // Độ rộng bit Po
    parameter int ACC_W     = 64,   // Độ rộng bộ tích lũy
    parameter int COEF_W    = 32    // Độ rộng hệ số đầu ra
)(
    input  logic clk,
    input  logic rst_n,

    // --- Cổng điều khiển từ FSM (Control Inputs) ---
    input  logic clr_all,       // Xóa bộ đếm và reset thanh ghi
    input  logic ena_corr,      // Kích hoạt tính tương quan
    input  logic ena_argmax,    // Kích hoạt tìm Argmax
    input  logic ena_alpha,     // Kích hoạt tính Alpha
    input  logic ena_coef,      // Kích hoạt cập nhật Coef
    input  logic ena_resid,     // Kích hoạt tính phần dư r
    input  logic iter_inc,      // Tăng biến đếm vòng lặp

    // --- Cờ báo trạng thái gửi về FSM (Status Outputs) ---
    output logic corr_done,
    output logic argmax_done,
    output logic resid_done,
    output logic iter_done,

    // --- Cổng giao tiếp với BRAM chứa Theta ---
    output logic [$clog2(M*NE)-1:0]  theta_raddr,
    input  logic signed [THETA_W-1:0] theta_rdata,

    // --- Cổng nạp dữ liệu Po từ Testbench (Setup Interface) ---
    input  logic                    po_we,
    input  logic [$clog2(M)-1:0]    po_waddr,
    input  logic signed [PO_W-1:0]  po_wdata,

    // --- Đầu ra kết quả ---
    output logic signed [COEF_W-1:0] coef [0:NE-1]
);

    // Các hằng số độ rộng bit
    localparam int ADDR_W = $clog2(M * NE);
    localparam int J_W    = $clog2(NE);
    localparam int M_W    = $clog2(M);
    localparam int K_W    = $clog2(K);

    // Mảng bộ nhớ nội bộ (Registers)
    logic signed [PO_W-1:0]  po_mem   [0:M-1];    // Lưu tín hiệu ban đầu
    logic signed [ACC_W-1:0] r_mem    [0:M-1];    // Vector phần dư r
    logic signed [ACC_W-1:0] corr_mem [0:NE-1];   // Vector tương quan

    // Các biến đếm (Counters)
    logic [J_W-1:0] j_cnt;
    logic [M_W-1:0] m_cnt;
    logic [K_W-1:0] iter_cnt;

    // Các biến lưu giá trị tính toán
    logic signed [ACC_W-1:0] corr_acc; // Bộ cộng dồn MAC
    logic signed [ACC_W-1:0] max_abs;  // Lưu giá trị tuyệt đối lớn nhất
    logic [J_W-1:0]          best_j;   // Chỉ số j* tìm được
    logic signed [ACC_W-1:0] alpha;    // Bước cập nhật hệ số

    // BIẾN QUAN TRỌNG NHẤT: Pha đọc BRAM (0: Cấp địa chỉ, 1: Tính MAC)
    logic mac_phase;

    // Quá trình nạp Po từ bên ngoài vào
    always_ff @(posedge clk) begin
        if (po_we) begin
            po_mem[po_waddr] <= po_wdata;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            j_cnt      <= '0;
            m_cnt      <= '0;
            iter_cnt   <= '0;
            corr_acc   <= '0;
            max_abs    <= '0;
            best_j     <= '0;
            alpha      <= '0;
            mac_phase  <= 1'b0;
            for (int i = 0; i < NE; i++) begin
                coef[i]     <= '0;
                corr_mem[i] <= '0;
            end
            for (int i = 0; i < M; i++) r_mem[i] <= '0;

        end else begin
            // ---------------------------------------------------------
            // 1. CLR_ALL: Khởi tạo dữ liệu khi có lệnh start từ FSM
            // ---------------------------------------------------------
            if (clr_all) begin
                j_cnt      <= '0;
                m_cnt      <= '0;
                iter_cnt   <= '0;
                corr_acc   <= '0;
                max_abs    <= '0;
                best_j     <= '0;
                mac_phase  <= 1'b0;
                for (int i = 0; i < M; i++) begin
                    r_mem[i] <= ACC_W'(signed'(po_mem[i])); // Nạp Po vào r
                end
                for (int i = 0; i < NE; i++) begin
                    coef[i] <= '0; // Reset hệ số
                end
            end

            // ---------------------------------------------------------
            // 2. CORR: Tính tương quan với kỹ thuật Pipelining 2 pha
            // ---------------------------------------------------------
            if (ena_corr) begin
                if (mac_phase == 1'b0) begin
                    // Pha 0: Gửi địa chỉ cho BRAM
                    theta_raddr <= ADDR_W'(m_cnt) * ADDR_W'(NE) + ADDR_W'(j_cnt);
                    mac_phase   <= 1'b1; // Chuyển pha
                end else begin
                    // Pha 1: BRAM trả dữ liệu, thực hiện nhân cộng (MAC)
                    if (m_cnt == M_W'(M-1)) begin
                        // Hàng cuối cùng: lưu vào mảng corr_mem, reset m, tăng j
                        corr_mem[j_cnt] <= corr_acc + ACC_W'(theta_rdata) * r_mem[m_cnt];
                        corr_acc <= '0;
                        m_cnt    <= '0;
                        j_cnt    <= j_cnt + 1'b1;
                    end else begin
                        // Tích lũy bình thường
                        corr_acc <= corr_acc + ACC_W'(theta_rdata) * r_mem[m_cnt];
                        m_cnt    <= m_cnt + 1'b1;
                    end
                    mac_phase <= 1'b0; // Quay lại pha 0 cho mẫu tiếp theo
                end
            end

            // ---------------------------------------------------------
            // 3. ARGMAX: Tìm giá trị tuyệt đối lớn nhất
            // ---------------------------------------------------------
            if (ena_argmax) begin
                logic signed [ACC_W-1:0] current_abs;
                // Tính giá trị tuyệt đối
                current_abs = (corr_mem[j_cnt][ACC_W-1]) ? -corr_mem[j_cnt] : corr_mem[j_cnt];
                
                if (current_abs > max_abs) begin
                    max_abs <= current_abs;
                    best_j  <= j_cnt;
                end
                
                j_cnt <= j_cnt + 1'b1;
            end

            // ---------------------------------------------------------
            // 4. ALPHA: Tính bước cập nhật
            // Lưu ý: Đã loại bỏ phép chia do giả định ma trận Theta 
            // được chuẩn hóa (norm_sq ≈ 1) bằng Python từ trước.
            // ---------------------------------------------------------
            if (ena_alpha) begin
                alpha <= corr_mem[best_j];
            end

            // ---------------------------------------------------------
            // 5. COEF_UPD: Cập nhật hệ số
            // ---------------------------------------------------------
            if (ena_coef) begin
                coef[best_j] <= coef[best_j] + COEF_W'(alpha);
            end

            // ---------------------------------------------------------
            // 6. RESID: Cập nhật lại vector phần dư (Cũng dùng 2 pha như CORR)
            // ---------------------------------------------------------
            if (ena_resid) begin
                if (mac_phase == 1'b0) begin
                    // Pha 0: Gửi địa chỉ cột j*
                    theta_raddr <= ADDR_W'(m_cnt) * ADDR_W'(NE) + ADDR_W'(best_j);
                    mac_phase   <= 1'b1;
                end else begin
                    // Pha 1: Nhận dữ liệu và trừ đi
                    r_mem[m_cnt] <= r_mem[m_cnt] - ACC_W'(theta_rdata) * alpha;
                    m_cnt        <= m_cnt + 1'b1;
                    mac_phase    <= 1'b0;
                end
            end

            // ---------------------------------------------------------
            // 7. ITER_INC: Tăng vòng lặp
            // ---------------------------------------------------------
            if (iter_inc) begin
                iter_cnt  <= iter_cnt + 1'b1;
                // Reset lại các biến chuẩn bị cho vòng lặp mới
                j_cnt     <= '0;
                m_cnt     <= '0;
                corr_acc  <= '0;
                max_abs   <= '0;
                best_j    <= '0;
                mac_phase <= 1'b0;
            end
        end
    end

    // Cờ báo hiệu dựa trên trạng thái biến đếm
    always_comb begin
        // CORR xong khi duyệt hết dòng M-1, cột NE-1 và ở pha 1
        corr_done   = (ena_corr && m_cnt == M_W'(M-1) && j_cnt == J_W'(NE-1) && mac_phase == 1'b1);
        
        // ARGMAX xong khi duyệt hết cột NE-1
        argmax_done = (ena_argmax && j_cnt == J_W'(NE-1));
        
        // RESID xong khi duyệt hết dòng M-1 và ở pha 1
        resid_done  = (ena_resid && m_cnt == M_W'(M-1) && mac_phase == 1'b1);
        
        // Hoàn thành khi chạm mốc K vòng lặp
        iter_done   = (iter_cnt == K_W'(K-1));
    end

endmodule