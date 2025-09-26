library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_snn_top is
end;

architecture sim of tb_snn_top is
  signal clk          : std_logic := '0';
  signal rst          : std_logic := '1';
  signal frame_data   : std_logic_vector(8*256-1 downto 0);
  signal frame_valid  : std_logic := '0';
  signal result_valid : std_logic;
  signal digit_out    : std_logic_vector(3 downto 0);

  -- clock period
  constant CLK_PERIOD : time := 10 ns;
begin
  -- DUT
  uut: entity work.snn_top
    port map(
      clk          => clk,
      rst          => rst,
      frame_data   => frame_data,
      frame_valid  => frame_valid,
      result_valid => result_valid,
      digit_out    => digit_out
    );

  -- clock
  clk_process: process
  begin
    while true loop
      clk <= '0'; wait for CLK_PERIOD/2;
      clk <= '1'; wait for CLK_PERIOD/2;
    end loop;
  end process;

  -- stimulus
  stim_proc: process
    variable img : std_logic_vector(8*256-1 downto 0);
  begin
    -- reset
    rst <= '1';
    wait for 50 ns;
    rst <= '0';

    -- Example "digit 0": all pixels = 200
    for i in 0 to 255 loop
      img((i+1)*8-1 downto i*8) := std_logic_vector(to_unsigned(200,8));
    end loop;
    frame_data <= img;
    frame_valid <= '1'; wait for CLK_PERIOD;
    frame_valid <= '0';

    -- wait for classification
    wait until result_valid = '1';
    report "Predicted digit (should be something like 0): " & integer'image(to_integer(unsigned(digit_out)));

    wait for 100 ns;

    -- Example "digit 1": half dark, half bright
    for i in 0 to 127 loop
      img((i+1)*8-1 downto i*8) := std_logic_vector(to_unsigned(20,8));
    end loop;
    for i in 128 to 255 loop
      img((i+1)*8-1 downto i*8) := std_logic_vector(to_unsigned(220,8));
    end loop;
    frame_data <= img;
    frame_valid <= '1'; wait for CLK_PERIOD;
    frame_valid <= '0';

    wait until result_valid = '1';
    report "Predicted digit (different pattern): " & integer'image(to_integer(unsigned(digit_out)));

    wait;
  end process;
end;
