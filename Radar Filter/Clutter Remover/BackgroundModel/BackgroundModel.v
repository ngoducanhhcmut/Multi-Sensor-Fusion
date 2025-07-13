module BackgroundModel #(
    parameter N = 16  // Kích thước cửa sổ, phải là lũy thừa của 2
) (
    input  wire clk,                     // Xung nhịp
    input  wire reset,                   // Tín hiệu reset
    input  wire valid_in,                // Tín hiệu hợp lệ đầu vào
    input  wire [15:0] intensity,        // Cường độ đầu vào
    output reg  [15:0] threshold         // Ngưỡng nhiễu
);
    initial begin
        if ((N & (N - 1)) != 0) begin
            $error("N must be a power of 2");
        end
    end
    reg [15:0] buffer [0:N-1];
    reg [31:0] sum = 0;
    reg [$clog2(N)-1:0] wptr = 0;
    reg [N-1:0] valid_buffer = 0;
    localparam SHIFT = $clog2(N);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wptr <= 0;
            sum <= 0;
            valid_buffer <= 0;
            threshold <= 16'h00FF;  // Ngưỡng mặc định
        end else if (valid_in) begin
            if (valid_buffer[wptr]) begin
                sum <= sum - buffer[wptr] + intensity;
            end else begin
                sum <= sum + intensity;
            end
            buffer[wptr] <= intensity;
            valid_buffer[wptr] <= 1'b1;
            wptr <= (wptr == N-1) ? 0 : wptr + 1;
            if (&valid_buffer) begin
                threshold <= sum >> SHIFT;
            end else begin
                threshold <= 16'h00FF;  // Giữ ngưỡng mặc định
            end
        end
    end
endmodule