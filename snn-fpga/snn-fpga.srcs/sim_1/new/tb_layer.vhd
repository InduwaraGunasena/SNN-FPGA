library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.types_pkg.all;

entity tb_layer is
end entity;

architecture sim of tb_layer is

  constant N_INPUTS   : integer := 4;
  constant N_NEURONS  : integer := 2;
  constant V_TH       : integer := 3;  -- small threshold
  constant MEM_BITS   : integer := 16;

  signal clk          : std_logic := '0';
  signal rst          : std_logic := '1';
  signal neuron_reset : std_logic := '0';
  signal spikes_in    : std_logic_vector(N_INPUTS-1 downto 0) := (others => '0');
  signal spikes_out   : std_logic_vector(N_NEURONS-1 downto 0);
  signal mem_outs     : mem_array(N_NEURONS-1 downto 0);

  constant weights : integer_matrix(0 to N_NEURONS-1, 0 to N_INPUTS-1) := (
      0 => (0 => 1, 1 => 1, 2 => 1, 3 => 1),
      1 => (0 => 2, 1 => 0, 2 => 0, 3 => 0)
    );

  constant biases : integer_vector(N_NEURONS-1 downto 0) := (others => 0);

begin

  -- DUT
  uut: entity work.layer
    generic map(
      N_INPUTS  => N_INPUTS,
      N_NEURONS => N_NEURONS,
      V_TH      => V_TH,
      LEAK      => 0,
      MEM_BITS  => MEM_BITS
    )
    port map(
      clk          => clk,
      rst          => rst,
      neuron_reset => neuron_reset,
      spikes_in    => spikes_in,
      weights      => weights,
      biases       => biases,
      spikes_out   => spikes_out,
      mem_outs     => mem_outs
    );

  -- Clock generation
  clk <= not clk after 5 ns;

  -- Stimulus
  process
  begin
    rst <= '1'; wait for 20 ns;
    rst <= '0'; wait for 20 ns;

    -- Feed some spikes
    spikes_in <= "1000"; wait for 10 ns;  -- one spike
    spikes_in <= "1111"; wait for 10 ns;  -- all spikes
    spikes_in <= "0000"; wait for 10 ns;  -- no spikes

    -- Trigger neuron_reset
    neuron_reset <= '1'; wait for 10 ns;
    neuron_reset <= '0'; wait for 20 ns;

    wait;
  end process;

end architecture;
