## ========= Clock =========
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports { clk100mhz }]

## System clock: constrained at 50 MHz (20 ns period) for timing closure.
## Board oscillator at pin E3 is 100 MHz; see report Limitations for discussion.
create_clock -add -name sys_clk -period 20.00 -waveform {0 10} [get_ports { clk100mhz }]

## ========= Reset button (BTNC) =========
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports { btnC }]

## ========= PS/2 (USB-HID emulated PS/2 from PIC24) =========
set_property -dict { PACKAGE_PIN F4 IOSTANDARD LVCMOS33 } [get_ports { ps2_clk }]
set_property -dict { PACKAGE_PIN B2 IOSTANDARD LVCMOS33 } [get_ports { ps2_data }]

## PS/2 requires pull-ups (idle-high open-drain style)
set_property PULLUP true [get_ports { ps2_clk }]
set_property PULLUP true [get_ports { ps2_data }]

## ========= LEDs led[15:0] =========
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports { led[0]  }]
set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 } [get_ports { led[1]  }]
set_property -dict { PACKAGE_PIN J13 IOSTANDARD LVCMOS33 } [get_ports { led[2]  }]
set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports { led[3]  }]
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports { led[4]  }]
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports { led[5]  }]
set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports { led[6]  }]
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports { led[7]  }]
set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports { led[8]  }]
set_property -dict { PACKAGE_PIN T15 IOSTANDARD LVCMOS33 } [get_ports { led[9]  }]
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports { led[10] }]
set_property -dict { PACKAGE_PIN T16 IOSTANDARD LVCMOS33 } [get_ports { led[11] }]
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports { led[12] }]
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports { led[13] }]
set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 } [get_ports { led[14] }]
set_property -dict { PACKAGE_PIN V11 IOSTANDARD LVCMOS33 } [get_ports { led[15] }]

## ========= 7-seg digit enables an[7:0] (active-low) =========
set_property -dict { PACKAGE_PIN J17 IOSTANDARD LVCMOS33 } [get_ports { an[0] }]
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } [get_ports { an[1] }]
set_property -dict { PACKAGE_PIN T9  IOSTANDARD LVCMOS33 } [get_ports { an[2] }]
set_property -dict { PACKAGE_PIN J14 IOSTANDARD LVCMOS33 } [get_ports { an[3] }]
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports { an[4] }]
set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS33 } [get_ports { an[5] }]
set_property -dict { PACKAGE_PIN K2  IOSTANDARD LVCMOS33 } [get_ports { an[6] }]
set_property -dict { PACKAGE_PIN U13 IOSTANDARD LVCMOS33 } [get_ports { an[7] }]

## ========= 7-seg segments seg[6:0] =========
## Your RTL uses seg = {a,b,c,d,e,f,g} => seg[6]=a ... seg[0]=g
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports { seg[6] }] ;# CA (a)
set_property -dict { PACKAGE_PIN R10 IOSTANDARD LVCMOS33 } [get_ports { seg[5] }] ;# CB (b)
set_property -dict { PACKAGE_PIN K16 IOSTANDARD LVCMOS33 } [get_ports { seg[4] }] ;# CC (c)
set_property -dict { PACKAGE_PIN K13 IOSTANDARD LVCMOS33 } [get_ports { seg[3] }] ;# CD (d)
set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33 } [get_ports { seg[2] }] ;# CE (e)
set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33 } [get_ports { seg[1] }] ;# CF (f)
set_property -dict { PACKAGE_PIN L18 IOSTANDARD LVCMOS33 } [get_ports { seg[0] }] ;# CG (g)

## decimal point
set_property -dict { PACKAGE_PIN H15 IOSTANDARD LVCMOS33 } [get_ports { dp }]

## ========= Additional Timing Constraints =========
## These fix the TIMING-18 warnings about missing I/O delays

## Input delays - assuming external signals arrive within 2ns of clock edge
set_input_delay -clock sys_clk -max 2.0 [get_ports btnC]
set_input_delay -clock sys_clk -max 2.0 [get_ports ps2_clk]
set_input_delay -clock sys_clk -max 2.0 [get_ports ps2_data]

## Output delays - assuming external loads need 2ns setup time
set_output_delay -clock sys_clk -max 2.0 [get_ports led[*]]
set_output_delay -clock sys_clk -max 2.0 [get_ports seg[*]]
set_output_delay -clock sys_clk -max 2.0 [get_ports an[*]]
set_output_delay -clock sys_clk -max 2.0 [get_ports dp]

## PS/2 signals are asynchronous (no phase relationship to sys_clk).
## Metastability is handled in RTL by the 3-stage synchronizer in ps2_rx.v.
## set_false_path is the correct constraint for async inputs with RTL synchronizers.
set_false_path -from [get_ports ps2_clk] -to [all_registers]
set_false_path -from [get_ports ps2_data] -to [all_registers]
