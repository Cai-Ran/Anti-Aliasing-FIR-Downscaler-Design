// wr_clk == rd_clk
// `define MAX_RES_TARX       //not 2 power
// fifo type: one slot left; set depth = max+1;

module tmp_row_buffer (
    input clk,
    input rst_n,
    input [7:0] in_data,
    input wr_en,
    input rd_en,
    output [7:0] out_data
);  

    reg [`MAX_ROW_LOG2-1:0] wptr, rptr;
    wire flag_empty, flag_full;

    wire write, read;
    assign write = wr_en & !flag_full;
    assign read = rd_en & !flag_empty;

    fifo buffer(.clk(clk), .wr_en(write), .rd_en(read), .w_addr(wptr), .w_data(in_data), .r_addr(rptr), .r_data(out_data));

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            wptr <= 0;
        else if (write) begin
            if (wptr==(`MAX_RES_TARX))  wptr <= 0;
            else                        wptr <= wptr + 1'b1;
        end
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            rptr <= 0;
        else if (read) begin
            if (rptr==(`MAX_RES_TARX))  rptr <= 0;
            else                        rptr <= rptr + 1'b1;
        end
    end


    assign flag_empty = (wptr==rptr);
    assign flag_full  = ((wptr+1'b1)==rptr) || (wptr==(`MAX_RES_TARX)&&(rptr==0));


endmodule




module fifo(
    input   clk,
    input   wr_en,
    input   rd_en,
    input   [`MAX_ROW_LOG2-1:0] w_addr,
    input   [7:0] w_data,
    input   [`MAX_ROW_LOG2-1:0] r_addr,
    output reg  [7:0] r_data
);
    reg [7:0] fifo [0:`MAX_RES_TARX];

    always @(posedge clk) begin
        if (wr_en)
            fifo[w_addr] <= w_data;
    end
    
    always @(posedge clk) begin
        if (rd_en)
            r_data <= fifo[r_addr];
    end

endmodule
