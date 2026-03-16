`timescale 1ns/1ps

module sync_bram #(
    parameter int DATA_W = 32,
    parameter int ADDR_W = 12
)(
    input  logic              clk,
    input  logic              we,      // Write enable
    input  logic [ADDR_W-1:0] waddr,   // Write address
    input  logic [DATA_W-1:0] wdata,   // Write data
    input  logic [ADDR_W-1:0] raddr,   // Read address
    output logic [DATA_W-1:0] rdata    // Read data (đầu ra đồng bộ)
);

    // Khai báo mảng bộ nhớ RAM
    logic [DATA_W-1:0] ram_array [0:(1<<ADDR_W)-1];

    // Quá trình ghi và đọc phải nằm chung trong 1 block đồng bộ với clock
    always_ff @(posedge clk) begin
        // Ghi dữ liệu
        if (we) begin
            ram_array[waddr] <= wdata;
        end
        
        // Đọc dữ liệu: rdata sẽ được cập nhật ở sườn lên của nhịp clock tiếp theo
        rdata <= ram_array[raddr];
    end

endmodule