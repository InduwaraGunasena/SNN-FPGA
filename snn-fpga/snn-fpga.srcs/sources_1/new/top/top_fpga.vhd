library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.types_pkg.all;  -- Contains int_vector_t
use work.weights_pkg.all;

entity top_fpga is
    port(
        clk      : in std_logic; -- 100MHz Basys 3
        RsRx     : in std_logic; -- USB-UART RX
        RsTx     : out std_logic; -- USB-UART TX (New! For ACK/NAK)
        seg      : out std_logic_vector(6 downto 0);
        an       : out std_logic_vector(3 downto 0);
        led      : out std_logic_vector(15 downto 0)
    );
end entity top_fpga;

architecture rtl of top_fpga is

    -- Signals for UART
    signal uart_data_flat : std_logic_vector(2047 downto 0); -- 256 * 8 bits
    signal uart_valid     : std_logic;
    
    -- Signals for SNN
    signal input_vec      : int_vector_t(0 to 255);
    signal start_inf      : std_logic := '0';
    signal inf_done       : std_logic;
    signal result         : integer range 0 to 9;
    
    -- Display signals
    signal seg_data       : std_logic_vector(6 downto 0);

begin

    -- 1. Instantiate Your Specific UART Receiver
    u_uart_rx : entity work.uart_frame_receiver256
    generic map(
        CLK_FREQ => 100_000_000,
        BAUD     => 115200
    )
    port map(
        clk         => clk,
        rst         => '0',
        rx          => RsRx,
        tx          => RsTx,         -- Connects to Basys 3 TX pin
        frame_data  => uart_data_flat,
        frame_valid => uart_valid
    );

    -- 2. Data Conversion Process (Bit Vector -> Integer Array)
    -- This unpacks the 2048-bit vector into 256 integers for the SNN
    process(clk)
    begin
        if rising_edge(clk) then
            start_inf <= '0'; -- Pulse default
            
            if uart_valid = '1' then
                for i in 0 to 255 loop
                    -- Extract 8 bits and convert to integer
                    -- Note: byte_idx logic in your UART code fills LSB first
                    input_vec(i) <= to_integer(unsigned(uart_data_flat(i*8 + 7 downto i*8)));
                end loop;
                start_inf <= '1'; -- Trigger SNN start
            end if;
        end if;
    end process;

    -- 3. SNN Core (Same as before)
    u_core : entity work.snn_core
    generic map(NUM_STEPS => 20)
    port map(
        clk         => clk,
        rst         => '0',
        start_infer => start_inf,
        input_vec   => input_vec,
        inf_done    => inf_done,
        pred_class  => result
    );

    -- 4. Display Driver
    u_seg : entity work.seven_seg
    port map(digit => result, segs => seg_data);
    
    seg <= seg_data;
    an  <= "1110"; 
    
    -- Debug LEDs
    led(3 downto 0) <= std_logic_vector(to_unsigned(result, 4));
    led(15) <= inf_done;

end architecture rtl;