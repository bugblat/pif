-----------------------------------------------------------------------
-- flasher.vhd
--
-- Initial entry: 21-Apr-11 te
--
-- VHDL hierarchy is
--      flasher         top level
--      piffla.vhd        does the work!
--
-----------------------------------------------------------------------
--
-- Copyright (c) 2001 to 2013  te
--
-----------------------------------------------------------------------
library IEEE;       use IEEE.std_logic_1164.all;
library machxo2;    use machxo2.components.all;

--=====================================================================
entity flasher is
   port ( GSRn      : in  std_logic;
          LEDR,
          LEDG      : out std_logic   );
end flasher;

--=====================================================================
architecture rtl of flasher is
  -----------------------------------------------
  component pif_flasher is port ( red, green : out std_logic );
  end component pif_flasher;
  -----------------------------------------------

  signal red_flash,
         green_flash  : std_logic;

  signal GSRnX        : std_logic;
  attribute pullmode  : string;
  attribute pullmode of GSRnX: signal is "UP";  -- else floats

begin
  -- global reset
  IBgsr   : IB  port map ( I=>GSRn, O=>GSRnX );
  GSR_GSR : GSR port map ( GSR=>GSRnX );

  -----------------------------------------------
  -- LED flasher
  F: pif_flasher port map ( red         => red_flash,
                            green       => green_flash  );

  -----------------------------------------------
  -- drive the LEDs
  REDL: OB port map ( I=>red_flash  , O => LEDR    );
  GRNL: OB port map ( I=>green_flash, O => LEDG  );

end rtl;
-- EOF ----------------------------------------------------------------
