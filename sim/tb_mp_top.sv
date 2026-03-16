`timescale 1ns/1ps

module tb_mp_top();

    // ------------------------------------------------------------------
    // Tham số hệ thống (Phải khớp với file Top)
    // ------------------------------------------------------------------
    localparam int M         = 20;   // Số hàng (số mẫu PD)
    localparam int NE        = 200;  // Số cột (cửa sổ phơi sáng)
    localparam int K         = 7;    // Số vòng lặp
    localparam int THETA_W   = 32;
    localparam int PO_W      = 32;
    localparam int ACC_W     = 64;
    localparam int COEF_W    = 32;

    // ------------------------------------------------------------------
    // Khai báo dây dẫn nối vào DUT (Device Under Test)
    // ------------------------------------------------------------------
    logic clk;
    logic rst_n;
    logic start;

    logic                      theta_we;
    logic [$clog2(M*NE)-1:0]   theta_waddr;
    logic signed [THETA_W-1:0] theta_wdata;

    logic                      po_we;
    logic [$clog2(M)-1:0]      po_waddr;
    logic signed [PO_W-1:0]    po_wdata;

    logic signed [COEF_W-1:0]  coef [0:NE-1];
    logic                      done;

    // Biến phụ cho mô phỏng
    integer fd, code, i;

    // ------------------------------------------------------------------
    // Gọi module phần cứng ra để test (Instantiate DUT)
    // ------------------------------------------------------------------
    mp_top #(
        .M(M), .NE(NE), .K(K),
        .THETA_W(THETA_W), .PO_W(PO_W), .ACC_W(ACC_W), .COEF_W(COEF_W)
    ) dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (start),
        .theta_we    (theta_we),
        .theta_waddr (theta_waddr),
        .theta_wdata (theta_wdata),
        .po_we       (po_we),
        .po_waddr    (po_waddr),
        .po_wdata    (po_wdata),
        .coef        (coef),
        .done        (done)
    );

    // ------------------------------------------------------------------
    // Tạo xung Clock 100MHz (Chu kỳ 10ns)
    // ------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------------
    // Kịch bản Test chính
    // ------------------------------------------------------------------
    initial begin
        // 1. Khởi tạo giá trị ban đầu
        rst_n       = 0;
        start       = 0;
        theta_we    = 0;
        po_we       = 0;
        theta_waddr = 0;
        theta_wdata = 0;
        po_waddr    = 0;
        po_wdata    = 0;
        
        // 2. Nhả Reset sau 20ns
        #20 rst_n = 1;
        #10;

        $display("---------------------------------------------------");
        $display("[%0t] BAT DAU NAP DU LIEU TU PYTHON...", $time);

        // 3. Nạp ma trận Theta từ file txt
        fd = $fopen("data/theta_matrix.txt", "r");
        if (fd) begin
            for (i = 0; i < M*NE; i++) begin
                code = $fscanf(fd, "%d", theta_wdata);
                theta_waddr = i;
                theta_we = 1;
                #10; // Đợi 1 chu kỳ clock để BRAM ghi dữ liệu
            end
            theta_we = 0;
            $fclose(fd);
            $display("[%0t] Nap xong %0d phan tu Theta.", $time, M*NE);
        end else begin
            $display("LOI: Khong mo duoc data/theta_matrix.txt");
            $stop; // Dừng mô phỏng nếu thiếu file
        end

        // 4. Nạp vector Po từ file txt
        fd = $fopen("data/po_vector.txt", "r");
        if (fd) begin
            for (i = 0; i < M; i++) begin
                code = $fscanf(fd, "%d", po_wdata);
                po_waddr = i;
                po_we = 1;
                #10; // Đợi 1 chu kỳ để thanh ghi nạp dữ liệu
            end
            po_we = 0;
            $fclose(fd);
            $display("[%0t] Nap xong %0d phan tu Po.", $time, M);
        end else begin
            $display("LOI: Khong mo duoc data/po_vector.txt");
            $stop;
        end

        // 5. Kích hoạt FSM chạy thuật toán
        $display("[%0t] KICH HOAT FSM MATCHING PURSUIT...", $time);
        #20 start = 1;
        #10 start = 0; // Xung start chỉ cần rộng 1 chu kỳ clock

        // 6. Ngồi chờ cờ 'done' bật lên (Báo hiệu chạy đủ K vòng)
        wait(done == 1'b1);
        
        // 7. In kết quả mảng Coef ra màn hình
        $display("---------------------------------------------------");
        $display("[%0t] THUAT TOAN HOAN THANH! IN KET QUA:", $time);
        for (i = 0; i < NE; i++) begin
            if (coef[i] != 0) begin // Chỉ in các hệ số khác 0 (tín hiệu thưa)
                $display("   -> coef[%0d] = %0d", i, coef[i]);
            end
        end
        $display("---------------------------------------------------");
        
        // Dừng mô phỏng
        #50;
        $stop;
    end

endmodule