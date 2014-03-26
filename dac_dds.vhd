-- The main core, which integrates DDS, DAC configuration, SPI modules
-- and wishbone communication (rs232).

-- Juliano Murari (LNLS)	- March 2014

library ieee;
use ieee.std_logic_1164.all;

use work.wishbone_pkg.all;
use work.gencores_pkg.all;

entity dac_dds is
	generic(
		wb_size 		: natural := 32 -- Data port size for wishbone
	);
	port(
        -- Syscon signals
        gls_reset_n		: in std_logic ;
        gls_clk			: in std_logic ;
        -- Wishbone signals
        wbs_add       	: in std_logic_vector(wb_size-1 downto 0) ;
        wbs_writedata 	: in std_logic_vector( wb_size-1 downto 0);
        wbs_readdata  	: out std_logic_vector( wb_size-1 downto 0);
        wbs_strobe    	: in std_logic ;
        wbs_cycle     	: in std_logic ;
        wbs_write     	: in std_logic ;
        wbs_ack       	: out std_logic;

        -- DAC Pins Interface
		dac_pin_sync_n		: out std_logic;
		dac_pin_sclk		: out std_logic;
		dac_pin_dgnd1		: out std_logic;
		dac_pin_sdin		: out std_logic;
		dac_pin_ldac_n		: out std_logic;
		dac_pin_iovcc		: out std_logic;
		dac_pin_clr_n		: out std_logic;
		dac_pin_dgnd2		: out std_logic;
		dac_pin_reset_n		: out std_logic;
		--~ dac_pin_sdo			: in  std_logic;

        -- out signals
        dds_data_in_debug		: out std_logic_vector(31 downto 0); 
        dac_word_debug			: out std_logic_vector(23 downto 0);
		dac_cg_spi_load_debug	: out std_logic;
		dac_cg_count_debug		: out std_logic_vector(19 downto 0);

		dac_spi_done			: out std_logic;
		dac_spi_sclk_out		: buffer std_logic;
		dac_dds_spi_data_out	: out std_logic;
		dds_tready				: buffer std_logic
    );
end dac_dds;

architecture rtl of dac_dds is  
    -- registers mapping
    constant REG_FREQ			: std_logic_vector( 15 downto 0) := x"0000";
    constant REG_DATA 			: std_logic_vector( 15 downto 0) := x"0001";
    
    signal reg_dds_data			: std_logic_vector( wb_size-1 downto 0);
    signal reg_frequency		: std_logic_vector( wb_size-1 downto 0);

    signal read_ack 			: std_logic ;
    signal write_ack 			: std_logic ;

	signal dds_data_out_aux		: std_logic_vector(23 downto 0);
	signal dds_data_out			: std_logic_vector(19 downto 0); 

	signal dac_cg_data_out		: std_logic_vector(23 downto 0); 
	signal dac_cg_spi_load		: std_logic; 

	signal dac_spi_done_aux				: std_logic; 
	signal dac_spi_sclk_out_aux			: std_logic;
	signal dac_dds_spi_data_out_aux		: std_logic;
	
	signal dac_pin_sync_n_aux			: std_logic;
    
	component dds_compiler_v5_0
	PORT (
    aclk : IN STD_LOGIC;
    s_axis_config_tvalid : IN STD_LOGIC;
    s_axis_config_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_data_tvalid : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(23 DOWNTO 0)
	);
	END component;
	
	component dac_config
	port(
		sys_rst_n			: in std_logic ;
		sys_clk				: in std_logic ;
		dac_cg_data_in		: in std_logic_vector(19 downto 0);
		spi_done			: in std_logic;
		wait_frequency		: in std_logic_vector(31 downto 0);
				
		dac_cg_load			: out std_logic;
		dac_cg_count_debug	: out std_logic_vector(19 downto 0);
		dac_cg_data_out		: out std_logic_vector(23 downto 0)
	);
	end component;
	
	component dac_spi
	generic (
		g_num_data_bits  : integer := 24;
		g_num_extra_bits : integer := 0;
		g_num_cs_select  : integer := 2
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

		xdone_o		: out std_logic
	);
    end component;
	
begin
	
  -- ##########################################################################
  -- Instantiate the Direct Digital Synthesizers (DDS) here! sine generator
  -- ##########################################################################
	cmp_dds_compiler_v5_0 : dds_compiler_v5_0
	port map(
		aclk 					=> gls_clk,
		s_axis_config_tvalid 	=> '1',	
		s_axis_config_tdata 	=> reg_dds_data(31 downto 0),
		m_axis_data_tvalid 		=> open,
		m_axis_data_tdata 		=> dds_data_out_aux
	);
	dds_data_out <= dds_data_out_aux(19 downto 0);
	dds_tready	 <= dac_spi_done_aux;

  -- ##########################################################################
  -- Instantiate DAC Configuration here!
  -- ##########################################################################
	cmp_dac_config : dac_config
	port map(
		sys_rst_n			=> gls_reset_n,
		sys_clk				=> gls_clk,
		dac_cg_data_in		=> dds_data_out,
		spi_done			=> dac_spi_done_aux,
		wait_frequency		=> reg_frequency,

		dac_cg_load			=> dac_cg_spi_load,
		dac_cg_count_debug	=> dac_cg_count_debug,
		dac_cg_data_out		=> dac_cg_data_out
	);
	dac_word_debug	<= dac_cg_data_out;

  -- ##########################################################################
  -- Instantiate DAC SPI here!
  -- ##########################################################################
	cmp_dac_spi : dac_spi
	generic map(
		g_num_data_bits  	=>24,
		g_num_extra_bits 	=>0,
		g_num_cs_select  	=>2
	)
	port map (
		-- clock & reset
		clk_i   			=> gls_clk,
		rst_n_i 			=> gls_reset_n,

		-- channel 1 value and value load strobe
		value_i  			=> dac_cg_data_out,
		cs_sel_i 			=> "01",
		load_i   			=> dac_cg_spi_load,

		-- SCLK divider: 000 = clk_i/8 ... 111 = clk_i/1024
		sclk_divsel_i 		=> "000",
		
		-- DAC I/F
		dac_cs_n_o  		=> open,

		dac_sdata_o 		=> dac_dds_spi_data_out_aux,
		dac_sclk_o  		=> dac_spi_sclk_out_aux,
		xdone_o 			=> dac_spi_done_aux
	);
	dac_spi_done 			<= dac_spi_done_aux;
	dac_dds_spi_data_out	<= dac_dds_spi_data_out_aux;
	dac_pin_sync_n_aux		<= dac_spi_done_aux;

	dac_spi_sclk_out	<= dac_spi_sclk_out_aux;
	--~ dac_clock : process(gls_clk)
	--~ begin
		--~ if dac_spi_done_aux = '0' then
			--~ dac_spi_sclk_out	<= dac_spi_sclk_out_aux;
		--~ else
			--~ dac_spi_sclk_out	<= '1';
		--~ end if;
	--~ end process dac_clock;
	
    -- DAC Pins Interface
	dac_pin_sync_n			<= dac_pin_sync_n_aux;
	dac_pin_sclk			<= dac_spi_sclk_out;
	dac_pin_dgnd1			<= '0';
	dac_pin_sdin			<= dac_dds_spi_data_out_aux;
	dac_pin_ldac_n			<= '0';
	dac_pin_iovcc			<= '1';
	dac_pin_clr_n			<= '1';
	dac_pin_dgnd2			<= '0';
	dac_pin_reset_n			<= gls_reset_n;
--	dac_pin_sdo				<= '0';

	wbs_ack <= read_ack or write_ack;
	-- manage register
	write_bloc : process(gls_clk)
	begin
		if rising_edge(gls_clk) then
			if gls_reset_n = '0' then 
				--~ reg_dds_data	<= (others => '0');
				--~ reg_frequency	<= (others => '0');

				--~ reg_dds_data	<= x"000001ad";		-- default value referring 10Hz
				reg_dds_data	<= x"000010c6";		-- default value referring 100Hz
				--~ reg_dds_data	<= x"0000a7c5";		-- default value referring 1 000Hz
				
				--~ reg_frequency	<= x"00002710";		-- default value referring 10 kHz
				--~ reg_frequency	<= x"00000d05";		-- default value referring 30 kHz
				--~ reg_frequency	<= x"00000b29";		-- default value referring 35 kHz
				--~ reg_frequency	<= x"00000ad9";		-- default value referring 36 kHz
				--~ reg_frequency	<= x"00000a8e";		-- default value referring 37 kHz
				reg_frequency	<= x"00000a47";		-- default value referring 38 kHz
				--~ reg_frequency	<= x"00000a04";		-- default value referring 39 kHz
				--~ reg_frequency	<= x"000009c4";		-- default value referring 40 kHz
				--~ reg_frequency	<= x"000007d0";		-- default value referring 50 kHz
				--~ reg_frequency	<= x"000003e8";		-- default value referring 100 kHz
				--~ reg_frequency	<= x"00000064";		-- default value referring 1000 kHz

				write_ack <= '0';
			else
				if ((wbs_strobe and wbs_write and wbs_cycle) = '1' ) then
					write_ack <= '1';
					case wbs_add(15 downto 0) is
						when REG_DATA(15 downto 0) 		=>	reg_dds_data <= wbs_writedata;
						when REG_FREQ(15 downto 0) 		=>	reg_frequency <= wbs_writedata;
						when others					 	=>	null;
					end case;
				else
					write_ack <= '0';
				end if;
			end if;
		end if;
	end process write_bloc;

	read_bloc : process(gls_clk)
	begin
		if rising_edge(gls_clk) then
			if gls_reset_n = '0' then
				wbs_readdata <= (others => '0');
			else
				if (wbs_strobe = '1' and wbs_write = '0'  and wbs_cycle = '1' ) then
					read_ack <= '1';
				case wbs_add(15 downto 0) is
					when REG_DATA(15 downto 0) 		=> wbs_readdata <= reg_dds_data;
					when REG_FREQ(15 downto 0) 		=> wbs_readdata <= reg_frequency;
					when others		 				=> null;
				end case;
				else
					wbs_readdata <= (others => '0');
					read_ack <= '0';
				end if;
			end if;
		end if;
	end process read_bloc;
	
	dds_data_in_debug		<= reg_dds_data;
	dac_cg_spi_load_debug	<= dac_cg_spi_load;

end rtl;
