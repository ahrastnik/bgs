transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vcom -93 -work work {C:/Users/adamh/Documents/Intel/QuartusPrime/BGS/TIMER.vhd}
vcom -93 -work work {C:/Users/adamh/Documents/Intel/QuartusPrime/BGS/IO_PORT.vhd}
vcom -93 -work work {C:/Users/adamh/Documents/Intel/QuartusPrime/BGS/INSTRUCTS.vhd}
vcom -93 -work work {C:/Users/adamh/Documents/Intel/QuartusPrime/BGS/BUS_SLAVE.vhd}
vcom -93 -work work {C:/Users/adamh/Documents/Intel/QuartusPrime/BGS/BGS.vhd}
vcom -93 -work work {C:/Users/adamh/Documents/Intel/QuartusPrime/BGS/DMA.vhd}
vcom -93 -work work {C:/Users/adamh/Documents/Intel/QuartusPrime/BGS/MEM_PROG.vhd}
vcom -93 -work work {C:/Users/adamh/Documents/Intel/QuartusPrime/BGS/MEM_DATA.vhd}
vcom -93 -work work {C:/Users/adamh/Documents/Intel/QuartusPrime/BGS/CPU.vhd}
vcom -93 -work work {C:/Users/adamh/Documents/Intel/QuartusPrime/BGS/ALU.vhd}

