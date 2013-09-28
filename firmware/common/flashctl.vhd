-----------------------------------------------------------------------
-- flashctl.vhd
--
-- Initial entry: 21-Apr-11 te
--
-- VHDL hierarchy is
--      flasher         top level
--      piffla.vhd        does the work!
--      pifwb.vhd         wishbone interface
--        efb.vhd           XO2 embedded function block
--
-----------------------------------------------------------------------
--
-- Copyright (c) 2001 to 2013  te
--
-----------------------------------------------------------------------
library IEEE;       use IEEE.std_logic_1164.all;
library work;       use work.defs.all;
library machxo2;    use machxo2.components.all;

--=====================================================================
entity flasher is
   port ( SCL,
          SDA           : inout std_logic;
          GSRn          : in    std_logic;
          LEDR,
          LEDG          : out   std_logic   );
end flasher;

--=====================================================================
architecture rtl of flasher is
  -----------------------------------------------
  component pif_flasher is port (
      red,
      green,
      xclk          : out   std_logic       );
  end component pif_flasher;
  -----------------------------------------------
  component pifwb is port (
      i2c_SCL       : inout std_logic;
      i2c_SDA       : inout std_logic;
      xclk          : in    std_logic;
      XI            : out   XIrec;
      XO            : in    slv8            );
  end component pifwb;
  -----------------------------------------------
  component pifctl is port (
      xclk          : in    std_logic;
      XI            : in    XIrec;
      XO            : out   slv8;
      MiscReg       : out   TMisc           );
  end component pifctl;
  -----------------------------------------------

  signal  red_flash,
          green_flash,
          xclk        : std_logic     := '0';
  signal  XI          : XIrec         := (  PRdFinished => false
                                         ,  PWr         => false
                                         ,  PRWA        => 0
                                         ,  PRdSubA     => 0
                                         ,  PD          => (others=>'0'));
  signal  XO          : slv8          := (others=>'0');

  signal  GSRnX       : std_logic;
  signal  MiscReg     : TMisc;

  -- attach a pullup to the GSRn signal
  attribute pullmode  : string;
  attribute pullmode of GSRnX   : signal is "UP";   -- else floats

begin
  -- global reset
  IBgsr   : IB  port map ( I=>GSRn, O=>GSRnX );
  GSR_GSR : GSR port map ( GSR=>GSRnX );

  -----------------------------------------------
  -- wishbone interface
  WB: pifwb      port map ( i2c_SCL     => SCL,
                            i2c_SDA     => SDA,
                            xclk        => xclk,
                            XI          => XI,
                            XO          => XO           );

  -----------------------------------------------
  -- LED flasher
  F: pif_flasher port map ( red         => red_flash,
                            green       => green_flash,
                            xclk        => xclk         );

  -----------------------------------------------
  -- control logic
  TC: pifctl     port map ( xclk        => xclk,
                            XI          => XI,
                            XO          => XO,
                            MiscReg     => MiscReg      );

  -----------------------------------------------
  -- drive the LEDs
  LED_BLOCK : block
    signal r,g : std_logic;
  begin
    r <= red_flash    when MiscReg=LED_ALTERNATING else
         red_flash    when MiscReg=LED_SYNC        else
         '0';
    g <= green_flash  when MiscReg=LED_ALTERNATING else
         red_flash    when MiscReg=LED_SYNC        else
         '0';
    RED_BUF: OB port map ( I=>r, O => LEDR   );
    GRN_BUF: OB port map ( I=>g, O => LEDG );
  end block LED_BLOCK;

end rtl;
-- EOF ----------------------------------------------------------------
