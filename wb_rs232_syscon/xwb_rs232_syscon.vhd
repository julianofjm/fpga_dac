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

entity xwb_rs232_syscon is
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
end xwb_rs232_syscon;

architecture rtl of xwb_rs232_syscon is

component wb_rs232_syscon
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
end component;


begin

  cmp_wb_rs232_syscon : wb_rs232_syscon
  generic map (
    g_ma_interface_mode                       => g_ma_interface_mode,
    g_ma_address_granularity                  => g_ma_address_granularity
  )
  port map(
    -- WISHBONE common
    wb_clk_i                                  => wb_clk_i,
    wb_rstn_i                                 => wb_rstn_i,

    -- External ports
    rs232_rxd_i                               => rs232_rxd_i,
    rs232_txd_o                               => rs232_txd_o,

    -- Reset to FPGA logic
    rstn_o                                    => rstn_o,

    -- WISHBONE master
    m_wb_adr_o                                => wb_master_o.adr,
    m_wb_sel_o                                => wb_master_o.sel,
    m_wb_we_o                                 => wb_master_o.we,
    m_wb_dat_o                                => wb_master_o.dat,
    m_wb_dat_i                                => wb_master_i.dat,
    m_wb_cyc_o                                => wb_master_o.cyc,
    m_wb_stb_o                                => wb_master_o.stb,
    m_wb_ack_i                                => wb_master_i.ack,
    m_wb_err_i                                => wb_master_i.err,
    m_wb_stall_i                              => wb_master_i.stall,
    m_wb_rty_i                                => wb_master_i.rty
  );

end rtl;
