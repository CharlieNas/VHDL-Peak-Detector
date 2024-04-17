library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
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
  -- Declaring types
  type state_type is (IDLE, PROCESS_DATA, WAIT_CMDP, CHECK_COMPLETE);
  type signed_array is array (integer range <>) of signed(7 downto 0);

  -- signals for state machine and two phase control
  signal curr_state, next_state: state_type;
  signal prev_ctrlIn, ctrlOut_state: std_logic := '0';
  signal edge_detected_ctrlIn: std_logic := '0';

  signal en_count, reset_count: boolean := TRUE;
  signal en_bcd_to_int: boolean := FALSE;

  -- signals to keep of fetched data
  signal numWords_int: integer := 0;
  signal counter: integer := 0;

  -- signals for the peak detection algorithm
  signal peak_value: signed(7 downto 0) := (others => '0');
  signal update_next_values: integer := 0;
  signal lastThreeBytes: signed_array(0 to 2) := (others => (others => '0'));

begin
  -- Detecting edge on ctrlIn
  edge_detected_ctrlIn <= ctrlIn XOR prev_ctrlIn;
  
  ---------------------------
  --  Edge detection
  --  store previous value of ctrlIn to detect edge 
  ---------------------------
  CtrlInEdgeDetect: process(clk)
  begin
    if rising_edge(clk) then
      prev_ctrlIn <= ctrlIn;
    end if;
  end process;

  ---------------------------
  --  Toggle control output
  -- CtrlOut is toggled when the program start
  -- or when the system is in the CHECK_COMPLETE state and more data is expected.
  ---------------------------
  CtrlOutToggle: process(clk, reset)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        ctrlOut_state <= '0';
      elsif (curr_state = IDLE and start = '1') or (curr_state = CHECK_COMPLETE and counter < numWords_int) then
        ctrlOut_state <= not ctrlOut_state;
      end if;
    end if;
    ctrlOut <= ctrlOut_state;
  end process;

  ----------------------------
  --  Byte output
  --  keep sending the bytes we read to the command processor
  ---------------------------
  ByteOutput: process(clk)
  begin
    if rising_edge(clk) then
      byte <= data;
    end if;
  end process;

  UpdateCounter: process(clk)
  begin
   if rising_edge(clk) then
      if reset_count = TRUE then
        counter <= 0;
      elsif en_count = TRUE then
        counter <= counter + 1;
      end if;
    end if;
  end process; 


  BCDtoINT: process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        numWords_int <= 0;
      elsif en_bcd_to_int = TRUE then
        numWords_int <= to_integer(unsigned(numWords_bcd(2))) * 100 +
                        to_integer(unsigned(numWords_bcd(1))) * 10 + 
                        to_integer(unsigned(numWords_bcd(0))); 
      end if;
    end if;
  end process;

  --------------------------------
  --  State Machine Transitions
  --------------------------------
  StateMachine: process(clk, reset)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        curr_state <= IDLE;
      else
        curr_state <= next_state;
      end if;
    end if;
  end process;

  combi_next: process(curr_state, start, edge_detected_ctrlIn)
  begin
    case curr_state is
      -- Reset and check for start from command processor
      when IDLE => 
        if start = '1' then
          next_state <= PROCESS_DATA;
        else
          next_state <= IDLE;
        end if;

      -- Processing coming bytes finding peak and storing values in DataResults
      when PROCESS_DATA => 
        if edge_detected_ctrlIn = '1' then
          next_state <= WAIT_CMDP;
        else
          next_state <= PROCESS_DATA;
        end if;

      -- Waiting for start from command processor or first run through  
      when WAIT_CMDP =>
        if start = '1' or counter = 1 then
            next_state <= CHECK_COMPLETE;
        else 
            next_state <= WAIT_CMDP;
        end if;
      
      -- Check if should do another byte or stop  
      when CHECK_COMPLETE =>
        if counter < numWords_int then
            next_state <= PROCESS_DATA;
        else
          next_state <= IDLE;
        end if;
      
      when others =>
        next_state <= IDLE;
    end case;
  end process;

  combi_out: process(curr_state, start, edge_detected_ctrlIn)
  begin
    en_count <= FALSE;
    reset_count <= FALSE;
    en_bcd_to_int <= FALSE;
    dataReady <= '0';
    seqDone <= '0';
    case curr_state is
      when IDLE => 
        reset_count <= TRUE;
        peak_value <= (others => '0');
        update_next_values <= 0;
        lastThreeBytes <= (others => (others => '0'));
        
        if start = '1' then
          en_bcd_to_int <= TRUE;
        end if;

      -- Processing coming bytes finding peak and storing values in DataResults
      when PROCESS_DATA => 
        if edge_detected_ctrlIn = '1' then
          en_count <= TRUE;
         
          -- 1. Update dataResults with next three values if the peak was recently found.
          --    We use update_next_values to keep track of how many values we have stored after the peak
          if update_next_values > 0 then
            case update_next_values is
                when 3 =>
                    dataResults(2) <= std_logic_vector(signed(data));
                when 2 =>
                    dataResults(1) <= std_logic_vector(signed(data));
                when 1 =>
                    dataResults(0) <= std_logic_vector(signed(data));
                when others =>
                    null;
            end case;
            update_next_values <= update_next_values - 1;
          end if;
          
          -- 2. Peak detection.
          --    If it's the first byte or the current byte is greater than past peak value
          if counter = 0 or signed(data) > peak_value then
              peak_value <= signed(data);

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
              
              -- Update update_next_values to indicate that we need to store the next three values
              -- in the following iterations
              update_next_values <= 3;
          end if;

          -- 3. Always keep track of the last three bytes to store them in the dataResults
          -- when the peak is found
          lastThreeBytes(2) <= lastThreeBytes(1);
          lastThreeBytes(1) <= lastThreeBytes(0);
          lastThreeBytes(0) <= signed(data);
        end if;
      
      -- Check if should do another byte or stop  
      when CHECK_COMPLETE =>
        dataReady <= '1';
        -- If we haven't reached the number of words we need to process, keep going
        if counter >= numWords_int then
          seqDone <= '1';
        end if;
      when others =>
        null;
    end case;
  end process;

end Behavioral;