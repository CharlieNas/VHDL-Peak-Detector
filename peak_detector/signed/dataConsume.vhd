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
  
  signal curr_state, next_state: state_type := S0;
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
  signal max_index_bcd: BCD_ARRAY_TYPE(2 downto 0) := (others => (others => '0'));
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
      if start = '1' or edge_detected_ctrlIn = '1' then
        ctrlOut_state <= not ctrlOut_state;
      end if;
    end if;
    ctrlOut <= ctrlOut_state;
  end process;

  BCDToInteger: process(clk, BCD2int_enable, numWords_bcd)
  begin
    if BCD2int_enable then
      numWords_int <= to_integer(unsigned(numWords_bcd(2))) * 100 +
                      to_integer(unsigned(numWords_bcd(1))) * 10 + 
                      to_integer(unsigned(numWords_bcd(0))); 
    end if;
  end process;

  MaxIndexBCD: process(clk)
  begin
    if rising_edge(clk) and max_index_bcd_enable then
      max_index_bcd(0)(3 downto 0) <= std_logic_vector(to_unsigned(peak_index mod 10, 4));
      max_index_bcd(1)(3 downto 0) <= std_logic_vector(to_unsigned((peak_index / 10) mod 10, 4));
      max_index_bcd(2)(3 downto 0) <= std_logic_vector(to_unsigned((peak_index / 100) mod 10, 4));
    end if;
  end process;

  StoreInDataResult: process(clk)
  begin
    if store_data_result_enable then
      dataResults(0) <= std_logic_vector(currentBytes(0));
      dataResults(1) <= std_logic_vector(currentBytes(1));
      dataResults(2) <= std_logic_vector(currentBytes(2));
      dataResults(3) <= std_logic_vector(currentBytes(3)); -- peak
      dataResults(4) <= std_logic_vector(currentBytes(4));
      dataResults(5) <= std_logic_vector(currentBytes(5));
      dataResults(6) <= std_logic_vector(currentBytes(6));
    end if;
  end process;

  PeakDetection: process(clk)
  begin
      if rising_edge(clk) then
          if compare_enable then
              report "COMPARING PEAK DETECTOR" severity note;
              -- 1. Update buffer with next three values if peak was recent
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

              -- 2. PeakDetection Process
              -- If it's the first byte or the current byte is greater than the current peak
              if counter = 0 or current_value > peak_value then
                  peak_value <= current_value;
                  peak_index <= counter;

                  -- Update the buffer for the values before the peak
                  currentBytes(0) <= lastThreeBytes(0);
                  currentBytes(1) <= lastThreeBytes(1);
                  currentBytes(2) <= lastThreeBytes(2);
                  currentBytes(3) <= current_value; -- Peak in the middle

                  -- Reset the next three values of the buffer as placeholders for potential future peaks
                  currentBytes(4) <= (others => '0');
                  currentBytes(5) <= (others => '0');
                  currentBytes(6) <= (others => '0');
                  peak_found <= 3; -- Ready to track the next three bytes post-peak
              end if;

              -- 3. Always keep track of last three bytes
              -- Shift lastThreeBytes to make room for the new byte
              lastThreeBytes(0) <= lastThreeBytes(1);
              lastThreeBytes(1) <= lastThreeBytes(2);
              lastThreeBytes(2) <= current_value;
          
          end if;
      end if;
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
        prev_ctrlIn <= '0';
        ctrlOut_state <= '0'; -- reseting output signal
        edge_detected_ctrlIn <= '0';
        -- Resetting internal signals to their initial values
        BCD2int_enable <= FALSE;
        numWords_int <= 0;
        counter <= 0;
        current_value <= (others => '0');
        peak_value <= (others => '0');
        compare_enable <= FALSE;
        peak_index <= 0;
        peak_found <= 0;
        currentBytes <= (others => (others => '0'));
        lastThreeBytes <= (others => (others => '0'));
        max_index_bcd_enable <= FALSE;
        -- max_index_bcd <= (others => (others => '0'));
        -- Note: Might not want to reset max_index_bcd here 
        store_data_result_enable <= FALSE;
        -- Resetting output signals
        seqDone <= '0';
        dataReady <= '0';
      else
        curr_state <= next_state;
      end if;
    end if;
  end process;

  NextState: process(curr_state, start, edge_detected_ctrlIn)
  begin
    case curr_state is
      when S0 =>
--        prev_ctrlIn <= '0';
--        ctrlOut_state <= '0'; -- reseting output signal
--        edge_detected_ctrlIn <= '0';
--        -- Resetting internal signals to their initial values
--        numWords_int <= 0;
--        counter <= 0;
--        current_value <= (others => '0');
--        peak_value <= (others => '0');
--        compare_enable <= FALSE;
--        peak_index <= 0;
--        peak_found <= 0;
--        currentBytes <= (others => (others => '0'));
--        lastThreeBytes <= (others => (others => '0'));
--        max_index_bcd_enable <= FALSE;
--        -- max_index_bcd <= (others => (others => '0'));
--        -- Note: Might not want to reset max_index_bcd here 
--        store_data_result_enable <= FALSE;
--        -- Resetting output signals
--        seqDone <= '0';
--        dataReady <= '0'; 
      
        if start = '1' then
          BCD2int_enable <= TRUE;
          next_state <= S1;
        else
          next_state <= S0;
        end if;

      when S1 =>
        if edge_detected_ctrlIn = '1' then
          report "CONTROL IN FLIPPED" severity note;
          current_value <= signed(data);
          counter <= counter + 1;
          compare_enable <= TRUE;
          next_state <= S2;
        else
          next_state <= S1;
        end if;

      when S2 =>
        report "STATE S2, Counter: " & integer'image(counter) & " NumWords_Int: " & integer'image(numWords_int) severity note;
        if counter = numWords_int then
          report "COUNTER === NUMBER OF WORDS" severity note;
          compare_enable <= FALSE;
          max_index_bcd_enable <= TRUE;
          next_state <= S3;
        else
          next_state <= S1;
        end if;

      when S3 =>
        report "STATE S3" severity note;
        
        store_data_result_enable <= TRUE;
        maxIndex <= max_index_bcd;
        seqDone <= '1';
        next_state <= S0;

      when others =>
        next_state <= S0;
    end case;
  end process;

end Behavioral;