library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.types_pkg.all;
use work.weights_pkg.all;

entity lif_array_seq is
    generic(
        N_NEURONS_G : integer
    );
    port(
        clk       : in  std_logic;
        rst       : in  std_logic;
        start     : in  std_logic; -- start processing all neurons
        cur_in    : in  int_vector_t(0 to N_NEURONS_G-1);
        beta_q    : in  integer;
        threshold : in  integer;
        done      : out std_logic;
        mem_out   : out int_vector_t(0 to N_NEURONS_G-1);
        spikes    : out std_logic_vector(0 to N_NEURONS_G-1)
    );
end entity lif_array_seq;

architecture rtl of lif_array_seq is
    signal mem_array : int_vector_t(0 to N_NEURONS_G-1) := (others => 0);
    signal spikes_s  : std_logic_vector(0 to N_NEURONS_G-1) := (others => '0');
    signal idx       : integer range 0 to N_NEURONS_G := 0;
    signal running   : std_logic := '0';
begin
    process(clk)
        variable vtmp : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                idx <= 0;
                running <= '0';
                done <= '0';
                mem_array <= (others => 0);
                spikes_s <= (others => '0');
                mem_out <= (others => 0);
                spikes <= (others => '0');
            else
                done <= '0';
                if start = '1' and running = '0' then
                    running <= '1';
                    idx <= 0;
                elsif running = '1' then
                    if idx < N_NEURONS_G then
                        -- vtmp := (beta_q * mem_array(idx)) / Q_SCALE + cur_in(idx);
                        vtmp := to_integer(shift_right(to_signed(beta_q * mem_array(idx), 32), Q_FRAC_BITS)) + cur_in(idx);
                        if vtmp > threshold then
                            spikes_s(idx) <= '1';
                            mem_array(idx) <= vtmp - threshold;
                        else
                            spikes_s(idx) <= '0';
                            mem_array(idx) <= vtmp;
                        end if;
                        idx <= idx + 1;
                    else
                        -- finished
                        mem_out <= mem_array;
                        spikes <= spikes_s;
                        done <= '1';
                        running <= '0';
                        idx <= 0;
                    end if;
                end if;
            end if;
        end if;
    end process;
end architecture rtl;
