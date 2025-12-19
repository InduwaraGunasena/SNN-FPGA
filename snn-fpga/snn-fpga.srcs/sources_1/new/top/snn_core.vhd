library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.types_pkg.all;
use work.weights_pkg.all;

entity snn_core is
    generic(
        NUM_STEPS : integer := 20
    );
    port(
        clk         : in  std_logic;
        rst         : in  std_logic;
        start_infer : in  std_logic;
        input_vec   : in  int_vector_t(0 to N_INPUTS-1);

        inf_done    : out std_logic;
        pred_class  : out integer
    );
end entity snn_core;

architecture rtl of snn_core is

    -- signals for fc1 (input->hidden)
    signal s_fc1_start : std_logic := '0';
    signal s_fc1_done  : std_logic := '0';
    signal z1_vec      : int_vector_t(0 to N_HIDDEN-1) := (others => 0);

    -- signals for lif1
    signal s_lif1_start: std_logic := '0';
    signal s_lif1_done : std_logic := '0';
    signal spikes1     : std_logic_vector(0 to N_HIDDEN-1) := (others => '0');

    -- spk1_q_vec will be built from spikes1
    signal spk1_q_vec  : int_vector_t(0 to N_HIDDEN-1) := (others => 0);

    -- fc2 signals (hidden->output)
    signal s_fc2_start : std_logic := '0';
    signal s_fc2_done  : std_logic := '0';
    signal z2_vec      : int_vector_t(0 to N_OUTPUT-1) := (others => 0);

    -- lif2 signals
    signal s_lif2_start: std_logic := '0';
    signal s_lif2_done : std_logic := '0';
    signal spikes2     : std_logic_vector(0 to N_OUTPUT-1) := (others => '0');

    signal score_vec   : int_vector_t(0 to N_OUTPUT-1) := (others => 0);
    
    -- DEBUG signals for membrane potentials
    signal dbg_mem1 : int_vector_t(0 to N_HIDDEN-1);
    signal dbg_mem2 : int_vector_t(0 to N_OUTPUT-1);
        
    -- FSM
    type state_t is (IDLE, FC1_RUN, LIF1_RUN, FC2_RUN, LIF2_RUN, ARGMAX);
    signal state : state_t := IDLE;
    signal step_cnt : integer := 0;

begin

    -- instantiate fc1: pass package weights/bias as generics
    fc1_inst : entity work.fc_layer_seq(rtl)
        generic map (
            WEIGHTS_G     => W_INPUT_HIDDEN,
            BIAS_G        => B_INPUT_HIDDEN,
            N_IN_G        => N_INPUTS,
            N_OUT_G       => N_HIDDEN,
            PARALLELISM_G => 64
        )
        port map (
            clk   => clk,
            rst   => rst,
            start => s_fc1_start,
            x_in  => input_vec,
            done  => s_fc1_done,
            z_out => z1_vec
        );

    -- instantiate lif1: hidden size
    lif1_inst : entity work.lif_array_seq(rtl)
        generic map ( N_NEURONS_G => N_HIDDEN )
        port map (
            clk => clk, rst => rst, start => s_lif1_start,
            cur_in => z1_vec, beta_q => LIF_BETA_Q, threshold => THRESHOLD_Q,
            done => s_lif1_done, mem_out => dbg_mem1, spikes => spikes1
        );

    -- instantiate fc2: hidden->output (pass different weights)
    fc2_inst : entity work.fc_layer_seq(rtl)
        generic map (
            WEIGHTS_G     => W_HIDDEN_OUTPUT,
            BIAS_G        => B_HIDDEN_OUTPUT,
            N_IN_G        => N_HIDDEN,
            N_OUT_G       => N_OUTPUT,
            PARALLELISM_G => 64
        )
        port map (
            clk   => clk,
            rst   => rst,
            start => s_fc2_start,
            x_in  => spk1_q_vec,
            done  => s_fc2_done,
            z_out => z2_vec
        );

    -- instantiate lif2: output size
    lif2_inst : entity work.lif_array_seq(rtl)
        generic map ( N_NEURONS_G => N_OUTPUT )
        port map (
            clk => clk, rst => rst, start => s_lif2_start,
            cur_in => z2_vec, beta_q => LIF_BETA_Q, threshold => THRESHOLD_Q,
            done => s_lif2_done, mem_out => dbg_mem2, spikes => spikes2
        );


    -- Build spk1_q_vec from spikes1 (use explicit sensitivity list to be pre-2008 friendly)
    spk_q_proc : process(spikes1)
    begin
        for i in 0 to N_HIDDEN-1 loop
            if spikes1(i) = '1' then
                spk1_q_vec(i) <= Q_SCALE;
            else
                spk1_q_vec(i) <= 0;
            end if;
        end loop;
    end process spk_q_proc;


    -- main FSM
    main_fsm : process(clk)
        variable maxv : integer;
        variable maxi : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                step_cnt <= 0;
                inf_done <= '0';
                pred_class <= 0;
                s_fc1_start <= '0';
                s_lif1_start <= '0';
                s_fc2_start <= '0';
                s_lif2_start <= '0';
                score_vec <= (others => 0);
            else
                case state is
                    when IDLE =>
                        inf_done <= '0';
                        if start_infer = '1' then
                            -- CRITICAL FIX: Reset scores before new inference
                            score_vec <= (others => 0);
                            s_fc1_start <= '1';
                            state <= FC1_RUN;
                        end if;

                    when FC1_RUN =>
                        if s_fc1_start = '1' then
                            s_fc1_start <= '0';
                        end if;
                        if s_fc1_done = '1' then
                            s_lif1_start <= '1';
                            state <= LIF1_RUN;
                        end if;

                    when LIF1_RUN =>
                        if s_lif1_start = '1' then
                            s_lif1_start <= '0';
                        end if;
                        if s_lif1_done = '1' then
                            s_fc2_start <= '1';
                            state <= FC2_RUN;
                        end if;

                    when FC2_RUN =>
                        if s_fc2_start = '1' then
                            s_fc2_start <= '0';
                        end if;
                        if s_fc2_done = '1' then
                            s_lif2_start <= '1';
                            state <= LIF2_RUN;
                        end if;

                    when LIF2_RUN =>
                        if s_lif2_start = '1' then
                            s_lif2_start <= '0';
                        end if;
                        if s_lif2_done = '1' then
                            -- accumulate scores
                            for o in 0 to N_OUTPUT-1 loop
                                if spikes2(o) = '1' then
                                    score_vec(o) <= score_vec(o) + Q_SCALE;
                                end if;
                            end loop;

                            if step_cnt < NUM_STEPS - 1 then
                                step_cnt <= step_cnt + 1;
                                s_fc1_start <= '1';
                                state <= FC1_RUN;
                            else
                                state <= ARGMAX;
                            end if;
                        end if;

                    when ARGMAX =>
                        maxv := -2147483647;
                        maxi := 0;
                        for o in 0 to N_OUTPUT-1 loop
                            if score_vec(o) > maxv then
                                maxv := score_vec(o);
                                maxi := o;
                            end if;
                        end loop;
                        pred_class <= maxi;
                        inf_done <= '1';
                        step_cnt <= 0;
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process main_fsm;

end architecture rtl;
