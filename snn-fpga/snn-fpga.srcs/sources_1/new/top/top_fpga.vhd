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
    -- CLOCK DIVIDER SIGNALS
    signal clk_div   : unsigned(1 downto 0) := "00";
    signal sys_clk   : std_logic; -- This will be 25 MHz
    
    -- Signals for UART
    signal uart_data_flat : std_logic_vector(2047 downto 0); -- 256 * 8 bits
    signal uart_valid     : std_logic;
    
    -- Signals for SNN
    signal input_vec      : int_vector_t(0 to 255);
    signal start_inf      : std_logic := '0';
    signal core_rst       : std_logic := '0'; -- Controlled Reset Signal
    signal rst_cnt        : integer range 0 to 31 := 0;
    signal inf_done       : std_logic;
    signal result         : integer range 0 to 9;
    
    -- Control FSM
    type t_ctrl_state is (IDLE, ASSERT_RESET, START_INFER, WAIT_STABLE, WAIT_DONE);
    signal ctrl_state : t_ctrl_state := IDLE;
        
    -- Display signals
    signal seg_data       : std_logic_vector(6 downto 0);
    
    -- Debug / Visibility
    signal led_done_toggle : std_logic := '0';
    signal input_checksum  : unsigned(7 downto 0) := (others => '0');

begin

    -- 1. Clock Divider Process (100MHz -> 25MHz)
    -- We count 0..3. Bit 1 toggles every 2 cycles (Divide by 4).
    process(clk)
    begin
        if rising_edge(clk) then
            clk_div <= clk_div + 1;
        end if;
    end process;

    -- Use Bit 1 as the new system clock (25 MHz)
    -- Use a BUFG if you want to be proper, but for this speed direct assignment works.
    sys_clk <= clk_div(1);
    
    
    -- 1. Instantiate Your Specific UART Receiver
    u_uart_rx : entity work.uart_frame_receiver256
    generic map(
        CLK_FREQ => 25_000_000, --100_000_000,
        BAUD     => 115200
    )
    port map(
        clk         => sys_clk,
        rst         => '0',
        rx          => RsRx,
        tx          => RsTx,         -- Connects to Basys 3 TX pin
        frame_data  => uart_data_flat,
        frame_valid => uart_valid
    );

    -- 2. Data Conversion Process (Bit Vector -> Integer Array)
    -- This unpacks the 2048-bit vector into 256 integers for the SNN
    -- Main Control Process (Unpacking + Reset Logic)
    process(sys_clk)
        variable sum_temp : unsigned(7 downto 0);
    begin
        if rising_edge(sys_clk) then
            case ctrl_state is
                when IDLE =>
                    start_inf <= '0';
                    core_rst  <= '0'; 

                    if uart_valid = '1' then
                        -- 1. Unpack data immediately
                        sum_temp := (others => '0');
                        for i in 0 to 255 loop
                            input_vec(i) <= to_integer(unsigned(uart_data_flat(i*8 + 7 downto i*8)));
                            sum_temp := sum_temp + unsigned(uart_data_flat(i*8 + 7 downto i*8));
                        end loop;
                        input_checksum <= sum_temp;
                        
                        -- 2. Go to Reset state to clear SNN memory
                        ctrl_state <= ASSERT_RESET;
                    end if;

                when ASSERT_RESET =>
                    -- Pulse Reset High to clear LIF membranes and Scores
                    core_rst <= '1';
                    start_inf <= '0';
                    
                    -- ctrl_state <= START_INFER;                                     
                    if rst_cnt < 15 then
                        rst_cnt <= rst_cnt + 1;
                        ctrl_state <= ASSERT_RESET; -- Stay here
                    else
                        rst_cnt <= 0;
                        ctrl_state <= WAIT_STABLE; -- NEW: Go here instead of START_INFER                    
                    end if;
                    
                -- NEW STATE: Hold everything low for a few cycles
                when WAIT_STABLE =>
                    core_rst <= '0';   -- Release Reset
                    start_inf <= '0';  -- Wait before Starting
    
                    if rst_cnt < 10 then  -- Reuse counter for a short delay
                        rst_cnt <= rst_cnt + 1;
                        ctrl_state <= WAIT_STABLE;
                    else
                        rst_cnt <= 0;
                        ctrl_state <= START_INFER; -- NOW we start
                    end if;

                when START_INFER =>
                    -- Release Reset, Trigger Start
                    core_rst <= '0';
                    start_inf <= '1';
                    ctrl_state <= WAIT_DONE;

                when WAIT_DONE =>
                    start_inf <= '0';
                    if inf_done = '1' then
                        led_done_toggle <= not led_done_toggle;
                        ctrl_state <= IDLE;
                    end if;
            end case;
        end if;
    end process;

    -- 3. SNN Core (Same as before)
    u_core : entity work.snn_core
    generic map(NUM_STEPS => 20)
    port map(
        clk         => sys_clk,
        rst         => core_rst,   -- <--- use the core_rst signal so reset pulses reach the SNN
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
    
    -- 5. Debug LEDs
    -- LED 0-3: Prediction Result (Binary)
    led(3 downto 0) <= std_logic_vector(to_unsigned(result, 4));
    
    -- LED 4-7: Always OFF (Separator)
    led(6 downto 4) <= "000";
    
    -- LED 8-14: Input Image Checksum (Verifies new image received)
    led(14 downto 7) <= std_logic_vector(input_checksum);
    
    -- LED 15: Done Toggle (Changes state every time inference finishes)
    led(15) <= led_done_toggle;

end architecture rtl;