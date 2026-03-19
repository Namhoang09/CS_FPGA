package mylib;

    // ── Kích thước ma trận ─────────────────────────────────────────
    parameter int M   = 20;   // số hàng (số phép đo)
    parameter int NE  = 200;  // số cột  (số atoms)
    parameter int K   = 7;    // số vòng lặp Matching Pursuit

    // ── Độ rộng bit ────────────────────────────────────────────────
    parameter int THETA_W = 32;  // Q2.14
    parameter int PO_W    = 32;  // Q15.0
    parameter int COEF_W  = 32;  // Q hệ số output
    parameter int ACC_W   = 64;  // accumulator, tránh overflow

    // ── Fixed-point shift ──────────────────────────────────────────
    parameter int FRAC_THETA  = 14;  // số bit thập phân của Theta
    parameter int NORM_SHIFT  = 28;  // dùng khi tính alpha = inner >> 28

endpackage