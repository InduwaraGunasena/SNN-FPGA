library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.types_pkg.all;
use work.weights_pkg.all;

entity snn_basys3_top is
  port(
    clk        : in  std_logic;
    rst        : in  std_logic;
    global_reset : in std_logic;
    spikes_in  : in  std_logic_vector(255 downto 0);  -- 16x16 pixel spikes
    an         : out std_logic_vector(3 downto 0);
    seg        : out std_logic_vector(6 downto 0)
  );
end entity;

architecture rtl of snn_basys3_top is

  -- Signals to connect SNN to display
  signal spikes_out_snn : std_logic_vector(9 downto 0);

begin

  -------------------------------------------------------------------
  -- Instantiate SNN
  -------------------------------------------------------------------
  snn_inst: entity work.snn_top
    generic map(
      N_INPUTS  => 256
    )
    port map(
      clk          => clk,
      rst          => rst,
      global_reset => global_reset,
      spikes_in    => spikes_in,
      spikes_out   => spikes_out_snn
    );

  -------------------------------------------------------------------
  -- Instantiate 7-segment display module
  -------------------------------------------------------------------
  display_inst: entity work.display_digit
    port map(
      clk        => clk,
      spikes_out => spikes_out_snn,
      an         => an,
      seg        => seg
    );

end architecture;
