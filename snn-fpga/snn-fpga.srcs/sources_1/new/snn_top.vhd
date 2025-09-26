library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.types_pkg.all;
use work.weights_pkg.all;

entity snn_top is
  generic(
    -- Layer sizes
    N_INPUTS   : integer := 256;  -- input layer neurons (16x16 image pixels)
    N_OUTPUT   : integer := 10   -- output layer neurons
  );
  port(
    clk       : in  std_logic;
    rst       : in  std_logic;
    global_reset : in std_logic;

    -- Input spikes (from encoder of image pixels)
    spikes_in  : in  std_logic_vector(N_INPUTS-1 downto 0);

    -- Output layer spikes (classification decision basis)
    spikes_out : out std_logic_vector(N_OUTPUT-1 downto 0)
  );
end entity;

architecture rtl of snn_top is

  -------------------------------------------------------------------
  -- Layer connections
  -------------------------------------------------------------------
  -- Hidden layer outputs
  signal hidden_spikes : std_logic_vector(N_HIDDEN-1 downto 0);
  signal hidden_mems   : mem_array(N_HIDDEN-1 downto 0);

  -- Output layer outputs
  signal output_mems   : mem_array(N_OUTPUT-1 downto 0);

begin

  -------------------------------------------------------------------
  -- Hidden Layer (256 ? 32)
  -------------------------------------------------------------------
  hidden_layer: entity work.layer
    generic map(
      N_INPUTS  => N_INPUTS,
      N_NEURONS => N_HIDDEN,
      V_TH      => V_TH,
      LEAK      => LEAK,
      MEM_BITS  => MEM_BITS
    )
    port map(
      clk          => clk,
      rst          => rst,
      neuron_reset => global_reset,
      spikes_in    => spikes_in,
      weights      => W_INPUT_HIDDEN,
      biases       => B_INPUT_HIDDEN,
      spikes_out   => hidden_spikes,
      mem_outs     => hidden_mems
    );

  -------------------------------------------------------------------
  -- Output Layer (32 ? 10)
  -------------------------------------------------------------------
  output_layer: entity work.layer
    generic map(
      N_INPUTS  => N_HIDDEN,
      N_NEURONS => N_OUTPUT,
      V_TH      => V_TH,
      LEAK      => LEAK,
      MEM_BITS  => MEM_BITS
    )
    port map(
      clk          => clk,
      rst          => rst,
      neuron_reset => global_reset,
      spikes_in    => hidden_spikes,
      weights      => W_HIDDEN_OUTPUT,
      biases       => B_HIDDEN_OUTPUT,
      spikes_out   => spikes_out,
      mem_outs     => output_mems
    );

end architecture;
