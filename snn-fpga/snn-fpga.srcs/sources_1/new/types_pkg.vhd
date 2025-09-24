library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package types_pkg is
  -- 1-D integer array
  type integer_vector is array (natural range <>) of integer;

  -- matrix as an array of integer_vector (each element is a row)
  type integer_matrix is array (natural range <>) of integer_vector;

  -- convenience signed element type for memory outputs (default 16 bits)
  -- If you need variable width, you can change this typedef or avoid exposing mem arrays in ports.
  subtype mem_t is signed(15 downto 0);
  type mem_array is array (natural range <>) of mem_t;

end package types_pkg;
