library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx is
    generic (
        CLKS_PER_BIT : integer := 868 -- 100MHz / 115200 baud
    );
    port (
        clk       : in  std_logic;
        rx_serial : in  std_logic;
        rx_dv     : out std_logic;
        rx_byte   : out std_logic_vector(7 downto 0)
    );
end uart_rx;

architecture rtl of uart_rx is
    type t_state is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    signal state : t_state := IDLE;
    signal clk_count : integer range 0 to CLKS_PER_BIT-1 := 0;
    signal bit_index : integer range 0 to 7 := 0;
    signal rx_data   : std_logic_vector(7 downto 0) := (others => '0');
begin
    process(clk)
    begin
        if rising_edge(clk) then
            case state is
                when IDLE =>
                    rx_dv <= '0';
                    clk_count <= 0;
                    bit_index <= 0;
                    if rx_serial = '0' then -- Start bit detected
                        state <= START_BIT;
                    end if;
                when START_BIT =>
                    if clk_count = (CLKS_PER_BIT-1)/2 then
                        if rx_serial = '0' then
                            clk_count <= 0;
                            state <= DATA_BITS;
                        else
                            state <= IDLE;
                        end if;
                    else
                        clk_count <= clk_count + 1;
                    end if;
                when DATA_BITS =>
                    if clk_count = CLKS_PER_BIT-1 then
                        clk_count <= 0;
                        rx_data(bit_index) <= rx_serial;
                        if bit_index < 7 then
                            bit_index <= bit_index + 1;
                        else
                            bit_index <= 0;
                            state <= STOP_BIT;
                        end if;
                    else
                        clk_count <= clk_count + 1;
                    end if;
                when STOP_BIT =>
                    if clk_count = CLKS_PER_BIT-1 then
                        rx_dv <= '1';
                        rx_byte <= rx_data;
                        state <= IDLE;
                    else
                        clk_count <= clk_count + 1;
                    end if;
            end case;
        end if;
    end process;
end rtl;