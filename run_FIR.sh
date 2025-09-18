#!/bin/bash
set -euo pipefail

if command -v nproc &> /dev/null; then
    num_cpus=$(nproc)
else
    num_cpus=$(sysctl -n hw.logicalcpu)
fi

max_parallel_jobs=$(( num_cpus * 70 / 100 )) 
max_parallel_jobs=$(( max_parallel_jobs < 1 ? 1 : max_parallel_jobs ))
echo "[bash] Using max parallel jobs: $max_parallel_jobs"

lib="pillow"

log_dir="./log"
LOGFILE="${log_dir}/run_FIR.log"
rm -rf "$LOGFILE" && mkdir -p "$log_dir"
exec 3>&1 4>&2
exec > >(tee -a "$LOGFILE") 2>&1

echo "[bash] Script started at $(date)"
echo "[bash] Logging to: $LOGFILE"

trap 'echo "[bash] Cleaning up..."; rm -rf "$tmp_dir"' EXIT


original_img_dir="./test_pictures_${lib}"
rom_data_dir="./rom_data"
c_window_dir="./prepare_data/window"
for dir in "$rom_data_dir" "$c_window_dir" "$original_img_dir"; do
    if [[ ! -d "$dir" ]]; then
        echo "[bash] Error: $dir is missing"
        exit 1
    fi
done

input_hex_dir="./hex_input"
mkdir -p "$input_hex_dir"
output_hex_dir="./hex_output"
mkdir -p "$output_hex_dir"
golden_dir="./hex_golden"
mkdir -p "$golden_dir"
output_img_dir="./output_FIR_${lib}"
mkdir -p "$output_img_dir"
tmp_dir="./tmp"
mkdir -p "$tmp_dir"                


postfix_txt="./tool/picture_basename.txt"
if [[ ! -s "$postfix_txt" ]]; then
    echo "[bash] Error: $postfix_txt is missing or empty"
    exit 1
fi

original_img_postfix=()
while IFS= read -r line; do
    clean_line="${line//$'\r'/}"
    original_img_postfix+=("$clean_line")
done < "$postfix_txt"


timeout_log="${log_dir}/run_fir_timeout_jobs.txt"
success_log="${log_dir}/run_fir_success_jobs.txt"
fail_log="${log_dir}/run_fir_fail_jobs.txt"
skip_log="${log_dir}/run_fir_skip_resolution.txt"
rm -f "$timeout_log" "$success_log" "$fail_log" "$skip_log"
touch "$timeout_log" "$success_log" "$fail_log" "$skip_log"


source_sizes=(
    "1920 1080"
    "2560 1440"
    "3840 2160"
    "4096 2160"
)

target_sizes=(
    "640 480"
    "720 480"
    "720 576"
    "800 600"
    "1024 768"
    "1152 864"
    "1280 720"
    "1280 800"
    "1280 960"
    "1360 768"
    "1440 900"
    "1600 900"
)


build_c_tool() {
    src=$1
    bin=$2
    gcc -g -c "$src" -o "${tmp_dir}/${bin}.o"
    gcc "${tmp_dir}/${bin}.o" -o "${tmp_dir}/$bin" -lm
}

build_c_tool "./prepare_data/bmp_to_hex.c" "BmpToHex"
build_c_tool "./prepare_data/gen_golden_hex.c" "GenGolden"
build_c_tool "./prepare_data/hex_to_bmp.c" "HexToBmp"


vvp_done_flag="VERILOG_OUTPUT_DONE"


run_vvp_simulation() {
    local OLD_X=$1 OLD_Y=$2 postfix=$3
    local NEW_X=$4 NEW_Y=$5

    local def_file="./rtl_configs/${OLD_X}x${OLD_Y}-${NEW_X}x${NEW_Y}_define.v"
    if [[ ! -f "$def_file" ]]; then
        echo "[skip] Missing def_file: $def_file" >> "$skip_log"
        return
    fi

    # echo "[GenGolden ${OLD_X}x${OLD_Y} ${NEW_X}x${NEW_Y} ${postfix}] Running..."
    if ! ./${tmp_dir}/GenGolden "${input_hex_dir}" "${OLD_X}x${OLD_Y}_${postfix}" "${golden_dir}" "${c_window_dir}" "${postfix}" "${OLD_X}" "${OLD_Y}" "${NEW_X}" "${NEW_Y}" \
        | while IFS= read -r line; do
            echo "[GenGolden ${OLD_X}x${OLD_Y}_${NEW_X}x${NEW_Y}_${postfix}] $line"
        done; then
        echo "[GenGolden ERROR] ${OLD_X}x${OLD_Y} to ${NEW_X}x${NEW_Y} ${postfix}" >> "$fail_log"
        return
    fi
    echo "[GenGolden ${OLD_X}x${OLD_Y} ${NEW_X}x${NEW_Y} ${postfix}] GenGolden DONE"

    local exe_name="/${tmp_dir}/${OLD_X}x${OLD_Y}_${NEW_X}x${NEW_Y}_${postfix}.out"


    iverilog \
        -DCONFIG_FILE="\"$def_file\"" \
        -DIN_HEX_DIR="\"$input_hex_dir\"" \
        -DOUT_HEX_DIR="\"$output_hex_dir\"" \
        -DPIC_NAME="\"$postfix\"" \
        -DIN_ROM_DIR="\"$rom_data_dir\"" \
        -DGOLDEN_DIR="\"$golden_dir\"" \
        -o "$exe_name" ./sim/tb.v


    echo "[vvp ${OLD_X}x${OLD_Y}_${NEW_X}x${NEW_Y}_${postfix}] Running simulation"

    found_done=0
    status=1
    timeout_secs=3000

    exec 3< <(
    bash -c '
        timeout '"$timeout_secs"' vvp "'"$exe_name"'" 2>&1
        echo "__VVP_EXIT_CODE__=$?"
    '
    )

    while IFS= read -r line <&3; do
        echo "[vvp $exe_name] $line"

        [[ "$line" == *"$vvp_done_flag"* ]] && found_done=1

        if [[ "$line" == __VVP_EXIT_CODE__=* ]]; then
            status="${line##*=}"
        fi
    done
    exec 3<&-


    if [[ "$status" -eq 124 ]]; then
        echo "$exe_name : timeout after $timeout_secs s" >> "$timeout_log"
    fi
    if [[ "$found_done" -ne 1 ]]; then
        echo "$exe_name : missing VVP_DONE_FLAG" >> "$fail_log"
    fi
    if [[ "$status" -ne 0 ]]; then
        echo "$exe_name : not exit normaly" >> "$fail_log"
    fi
    if [[ "$found_done" -ne 1 || "$status" -eq 124 ]]; then
        return
    fi

    local output_img_name="${OLD_X}x${OLD_Y}_${NEW_X}x${NEW_Y}_${postfix}"
    ./${tmp_dir}/HexToBmp "$output_hex_dir" "$output_img_name" "$output_img_dir" \
        > >(
            while IFS= read -r line; do
                echo "[HexToBmp][${OLD_X}x${OLD_Y}_${NEW_X}x${NEW_Y}_${postfix}] $line"
            done
        ) 2>&1


    if [[ $? -ne 0 ]]; then
        echo "HexToBmp ${output_img_name} failed" >> "$fail_log"
        return
    fi

    echo "$exe_name" >> "$success_log"
    rm -f "$exe_name"
}


for src_size in "${source_sizes[@]}"; do
    read -r OLD_X OLD_Y <<< "$src_size"

    found_any_image=0
    img_postfix=""
    for postfix in "${original_img_postfix[@]}"; do
        test_img="${original_img_dir}/test_${OLD_X}x${OLD_Y}_${postfix}.bmp"
        if [[ -f "$test_img" ]]; then
            found_any_image=1
            img_postfix="$postfix"
            break
        fi
    done

    if [[ "$found_any_image" -eq 0 ]]; then
        echo "[skip] No images found for ${OLD_X}x${OLD_Y}, skipping this source resolution." >> "$skip_log"
        continue
    fi

    all_not_large=1
    for tar_size in "${target_sizes[@]}"; do
        [[ "$src_size" == "$tar_size" ]] && continue
        read -r NEW_X NEW_Y <<< "$tar_size"

        x_ratio=$(awk "BEGIN { printf \"%.4f\", ${OLD_X}/${NEW_X} }")
        y_ratio=$(awk "BEGIN { printf \"%.4f\", ${OLD_Y}/${NEW_Y} }")
        is_large=$(awk "BEGIN { print (${x_ratio} > 2 && ${y_ratio} > 2) }")

        if [[ "$is_large" -eq 1 ]]; then
            all_not_large=0  
            break
        fi
    done

    if [[ "$all_not_large" -eq 1 ]]; then
        echo "[skip] No large ratio for ${OLD_X}x${OLD_Y}, skipping this source resolution." >> "$skip_log"
        continue
    fi


    for postfix in "${original_img_postfix[@]}"; do

        original_img_path="${original_img_dir}/test_${OLD_X}x${OLD_Y}_${postfix}.bmp"
        if [[ ! -f "${original_img_path}" ]]; then
            # echo "[Warn] Skipping nonexistent image: $original_img_path"
            continue
        fi


        input_hex_path="${input_hex_dir}/${OLD_X}x${OLD_Y}_${postfix}"
        {
            # echo "[BmpToHex ${OLD_X}x${OLD_Y} ${postfix}] Running BmpToHex..."
            stdbuf -oL ./"${tmp_dir}"/BmpToHex "$original_img_path" "$input_hex_path"
            echo "[BmpToHex ${OLD_X}x${OLD_Y} ${postfix}] BmpToHex DONE"
        } > >(
            while IFS= read -r line; do
                echo "[BmpToHex ${OLD_X}x${OLD_Y} ${postfix}] $line"
            done
        )
        

        for tar_size in "${target_sizes[@]}"; do
            [[ "$src_size" == "$tar_size" ]] && continue
            read -r NEW_X NEW_Y <<< "$tar_size"

            x_ratio=$(awk "BEGIN { printf \"%.4f\", ${OLD_X}/${NEW_X} }")
            y_ratio=$(awk "BEGIN { printf \"%.4f\", ${OLD_Y}/${NEW_Y} }")
            is_large=$(awk "BEGIN { print (${x_ratio} > 2 && ${y_ratio} > 1) }")
            [[ "$is_large" -eq 0 ]] && continue


            while true; do
                running_jobs=$(jobs -r | wc -l || echo 0)
                # echo "[DEBUG] Running jobs: $running_jobs"
                if (( running_jobs < max_parallel_jobs )); then
                    break
                fi
                sleep 0.2
            done


            (
                run_vvp_simulation "$OLD_X" "$OLD_Y" "$postfix" "$NEW_X" "$NEW_Y"
            ) &

        done
    done
done

exec 1>&3 2>&4
wait


echo "[bash] Script finished at $(date)"
echo "[bash] Summary:"
echo "  Success: $( if [[ -f $success_log ]]; then wc -l < "$success_log"; else echo 0; fi )"
echo "  Timeout: $( if [[ -f $timeout_log ]]; then grep -c ': timeout' "$timeout_log"; else echo 0; fi )"
echo "  Failures: $( if [[ -f $fail_log ]]; then wc -l < "$fail_log"; else echo 0; fi )"


if [[ -s "$timeout_log" || -s "$fail_log" ]]; then
    echo "[bash] Some jobs failed or timed out. See $timeout_log and $fail_log."
fi
