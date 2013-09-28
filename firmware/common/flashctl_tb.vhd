-- testbench for flasher xo2 design
-- ============================================================
library ieee;                   use ieee.std_logic_1164.all;
                                use ieee.NUMERIC_STD.all;
                                use ieee.std_logic_textio.all;
                                use std.textio.all;

library work;                   use work.defs.all;

entity test is
end test;

---------------------------------------------------------------
architecture test_arch of test is

constant MAX_BUF : integer := 250;
type Tdata is array (0 to MAX_BUF) of integer;

type Tbuf is record
  count : integer;
  data  : Tdata;
end record Tbuf;

constant MAX_KEYLEN : integer := 8;    -- keyword length
constant MAX_LINE   : integer := 132;  -- input or output

function ToUpper( x : string ) return string is
  variable s : string(1 to x'length);
  variable c: character;
  variable p: integer;
begin
  for i in 1 to x'length loop
    c := x(i);
    p := character'pos(c);
    if p >= character'pos('a') and p <= character'pos('z') then
      p := p + character'pos('A') - character'pos('a');
    end if;
    s(i) := character'val(p);
  end loop;
  return s;
end ToUpper;

function str( x : std_logic_vector ) return string is
  variable r : line;
  variable s : string(1 to x'length) := (others => ' ');
begin
  write( r, x );
  s(r.all'range) := r.all;
  deallocate(r);
  return s;
end str;

function str( x : integer ) return string is
  variable u : unsigned(31 downto 0);
begin
    u := to_unsigned(x,32);
    return str(std_logic_vector(u));
end str;

function hstr( x : std_logic_vector ) return string is
  variable r : line;
  variable s : string(1 to (x'length)/4) := (others => ' ');
begin
  hwrite( r, x );
  s(r.all'range) := r.all;
  deallocate(r);
  return "0x" & s;
end hstr;

function hstr( x : unsigned ) return string is
begin
    return hstr(std_logic_vector(x));
end hstr;

function hstr( x : integer ) return string is
  variable u : unsigned(31 downto 0);
begin
    u := to_unsigned(x,32);
    return hstr(std_logic_vector(u));
end hstr;

function hstr8( x : integer ) return string is
  variable u : unsigned(7 downto 0);
begin
    u := to_unsigned(x,8);
    return hstr(std_logic_vector(u));
end hstr8;

function nstr( n : integer; len: integer ) return string is
  variable r : line;
  variable s : string(1 to len);
begin
  write( r, n );
  s(r.all'range) := r.all;
  deallocate(r);
  return s;
end nstr;

signal TestFinished : boolean := false;         -- set 'true' at end of sim

component flasher is port (
    SCL,
    SDA           : inout std_logic;
    GSRn          : in    std_logic;
    LEDR,
    LEDG          : out   std_logic
    );
end component flasher;

-----------------------------------------------------------------------
signal  ExtClock,
        RSTn        : std_logic := '0';

signal RedLedn,  GreenLedn  : std_logic;
signal TrigInPad, ClkInPad  : std_logic := '0';

signal outBuf, inBuf : Tbuf;

---------------------------------------------
-- I2C
signal  i2cSCL, i2cSDA          : std_logic := 'H';
signal  i2c_sclIn, i2c_sdaIn,
        i2c_din                 : std_logic := '0';
signal  i2c_sclOut, i2c_sdaOut  : std_logic := '1';
signal  i2c_addr                : slv8      := x"82";
signal  i2cToggle               : boolean   := true;
signal  i2cAckn                 : std_logic;

signal  obSig                   : Tbuf      := (count=>0, data=>(others=>0));
---------------------------------------------
begin
    -- instantiate the design
    UUT : flasher port map ( SCL          => i2cSCL
                           , SDA          => i2cSDA
                           , GSRn         => RSTn
                           , LEDR         => RedLedn
                           , LEDG         => GreenLedn
                           );

    i2cSCL <= 'H';
    i2cSDA <= 'H';

    EXT_CLK: process
      constant E_PERIOD: time := 50 ns;
    begin
      ExtClock <= '0'; wait for E_PERIOD/2;
      ExtClock <= '1'; wait for E_PERIOD/2;
      if TestFinished then wait; end if;
    end process EXT_CLK;

  i2cSCL <= '0' when i2c_sclOut='0' else 'Z';
  i2cSDA <= '0' when i2c_sdaOut='0' else 'Z';

  i2c_sdaIn <= to_x01(i2cSDA);
  i2c_sclIn <= to_x01(i2cSCL);

  process (i2c_sclIn) begin
    if rising_edge(i2c_sclIn) then
      i2c_din <= i2c_sdaIn;
    end if;
  end process;

-- ============================================================
-- main testbench 'stimulus' process
-- ============================================================
STIMULUS: process

  variable  Lin,Lout    : line;
  variable  LineNum     : natural   := 0;
  variable  keyword     : string(1 to MAX_KEYLEN);
  variable  Reg,Val,x   : integer   := 0;
  variable  v0,v1,v2,v3,v4,v5,v6    : integer := 0;
  variable  len         : integer;

  variable  Ibuff       : string(1 to MAX_LINE);
  variable  Ibuffstrt   : integer;
  variable  Ibuffend    : integer;

  constant  x1          : time      := 2500 ns;        -- i2c clock
  constant  x2          : time      := x1 / 2;

  variable  outBuf      : Tbuf      := (count=>0, data=>(others=>0));

    function ToUpper(ch: character) return character is
      variable c: character;
    begin
      c := ch;
      if c>='a' and c<='z' then
        c :=character'val(  character'pos(c)
                          + character'pos('A')
                          - character'pos('a')  );
      end if;
      return c;
    end function ToUpper;

    procedure GetCh(ch: out character; good: out boolean) is
    begin
      if Ibuffstrt <= Ibuffend then
        ch := Ibuff(Ibuffstrt);
        Ibuffstrt := Ibuffstrt+1;
        good := true;
      else
        ch := ';';
        good := false;
      end if;
    end procedure GetCh;

    function IsWS(c: character) return boolean is
    begin
      return (c=' ' or c=HT);
    end function IsWS;

    procedure PutBack(c : character) is
    begin
      Ibuffstrt := Ibuffstrt-1;
      Ibuff(Ibuffstrt) := c;
    end procedure PutBack;

    procedure SkipSpaces is
      variable c: character;
      variable good: boolean;
    begin
      -- eat the leading spaces
      L: loop
        GetCh(c, good);
        exit L when not good;
        if not IsWS(c) then
          PutBack(c);
          exit L;
        end if;
      end loop L;
    end;

    impure function  InputStr return string is
      variable n : integer := 0;
      variable c: character;
      variable good: boolean;
      variable s: string(1 to MAX_LINE);    -- := (others=>' ');
    begin
      SkipSpaces;
      L: loop
        GetCh(c, good);
        exit L when not good;
        exit L when IsWS(c);
        n := n+1;
        s(n) := c;
      end loop L;
      return s(1 to n);
    end function InputStr;

    procedure ReadKeyword(str: out string) is
      variable s    : string(1 to str'length);
      variable n    : integer;
    begin
      for i in 1 to s'length loop
        s(i) := '_';
      end loop;
      SkipSpaces;
      -- read the keyword
      n := 0;
      while (Ibuff(Ibuffstrt) /= ' ')
            and (Ibuff(Ibuffstrt) /= HT)
            and (Ibuffstrt <= Ibuffend) loop
        n := n+1;
        if n <= str'length then
          s(n) := Ibuff(Ibuffstrt);    -- don't want to overflow
        end if;
        Ibuffstrt := Ibuffstrt+1;
      end loop;
      str := s;
    end ReadKeyword;

    procedure InputDecAsInt( x: out integer) is
      variable c    : character;
      variable n    : integer := 0;
    begin
      SkipSpaces;
      while (Ibuff(Ibuffstrt) >= '0')
            and (Ibuff(Ibuffstrt) <= '9')
            and (Ibuffstrt <= Ibuffend) loop
        c := Ibuff(Ibuffstrt);
        n := n*10 + character'pos(c) - character'pos('0');
        Ibuffstrt := Ibuffstrt+1;
      end loop;
      x := n;
    end InputDecAsInt;

    procedure InputHexAsInt( x: out integer) is
      variable n    : integer := 0;
      variable c    : character;
    begin
      SkipSpaces;
      while Ibuffstrt <= Ibuffend loop
        c := Ibuff(Ibuffstrt);
        if '0' <= c and c <= '9' then
          n := n*16 + character'pos(c) - character'pos('0');
        elsif 'A' <= c and c <= 'F' then
          n := n*16 + character'pos(c) - character'pos('A') + 10;
        elsif 'a' <= c and c <= 'f' then
          n := n*16 + character'pos(c) - character'pos('a') + 10;
        else exit;
        end if;
        Ibuffstrt := Ibuffstrt+1;
      end loop;
      x := n;
    end InputHexAsInt;

    procedure InputHexAsSLV32( x: out slv32) is
      variable n : integer;
      variable sn: slv4;
      variable r : slv32 := (others=>'0');
      variable c : character;
      variable i : integer := 0;
    begin
      SkipSpaces;
      while Ibuffstrt <= Ibuffend and i<8 loop
        c := Ibuff(Ibuffstrt);
        if '0' <= c and c <= '9' then
          n := character'pos(c) - character'pos('0');
        elsif 'A' <= c and c <= 'F' then
          n := character'pos(c) - character'pos('A') + 10;
        elsif 'a' <= c and c <= 'f' then
          n := character'pos(c) - character'pos('a') + 10;
        else exit;
        end if;
        sn := n2slv(n, 4);
        r := r(27 downto 0) & sn;
        Ibuffstrt := Ibuffstrt+1;
        i := i+1;
      end loop;
      x := r;
    end InputHexAsSLV32;

    procedure Inputline( Lin : inout line;
                         str: out string; len: out integer) is
      variable s    : string(1 to MAX_LINE);
      variable c    : character;
      variable n    : integer;
    begin
      n := Lin'length;
      L: for i in 1 to n loop
        read(Lin,c);
        s(i) := ToUpper(c);
      end loop L;
      str := s;
      len := n;
    end Inputline;

    procedure WaitFor ( n : natural ) is
    begin
      for i in 1 to n loop
        wait until rising_edge(ExtClock);   -- wait for n clocks
      end loop;
    end;

    procedure write_string(L: inout line; v: in string) is
      begin
        write(L, v);
      end write_string;

    ---------------------------------------------
    --       <--- i2cStart ---->   or <-- Rep i2cStart ->
    -- time     |   |   |   |         |   |   |   |
    -- sda    ~~~~~~~~~~\_____      __/~~~~~~~\_____
    -- scl    __/~~~~~~~~~~~\__     ______/~~~~~~~\__
    procedure i2cStart is
    begin
      i2c_sdaOut <= '1';    wait for x2;
      i2c_sclOut <= '1';    wait for x2;
      i2c_sdaOut <= '0';    wait for x2;
      i2c_sclOut <= '0';    wait for x2;
    end procedure i2cStart;

    ---------------------------------------------
    -- time     |   |   |   | or    |   |   |   |
    -- sda    __________/~~~    ~~~~\______/~~~
    -- scl    ______/~~~~~~~     ______/~~~~~~~
    procedure i2cStop is
    begin
      i2c_sdaOut <= '0';    wait for x2;
      i2c_sclOut <= '1';    wait for x2;
      i2c_sdaOut <= '1';    wait for x2;
    end procedure i2cStop;

    ---------------------------------------------
    -- time     |   |   |   |
    -- sda     a bbbbbbbbbbb
    -- scl     _____/~~~\___
    procedure i2cSendBit(b:std_logic) is
    begin
      i2c_sdaOut <=  b ;    wait for x2;
      i2c_sclOut <= '1';    wait for x2;
      i2c_sclOut <= '0';    wait for x2;
    end procedure i2cSendBit;

    ---------------------------------------------
    procedure i2cDoClock is
    begin
      i2c_sclOut <= '0';    wait for x2;
      i2c_sclOut <= '1';    wait for x2;
      i2c_sclOut <= '0';    wait for x2;
    end procedure i2cDoClock;

    ---------------------------------------------
    procedure i2cSendByte(v:slv8) is
    begin
      for i in 7 downto 0 loop
        i2cSendBit(v(i));
      end loop;

      i2cDoClock;      -- after this, ack=0/nak=1 in i2c_din
--wait for x2 * 4;
      i2cAckn   <= i2c_din;
      i2cToggle <= not i2cToggle;
    end procedure i2cSendByte;

    ---------------------------------------------
    procedure i2cRecvBit(v: out slv8; i2cAckn:std_logic) is
      variable bi : slv8;
    begin
      bi := (others=>'0');
      for i in 7 downto 0 loop
        i2cSendBit('1');
        bi := bi(6 downto 0) & i2c_din;
      end loop;

      i2cSendBit(i2cAckn);   -- send ack=0/nak=1

--wait for x2 * 4;
      v := bi;
      i2cToggle <= not i2cToggle;
    end procedure i2cRecvBit;

    ---------------------------------------------
    procedure i2cWrStart is begin
      i2cStart;
      i2cSendByte(i2c_addr(7 downto 1) & '0');
    end i2cWrStart;

    ---------------------------------------------
    procedure i2cRdStart is begin
      i2cStart;
      i2cSendByte(i2c_addr(7 downto 1) & '1');
    end i2cRdStart;

    ---------------------------------------------
    procedure writeBus(x : in slv8) is
      variable n: integer;
    begin
      n := outBuf.count;
      outBuf.data(n) := ToInteger(x);
      outBuf.count   := n + 1;
      obSig <= outBuf;
      WaitFor(1);
    end writeBus;

    procedure writeD(V : in TwrData) is
    begin
      writeBus(D_ADDR & V);
    end writeD;

    procedure writeD(V : in integer) is
      variable x: TwrData;
    begin
      x := n2slv(V,I2C_DATA_BITS);
      writeD(x);
    end writeD;

    procedure writexD(x : in slv8) is
    begin
      writeD(ToInteger(x));
    end writexD;

    procedure writeA(Addr: in integer) is
    begin
      writeBus(A_ADDR & n2slv(Addr,I2C_DATA_BITS));
    end writeA;

    ---------------------------------------------
    procedure flush is
      variable n : integer;
    begin
      n := outBuf.count;
      if n>0 then
        WaitFor(1);
        wait for 5 ns;
        i2cWrStart;
        for i in 0 to (n-1) loop
          i2cSendByte(n2slv(outBuf.data(i), 8));
          outBuf.count := outBuf.count -1;
          obSig <= outBuf;
        end loop;
        i2cStop;
      end if;
    end flush;

    ---------------------------------------------
    procedure readReg(rdCount:integer) is
      variable i2cAckn : std_logic;
      variable v       : slv8;
    begin
      i2cRdStart;
      for i in 0 to (rdCount-1) loop
        if i < (rdCount-1) then
          i2cAckn := '0';
        else
          i2cAckn := '1';
        end if;
        i2cRecvBit(v, i2cAckn);
        write_string(Lout, ".  Value: " & hstr8(ToInteger(v)));
      end loop;
      i2cStop;
    end readReg;

------------------------------------------------------------------
  variable  dummy   : integer;
  variable  trace   : boolean := true;
  variable  Count   : integer;

  file CommandFile  : text;

-----------------------------
-- body of process 'STIMULUS'
-----------------------------
-- read:
--    read hex_addr decimal_num
--    results in the rdData array
-- data to wrData array
--    data hex_data
-- address to wrData array
--    addr hex_addr
-- write:
--    write
--    takes data from the wrData array
begin
    TestFinished <= false;

    write_string(Lout,"Resetting...");
    writeline(OUTPUT, Lout);
    RSTn <= '0';
    wait for 100 ns;
    RSTn <= '1';

    write_string(Lout,"Running...");
    writeline(OUTPUT, Lout);
    wait for 50 ns;

    file_open(CommandFile, "..\..\test.txt", read_mode);
    MainLoop: loop
      exit MainLoop when endfile(CommandFile);
      readline(CommandFile, Lin);
      LineNum := LineNum + 1;

      next MainLoop when Lin'length=0;     -- skip empty lines
      InputLine(Lin, Ibuff, Ibuffend);
      Ibuffstrt := 1;

      ReadKeyword(keyword);
      if trace then
         write_string(Lout, "Tr: " & keyword & " Ln ");
         write(Lout, LineNum);
         write_string(Lout, ".  " & Ibuff );
         writeline(OUTPUT, Lout);
      end if;
      next MainLoop when keyword(2)='_'; -- skip junk line at some file ends

      case keyword is
        when "REM_____"  =>
              dummy := 0;               -- for debugging
        when "WRITE_A_"  =>
              InputDecAsInt(Val);
              writeA(Val);
        when "WRITE_D_"  =>
              InputHexAsInt(Val);
              writeD(Val);
        when "FLUSH___"  =>
              flush;
        when "READ____"  =>
              InputDecAsInt(Reg);
              writeA(Reg);
              flush;
              write_string(Lout, "  Read of register ");
              write(Lout, Reg );
              ReadReg(1);
              writeline(OUTPUT, Lout);
        when "READMULT"  =>
              InputDecAsInt(Reg);
              InputDecAsInt(Count);
              writeA(Reg);
              flush;
              write_string(Lout, "  Read multiple (");
              write(Lout, Count );
              write_string(Lout, ") of register ");
              write(Lout, Reg );
              ReadReg(Count);
              writeline(OUTPUT, Lout);
        when "ECHO____"  =>
              SkipSpaces;
              write_string(Lout, Ibuff(Ibuffstrt to Ibuffend));
              writeline(OUTPUT, Lout);
        when "TRACE___"  =>
              InputDecAsInt(Val);
              trace := Val/=0;
        when "QUIT____"  =>
              write_string(Lout,"    QUIT command seen. Exiting.");
              writeline(OUTPUT, Lout);
              exit MainLoop;
        when others      =>
           assert false
             report "Unexpected command: " & keyword
             severity ERROR;
      end case;

    end loop MainLoop;
    file_close(CommandFile);

    WaitFor(10);
    TestFinished <= true;
    wait;            -- Suspend simulation

end process STIMULUS;
end test_arch;
-- EOF --------------------------------------------------------
