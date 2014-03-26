-------------------------------------------------------------------------------
-- Title      : Serial DAC interface
-- Project    : White Rabbit Switch
-------------------------------------------------------------------------------
-- File       : serial_dac.vhd
-- Author     : paas, slayer
-- Company    : CERN BE-Co-HT
-- Created    : 2010-02-25
-- Last update: 2011-05-10
-- Platform   : fpga-generic
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: The dac unit provides an interface to a 16 bit serial Digita to Analogue converter (max5441, SPI?/QSPI?/MICROWIRE? compatible) 
--
-------------------------------------------------------------------------------
-- Copyright (c) 2010 CERN
-------------------------------------------------------------------------------
-- Revisions  :1
-- Date        Version  Author  Description
-- 2009-01-24  1.0      paas    Created
-- 2010-02-25  1.1      slayer  Modified for rev 1.1 switch
-------------------------------------------------------------------------------
-- 2014-03-25	Juliano Murari (LNLS)	Adapted to dac_spi.vhd

library IEEE;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


entity dac_spi is

  generic (
    g_num_data_bits  : integer := 24;
    --~ g_num_data_bits  : integer := 4;
    g_num_extra_bits : integer := 0;
    g_num_cs_select  : integer := 2;
    g_invert_sclk	 : boolean := false
    );

  port (
-- clock & reset
    clk_i   : in std_logic;
    rst_n_i : in std_logic;

-- channel 1 value and value load strobe
    value_i  : in std_logic_vector(g_num_data_bits-1 downto 0);
    cs_sel_i : in std_logic_vector(g_num_cs_select-1 downto 0);
    load_i   : in std_logic;

-- SCLK divider: 000 = clk_i/8 ... 111 = clk_i/1024
    sclk_divsel_i : in std_logic_vector(2 downto 0);

-- DAC I/F
    dac_cs_n_o  : out std_logic_vector(g_num_cs_select-1 downto 0);
    dac_sclk_o  : out std_logic;
    dac_sdata_o : out std_logic;

    xdone_o : out std_logic
    );
end dac_spi;


architecture syn of dac_spi is

  signal divider        : unsigned(11 downto 0);
  signal dataSh         : std_logic_vector(g_num_data_bits + g_num_extra_bits-1 downto 0);
  --~ signal bitCounter     : std_logic_vector(g_num_data_bits + g_num_extra_bits+1 downto 0);
  signal bitCounter     : std_logic_vector(g_num_data_bits + g_num_extra_bits downto 0);
  signal endSendingData : std_logic;
  signal sendingData    : std_logic;
  signal iDacClk        : std_logic;
  signal iValidValue    : std_logic;

  signal divider_muxed : std_logic;

  signal cs_sel_reg : std_logic_vector(g_num_cs_select-1 downto 0);
  
begin
  --~ select_divider : process (divider, sclk_divsel_i)
  --~ begin  -- process
    --~ case sclk_divsel_i is
      --~ when "000" =>	if divider(1 downto 0) = "11" 		 then divider_muxed <= '1';
					--~ else	divider_muxed <= '0'; end if;		-- sclk = clk_i/8
      --~ when "001" =>	if divider(2 downto 0) = "111"		 then divider_muxed <= '1';
					--~ else	divider_muxed <= '0'; end if;		-- sclk = clk_i/16
      --~ when "010" =>	if divider(3 downto 0) = "1111"		 then divider_muxed <= '1';
					--~ else	divider_muxed <= '0'; end if;		-- sclk = clk_i/32
      --~ when "011" =>	if divider(4 downto 0) = "11111"	 then divider_muxed <= '1';
					--~ else	divider_muxed <= '0'; end if;		-- sclk = clk_i/64
      --~ when "100" =>	if divider(5 downto 0) = "111111"	 then divider_muxed <= '1';
					--~ else	divider_muxed <= '0'; end if;		-- sclk = clk_i/128
      --~ when "101" =>	if divider(6 downto 0) = "1111111"	 then divider_muxed <= '1';
					--~ else	divider_muxed <= '0'; end if;		-- sclk = clk_i/256
      --~ when "110" =>	if divider(7 downto 0) = "11111111"	 then divider_muxed <= '1';
					--~ else	divider_muxed <= '0'; end if;		-- sclk = clk_i/512
      --~ when "111" =>	if divider(8 downto 0) = "111111111" then divider_muxed <= '1';
					--~ else	divider_muxed <= '0'; end if;		-- sclk = clk_i/1024
      --~ when others => null;
    --~ end case;
  --~ end process;

  select_divider : process (divider, sclk_divsel_i)
  begin  -- process
    case sclk_divsel_i is
      --~ when "000"  => divider_muxed <= not divider(0);						-- sclk = clk_i/2
      --~ when "000"  => divider_muxed <= divider(0);						-- sclk = clk_i/4
      --~ when "000"  => divider_muxed <= divider(1);						-- sclk = clk_i/6
      --~ when "000"  => divider_muxed <= divider(1) and divider(0);		-- sclk = clk_i/8
      when "000"  => divider_muxed <= divider(2);						-- sclk = clk_i/10
      --~ when "000"  => divider_muxed <= divider(4) and divider(0);			-- sclk = clk_i/2024*20
      --~ when "000" =>	if divider(8 downto 0) = "111110011" then divider_muxed <= '1';
					--~ else	divider_muxed <= '0'; end if;		-- sclk = clk_i/1000
      --~ when "000" =>	if divider(5 downto 0) = "110001" then divider_muxed <= '1';
					--~ else	divider_muxed <= '0'; end if;		-- sclk = clk_i/100
      when others => null;
    end case;
  end process;

  iValidValue <= load_i;

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        sendingData <= '0';
      else
        if iValidValue = '1' and sendingData = '0' then
          sendingData <= '1';
        elsif endSendingData = '1' then
          sendingData <= '0';
        end if;
      end if;
    end if;
  end process;

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if iValidValue = '1' then
        divider <= (others => '0');
      elsif sendingData = '1' then
        if(divider_muxed = '1') then
        divider <= (others => '0');
        else
          divider <= divider + 1;
        end if;
      elsif endSendingData = '1' then
        divider <= (others => '0');
      end if;
    end if;
  end process;

  --~ process(clk_i)
  --~ begin
    --~ if rising_edge(clk_i) then
      --~ if rst_n_i = '0' then
        --~ iDacClk <= '1';                 -- 0
      --~ else
        --~ if iValidValue = '1' then
			--~ iDacClk <= '1';               -- 0
        --~ elsif endSendingData = '0' then
			--~ if divider_muxed = '1' then
				--~ iDacClk <= '1';
			--~ else
				--~ iDacClk <= '0';
			--~ end if;
        --~ elsif endSendingData = '1' then
			--~ iDacClk <= '1';               -- 0
        --~ end if;
      --~ end if;
    --~ end if;
  --~ end process;

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        iDacClk <= '1';                 -- 0
      else
        if iValidValue = '1' then
          iDacClk <= '1';               -- 0
        elsif divider_muxed = '1' then
          iDacClk <= not(iDacClk);
        elsif endSendingData = '1' then
          iDacClk <= '1';               -- 0
        end if;
      end if;
    end if;
  end process;
  
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        dataSh <= (others => '0');
      else
        if iValidValue = '1' and sendingData = '0' then
          cs_sel_reg <= cs_sel_i;
          dataSh(g_num_data_bits-1 downto 0)     <= value_i;
          dataSh(dataSh'left downto g_num_data_bits) <= (others => '0');
        elsif sendingData = '1' and divider_muxed = '1' and iDacClk = '0' then
        --~ elsif sendingData = '1' and divider_muxed = '1' and iDacClk = '1' then
          dataSh(0)                    <= dataSh(dataSh'left);
          dataSh(dataSh'left downto 1) <= dataSh(dataSh'left - 1 downto 0);
        end if;
      end if;
    end if;
  end process;

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if iValidValue = '1' and sendingData = '0' then
        bitCounter(0)                        <= '1';
        bitCounter(bitCounter'left downto 1) <= (others => '0');
      --~ elsif sendingData = '1' and to_integer(divider) = 0 and iDacClk = '1' then
      elsif sendingData = '1' and to_integer(divider) = 0 and iDacClk = '0' then
        bitCounter(0)                        <= '0';
        bitCounter(bitCounter'left downto 1) <= bitCounter(bitCounter'left - 1 downto 0);
      end if;
    end if;
  end process;

  --~ endSendingData <= bitCounter(bitCounter'left);
  endSendingData <= bitCounter(bitCounter'left) and divider_muxed;

  xdone_o <= not sendingData;

  dac_sdata_o <= dataSh(dataSh'left);

  gen_cs_out : for i in 0 to g_num_cs_select-1 generate
    dac_cs_n_o(i) <= not(sendingData) or (not cs_sel_reg(i));
  end generate gen_cs_out;

  --dac_sclk_o <= iDacClk;
  p_drive_sclk: process(iDacClk)
  begin
    if(g_invert_sclk) then
      dac_sclk_o <= not iDacClk;
    else
      dac_sclk_o <= iDacClk;
     end if;
   end process;

end syn;
