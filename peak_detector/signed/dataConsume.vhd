library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.common_pack.all;

ENTITY dataConsume IS
  port(
    clk:        in std_logic;
    reset:      in std_logic;
    start:      in std_logic;
    numWords_bcd: in BCD_ARRAY_TYPE(2 downto 0);
    data:       in std_logic_vector(7 downto 0);
    ctrlIn:     in std_logic;
    ctrlOut:    out std_logic;
    dataReady:  out std_logic;
    seqDone:    out std_logic;
    byte:       out std_logic_vector(7 downto 0);
    maxIndex:   out BCD_ARRAY_TYPE(2 downto 0);
    dataResults: out CHAR_ARRAY_TYPE(0 to 6)
  );
END dataConsume;

architecture Behavioral of dataConsume is
  type state_type is (S0, S1, S2, S3);
  type signed_array is array (integer range <>) of signed(7 downto 0);

  signal curr_state, next_state: state_type;
  signal prev_ctrlIn, ctrlOut_state: std_logic := '0';
  signal edge_detected_ctrlIn: std_logic := '0';

  signal BCD2int_enable: boolean := FALSE;
  signal numWords_int: integer := 0;
  signal counter: integer := 0;

  signal current_value: signed(7 downto 0) := (others => '0');
  signal peak_value: signed(7 downto 0) := (others => '0');
  signal compare_enable: boolean := FALSE;
  signal peak_index: integer := 0;
  signal peak_found: integer := 0;
  signal currentBytes: signed_array(0 to 6) := (others => (others => '0'));
  signal lastThreeBytes: signed_array(0 to 2) := (others => (others => '0'));

  signal max_index_bcd_enable: boolean := FALSE;
  signal max_index_bcd: BCD_ARRAY_TYPE(2 downto 0); 
  signal store_data_result_enable: boolean := FALSE;

begin

  ctrlIn_edge_detect: process(clk)
  begin
    if rising_edge(clk) then
      edge_detected_ctrlIn <= ctrlIn XOR prev_ctrlIn;
      prev_ctrlIn <= ctrlIn;
    end if;
  end process;

  ctrlOut_toggle: process(clk, reset)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        ctrlOut_state <= '0';
      elsif start = '1' or edge_detected_ctrlIn = '1' then
        ctrlOut_state <= not ctrlOut_state;
      end if;
    end if;
    ctrlOut <= ctrlOut_state;
  end process;

  ByteOutput: process(clk)
  begin
    if rising_edge(clk) then
      byte <= data;
    end if;
  end process;

  StateMachine: process(clk, reset)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        curr_state <= S0;
      else
        curr_state <= next_state;
      end if;
    end if;
  end process;

  NextState: process(curr_state, start, edge_detected_ctrlIn)
  begin
    case curr_state is
      when S0 =>
        dataReady <= '0';
        seqDone <= '0';
        counter <= 0;
        current_value <= (others => '0');
        peak_value <= (others => '0');
        peak_index <= 0;
        peak_found <= 0;
        currentBytes <= (others => (others => '0'));
        lastThreeBytes <= (others => (others => '0'));
        numWords_int <= 0;
        
        
        if start = '1' then
          numWords_int <= to_integer(unsigned(numWords_bcd(2))) * 100 +
                          to_integer(unsigned(numWords_bcd(1))) * 10 + 
                          to_integer(unsigned(numWords_bcd(0))); 

          next_state <= S1;
        else
          next_state <= S0;
        end if;

      when S1 =>
        dataReady <= '0';
        if edge_detected_ctrlIn = '1' then
          current_value <= signed(data);
          counter <= counter + 1;
          dataReady <= '1';

          if peak_found > 0 then
            case peak_found is
                when 3 =>
                    currentBytes(4) <= current_value;
                when 2 =>
                    currentBytes(5) <= current_value;
                when 1 =>
                    currentBytes(6) <= current_value;
                when others =>
                    null;
            end case;
            peak_found <= peak_found - 1;
          end if;
          if counter = 0 or current_value > peak_value then
              peak_value <= current_value;
              peak_index <= counter;

              currentBytes(0) <= lastThreeBytes(0);
              currentBytes(1) <= lastThreeBytes(1);
              currentBytes(2) <= lastThreeBytes(2);
              currentBytes(3) <= current_value;

              currentBytes(4) <= (others => '0');
              currentBytes(5) <= (others => '0');
              currentBytes(6) <= (others => '0');
              peak_found <= 3;
          end if;
          lastThreeBytes(0) <= lastThreeBytes(1);
          lastThreeBytes(1) <= lastThreeBytes(2);
          lastThreeBytes(2) <= current_value;

          next_state <= S2;
        else
          next_state <= S1;
        end if;

      when S2 =>
        
        if counter >= numWords_int then
          dataReady <= '0';
          next_state <= S3;
        else
          next_state <= S1;
        end if;

      when S3 =>
        dataReady <= '0';
        seqDone <= '1';

        dataResults(0) <= std_logic_vector(currentBytes(0));
        dataResults(1) <= std_logic_vector(currentBytes(1));
        dataResults(2) <= std_logic_vector(currentBytes(2));
        dataResults(3) <= std_logic_vector(currentBytes(3)); -- peak
        dataResults(4) <= std_logic_vector(currentBytes(4));
        dataResults(5) <= std_logic_vector(currentBytes(5));
        dataResults(6) <= std_logic_vector(currentBytes(6));

        maxIndex(0) <= std_logic_vector(to_unsigned(peak_index mod 10, 4));
        maxIndex(1) <= std_logic_vector(to_unsigned((peak_index / 10) mod 10, 4));
        maxIndex(2) <= std_logic_vector(to_unsigned((peak_index / 100) mod 10, 4));
      

        next_state <= S0;
      when others =>
        next_state <= S0;
    end case;
  end process;

end Behavioral;