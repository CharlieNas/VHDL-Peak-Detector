-- TEAM A: charlie - damian
-- signed 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.common_pack.all;

--------------- ENTITY DECLARATION -------------------------------------------------------------------------------------------------
ENTITY dataConsume IS
  port(
    clk:		in std_logic;
    reset:		in std_logic;

    start: in std_logic; -- to start retreiving the data 
    numWords_bcd: in BCD_ARRAY_TYPE(2 downto 0); -- how many numbers (data) are gonna enter to the data processor
    -- TODO: transform it into a signed number
    data: in std_logic_vector(7 downto 0); -- each data is one number of 8 bits, data = number

    ctrlIn: in std_logic; -- for two phase protocol
    -- TODO: we use this to check if the data generator have sent the data
    ctrlOut: out std_logic; -- for two phase protocol

    dataReady: out std_logic; -- set to high after the number is processes and the data processor is ready for a new number
    seqDone: out std_logic; -- when numWords has been processed and dataResult is ready
    byte: out std_logic_vector(7 downto 0); -- send the number to the command processor after process the number (S2)
    maxIndex: out BCD_ARRAY_TYPE(2 downto 0); -- index of the largest number (peak) in dataResults
    dataResults: out CHAR_ARRAY_TYPE(0 to 6) -- array of 7 numbers (bytes) with the largest one in the middle
  )
END dataConsume;

------------------------------------------------------------------------------------------------------------------------------------

architecture Behavioral of dataConsume is
  type state_type is (S0, S1, S2, S3);
  signal curr_state, next_state: state_type;

  -------------------------------------------------------------  SIGNALS  ----------------------------------------------------------------

  signal BCD2int_enable: boolean := FALSE;
  signal numWords_int: integer := 0;
  signal counter: integer := 0;

  signal peak_value: signed(7 downto 0) := (others => '0');
  signal compare_enable: integer := 0;
  signal peak_index: integer := 0;
  signal peak_found: integer := 0; -- set to 3 and decrements if peak found, in order to record next three bytes
  signal currentBytes: array(0 to 6) of std_logic_vector(7 downto 0); -- acts as our main buffer
  signal lastThreeBytes: array(0 to 2) of std_logic_vector(7 downto 0); -- always storing last three bytes

  ---------------------------------------------------------------  PROCESSES  ---------------------------------------------------------
  begin

  -- Process to transform 3-bit BCD array into an integer
  BCDToInteger: process(clk, BCD2int_enable, numWords_bcd)
  begin
    if BCD2int_enable then
      numWords_int <= to_integer(unsigned(numWords_bcd(2))) * 100 +
                      to_integer(unsigned(numWords_bcd(1))) * 10 + 
                      to_integer(unsigned(numWords_bcd(0))); 
    end if;
  end process;

  -- Process to convert maxIndex from Binary to BCD
  BinaryToBCD: process(clk)
  begin
  end process;
  
  -- AddToBuffer: process(clk)
  -- begin
  --     if rising_edge(clk) and dataReady = '1' then
  --         buffer(counter) <= signed(data);
  --     end if;
  -- end process;
  
  -- split PeakDetection into several processes? ************************************
  PeakDetection: process(clk)
  begin
      if rising_edge(clk) and compare_enable = 1 then
          -- 1. Update buffer with next three values if peak was recent
          if peak_found > 0 then
            if peak_found = 3:
              currentBytes[4] = data;
            elsif peak_found = 2 then
              currentBytes[5] = data;
            elsif peak_found = 1 then
              currentBytes[6] = data;
            peak_found <= peak_found - 1;
            end if;
          end if;

          -- 2. PeakDetection Process
          if counter = 0 or signed(data) > peak_value then
              -- update peak index
              peak_index <= counter;
              -- update the first 3 values of buffer
              currentBytes[0] <= lastThreeBytes[0];
              currentBytes[1] <= lastThreeBytes[1];
              currentBytes[2] <= lastThreeBytes[2];
              -- # new peak in the middle
              currentBytes[3] <= data;
              -- # reset next three values of buffer 
              currentBytes[4] <= (others => '0');
              currentBytes[5] <= (others => '0');
              currentBytes[6] <= (others => '0');
              -- # we update the last three 
              peak_found <= 3;
          end if;

          -- 3. Always keep track of last three bytes
          lastThreeBytes[0] <= lastThreeBytes[1];
          lastThreeBytes[1] <= lastThreeBytes[2];
          lastThreeBytes[2] <= data;
      end if;
  end process;

  GetValuesFromBuffer: process(clk)
  begin
  end process;
  
  -- -- Compares two binary string to determine which is bigger
  -- compareData: PROCESS(clk)
  -- begin
  --   if clk'event and clk = '1' then
  --     IF comp_en = TRUE then
  --     newPeak_en <= FALSE;
  --     -- If B greater than A, assign B to be the new A
  --     -- Otherwise, if A greater than B or A equal to B, keep A as peak
  --     if B > A then
  --       newPeak_en <= TRUE;
  --     else
  --       newPeak_en <= FALSE;
  --   end if;
  -- end process;

  CounterUpdate: process(clk)
  begin
      if rising_edge(clk) and dataReady = '1' then
          counter <= counter + 1;
      end if;
  end process;


  ByteOutput: process(clk)
  begin
      if rising_edge(clk) and dataReady = '1' then
          byte <= data; -- Output the processed data
      end if;
  end process;

  ------------------------------------------------------  STATE MACHINE  --------------------------------------------------------------
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

  NextState: process(curr_state, start, counter)
    begin
      case curr_state is
        ------------------------------------------- S0 Idle State -------------------------------------------
        when S0 =>
          -- reset all signals
          BCD2int_enable <= FALSE;
          seqDone <= '0';
          dataReady <= '0';                      
          dataResults <= (others => 'X');
          maxIndex <= (others => 'X');

          -- if start = 1 -> S1
          if start = '1' then
            -- transform numWords to int
            BCD2int_enable <= TRUE;
            next_state <= S1;
          else
            next_state <= S0;
          end if;

        ------------------------------------------- S1 Retrieving data from generator -------------------------------------------
        when S1 => 
          -- flip ctrlOut
          ctrlOut <= not ctrlOut;
          -- update counter
          counter <= counter + 1;

            -- if ctrlIn flips (received data) -> S2
          if rising_edge(ctrlIn) then
            next_state <= S2;
          end if;
        ------------------------------------------- S2 Process data bytes -------------------------------------------
        when S2 => 
          -- compare 2 bytes (current byte & current peak)
          compare_enable <= 1;
          -- What peakDetection process does:
          -- 1. update buffer with next three values if peak was recent
          -- 2. if a peak was found, update peak index + update the first three values of the buffer with the last three bytes 
          --    + new peak in the middle of buffer + reset the next three values of the buffer 
          -- 3. always keep track of last three bytes
            
          -- sending byte & dataReady signal to command processor
          byte <= data;
          dataReady = '1';

          if counter = numWords_int then
              next_state <= S3;
          else
            next_state <= S1;
          end if;

        ------------------------------------------- S3 Handle output -------------------------------------------
        when S3 =>
          -- Get the peak from buffer
          -- convert the 7 values to BCD 
          -- Put values into dataResults
          -- Set seqDone = 1 to indicate completion
          seqDone <= 1;

          next_state <= S0;
      end case;

  end process;

end Behavioral;
