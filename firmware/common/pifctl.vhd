-----------------------------------------------------------------------
-- pifctl.vhd    Bugblat pif central control logic
--
-- Initial entry: 31-May-13 te
-- Copyright (c) 2001 to 2013  te
--
-----------------------------------------------------------------------
library ieee;           use ieee.std_logic_1164.all;
                        use ieee.numeric_std.all;
library work;           use work.defs.all;

entity pifctl is
  port (xclk            : in    std_logic;
        XI              : in    XIrec;
        XO              : out   slv8;
        MiscReg         : out   TMisc  );
end pifctl;

architecture rtl of pifctl is

  signal  ScratchReg    : TwrData := n2slv(21, I2C_DATA_BITS);  -- 15h
  signal  MiscRegLocal  : TMisc   := LED_SYNC;

begin
  ---------------------------------------------------------------------
  -- the inner case statement can be extended to write to many registers
  process (xclk)
  begin
    if rising_edge(xclk) then
      if XI.PWr then
        case XI.PRWA is

          when W_SCRATCH_REG =>
            ScratchReg <= XI.PD;

          when W_MISC_REG =>
            MiscRegLocal <= ToInteger(XI.PD);

          when others => null;
        end case;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------
  -- readout to the wishbone controller
  READBACK: block
    signal IdReadback : slv8;
  begin
    -----------------------------------------------
    -- ID/Scratch/Misc register readback
    process (xclk)
      variable subAddr    : integer range R_ID_NUM_SUBS-1 downto 0;
      variable IDscratch
             , IDletter
             , subOut
             , regOut     : slv8;
    begin
      if rising_edge(xclk) then
        IDscratch := "01" & ScratchReg;
        IDletter  := n2slv(6, 4) & n2slv(XI.PRdSubA, 4); -- 61h='a'...

        subAddr := XI.PRdSubA mod R_ID_NUM_SUBS;

        subOut  := IDletter;

        if (subAddr = R_ID_ID) then
          subOut := ID;
        end if;
        if (subAddr = R_ID_SCRATCH) then
          subOut := IDscratch;
        end if;
        if (subAddr = R_ID_MISC) then
          subOut := n2slv(5, 4) & n2slv(MiscRegLocal, 4);  -- 50h='P'...
        end if;

        regOut := (others=>'0');
        if (XI.PRWA = R_ID) then
          regOut := subOut;
        end if;

        IdReadback <= regOut;
      end if;
    end process;

    XO      <= IdReadback;
    MiscReg <= MiscRegLocal;

  end block READBACK;

end rtl;

-----------------------------------------------------------------------
-- EOF pifctl.vhd
