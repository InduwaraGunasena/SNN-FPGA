-- ============================================================
-- File: hw/vhdl/packages/types_pkg.vhd
-- Purpose: common types, fixed-point constants, helper functions
-- ============================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


package types_pkg is
    -- Q-format configuration (included in weights_pkg.vhd file. No need to define it here.)
--    constant Q_FRAC_BITS : integer := 8; -- fractional bits (Q8.8)
--    constant Q_SCALE : integer := 2 ** Q_FRAC_BITS;
    
    -- Generic integer subtypes (adjust if you need larger ranges)
    subtype int16_t is integer range -32768 to 32767;
    subtype int32_t is integer range -2147483648 to 2147483647;
    
    
    -- 1D Vector (Unconstrained)
    type int_vector_t is array (natural range <>) of integer;
        
    -- True 2D Matrix (Row, Col)
    type int_matrix_t is array (natural range <>, natural range <>) of integer;
    
    
    -- Small utility function: sign-extend isn't needed for integer types, but provide clamp
    function clamp_i(val : integer; low : integer; high : integer) return integer;

end package types_pkg;


package body types_pkg is
    function clamp_i(val : integer; low : integer; high : integer) return integer is
    begin
        if val < low then
            return low;
        elsif val > high then
            return high;
        else
            return val;
        end if;
    end function clamp_i;

end package body types_pkg;