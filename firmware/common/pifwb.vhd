-----------------------------------------------------------------------
-- pifwb.vhd    Bugblat pif central Wishbone/control logic
--
-- Initial entry: 05-Jan-12 te
-- Copyright (c) 2001 to 2013  te
--
-----------------------------------------------------------------------
-- read sequence via i2c
--  i2c transaction : addr, rd_data, rd_data, rd_data, ...
--
-----------------------------------------------------------------------
-- write sequence via i2c
--  i2c transaction is : addr, wr_data, wr_data, wr_data, ...
--
-- wr_data is
--   bits 7..6 : 00 - load address register - 64 registers, 16 used
--               01 - load data register
--               10 - reserved (was tx count)
--               11 - reserved
--   bits 5..0 : data value
--
-----------------------------------------------------------------------
library ieee;           use ieee.std_logic_1164.all;
                        use ieee.numeric_std.all;
library work;           use work.defs.all;
library machxo2;        use machxo2.components.all;

entity pifwb is
  port (
    i2c_SCL       : inout std_logic;
    i2c_SDA       : inout std_logic;
    xclk          : in    std_logic;
    XI            : out   XIrec;
    XO            : in    slv8            );
end pifwb;

architecture rtl of pifwb is

  ---------------------------------------------------------------------
  component efbx is port (
        wb_clk_i    : in    std_logic;
        wb_rst_i    : in    std_logic;
        wb_cyc_i    : in    std_logic;
        wb_stb_i    : in    std_logic;
        wb_we_i     : in    std_logic;
        wb_adr_i    : in    std_logic_vector(7 downto 0);
        wb_dat_i    : in    std_logic_vector(7 downto 0);
        wb_dat_o    : out   std_logic_vector(7 downto 0);
        wb_ack_o    : out   std_logic;
        i2c1_scl    : inout std_logic;
        i2c1_sda    : inout std_logic;
        i2c1_irqo   : out   std_logic       );
  end component efbx;
  ---------------------------------------------------------------------
  signal  wbCyc
        , wbStb
        , wbWe
        , wbAck_o     : std_logic;
  signal  wbDat_o
        , wbDat_i
        , wbAddr
        , wbOutBuff   : slv8 := (others=>'0');

  -- quasi-static data out from the USB
  signal  Xiloc       : XIrec;                -- local copy of XI
  signal  rst         : boolean := true;      -- assume initialiser is honoured

begin
  ---------------------------------------------------------------------
  -- Power-Up Reset for 16 clocks
  -- assumes initialisers are honoured by the synthesiser
  RST_BLK: block
    signal nrst      : boolean := false;
    signal rst_count : integer range 0 to 15 := 0;
  begin
    process (xclk) begin
      if rising_edge(xclk) then
        if rst_count /= 15 then
          rst_count <= rst_count +1;
        end if;
        nrst <= rst_count=15;
        rst  <= not nrst;
      end if;
    end process;
  end block RST_BLK;

  ------------------------------------------------
  -- wishbone state machine
  WBSM_B: block

    type TWBstate is ( WBstart,
                       WBinit1, WBinit2, WBinit3, WBinit4,
                       WBidle,
                       WBwaitTR,
                       WBin0, WBout0, WBout1,
                       WBwr, WBrd               );

    signal WBstate, rwReturn : TWBstate;

    signal busy, txReady, rxReady, lastTxNak, wbAck, isAddr, isData : boolean;

    -- wishbone/EFB addresses
    constant  I2C1_CR     : slv8 := x"40";
    constant  I2C1_CMDR   : slv8 := x"41";
    constant  I2C1_BR0    : slv8 := x"42";
    constant  I2C1_BR1    : slv8 := x"43";
    constant  I2C1_TXDR   : slv8 := x"44";
    constant  I2C1_SR     : slv8 := x"45";
    constant  I2C1_GCDR   : slv8 := x"46";
    constant  I2C1_RXDR   : slv8 := x"47";
    constant  I2C1_IRQ    : slv8 := x"48";
    constant  I2C1_IRQEN  : slv8 := x"49";

    constant  I2C2_CR     : slv8 := x"4A";
    constant  I2C2_CMDR   : slv8 := x"4B";
    constant  I2C2_BR0    : slv8 := x"4C";
    constant  I2C2_BR1    : slv8 := x"4D";
    constant  I2C2_TXDR   : slv8 := x"4E";
    constant  I2C2_SR     : slv8 := x"4F";
    constant  I2C2_GCDR   : slv8 := x"50";
    constant  I2C2_RXDR   : slv8 := x"51";
    constant  I2C2_IRQ    : slv8 := x"52";
    constant  I2C2_IRQEN  : slv8 := x"53";

    constant  CFG_CR      : slv8 := x"70";
    constant  CFG_TXDR    : slv8 := x"71";
    constant  CFG_SR      : slv8 := x"72";
    constant  CFG_RXDR    : slv8 := x"73";
    constant  CFG_IRQ     : slv8 := x"74";
    constant  CFG_IRQEN   : slv8 := x"75";

    signal  hitI2CSR
          , hitI2CRXDR
          , hitCFGRXDR
          , cfgBusy       : boolean;
    signal  RdSubAddr
          , WrSubAddr     : TXSubA;       -- sub-addresses
    signal  rwAddr        : TXA;
    signal  inData        : TwrData;
    signal  wbRst         : std_logic;

  begin
    -- used in debug mode to reset the internal 16-bit counters
    wbRst  <= '0'
-- synthesis translate_off
              or (to_sl(rst))
-- synthesis translate_on
              ;
    myEFB: efbx port map ( wb_clk_i  => xclk,
                           wb_rst_i  => wbRst,
                           wb_cyc_i  => wbCyc,
                           wb_stb_i  => wbStb,
                           wb_we_i   => wbWe,
                           wb_adr_i  => wbAddr,
                           wb_dat_i  => wbDat_i,
                           wb_dat_o  => wbDat_o,
                           wb_ack_o  => wbAck_o,
                           i2c1_scl  => i2c_SCL,
                           i2c1_sda  => i2c_SDA,
                           i2c1_irqo => open         );

    wbAck <= (wbAck_o = '1');

    process (xclk)
      variable  nextState : TWBstate;
      variable  vSlaveTransmitting
              , vTxRxRdy
              , vBusy
              , vTIP
              , vRARC
              , vTROE     : boolean;
      variable  vInst     : slv8;

      -----------------------------------------------------
      procedure Wr(addr:slv8; din:slv8; retState:TWBstate) is
      begin
        wbAddr    <= addr;
        wbDat_i   <= din;
        rwReturn  <= retState;
        nextState := WBwr;
      end procedure Wr;

      -----------------------------------------------------
      procedure Rd(addr:slv8; retState:TWBstate) is
      begin
        wbAddr    <= addr;
        wbDat_i   <= (others=>'0');
        rwReturn  <= retState;
        nextState := WBrd;
      end procedure Rd;

      -----------------------------------------------------
      procedure ReadRegAgain is
      begin
        nextState := WBrd;
      end procedure ReadRegAgain;

      -----------------------------------------------------

    begin
      if rising_edge(xclk) then
        nextState := WBstate;
        hitI2CSR   <= (wbAddr = I2C1_SR  );
        hitI2CRXDR <= (wbAddr = I2C1_RXDR);
        hitCFGRXDR <= (wbAddr = CFG_RXDR);

        if rst then
          nextState     := WBstart;
          rwReturn      <= WBstart;
          wbStb         <= '0';
          wbCyc         <= '0';
          wbWe          <= '0';
          busy          <= false;
          txReady       <= false;
          rxReady       <= false;
          lastTxNak     <= false;
          rwAddr        <= 0;
          RdSubAddr     <= 0;
          WrSubAddr     <= 0;
        else
          case WBstate is
            -----------------------------------
            -- initialise
            when WBstart =>
              Wr(I2C1_CMDR, x"04", WBinit1);  -- clock stretch disable

            when WBinit1 =>
              Rd(I2C1_SR, WBinit2);           -- wait for not busy

            when WBinit2 =>
              if busy then
                ReadRegAgain;
              else
                Rd(I2C1_RXDR, WBinit3);       -- read and discard RXDR, #1
              end if;

            when WBinit3 =>
              Rd(I2C1_RXDR, WBinit4);         -- read and discard RXDR, #2

            when WBinit4 =>
              Wr(I2C1_CMDR, x"00", WBidle);   -- clock stretch enable

            -----------------------------------
            -- wait for I2C activity - "busy" is signalled
            when WBidle =>
              if busy then                    -- I2C bus active?
                Rd(I2C1_SR, WBwaitTR);
              else
                Rd(I2C1_SR, WBidle);
              end if;

            -----------------------------------
            -- wait for TRRDY
            when WBwaitTR =>
              if lastTxNak then               -- last read?
                nextState := WBstart;
              elsif txReady then
                Wr(I2C1_TXDR, XO, WBout0);
              elsif rxReady then
                Rd(I2C1_RXDR, WBin0);
              elsif not busy then
                nextState := WBstart;
              else
                ReadRegAgain;
              end if;

            -----------------------------------
            -- incoming data
            when WBin0 =>
              nextState := WBidle;

            -----------------------------------
            -- outgoing data
            when WBout0 =>
              nextState := WBout1;

            when WBout1 =>
              nextState := WBidle;

            -----------------------------------
            -- read cycle
            when WBrd =>
              if wbAck then
                wbStb <= '0';
                wbCyc <= '0';
                if hitI2CSR then
                  vTIP               := (wbDat_o(7) = '1');
                  vBusy              := (wbDat_o(6) = '1');
                  vRARC              := (wbDat_o(5) = '1');
                  vSlaveTransmitting := (wbDat_o(4) = '1');
                  vTxRxRdy           := (wbDat_o(2) = '1');
                  vTROE              := (wbDat_o(1) = '1');
      txReady   <= vBusy and (vTxRxRdy and vSlaveTransmitting and not vTIP );
      rxReady   <= vBusy and (vTxRxRdy and not vSlaveTransmitting          );
      lastTxNak <= vBusy and (vRARC    and     vSlaveTransmitting and vTROE);
      busy      <= vBusy;
                end if;
                if hitI2CRXDR then
                  isAddr  <= (wbDat_o(TincomingTypeRange) = A_ADDR);
                  isData  <= (wbDat_o(TincomingTypeRange) = D_ADDR);
                  inData  <= wbDat_o(TincomingDataRange);
                end if;
                if hitCFGRXDR then
                  cfgBusy <= (wbDat_o(7) = '1');
                end if;

                wbOutBuff <= wbDat_o;
                nextState := rwReturn;
              else
                wbStb <= '1';
                wbCyc <= '1';
              end if;

            -----------------------------------
            -- write cycle
            when WBwr =>
              if wbAck then
                wbStb <= '0';
                wbCyc <= '0';
                wbWe  <= '0';
                nextState := rwReturn;
              else
                wbStb <= '1';
                wbCyc <= '1';
                wbWe  <= '1';
              end if;

            -----------------------------------
--          when others =>
--            nextState := WBstart;

          end case;
        end if;

        XiLoc.PRdFinished <= (WBstate = WBout0);

        if (WBstate = WBin0) and isAddr then
          rwAddr <= ToInteger(inData(TXARange));
        end if;

        if (WBstate = WBin0) and isAddr then
          RdSubAddr <= 0;
        elsif XiLoc.PRdFinished then
          RdSubAddr <= (RdSubAddr +1) mod (XSUBA_MAX+1);
        end if;

        if (WBstate = WBin0) and isAddr then
          WrSubAddr <= 0;
        elsif XiLoc.PWr then
          WrSubAddr <= (WrSubAddr +1) mod (XSUBA_MAX+1);
        end if;

        if (WBstate = WBin0) and isData then
          XiLoc.PD  <= inData;
          XiLoc.PWr <= true;
        else
          XiLoc.PWr <= false;
        end if;

        WBstate <= nextState;
      end if;
    end process;

    XiLoc.PRWA    <= rwAddr;
    XiLoc.PRdSubA <= RdSubAddr;

  end block WBSM_B;

  XI  <= XIloc;

end rtl;

-----------------------------------------------------------------------
-- EOF pifwb.vhd
