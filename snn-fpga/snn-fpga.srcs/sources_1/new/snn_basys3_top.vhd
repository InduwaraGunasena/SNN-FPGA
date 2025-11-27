-- snn_basys3_top.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.types_pkg.all;

entity snn_basys3_top is
  port(
    clk        : in  std_logic;  -- 100 MHz
    rst        : in  std_logic;
    rx         : in  std_logic;
    tx         : out std_logic;
    an         : out std_logic_vector(3 downto 0);
    seg        : out std_logic_vector(6 downto 0)
  );
end entity;

architecture rtl of snn_basys3_top is
  signal frame_data : std_logic_vector(8*256-1 downto 0);
  signal frame_valid: std_logic;
  signal result_valid: std_logic;
  signal digit_out: std_logic_vector(3 downto 0);

  -- uart tx wires
  signal tx_start_sig : std_logic := '0';
  signal tx_byte_sig  : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_busy_sig  : std_logic := '0';

begin

  -- UART receiver (instantiation of your existing module)
  uart_rx_inst: entity work.uart_frame_receiver256
    port map(
      clk => clk, rst => rst,
      rx => rx,
      tx => tx,  -- the receiver module drives tx for ACK/NAK
      frame_data => frame_data,
      frame_valid => frame_valid
    );

  -- SNN core
  snn_inst: entity work.snn_top
    generic map(
      N_INPUTS => 256,
      N_HIDDEN => 32,
      N_OUTPUT => 10,
      T_STEPS  => 50
    )
    port map(
      clk => clk,
      rst => rst,
      frame_data => frame_data,
      frame_valid => frame_valid,
      result_valid => result_valid,
      digit_out => digit_out
    );

  -- 7-seg display (modified to accept binary digit)
  display_inst: entity work.display_digit
    port map(
      clk => clk,
      digit => digit_out,
      an => an,
      seg => seg
    );

end architecture;
