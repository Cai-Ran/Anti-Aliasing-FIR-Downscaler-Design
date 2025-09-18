#!/bin/bash
set -euo pipefail

if command -v nproc &> /dev/null; then
    num_cpus=$(nproc)
else
    num_cpus=$(sysctl -n hw.logicalcpu)
fi

# Calculate max parallel jobs 
max_parallel_jobs=$(( num_cpus * 70 / 100 ))
max_parallel_jobs=$(( max_parallel_jobs < 1 ? 1 : max_parallel_jobs ))

echo "Running with max parallel jobs: $max_parallel_jobs"

lib="pillow"
mkdir -p "./log"
LOGFILE="./log/run_traditional.log"

# start recording
exec 3>&1 4>&2      
exec > >(tee -a "$LOGFILE") 2>&1 # | ts '[%Y-%m-%d %H:%M:%S]'


echo "[bash] Info: Script started at $(date)"

trap 'echo "[bash] Cleaning up..."; rm -rf "$tmp_dir"' EXIT


original_img_dirs=("./test_pictures_${lib}") 
if [[ ! -d "$original_img_dirs" ]]; then
    echo "[bash] Error: $original_img_dirs is missing!"
    exit 1
fi
output_img_dirs=("./output_nearest_${lib}" "./output_bilinear_${lib}") 
for dir in "${output_img_dirs[@]}"; do
    mkdir -p "$dir"
done

tmp_dir="./tmp2"
mkdir -p "${tmp_dir}"

postfix_txt="./tool/picture_basename.txt"
if [[ ! -s "$postfix_txt" ]]; then
    echo "[bash] Error: $postfix_txt is empty or does not exist!"
    exit 1
fi
original_img_postfix=()

while IFS= read -r line; do             
    clean_line="${line//$'\r'/}"
    original_img_postfix+=("$clean_line")
done < "$postfix_txt"                   


output_methods=("Nearest" "Bilinear")

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


main_code="./benchmarks/resize_traditional_methods.c"
bin_name="${tmp_dir}/scaling_traditional"
if [ ! -f "${bin_name}" ]; then
    gcc -g -c "${main_code}" -o "${bin_name}.o"
    gcc "${bin_name}.o" -o "${bin_name}" -lm
    if [ $? -ne 0 ]; then
        echo "[bash] Error: Compilation failed for ${bin_name}." >&2
        exit 1
    fi
fi


for j in "${!original_img_dirs[@]}"; do
    golden_dir="${original_img_dirs[$j]}"

    for i in "${!output_methods[@]}"; do
        output_img_method="${output_methods[$i]}"
        output_dir="${output_img_dirs[$i]}"
        mkdir -p "$output_dir"

        echo "[bash] Info: processing method=${output_img_method}"

        for src_size in "${source_sizes[@]}"; do
            read -r OLD_X OLD_Y <<< "$src_size"
            
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
                echo "[skip] No large ratio for ${OLD_X}x${OLD_Y}, skipping this source resolution."
                continue
            fi


            for tar_size in "${target_sizes[@]}"; do
                if [[ "$src_size" == "$tar_size" ]]; then
                    continue
                fi

                read -r NEW_X NEW_Y <<< "$tar_size"

                x_ratio=$(awk "BEGIN { printf \"%.4f\", ${OLD_X}/${NEW_X} }")
                y_ratio=$(awk "BEGIN { printf \"%.4f\", ${OLD_Y}/${NEW_Y} }")
                is_large=$(awk "BEGIN { print (${x_ratio} > 2 && ${y_ratio} > 2) }")
                [[ "$is_large" -eq 0 ]] && continue

                for n in "${!original_img_postfix[@]}"; do
                    img_postfix="${original_img_postfix[$n]}"
                    original_img_path="${golden_dir}/test_${OLD_X}x${OLD_Y}_${img_postfix}.bmp"
                    if [ ! -f "${original_img_path}" ]; then
                        # echo "[bash] Error: input file ${original_img_path} does not exist." >&2
                        continue
                    fi

                    output_img_path="${output_dir}/${output_img_method}_${OLD_X}x${OLD_Y}_${NEW_X}x${NEW_Y}_${img_postfix}.bmp"

                    # echo "[bash] Info: running ${bin_name} INPUT ${original_img_path}" 
                    
                    {
                        pid=$BASHPID
                        # echo "[${bin_name} ${OLD_X}x${OLD_Y} ${NEW_X}x${NEW_Y} ${img_postfix}] [PID: ${pid}] Starting process."
                        ./"${bin_name}" "${original_img_path}" "${output_img_path}" "${OLD_X}" "${OLD_Y}" "${NEW_X}" "${NEW_Y}" "$((i))" 2>&1 | sed -u "s|^|[${bin_name} ${OLD_X}x${OLD_Y} ${NEW_X}x${NEW_Y} ${img_postfix}] [PID: ${pid}] |"
                        echo "[${output_img_method} ${OLD_X}x${OLD_Y} ${NEW_X}x${NEW_Y} ${img_postfix}] [PID: ${pid}] Process completed."
                    } &
                    
                    while (( $(jobs -p | wc -l) >= max_parallel_jobs )); do
                        sleep 1  
                    done
                done
            done
        done
    done
done

echo "[bash] Info: All scaling operations completed!"
echo "[bash] Record finished at $(date)"
exec 1>&3 2>&4
wait  

echo "[bash] Script finished at $(date)"
