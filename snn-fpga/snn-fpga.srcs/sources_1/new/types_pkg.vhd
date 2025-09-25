library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package types_pkg is
  --------------------------------------------------------------------
  -- Integer weights
  --------------------------------------------------------------------
  -- Explicitly constrain integers to 16-bit range (safe for FPGA)
  subtype int16 is integer range -32768 to 32767;
  
  -- 1D array of weights (for one neuron’s inputs)
  type integer_vector is array (natural range <>) of int16;
  
  -- 2D array of weights (for a layer: neurons × inputs)
  -- Both dimensions must be constrained when you declare a signal/constant
  type integer_matrix is array (natural range <>, natural range <>) of int16;


  --------------------------------------------------------------------
  -- Membrane potential outputs
  --------------------------------------------------------------------
  -- Default signed type (16 bits wide)
  subtype mem_t is signed(15 downto 0);

  -- Array of membrane outputs (one per neuron in a layer)
  type mem_array is array (natural range <>) of mem_t;
  
end package types_pkg;
