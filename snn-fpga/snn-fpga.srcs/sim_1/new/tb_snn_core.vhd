library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.types_pkg.all;
use work.weights_pkg.all;

entity tb_snn_core is
end tb_snn_core;

architecture behavior of tb_snn_core is

    component snn_core
        generic( NUM_STEPS : integer := 20 );
        port(
            clk         : in  std_logic;
            rst         : in  std_logic;
            start_infer : in  std_logic;
            input_vec   : in  int_vector_t(0 to N_INPUTS-1);
            inf_done    : out std_logic;
            pred_class  : out integer
        );
    end component;

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '0';
    signal start_infer : std_logic := '0';
    signal inf_done    : std_logic;
    signal pred_class  : integer;

    -- COPY-PASTE FROM PYTHON HERE:
    signal test_input : int_vector_t(0 to 255) := (
        -- REPLACE THIS LINE WITH THE ARRAY PRINTED BY YOUR PYTHON SCRIPT
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 140, 79, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 80, 226, 37, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 196, 164, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 28, 230, 112, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 101, 234, 23, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 137, 213, 0, 0, 19, 61, 67, 8, 0, 0, 0, 0, 0, 0, 0, 0, 152, 163, 0, 80, 218, 253, 249, 155, 9, 0, 0, 0, 0, 0, 0, 0, 192, 140, 112, 237, 155, 66, 54, 213, 33, 0, 0, 0, 0, 0, 0, 0, 191, 214, 239, 89, 0, 0, 21, 212, 35, 0, 0, 0, 0, 0, 0, 0, 138, 256, 163, 0, 0, 69, 187, 139, 9, 0, 0, 0, 0, 0, 0, 0, 28, 204, 227, 167, 175, 234, 118, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 24, 123, 159, 139, 51, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
      
    );

    constant CLK_PERIOD : time := 10 ns;

begin

    uut: snn_core
    generic map ( NUM_STEPS => 20 )
    port map (
        clk => clk,
        rst => rst,
        start_infer => start_infer,
        input_vec => test_input,
        inf_done => inf_done,
        pred_class => pred_class
    );

    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    stim_proc: process
    begin
        -- Reset system
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for 20 ns;

        -- Start Inference
        start_infer <= '1';
        wait for CLK_PERIOD;
        start_infer <= '0';

        -- Wait for completion
        wait until inf_done = '1';
        
        -- Display Result
        report "Inference Finished.";
        report "Predicted Class: " & integer'image(pred_class);
        
        wait;
    end process;

end behavior;