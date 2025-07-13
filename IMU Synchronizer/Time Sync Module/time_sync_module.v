// Time Sync Module
module time_sync_module (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [127:0] data_in,
    input  logic        valid_in,
    input  logic [63:0] ref_time,
    input  logic [15:0] time_offset,
    output logic [127:0] data_out,
    output logic        valid_out
);
    logic [63:0] adjusted_time;
    assign adjusted_time = data_in[63:0] + time_offset;
    assign data_out = {data_in[127:64], adjusted_time};

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) valid_out <= 1'b0;
        else valid_out <= valid_in;
    end
endmodule