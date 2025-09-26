library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity display_digit is
  port(
    clk       : in  std_logic;
    spikes_out: in  std_logic_vector(9 downto 0);  -- SNN output
    an        : out std_logic_vector(3 downto 0);  -- display anodes
    seg       : out std_logic_vector(6 downto 0)   -- 7-seg segments
  );
end entity;

architecture rtl of display_digit is
  signal digit_bin : std_logic_vector(3 downto 0);
begin

  -- Convert spikes_out (one-hot) to binary digit
  process(spikes_out)
    variable i : integer;
  begin
    digit_bin <= (others => '0');  -- default
    for i in 0 to 9 loop
      if spikes_out(i) = '1' then
        digit_bin <= std_logic_vector(to_unsigned(i, 4));
      end if;
    end loop;
  end process;

  -- Connect to 7-segment decoder
  seg_dec: entity work.seven_seg_decoder
    port map(
      digit => digit_bin,
      seg   => seg
    );

  -- Activate only AN0
  an <= "1110";  -- AN0 active low
end architecture;
