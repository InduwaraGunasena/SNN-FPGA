library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- bring in our custom types
use work.types_pkg.all;

entity neuron is
  generic(
    N_INPUTS  : integer := 7;      -- number of inputs
    V_TH      : integer := 256;    -- firing threshold
    LEAK      : integer := 0;      -- optional leak per timestep
    MEM_BITS  : integer := 16      -- bit-width of mem_out (signed)
  );
  port(
    clk          : in  std_logic;
    rst          : in  std_logic;   -- synchronous reset
    neuron_reset : in  std_logic;   -- asynchronous per-pixel reset
    spikes       : in  std_logic_vector(N_INPUTS-1 downto 0);  -- input spikes
    weights      : in  integer_vector(N_INPUTS-1 downto 0);    -- input weights
    bias         : in  integer;     -- bias term
    spike_out    : out std_logic;
    mem_out      : out signed(MEM_BITS-1 downto 0)
  );
end entity neuron;

architecture rtl of neuron is
  constant MAX_VOLTAGE : integer := 2**(MEM_BITS-1) - 1;
  constant MIN_VOLTAGE : integer := - (2**(MEM_BITS-1));
begin

  process(clk)
    variable voltage : integer := 0;
    variable sum_in  : integer := 0;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        voltage := 0;
        spike_out <= '0';
        mem_out <= (others => '0');
      else
        -- compute weighted sum of incoming spikes + bias
        sum_in := bias;
        for i in 0 to N_INPUTS-1 loop
          if spikes(i) = '1' then
            sum_in := sum_in + weights(i);
          end if;
        end loop;

        -- integrate
        voltage := voltage + sum_in;

        -- optional leak
        if LEAK /= 0 then
          if voltage > 0 then
            voltage := voltage - LEAK;
            if voltage < 0 then voltage := 0; end if;
          elsif voltage < 0 then
            voltage := voltage + LEAK;
            if voltage > 0 then voltage := 0; end if;
          end if;
        end if;

        -- clamp
        if voltage > MAX_VOLTAGE then
          voltage := MAX_VOLTAGE;
        elsif voltage < MIN_VOLTAGE then
          voltage := MIN_VOLTAGE;
        end if;

        -- external neuron_reset clears voltage immediately
        if neuron_reset = '1' then
          voltage := 0;
        end if;

        -- check threshold and generate spike
        if voltage >= V_TH then
          voltage := voltage - V_TH;
          spike_out <= '1';
        else
          spike_out <= '0';
        end if;

        mem_out <= to_signed(voltage, MEM_BITS);
      end if;
    end if;
  end process;

end architecture rtl;
