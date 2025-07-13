module TMR_Voter (
    input  wire [191:0] copy1, copy2, copy3,
    output wire [191:0] voted,
    output wire [11:0]  error_flags  // Cờ lỗi cho 12 từ
);
    genvar i;
    generate
        for (i = 0; i < 12; i = i + 1) begin : vote_loop
            wire [15:0] c1 = copy1[16*i + 15 : 16*i];
            wire [15:0] c2 = copy2[16*i + 15 : 16*i];
            wire [15:0] c3 = copy3[16*i + 15 : 16*i];
            reg  [15:0] voted_word;
            reg         error;

            always_comb begin
                if (c1 == c2) begin
                    voted_word = c1;
                    error = 1'b0;
                end else if (c1 == c3) begin
                    voted_word = c1;
                    error = 1'b0;
                end else if (c2 == c3) begin
                    voted_word = c2;
                    error = 1'b0;
                end else begin
                    voted_word = c1;  // Chọn mặc định
                    error = 1'b1;     // Báo lỗi
                end
            end
            assign voted[16*i + 15 : 16*i] = voted_word;
            assign error_flags[i] = error;
        end
    endgenerate
endmodule