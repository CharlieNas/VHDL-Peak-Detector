library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.common_pack.all;

entity dataConsume is
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
end dataConsume;

architecture Behavioral of dataConsume is
  type state_type is (S0, S1, S2, S3);
  type signed_array is array (integer range <>) of signed(7 downto 0);

  signal curr_state, next_state: state_type;
  signal prev_ctrlIn, ctrlOut_state: std_logic := '0';
  signal edge_detected_ctrlIn: std_logic := '0';

  signal numWords_int: integer := 0;
  signal counter: integer := 0;

  signal peak_value: signed(7 downto 0) := (others => '0');
  signal peak_index: integer := 0;
  signal peak_found: integer := 0;
  signal lastThreeBytes: signed_array(0 to 2) := (others => (others => '0'));

begin
  edge_detected_ctrlIn <= ctrlIn XOR prev_ctrlIn;
  
  CtrlInEdgeDetect: process(clk)
  begin
    if rising_edge(clk) then
      prev_ctrlIn <= ctrlIn;
    end if;
  end process;

  CtrlOutToggle: process(clk, reset)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        ctrlOut_state <= '0';
      elsif (curr_state = S0 and start = '1') or (curr_state = S3 and counter < numWords_int) then
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
      when S0 => -- Reset and check for start from command processor
        counter <= 0;
        peak_value <= (others => '0');
        peak_index <= 0;
        peak_found <= 0;
        dataReady <= '0';
        seqDone <= '0';
        lastThreeBytes <= (others => (others => '0'));
        numWords_int <= 0;
        
        if start = '1' then
          -- Convert number of words from BCD to integer
          numWords_int <= to_integer(unsigned(numWords_bcd(2))) * 100 +
                          to_integer(unsigned(numWords_bcd(1))) * 10 + 
                          to_integer(unsigned(numWords_bcd(0))); 

          next_state <= S1;
        else
          next_state <= S0;
        end if;

      when S1 => -- Wait for data Gen to send byte and fill peaks/dataResults. . .
        if edge_detected_ctrlIn = '1' then
          dataReady <= '0';
          seqDone <= '0';
          counter <= counter + 1;
         
          -- 1. Update dataResults with next three values if the peak was recently found
          -- We use peak_found to keep track of how many values we have stored after the peak
          if peak_found > 0 then
            case peak_found is
                when 3 =>
                    dataResults(2) <= std_logic_vector(signed(data));
                when 2 =>
                    dataResults(1) <= std_logic_vector(signed(data));
                when 1 =>
                    dataResults(0) <= std_logic_vector(signed(data));
                when others =>
                    null;
            end case;
            peak_found <= peak_found - 1;
          end if;
          
          -- 2. PeakDetection Process
          -- If it's the first byte or the current byte is greater than the current peak
          if counter = 0 or signed(data) > peak_value then
              peak_value <= signed(data);
              peak_index <= counter;

              -- Update max index which in this case would be the same number as the counter
              maxIndex(0) <= std_logic_vector(to_unsigned(counter mod 10, 4));
              maxIndex(1) <= std_logic_vector(to_unsigned((counter / 10) mod 10, 4));
              maxIndex(2) <= std_logic_vector(to_unsigned((counter / 100) mod 10, 4));

              -- Update the values before the peak
              dataResults(6) <= std_logic_vector(lastThreeBytes(2));
              dataResults(5) <= std_logic_vector(lastThreeBytes(1));
              dataResults(4) <= std_logic_vector(lastThreeBytes(0));
              -- Update the peak value
              dataResults(3) <= std_logic_vector(signed(data));
              -- Reset values after the peak
              dataResults(2) <= (others => '0');
              dataResults(1) <= (others => '0');
              dataResults(0) <= (others => '0');
              
              -- Update the peak found counter to indicate that we need to store the next three values
              -- in the following iterations
              peak_found <= 3;
              
          end if;

          -- 3. Always keep track of the last three bytes to store them in the dataResults
          --    when the peak is found
          lastThreeBytes(2) <= lastThreeBytes(1);
          lastThreeBytes(1) <= lastThreeBytes(0);
          lastThreeBytes(0) <= signed(data);
          
          next_state <= S2;
        else
          next_state <= S1;
        end if;

      when S2 => -- Waiting for start from command processor or first run through
        if start = '1' or counter = 1 then
            next_state <= S3;
        else 
            next_state <= S2;
        end if;

      when S3 => -- Check if should do another byte or stop
        dataReady <= '1';
        if counter < numWords_int then
            next_state <= S1;
        else
          seqDone <= '1';
          next_state <= S0;
        end if;
        
      when others =>
        next_state <= S0;
    end case;
  end process;

end Behavioral;