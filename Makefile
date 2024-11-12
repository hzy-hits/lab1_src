#
# Copyright 2019-2021 Xilinx, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# makefile-generator v1.0.3
#

# 
# Copyright 2019-2021 Xilinx, Inc.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# makefile-generator v1.0.3
#
# 
# Copyright 2019-2021 Xilinx, Inc.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# makefile-generator v1.0.3
#

############################## Help Section ##############################

ifneq ($(findstring Makefile, $(MAKEFILE_LIST)), Makefile)
help:
	@echo "Makefile Usage:"
	@echo "  make all TARGET=<sw_emu/hw_emu/hw> PLATFORM=<FPGA platform>"
	@echo "      Command to generate the design for specified Target and Shell."
	@echo ""
	@echo "  make run TARGET=<sw_emu/hw_emu/hw> PLATFORM=<FPGA platform>"
	@echo "      Command to run application in emulation."
	@echo ""
	@echo "  make build TARGET=<sw_emu/hw_emu/hw> PLATFORM=<FPGA platform>"
	@echo "      Command to build xclbin application."
	@echo ""
	@echo "  make host"
	@echo "      Command to build host application."
	@echo ""
	@echo "  make clean"
	@echo "      Command to remove the generated non-hardware files."
	@echo ""
	@echo "  make cleanall"
	@echo "      Command to remove all the generated files."
	@echo ""
endif

############################## Setting up Project Variables ##############################
HOST_SRCS := ./src/host.cpp 
HLS_SRCS := ./src/vadd.cpp 
PLATFORM := xilinx_u250_gen3x16_xdma_4_1_202210_1
HOST_ARCH := x86
TARGET := hw
Freq := 250000000

# Define necessary commands
ECHO := echo
RM := rm -f
RMDIR := rm -rf

TEMP_DIR := ./_x.$(TARGET).$(PLATFORM)
BUILD_DIR := ./build_dir.$(TARGET).$(PLATFORM)
INCR_BUILD_DIR := ./incremental_build
TIMESTAMP_DIR := $(INCR_BUILD_DIR)/.timestamps

VPP_PFLAGS :=
CMD_ARGS := $(BUILD_DIR)/vadd.xclbin
CXXFLAGS += -I$(XILINX_XRT)/include -I$(XILINX_VIVADO)/include -Wall -O0 -g -std=c++1y
LDFLAGS += -lxrt_coreutil -lxrt_core -lxrt_coreutil -L$(XILINX_XRT)/lib -pthread -lOpenCL

########################## Checking if PLATFORM in allowlist #######################
PLATFORM_BLOCKLIST += nodma 

############################## Setting up Host Variables ##############################
# Host compiler global settings
CXXFLAGS += -fmessage-length=0
LDFLAGS += -lrt -lstdc++ 

############################## Setting up Kernel Variables ##############################
# Kernel compiler global settings

PARALLEL_JOBS := 4
VPP_PARALLEL_FLAGS := --jobs $(PARALLEL_JOBS)

# Update incremental compilation flags for Vitis 2023.1
VPP_INCR_FLAGS := --save-temps \
                  --temp_dir $(INCR_BUILD_DIR) \
                  --advanced.param compiler.incrementalCompilation=true

VPP_FLAGS := $(VPP_PARALLEL_FLAGS) $(VPP_INCR_FLAGS)

EXECUTABLE := ./hello_world
EMCONFIG_DIR := $(TEMP_DIR)

############################## Directory Setup ##############################
$(TEMP_DIR):
	mkdir -p $@

$(BUILD_DIR):
	mkdir -p $@

$(TIMESTAMP_DIR):
	mkdir -p $@

.PRECIOUS: $(TIMESTAMP_DIR)/%.timestamp
$(TIMESTAMP_DIR)/%.timestamp: $(TEMP_DIR)/%.xo | $(TIMESTAMP_DIR)
	@touch $@

############################## Setting Targets ##############################
.PHONY: all clean cleanall incremental_clean host build xclbin run test status check-platform check-device check-vitis check-xrt

all: check-platform check-device check-vitis $(EXECUTABLE) $(BUILD_DIR)/vadd.xclbin emconfig

host: $(EXECUTABLE)

build: check-vitis check-device $(BUILD_DIR)/vadd.xclbin

xclbin: build

############################## Setting Rules for Binary Containers (Building Kernels) ##############################
$(TEMP_DIR)/%.xo: src/%.cpp | $(TEMP_DIR) $(TIMESTAMP_DIR)
	@echo "Incrementally building kernel $*..."
	v++ -c $(VPP_FLAGS) -t $(TARGET) --platform $(PLATFORM) -k $* \
		--hls.clock 300000000:$* \
		-I'$(<D)' -o'$@' '$<'

$(BUILD_DIR)/vadd.xclbin: $(TEMP_DIR)/vadd.xo | $(BUILD_DIR)
	@echo "Incrementally linking kernels..."
	v++ -l --clock.defaultFreqHz $(Freq) $(VPP_FLAGS) \
		-t $(TARGET) --platform $(PLATFORM) \
		-o $(BUILD_DIR)/vadd.xclbin $^


############################## Setting Rules for Host (Building Host Executable) ##############################
$(EXECUTABLE): $(HOST_SRCS) | check-xrt
	g++ -o $@ $^ $(CXXFLAGS) $(LDFLAGS)

emconfig: $(EMCONFIG_DIR)/emconfig.json

$(EMCONFIG_DIR)/emconfig.json:
	emconfigutil --platform $(PLATFORM) --od $(EMCONFIG_DIR)

############################## Setting Essential Checks and Running Rules ##############################
run: all
ifeq ($(TARGET),$(filter $(TARGET),sw_emu hw_emu))
	cp -rf $(EMCONFIG_DIR)/emconfig.json .
	XCL_EMULATION_MODE=$(TARGET) $(EXECUTABLE) $(CMD_ARGS)
else
	$(EXECUTABLE) $(CMD_ARGS)
endif

test: $(EXECUTABLE)
ifeq ($(TARGET),$(filter $(TARGET),sw_emu hw_emu))
	XCL_EMULATION_MODE=$(TARGET) $(EXECUTABLE) $(CMD_ARGS)
else
	$(EXECUTABLE) $(CMD_ARGS)
endif

############################## Cleaning Rules ##############################
clean:
	-$(RMDIR) $(EXECUTABLE)
	-$(RMDIR) profile_* TempConfig system_estimate.xtxt *.rpt *.csv
	-$(RMDIR) src/*.ll *v++* .Xil emconfig.json dltmp* xmltmp* *.log *.jou *.wcfg *.wdb

incremental_clean:
	-$(RM) $(TIMESTAMP_DIR)/*.timestamp
	-$(RM) $(BUILD_DIR)/vadd.xclbin

cleanall: clean incremental_clean
	-$(RMDIR) $(INCR_BUILD_DIR)
	-$(RMDIR) $(BUILD_DIR)
	-$(RMDIR) $(TEMP_DIR)

############################## Status Check ##############################
status:
	@echo "Build Status:"
	@echo "  Platform: $(PLATFORM)"
	@echo "  Target: $(TARGET)"
	@echo "  Parallel Jobs: $(PARALLEL_JOBS)"
	@if [ -d "$(INCR_BUILD_DIR)" ]; then \
	    echo "  Last Build: $$(ls -l $(INCR_BUILD_DIR) | tail -n 1)"; \
	else \
	    echo "  No previous build found"; \
	fi

############################## Utility Targets ##############################
check-platform:
	@echo "Checking platform..."
	# Add platform checks here if necessary

check-device:
	@echo "Checking device..."
	# Add device checks here if necessary

check-vitis:
	@echo "Checking Vitis installation..."
	@if [ -z "$(XILINX_VITIS)" ]; then \
	    echo "Error: XILINX_VITIS environment variable is not set."; \
	    exit 1; \
	fi

check-xrt:
	@echo "Checking XRT installation..."
	@if [ -z "$(XILINX_XRT)" ]; then \
	    echo "Error: XILINX_XRT environment variable is not set."; \
	    exit 1; \
	fi
