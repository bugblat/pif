pif - FPGA on a Raspberry Pi
============================

This is the software for Bugblat's *Raspberry Pi FPGA* board - the *pif* board.

What is the pif board?
----------------------

A pif board, which plugs into a Raspberry Pi, carries a non-volatile Lattice Semiconductor MachXO2 FPGA. 

To program the FPGA, you start by writing a firmware program, usually in VHDL or Verilog though there are other options. The firmware program can be  simulated and compiled to a JEDEC bitstream with Lattice's free 
*[Diamond](http://www.latticesemi.com/en/Products/DesignSoftwareAndIP/FPGAandLDS/LatticeDiamond.aspx)* 
software.  

Then you have to inject the bitstream into the pif's FPGA, and that's the job of the software in this repo. Primarily in Python, there are programs to

- program the onboard FPGA with a compiled bitstream
- control the FPGA firmware from the Raspberry Pi processor

Example FPGA firmware programs are also included, 
plus an example of controlling the FPGA from a web application. 

Many flavors of Linux are available for the Raspberry Pi. 
This software is written for the *Raspbian/wheezy* distribution.

More Information
----------------

The pif product pages, including links to the full documentation, are
[here](http://bugblat.com/products/pif).
