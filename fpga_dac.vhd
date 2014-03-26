-- Top level file
-- Juliano Murari (LNLS)	- March 2014

library ieee;
use ieee.std_logic_1164.all;

use work.wishbone_pkg.all;
use work.gencores_pkg.all;

entity fpga_dac is

  -- Create the .ucf file for all the TOP level pins described here!
  
  port (
    clk_sys_p_i          : in std_logic; -- Diferential 200 MHz clock from the SP605 board
    clk_sys_n_i          : in std_logic; -- Diferential 200 MHz clock from the SP605 board
    sys_rst_button_i     : in std_logic; -- Reset button from the SP605

	-- DAC Pins Interface
	dac_pin_sync_n		: buffer std_logic;
	dac_pin_sclk		: buffer std_logic;
	dac_pin_dgnd1		: buffer std_logic;
	dac_pin_sdin		: buffer std_logic;
	dac_pin_ldac_n		: buffer std_logic;
	dac_pin_iovcc		: buffer std_logic;
	dac_pin_clr_n		: buffer std_logic;
	dac_pin_dgnd2		: buffer std_logic;
	dac_pin_reset_n		: buffer std_logic;
	dac_pin_sdo			: buffer std_logic;
	
	debug_dac_pin_sync_n		: out std_logic;
	debug_dac_pin_sclk			: out std_logic;
	debug_dac_pin_dgnd1			: out std_logic;
	debug_dac_pin_sdin			: out std_logic;
	debug_dac_pin_ldac_n		: out std_logic;
	debug_dac_pin_iovcc			: out std_logic;
	debug_dac_pin_clr_n			: out std_logic;
	debug_dac_pin_dgnd2			: out std_logic;
	debug_dac_pin_reset_n		: out std_logic;
	debug_dac_pin_sdo			: out std_logic;

    LED2                 : out std_logic;  -- Leds from the SP605 - blink
    LED3                 : buffer std_logic;  -- Leds from the SP605 - invert with reset

    txd_o                : out   std_logic;                   -- UART TX from SP605
    rxd_i                : in    std_logic                    -- UART RX from SP605
    );

end fpga_dac;

architecture rtl of fpga_dac is  
  constant c_cnx_master_ports  : integer := 1; -- Number of slaves (in our case: leds, buttons, 2x dpram)
  constant c_cnx_slave_ports : integer := 1; -- Number of master (in our case just the rs232 module)

  constant c_peripherals : integer := 1;

  signal cnx_slave_in  : t_wishbone_slave_in_array(c_cnx_slave_ports-1 downto 0);
  signal cnx_slave_out : t_wishbone_slave_out_array(c_cnx_slave_ports-1 downto 0);

  signal cnx_master_in  : t_wishbone_master_in_array(c_cnx_master_ports-1 downto 0);
  signal cnx_master_out : t_wishbone_master_out_array(c_cnx_master_ports-1 downto 0);

  signal periph_out : t_wishbone_master_out_array(0 to c_peripherals-1);
  signal periph_in  : t_wishbone_master_in_array(0 to c_peripherals-1);

  signal sys_clk_gen : std_logic;  
  
  signal clk_sys : std_logic;
  signal clk_sys_rst : std_logic;
  signal clk_sys_rstn : std_logic;
  signal locked : std_logic;
  
  signal rst_button_sys_sync : std_logic;
  signal rst_button_sys_n : std_logic;
  
  signal rs232_rstn : std_logic;

  signal reset_clks     : std_logic;
  signal reset_rstn	: std_logic;
  
  signal txd_int : std_logic;
  signal rxd_int : std_logic;
  
  signal CONTROL0: std_logic_vector(35 downto 0);
  signal TRIG0: std_logic_vector(31 downto 0);
  signal TRIG1: std_logic_vector(31 downto 0);
  signal TRIG2: std_logic_vector(31 downto 0);
  signal TRIG3: std_logic_vector(31 downto 0);

  constant c_cfg_base_addr : t_wishbone_address_array(c_cnx_master_ports-1 downto 0) :=
    (0 => x"00880000");                 -- dac dds component

  constant c_cfg_base_mask : t_wishbone_address_array(c_cnx_master_ports-1 downto 0) :=
    (0 => x"ffff0000");

  component clk_gen
    port(
      sys_clk_p_i : in std_logic;
      sys_clk_n_i : in std_logic;
      sys_clk_o : out std_logic;
      sys_clk_bufg_o : out std_logic
    );
  end component;

  component clk_pll
	port
	 (-- Clock in ports
	  CLK_IN1           : in     std_logic;
	  -- Clock out ports
	  CLK_OUT1          : out    std_logic;
	  CLK_OUT2          : out    std_logic;
	  -- Status and control signals
	  RESET             : in     std_logic;
	  LOCKED            : out    std_logic
	 );
  end component;

  component gc_reset
  generic(
    g_clocks    : natural := 1;
    g_logdelay  : natural := 10;
    g_syncdepth : natural := 3);
  port(
    free_clk_i : in  std_logic;
    locked_i   : in  std_logic := '1'; -- All the PLL locked signals ANDed together
    clks_i     : in  std_logic_vector(g_clocks-1 downto 0);
    rstn_o     : out std_logic_vector(g_clocks-1 downto 0));
  end component;

  component gc_sync_ffs
  generic(
    g_sync_edge : string := "positive"
    );
  port(
    clk_i    : in  std_logic;  -- clock from the destination clock domain
    rst_n_i  : in  std_logic;           -- reset
    data_i   : in  std_logic;           -- async input
    synced_o : out std_logic;           -- synchronized output
    npulse_o : out std_logic;  -- negative edge detect output (single-clock pulse)
    ppulse_o : out std_logic   -- positive edge detect output (single-clock pulse)
    );
  end component;

  component gc_extend_pulse
  generic (
    -- output pulse width in clk_i cycles
    g_width : natural := 1000
    );
  port (
    clk_i      : in  std_logic;
    rst_n_i    : in  std_logic;
    -- input pulse (synchronou to clk_i)
    pulse_i    : in  std_logic;
    -- extended output pulse
    extended_o : out std_logic := '0');
  end component;

  component xwb_rs232_syscon
  generic (
    g_ma_interface_mode                       : t_wishbone_interface_mode      := PIPELINED;
    g_ma_address_granularity                  : t_wishbone_address_granularity := BYTE
  );
  port(
    -- WISHBONE common
    wb_clk_i                                  : in std_logic;
    wb_rstn_i                                 : in std_logic;

    -- External ports
    rs232_rxd_i                               : in std_logic;
    rs232_txd_o                               : out std_logic;

    -- Reset to FPGA logic
    rstn_o                                    : out std_logic;

    -- WISHBONE master
    wb_master_i                               : in t_wishbone_master_in;
    wb_master_o                               : out t_wishbone_master_out
  );
  end component;

  component xwb_crossbar
  generic(
    g_num_masters : integer := 1;
    g_num_slaves  : integer := 1;
    g_registered  : boolean := false;
    -- Address of the slaves connected
    g_address     : t_wishbone_address_array;
    g_mask        : t_wishbone_address_array);
  port(
    clk_sys_i     : in  std_logic;
    rst_n_i       : in  std_logic;
    -- Master connections (INTERCON is a slave)
    slave_i       : in  t_wishbone_slave_in_array(g_num_masters-1 downto 0);
    slave_o       : out t_wishbone_slave_out_array(g_num_masters-1 downto 0);
    -- Slave connections (INTERCON is a master)
    master_i      : in  t_wishbone_master_in_array(g_num_slaves-1 downto 0);
    master_o      : out t_wishbone_master_out_array(g_num_slaves-1 downto 0));
  end component;
  
  component chipscope_icon
  port (
    CONTROL0: inout std_logic_vector(35 downto 0));
  end component; 
  
  component chipscope_ila
  port (
    CONTROL: inout std_logic_vector(35 downto 0);
    CLK: in std_logic;
    TRIG0: in std_logic_vector(31 downto 0);
    TRIG1: in std_logic_vector(31 downto 0);
    TRIG2: in std_logic_vector(31 downto 0);
    TRIG3: in std_logic_vector(31 downto 0));
  end component;
  
  component dac_dds
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
		--~ dac_pin_sdo			: out std_logic;

        dds_data_in_debug		: out std_logic_vector(31 downto 0); 
        dac_word_debug			: out std_logic_vector(23 downto 0);
   		dac_cg_spi_load_debug	: out std_logic;
   		dac_cg_count_debug		: out std_logic_vector(19 downto 0);

		dac_spi_done			: out std_logic;
		dac_spi_sclk_out		: out std_logic;
		dac_dds_spi_data_out	: out std_logic;
		dds_tready				: out std_logic
    );  
	end component;

	signal dac_spi_done				: std_logic;
	signal dac_dds_spi_data_out		: std_logic; 
	signal dac_spi_sclk_out			: std_logic;

	signal dds_data_in_debug		: std_logic_vector(31 downto 0); 
	signal dac_word_debug			: std_logic_vector(23 downto 0);
	signal dac_cg_spi_load_debug	: std_logic;
	signal dac_cg_count_debug		: std_logic_vector(19 downto 0);
	signal dds_tready_aux			: std_logic;

begin  -- rtl

  -- ##########################################################################
  -- Instantiate the clock generation circuit here!
  -- ##########################################################################
  
  cmp_clk_gen : clk_gen
  port map (
    sys_clk_p_i                             => clk_sys_p_i,  -- input clock P
    sys_clk_n_i                             => clk_sys_n_i,  -- input clock N
    sys_clk_o                               => open,  -- output clock to use in the rest of the FPGA
    sys_clk_bufg_o                          => sys_clk_gen
  );
  
  cmp_sys_pll_inst : clk_pll
  port map (
    reset                                 => '0',
    clk_in1                               => sys_clk_gen,
    clk_out1                              => clk_sys,     	-- output 100MHz locked clock
    clk_out2                              => open,  		-- output 200MHz locked clock
    locked                                => locked       	-- '1' when the PLL has locked
  );
  
  cmp_reset : gc_reset
  generic map(
    g_clocks                                => 1    -- Only CLK_SYS
  )
  port map(
    free_clk_i                              => sys_clk_gen,
    locked_i                                => locked,
    clks_i(0)                               => reset_clks,
    rstn_o(0)                               => reset_rstn
  );
  
  reset_clks                                <= clk_sys;
  -- Use this reset in the reset of the FPGA design. Note that it is a negative reset!
  clk_sys_rstn                  <= reset_rstn and rst_button_sys_n and rs232_rstn;
  clk_sys_rst				    <= not clk_sys_rstn;

  ---- Generate button reset synchronous to each clock domain
  ---- Detect button positive edge of clk_sys
  -- This module is available inside the general-cores repository:
  -- "general-cores/modules/common/gc_sync_ffs.vhd"
  
  cmp_button_sys_ffs : gc_sync_ffs
  port map (
    clk_i                                   => clk_sys,
    rst_n_i                                 => '1',
    data_i                                  => sys_rst_button_i,    -- Input button from the SP605
    synced_o                                => rst_button_sys_sync,
    ppulse_o                                => open    -- Positive-edge detection
  );
  rst_button_sys_n                          <= not rst_button_sys_sync;

  -- ##########################################################################
  -- Instantiate the rs232 system here!
  -- ##########################################################################

  cmp_xwb_rs232_syscon : xwb_rs232_syscon
  generic map (
    g_ma_interface_mode                       => CLASSIC,
    g_ma_address_granularity                  => BYTE
  )
  port map(
    -- WISHBONE common
    wb_clk_i                                  => clk_sys,
    wb_rstn_i                                 => '1', -- No need for resetting the controller
  
    -- External ports
	rs232_rxd_i                        		=> rxd_int,
    rs232_txd_o                             => txd_int,
  
    -- Reset to FPGA logic
    rstn_o                               => rs232_rstn,
  
    -- WISHBONE master
    wb_master_i                               => cnx_slave_out(0),
    wb_master_o                               => cnx_slave_in(0)
  );
  txd_o <= txd_int;
  rxd_int <= rxd_i;
  
  -- CROSSBAR: This module is available inside the general-cores repository:
  -- "general-cores/modules/wishbone/wb_crossbar/xwb_crossbar.vhd"
  U_Intercon : xwb_crossbar
    generic map (
      g_num_masters => c_cnx_slave_ports,
      g_num_slaves  => c_cnx_master_ports,
      g_registered  => true,
      g_address => c_cfg_base_addr,
      g_mask => c_cfg_base_mask)
    port map (
      clk_sys_i     => clk_sys,
      rst_n_i       => clk_sys_rstn,
      slave_i       => cnx_slave_in,
      slave_o       => cnx_slave_out,
      master_i      => cnx_master_in,
      master_o      => cnx_master_out);

  -- ##########################################################################
  -- Instantiate DAC, DDS and CONFIG block here!
  -- ##########################################################################
	cmp_dac_dds : dac_dds
	generic map(
		wb_size 		=>	32
	)
	port map(
        -- Syscon signals
        gls_reset_n		=>	clk_sys_rstn,
        gls_clk			=>	clk_sys,
        -- Wishbone signals
        wbs_add       	=>	cnx_master_out(0).adr,
        wbs_writedata 	=>	cnx_master_out(0).dat,
        wbs_readdata  	=>	cnx_master_in(0).dat,
        wbs_strobe    	=>	cnx_master_out(0).stb,
        wbs_cycle     	=>	cnx_master_out(0).cyc,
        wbs_write     	=>	cnx_master_out(0).we,
        wbs_ack       	=>	cnx_master_in(0).ack,

		-- DAC Pins Interface
		dac_pin_sync_n		=>	dac_pin_sync_n,
		dac_pin_sclk		=>	dac_pin_sclk,
		dac_pin_dgnd1		=>	dac_pin_dgnd1,
		dac_pin_sdin		=>	dac_pin_sdin,
		dac_pin_ldac_n		=>	dac_pin_ldac_n,
		dac_pin_iovcc		=>	dac_pin_iovcc,
		dac_pin_clr_n		=>	dac_pin_clr_n,
		dac_pin_dgnd2		=>	dac_pin_dgnd2,
		dac_pin_reset_n		=>	dac_pin_reset_n,
		--~ dac_pin_sdo			=>	dac_pin_sdo,
		
        -- out signals
        dds_data_in_debug		=> 	dds_data_in_debug,
        dac_word_debug			=>	dac_word_debug,
   		dac_cg_spi_load_debug	=> 	dac_cg_spi_load_debug,
   		dac_cg_count_debug		=>	dac_cg_count_debug,
        
        dac_spi_done			=>	dac_spi_done,		
        dac_spi_sclk_out		=>	dac_spi_sclk_out,	
        dac_dds_spi_data_out	=>	dac_dds_spi_data_out,
        dds_tready				=>	dds_tready_aux
	);
	
    cmp_chipscope_icon : chipscope_icon
	port map (
		CONTROL0		=> CONTROL0);
  
   cmp_chipscope_ila : chipscope_ila
	port map(
		CONTROL			=>	CONTROL0,
		CLK				=>	clk_sys,
		TRIG0 			=>	TRIG0,
		TRIG1 			=>	TRIG1,
		TRIG2 			=>	TRIG2,
		TRIG3 			=>	TRIG3);

	TRIG0 <= dds_data_in_debug;
							--	COUNT 11				 SYNC N 10		SCLK 9			DGND1 8		 SDIN 7 		LDAC N 6		IOVcc 5			CLR N 4			DGND 3				RESET N 2		SDO 1
	TRIG1 <= dac_cg_count_debug & "00" & dac_pin_sync_n & dac_pin_sclk & dac_pin_dgnd1 & dac_pin_sdin & dac_pin_ldac_n & dac_pin_iovcc & dac_pin_clr_n & dac_pin_dgnd2 & dac_pin_reset_n & dac_pin_sdo;
	TRIG2 <= cnx_master_out(0).adr;										-- 6 strobe				5 done				4 out_bit		3 out_clk			2 load				1
	TRIG3 <= dac_word_debug & '1' & clk_sys_rstn & cnx_master_out(0).stb & dac_spi_done & dac_dds_spi_data_out & dac_spi_sclk_out & dac_cg_spi_load_debug & dds_tready_aux;
	--~ TRIG3 <= x"00000" & dac_word_debug & '1' & clk_sys_rstn & cnx_master_out(0).stb & dac_spi_done & dac_dds_spi_data_out & dac_spi_sclk_out & dac_cg_spi_load_debug & dds_tready_aux;

--	Blinking led just for test
	blink_led : process(clk_sys)
	constant c_max : natural := 20000000;
    variable count : natural range 0 to c_max;
    begin
        if rising_edge(clk_sys) then
			if(clk_sys_rstn = '0') then
				count := 0;
				LED2 <= '0';
				LED3 <= not LED3;
			else
				if count < c_max/2 then
					LED2 <= '1';
					count := count + 1;
				elsif count < c_max then
					LED2 <= '0';
					count := count + 1;
				else
					count := 0;
					LED2 <= '1';
				end if;
			end if;
        end if;
    end process blink_led; 
    
    debug_dac_pin_sync_n	<= dac_pin_sync_n;
    debug_dac_pin_sclk		<= dac_pin_sclk;
    debug_dac_pin_dgnd1		<= dac_pin_dgnd1;
    debug_dac_pin_sdin		<= dac_pin_sdin	;
    debug_dac_pin_ldac_n	<= dac_pin_ldac_n;
    debug_dac_pin_iovcc		<= dac_pin_iovcc;
    debug_dac_pin_clr_n		<= dac_pin_clr_n;
    debug_dac_pin_dgnd2		<= dac_pin_dgnd2;
    debug_dac_pin_reset_n	<= dac_pin_reset_n;
    debug_dac_pin_sdo		<= dac_pin_sdo;
	
end rtl;
