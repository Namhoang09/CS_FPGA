# CS_FPGA – Thiết kế RTL SystemVerilog cho đo khoảng cách bằng lấy mẫu nén

## 📌 Tổng quan

Dự án này triển khai thiết kế **RTL (Register Transfer Level)** với ngôn ngữ **SystemVerilog** nhằm thực hiện **đo khoảng cách** dựa trên kỹ thuật **lấy mẫu nén (Compressed Sensing - CS)** trên nền tảng FPGA.

Mục tiêu là giảm số lượng mẫu cần thu thập nhưng vẫn đảm bảo khả năng tái tạo tín hiệu và xác định khoảng cách chính xác.

---

## 🎯 Mục tiêu

* Thiết kế các module RTL cho hệ thống lấy mẫu nén.
* Giảm tần số lấy mẫu so với Nyquist.
* Tối ưu tài nguyên FPGA (LUT, FF, DSP).
* Đảm bảo độ chính xác trong việc ước lượng khoảng cách.

---

## 🧠 Cơ sở lý thuyết

Trong phương pháp truyền thống, tín hiệu cần được lấy mẫu theo định lý Nyquist. Tuy nhiên:

**Compressive Sampling (CS)** cho phép:

* Thu thập ít mẫu hơn
* Khôi phục tín hiệu nếu tín hiệu có tính **sparse (thưa)**

Nguyên lý:

```
y = Φx
```

Trong đó:

* `x`: tín hiệu đầu vào
* `Φ`: ma trận đo (measurement matrix)
* `y`: vector mẫu nén

Khoảng cách được suy ra từ đặc trưng của tín hiệu (ví dụ: độ trễ, vị trí đỉnh).

---

## 🏗️ Kiến trúc hệ thống

Hệ thống gồm các khối chính sau:

### 1. Khối thu nhận tín hiệu (Signal Acquisition)

* Nhận dữ liệu từ ADC
* Đồng bộ và lưu trữ tạm thời

### 2. Khối tạo ma trận đo (Measurement Matrix Generator)

* Sinh ma trận giả ngẫu nhiên hoặc xác định
* Có thể cấu hình kích thước

### 3. Khối lấy mẫu nén (Compressive Sampler)

* Thực hiện phép nhân ma trận:

  ```
  y = Φx
  ```

### 4. Bộ đệm (FIFO / Buffer)

* Lưu trữ dữ liệu nén
* Hỗ trợ đồng bộ clock nếu cần

### 5. Khối ước lượng khoảng cách (Distance Estimator)

* Phát hiện đỉnh / độ trễ tín hiệu
* Tính toán khoảng cách

### 6. Khối điều khiển (FSM Controller)

* Điều phối hoạt động toàn hệ thống
* Quản lý trạng thái: idle / run / done

---

## 📂 Cấu trúc thư mục

```
CS_FPGA/
│── rtl/
│   ├── mylib.sv
│   ├── sync_bram.sv
│   ├── mp_fsm.sv
│   ├── mp_datapath.sv
│   └── mp_top.sv
│
│── data/
│   ├── po_vector.txt
│   ├── A_matrix.txt
│   ├── norms.txt
│   ├── d_matrix.txt
│   └── coef_output.txt
│
│── sim/
│   └── tb_mp_top.sv
│
│── run_sim.do
│
└── README.md
```

---

## ⚙️ Yêu cầu

* Công cụ FPGA: Vivado / Quartus / ModelSim
* Ngôn ngữ: SystemVerilog (IEEE 1800)
* (Tuỳ chọn) MATLAB/Python để kiểm chứng thuật toán

---

## 🚀 Bắt đầu nhanh

### 1. Clone dự án

```
git clone <repo_url>
cd CS_FPGA
```

### 2. Chạy mô phỏng

```
vsim -do run_sim.do
```

### 3. Tổng hợp (Synthesis)

* Mở Vivado/Quartus
* Thêm các file trong `rtl/`
* Đặt `mp_top.sv` làm top module
* Chạy synthesis và implementation

---

## 🧪 Kiểm thử

* Testbench trong thư mục `sim/`
* Bao gồm:

  * Kiểm tra chức năng
  * Dữ liệu test ngẫu nhiên
  * Phân tích waveform

---

## 📊 Chỉ số đánh giá

* Sử dụng tài nguyên (LUT, FF, DSP)
* Độ trễ xử lý (latency)
* Tỷ lệ nén (compression ratio)
* Độ chính xác đo khoảng cách

---

## 🔧 Tùy chỉnh

* Thay đổi kích thước ma trận đo
* Điều chỉnh độ sparse của tín hiệu
* Tùy chỉnh độ sâu FIFO
* Thay đổi thuật toán ước lượng khoảng cách

---

## 📈 Hướng phát triển

* Triển khai thuật toán khôi phục (OMP, Basis Pursuit) trên FPGA
* Kết nối với phần cứng ADC/DAC thực
* Tối ưu năng lượng cho hệ thống nhúng
* Hỗ trợ xử lý thời gian thực

---

## 🤝 Đóng góp

Hoan nghênh đóng góp:

* Sửa lỗi
* Tối ưu hiệu năng
* Bổ sung testbench
* Cải thiện tài liệu

---


## 👨‍💻 Tác giả

* Đặng Hoàng Nam
* Email: [hnam910204@gmail.com](mailto:hnam910204@gmail.com)

---

## 📌 Ghi chú

* Dự án tập trung vào **thiết kế phần cứng (RTL)**.
* Việc khôi phục tín hiệu có thể thực hiện ngoài FPGA (software) để giảm độ phức tạp phần cứng.
