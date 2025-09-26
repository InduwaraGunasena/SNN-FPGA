library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_frame_receiver256 is
  generic(
    CLK_FREQ : integer := 100_000_000;
    BAUD     : integer := 115200
  );
  port(
    clk        : in  std_logic;
    rst        : in  std_logic;
    rx         : in  std_logic;  -- UART RX
    tx         : out std_logic;  -- UART TX (ACK/NAK)
    frame_data : out std_logic_vector(8*256-1 downto 0); -- payload bytes packed
    frame_valid: out std_logic   -- pulse when new frame latched
  );
end entity;

architecture rtl of uart_frame_receiver256 is
  signal rx_byte  : std_logic_vector(7 downto 0);
  signal rx_ready : std_logic;

  -- internal storage
  signal data_reg : std_logic_vector(8*256-1 downto 0) := (others => '0');
  signal ready_r  : std_logic := '0';

  -- states for frame parsing
  type fstate_t is (WAIT_P1, WAIT_P2, COLLECT, CHECKSUM);
  signal fstate : fstate_t := WAIT_P1;
  signal byte_idx : integer range 0 to 255 := 0;

  -- UART TX support
  signal tx_byte_sig   : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_start_sig  : std_logic := '0';
  signal tx_busy_sig   : std_logic := '0';

begin

  -- instantiate uart_rx
  rx_inst: entity work.uart_rx
    generic map(CLK_FREQ => CLK_FREQ, BAUD => BAUD)
    port map(clk => clk, rst => rst,
             rx => rx, rx_byte => rx_byte, rx_ready => rx_ready);

  -- instantiate uart_tx (for ack/nak)
  tx_inst: entity work.uart_tx
    generic map(CLK_FREQ => CLK_FREQ, BAUD => BAUD)
    port map(clk => clk, rst => rst,
             tx_start => tx_start_sig, tx_byte => tx_byte_sig,
             tx => tx, tx_busy => tx_busy_sig);

  -- main parsing process
  process(clk)
    -- process-local variables
    variable tmp     : std_logic_vector(data_reg'range);
    variable sum_chk : integer := 0;
    variable idx_lo  : natural := 0;
    variable idx_hi  : natural := 0;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        fstate       <= WAIT_P1;
        byte_idx     <= 0;
        data_reg     <= (others => '0');
        ready_r      <= '0';
        tx_start_sig <= '0';
        tx_byte_sig  <= (others => '0');
        sum_chk      := 0;

      else
        ready_r      <= '0';
        tx_start_sig <= '0';  -- default: don’t start tx this cycle

        if rx_ready = '1' then
          case fstate is
            when WAIT_P1 =>
              if rx_byte = x"AA" then
                fstate <= WAIT_P2;
              else
                fstate <= WAIT_P1;
              end if;

            when WAIT_P2 =>
              if rx_byte = x"55" then
                fstate   <= COLLECT;
                byte_idx <= 0;
                sum_chk  := 0;
              elsif rx_byte = x"AA" then
                fstate <= WAIT_P2; -- saw another AA
              else
                fstate <= WAIT_P1;
              end if;

            when COLLECT =>
              -- write byte into data_reg at position byte_idx
              tmp := data_reg;
              idx_lo := byte_idx * 8;
              idx_hi := idx_lo + 7;
              tmp(idx_hi downto idx_lo) := rx_byte;
              data_reg <= tmp;

              -- update checksum
              sum_chk := (sum_chk + to_integer(unsigned(rx_byte))) mod 256;

              if byte_idx = 255 then
                fstate <= CHECKSUM;
              else
                byte_idx <= byte_idx + 1;
              end if;

            when CHECKSUM =>
              -- rx_byte is checksum byte
              if to_integer(unsigned(rx_byte)) = (sum_chk mod 256) then
                -- good frame
                ready_r      <= '1';
                tx_byte_sig  <= x"06";    -- ACK
                tx_start_sig <= '1';
                fstate       <= WAIT_P1;
              else
                -- bad frame -> NAK
                tx_byte_sig  <= x"15";    -- NAK
                tx_start_sig <= '1';
                fstate       <= WAIT_P1;
              end if;
          end case;
        end if;
      end if;
    end if;
  end process;

  frame_data  <= data_reg;
  frame_valid <= ready_r;

end architecture;
