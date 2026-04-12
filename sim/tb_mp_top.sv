`timescale 1ns/1ps

module tb_mp_top
    import mylib::*;
();

    // ── Tín hiệu ────────────────────────────────────────────────────
    logic clk, rst, start, done;
    logic signed [COEF_W-1:0] coef [0:NE-1];

    // ── Clock 100MHz ─────────────────────────────────────────────────
    initial clk = 0;
    always #5 clk = ~clk;

    // ── Instance DUT ─────────────────────────────────────────────────
    mp_top u_dut (
        .clk   (clk),
        .rst   (rst),
        .start (start),
        .done  (done),
        .coef  (coef)
    );

    // ── Kiểm tra BRAM load data ───────────────────────────
    initial begin
        #1;
        $display("=== KIEM TRA BRAM ===");
        $display("A[0]  = %0d", u_dut.u_datapath.bram_A.mem[0]);
        $display("A[1]  = %0d", u_dut.u_datapath.bram_A.mem[1]);
        $display("po[0] = %0d", u_dut.u_datapath.bram_po.mem[0]);
        $display("po[1] = %0d", u_dut.u_datapath.bram_po.mem[1]);
    end

    // ── Theo dõi FSM state ───────────────────────────────────────────
    always @(posedge clk)
        $display("t=%0t | state=%0d | row=%0d | col=%0d | iter=%0d | done=%0b",
            $time,
            u_dut.u_fsm.state,
            u_dut.u_fsm.row_idx,
            u_dut.u_fsm.col_idx,
            u_dut.u_fsm.iter,
            done);

    // ── Kịch bản test ────────────────────────────────────────────────
    initial begin
        rst   = 1;
        start = 0;

        // reset 5 cycle
        repeat(5) @(posedge clk);
        rst = 0;

        // ch�? 2 cycle rồi kích start
        repeat(2) @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // ch�? done, timeout sau 100000 cycle
        fork
            begin
                wait(done == 1);
                @(posedge clk);
                $display("=== DONE ===");
                dump_coef();
                $finish;
            end
            begin
                repeat(200000) @(posedge clk);
                $display("ERROR: Timeout - FSM khong den DONE");
                $finish;
            end
        join_any
    end

    // ── Waveform ─────────────────────────────────────────────────────
    initial begin
        $dumpfile("sim.vcd");
        $dumpvars(0, tb_mp_top);
    end

    // ── Task dump coef ───────────────────────────────────────────────
    task dump_coef();
        int fd;
        fd = $fopen("data/coef_output.txt", "w");
        if (fd == 0) begin
            $display("ERROR: Khong mo duoc file coef_output.txt");
            $finish;
        end
        for (int i = 0; i < NE; i++)
            $fdisplay(fd, "%0d", coef[i]);
        $fclose(fd);
        $display("Da ghi coef_output.txt");
    endtask

endmodule