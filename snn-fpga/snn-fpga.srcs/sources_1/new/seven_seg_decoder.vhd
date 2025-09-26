library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity seven_seg_decoder is
  port(
    digit : in  std_logic_vector(3 downto 0);  -- binary input 0..9
    seg   : out std_logic_vector(6 downto 0)   -- a..g segments
  );
end entity;

architecture rtl of seven_seg_decoder is
begin
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
