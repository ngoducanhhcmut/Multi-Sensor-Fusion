module QKV_Generator (
    input  wire [255:0] normalized_vector,
    input  wire [15:0] W_q [0:5][0:15],   // 6x16 weight matrices for 6x32-bit output
    input  wire [15:0] W_k [0:5][0:15],
    input  wire [15:0] W_v [0:5][0:15],
    output wire [191:0] Q, K, V,          // 6x32-bit outputs (192-bit total)
    output wire [2:0]   overflow          // Overflow flags
);
    wire signed [15:0] x [0:15];
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin
            assign x[i] = normalized_vector[16*i + 15 : 16*i];
        end
    endgenerate

    reg signed [39:0] accum_q [0:5];   // 6 outputs for 6x32-bit
    reg signed [39:0] accum_k [0:5];
    reg signed [39:0] accum_v [0:5];
    reg [2:0] ovf_flags;

    always_comb begin
        ovf_flags = 3'b0;
        for (int j = 0; j < 6; j = j + 1) begin   // 6 outputs
            accum_q[j] = 0;
            accum_k[j] = 0;
            accum_v[j] = 0;
            for (int k = 0; k < 16; k = k + 1) begin
                accum_q[j] = accum_q[j] + ($signed(W_q[j][k]) * $signed(x[k]));
                accum_k[j] = accum_k[j] + ($signed(W_k[j][k]) * $signed(x[k]));
                accum_v[j] = accum_v[j] + ($signed(W_v[j][k]) * $signed(x[k]));
            end
            // Check for 32-bit overflow
            if (accum_q[j] > 2147483647 || accum_q[j] < -2147483648) ovf_flags[0] = 1'b1;
            if (accum_k[j] > 2147483647 || accum_k[j] < -2147483648) ovf_flags[1] = 1'b1;
            if (accum_v[j] > 2147483647 || accum_v[j] < -2147483648) ovf_flags[2] = 1'b1;
        end
    end

    generate
        for (i = 0; i < 6; i = i + 1) begin  // 6 outputs of 32-bit each
            assign Q[32*i + 31 : 32*i] = (accum_q[i] > 2147483647) ? 2147483647 :
                                         (accum_q[i] < -2147483648) ? -2147483648 : accum_q[i][31:0];
            assign K[32*i + 31 : 32*i] = (accum_k[i] > 2147483647) ? 2147483647 :
                                         (accum_k[i] < -2147483648) ? -2147483648 : accum_k[i][31:0];
            assign V[32*i + 31 : 32*i] = (accum_v[i] > 2147483647) ? 2147483647 :
                                         (accum_v[i] < -2147483648) ? -2147483648 : accum_v[i][31:0];
        end
    endgenerate
    assign overflow = ovf_flags;
endmodule