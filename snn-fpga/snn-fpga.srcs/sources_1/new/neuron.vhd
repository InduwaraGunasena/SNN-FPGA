library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Simple parameterizable Integrate-and-Fire neuron (7 inputs)
entity neuron is
  generic(
    W0        : integer := 0;    -- weight for input 0
    W1        : integer := 0;
    W2        : integer := 0;
    W3        : integer := 0;
    W4        : integer := 0;
    W5        : integer := 0;
    W6        : integer := 0;
    BIAS      : integer := 0;    -- bias term added each timestep
    V_TH      : integer := 256;  -- firing threshold
    LEAK      : integer := 0;    -- optional leak per timestep (subtracted)
    MEM_BITS  : integer := 16    -- bit-width of mem_out (signed)
  );
  port(
    clk         : in  std_logic;
    rst         : in  std_logic;   -- synchronous reset (active '1')
    neuron_reset: in  std_logic;   -- asynchronous per-pixel reset pulse (active '1' for one cycle)
    sp_0        : in  std_logic;
    sp_1        : in  std_logic;
    sp_2        : in  std_logic;
    sp_3        : in  std_logic;
    sp_4        : in  std_logic;
    sp_5        : in  std_logic;
    sp_6        : in  std_logic;
    spike_out   : out std_logic;
    mem_out     : out signed(MEM_BITS-1 downto 0)  -- debug: membrane potential as signed
  );
end entity;

architecture rtl of neuron is

  -- derived constants for saturation limits
  constant MAX_VOLTAGE : integer := 2**(MEM_BITS-1) - 1;
  constant MIN_VOLTAGE : integer := - (2**(MEM_BITS-1));

begin

  process(clk)
    variable voltage : integer := 0; -- membrane potential (variable => immediate update inside process)
    variable sum_in  : integer := 0;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        voltage := 0;
        spike_out <= '0';
        mem_out <= (others => '0');
      else
        -- compute weighted sum of incoming spikes + bias
        sum_in := BIAS;
        if sp_0 = '1' then sum_in := sum_in + W0; end if;
        if sp_1 = '1' then sum_in := sum_in + W1; end if;
        if sp_2 = '1' then sum_in := sum_in + W2; end if;
        if sp_3 = '1' then sum_in := sum_in + W3; end if;
        if sp_4 = '1' then sum_in := sum_in + W4; end if;
        if sp_5 = '1' then sum_in := sum_in + W5; end if;
        if sp_6 = '1' then sum_in := sum_in + W6; end if;

        -- integrate
        voltage := voltage + sum_in;

        -- optional leak (simple model)
        if LEAK /= 0 then
          if voltage > 0 then
            voltage := voltage - LEAK;
            if voltage < 0 then voltage := 0; end if;
          elsif voltage < 0 then
            voltage := voltage + LEAK;
            if voltage > 0 then voltage := 0; end if;
          end if;
        end if;

        -- clamp / saturate to prevent overflow
        if voltage > MAX_VOLTAGE then
          voltage := MAX_VOLTAGE;
        elsif voltage < MIN_VOLTAGE then
          voltage := MIN_VOLTAGE;
        end if;

        -- external neuron_reset clears voltage immediately
        if neuron_reset = '1' then
          voltage := 0;
        end if;

        -- check threshold and generate spike (subtract threshold to allow bursting)
        if voltage >= V_TH then
          voltage := voltage - V_TH;
          spike_out <= '1';
        else
          spike_out <= '0';
        end if;

        -- output membrane as signed bus for debugging/visibility
        mem_out <= to_signed(voltage, MEM_BITS);
      end if;
    end if;
  end process;

end architecture;