library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.types_pkg.all;
use work.weights_pkg.all;

entity tb_fc_layer_seq is
end tb_fc_layer_seq;

architecture behavior of tb_fc_layer_seq is

    -- Component Declaration
    component fc_layer_seq
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
    end component;

    -- Signals
    signal clk   : std_logic := '0';
    signal rst   : std_logic := '0';
    signal start : std_logic := '0';
    signal done  : std_logic;
    
    -- Test Inputs (Using N_INPUTS from weights_pkg)
    signal x_in  : int_vector_t(0 to N_INPUTS-1) := (
--    others => 10
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 140, 79, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 80, 226, 37, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 196, 164, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 28, 230, 112, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 101, 234, 23, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 137, 213, 0, 0, 19, 61, 67, 8, 0, 0, 0, 0, 0, 0, 0, 0, 152, 163, 0, 80, 218, 253, 249, 155, 9, 0, 0, 0, 0, 0, 0, 0, 192, 140, 112, 237, 155, 66, 54, 213, 33, 0, 0, 0, 0, 0, 0, 0, 191, 214, 239, 89, 0, 0, 21, 212, 35, 0, 0, 0, 0, 0, 0, 0, 138, 256, 163, 0, 0, 69, 187, 139, 9, 0, 0, 0, 0, 0, 0, 0, 28, 204, 227, 167, 175, 234, 118, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 24, 123, 159, 139, 51, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    ); -- Default input value 10
    signal z_out : int_vector_t(0 to N_HIDDEN-1);

    -- Clock period
    constant CLK_PERIOD : time := 10 ns;

begin

    -- Instantiate the Unit Under Test (UUT)
    -- We test the Input -> Hidden Layer (W_INPUT_HIDDEN)
    uut: fc_layer_seq
    generic map (
        WEIGHTS_G => W_INPUT_HIDDEN,
        BIAS_G    => B_INPUT_HIDDEN,
        N_IN_G    => N_INPUTS,
        N_OUT_G   => N_HIDDEN
    )
    port map (
        clk => clk,
        rst => rst,
        start => start,
        x_in => x_in,
        done => done,
        z_out => z_out
    );

    -- Clock Process
    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    -- Stimulus Process
    stim_proc: process
    begin
        -- 1. Reset
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for 20 ns;

        -- 2. Start Computation
        start <= '1';
        wait for CLK_PERIOD; -- Pulse start
        start <= '0';

        -- 3. Wait for Done
--        wait until done = '1';
        
        -- Wait for done with reasonable timeout (500 us)
        wait for 500 us;
        if done /= '1' then
            report "TIMEOUT: layer did not assert done within 500 us" severity FAILURE;
        else
            report "DONE asserted -- dumping some outputs";
            -- print a few z_out values to transcript
            for i in 0 to 7 loop
                report "z_out(" & integer'image(i) & ") = " & integer'image(z_out(i));
            end loop;
        end if;
        
        -- 4. Check Results (View z_out in Waveform)
        report "Calculation Done! Check z_out in Waveform window.";
        
        wait;
    end process;

end behavior;