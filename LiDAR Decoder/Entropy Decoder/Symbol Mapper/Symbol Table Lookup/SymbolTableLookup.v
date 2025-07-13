module SymbolTableLookup (
    input wire clk,
    input wire reset,
    input wire lookup_en,
    input wire [15:0] decoded_range,
    output reg [7:0] symbol_code,
    output reg lookup_valid,
    output reg lookup_error
);
    reg [15:0] range_table [0:255];
    reg [7:0] symbol_table [0:255];

    initial begin
        $readmemh("range_table.mem", range_table);
        $readmemh("symbol_table.mem", symbol_table);
    end

    reg [7:0] low, high, mid;
    reg [1:0] search_state;
    reg [15:0] current_range;

    localparam IDLE = 0, SEARCHING = 1;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            lookup_valid <= 0;
            lookup_error <= 0;
            search_state <= IDLE;
        end
        else begin
            case (search_state)
                IDLE: begin
                    if (lookup_en) begin
                        current_range <= decoded_range;
                        low <= 0;
                        high <= 255;
                        mid <= 128;
                        search_state <= SEARCHING;
                        lookup_valid <= 0;
                        lookup_error <= 0;
                    end
                end
                SEARCHING: begin
                    if (low > high) begin
                        lookup_error <= 1;
                        search_state <= IDLE;
                    end
                    else if (current_range < range_table[mid]) begin
                        if (mid == 0 || current_range >= range_table[mid-1]) begin
                            symbol_code <= symbol_table[mid];
                            lookup_valid <= 1;
                            search_state <= IDLE;
                        end
                        else begin
                            high <= mid - 1;
                            mid <= (low + mid - 1) >> 1;
                        end
                    end
                    else begin
                        low <= mid + 1;
                        mid <= (mid + 1 + high) >> 1;
                    end
                end
            endcase
        end
    end
endmodule