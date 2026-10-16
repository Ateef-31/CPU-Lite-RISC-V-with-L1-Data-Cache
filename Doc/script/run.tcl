#set design "CPU_LITE_TOP"

#analyze -format verilog {CPU_LITE_TOP.v CPU_CORE.v PROGRAM_COUNTER.v INSTRUCTION_DECODER.v REGISTER_FILE.v ALU.v L1_DATA_CACHE.v CDC_BRIDGE.v ASYNCH_FIFO.v TWO_FLOP_SYNCHRONIZER.v WRITE_POINTER.v READ_POINTER.v FIFOMEM.v SLOW_MEM_CONTROLLER.v }

#elaborate $design 

# Fix assign statements by inserting buffers (PT hates assigns in netlists)
#set_fix_multiple_port_nets -all -buffer_constants

# Force strict Verilog naming conventions
#change_names -rules verilog -hierarchy

# Now write the netlist


#source script/constraints_sdc.sdc
#link
#check_design
#write -format verilog -hier -output unmapped/$design.v
#write -format ddc -hierarchy -output unmapped/$design.ddc
#compile_ultra
#check_timing
#write -format verilog -hierarchy -output netlist/netlist_CPU_LITE_TOP.v
#write -format ddc -hierarchy -output mapped/$design.ddc
#cd reports
#report_timing > timing_report_$design.rpt
#report_area > area_report_$design.rpt
#cd ..

set design "CPU_LITE_TOP"

# 1. Read and Elaborate RTL
analyze -format verilog {CPU_LITE_TOP.v CPU_CORE.v PROGRAM_COUNTER.v INSTRUCTION_DECODER.v REGISTER_FILE.v ALU.v L1_DATA_CACHE.v CDC_BRIDGE.v ASYNCH_FIFO.v TWO_FLOP_SYNCHRONIZER.v WRITE_POINTER.v READ_POINTER.v FIFOMEM.v SLOW_MEM_CONTROLLER.v }
elaborate $design 

# 2. Link and Check Initial Design
link
check_design
write -format verilog -hier -output unmapped/$design.v
write -format ddc -hierarchy -output unmapped/$design.ddc

# 3. Apply Constraints and Synthesis Settings
source script/constraints_sdc.sdc

# Instruct the compiler to buffer assign statements
set_fix_multiple_port_nets -all -buffer_constants

# 4. Synthesize the Design
compile_ultra
check_timing

# 5. Sanitize Netlist Names (MUST BE HERE, AFTER COMPILE)
# Force strict Verilog naming conventions on all the new synthesized gates
change_names -rules verilog -hierarchy

# 6. Export Final Netlist and Reports
write -format verilog -hierarchy -output netlist/netlist_${design}.v
write -format ddc -hierarchy -output mapped/$design.ddc

cd reports
report_timing > timing_report_$design.rpt
report_area > area_report_$design.rpt
cd ..
