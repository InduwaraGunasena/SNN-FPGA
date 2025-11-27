-- tb_snn_top.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.types_pkg.all;  -- for integer_vector

entity tb_snn_top is
end;

architecture sim of tb_snn_top is
  signal clk          : std_logic := '0';
  signal rst          : std_logic := '1';
  signal frame_data   : std_logic_vector(8*256-1 downto 0);
  signal frame_valid  : std_logic := '0';
  signal result_valid : std_logic;
  signal digit_out    : std_logic_vector(3 downto 0);

  -- debug signals (matching snn_top ports)
  signal dbg_frame_pixels : std_logic_vector(8*256-1 downto 0);
  signal dbg_input_spikes : std_logic_vector(255 downto 0);
  signal dbg_hidden_spk   : std_logic_vector(31 downto 0); -- N_HIDDEN=32
  signal dbg_hidden_inputs: integer_vector(0 to 31);
  signal dbg_output_inputs: integer_vector(0 to 9);
  signal dbg_out_counts   : integer_vector(0 to 9);

  -- clock period
  constant CLK_PERIOD : time := 10 ns;
begin
  -- DUT (use the debug build filename / entity)
  uut: entity work.snn_top
    generic map(
        N_INPUTS => 256,
        N_HIDDEN => 32,
        N_OUTPUT => 10,
        T_STEPS  => 50
    )
    port map(
      clk          => clk,
      rst          => rst,
      frame_data   => frame_data,
      frame_valid  => frame_valid,
      result_valid => result_valid,
      digit_out    => digit_out,
      dbg_frame_pixels => dbg_frame_pixels,
      dbg_input_spikes => dbg_input_spikes,
      dbg_hidden_spk   => dbg_hidden_spk,
      dbg_hidden_inputs=> dbg_hidden_inputs,
      dbg_output_inputs=> dbg_output_inputs,
      dbg_out_counts   => dbg_out_counts
    );

  -- clock
  clk_process: process
  begin
    while true loop
      clk <= '0'; wait for CLK_PERIOD/2;
      clk <= '1'; wait for CLK_PERIOD/2;
    end loop;
  end process;

  -- stimulus: load images, pulse frame_valid, print debug snapshots
  stim_proc: process
    -- flat image buffer
    variable img : std_logic_vector(8*256-1 downto 0);

    -- byte array type for MNIST image
    type byte_array_t is array (0 to 255) of std_logic_vector(7 downto 0);

    -- example images (shortened in this snippet; use your data)
    constant img_digit2 : byte_array_t := (
--      others => x"00"
          0 => x"00", 1 => x"00", 2 => x"00", 3 => x"00", 4 => x"00", 5 => x"00", 6 => x"00", 7 => x"06", 8 => x"04", 9 => x"00", 10 => x"00", 
          11 => x"00", 12 => x"00", 13 => x"00", 14 => x"00", 15 => x"00", 16 => x"00", 17 => x"00", 18 => x"00", 19 => x"00", 20 => x"00", 
          21 => x"00", 22 => x"0D", 23 => x"79", 24 => x"49", 25 => x"00", 26 => x"00", 27 => x"00", 28 => x"00", 29 => x"00", 30 => x"00", 
          31 => x"00", 32 => x"00", 33 => x"00", 34 => x"00", 35 => x"00", 36 => x"00", 37 => x"01", 38 => x"58", 39 => x"C0", 40 => x"2E", 
          41 => x"00", 42 => x"00", 43 => x"00", 44 => x"00", 45 => x"00", 46 => x"00", 47 => x"00", 48 => x"00", 49 => x"00", 50 => x"00", 
          51 => x"00", 52 => x"00", 53 => x"0C", 54 => x"B4", 55 => x"94", 56 => x"0C", 57 => x"00", 58 => x"00", 59 => x"00", 60 => x"00", 
          61 => x"00", 62 => x"00", 63 => x"00", 64 => x"00", 65 => x"00", 66 => x"00", 67 => x"00", 68 => x"00", 69 => x"24", 70 => x"D2", 
          71 => x"6A", 72 => x"03", 73 => x"00", 74 => x"00", 75 => x"00", 76 => x"00", 77 => x"00", 78 => x"00", 79 => x"00", 80 => x"00", 
          81 => x"00", 82 => x"00", 83 => x"00", 84 => x"02", 85 => x"5C", 86 => x"D4", 87 => x"24", 88 => x"00", 89 => x"00", 90 => x"00", 
          91 => x"00", 92 => x"00", 93 => x"00", 94 => x"00", 95 => x"00", 96 => x"00", 97 => x"00", 98 => x"00", 99 => x"00", 100 => x"04", 
          101 => x"7C", 102 => x"C0", 103 => x"0A", 104 => x"03", 105 => x"1D", 106 => x"43", 107 => x"44", 108 => x"12", 109 => x"00", 110 => x"00", 
          111 => x"00", 112 => x"00", 113 => x"00", 114 => x"00", 115 => x"00", 116 => x"05", 117 => x"8C", 118 => x"96", 119 => x"15", 120 => x"57", 
          121 => x"C1", 122 => x"E1", 123 => x"D9", 124 => x"94", 125 => x"11", 126 => x"00", 127 => x"00", 128 => x"00", 129 => x"00", 130 => x"00", 
          131 => x"00", 132 => x"08", 133 => x"AD", 134 => x"8E", 135 => x"79", 136 => x"C9", 137 => x"96", 138 => x"4E", 139 => x"4F", 140 => x"BA", 
          141 => x"27", 142 => x"00", 143 => x"00", 144 => x"00", 145 => x"00", 146 => x"00", 147 => x"00", 148 => x"08", 149 => x"B1", 150 => x"CF", 
          151 => x"D8", 152 => x"64", 153 => x"09", 154 => x"00", 155 => x"2A", 156 => x"B6", 157 => x"29", 158 => x"00", 159 => x"00", 160 => x"00", 
          161 => x"00", 162 => x"00", 163 => x"00", 164 => x"05", 165 => x"80", 166 => x"FB", 167 => x"9F", 168 => x"14", 169 => x"0A", 170 => x"4D", 
          171 => x"A4", 172 => x"80", 173 => x"10", 174 => x"00", 175 => x"00", 176 => x"00", 177 => x"00", 178 => x"00", 179 => x"00", 180 => x"01", 
          181 => x"24", 182 => x"BC", 183 => x"D1", 184 => x"A1", 185 => x"A2", 186 => x"C8", 187 => x"6A", 188 => x"0F", 189 => x"00", 190 => x"00", 
          191 => x"00", 192 => x"00", 193 => x"00", 194 => x"00", 195 => x"00", 196 => x"00", 197 => x"01", 198 => x"29", 199 => x"79", 200 => x"92", 
          201 => x"82", 202 => x"3D", 203 => x"0A", 204 => x"00", 205 => x"00", 206 => x"00", 207 => x"00", 208 => x"00", 209 => x"00", 210 => x"00", 
          211 => x"00", 212 => x"00", 213 => x"00", 214 => x"00", 215 => x"00", 216 => x"00", 217 => x"00", 218 => x"00", 219 => x"00", 220 => x"00", 
          221 => x"00", 222 => x"00", 223 => x"00", 224 => x"00", 225 => x"00", 226 => x"00", 227 => x"00", 228 => x"00", 229 => x"00", 230 => x"00", 
          231 => x"00", 232 => x"00", 233 => x"00", 234 => x"00", 235 => x"00", 236 => x"00", 237 => x"00", 238 => x"00", 239 => x"00", 240 => x"00", 
          241 => x"00", 242 => x"00", 243 => x"00", 244 => x"00", 245 => x"00", 246 => x"00", 247 => x"00", 248 => x"00", 249 => x"00", 250 => x"00", 
          251 => x"00", 252 => x"00", 253 => x"00", 254 => x"00", 255 => x"00"   
    );

    constant img_digit3 : byte_array_t := (
--      others => x"00"
          0 => x"00", 1 => x"00", 2 => x"00", 3 => x"00", 4 => x"00", 5 => x"00", 6 => x"00", 7 => x"00", 8 => x"00", 9 => x"00", 10 => x"00", 
          11 => x"00", 12 => x"00", 13 => x"00", 14 => x"00", 15 => x"00", 16 => x"00", 17 => x"00", 18 => x"00", 19 => x"00", 20 => x"00", 
          21 => x"00", 22 => x"00", 23 => x"00", 24 => x"00", 25 => x"00", 26 => x"00", 27 => x"00", 28 => x"00", 29 => x"00", 30 => x"00", 
          31 => x"00", 32 => x"00", 33 => x"00", 34 => x"00", 35 => x"00", 36 => x"00", 37 => x"00", 38 => x"01", 39 => x"06", 40 => x"07", 
          41 => x"06", 42 => x"01", 43 => x"00", 44 => x"00", 45 => x"00", 46 => x"00", 47 => x"00", 48 => x"00", 49 => x"00", 50 => x"00", 
          51 => x"00", 52 => x"00", 53 => x"06", 54 => x"52", 55 => x"98", 56 => x"A1", 57 => x"99", 58 => x"52", 59 => x"11", 60 => x"01", 
          61 => x"00", 62 => x"00", 63 => x"00", 64 => x"00", 65 => x"00", 66 => x"00", 67 => x"00", 68 => x"00", 69 => x"32", 70 => x"DD", 
          71 => x"FB", 72 => x"FD", 73 => x"FB", 74 => x"E3", 75 => x"8D", 76 => x"20", 77 => x"00", 78 => x"00", 79 => x"00", 80 => x"00", 
          81 => x"00", 82 => x"00", 83 => x"00", 84 => x"00", 85 => x"3C", 86 => x"F0", 87 => x"FC", 88 => x"EE", 89 => x"C7", 90 => x"C1", 
          91 => x"F3", 92 => x"91", 93 => x"09", 94 => x"00", 95 => x"00", 96 => x"00", 97 => x"00", 98 => x"00", 99 => x"00", 100 => x"00", 
          101 => x"07", 102 => x"5D", 103 => x"6C", 104 => x"42", 105 => x"34", 106 => x"A4", 107 => x"FA", 108 => x"E4", 109 => x"2B", 110 => x"00", 
          111 => x"00", 112 => x"00", 113 => x"00", 114 => x"00", 115 => x"00", 116 => x"00", 117 => x"02", 118 => x"66", 119 => x"A4", 120 => x"A5", 
          121 => x"C7", 122 => x"FA", 123 => x"FB", 124 => x"C5", 125 => x"1E", 126 => x"00", 127 => x"00", 128 => x"00", 129 => x"03", 130 => x"05", 
          131 => x"00", 132 => x"00", 133 => x"04", 134 => x"A2", 135 => x"FB", 136 => x"FD", 137 => x"FD", 138 => x"FB", 139 => x"CC", 140 => x"4B", 
          141 => x"03", 142 => x"00", 143 => x"00", 144 => x"00", 145 => x"35", 146 => x"80", 147 => x"2A", 148 => x"06", 149 => x"04", 150 => x"4E", 
          151 => x"AE", 152 => x"B9", 153 => x"CF", 154 => x"F8", 155 => x"9A", 156 => x"13", 157 => x"00", 158 => x"00", 159 => x"00", 160 => x"00", 
          161 => x"41", 162 => x"F6", 163 => x"DE", 164 => x"BD", 165 => x"BA", 166 => x"9E", 167 => x"8D", 168 => x"8F", 169 => x"C9", 170 => x"FD", 
          171 => x"DB", 172 => x"2B", 173 => x"00", 174 => x"00", 175 => x"00", 176 => x"00", 177 => x"14", 178 => x"87", 179 => x"D7", 180 => x"ED", 
          181 => x"F3", 182 => x"F8", 183 => x"F1", 184 => x"F1", 185 => x"F6", 186 => x"E9", 187 => x"9A", 188 => x"16", 189 => x"00", 190 => x"00", 
          191 => x"00", 192 => x"00", 193 => x"00", 194 => x"0C", 195 => x"32", 196 => x"59", 197 => x"71", 198 => x"93", 199 => x"76", 200 => x"77", 
          201 => x"7F", 202 => x"4F", 203 => x"19", 204 => x"01", 205 => x"00", 206 => x"00", 207 => x"00", 208 => x"00", 209 => x"00", 210 => x"00", 
          211 => x"00", 212 => x"00", 213 => x"01", 214 => x"05", 215 => x"01", 216 => x"01", 217 => x"02", 218 => x"00", 219 => x"00", 220 => x"00", 
          221 => x"00", 222 => x"00", 223 => x"00", 224 => x"00", 225 => x"00", 226 => x"00", 227 => x"00", 228 => x"00", 229 => x"00", 230 => x"00", 
          231 => x"00", 232 => x"00", 233 => x"00", 234 => x"00", 235 => x"00", 236 => x"00", 237 => x"00", 238 => x"00", 239 => x"00", 240 => x"00", 
          241 => x"00", 242 => x"00", 243 => x"00", 244 => x"00", 245 => x"00", 246 => x"00", 247 => x"00", 248 => x"00", 249 => x"00", 250 => x"00", 
          251 => x"00", 252 => x"00", 253 => x"00", 254 => x"00", 255 => x"00"   
    );

    -- local loop index
    variable i : integer;
    variable j : integer;
  begin
    -- reset
    rst <= '1';
    wait for 50 ns;
    rst <= '0';
    wait for CLK_PERIOD;

    -- --- send digit 2 ---
    -- pack the 256 bytes into frame_data
    for i in 0 to 255 loop
      img((i+1)*8-1 downto i*8) := img_digit2(i);
    end loop;
    frame_data <= img;

    -- pulse frame_valid for a few clocks
    frame_valid <= '1';
    wait for 10*CLK_PERIOD;
    frame_valid <= '0';

    -- wait for the DUT to process and assert result_valid
    wait until result_valid = '1';
    report "Predicted digit (digit 2): " & integer'image(to_integer(unsigned(digit_out)));

    -- print some debug info: pixels[0..15], input spikes[0..15], hidden inputs[0..7], output inputs[0..4]
    for j in 0 to 15 loop
      report "pixel(" & integer'image(j) & ") = " &
             integer'image(to_integer(unsigned(dbg_frame_pixels((j+1)*8-1 downto j*8))));
    end loop;
    for j in 0 to 15 loop
      report "dbg_input_spike(" & integer'image(j) & ") = " & std_logic'image(dbg_input_spikes(j));
    end loop;
    for j in 0 to 7 loop
      report "hidden_input(" & integer'image(j) & ") = " & integer'image(dbg_hidden_inputs(j));
    end loop;
    for j in 0 to 4 loop
      report "output_input(" & integer'image(j) & ") = " & integer'image(dbg_output_inputs(j));
    end loop;

    wait for 1000 us;

    -- --- send digit 3 ---
    for i in 0 to 255 loop
      img((i+1)*8-1 downto i*8) := img_digit3(i);
    end loop;
    frame_data <= img;

    frame_valid <= '1';
    wait for 10*CLK_PERIOD;
    frame_valid <= '0';

    wait until result_valid = '1';
    report "Predicted digit (digit 3): " & integer'image(to_integer(unsigned(digit_out)));

    -- print a few debug values again
    for j in 0 to 15 loop
      report "pixel(" & integer'image(j) & ") = " &
             integer'image(to_integer(unsigned(dbg_frame_pixels((j+1)*8-1 downto j*8))));
    end loop;
    for j in 0 to 15 loop
      report "dbg_input_spike(" & integer'image(j) & ") = " & std_logic'image(dbg_input_spikes(j));
    end loop;
    for j in 0 to 7 loop
      report "hidden_input(" & integer'image(j) & ") = " & integer'image(dbg_hidden_inputs(j));
    end loop;
    for j in 0 to 4 loop
      report "output_input(" & integer'image(j) & ") = " & integer'image(dbg_output_inputs(j));
    end loop;

    wait;
  end process;
end architecture;
