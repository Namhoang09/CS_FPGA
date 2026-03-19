module sync_bram #(
    parameter int DATA_W  = 32,    // độ rộng mỗi phần tử
    parameter int DEPTH   = 4000,  // số phần tử
    parameter     INIT_FILE = ""   // đường dẫn file khởi tạo, mặc định rỗng
)(
    input  logic                      clk,
    input  logic                      we,       // write enable
    input  logic [$clog2(DEPTH)-1:0]  addr,     // địa chỉ đọc/ghi
    input  logic [DATA_W-1:0]         din,      // data vào khi ghi
    output logic [DATA_W-1:0]         dout      // data ra khi đọc
);

    logic [DATA_W-1:0] mem [0:DEPTH-1];

    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);  // đọc file hex vào mem khi sim bắt đầu
        end
    end

    always_ff @(posedge clk) begin
        if (we) begin
            mem[addr] <= din;   // ghi: ưu tiên ghi khi we=1
        end
        dout <= mem[addr];      // đọc: luôn đọc, trễ 1 cycle
    end

endmodule