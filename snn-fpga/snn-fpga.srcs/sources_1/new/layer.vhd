library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.types_pkg.all;

entity layer is
  generic(
    N_INPUTS   : integer := 256; -- fan-in per neuron
    N_NEURONS  : integer := 32;  -- number of neurons in this layer
    V_TH       : integer := 256;
    LEAK       : integer := 0;
    MEM_BITS   : integer := 16
  );
  port(
    clk          : in  std_logic;
    rst          : in  std_logic;
    neuron_reset : in  std_logic;   -- reset applied to all neurons (e.g., per-pixel/frame)
    spikes_in    : in  std_logic_vector(N_INPUTS-1 downto 0); -- inputs from previous layer (or encoder)
    weights      : in  integer_matrix(N_NEURONS-1 downto 0);  -- each element is an integer_vector(N_INPUTS-1 downto 0)
    biases       : in  integer_vector(N_NEURONS-1 downto 0);  -- bias per neuron
    spikes_out   : out std_logic_vector(N_NEURONS-1 downto 0); -- outputs of this layer (spike per neuron)
    mem_outs     : out mem_array(N_NEURONS-1 downto 0)
  );
end entity;

architecture rtl of layer is
begin
  gen_neurons: for n in 0 to N_NEURONS-1 generate
    neuron_inst: entity work.neuron
      generic map(
        N_INPUTS => N_INPUTS,
        V_TH     => V_TH,
        LEAK     => LEAK,
        MEM_BITS => MEM_BITS
      )
      port map(
        clk          => clk,
        rst          => rst,
        neuron_reset => neuron_reset,
        spikes       => spikes_in,
        weights      => weights(n),
        bias         => biases(n),
        spike_out    => spikes_out(n),
        mem_out      => mem_outs(n)
      );
  end generate;
end architecture;
