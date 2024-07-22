##
## Copyright by Syntacore LLC © 2016, 2017, 2021. See LICENSE for details
## @file       <nexys4ddr_scr1_synth.xdc>
## @brief      Constraint file for Xilinx Vivado synthesis.
##

## Primary Clocks
set_property -dict { PACKAGE_PIN F22 IOSTANDARD LVCMOS33 } [get_ports CLK50MHZ]

create_clock -period 20.000     -name CLK50MHZ         -waveform {0.000 10.000}     -add [get_ports CLK50MHZ]
create_clock -period 33.333     -name CPU_CLK_VIRT      -waveform {0.000 16.666}
create_clock -period 100.000    -name JTAG_TCK          -waveform {0.000 50.000}    -add [get_ports {JC[3]}]
create_clock -period 100.000    -name JTAG_TCK_VIRT     -waveform {0.000 50.000}


