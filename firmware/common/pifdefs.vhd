-----------------------------------------------------------------------
-- pifdefs.vhd    Bugblat pif definitions
--
-- Initial entry: 05-Jan-12 te
-- Copyright (c) 2001 to 2013  te
--
-----------------------------------------------------------------------
library ieee;               use ieee.std_logic_1164.all;
                            use ieee.numeric_std.all;
library work;               use work.pifcfg.all;

package defs is

  -- save lots of typing
  subtype slv2  is std_logic_vector( 1 downto 0);
  subtype slv3  is std_logic_vector( 2 downto 0);
  subtype slv4  is std_logic_vector( 3 downto 0);
  subtype slv5  is std_logic_vector( 4 downto 0);
  subtype slv6  is std_logic_vector( 5 downto 0);
  subtype slv7  is std_logic_vector( 6 downto 0);
  subtype slv8  is std_logic_vector( 7 downto 0);
  subtype slv16 is std_logic_vector(15 downto 0);
  subtype slv32 is std_logic_vector(31 downto 0);

  -------------------------------------------------------------
  -- these constants are defined in outer 'pifcfg' files
  constant ID             : std_logic_vector(7 downto 0) := PIF_ID;
  constant DEVICE_DENSITY : string                       := XO2_DENSITY;

  -- I2C interface --------------------------------------------

  constant A_ADDR         : slv2 := "00";
  constant D_ADDR         : slv2 := "01";

  constant I2C_TYPE_BITS  : integer := 2;
  constant I2C_DATA_BITS  : integer := 6;

  subtype TincomingTypeRange is integer range 7 downto I2C_DATA_BITS;
  subtype TincomingDataRange is integer range (I2C_DATA_BITS-1) downto 0;

  subtype TwrData   is std_logic_vector(TincomingDataRange);
  subtype TbyteType is std_logic_vector(TincomingTypeRange);

  constant XA_BITS        : integer := 4;                 -- 16 registers
  constant XSUBA_BITS     : integer := 7;                 -- 128 sub-addresses
  constant XSUBA_MAX      : integer := 2**XSUBA_BITS -1;

  subtype TXARange is integer range XA_BITS-1 downto 0;
  subtype TXA      is integer range 0 to 2**XA_BITS -1;
  subtype TXSubA   is integer range 0 to XSUBA_MAX;

  subtype TXDRange is integer range 0 to (2**I2C_DATA_BITS) -1;

  -------------------------------------------------------------
  type XIrec is record          -- write data for regs
    PWr         : boolean;      -- registered single-clock write strobe
    PRWA        : TXA;          -- registered incoming addr bus
    PRdFinished : boolean;      -- registered in clock PRDn goes off
    PRdSubA     : TXSubA;       -- read sub-address
    PD          : TwrData;      -- registered incoming data bus
  end record XIrec;

  -------------------------------------------------------------
  -- ID register, read-only
  constant R_ID             : TXA := 0;

  -- ID subregisters
  --  0     ID                        BX4/8/16 = G/L/A
  --  1     Scratch
  --  2     Misc                      plus 30h -> 0/1/2/3
  --  3..31 ID letter                 abcdefghij...
  --
  constant R_ID_NUM_SUBS    : integer := 32;
  constant R_ID_ID          : integer := 0;
  constant R_ID_SCRATCH     : integer := 1;
  constant R_ID_MISC        : integer := 2;

  -- Scratch register, write here, read via R_ID, subaddr 1
  constant W_SCRATCH_REG    : TXA := 1;

  -- Misc register, write here, read via R_ID, subaddr 2
  -- one of the examples uses this register to control the LEDs
  constant W_MISC_REG       : TXA := 2;
  subtype TMisc is integer range 0 to 2;
  constant  LED_ALTERNATING : TMisc := 0;
  constant  LED_SYNC        : TMisc := 1;
  constant  LED_OFF         : TMisc := 2;

  -------------------------------------------------------------
  -- intercept calls to conv_integer and to_integer
  function ToInteger(arg: std_logic_vector) return integer;
  function ToInteger(arg:         unsigned) return integer;
  function ToInteger(arg:           signed) return integer;

  -- convert boolean to std_logic ( t->1, f->0 )
  function to_sl(b: boolean) return std_logic;

  -- convert to std_logic vector
  function n2slv   (n,l: natural ) return std_logic_vector;

end package defs;

--=============================================================
package body defs is
  -------------------------------------------------------------
  -- put the to_integer/conv_integer resolution in one place
  function ToInteger(arg: unsigned) return integer is
    variable x: unsigned(arg'range);
    variable n: integer;
  begin
    x := arg;
    -- synthesis translate_off
    for i in x'range loop
      if x(i)/='1' then       -- resolve the 'undefined' signals
        x(i) := '0';
      end if;
    end loop;
    -- synthesis translate_on
    n := to_integer(x);
    return n;
  end;
  -------------------------------------------------------------
  function ToInteger(arg: signed) return integer is
    variable x: signed(arg'range);
    variable n: integer;
  begin
    x := arg;
    -- synthesis translate_off
    for i in x'range loop
      if x(i)/='1' then
        x(i) := '0';
      end if;
    end loop;
    -- synthesis translate_on
    n := to_integer(x);
    return n;
  end;
  -------------------------------------------------------------
  function ToInteger(arg: std_logic_vector) return integer is
    variable x: unsigned(arg'range);
    variable n: integer;
  begin
    x := unsigned(arg);
    -- synthesis translate_off
    for i in x'range loop
      if x(i)/='1' then       -- resolve the 'undefined' signals
        x(i) := '0';
      end if;
    end loop;
    -- synthesis translate_on
    n := to_integer(x);
    return n;
  end;
  -------------------------------------------------------------
  function ToInteger(arg: std_ulogic_vector) return integer is
    variable x: std_logic_vector(arg'range);
  begin
    x := std_logic_vector(arg);
    return ToInteger(x);
  end;
  -------------------------------------------------------------
  function to_sl(b: boolean) return std_logic is
    variable s: std_logic;
  begin
    if b then s :='1'; else s :='0'; end if;
    return s;
  end to_sl;
  -------------------------------------------------------------
  function n2slv ( N,L: natural ) return std_logic_vector is
    variable vec: std_logic_vector(L-1 downto 0);
    variable Nx : natural;
  begin
    Nx := N rem 2**L;
    vec := std_logic_vector(to_unsigned(Nx,L));
    return vec;
  end;

end package body defs;

-- EOF pifdefs.vhd --------------------------------------------
