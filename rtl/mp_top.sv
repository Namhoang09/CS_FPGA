`timescale 1ns/1ps

module mp_top #(
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
    input  logic start,

    // --- Cổng nạp ma trận Theta (từ Testbench/DMA) ---
    input  logic                      theta_we,
    input  logic [$clog2(M*NE)-1:0]   theta_waddr,
    input  logic signed [THETA_W-1:0] theta_wdata,

    // --- Cổng nạp vector Po (từ Testbench/PD) ---
    input  logic                      po_we,
    input  logic [$clog2(M)-1:0]      po_waddr,
    input  logic signed [PO_W-1:0]    po_wdata,

    // --- Cổng xuất kết quả ---
    output logic signed [COEF_W-1:0]  coef [0:NE-1],
    output logic                      done
);

    // ------------------------------------------------------------------
    // Dây nối giữa FSM và Datapath (Control & Status)
    // ------------------------------------------------------------------
    logic clr_all, ena_corr, ena_argmax, ena_alpha, ena_coef, ena_resid, iter_inc;
    logic corr_done, argmax_done, resid_done, iter_done;

    // ------------------------------------------------------------------
    // Dây nối giữa Datapath và BRAM (Read Interface)
    // ------------------------------------------------------------------
    logic [$clog2(M*NE)-1:0]   theta_raddr;
    logic signed [THETA_W-1:0] theta_rdata;

    // ------------------------------------------------------------------
    // 1. Khởi tạo bộ nhớ BRAM chứa ma trận Theta
    // ------------------------------------------------------------------
    sync_bram #(
        .DATA_W (THETA_W),
        .ADDR_W ($clog2(M*NE))
    ) u_theta_bram (
        .clk    (clk),
        .we     (theta_we),
        .waddr  (theta_waddr),
        .wdata  (theta_wdata),
        .raddr  (theta_raddr),   // Datapath cấp địa chỉ đọc
        .rdata  (theta_rdata)    // BRAM trả dữ liệu cho Datapath
    );

    // ------------------------------------------------------------------
    // 2. Khởi tạo khối Điều khiển (FSM)
    // ------------------------------------------------------------------
    mp_fsm u_fsm (
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (start),
        
        // Tín hiệu vào (Status từ Datapath)
        .corr_done   (corr_done),
        .argmax_done (argmax_done),
        .resid_done  (resid_done),
        .iter_done   (iter_done),
        
        // Tín hiệu ra (Control cấp cho Datapath)
        .clr_all     (clr_all),
        .ena_corr    (ena_corr),
        .ena_argmax  (ena_argmax),
        .ena_alpha   (ena_alpha),
        .ena_coef    (ena_coef),
        .ena_resid   (ena_resid),
        .iter_inc    (iter_inc),
        .done        (done)
    );

    // ------------------------------------------------------------------
    // 3. Khởi tạo khối Tính toán (Datapath)
    // ------------------------------------------------------------------
    mp_datapath #(
        .M       (M),
        .NE      (NE),
        .K       (K),
        .THETA_W (THETA_W),
        .PO_W    (PO_W),
        .ACC_W   (ACC_W),
        .COEF_W  (COEF_W)
    ) u_datapath (
        .clk         (clk),
        .rst_n       (rst_n),
        
        // Control từ FSM
        .clr_all     (clr_all),
        .ena_corr    (ena_corr),
        .ena_argmax  (ena_argmax),
        .ena_alpha   (ena_alpha),
        .ena_coef    (ena_coef),
        .ena_resid   (ena_resid),
        .iter_inc    (iter_inc),
        
        // Status trả về FSM
        .corr_done   (corr_done),
        .argmax_done (argmax_done),
        .resid_done  (resid_done),
        .iter_done   (iter_done),
        
        // Giao tiếp với BRAM
        .theta_raddr (theta_raddr),
        .theta_rdata (theta_rdata),
        
        // Setup từ bên ngoài
        .po_we       (po_we),
        .po_waddr    (po_waddr),
        .po_wdata    (po_wdata),
        
        // Output
        .coef        (coef)
    );

endmodule