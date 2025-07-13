module Window_Buffer (
    input  logic        clk,
    input  logic        rst,
    input  logic        valid_in,       // Tín hiệu valid đầu vào
    input  logic [127:0] raw_point,
    output logic [127:0] window_out [0:4],
    output logic        buffer_full     // Báo hiệu buffer đã đầy
);

    logic [127:0] buffer [0:4];
    logic [2:0] count;             // Đếm số điểm đã nhận

    always_ff @(posedge clk) begin
        if (rst) begin
            count <= 0;
            buffer_full <= 0;
            for (int i = 0; i < 5; i++) buffer[i] <= '1; // Giá trị không hợp lệ
        end
        else if (valid_in) begin
            // Dịch chuyển buffer
            for (int i = 0; i < 4; i++) buffer[i] <= buffer[i+1];
            buffer[4] <= raw_point;
            
            // Cập nhật bộ đếm và trạng thái buffer
            count <= (count == 5) ? count : count + 1;
            buffer_full <= (count >= 4);
        end
    end

    assign window_out = buffer;
endmodule