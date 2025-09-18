`include "MACRO.svh"

package load_rom_pkg;

class LoadROM;
    logic [`MAX_X_DECIMATION_FACTOR_LOG2-1:0] Xwindow_rom [0: `X_ROM_LEN-1];
    logic [`MAX_Y_DECIMATION_FACTOR_LOG2-1:0] Ywindow_rom [0: `Y_ROM_LEN-1];
    logic [`X_ROM_LEN_LOG2-1:0] Xstart_table_rom [0: `NUM_RESLUTION_PAIR-1];
    logic [`Y_ROM_LEN_LOG2-1:0] Ystart_table_rom [0: `NUM_RESLUTION_PAIR-1];

    function new();
    endfunction

    task load(string xwindow_name, string ywindow_name, string xtable_name, string ytable_name);
        $readmemh(xwindow_name, Xwindow_rom);
        $readmemh(ywindow_name, Ywindow_rom);
        $readmemh(xtable_name, Xstart_table_rom);
        $readmemh(ytable_name, Ystart_table_rom);
    endtask

endclass

endpackage
