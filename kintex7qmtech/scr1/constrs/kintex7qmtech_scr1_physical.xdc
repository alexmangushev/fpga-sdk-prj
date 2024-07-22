##
## Copyright by Syntacore LLC © 2016, 2017, 2021. See LICENSE for details
## @file       <nexys4ddr_scr1_physical.xdc>
## @brief      Physical constraints file for Xilinx Vivado implementation.
##

## Clock & Reset
set_property -dict { PACKAGE_PIN F22    IOSTANDARD LVCMOS33 }   [get_ports CLK50MHZ]
set_property -dict { PACKAGE_PIN AF9    IOSTANDARD LVCMOS18 }   [get_ports CPU_RESETn]
set_property PULLUP     true                                    [get_ports CPU_RESETn]

## UART
set_property -dict { PACKAGE_PIN E10    IOSTANDARD LVCMOS33 }   [get_ports FTDI_RXD]
set_property -dict { PACKAGE_PIN B10    IOSTANDARD LVCMOS33 }   [get_ports FTDI_TXD]

## LEDs
set_property -dict { PACKAGE_PIN J26    IOSTANDARD LVCMOS33 }   [get_ports {LED[2]}]
set_property -dict { PACKAGE_PIN H26    IOSTANDARD LVCMOS33 }   [get_ports {LED[3]}]
#set_property -dict { PACKAGE_PIN J13    IOSTANDARD LVCMOS33 }   [get_ports {LED[2]}]

## PMOD Header JC ## Change
set_property -dict { PACKAGE_PIN B14    IOSTANDARD LVCMOS33 }   [get_ports {JC[3]}]
set_property -dict { PACKAGE_PIN C12    IOSTANDARD LVCMOS33 }   [get_ports {JC[0]}]
set_property -dict { PACKAGE_PIN A13    IOSTANDARD LVCMOS33 }   [get_ports {JC[1]}]
set_property -dict { PACKAGE_PIN D14    IOSTANDARD LVCMOS33 }   [get_ports {JC[2]}]

set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets {JC_IBUF[3]}]
set_property PULLDOWN   true    [get_ports {JC[3]}]
set_property PULLUP     true    [get_ports {JC[0]}]
set_property PULLUP     true    [get_ports {JC[1]}]
set_property PULLUP     true    [get_ports {JC[2]}]

## FPGA Configuration
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]