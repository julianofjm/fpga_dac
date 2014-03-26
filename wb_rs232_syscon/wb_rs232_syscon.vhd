------------------------------------------------------------------------------
-- Title      : Wishbone Ethernet MAC Wrapper
------------------------------------------------------------------------------
-- Author     : Lucas Maziero Russo
-- Company    : CNPEM LNLS-DIG
-- Created    : 2013-26-08
-- Platform   : FPGA-generic
-------------------------------------------------------------------------------
-- Description: Wishbone Wrapper for RS232 Master
-------------------------------------------------------------------------------
-- Copyright (c) 2012 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2013-26-08  1.0      lucas.russo        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.wishbone_pkg.all;

entity wb_rs232_syscon is
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
  m_wb_adr_o                                : out std_logic_vector(31 downto 0);
  m_wb_sel_o                                : out std_logic_vector(3 downto 0);
  m_wb_we_o                                 : out std_logic;
  m_wb_dat_o                                : out std_logic_vector(31 downto 0);
  m_wb_dat_i                                : in std_logic_vector(31 downto 0);
  m_wb_cyc_o                                : out std_logic;
  m_wb_stb_o                                : out std_logic;
  m_wb_ack_i                                : in std_logic;
  m_wb_err_i                                : in std_logic;
  m_wb_stall_i                              : in std_logic;
  m_wb_rty_i                                : in std_logic
);
end wb_rs232_syscon;

architecture rtl of wb_rs232_syscon is

  signal rst                                : std_logic;
  signal rst_out                            : std_logic;

  signal m_wb_adr_out                       : std_logic_vector(31 downto 0);
  signal m_wb_sel_out                       : std_logic_vector(3 downto 0);
  signal m_wb_we_out                        : std_logic;
  signal m_wb_dat_out                       : std_logic_vector(31 downto 0);
  signal m_wb_dat_in                        : std_logic_vector(31 downto 0);
  signal m_wb_cyc_out                       : std_logic;
  signal m_wb_stb_out                       : std_logic;
  signal m_wb_ack_in                        : std_logic;
  signal m_wb_err_in                        : std_logic;
  signal m_wb_stall_in                      : std_logic;
  signal m_wb_rty_in                        : std_logic;

  component rs232_syscon_top_1_0
  port (
    clk_i                                   : in std_logic;
    reset_i                                 : in std_logic;
    ack_i                                   : in std_logic;
    err_i                                   : in std_logic;
    rs232_rxd_i                             : in std_logic;
    data_in                                 : in std_logic_vector(31 downto 0);
    data_out                                : out std_logic_vector(31 downto 0);
    rst_o                                   : out std_logic;
    stb_o                                   : out std_logic;
    cyc_o                                   : out std_logic;
    adr_o                                   : out std_logic_vector(31 downto 0);
    we_o                                    : out std_logic;
    rs232_txd_o                             : out std_logic;
    sel_o                                   : out std_logic_vector(3 downto 0)
  );
  end component;

begin
  rst                                       <= not wb_rstn_i;

  -- ETHMAC master interface is byte addressed, classic wishbone
  cmp_ma_iface_slave_adapter : wb_slave_adapter
  generic map (
    g_master_use_struct                     => false,
    g_master_mode                           => g_ma_interface_mode,
    g_master_granularity                    => g_ma_address_granularity,
    g_slave_use_struct                      => false,
    g_slave_mode                            => CLASSIC,
    g_slave_granularity                     => BYTE
  )
  port map (
    clk_sys_i                               => wb_clk_i,
    rst_n_i                                 => wb_rstn_i,

    sl_adr_i                                => m_wb_adr_out,
    sl_dat_i                                => m_wb_dat_out,
    sl_sel_i                                => m_wb_sel_out,
    sl_cyc_i                                => m_wb_cyc_out,
    sl_stb_i                                => m_wb_stb_out,
    sl_we_i                                 => m_wb_we_out,
    sl_dat_o                                => m_wb_dat_in,
    sl_ack_o                                => m_wb_ack_in,
    sl_stall_o                              => open,
    sl_int_o                                => open,
    sl_rty_o                                => open,
    sl_err_o                                => m_wb_err_in,

    ma_adr_o                                => m_wb_adr_o,
    ma_dat_o                                => m_wb_dat_o,
    ma_sel_o                                => m_wb_sel_o,
    ma_cyc_o                                => m_wb_cyc_o,
    ma_stb_o                                => m_wb_stb_o,
    ma_we_o                                 => m_wb_we_o,
    ma_dat_i                                => m_wb_dat_i,
    ma_ack_i                                => m_wb_ack_i,
    ma_stall_i                              => m_wb_stall_i,
    ma_rty_i                                => m_wb_rty_i,
    ma_err_i                                => m_wb_err_i
  );

  cmp_rs232_syscon_top_1_0 : rs232_syscon_top_1_0
  port map (
    clk_i                                   => wb_clk_i,
    reset_i                                 => rst,
    ack_i                                   => m_wb_ack_in,
    err_i                                   => m_wb_err_in,
    rs232_rxd_i                             => rs232_rxd_i,
    data_in                                 => m_wb_dat_in,
    data_out                                => m_wb_dat_out,
    rst_o                                   => rst_out,
    stb_o                                   => m_wb_stb_out,
    cyc_o                                   => m_wb_cyc_out,
    adr_o                                   => m_wb_adr_out,
    we_o                                    => m_wb_we_out,
    rs232_txd_o                             => rs232_txd_o,
    sel_o                                   => m_wb_sel_out
  );

  rstn_o                                    <= not rst_out;

end rtl;
