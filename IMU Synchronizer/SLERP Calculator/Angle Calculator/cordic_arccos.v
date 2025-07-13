module cordic_arccos (
    input logic clk,
    input logic rst_n,
    input logic [31:0] x,     // Giá trị đầu vào (Q16.16, trong [-1, 1])
    output logic [31:0] angle // Góc đầu ra (Q16.16, radian)
);
    parameter NSTAGES = 16;
    parameter WW = 32;
    parameter PW = 32;

    reg signed [WW-1:0] x_reg [0:NSTAGES];
    reg signed [WW-1:0] y_reg [0:NSTAGES];
    reg [PW-1:0] z_reg [0:NSTAGES];
    wire [PW-1:0] cordic_angle [0:NSTAGES-1];

    // Bảng góc CORDIC
    assign cordic_angle[0] = 32'h3243f6a9; // atan(2^0)
    assign cordic_angle[1] = 32'h1dac6705; // atan(2^-1)
    assign cordic_angle[2] = 32'h0fadbafd; // atan(2^-2)
    assign cordic_angle[3] = 32'h07f56ea7; // atan(2^-3)
    assign cordic_angle[4] = 32'h03feab77; // atan(2^-4)
    assign cordic_angle[5] = 32'h01ffd55c; // atan(2^-5)
    assign cordic_angle[6] = 32'h00fffaab; // atan(2^-6)
    assign cordic_angle[7] = 32'h007fff55; // atan(2^-7)
    assign cordic_angle[8] = 32'h003fffeb; // atan(2^-8)
    assign cordic_angle[9] = 32'h001ffffd; // atan(2^-9)
    assign cordic_angle[10] = 32'h00100000; // atan(2^-10)
    assign cordic_angle[11] = 32'h00080000; // atan(2^-11)
    assign cordic_angle[12] = 32'h00040000; // atan(2^-12)
    assign cordic_angle[13] = 32'h00020000; // atan(2^-13)
    assign cordic_angle[14] = 32'h00010000; // atan(2^-14)
    assign cordic_angle[15] = 32'h00008000; // atan(2^-15)

    // Tính toán √(1-x²)/x
    logic [31:0] x_squared, one_minus_x_squared, sqrt_term, y_init;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_squared <= 0;
            one_minus_x_squared <= 0;
            sqrt_term <= 0;
            y_init <= 0;
        end else begin
            x_squared <= (x * x) >> 16; // Q16.16
            one_minus_x_squared <= 32'h00010000 - x_squared; // 1 - x²
            sqrt_term <= sqrt_approx(one_minus_x_squared); // Cần hàm sqrt
            y_init <= (sqrt_term << 16) / x; // √(1-x²)/x
        end
    end

    // Khởi tạo giá trị ban đầu
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_reg[0] <= 0;
            y_reg[0] <= 0;
            z_reg[0] <= 0;
        end else begin
            x_reg[0] <= 32'h26dd3b6a; // Hệ số CORDIC gain
            y_reg[0] <= y_init;
            z_reg[0] <= 0;
        end
    end

    // Vòng lặp CORDIC (chế độ vectoring)
    genvar i;
    generate
        for (i = 0; i < NSTAGES; i = i + 1) begin : CORDICops
            always @(posedge clk) begin
                if (y_reg[i][WW-1]) begin
                    x_reg[i+1] <= x_reg[i] - (y_reg[i] >>> i);
                    y_reg[i+1] <= y_reg[i] + (x_reg[i] >>> i);
                    z_reg[i+1] <= z_reg[i] - cordic_angle[i];
                end else begin

                    x_reg[i+1] <= x_reg[i] + (y_reg[i] >>> i);
                    y_reg[i+1] <= y_reg[i] - (x_reg[i] >>> i);
                    z_reg[i+1] <= z_reg[i] + cordic_angle[i];
                end
            end
        end
    endgenerate

    // Đầu ra
    always @(posedge clk) begin
        angle <= z_reg[NSTAGES];
    end

    // Hàm xấp xỉ căn bậc hai (placeholder)
    function logic [31:0] sqrt_approx(input logic [31:0] val);
        // Cần triển khai hàm sqrt chính xác
        sqrt_approx = val; // Placeholder
    endfunction
endmodule