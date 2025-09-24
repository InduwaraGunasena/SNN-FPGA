library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_neuron is
end entity;

architecture sim of tb_neuron is
  signal clk  : std_logic := '0';
  signal rst  : std_logic := '1';
  signal nreset : std_logic := '0';
  signal sp0, sp1, sp2, sp3, sp4, sp5, sp6 : std_logic := '0';
  signal spike_out : std_logic;
  signal mem_out : signed(15 downto 0);

  -- instantiate the neuron: set a few example weights
  component neuron
    generic(
      W0 : integer := 0;
      W1 : integer := 0;
      W2 : integer := 0;
      W3 : integer := 0;
      W4 : integer := 0;
      W5 : integer := 0;
      W6 : integer := 0;
      BIAS : integer := 0;
      V_TH : integer := 256;
      LEAK : integer := 0;
      MEM_BITS : integer := 16
    );
    port(
      clk : in std_logic;
      rst : in std_logic;
      neuron_reset : in std_logic;
      sp_0 : in std_logic;
      sp_1 : in std_logic;
      sp_2 : in std_logic;
      sp_3 : in std_logic;
      sp_4 : in std_logic;
      sp_5 : in std_logic;
      sp_6 : in std_logic;
      spike_out : out std_logic;
      mem_out : out signed(15 downto 0)
    );
  end component;

begin
  -- clock: 10 ns period
  clk <= not clk after 5 ns;

  UUT: neuron
    generic map(
      W0 => 50,
      W1 => 30,
      W2 => 20,
      W3 => 0,
      W4 => 0,
      W5 => 0,
      W6 => 0,
      BIAS => 0,
      V_TH => 100,
      LEAK => 0,
      MEM_BITS => 16
    )
    port map(
      clk => clk,
      rst => rst,
      neuron_reset => nreset,
      sp_0 => sp0,
      sp_1 => sp1,
      sp_2 => sp2,
      sp_3 => sp3,
      sp_4 => sp4,
      sp_5 => sp5,
      sp_6 => sp6,
      spike_out => spike_out,
      mem_out => mem_out
    );

  -- stimulus
  stim_proc : process
  begin
    -- keep reset active for a few clocks
    rst <= '1';
    wait for 30 ns;
    rst <= '0';
    wait for 20 ns;

    -- send a few spikes on sp0 and sp1 that should cause firing
    sp0 <= '1';
    wait for 10 ns;
    sp0 <= '0';
    wait for 10 ns;

    sp1 <= '1';
    wait for 10 ns;
    sp1 <= '0';
    wait for 20 ns;

    -- send repeated sp0 pulses to force integration
    repeat_spikes: for i in 1 to 5 loop
      sp0 <= '1';
      wait for 10 ns;
      sp0 <= '0';
      wait for 30 ns;
    end loop;

    -- test neuron_reset (clear membrane)
    nreset <= '1';
    wait for 10 ns;
    nreset <= '0';
    wait for 20 ns;

    -- done
    wait;
  end process;

end architecture;
