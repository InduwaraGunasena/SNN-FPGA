library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.types_pkg.all;

entity top_fpga is
    port(
        clk      : in std_logic; -- 100MHz on Basys 3
        RsRx     : in std_logic; -- USB-UART RX
        seg      : out std_logic_vector(6 downto 0);
        an       : out std_logic_vector(3 downto 0); -- Anodes
        led      : out std_logic_vector(15 downto 0) -- Debug LEDs
    );
end entity top_fpga;

architecture rtl of top_fpga is
    signal rx_dv   : std_logic;
    signal rx_byte : std_logic_vector(7 downto 0);
    
    signal input_vec : int_vector_t(0 to 255);
    signal write_idx : integer range 0 to 255 := 0;
    signal start_inf : std_logic := '0';
    signal inf_done  : std_logic;
    signal result    : integer range 0 to 9;
    
    -- Display signals
    signal seg_data : std_logic_vector(6 downto 0);
    
begin

    -- 1. UART Receiver
    u_rx : entity work.uart_rx
    generic map(CLKS_PER_BIT => 868)
    port map(
        clk => clk,
        rx_serial => RsRx,
        rx_dv => rx_dv,
        rx_byte => rx_byte
    );

    -- 2. Input Loading Logic
    process(clk)
    begin
        if rising_edge(clk) then
            start_inf <= '0';
            if rx_dv = '1' then
                input_vec(write_idx) <= to_integer(unsigned(rx_byte));
                if write_idx = 255 then
                    write_idx <= 0;
                    start_inf <= '1'; -- Start when full image received
                else
                    write_idx <= write_idx + 1;
                end if;
            end if;
        end if;
    end process;

    -- 3. SNN Core
    u_core : entity work.snn_core
    generic map(NUM_STEPS => 20)
    port map(
        clk => clk,
        rst => '0', -- Add reset button logic if desired
        start_infer => start_inf,
        input_vec => input_vec,
        inf_done => inf_done,
        pred_class => result
    );

    -- 4. Display Driver (Fixed for Basys 3)
    -- We only display the result on the right-most digit
    u_seg : entity work.seven_seg
    port map(
        digit => result,
        segs => seg_data
    );
    
    seg <= seg_data; -- Active Low on Basys 3 usually, check schematic
    an  <= "1110";   -- Activate only right-most digit (Active Low)
    
    -- Debug LEDs: Show progress or prediction
    led(3 downto 0) <= std_logic_vector(to_unsigned(result, 4));
    led(15) <= inf_done;

end architecture rtl;