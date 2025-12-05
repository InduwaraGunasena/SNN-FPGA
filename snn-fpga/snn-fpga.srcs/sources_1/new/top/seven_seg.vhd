-- ============================================================
-- File: hw/vhdl/top/sevenseg.vhd
-- Purpose: simple 1-digit 7-segment driver mapping 0..9 to segments
-- ============================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity seven_seg is
    port(
        digit : in integer range 0 to 15;
        segs : out std_logic_vector(6 downto 0) -- segments a..g
    );
end entity seven_seg;


architecture rtl of seven_seg is
begin
process(digit)
    begin
        case digit is
            when 0 => segs <= "1111110"; -- 0
            when 1 => segs <= "0110000"; -- 1
            when 2 => segs <= "1101101"; -- 2
            when 3 => segs <= "1111001"; -- 3
            when 4 => segs <= "0110011"; -- 4
            when 5 => segs <= "1011011"; -- 5
            when 6 => segs <= "1011111"; -- 6
            when 7 => segs <= "1110000"; -- 7
            when 8 => segs <= "1111111"; -- 8
            when 9 => segs <= "1111011"; -- 9
            when others => segs <= "0000000";
        end case;
end process;
end architecture rtl;