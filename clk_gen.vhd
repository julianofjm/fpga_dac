library UNISIM;
use UNISIM.vcomponents.all;

library ieee;
use ieee.std_logic_1164.all;

entity clk_gen is
port(
  sys_clk_p_i : in std_logic;
  sys_clk_n_i : in std_logic;
  sys_clk_o : out std_logic;
  sys_clk_bufg_o : out std_logic
);
end clk_gen;

architecture syn of clk_gen is

  -- Internal clock signal
  signal s_sys_clk : std_logic;

begin
  -- IBUFGDS: Differential Global Clock Input Buffer
  -- Virtex-6
  -- Xilinx HDL Language Template, version 13.4

  cpm_ibufgds_clk_gen : IBUFGDS
  generic map (
    DIFF_TERM => FALSE, -- Differential Termination
    IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
    IOSTANDARD => "DEFAULT"
  )
  port map (
      O => s_sys_clk, -- Clock buffer output
      I => sys_clk_p_i, -- Diff_p clock buffer input (connect directly to top-level port)
      IB => sys_clk_n_i -- Diff_n clock buffer input (connect directly to top-level port)
  );

  sys_clk_o <= s_sys_clk;
    
  -- BUFG: Global Clock Buffer
  -- Virtex-6
  -- Xilinx HDL Language Template, version 13.4
  
  cmp_bufg_clk_gen : BUFG
  port map (
    O => sys_clk_bufg_o, -- 1-bit output: Clock buffer output
    I => s_sys_clk -- 1-bit input: Clock buffer input
  );

end syn;
