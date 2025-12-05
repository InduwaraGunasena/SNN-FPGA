library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.types_pkg.all;
use work.weights_pkg.all;

entity fc_layer_seq is
    generic(
        WEIGHTS_G : int_matrix_t;
        BIAS_G    : int_vector_t;
        N_IN_G    : integer;
        N_OUT_G   : integer
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
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state   <= IDLE;
                done    <= '0';
                row_idx <= 0;
                col_idx <= 0;
                acc     <= 0;
                z_out   <= (others => 0); -- Safe init
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
                        -- MAC Operation: Accumulate (Weight * Input)
                        if col_idx < N_IN_G then
                            acc <= acc + (WEIGHTS_G(row_idx, col_idx) * x_in(col_idx)) / Q_SCALE;
                            col_idx <= col_idx + 1;
                        else
                            -- Column loop finished, add bias
                            state <= WRITE_RESULT;
                        end if;

                    when WRITE_RESULT =>
                        -- Store result + bias
                        z_out(row_idx) <= acc + BIAS_G(row_idx);
                        
                        -- Check if we are done with all neurons
                        if row_idx = N_OUT_G - 1 then
                            state <= FINISHED;
                        else
                            -- Setup for next neuron
                            row_idx <= row_idx + 1;
                            col_idx <= 0;
                            acc     <= 0;
                            state   <= COMPUTE_ACC;
                        end if;

                    when FINISHED =>
                        done <= '1';
                        -- Wait for start signal to drop (handshake) or auto-reset
                        state <= IDLE;
                        
                end case;
            end if;
        end if;
    end process;

end architecture rtl;