-- display_digit.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity display_digit is
  port(
    clk   : in  std_logic;
    digit : in  std_logic_vector(3 downto 0);  -- 0..9
    an    : out std_logic_vector(3 downto 0);
    seg   : out std_logic_vector(6 downto 0)
  );
end entity;

architecture rtl of display_digit is
begin
  -- single-digit static display (AN0 active low)
  an <= "1110";

  process(digit)
  begin
    case digit is
      when "0000" => seg <= "0000001"; -- 0
      when "0001" => seg <= "1001111"; -- 1
      when "0010" => seg <= "0010010"; -- 2
      when "0011" => seg <= "0000110"; -- 3
      when "0100" => seg <= "1001100"; -- 4
      when "0101" => seg <= "0100100"; -- 5
      when "0110" => seg <= "0100000"; -- 6
      when "0111" => seg <= "0001111"; -- 7
      when "1000" => seg <= "0000000"; -- 8
      when "1001" => seg <= "0000100"; -- 9
      when others => seg <= "1111111"; -- blank
    end case;
  end process;
end architecture;
