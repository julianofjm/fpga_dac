--------------------------------------------------------------------------------
--    This file is owned and controlled by Xilinx and must be used solely     --
--    for design, simulation, implementation and creation of design files     --
--    limited to Xilinx devices or technologies. Use with non-Xilinx          --
--    devices or technologies is expressly prohibited and immediately         --
--    terminates your license.                                                --
--                                                                            --
--    XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS" SOLELY    --
--    FOR USE IN DEVELOPING PROGRAMS AND SOLUTIONS FOR XILINX DEVICES.  BY    --
--    PROVIDING THIS DESIGN, CODE, OR INFORMATION AS ONE POSSIBLE             --
--    IMPLEMENTATION OF THIS FEATURE, APPLICATION OR STANDARD, XILINX IS      --
--    MAKING NO REPRESENTATION THAT THIS IMPLEMENTATION IS FREE FROM ANY      --
--    CLAIMS OF INFRINGEMENT, AND YOU ARE RESPONSIBLE FOR OBTAINING ANY       --
--    RIGHTS YOU MAY REQUIRE FOR YOUR IMPLEMENTATION.  XILINX EXPRESSLY       --
--    DISCLAIMS ANY WARRANTY WHATSOEVER WITH RESPECT TO THE ADEQUACY OF THE   --
--    IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OR          --
--    REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE FROM CLAIMS OF         --
--    INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A   --
--    PARTICULAR PURPOSE.                                                     --
--                                                                            --
--    Xilinx products are not intended for use in life support appliances,    --
--    devices, or systems.  Use in such applications are expressly            --
--    prohibited.                                                             --
--                                                                            --
--    (c) Copyright 1995-2014 Xilinx, Inc.                                    --
--    All rights reserved.                                                    --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- You must compile the wrapper file dds_compiler_v5_0.vhd when simulating
-- the core, dds_compiler_v5_0. When compiling the wrapper file, be sure to
-- reference the XilinxCoreLib VHDL simulation library. For detailed
-- instructions, please refer to the "CORE Generator Help".

-- The synthesis directives "translate_off/translate_on" specified
-- below are supported by Xilinx, Mentor Graphics and Synplicity
-- synthesis tools. Ensure they are correct for your synthesis tool(s).

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
-- synthesis translate_off
LIBRARY XilinxCoreLib;
-- synthesis translate_on
ENTITY dds_compiler_v5_0 IS
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_config_tvalid : IN STD_LOGIC;
    s_axis_config_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_data_tvalid : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(23 DOWNTO 0)
  );
END dds_compiler_v5_0;

ARCHITECTURE dds_compiler_v5_0_a OF dds_compiler_v5_0 IS
-- synthesis translate_off
COMPONENT wrapped_dds_compiler_v5_0
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_config_tvalid : IN STD_LOGIC;
    s_axis_config_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_data_tvalid : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(23 DOWNTO 0)
  );
END COMPONENT;

-- Configuration specification
  FOR ALL : wrapped_dds_compiler_v5_0 USE ENTITY XilinxCoreLib.dds_compiler_v5_0(behavioral)
    GENERIC MAP (
      c_accumulator_width => 32,
      c_amplitude => 0,
      c_chan_width => 1,
      c_channels => 1,
      c_debug_interface => 0,
      c_has_aclken => 0,
      c_has_aresetn => 0,
      c_has_channel_index => 0,
      c_has_m_data => 1,
      c_has_m_phase => 0,
      c_has_phase_out => 0,
      c_has_phasegen => 1,
      c_has_s_config => 1,
      c_has_s_phase => 0,
      c_has_sincos => 1,
      c_has_tlast => 0,
      c_has_tready => 0,
      c_latency => 7,
      c_m_data_has_tuser => 0,
      c_m_data_tdata_width => 24,
      c_m_data_tuser_width => 1,
      c_m_phase_has_tuser => 0,
      c_m_phase_tdata_width => 1,
      c_m_phase_tuser_width => 1,
      c_mem_type => 1,
      c_negative_cosine => 0,
      c_negative_sine => 0,
      c_noise_shaping => 2,
      c_optimise_goal => 0,
      c_output_width => 20,
      c_outputs_required => 0,
      c_phase_angle_width => 11,
      c_phase_increment => 1,
      c_phase_increment_value => "111111111111101111101110000,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0",
      c_phase_offset => 0,
      c_phase_offset_value => "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0",
      c_por_mode => 0,
      c_s_config_sync_mode => 0,
      c_s_config_tdata_width => 32,
      c_s_phase_has_tuser => 0,
      c_s_phase_tdata_width => 1,
      c_s_phase_tuser_width => 1,
      c_use_dsp48 => 0,
      c_xdevicefamily => "spartan6"
    );
-- synthesis translate_on
BEGIN
-- synthesis translate_off
U0 : wrapped_dds_compiler_v5_0
  PORT MAP (
    aclk => aclk,
    s_axis_config_tvalid => s_axis_config_tvalid,
    s_axis_config_tdata => s_axis_config_tdata,
    m_axis_data_tvalid => m_axis_data_tvalid,
    m_axis_data_tdata => m_axis_data_tdata
  );
-- synthesis translate_on

END dds_compiler_v5_0_a;
