
# PlanAhead Launch Script for Pre-Synthesis Floorplanning, created by Project Navigator

create_project -name papilio-pro-j1 -dir "D:/FORTH/FPGA_FORTH/2020/j1 eForth/j1eforth_papilio_pro/fpga/planAhead_run_1" -part xc6slx9tqg144-3
set_param project.pinAheadLayout yes
set srcset [get_property srcset [current_run -impl]]
set_property target_constrs_file "D:/FORTH/FPGA_FORTH/2020/j1 eForth/j1eforth_papilio_pro/fpga/src/papilio-pro.ucf" [current_fileset -constrset]
set hdlfile [add_files [list {src/utils.vhd}]]
set_property file_type VHDL $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {src/Txunit.vhd}]]
set_property file_type VHDL $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {src/Rxunit.vhd}]]
set_property file_type VHDL $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {src/miniuart.vhd}]]
set_property file_type VHDL $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {src/j1.v}]]
set_property file_type Verilog $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {src/clock.vhd}]]
set_property file_type VHDL $hdlfile
set_property library work $hdlfile
set hdlfile [add_files [list {src/papilio-pro-j1.vhd}]]
set_property file_type VHDL $hdlfile
set_property library work $hdlfile
set_property top papilio_pro_j1 $srcset
add_files [list {D:/FORTH/FPGA_FORTH/2020/j1 eForth/j1eforth_papilio_pro/fpga/src/papilio-pro.ucf}] -fileset [get_property constrset [current_run]]
open_rtl_design -part xc6slx9tqg144-3
