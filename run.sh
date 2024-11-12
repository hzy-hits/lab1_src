#!/bin/bash
source /tools/Xilinx/Vitis/2023.1/settings64.sh
source /opt/xilinx/xrt/setup.sh
# config
VERSIONS=(1 2 3)
SOURCE_DIR="src"
REPORTS_BASE="_x.hw.xilinx_u250_gen3x16_xdma_4_1_202210_1/reports/link/imp"

# func: copy_reports
copy_reports() {
    local version=$1
    local reports_dir="v${version}/reports"
    
    echo "Copying reports for version $version..."
    
    # create reports directory
    mkdir -p "${reports_dir}"
    
    # copy reports
    if [ -d "$REPORTS_BASE" ]; then
        # resource utilization report
        if [ -f "${REPORTS_BASE}/impl_1_kernel_util_routed.rpt" ]; then
            cp "${REPORTS_BASE}/impl_1_kernel_util_routed.rpt" \
               "${reports_dir}/kernel_util.rpt"
        fi
        
        # timing summary report
        if [ -f "${REPORTS_BASE}/impl_1_hw_bb_locked_timing_summary_routed.rpt" ]; then
            cp "${REPORTS_BASE}/impl_1_hw_bb_locked_timing_summary_routed.rpt" \
               "${reports_dir}/timing_summary.rpt"
        fi
        
        # other reports
        cp -r "${REPORTS_BASE}"/*.rpt "${reports_dir}/" 2>/dev/null || true
    fi
}

# func: build_with_retry
build_with_retry() {
    local version=$1
    local retry_count=0
    local max_retries=1
    
    while [ $retry_count -le $max_retries ]; do
        if [ $retry_count -eq 0 ]; then
            echo "Attempting incremental build for version $version..."
            make incremental_clean
            make TARGET=hw all
        else
            echo "Retrying with clean build for version $version..."
            make cleanall
            make TARGET=hw all
        fi
        
        # check if build was successful
        if [ -f "build_dir.hw.xilinx_u250_gen3x16_xdma_4_1_202210_1/vadd.xclbin" ]; then
            echo "Build successful for version $version"
            # save reports
            copy_reports $version
            # move xclbin to version directory
            mv build_dir.hw.xilinx_u250_gen3x16_xdma_4_1_202210_1/vadd.xclbin "v${version}/"
            return 0
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -le $max_retries ]; then
                echo "Build failed, attempting retry ($retry_count/$max_retries)..."
            fi
        fi
    done
    
    echo "Build failed after all attempts for version $version"
    return 1
}

# check source directory
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory $SOURCE_DIR not found!"
    exit 1
fi

if [ ! -f "${SOURCE_DIR}/host.cpp" ]; then
    echo "Error: host.cpp not found in $SOURCE_DIR!"
    exit 1
fi

for version in "${VERSIONS[@]}"; do
    if [ ! -f "${SOURCE_DIR}/vadd_v${version}.cpp" ]; then
        echo "Error: vadd_v${version}.cpp not found!"
        exit 1
    fi
done

# record failed versions
failed_versions=()

# build each version
for version in "${VERSIONS[@]}"; do
    echo "==============================================="
    echo "Processing version $version - $(date)"
    echo "==============================================="
    
    # create version directory
    mkdir -p "v${version}"
    
    # copy version-specific source file
    cp "${SOURCE_DIR}/vadd_v${version}.cpp" "${SOURCE_DIR}/vadd.cpp"
    
    # build version
    if build_with_retry $version; then
        echo "Version $version completed successfully"
    else
        failed_versions+=($version)
        echo "Version $version failed after all attempts"
    fi
    
    echo "Completed version $version at $(date)"
    echo ""
done

# final summary
echo "==============================================="
echo "Build Summary"
echo "==============================================="
echo "Total versions attempted: ${#VERSIONS[@]}"
echo "Successfully built: $((${#VERSIONS[@]} - ${#failed_versions[@]}))"
if [ ${#failed_versions[@]} -gt 0 ]; then
    echo "Failed versions: ${failed_versions[@]}"
fi
echo ""
echo "Generated files for each version:"
for version in "${VERSIONS[@]}"; do
    if [ -d "v${version}" ]; then
        echo "Version $version:"
        echo "  - xclbin: $([ -f "v${version}/vadd.xclbin" ] && echo "Yes" || echo "No")"
        echo "  - reports: $([ -d "v${version}/reports" ] && echo "Yes" || echo "No")"
    fi
done
