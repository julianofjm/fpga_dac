library ieee;
use ieee.std_logic_1164.all;

entity dac is
	--~ generic(




	--~ );
	port(




    );
end dac;

architecture rtl of dac is  
begin






end rtl;

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
--~ 		23		22...20		19...2				1	0
--~ 		R/!W	Reg addr	Dac Register		
--~ 		R or W	0 0 1		18 bits of data		X	X


--~			Control Register
--~			23		22...20		19...10			9...6		5		4	3	2	1	 0
--~			R/!W	Reg addr	reserved		LIN COMP	SDODIS	BIN TRI	GND RBUF reserved
--~			0		0 1 0		0				0			0		1	1	1	1	 0


--~ 		Clearcode Register
--~ 		23		22...20		19...2				1	0
--~ 		R/!W	Reg addr	Clearcode Register		
--~ 		R or W	0 1 1		18 bits of data		X	X

--~ 		Software Register
--~ 		23		22...20		19...3		2		1		0
--~ 		R/!W	Reg addr	reserved	reset	clr		ldac
--~ 		R or W	1 0 0		0			











