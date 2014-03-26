-- VHD file which contains the machine state for the DAC (AD5791)
-- Juliano Murari (LNLS)	- March 2014

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dac_config is
	port(
		sys_rst_n		: in std_logic ;
		sys_clk			: in std_logic ;
		dac_cg_data_in	: in std_logic_vector(19 downto 0);
		spi_done		: in std_logic;
		wait_frequency	: in std_logic_vector(31 downto 0);

		dac_cg_load		: out std_logic;
		dac_cg_count_debug		: out std_logic_vector(19 downto 0);
		dac_cg_data_out	: out std_logic_vector(23 downto 0)
    );
end dac_config;

architecture rtl of dac_config is  

    constant wr_read 			: std_logic :=	'1';
    constant wr_write 			: std_logic :=	'0';

	-- Register control to config dac
    constant reg_control		: std_logic_vector(19 downto 0) := "00000000000000000010";

	-- State machine
	type state_type is (idle, set_load, reset_load, waiting_transfer, waiting_new_data, init, normal);
	signal sys_state : state_type;
	signal state_flag			: boolean;

begin
	process (sys_clk)
		variable count_max		: integer := to_integer(unsigned(wait_frequency));
		variable count_new_data : integer range 0 to 2000000;
	begin
		if (rising_edge(sys_clk)) then
			if sys_rst_n = '0' then
				sys_state <= idle;
				count_new_data := 0;
			else
				case sys_state is
					when idle=>			-- Idle mode: not operation
										-- register_address	= 000
						dac_cg_data_out	<=	wr_write & "000" & x"00000";
						state_flag <= true;
						sys_state <= set_load;
						count_new_data := count_new_data + 1;

					when set_load=>
						count_new_data := count_new_data + 1;
						dac_cg_count_debug <= std_logic_vector(to_unsigned(count_new_data, 20));
						dac_cg_load <= '1';
						sys_state <= reset_load;

					when reset_load=>
						dac_cg_load <= '0';
						sys_state <= waiting_transfer;
						count_new_data := 0;
						dac_cg_count_debug <= std_logic_vector(to_unsigned(count_new_data, 20));

					when waiting_transfer=>
						count_new_data := count_new_data + 1;
						dac_cg_count_debug <= std_logic_vector(to_unsigned(count_new_data, 20));
						if spi_done = '0' then		-- if did not finish the transmission
							sys_state <= waiting_transfer;	-- keep waiting the transfer
						else						-- else go to next state
							sys_state <= waiting_new_data;
						end if;

					when waiting_new_data=>				
						count_new_data := count_new_data + 1;
						dac_cg_count_debug <= std_logic_vector(to_unsigned(count_new_data, 20));
						if count_new_data < (count_max-3) then			-- if the new data are not available
							sys_state <= waiting_new_data;				-- keep waiting
						else											-- else go to next state
							if state_flag then
								sys_state <= init;
							else
								sys_state <= normal;
							end if;
						end if;

					when init=>
						count_new_data := count_new_data + 1;
						dac_cg_data_out	<=	wr_write & "010" & reg_control;
						state_flag		<= false;
						sys_state		<= set_load;

					when normal=>
						count_new_data := count_new_data + 1;
						dac_cg_count_debug <= std_logic_vector(to_unsigned(count_new_data, 20));
										-- Dac register address = 001
						dac_cg_data_out	<=	wr_write & "001" & dac_cg_data_in;
						sys_state <= set_load;

				end case;
			end if;
		end if;
	end process;
	
end rtl;


--~			DAC AD5791 informations (http://www.analog.com/static/imported-files/data_sheets/AD5791.pdf):

--~			INPUT SHIFT REGISTER FORMAT
--~			23		22...20		19...0
--~			R/!W	Reg addr	Description:
--~			X		0 0 0		No operation (NOP). Used in readback operations.
--~			0 		0 0 1		Write to the DAC register.
--~			0 		0 1 0		Write to the control register.
--~			0 		0 1 1		Write to the clearcode register.
--~			0 		1 0 0		Write to the software control register.
--~			1 		0 0 1		Read from the DAC register.
--~			1 		0 1 0		Read from the control register.
--~			1 		0 1 1		Read from the clearcode register. 

----------------------------------------------------------------
------------------------	REGISTERS	------------------------	
----------------------------------------------------------------

--~			DAC Register
--~ 		23		22...20		19...0
--~ 		R/!W	Reg addr	Dac Register		
--~ 		R or W	0 0 1		18 bits of data

--~			Control Register
--~			23		22...20		19...10			9...6		5		4	3	2	1	 0
--~			R/!W	Reg addr	reserved		LIN COMP	SDODIS	BIN TRI	GND RBUF reserved
--~			0		0 1 0		0				0			0		0	0	0	1	 0

--~ 		Clearcode Register
--~ 		23		22...20		19...0
--~ 		R/!W	Reg addr	Clearcode Register		
--~ 		R or W	0 1 1		20 bits of data

--~ 		Software Register
--~ 		23		22...20		19...3		2		1		0
--~ 		R/!W	Reg addr	reserved	reset	clr		ldac
--~ 		R or W	1 0 0		0			
