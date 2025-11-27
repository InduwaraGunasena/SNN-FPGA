-- types_pkg.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package types_pkg is

  -- CHANGE THESE IF YOU CHANGE QUANTIZATION. Keep consistent with Python generator.
  constant MEM_BITS_C : integer := 16;  -- width of stored weight/bias integers
  constant ACC_BITS_C : integer := 32;  -- accumulator internal width (must be larger)

  -- integer weight type (for weights stored via weights_pkg)
  subtype weight_int_t is integer range -2**(MEM_BITS_C-1) to 2**(MEM_BITS_C-1)-1;

  -- matrix/vector types using integers (weights/biases generated into weights_pkg.vhd)
  type integer_vector is array (natural range <>) of integer;
  type integer_matrix is array (natural range <>, natural range <>) of integer;

  -- accumulator signed type
  subtype acc_t is signed(ACC_BITS_C-1 downto 0);

  -- convenient types
  type acc_array is array (natural range <>) of acc_t;
  type mem_array is array (natural range <>) of signed(MEM_BITS_C-1 downto 0);

end package types_pkg;
