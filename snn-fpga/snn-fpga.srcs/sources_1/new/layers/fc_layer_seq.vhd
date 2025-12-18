library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.types_pkg.all;
use work.weights_pkg.all;

entity fc_layer_seq is
    generic(
        WEIGHTS_G     : int_matrix_t;
        BIAS_G        : int_vector_t;
        N_IN_G        : integer;
        N_OUT_G       : integer;
        PARALLELISM_G : integer := 8  -- Default to 8 parallel MACs
    );
    port(
        clk   : in  std_logic;
        rst   : in  std_logic;
        start : in  std_logic;
        x_in  : in  int_vector_t(0 to N_IN_G-1);
        done  : out std_logic;
        z_out : out int_vector_t(0 to N_OUT_G-1)
    );
end entity fc_layer_seq;

architecture rtl of fc_layer_seq is
    type t_state is (IDLE, COMPUTE_ACC, WRITE_RESULT, FINISHED);
    signal state : t_state := IDLE;
    
    signal row_idx : integer range 0 to N_OUT_G; -- Current Neuron
    signal col_idx : integer range 0 to N_IN_G;  -- Current Input
    signal acc     : integer := 0;               -- Accumulator
begin

    process(clk)
        variable v_sum : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state   <= IDLE;
                done    <= '0';
                row_idx <= 0;
                col_idx <= 0;
                acc     <= 0;
                z_out   <= (others => 0); 
            else
                case state is
                    when IDLE =>
                        done <= '0';
                        if start = '1' then
                            row_idx <= 0;
                            col_idx <= 0;
                            acc     <= 0;
                            state   <= COMPUTE_ACC;
                        end if;

                    when COMPUTE_ACC =>
                        -- PARALLEL MAC IMPLEMENTATION
                        -- We compute 'PARALLELISM_G' products in one cycle
                        v_sum := 0;
                        
                        -- Loop unrolling (Synthesis will parallelize this into an adder tree)
                        for k in 0 to PARALLELISM_G-1 loop
                            if (col_idx + k) < N_IN_G then
                                v_sum := v_sum + (WEIGHTS_G(row_idx, col_idx + k) * x_in(col_idx + k));
                            end if;
                        end loop;
                        
                        acc <= acc + v_sum;
                        
                        -- Check for end of row
                        if (col_idx + PARALLELISM_G) >= N_IN_G then
                            state <= WRITE_RESULT;
                        else
                            col_idx <= col_idx + PARALLELISM_G;
                        end if;

                    when WRITE_RESULT =>
                        -- Validation Scale + Bias
                        z_out(row_idx) <= to_integer(shift_right(to_signed(acc, 32), 8)) + BIAS_G(row_idx);

                        if row_idx = N_OUT_G - 1 then
                            state <= FINISHED;
                        else
                            row_idx <= row_idx + 1;
                            col_idx <= 0;
                            acc     <= 0;
                            state   <= COMPUTE_ACC;
                        end if;

                    when FINISHED =>
                        done <= '1';
                        state <= IDLE;
                        
                end case;
            end if;
        end if;
    end process;

end architecture rtl;