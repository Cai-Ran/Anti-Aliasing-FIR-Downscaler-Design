set OLD_X      3840
set OLD_Y      2160
set NEW_X      640
set NEW_Y      480
set BASENAME   batch_14
set IN_HEX_DIR ./hex_input
set OUT_HEX_DIR ./hex_output
set IN_ROM_DIR ./rom_data
set GOLDEN_DIR ./hex_golden


vlib work
vmap work work

vlog -sv +incdir+sim sim/write_file.sv
vlog -sv +define+CONFIG_FILE="./rtl_configs/${OLD_X}x${OLD_Y}-${NEW_X}x${NEW_Y}_define.v" +incdir+sim sim/load_file.sv
vlog -sv +incdir+sim sim/load_rom.sv
vlog -sv +define+CONFIG_FILE="./rtl_configs/${OLD_X}x${OLD_Y}-${NEW_X}x${NEW_Y}_define.v" +define+IN_HEX_DIR="${IN_HEX_DIR}" +define+OUT_HEX_DIR="${OUT_HEX_DIR}" +define+PIC_NAME=\"${BASENAME}\" +define+IN_ROM_DIR="${IN_ROM_DIR}" +define+GOLDEN_DIR="${GOLDEN_DIR}" +incdir+sim sim/tb.sv


vsim tb
run -all
quit
