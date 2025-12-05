library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_frame_receiver256 is
  generic(
    CLK_FREQ : integer := 100_000_000;
    BAUD     : integer := 115200
  );
  port(
    clk         : in  std_logic;
    rst         : in  std_logic;
    rx          : in  std_logic;  -- UART RX
    tx          : out std_logic;  -- UART TX (ACK/NAK)
    frame_data  : out std_logic_vector(8*256-1 downto 0); -- payload bytes packed
    frame_valid : out std_logic   -- pulse when new frame latched
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
    -- Fixed: Variable declared with correct name
    variable sum_chk : integer := 0;
  begin
    if rising_edge(clk) then
      -- Default values
      ready_r      <= '0';
      tx_start_sig <= '0'; 
      -- tx_byte_sig holds previous value unless updated
      
      if rst = '1' then
        fstate       <= WAIT_P1;
        byte_idx     <= 0;
        data_reg     <= (others => '0');
        sum_chk      := 0; -- Use := for variables
        tx_byte_sig  <= (others => '0');
      
      else
        if rx_ready = '1' then
          case fstate is
            when WAIT_P1 =>
              if rx_byte = x"AA" then
                fstate <= WAIT_P2;
              end if;

            when WAIT_P2 =>
              if rx_byte = x"55" then
                fstate   <= COLLECT;
                byte_idx <= 0;
                sum_chk  := 0; -- Reset checksum accumulator
              elsif rx_byte = x"AA" then
                fstate <= WAIT_P2; -- Stay in P2 if we get another AA
              else
                fstate <= WAIT_P1;
              end if;

            when COLLECT =>
              -- Use loop for static assignment (Synth 8-27 fix)
              for i in 0 to 255 loop
                  if i = byte_idx then
                      data_reg((i*8)+7 downto i*8) <= rx_byte;
                  end if;
              end loop;

              -- Update Checksum variable
              sum_chk := (sum_chk + to_integer(unsigned(rx_byte))) mod 256;

              if byte_idx = 255 then
                fstate <= CHECKSUM;
              else
                byte_idx <= byte_idx + 1;
              end if;

            when CHECKSUM =>
              -- Verify checksum
              if to_integer(unsigned(rx_byte)) = sum_chk then
                ready_r      <= '1';   -- Pulse valid
                tx_byte_sig  <= x"06"; -- ACK
                tx_start_sig <= '1';
                fstate       <= WAIT_P1;
              else
                tx_byte_sig  <= x"15"; -- NAK
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