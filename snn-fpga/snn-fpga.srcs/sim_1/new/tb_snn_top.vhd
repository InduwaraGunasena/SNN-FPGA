library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.types_pkg.all;

entity tb_snn_top is
end entity;

architecture sim of tb_snn_top is

  -------------------------------------------------------------------
  -- Parameters (match your snn_top generics)
  -------------------------------------------------------------------
  constant N_INPUTS  : integer := 256;
  constant N_HIDDEN  : integer := 32;
  constant N_OUTPUT  : integer := 10;
  constant V_TH      : integer := 5;
  constant LEAK      : integer := 0;
  constant MEM_BITS  : integer := 16;

  -------------------------------------------------------------------
  -- Signals
  -------------------------------------------------------------------
  signal clk           : std_logic := '0';
  signal rst           : std_logic := '1';
  signal global_reset  : std_logic := '0';
  signal spikes_in     : std_logic_vector(N_INPUTS-1 downto 0) := (others => '0');
  signal spikes_out    : std_logic_vector(N_OUTPUT-1 downto 0);

begin

  -------------------------------------------------------------------
  -- Instantiate the SNN top
  -------------------------------------------------------------------
  uut: entity work.snn_top
    generic map(
      N_INPUTS  => N_INPUTS,
      N_HIDDEN  => N_HIDDEN,
      N_OUTPUT  => N_OUTPUT,
      V_TH      => V_TH,
      LEAK      => LEAK,
      MEM_BITS  => MEM_BITS
    )
    port map(
      clk          => clk,
      rst          => rst,
      global_reset => global_reset,
      spikes_in    => spikes_in,
      spikes_out   => spikes_out
    );

  -------------------------------------------------------------------
  -- Clock generation
  -------------------------------------------------------------------
  clk_process : process
  begin
    clk <= '0';
    wait for 5 ns;
    clk <= '1';
    wait for 5 ns;
  end process;

  -------------------------------------------------------------------
  -- Stimulus process
  -------------------------------------------------------------------
  stim_proc: process
  begin
    -- Initial reset
    rst <= '1';
    wait for 20 ns;
    rst <= '0';
    wait for 20 ns;

    -- Pulse global reset
    global_reset <= '1';
    wait for 10 ns;
    global_reset <= '0';
    wait for 10 ns;

    -- Test 1: single input spike
    spikes_in <= (others => '0');
    spikes_in(0) <= '1';
    wait for 20 ns;

    -- Test 2: multiple spikes
    spikes_in <= (others => '0');
    spikes_in(3 downto 0) <= "1111";
    wait for 20 ns;

    -- Test 3: all spikes
    spikes_in <= (others => '1');
    wait for 20 ns;

    -- Test 4: no spikes
    spikes_in <= (others => '0');
    wait for 20 ns;

    wait; -- end simulation
  end process;

end architecture;
