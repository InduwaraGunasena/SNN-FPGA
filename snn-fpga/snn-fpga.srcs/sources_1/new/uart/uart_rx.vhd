library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx is
  generic(
    CLK_FREQ : integer := 100_000_000; -- system clock Hz
    BAUD     : integer := 115200;      -- desired UART baud
    OVERSAMP : integer := 16          -- oversampling factor
  );
  port(
    clk      : in  std_logic;
    rst      : in  std_logic;
    rx       : in  std_logic;                         -- UART RX (idle '1')
    rx_byte  : out std_logic_vector(7 downto 0);
    rx_ready : out std_logic                         -- single-cycle pulse when byte available
  );
end entity;

architecture rtl of uart_rx is
  type state_t is (IDLE, START, DATA, STOP);
  signal state       : state_t := IDLE;

  -- internal variables will be implemented by process variables
begin

  process(clk)
    -- fractional accumulator and counters as variables (preserved across calls)
    variable acc_ticks    : integer := 0;            -- accumulator for sample tick
    constant TICK_INC     : integer := BAUD * OVERSAMP;
    variable sample_tick  : boolean := false;
    variable samp_cnt     : integer := 0;            -- oversample counter
    variable bit_idx      : integer := 0;
    variable shift_reg    : std_logic_vector(7 downto 0) := (others => '0');
    variable rx_sync      : std_logic_vector(2 downto 0) := (others => '1');
  begin
    if rising_edge(clk) then
      if rst = '1' then
        acc_ticks := 0;
        sample_tick := false;
        samp_cnt := 0;
        bit_idx := 0;
        shift_reg := (others => '0');
        rx_sync := (others => '1');
        state <= IDLE;
        rx_byte <= (others => '0');
        rx_ready <= '0';
      else
        rx_ready <= '0';  -- default low

        -- 3-stage synchronizer (update variable)
        rx_sync := rx_sync(1 downto 0) & rx;

        -- fractional tick generator for oversampling:
        acc_ticks := acc_ticks + TICK_INC;
        if acc_ticks >= CLK_FREQ then
          acc_ticks := acc_ticks - CLK_FREQ;
          sample_tick := true;
        else
          sample_tick := false;
        end if;

        if sample_tick then
          -- oversample FSM
          case state is
            when IDLE =>
              -- waiting for start bit (line low)
              if rx_sync(2) = '0' then
                -- detected falling edge => possible start bit
                samp_cnt := 0;
                acc_ticks := acc_ticks; -- keep accumulator
                state <= START;
              end if;

            when START =>
              -- count oversamples until middle of start bit (OVERSAMP/2)
              if samp_cnt < (OVERSAMP/2 - 1) then
                samp_cnt := samp_cnt + 1;
              else
                -- sample start bit
                if rx_sync(2) = '0' then
                  samp_cnt := 0;
                  bit_idx := 0;
                  state <= DATA;
                else
                  -- false start, return to idle
                  state <= IDLE;
                end if;
              end if;

            when DATA =>
              if samp_cnt < OVERSAMP - 1 then
                samp_cnt := samp_cnt + 1;
              else
                samp_cnt := 0;
                -- sample bit (LSB first)
                shift_reg(bit_idx) := rx_sync(2);
                if bit_idx < 7 then
                  bit_idx := bit_idx + 1;
                else
                  state <= STOP;
                end if;
              end if;

            when STOP =>
              -- CRITICAL FIX: Only wait for HALF the stop bit (OVERSAMP/2)
              -- This ensures we are back in IDLE before the next Start bit arrives.
              if samp_cnt < (OVERSAMP/2) then
                samp_cnt := samp_cnt + 1;
              else
                samp_cnt := 0;
                -- If line is high (Stop bit valid), latch the data
                if rx_sync(2) = '1' then
                  rx_byte <= shift_reg;
                  rx_ready <= '1';
                end if;
                -- Go to IDLE immediately
                state <= IDLE;
              end if;
              
          end case;
        end if; -- sample_tick
      end if;
    end if;
  end process;

end architecture;
