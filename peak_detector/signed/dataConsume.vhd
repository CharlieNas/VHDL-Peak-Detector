library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.common_pack.all;

entity dataConsume is
  port(
    clk:          in std_logic;
    reset:        in std_logic;
    start:        in std_logic;
    numWords_bcd: in BCD_ARRAY_TYPE(2 downto 0);
    data:         in std_logic_vector(7 downto 0);
    ctrlIn:       in std_logic;
    ctrlOut:      out std_logic;
    dataReady:    out std_logic;
    seqDone:      out std_logic;
    byte:         out std_logic_vector(7 downto 0);
    maxIndex:     out BCD_ARRAY_TYPE(2 downto 0);
    dataResults:  out CHAR_ARRAY_TYPE(0 to 6)
  );
end dataConsume;

--------------------------------------------------------- SIGNAL DECLARATION ---------------------------------------------------------
architecture Behavioral of dataConsume is
  -- define custom types for use within architecture
  type state_type is (IDLE, PROCESS_DATA, WAIT_CMDP, CHECK_COMPLETE);
  type signed_array is array (integer range <>) of signed(7 downto 0);
  -- signals for managing state transitions
  signal curr_state, next_state: state_type;
  -- signals for two phase protocol logic
  signal prev_ctrlIn, ctrlOut_state: std_logic := '0';
  signal edge_detected_ctrlIn: std_logic := '0';
  -- signals for counter and numWords as integer
  signal numWords_int: integer := 0;
  signal counter: integer := 0;
  -- signals for the peak detection algorithm
  signal peak_value: signed(7 downto 0) := (others => '0');
  signal lastThreeBytes: signed_array(0 to 2) := (others => (others => '0'));
  signal update_next_values: integer := 0;
  -- enable signals and counter reset
  signal en_counter: boolean := FALSE;
  signal en_bcd_to_int: boolean := FALSE;
  signal en_peak_detection: boolean := FALSE;
  signal en_data: boolean := FALSE;
  signal en_reset: boolean := TRUE;

begin
  --------------------------------------------------------- STATE MACHINE ---------------------------------------------------------
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

  --------------------------------------
  --  Next State Logic
  --------------------------------------
  combi_next: process(curr_state, start, edge_detected_ctrlIn, counter, numWords_int)
  begin
    case curr_state is
      when IDLE => -- Remain idle until start signal goes high, synchronising us with command processor
        if start = '1' then
          next_state <= PROCESS_DATA;
        else
          next_state <= IDLE;
        end if;

      when PROCESS_DATA => -- Processing incoming bytes, finding peak and storing values in DataResults
        if edge_detected_ctrlIn = '1' then
          next_state <= WAIT_CMDP;
        else
          next_state <= PROCESS_DATA;
        end if;

      when WAIT_CMDP => -- Waiting for start from command processor or first run through
        if start = '1' or counter = 1 then
            next_state <= CHECK_COMPLETE;
        else 
            next_state <= WAIT_CMDP;
        end if;
       
      when CHECK_COMPLETE => -- If we haven't reached the number of words we need to process, keep processing
        if counter < numWords_int then
            next_state <= PROCESS_DATA;
        else
          next_state <= IDLE;
        end if;
      
      when others =>
        next_state <= IDLE;
    end case;
  end process;
  
  --------------------------------------
  --  Combinatorial logic for state machine outputs
  --------------------------------------
  combi_out: process(curr_state, start, edge_detected_ctrlIn, counter, numWords_int)
  begin
    -- Reset signals to avoid latches
    en_reset <= FALSE;
    en_bcd_to_int <= FALSE;
    en_counter <= FALSE;
    en_peak_detection <= FALSE;
    en_data <= FALSE;
    dataReady <= '0';
    seqDone <= '0';
    
    case curr_state is
      when IDLE =>  
        en_reset <= TRUE; -- reset signals, fixing bug for board reset button
        if start = '1' then
          en_bcd_to_int <= TRUE; -- BCDtoINT process
        end if;

      when PROCESS_DATA => 
        if edge_detected_ctrlIn = '1' then
          en_counter <= TRUE; -- UpdateCounter Process
          en_peak_detection <= TRUE;  -- PeakDetection process
        end if;
      
      when WAIT_CMDP => 
        en_data <= TRUE; -- ByteOutput process
      
      when CHECK_COMPLETE =>  
        dataReady <= '1'; 
        if counter >= numWords_int then
          seqDone <= '1';
        end if;

      when others =>
        null;

    end case;
  end process;

  --------------------------------------------------------- TWO PHASE PROTOCOL ---------------------------------------------------------
  ---------------------------
  -- detect ctrlIn edge toggle by using XOR gate to spot a binary difference between current and previous ctrlIn
  ---------------------------
  CtrlInEdgeDetect: process(clk, ctrlIn, prev_ctrlIn)
  begin
    if rising_edge(clk) then
      prev_ctrlIn <= ctrlIn;
    end if;
    edge_detected_ctrlIn <= ctrlIn XOR prev_ctrlIn; 
  end process;

  ---------------------------
  -- ctrlOut is toggled when the program starts and when we have processed a byte and the next byte is expected
  ---------------------------
  CtrlOutToggle: process(clk, reset, ctrlOut_state)
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

  --------------------------------------------------------- BASIC PROCESSES ---------------------------------------------------------
  --------------------------------------
  --  Update counter to keep track of current index of byte being processed 
  --------------------------------------
  UpdateCounter: process(clk)
  begin
   if rising_edge(clk) then
      if en_reset then
        counter <= 0;
      elsif en_counter then
        counter <= counter + 1;
      end if;
    end if;
  end process; 

  ----------------------------
  -- converts numWords_bcd input signal from BCD to integer for comparison against counter
  ----------------------------
  BCDtoINT: process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        numWords_int <= 0;
      elsif en_bcd_to_int then
        numWords_int <= to_integer(unsigned(numWords_bcd(2))) * 100 +
                        to_integer(unsigned(numWords_bcd(1))) * 10 + 
                        to_integer(unsigned(numWords_bcd(0))); 
      end if;
    end if;
  end process;

  ----------------------------
  -- keep sending the bytes we read to the command processor
  ----------------------------
  ByteOutput: process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then 
        byte <= "00000000";
      elsif en_data THEN
        byte <= data;
      end if;
    end if;
  end process;
  
  --------------------------------------------------------- PEAK DETECTION ALGORITHM ---------------------------------------------------------
  PeakDetection: process(clk)
  begin
   if rising_edge(clk) then
      if reset = '1' or en_reset then
        peak_value <= (others => '0');
        update_next_values <= 0;
        lastThreeBytes <= (others => (others => '0'));
        maxIndex <= (others => (others => '0'));
        dataResults <= (others => (others => '0'));
      elsif en_peak_detection then
        -- 1. Update dataResults with next three values if the peak was recently found.
        --    update_next_values tracks how many values we still need to store after the peak
        if update_next_values > 0 then
          dataResults(update_next_values - 1) <= std_logic_vector(signed(data));
          update_next_values <= update_next_values - 1;
        end if;

        -- 2. Peak detection.
        --    If it's the first byte or the current byte is greater than past peak value
        if counter = 0 or signed(data) > peak_value then
            peak_value <= signed(data); -- update peak value for future comparison
            maxIndex(0) <= std_logic_vector(to_unsigned(counter mod 10, 4)); -- Update max index using counter
            maxIndex(1) <= std_logic_vector(to_unsigned((counter / 10) mod 10, 4));
            maxIndex(2) <= std_logic_vector(to_unsigned((counter / 100) mod 10, 4));
            dataResults(6) <= std_logic_vector(lastThreeBytes(2));-- Update the three values before the peak
            dataResults(5) <= std_logic_vector(lastThreeBytes(1));
            dataResults(4) <= std_logic_vector(lastThreeBytes(0));
            dataResults(3) <= std_logic_vector(signed(data)); -- Update the peak value
            dataResults(2) <= (others => '0'); -- Reset the three values after the peak
            dataResults(1) <= (others => '0');
            dataResults(0) <= (others => '0'); 
            update_next_values <= 3; -- indicating that we need to store the next three values
        end if;

        -- 3. Always keep track of the last three bytes, so we can update dataResults(6 downto 4) when peak found
        lastThreeBytes(2) <= lastThreeBytes(1);
        lastThreeBytes(1) <= lastThreeBytes(0);
        lastThreeBytes(0) <= signed(data);
      end if;
    end if;
  end process;

end Behavioral;