onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider CPU
add wave -noupdate /bgs/U_CPU/clk
add wave -noupdate /bgs/U_CPU/rst
add wave -noupdate -radix unsigned /bgs/U_CPU/pc
add wave -noupdate -radix unsigned /bgs/U_CPU/stack
add wave -noupdate -radix unsigned /bgs/U_CPU/prog_data_a
add wave -noupdate -radix unsigned /bgs/U_CPU/prog_data_b
add wave -noupdate -divider States
add wave -noupdate /bgs/U_CPU/state
add wave -noupdate /bgs/U_CPU/fetch_s
add wave -noupdate /bgs/U_CPU/decode_s
add wave -noupdate -divider {Program Mem}
add wave -noupdate -radix decimal /bgs/U_DMA/prog_adr_a_i
add wave -noupdate -radix decimal /bgs/U_DMA/prog_adr_b_i
add wave -noupdate -radix decimal /bgs/U_DMA/prog_data_a_i
add wave -noupdate -radix unsigned /bgs/U_DMA/prog_data_b_i
add wave -noupdate -divider DMA
add wave -noupdate /bgs/io_mem
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 171
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {804 ps}
