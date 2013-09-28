-----------------------------------------------------------------------
-- piffla.vhd    Bugblat pif LED flasher
--
-- Initial entry: 05-Jan-12 te
--
-- Copyright (c) 2001 to 2012  te
--
-----------------------------------------------------------------------
library ieee;                 use ieee.std_logic_1164.all;
                              use ieee.numeric_std.all;

entity DownCounter is
  generic ( BITS : natural := 10);
  port (
    Clk,
    LoadN,
    CE           : in  std_logic;
    InitialVal   : in  unsigned(BITS-1 downto 0);
    zero         : out boolean         );
end DownCounter;

architecture rtl of DownCounter is
  attribute syn_hier       : string;
  attribute syn_hier of rtl: architecture is "hard";

  -- extended to get carry-out
  signal Ctr : unsigned(BITS downto 0) := (others=>'0');
begin

  process (Clk) begin
    if rising_edge(Clk) then
      if CE='1' then
        if LoadN='0' then
          Ctr <= '0' & InitialVal;
        else
          Ctr <= Ctr -1;
        end if;
      end if;
    end if;
  end process;

  zero  <= Ctr(BITS) = '1';
end rtl;

-----------------------------------------------------------------------
library ieee;                 use ieee.std_logic_1164.all;
                              use ieee.numeric_std.all;
--                            use ieee.math_real.all;
library machxo2;              use machxo2.components.all;

entity pif_flasher is port ( red, green, xclk : out std_logic );
end pif_flasher;

architecture rtl of pif_flasher is
  -----------------------------------------------
  component osch is
      -- synthesis translate_off
      generic (nom_freq: string := "2.08");
      -- synthesis translate_on
    port ( stdby    :in  std_logic;
           osc      :out std_logic;
           sedstdby :out std_logic );
  end component osch;
  -----------------------------------------------
  component DownCounter is generic (BITS : natural := 10);
    port (
      Clk          : in  std_logic;
      InitialVal   : in  unsigned(BITS-1 downto 0);
      LoadN,
      CE           : in  std_logic;
      zero         : out boolean         );
  end component DownCounter;
  -----------------------------------------------
  function to_sl(b: boolean) return std_logic is
  begin
    if b then return '1'; else return '0'; end if;
  end to_sl;
  -----------------------------------------------
  -- calculate the number of bits required to represent a given value
  function numBits(arg : natural) return natural is
  begin
    case arg is
      when 1 | 0 =>
        return 1;
      when others =>
        return 1 + numBits(arg/2);
    end case;
  end;
  ---------------------------------------------------------------------

  constant OSC_RATE : natural := (26600 * 1000);
  constant OSC_STR  : string  := "26.60";
  constant TICK_RATE: integer := 150;

  attribute nom_freq : string;
  attribute nom_freq of oscinst0 : label is OSC_STR;

  signal osc      : std_logic;

  -- each slot containing 2**B ticks
  constant B      : integer := 5;
  signal Tick     : boolean;

  -- the ramping LED signal
  signal LedOn    : boolean;

  -- red/green outputs
  signal R,G      : std_logic := '0';

  -- phase accumulator for the PWM
  signal Accum    : unsigned(B   downto 0) := (others=>'0');

  -- saw-tooth incrementing Phase Delta register
  signal DeltaReg : unsigned(B+1 downto 0) := (others=>'0');

  -- low bits of DeltaReg
  signal Delta    : unsigned(B-1 downto 0);

  -- high bits of DeltaReg
  signal LedPhase : unsigned(1 downto 0);

begin
  -------------------------------------------------------------
  -- instantiate the internal oscillator
  OSCInst0: osch
    -- synthesis translate_off
    generic map ( nom_freq => OSC_STR )
    -- synthesis translate_on
    port map ( stdby    => '0',         -- could use a standby signal
               osc      => osc,
               sedstdby => open   );    -- for simulation, use stdby_sed sig

  -------------------------------------------------------------
  -- generate the Tick clock
  TBLOCK: block
    -- divide down from 2MHz to approx 150Hz
    constant FREQ_DIV: natural := OSC_RATE/TICK_RATE;

    constant TICK_LEN: natural := FREQ_DIV
    -- synthesis translate_off
            - FREQ_DIV + 8                -- make the simulation reasonable!
    -- synthesis translate_on
      ;
    constant CLEN: natural := numBits(TICK_LEN);
    constant DIV : unsigned(CLEN-1 downto 0) := to_unsigned(TICK_LEN, CLEN);

    signal LoadN: std_logic;
  begin
    LoadN <= '0' when Tick else '1';
    TK:  DownCounter generic map ( BITS => CLEN )
                     port map    ( Clk        => osc,
                                   InitialVal => DIV,
                                   LoadN      => LoadN,
                                   CE         => '1',
                                   zero       => Tick );
  end block TBLOCK;

  -------------------------------------------------------------
  -- increment the Delta register and the 0.1.2.3 phase counter
  Delta    <= DeltaReg(Delta'range);
  LedPhase <= DeltaReg(DeltaReg'high downto DeltaReg'high-1);

  process (osc)
  begin
    if rising_edge(osc) then
      if Tick then
        DeltaReg <= DeltaReg+1;
      end if;
    end if;
  end process;

  -- generate the LED PWM signal
  process (osc)
    variable Acc, Delt: unsigned(Accum'range);
  begin
    if rising_edge(osc) then
      if Tick then
        Accum <= (others=>'0');
      else
        Acc := '0' & Accum(B-1 downto 0);   -- clear overflow to zero
        Delt:= '0' & Delta;                 -- bit-extend with zero
        Accum <= Acc + Delt;
      end if;

      LedOn <= (Accum(B) = '1');            -- overflow drives LED

      R <= not to_sl(((LedPhase=0) and LedOn) or ((LedPhase=1) and not LedOn));
      G <= not to_sl(((LedPhase=2) and LedOn) or ((LedPhase=3) and not LedOn));
    end if;
  end process;

  red   <= R;
  green <= G;
  xclk  <= osc;

end rtl;
-- EOF piffla.vhd -----------------------------------------------------
