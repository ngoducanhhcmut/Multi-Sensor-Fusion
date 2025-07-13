// ==========================================================
// Time Reference Module
// ==========================================================
module time_reference (
    input clk,
    input rst_n,
    input sync_signal,
    output logic [63:0] t_common
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            t_common <= 0;
        end else if (sync_signal) begin
            t_common <= t_common + 1;
        end
    end
endmodule
