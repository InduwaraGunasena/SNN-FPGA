-- snn_top.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.types_pkg.all;
use work.weights_pkg.all;

entity snn_top is
  generic(
    N_INPUTS  : integer := 256;
    N_HIDDEN  : integer := 32;
    N_OUTPUT  : integer := 10;
    T_STEPS   : integer := 50  -- number of Poisson timesteps
  );
  port(
    clk          : in  std_logic;
    rst          : in  std_logic;
    frame_data   : in  std_logic_vector(8*N_INPUTS-1 downto 0);
    frame_valid  : in  std_logic;
    result_valid : out std_logic;
    digit_out    : out std_logic_vector(3 downto 0);

    -- debug outputs
    dbg_frame_pixels : out std_logic_vector(8*N_INPUTS-1 downto 0); -- intensities as latched from frame_data
    dbg_input_spikes : out std_logic_vector(N_INPUTS-1 downto 0);   -- one-shot Poisson snapshot at frame latch
    dbg_hidden_spk   : out std_logic_vector(N_HIDDEN-1 downto 0);  -- spike outputs of hidden layer
    dbg_hidden_inputs: out integer_vector(0 to N_HIDDEN-1);        -- input sums (pre-threshold) for hidden neurons
    dbg_output_inputs: out integer_vector(0 to N_OUTPUT-1);        -- input sums (pre-threshold) for output neurons
    dbg_out_counts   : out integer_vector(0 to N_OUTPUT-1)         -- output spike counts
  );
end entity;

architecture rtl of snn_top is

  --------------------------------------------------------------------
  -- small types
  --------------------------------------------------------------------
  subtype byte_t is unsigned(7 downto 0);
  type byte_array_t is array (natural range <>) of byte_t;

  --------------------------------------------------------------------
  -- signals
  --------------------------------------------------------------------
  signal frame_mem : byte_array_t(0 to N_INPUTS-1);

  signal hidden_spikes : std_logic_vector(N_HIDDEN-1 downto 0) := (others => '0');

  -- use integer_vector for output_counts so we can expose it directly
  signal output_counts : integer_vector(0 to N_OUTPUT-1);

  signal lfsr_reg : std_logic_vector(7 downto 0) := x"AA";

  -- single-cycle start pulse from unpacker to FSM
  signal start_frame : std_logic := '0';

  type state_t is (
    IDLE,
    TIMESTEP_START,
    HIDDEN_STREAM,
    HIDDEN_COMMIT,
    OUTPUT_STREAM,
    OUTPUT_COMMIT,
    NEXT_TIMESTEP,
    DONE,
    WAIT_RESULT
  );
  signal state : state_t := IDLE;

  signal tstep      : integer range 0 to integer'high := 0;
  signal neuron_i   : integer range 0 to integer'high := 0;
  signal input_i    : integer range 0 to integer'high := 0;
  signal out_j      : integer range 0 to integer'high := 0;
  signal hidden_k   : integer range 0 to integer'high := 0;

  -- debug internal signals (driven inside)
  signal dbg_input_spikes_sig : std_logic_vector(N_INPUTS-1 downto 0) := (others => '0');
  signal dbg_hidden_inputs_sig : integer_vector(0 to N_HIDDEN-1);
  signal dbg_output_inputs_sig : integer_vector(0 to N_OUTPUT-1);

  -- thresholds as signed accumulator width
  constant VTH_HIDDEN_ACC : acc_t := to_signed(V_TH_HIDDEN, ACC_BITS_C);
  constant VTH_OUTPUT_ACC : acc_t := to_signed(V_TH_OUTPUT, ACC_BITS_C);

begin

  --------------------------------------------------------------------
  -- LFSR RNG (8-bit, advances each clk)
  --------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        lfsr_reg <= x"AA";
      else
        lfsr_reg <= lfsr_reg(6 downto 0) & (lfsr_reg(7) xor lfsr_reg(5) xor lfsr_reg(4) xor lfsr_reg(3));
      end if;
    end if;
  end process;

  --------------------------------------------------------------------
  -- Unpack incoming frame bytes (frame_valid latches the frame into frame_mem)
  -- Also create a one-shot dbg_input_spikes_sig snapshot (debug-only)
  --------------------------------------------------------------------
  process(clk)
    variable tmp     : std_logic_vector(frame_data'range);
    variable idx_lo  : integer;
    variable idx_hi  : integer;
    variable b       : integer;
    variable rnd_var : std_logic_vector(7 downto 0);
    variable fb      : std_logic;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        for i in 0 to N_INPUTS-1 loop
          frame_mem(i) <= (others => '0');
          dbg_input_spikes_sig(i) <= '0';
        end loop;
        start_frame <= '0';
      else
        start_frame <= '0';
        if frame_valid = '1' then
          -- latch whole frame into frame_mem
          tmp := frame_data;
          for b in 0 to N_INPUTS-1 loop
            idx_lo := b*8;
            idx_hi := idx_lo + 7;
            frame_mem(b) <= unsigned(tmp(idx_hi downto idx_lo));
          end loop;

          -- produce a debug snapshot of Poisson spikes (one sampling across all inputs).
          -- initialize rnd_var from the current LFSR register (std_logic_vector)
          rnd_var := lfsr_reg;

          for b in 0 to N_INPUTS-1 loop
            -- one-step 8-bit LFSR: feedback = xor of taps [7,5,4,3]
            fb := rnd_var(7) xor rnd_var(5) xor rnd_var(4) xor rnd_var(3);
            -- shift left and insert feedback as LSB (same direction as your main LFSR)
            rnd_var := rnd_var(6 downto 0) & fb;
            -- compare numeric rnd to intensity (frame_mem is unsigned)
            if to_integer(unsigned(rnd_var)) < to_integer(frame_mem(b)) then
              dbg_input_spikes_sig(b) <= '1';
            else
              dbg_input_spikes_sig(b) <= '0';
            end if;
          end loop;

          -- pulse start_frame for FSM
          start_frame <= '1';
        end if;
      end if;
    end if;
  end process;


  --------------------------------------------------------------------
  -- Main serial FSM (keeps original behaviour)
  --------------------------------------------------------------------
  process(clk)
    -- locals used as variables (preserved between cycles)
    variable acc_var       : acc_t := (others => '0');
    variable w_int_var     : integer := 0;
    variable bias_int_var  : integer := 0;
    variable rand8_var     : unsigned(7 downto 0) := (others => '0');
    variable intensity_var : unsigned(7 downto 0) := (others => '0');
    variable best_i_var    : integer := 0;
    variable best_v_var    : integer := -1;
    variable k_var         : integer := 0;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= IDLE;
        hidden_spikes <= (others => '0');
        for i in 0 to N_OUTPUT-1 loop
          output_counts(i) <= 0;
        end loop;
        digit_out <= (others => '0');
        result_valid <= '0';
        tstep <= 0;
        neuron_i <= 0;
        input_i <= 0;
        out_j <= 0;
        hidden_k <= 0;
        acc_var := (others => '0');
        best_i_var := 0;
        best_v_var := -1;
        -- clear debug arrays
        for i in 0 to N_HIDDEN-1 loop dbg_hidden_inputs_sig(i) <= 0; end loop;
        for j in 0 to N_OUTPUT-1 loop dbg_output_inputs_sig(j) <= 0; end loop;
      else
        if start_frame = '1' and state = IDLE then
          for i in 0 to N_OUTPUT-1 loop
            output_counts(i) <= 0;
          end loop;
          tstep <= 0;
          hidden_spikes <= (others => '0');
          neuron_i <= 0;
          input_i <= 0;
          out_j <= 0;
          hidden_k <= 0;
          acc_var := (others => '0');
          result_valid <= '0';
          state <= TIMESTEP_START;
        else
          case state is
            when IDLE =>
              null;

            when TIMESTEP_START =>
              neuron_i <= 0;
              input_i <= 0;
              acc_var := (others => '0');
              state <= HIDDEN_STREAM;

            when HIDDEN_STREAM =>
              -- serially stream inputs into an accumulator for neuron neuron_i
              w_int_var := W_INPUT_HIDDEN(neuron_i, input_i);
              intensity_var := frame_mem(input_i);
              rand8_var := unsigned(lfsr_reg); -- sample RNG (note: lfsr_reg changes only each clock)
              if to_integer(rand8_var) < to_integer(intensity_var) then
                acc_var := acc_var + to_signed(w_int_var, ACC_BITS_C);
              end if;

              if input_i = N_INPUTS - 1 then
                state <= HIDDEN_COMMIT;
              else
                input_i <= input_i + 1;
              end if;

            when HIDDEN_COMMIT =>
              bias_int_var := B_INPUT_HIDDEN(neuron_i);
              acc_var := acc_var + to_signed(bias_int_var, ACC_BITS_C);

              -- record the pre-threshold input sum (debug)
              dbg_hidden_inputs_sig(neuron_i) <= to_integer(acc_var);

              if acc_var >= VTH_HIDDEN_ACC then
                hidden_spikes(neuron_i) <= '1';
                acc_var := acc_var - VTH_HIDDEN_ACC;
              else
                hidden_spikes(neuron_i) <= '0';
              end if;

              acc_var := (others => '0');
              if neuron_i = N_HIDDEN - 1 then
                out_j <= 0;
                hidden_k <= 0;
                state <= OUTPUT_STREAM;
              else
                neuron_i <= neuron_i + 1;
                input_i <= 0;
                state <= HIDDEN_STREAM;
              end if;

            when OUTPUT_STREAM =>
              w_int_var := W_HIDDEN_OUTPUT(out_j, hidden_k);
              if hidden_spikes(hidden_k) = '1' then
                acc_var := acc_var + to_signed(w_int_var, ACC_BITS_C);
              end if;

              if hidden_k = N_HIDDEN - 1 then
                state <= OUTPUT_COMMIT;
              else
                hidden_k <= hidden_k + 1;
              end if;

            when OUTPUT_COMMIT =>
              bias_int_var := B_HIDDEN_OUTPUT(out_j);
              acc_var := acc_var + to_signed(bias_int_var, ACC_BITS_C);

              -- record pre-threshold output input sum (debug)
              dbg_output_inputs_sig(out_j) <= to_integer(acc_var);

              if acc_var >= VTH_OUTPUT_ACC then
                output_counts(out_j) <= output_counts(out_j) + 1;
                acc_var := acc_var - VTH_OUTPUT_ACC;
              end if;

              acc_var := (others => '0');

              if out_j = N_OUTPUT - 1 then
                state <= NEXT_TIMESTEP;
              else
                out_j <= out_j + 1;
                hidden_k <= 0;
                state <= OUTPUT_STREAM;
              end if;

            when NEXT_TIMESTEP =>
              if tstep < T_STEPS - 1 then
                tstep <= tstep + 1;
                hidden_spikes <= (others => '0');
                neuron_i <= 0;
                input_i <= 0;
                acc_var := (others => '0');
                state <= HIDDEN_STREAM;
              else
                state <= DONE;
              end if;

            when DONE =>
              -- choose argmax over output_counts
              best_i_var := 0;
              best_v_var := -1;
              for k_var in 0 to N_OUTPUT-1 loop
                if output_counts(k_var) > best_v_var then
                  best_v_var := output_counts(k_var);
                  best_i_var := k_var;
                end if;
              end loop;
              digit_out <= std_logic_vector(to_unsigned(best_i_var, digit_out'length));
              result_valid <= '1';
              state <= WAIT_RESULT;

            when WAIT_RESULT =>
              result_valid <= '0';
              state <= IDLE;

            when others =>
              state <= IDLE;
          end case;
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------
  -- Debug output port wiring (combinational)
  --------------------------------------------------------------------
  dbg_frame_pixels <= frame_data;
  dbg_input_spikes <= dbg_input_spikes_sig;
  dbg_hidden_spk   <= hidden_spikes;
  dbg_hidden_inputs<= dbg_hidden_inputs_sig;
  dbg_output_inputs<= dbg_output_inputs_sig;
  dbg_out_counts   <= output_counts;

end architecture;

