library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- use the package that defines integer_vector
use work.types_pkg.all;

entity tb_neuron is
end entity tb_neuron;

architecture sim of tb_neuron is

  constant N_INPUTS : integer := 7;
  constant MEM_BITS  : integer := 16;

  signal clk    : std_logic := '0';
  signal rst    : std_logic := '1';
  signal nreset : std_logic := '0';

  signal spikes    : std_logic_vector(N_INPUTS-1 downto 0) := (others => '0');
  signal spike_out : std_logic;
  signal mem_out   : signed(MEM_BITS-1 downto 0);

  -- test weights (index order matches downto: N_INPUTS-1 downto 0)
  constant W_EX : integer_vector(N_INPUTS-1 downto 0) :=
    (6 => 0, 5 => 0, 4 => 0, 3 => 0, 2 => 20, 1 => 30, 0 => 50);

  constant BIAS_C : integer := 0;

  -- Component declaration (matches your neuron entity)
  component neuron
    generic(
      N_INPUTS : integer := 7;
      V_TH     : integer := 256;
      LEAK     : integer := 0;
      MEM_BITS : integer := 16
    );
    port(
      clk          : in  std_logic;
      rst          : in  std_logic;
      neuron_reset : in  std_logic;
      spikes       : in  std_logic_vector(N_INPUTS-1 downto 0);
      weights      : in  integer_vector(N_INPUTS-1 downto 0);
      bias         : in  integer;
      spike_out    : out std_logic;
      mem_out      : out signed(MEM_BITS-1 downto 0)
    );
  end component;

begin

  -- clock generator: 10ns period
  clk <= not clk after 5 ns;

  -- Instantiate neuron under test
  UUT: neuron
    generic map(
      N_INPUTS => N_INPUTS,
      V_TH     => 100,     -- lower threshold for test stimulus
      LEAK     => 0,
      MEM_BITS => MEM_BITS
    )
    port map(
      clk          => clk,
      rst          => rst,
      neuron_reset => nreset,
      spikes       => spikes,
      weights      => W_EX,
      bias         => BIAS_C,
      spike_out    => spike_out,
      mem_out      => mem_out
    );

  -- Stimulus process
  stim_proc : process
  begin
    -- initial reset
    rst <= '1';
    nreset <= '0';
    wait for 30 ns;
    rst <= '0';
    wait for 20 ns;

    -- Single spike on input 0 (should integrate but not fire yet)
    spikes <= (others => '0');
    spikes(0) <= '1';
    wait for 10 ns;
    spikes(0) <= '0';
    wait for 30 ns;

    -- Single spike on input 1
    spikes(1) <= '1';
    wait for 10 ns;
    spikes(1) <= '0';
    wait for 30 ns;

    -- A sequence of spikes to cause firing:
    -- repeatedly pulse input0 (weight 50) 3 times -> should exceed V_TH=100
    for i in 1 to 3 loop
      spikes <= (others => '0');
      spikes(0) <= '1';
      wait for 10 ns;
      spikes(0) <= '0';
      wait for 30 ns;
    end loop;

    -- Another pattern: simultaneous spikes on input0 and input1
    spikes <= (others => '0');
    spikes(0) <= '1';
    spikes(1) <= '1';
    wait for 10 ns;
    spikes <= (others => '0');
    wait for 30 ns;

    -- Test neuron_reset: inject a spike then clear membrane early
    spikes <= (others => '0');
    spikes(0) <= '1';
    wait for 10 ns;
    spikes <= (others => '0');
    nreset <= '1';      -- clear membrane
    wait for 10 ns;
    nreset <= '0';
    wait for 40 ns;

    -- Final burst to ensure another firing event
    for i in 1 to 4 loop
      spikes <= (others => '0');
      spikes(1) <= '1';
      wait for 10 ns;
      spikes <= (others => '0');
      wait for 20 ns;
    end loop;

    -- done
    wait;
  end process stim_proc;

end architecture sim;
