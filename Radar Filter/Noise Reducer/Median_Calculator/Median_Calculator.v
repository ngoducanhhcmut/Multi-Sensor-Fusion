module Median_Calculator (
    input  logic signed [31:0] data_in [0:4],
    output logic signed [31:0] median
);

    // Định nghĩa các giai đoạn cho mạng sắp xếp
    logic signed [31:0] stage1[0:4];
    logic signed [31:0] stage2[0:4];
    logic signed [31:0] stage3[0:4];
    logic signed [31:0] stage4[0:4];
    logic signed [31:0] stage5[0:4];
    logic signed [31:0] stage6[0:4];
    logic signed [31:0] stage7[0:4];
    logic signed [31:0] stage8[0:4];
    logic signed [31:0] stage9[0:4];

    // Giai đoạn 1: So sánh và hoán đổi 0 và 1
    assign stage1[0] = (data_in[0] < data_in[1]) ? data_in[0] : data_in[1];
    assign stage1[1] = (data_in[0] < data_in[1]) ? data_in[1] : data_in[0];
    assign stage1[2] = data_in[2];
    assign stage1[3] = data_in[3];
    assign stage1[4] = data_in[4];

    // Giai đoạn 2: So sánh và hoán đổi 3 và 4
    assign stage2[0] = stage1[0];
    assign stage2[1] = stage1[1];
    assign stage2[2] = stage1[2];
    assign stage2[3] = (stage1[3] < stage1[4]) ? stage1[3] : stage1[4];
    assign stage2[4] = (stage1[3] < stage1[4]) ? stage1[4] : stage1[3];

    // Giai đoạn 3: So sánh và hoán đổi 2 và 4
    assign stage3[0] = stage2[0];
    assign stage3[1] = stage2[1];
    assign stage3[2] = (stage2[2] < stage2[4]) ? stage2[2] : stage2[4];
    assign stage3[4] = (stage2[2] < stage2[4]) ? stage2[4] : stage2[2];
    assign stage3[3] = stage2[3];

    // Giai đoạn 4: So sánh và hoán đổi 2 và 3
    assign stage4[0] = stage3[0];
    assign stage4[1] = stage3[1];
    assign stage4[2] = (stage3[2] < stage3[3]) ? stage3[2] : stage3[3];
    assign stage4[3] = (stage3[2] < stage3[3]) ? stage3[3] : stage3[2];
    assign stage4[4] = stage3[4];

    // Giai đoạn 5: So sánh và hoán đổi 1 và 4
    assign stage5[0] = stage4[0];
    assign stage5[1] = (stage4[1] < stage4[4]) ? stage4[1] : stage4[4];
    assign stage5[4] = (stage4[1] < stage4[4]) ? stage4[4] : stage4[1];
    assign stage5[2] = stage4[2];
    assign stage5[3] = stage4[3];

    // Giai đoạn 6: So sánh và hoán đổi 0 và 3
    assign stage6[0] = (stage5[0] < stage5[3]) ? stage5[0] : stage5[3];
    assign stage6[3] = (stage5[0] < stage5[3]) ? stage5[3] : stage5[0];
    assign stage6[1] = stage5[1];
    assign stage6[2] = stage5[2];
    assign stage6[4] = stage5[4];

    // Giai đoạn 7: So sánh và hoán đổi 0 và 2
    assign stage7[0] = (stage6[0] < stage6[2]) ? stage6[0] : stage6[2];
    assign stage7[2] = (stage6[0] < stage6[2]) ? stage6[2] : stage6[0];
    assign stage7[1] = stage6[1];
    assign stage7[3] = stage6[3];
    assign stage7[4] = stage6[4];

    // Giai đoạn 8: So sánh và hoán đổi 1 và 3
    assign stage8[0] = stage7[0];
    assign stage8[1] = (stage7[1] < stage7[3]) ? stage7[1] : stage7[3];
    assign stage8[3] = (stage7[1] < stage7[3]) ? stage7[3] : stage7[1];
    assign stage8[2] = stage7[2];
    assign stage8[4] = stage7[4];

    // Giai đoạn 9: So sánh và hoán đổi 1 và 2
    assign stage9[0] = stage8[0];
    assign stage9[1] = (stage8[1] < stage8[2]) ? stage8[1] : stage8[2];
    assign stage9[2] = (stage8[1] < stage8[2]) ? stage8[2] : stage8[1];
    assign stage9[3] = stage8[3];
    assign stage9[4] = stage8[4];

    // Giá trị trung vị là phần tử thứ ba trong mảng đã sắp xếp
    assign median = stage9[2];
endmodule