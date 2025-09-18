rm -rf ./work

logfile="./log/run_modelsim.log"
exec > >(tee -a "$logfile") 2>&1

lib="pillow"

input_hex_dir="./hex_input"
mkdir -p "$input_hex_dir"
output_hex_dir="./hex_output"
mkdir -p "$output_hex_dir"
golden_dir="./hex_golden"
mkdir -p "$golden_dir"
output_img_dir="./output_FIR_${lib}"
mkdir -p "$output_img_dir"
tmp_dir="./tmp3"
mkdir -p "$tmp_dir"

test_img_dir="./test_pictures_pillow"
c_dir="./prepare_data"
c_window_dir="./prepare_data/window"

OLD_X=3840
OLD_Y=2160
NEW_X=640
NEW_Y=480
BASENAME="batch_14"
IN_HEX_DIR="./hex_input"
OUT_HEX_DIR="./hex_output"
IN_ROM_DIR="./rom_data"
GOLDEN_DIR="./hex_golden"

test_img_path="${test_img_dir}/test_${OLD_X}x${OLD_Y}_${BASENAME}.bmp"


gcc -g -c ${c_dir}/bmp_to_hex.c -o ${tmp_dir}/BmpToHex.o
gcc ${tmp_dir}/BmpToHex.o -o ${tmp_dir}/BmpToHex -lm

gcc -g -c ${c_dir}/gen_golden_hex.c -o ${tmp_dir}/GenGolden.o
gcc ${tmp_dir}/GenGolden.o -o ${tmp_dir}/GenGolden -lm

gcc -g -c ${c_dir}/hex_to_bmp.c -o ${tmp_dir}/HexToBmp.o
gcc ${tmp_dir}/HexToBmp.o -o ${tmp_dir}/HexToBmp -lm


# BmpToHex
input_hex_path="${input_hex_dir}/${OLD_X}x${OLD_Y}_${BASENAME}"
./${tmp_dir}/BmpToHex "$test_img_path" "$input_hex_path"
if [[ $? -ne 0 ]]; then
    echo "[BmpToHex ERROR] ${OLD_X}x${OLD_Y} to ${NEW_X}x${NEW_Y} ${BASENAME}"
fi
echo "[BmpToHex ${OLD_X}x${OLD_Y} ${BASENAME}] BmpToHex DONE"


# GenGolden
./${tmp_dir}/GenGolden "${input_hex_dir}" "${OLD_X}x${OLD_Y}_${BASENAME}" "${golden_dir}" "${c_window_dir}" "${BASENAME}" "${OLD_X}" "${OLD_Y}" "${NEW_X}" "${NEW_Y}"
if [[ $? -ne 0 ]]; then
    echo "[GenGolden ERROR] ${OLD_X}x${OLD_Y} ${NEW_X}x${NEW_Y} ${BASENAME}"
fi
echo "[GenGolden ${OLD_X}x${OLD_Y} ${NEW_X}x${NEW_Y} ${BASENAME}] GenGolden DONE"


vsim -c -do run_modelsim.do 


# HexToBmp
output_img_name="${OLD_X}x${OLD_Y}_${NEW_X}x${NEW_Y}_${BASENAME}"
./${tmp_dir}/HexToBmp "$output_hex_dir" "$output_img_name" "$output_img_dir"
if [[ $? -ne 0 ]]; then
    echo "[HexToBmp ERROR] ${output_img_name}"
fi
echo "[HexToBmp ${OLD_X}x${OLD_Y} ${NEW_X}x${NEW_Y} ${BASENAME}] HexToBmp DONE"

rm -rf "$tmp_dir"

echo "[bash] Script finished at $(date)"
