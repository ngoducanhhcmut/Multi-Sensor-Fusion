// Module: Output Formatter
// Đóng gói 128 pixel RGB thành gói 3072-bit
module output_formatter (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [7:0]  R,
    input  logic [7:0]  G,
    input  logic [7:0]  B,
    input  logic        valid_in,
    output logic [3071:0] data_out,
    output logic        valid_out
);
    logic [23:0] pixel_buffer [0:127]; // Buffer cho 128 pixel
    logic [6:0]  count;                // Đếm số pixel

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count     <= 7'd0;
            valid_out <= 1'b0;
            data_out  <= 3072'd0;
        end else if (valid_in) begin
            pixel_buffer[count] <= {R, G, B};
            if (count == 7'd127) begin
                // Buffer đầy, xuất gói dữ liệu
                for (int i = 0; i < 128; i++) begin
                    data_out[i*24 +: 24] = pixel_buffer[i];
                end
                valid_out <= 1'b1;
                count     <= 7'd0;
            end else begin
                count     <= count + 1;
                valid_out <= 1'b0;
            end
        end else begin
            valid_out <= 1'b0;
        end
    end
endmodule
