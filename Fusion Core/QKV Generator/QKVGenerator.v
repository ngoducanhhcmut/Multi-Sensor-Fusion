module QKV_Generator (
    input  wire [255:0] normalized_vector,
    input  wire [15:0] W_q [0:11][0:15],  // Trọng số từ bên ngoài
    input  wire [15:0] W_k [0:11][0:15],
    input  wire [15:0] W_v [0:11][0:15],
    output wire [191:0] Q, K, V,
    output wire [2:0]   overflow  // Cờ tràn số
);
    wire signed [15:0] x [0:15];
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin
            assign x[i] = normalized_vector[16*i + 15 : 16*i];
        end
    endgenerate

    reg signed [39:0] accum_q [0:11];
    reg signed [39:0] accum_k [0:11];
    reg signed [39:0] accum_v [0:11];
    reg [2:0] ovf_flags;

    always_comb begin
        ovf_flags = 3'b0;
        for (int j = 0; j < 12; j = j + 1) begin
            accum_q[j] = 0;
            accum_k[j] = 0;
            accum_v[j] = 0;
            for (int k = 0; k < 16; k = k + 1) begin
                accum_q[j] = accum_q[j] + ($signed(W_q[j][k]) * $signed(x[k]));
                accum_k[j] = accum_k[j] + ($signed(W_k[j][k]) * $signed(x[k]));
                accum_v[j] = accum_v[j] + ($signed(W_v[j][k]) * $signed(x[k]));
            end
            // Kiểm tra tràn số cho 16-bit
            if (accum_q[j] > 32767 || accum_q[j] < -32768) ovf_flags[0] = 1'b1;
            if (accum_k[j] > 32767 || accum_k[j] < -32768) ovf_flags[1] = 1'b1;
            if (accum_v[j] > 32767 || accum_v[j] < -32768) ovf_flags[2] = 1'b1;
        end
    end

    generate
        for (i = 0; i < 12; i = i + 1) begin
            assign Q[16*i + 15 : 16*i] = (accum_q[i] > 32767) ? 32767 :
                                         (accum_q[i] < -32768) ? -32768 : accum_q[i][15:0];
            assign K[16*i + 15 : 16*i] = (accum_k[i] > 32767) ? 32767 :
                                         (accum_k[i] < -32768) ? -32768 : accum_k[i][15:0];
            assign V[16*i + 15 : 16*i] = (accum_v[i] > 32767) ? 32767 :
                                         (accum_v[i] < -32768) ? -32768 : accum_v[i][15:0];
        end
    endgenerate
    assign overflow = ovf_flags;
endmodule