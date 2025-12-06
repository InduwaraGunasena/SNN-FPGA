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
        -- Basys 3 has common anode type 7 seg display (0= on 1=off    g f e d c b a)
            when 0 => segs <= "1000000"; -- 0
            when 1 => segs <= "1111001"; -- 1
            when 2 => segs <= "0100100"; -- 2
            when 3 => segs <= "0110000"; -- 3
            when 4 => segs <= "0011001"; -- 4
            when 5 => segs <= "0010010"; -- 5
            when 6 => segs <= "0000010"; -- 6
            when 7 => segs <= "1111000"; -- 7
            when 8 => segs <= "0000000"; -- 8
            when 9 => segs <= "0010000"; -- 9
            when others => segs <= "1111111";
            
        end case;
end process;
end architecture rtl;