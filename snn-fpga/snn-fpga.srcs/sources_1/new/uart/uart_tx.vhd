library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx is
  generic(
    CLK_FREQ : integer := 100_000_000;
    BAUD     : integer := 115200
  );
  port(
    clk      : in  std_logic;
    rst      : in  std_logic;
    tx_start : in  std_logic;                     -- pulse to send tx_byte (assert 1 cycle)
    tx_byte  : in  std_logic_vector(7 downto 0);
    tx       : out std_logic;                     -- UART TX (idle '1')
    tx_busy  : out std_logic
  );
end entity;

architecture rtl of uart_tx is
  type state_t is (IDLE, START, DATA, STOP);
  signal state : state_t := IDLE;

begin
  process(clk)
    variable acc : integer := 0;
    constant TICK_INC : integer := BAUD;
    variable bit_tick : boolean := false;
    variable bit_idx  : integer := 0;
    variable shreg   : std_logic_vector(7 downto 0) := (others => '0');
    variable outbit  : std_logic := '1';
    variable tx_active : boolean := false;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        acc := 0;
        state <= IDLE;
        tx <= '1';
        tx_busy <= '0';
      else
        -- simple fractional tick generator for bit ticks (one tick per baud)
        acc := acc + TICK_INC;
        if acc >= CLK_FREQ then
          acc := acc - CLK_FREQ;
          bit_tick := true;
        else
          bit_tick := false;
        end if;

        case state is
          when IDLE =>
            tx <= '1';
            tx_busy <= '0';
            if tx_start = '1' then
              shreg := tx_byte;
              bit_idx := 0;
              tx_busy <= '1';
              state <= START;
            end if;

          when START =>
            if bit_tick then
              tx <= '0'; -- start bit (low)
              state <= DATA;
            end if;

          when DATA =>
            if bit_tick then
              tx <= shreg(bit_idx);
              if bit_idx < 7 then
                bit_idx := bit_idx + 1;
              else
                state <= STOP;
              end if;
            end if;

          when STOP =>
            if bit_tick then
              tx <= '1'; -- stop bit
              state <= IDLE;
              tx_busy <= '0';
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
