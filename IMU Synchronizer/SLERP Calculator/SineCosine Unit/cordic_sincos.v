module cordic_sincos (
    input logic clk,
    input logic rst_n,
    input logic [31:0] angle, // Góc đầu vào (Q16.16, radian)
    output logic [31:0] sin,  // Giá trị sine (Q16.16)
    output logic [31:0] cos   // Giá trị cosine (Q16.16)
);
    parameter NSTAGES = 16;
    parameter WW = 32; // Độ rộng bit
    parameter PW = 32; // Độ rộng bit của pha

    reg signed [WW-1:0] x [0:NSTAGES];
    reg signed [WW-1:0] y [0:NSTAGES];
    reg [PW-1:0] z [0:NSTAGES];
    wire [PW-1:0] cordic_angle [0:NSTAGES-1];

    // Bảng góc CORDIC (tính bằng arctan(2^-i))
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

    // Khởi tạo giá trị ban đầu
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x[0] <= 32'h26dd3b6a; // Hệ số CORDIC gain ~0.6073
            y[0] <= 0;
            z[0] <= 0;
        end else begin
            x[0] <= 32'h26dd3b6a; // Hệ số CORDIC gain
            y[0] <= 0;
            z[0] <= angle;
        end
    end

    // Vòng lặp CORDIC
    genvar i;
    generate
        for (i = 0; i < NSTAGES; i = i + 1) begin : CORDICops
            always @(posedge clk) begin
                if (z[i][PW-1]) begin
                    x[i+1] <= x[i] + (y[i] >>> i);
                    y[i+1] <= y[i] - (x[i] >>> i);
                    z[i+1] <= z[i] + cordic_angle[i];
                end else begin
                    x[i+1] <= x[i] - (y[i] >>> i);
                    y[i+1] <= y[i] + (x[i] >>> i);
                    z[i+1] <= z[i] - cordic_angle[i];
                end
            end
        end
    endgenerate

    // Đầu ra
    always @(posedge clk) begin
        cos <= x[NSTAGES];
        sin <= y[NSTAGES];
    end
endmodule