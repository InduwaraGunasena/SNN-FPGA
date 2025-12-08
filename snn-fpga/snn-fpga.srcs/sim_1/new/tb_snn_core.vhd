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
0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 41, 65, 66, 52, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 63, 160, 199, 200, 179, 117, 43, 5, 0, 0, 0, 0, 0, 0, 0, 20, 123, 249, 255, 245, 229, 215, 150, 46, 0, 0, 0, 0, 0, 0, 0, 13, 91, 189, 185, 153, 142, 202, 232, 122, 0, 0, 0, 0, 0, 0, 0, 1, 33, 104, 115, 95, 132, 216, 249, 152, 0, 0, 0, 0, 0, 0, 0, 0, 45, 152, 198, 207, 236, 249, 207, 98, 0, 0, 0, 8, 36, 43, 9, 0, 45, 162, 222, 227, 242, 232, 134, 23, 0, 0, 0, 22, 108, 163, 102, 76, 84, 117, 154, 171, 220, 233, 128, 9, 0, 0, 0, 17, 105, 218, 228, 216, 208, 189, 179, 194, 233, 240, 147, 16, 0, 0, 0, 3, 35, 109, 167, 190, 202, 208, 198, 201, 195, 153, 72, 5, 0, 0, 0, 0, 0, 8, 31, 55, 73, 82, 67, 71, 64, 30, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
      
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