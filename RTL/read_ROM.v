module read_ROM (
    input clk,
    input rst_n,

    input [`RESOLUTION_PAIR_LOG2-1:0] resolution_pair_idx,

    input [`X_ROM_LEN_LOG2-1:0] xw,
    input [`Y_ROM_LEN_LOG2-1:0] yw,

    output reg [`X_ROM_LEN_LOG2-1:0] x_rom_start,
    output reg [`X_ROM_LEN_LOG2-1:0] x_rom_end,
    output reg [`Y_ROM_LEN_LOG2-1:0] y_rom_start,
    output reg [`Y_ROM_LEN_LOG2-1:0] y_rom_end,
    output reg [`MAX_X_DECIMATION_FACTOR_LOG2-1:0] x_window,
    output reg [`MAX_Y_DECIMATION_FACTOR_LOG2-1:0] y_window,

    output reg [1:0] Xh1_1, Xh2_1, Xh3_1, Xh4_1, Xh5_1, Xh6_1, Xh7_1,
    output reg [1:0] Xh1_2, Xh2_2, Xh3_2, Xh4_2, Xh5_2, Xh6_2, Xh7_2,
    output reg [1:0] Xh1_3, Xh2_3, Xh3_3, Xh4_3, Xh5_3, Xh6_3, Xh7_3,
    output reg [2:0] Xh1_shft_dir, Xh2_shft_dir, Xh3_shft_dir, Xh4_shft_dir, Xh5_shft_dir, Xh6_shft_dir, Xh7_shft_dir,
    output reg [2:0] Xnormalize,
    output reg [1:0] Yh1_1, Yh2_1, Yh3_1, Yh4_1, Yh5_1,
    output reg [1:0] Yh1_2, Yh2_2, Yh3_2, Yh4_2, Yh5_2,
    output reg [1:0] Yh1_3, Yh2_3, Yh3_3, Yh4_3, Yh5_3,
    output reg [2:0] Yh1_shft_dir, Yh2_shft_dir, Yh3_shft_dir, Yh4_shft_dir, Yh5_shft_dir,
    output reg [2:0] Ynormalize

);

    localparam H_ROM_SIZE = 60;
    localparam N_ROM_SIZE = 6;

    reg [`X_ROM_LEN_LOG2-1:0] x_start_table [0: `NUM_RESLUTION_PAIR-1];
    reg [`MAX_X_DECIMATION_FACTOR_LOG2-1:0] x_window_rom [0: `X_ROM_LEN-1];

    reg [`Y_ROM_LEN_LOG2-1:0] y_start_table [0: `NUM_RESLUTION_PAIR-1];
    reg [`MAX_Y_DECIMATION_FACTOR_LOG2-1:0] y_window_rom [0: `Y_ROM_LEN-1];


    reg [1:0] h_rom [0: H_ROM_SIZE-1];
    reg [2:0] normalize_rom [0: N_ROM_SIZE-1];

    always @(posedge clk) begin
        x_rom_start     <= x_start_table[resolution_pair_idx];
        x_rom_end       <= x_start_table[resolution_pair_idx+1]-1;
        y_rom_start     <= y_start_table[resolution_pair_idx];
        y_rom_end       <= y_start_table[resolution_pair_idx+1]-1;   
        x_window        <= x_window_rom[xw];
        y_window        <= y_window_rom[yw];
    end


    localparam X7_BASE = 0;
    localparam X6_BASE = 16;
    localparam X5_BASE = 28;
    localparam X4_BASE = 40;
    localparam X3_BASE = 48;
    localparam X2_BASE = 56;

    localparam Y5_BASE = 28;
    localparam Y4_BASE = 40;
    localparam Y3_BASE = 48;
    localparam Y2_BASE = 56;

    always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {Xh1_1, Xh2_1, Xh3_1, Xh4_1, Xh5_1, Xh6_1, Xh7_1,
             Xh1_2, Xh2_2, Xh3_2, Xh4_2, Xh5_2, Xh6_2, Xh7_2,
             Xh1_3, Xh2_3, Xh3_3, Xh4_3, Xh5_3, Xh6_3, Xh7_3} <= 0;
            {Xh1_shft_dir, Xh2_shft_dir, Xh3_shft_dir, Xh4_shft_dir, Xh5_shft_dir, Xh6_shft_dir, Xh7_shft_dir, Xnormalize} <= 0;
        end
        else begin
            case (x_window)
                3'd7:   
                begin   // h_rom[0..15]
                    Xh1_1 <= h_rom[X7_BASE+0];
                    Xh1_2 <= h_rom[X7_BASE+1];
                    Xh1_3 <= h_rom[X7_BASE+2];
                    Xh1_shft_dir <= {1'b0, h_rom[X7_BASE+3]};
                    Xh2_1 <= h_rom[X7_BASE+4];
                    Xh2_2 <= h_rom[X7_BASE+5];
                    Xh2_3 <= h_rom[X7_BASE+6];
                    Xh2_shft_dir <= {1'b0, h_rom[X7_BASE+7]};
                    Xh3_1 <= h_rom[X7_BASE+8];
                    Xh3_2 <= h_rom[X7_BASE+9];
                    Xh3_3 <= h_rom[X7_BASE+10];
                    Xh3_shft_dir <= {1'b0, h_rom[X7_BASE+11]};
                    Xh4_1 <= h_rom[X7_BASE+12];
                    Xh4_2 <= h_rom[X7_BASE+13];
                    Xh4_3 <= h_rom[X7_BASE+14];
                    Xh4_shft_dir <= {1'b0, h_rom[X7_BASE+15]};
                    // mirror assign
                    Xh7_1 <= h_rom[X7_BASE+0];
                    Xh7_2 <= h_rom[X7_BASE+1];
                    Xh7_3 <= h_rom[X7_BASE+2];
                    Xh7_shft_dir <= {1'b0, h_rom[X7_BASE+3]};
                    Xh6_1 <= h_rom[X7_BASE+4];
                    Xh6_2 <= h_rom[X7_BASE+5];
                    Xh6_3 <= h_rom[X7_BASE+6];
                    Xh6_shft_dir <= {1'b0, h_rom[X7_BASE+7]};
                    Xh5_1 <= h_rom[X7_BASE+8];
                    Xh5_2 <= h_rom[X7_BASE+9];
                    Xh5_3 <= h_rom[X7_BASE+10];
                    Xh5_shft_dir <= {1'b0, h_rom[X7_BASE+11]};

                    Xnormalize <= normalize_rom[0];
                end
                3'd6:
                begin   // h_rom[16..27]
                    Xh1_1 <= h_rom[X6_BASE+0];
                    Xh1_2 <= h_rom[X6_BASE+1];
                    Xh1_3 <= h_rom[X6_BASE+2];
                    Xh1_shft_dir <= {1'b0, h_rom[X6_BASE+3]};
                    Xh2_1 <= h_rom[X6_BASE+4];
                    Xh2_2 <= h_rom[X6_BASE+5];
                    Xh2_3 <= h_rom[X6_BASE+6];
                    Xh2_shft_dir <= {1'b0, h_rom[X6_BASE+7]};
                    Xh3_1 <= h_rom[X6_BASE+8];
                    Xh3_2 <= h_rom[X6_BASE+9];
                    Xh3_3 <= h_rom[X6_BASE+10];
                    Xh3_shft_dir <= {1'b0, h_rom[X6_BASE+11]};
                    // mirror
                    Xh6_1 <= h_rom[X6_BASE+0];
                    Xh6_2 <= h_rom[X6_BASE+1];
                    Xh6_3 <= h_rom[X6_BASE+2];
                    Xh6_shft_dir <= {1'b0, h_rom[X6_BASE+3]};
                    Xh5_1 <= h_rom[X6_BASE+4];
                    Xh5_2 <= h_rom[X6_BASE+5];
                    Xh5_3 <= h_rom[X6_BASE+6];
                    Xh5_shft_dir <= {1'b0, h_rom[X6_BASE+7]};
                    Xh4_1 <= h_rom[X6_BASE+8];
                    Xh4_2 <= h_rom[X6_BASE+9];
                    Xh4_3 <= h_rom[X6_BASE+10];
                    Xh4_shft_dir <= {1'b0, h_rom[X6_BASE+11]};

                    {Xh7_1, Xh7_2, Xh7_3, Xh7_shft_dir} <= 0;

                    Xnormalize <= normalize_rom[1];
                end

                3'd5:
                begin   // h_rom[28..39]
                    Xh1_1 <= h_rom[X5_BASE+0];
                    Xh1_2 <= h_rom[X5_BASE+1];
                    Xh1_3 <= h_rom[X5_BASE+2];
                    Xh1_shft_dir <= {1'b0, h_rom[X5_BASE+3]};
                    Xh2_1 <= h_rom[X5_BASE+4];
                    Xh2_2 <= h_rom[X5_BASE+5];
                    Xh2_3 <= h_rom[X5_BASE+6];
                    Xh2_shft_dir <= {1'b0, h_rom[X5_BASE+7]};
                    Xh3_1 <= h_rom[X5_BASE+8];
                    Xh3_2 <= h_rom[X5_BASE+9];
                    Xh3_3 <= h_rom[X5_BASE+10];
                    Xh3_shft_dir <= {1'b0, h_rom[X5_BASE+11]};

                    // mirror
                    Xh5_1 <= h_rom[X5_BASE+0];
                    Xh5_2 <= h_rom[X5_BASE+1];
                    Xh5_3 <= h_rom[X5_BASE+2];
                    Xh5_shft_dir <= {1'b0, h_rom[X5_BASE+3]};
                    Xh4_1 <= h_rom[X5_BASE+4];
                    Xh4_2 <= h_rom[X5_BASE+5];
                    Xh4_3 <= h_rom[X5_BASE+6];
                    Xh4_shft_dir <= {1'b0, h_rom[X5_BASE+7]};

                    {Xh6_1, Xh6_2, Xh6_3, Xh6_shft_dir} <= 0;
                    {Xh7_1, Xh7_2, Xh7_3, Xh7_shft_dir} <= 0;

                    Xnormalize <= normalize_rom[2];
                end
                3'd4:
                begin   // h_rom[40..47]
                    Xh1_1 <= h_rom[X4_BASE+0];
                    Xh1_2 <= h_rom[X4_BASE+1];
                    Xh1_3 <= h_rom[X4_BASE+2];
                    Xh1_shft_dir <= {1'b0, h_rom[X4_BASE+3]};
                    Xh2_1 <= h_rom[X4_BASE+4];
                    Xh2_2 <= h_rom[X4_BASE+5];
                    Xh2_3 <= h_rom[X4_BASE+6];
                    Xh2_shft_dir <= {1'b0, h_rom[X4_BASE+7]};

                    // mirror
                    Xh4_1 <= h_rom[X4_BASE+0];
                    Xh4_2 <= h_rom[X4_BASE+1];
                    Xh4_3 <= h_rom[X4_BASE+2];
                    Xh4_shft_dir <= {1'b0, h_rom[X4_BASE+3]};
                    Xh3_1 <= h_rom[X4_BASE+4];
                    Xh3_2 <= h_rom[X4_BASE+5];
                    Xh3_3 <= h_rom[X4_BASE+6];
                    Xh3_shft_dir <= {1'b0, h_rom[X4_BASE+7]};

                    {Xh5_1, Xh5_2, Xh5_3, Xh5_shft_dir} <= 0;
                    {Xh6_1, Xh6_2, Xh6_3, Xh6_shft_dir} <= 0;
                    {Xh7_1, Xh7_2, Xh7_3, Xh7_shft_dir} <= 0;

                    Xnormalize <= normalize_rom[3];
                end
                3'd3:
                begin   // h_rom[48..55]
                    Xh1_1 <= h_rom[X3_BASE+0];
                    Xh1_2 <= h_rom[X3_BASE+1];
                    Xh1_3 <= h_rom[X3_BASE+2];
                    Xh1_shft_dir <= {1'b0, h_rom[X3_BASE+3]};
                    Xh2_1 <= h_rom[X3_BASE+4];
                    Xh2_2 <= h_rom[X3_BASE+5];
                    Xh2_3 <= h_rom[X3_BASE+6];
                    Xh2_shft_dir <= {1'b0, h_rom[X3_BASE+7]};

                    // mirror
                    Xh3_1 <= h_rom[X3_BASE+0];
                    Xh3_2 <= h_rom[X3_BASE+1];
                    Xh3_3 <= h_rom[X3_BASE+2];
                    Xh3_shft_dir <= {1'b0, h_rom[X3_BASE+3]};

                    {Xh4_1, Xh4_2, Xh4_3, Xh4_shft_dir} <= 0;
                    {Xh5_1, Xh5_2, Xh5_3, Xh5_shft_dir} <= 0;
                    {Xh6_1, Xh6_2, Xh6_3, Xh6_shft_dir} <= 0;
                    {Xh7_1, Xh7_2, Xh7_3, Xh7_shft_dir} <= 0;

                    Xnormalize <= normalize_rom[4];
                end
                3'd2:
                begin   // h_rom[56..59]
                    Xh1_1 <= h_rom[X2_BASE+0];
                    Xh1_2 <= h_rom[X2_BASE+1];
                    Xh1_3 <= h_rom[X2_BASE+2];
                    Xh1_shft_dir <= {1'b0, h_rom[X2_BASE+3]};

                    // mirror
                    Xh2_1 <= h_rom[X2_BASE+0];
                    Xh2_2 <= h_rom[X2_BASE+1];
                    Xh2_3 <= h_rom[X2_BASE+2];
                    Xh2_shft_dir <= {1'b0, h_rom[X2_BASE+3]};

                    {Xh3_1, Xh3_2, Xh3_3, Xh3_shft_dir} <= 0;
                    {Xh4_1, Xh4_2, Xh4_3, Xh4_shft_dir} <= 0;
                    {Xh5_1, Xh5_2, Xh5_3, Xh5_shft_dir} <= 0;
                    {Xh6_1, Xh6_2, Xh6_3, Xh6_shft_dir} <= 0;
                    {Xh7_1, Xh7_2, Xh7_3, Xh7_shft_dir} <= 0;

                    Xnormalize <= normalize_rom[5];
                end
                default: begin
                    $fatal(1, "[Error] Illegal x_window value in read_ROM: %0d", x_window);
                end
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            { Yh1_1, Yh2_1, Yh3_1, Yh4_1, Yh5_1,
              Yh1_2, Yh2_2, Yh3_2, Yh4_2, Yh5_2,
              Yh1_3, Yh2_3, Yh3_3, Yh4_3, Yh5_3 } <= 0;
            { Yh1_shft_dir, Yh2_shft_dir, Yh3_shft_dir, Yh4_shft_dir, Yh5_shft_dir, Ynormalize } <= 0;
        end
        else begin
            case (y_window)
                3'd5:
                begin   // h_rom[28..39]
                    Yh1_1 <= h_rom[Y5_BASE+0];
                    Yh1_2 <= h_rom[Y5_BASE+1];
                    Yh1_3 <= h_rom[Y5_BASE+2];
                    Yh1_shft_dir <= {1'b0, h_rom[Y5_BASE+3]};
                    Yh2_1 <= h_rom[Y5_BASE+4];
                    Yh2_2 <= h_rom[Y5_BASE+5];
                    Yh2_3 <= h_rom[Y5_BASE+6];
                    Yh2_shft_dir <= {1'b0, h_rom[Y5_BASE+7]};
                    Yh3_1 <= h_rom[Y5_BASE+8];
                    Yh3_2 <= h_rom[Y5_BASE+9];
                    Yh3_3 <= h_rom[Y5_BASE+10];
                    Yh3_shft_dir <= {1'b0, h_rom[Y5_BASE+11]};

                    // mirror
                    Yh5_1 <= h_rom[Y5_BASE+0];
                    Yh5_2 <= h_rom[Y5_BASE+1];
                    Yh5_3 <= h_rom[Y5_BASE+2];
                    Yh5_shft_dir <= {1'b0, h_rom[Y5_BASE+3]};
                    Yh4_1 <= h_rom[Y5_BASE+4];
                    Yh4_2 <= h_rom[Y5_BASE+5];
                    Yh4_3 <= h_rom[Y5_BASE+6];
                    Yh4_shft_dir <= {1'b0, h_rom[Y5_BASE+7]};

                    Ynormalize <= normalize_rom[2];
                end
                3'd4:
                begin   // h_rom[40..47]
                    Yh1_1 <= h_rom[Y4_BASE+0];
                    Yh1_2 <= h_rom[Y4_BASE+1];
                    Yh1_3 <= h_rom[Y4_BASE+2];
                    Yh1_shft_dir <= {1'b0, h_rom[Y4_BASE+3]};
                    Yh2_1 <= h_rom[Y4_BASE+4];
                    Yh2_2 <= h_rom[Y4_BASE+5];
                    Yh2_3 <= h_rom[Y4_BASE+6];
                    Yh2_shft_dir <= {1'b0, h_rom[Y4_BASE+7]};

                    // mirror
                    Yh4_1 <= h_rom[Y4_BASE+0];
                    Yh4_2 <= h_rom[Y4_BASE+1];
                    Yh4_3 <= h_rom[Y4_BASE+2];
                    Yh4_shft_dir <= {1'b0, h_rom[Y4_BASE+3]};
                    Yh3_1 <= h_rom[Y4_BASE+4];
                    Yh3_2 <= h_rom[Y4_BASE+5];
                    Yh3_3 <= h_rom[Y4_BASE+6];
                    Yh3_shft_dir <= {1'b0, h_rom[Y4_BASE+7]};

                    {Yh5_1, Yh5_2, Yh5_3, Yh5_shft_dir} <= 0;

                    Ynormalize <= normalize_rom[3];
                end
                3'd3:
                begin   // h_rom[48..55]
                    Yh1_1 <= h_rom[Y3_BASE+0];
                    Yh1_2 <= h_rom[Y3_BASE+1];
                    Yh1_3 <= h_rom[Y3_BASE+2];
                    Yh1_shft_dir <= {1'b0, h_rom[Y3_BASE+3]};
                    Yh2_1 <= h_rom[Y3_BASE+4];
                    Yh2_2 <= h_rom[Y3_BASE+5];
                    Yh2_3 <= h_rom[Y3_BASE+6];
                    Yh2_shft_dir <= {1'b0, h_rom[Y3_BASE+7]};

                    // mirror
                    Yh3_1 <= h_rom[Y3_BASE+0];
                    Yh3_2 <= h_rom[Y3_BASE+1];
                    Yh3_3 <= h_rom[Y3_BASE+2];
                    Yh3_shft_dir <= {1'b0, h_rom[Y3_BASE+3]};

                    {Yh4_1, Yh4_2, Yh4_3, Yh4_shft_dir} <= 0;
                    {Yh5_1, Yh5_2, Yh5_3, Yh5_shft_dir} <= 0;

                    Ynormalize <= normalize_rom[4];
                end
                3'd2:
                begin   // h_rom[56..59]
                    Yh1_1 <= h_rom[Y2_BASE+0];
                    Yh1_2 <= h_rom[Y2_BASE+1];
                    Yh1_3 <= h_rom[Y2_BASE+2];
                    Yh1_shft_dir <= {1'b0, h_rom[Y2_BASE+3]};

                    // mirror
                    Yh2_1 <= h_rom[Y2_BASE+0];
                    Yh2_2 <= h_rom[Y2_BASE+1];
                    Yh2_3 <= h_rom[Y2_BASE+2];
                    Yh2_shft_dir <= {1'b0, h_rom[Y2_BASE+3]};

                    {Yh3_1, Yh3_2, Yh3_3, Yh3_shft_dir} <= 0;
                    {Yh4_1, Yh4_2, Yh4_3, Yh4_shft_dir} <= 0;
                    {Yh5_1, Yh5_2, Yh5_3, Yh5_shft_dir} <= 0;

                    Ynormalize <= normalize_rom[5];
                end
                default: begin
                    $fatal(1, "[Error] Illegal y_window value in read_ROM: %0d", y_window);
                end
            endcase
        end
    end



    /*  ROM  */

    `ifdef SIM
        reg [64*8-1:0] rom_filename;  //64 char
        initial begin
            $sformat(rom_filename, "%s/X_start_table.mem", `IN_ROM_DIR);
            $readmemh(rom_filename, x_start_table);
            $sformat(rom_filename, "%s/Xwindow_rom.mem", `IN_ROM_DIR);
            $readmemh(rom_filename, x_window_rom);

            $sformat(rom_filename, "%s/Y_start_table.mem", `IN_ROM_DIR);
            $readmemh(rom_filename, y_start_table);
            $sformat(rom_filename, "%s/Ywindow_rom.mem", `IN_ROM_DIR);
            $readmemh(rom_filename, y_window_rom);

            $sformat(rom_filename, "%s/H_rom.mem", `IN_ROM_DIR);
            $readmemh(rom_filename, h_rom);
            $sformat(rom_filename, "%s/N_rom.mem", `IN_ROM_DIR);
            $readmemh(rom_filename, normalize_rom);
        end
    `endif 

    `ifdef SYN 
        `define IN_ROM_DIR      "../rom_data"
        localparam X_start_table_filename   = {`IN_ROM_DIR, "/X_start_table.mem"};
        localparam Y_start_table_filename   = {`IN_ROM_DIR, "/Y_start_table.mem"};
        localparam Xwindow_rom_filename     = {`IN_ROM_DIR, "/Xwindow_rom.mem"};
        localparam Ywindow_rom_filename     = {`IN_ROM_DIR, "/Ywindow_rom.mem"};
        localparam H_rom_filename           = {`IN_ROM_DIR, "/H_rom.mem"};
        localparam N_rom_filename           = {`IN_ROM_DIR, "/N_rom.mem"};

        initial begin
            $readmemh(X_start_table_filename, x_start_table);
            $readmemh(Xwindow_rom_filename, x_window_rom);
            $readmemh(Y_start_table_filename, y_start_table);
            $readmemh(Ywindow_rom_filename, y_window_rom);
            $readmemh(H_rom_filename, h_rom);
            $readmemh(N_rom_filename, normalize_rom);
        end
    `endif


endmodule
