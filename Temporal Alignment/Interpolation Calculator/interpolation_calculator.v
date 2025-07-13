// ==========================================================
// Interpolation Calculator (fixed-point)
// ==========================================================
module interpolation_calculator #(
    parameter DATA_WIDTH = 512
)(
    input clk,
    input rst_n,
    input [63:0] t_common,
    input [DATA_WIDTH+63:0] packet1,
    input [DATA_WIDTH+63:0] packet2,
    input start,
    output logic [DATA_WIDTH-1:0] interpolated_data,
    output logic valid,
    output logic error
);

    logic [63:0] ts1, ts2;
    logic [DATA_WIDTH-1:0] data1, data2;
    logic [31:0] ratio;
    
    assign ts1 = packet1[DATA_WIDTH +: 64];
    assign ts2 = packet2[DATA_WIDTH +: 64];
    assign data1 = packet1[0 +: DATA_WIDTH];
    assign data2 = packet2[0 +: DATA_WIDTH];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            interpolated_data <= 0;
            valid <= 0;
            error <= 0;
        end else if (start) begin
            valid <= 0;
            error <= 0;
            if (ts1 == t_common) begin
                interpolated_data <= data1;
                valid <= 1;
            end else if (ts2 == t_common) begin
                interpolated_data <= data2;
                valid <= 1;
            end else if (ts1 > t_common || ts2 < t_common) begin
                error <= 1;
            end else if (ts1 == ts2) begin
                interpolated_data <= data1;
                valid <= 1;
                error <= (ts1 != t_common);
            end else begin
                ratio = ((t_common - ts1) << 16) / (ts2 - ts1);
                for (int i = 0; i < DATA_WIDTH/32; i++) begin
                    logic [31:0] val1 = data1[i*32 +: 32];
                    logic [31:0] val2 = data2[i*32 +:32];
                    logic signed [31:0] delta = val2 - val1;
                    interpolated_data[i*32 +: 32] = val1 + ((delta * ratio) >> 16);
                end
                valid <= 1;
            end
        end else begin
            valid <= 0;
        end
    end
endmodule