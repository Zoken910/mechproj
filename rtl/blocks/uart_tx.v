// uart_tx: manda un byte por UART (1 inicio, 8 datos LSB primero, 1 parada)
module uart_tx #(parameter CLKS_PER_BIT = 104) (
    input  wire       clk,
    input  wire       start,         // pulso: manda 'data'
    input  wire [7:0] data,
    output reg        tx   = 1,
    output reg        busy = 0
);
    reg [8:0] shift = 9'h1FF;        // {bit de parada, 8 datos}
    reg [7:0] cnt   = 0;
    reg [3:0] bitn  = 0;

    always @(posedge clk) begin
        if (!busy) begin
            tx <= 1;
            if (start) begin
                shift <= {1'b1, data}; tx <= 0; busy <= 1; cnt <= 0; bitn <= 0;
            end
        end else if (cnt < CLKS_PER_BIT-1) cnt <= cnt + 1;
        else begin
            cnt <= 0;
            if (bitn == 9) busy <= 0;
            else begin tx <= shift[0]; shift <= {1'b1, shift[8:1]}; bitn <= bitn + 1; end
        end
    end
endmodule
