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
    data: in std_logic_vector(7 downto 0); -- each data is one number of 8 bits, data = number

    ctrlIn: in std_logic; -- for two phase protocol
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

  signal current_value: signed(7 downto 0) := (others => '0');

  signal peak_value: signed(7 downto 0) := (others => '0');
  signal compare_enable: boolean := FALSE;
  signal peak_index: integer := 0;
  signal peak_found: integer := 0; -- set to 3 and decrements if peak found, in order to record next three bytes
  signal currentBytes: array(0 to 6) of signed(7 downto 0); -- acts as our main buffer
  signal lastThreeBytes: array(0 to 2) of signed(7 downto 0); -- always storing last three bytes

  signal max_index_bcd_enable: boolean := FALSE;
  signal max_index_bcd: BCD_ARRAY_TYPE(2 downto 0); 

  signal store_data_result_enable: boolean := FALSE;

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

  -- Convert peak_index into BCD to output maxIndex in the future
  MaxIndexBCD: process(clk)
  begin
    if rising_edge(clk) and max_index_bcd_enable then
      max_index_bcd(0)(3 downto 0) <= std_logic_vector(to_unsigned(peak_index mod 10, 4));
      max_index_bcd(1)(3 downto 0) <= std_logic_vector(to_unsigned((peak_index / 10) mod 10, 4));
      max_index_bcd(2)(3 downto 0) <= std_logic_vector(to_unsigned((peak_index / 100) mod 10, 4));
    end if;
  end process;

  -- We dont need to do any conversion if currentBytes are already signed
  StoreInDataResult: process(clk)
  begin
    if store_data_result_enable then
      dataResults(0) <= currentBytes(0);
      dataResults(1) <= currentBytes(1);
      dataResults(2) <= currentBytes(2);
      dataResults(3) <= currentBytes(3); -- peak
      dataResults(4) <= currentBytes(4);
      dataResults(5) <= currentBytes(5);
      dataResults(6) <= currentBytes(6);
    end if;
  end process;

  -- split PeakDetection into several processes? ************************************
  PeakDetection: process(clk)
  begin
      if rising_edge(clk) and compare_enable then
          -- 1. Update buffer with next three values if peak was recent
          if peak_found > 0 then
            if peak_found = 3 then
              currentBytes(4) = current_value;
            elsif peak_found = 2 then
              currentBytes(5) = current_value;
            elsif peak_found = 1 then
              currentBytes(6) = current_value;
            peak_found <= peak_found - 1;
            end if;
          end if;

          -- 2. PeakDetection Process
          if counter = 0 or current_value > peak_value then
              -- update peak index
              peak_index <= counter;
              -- update the first 3 values of buffer
              currentBytes(0) <= lastThreeBytes(0);
              currentBytes(1) <= lastThreeBytes(1);
              currentBytes(2) <= lastThreeBytes(2);
              -- # new peak in the middle
              currentBytes(3) <= current_value;
              -- # reset next three values of buffer 
              currentBytes(4) <= (others => '0');
              currentBytes(5) <= (others => '0');
              currentBytes(6) <= (others => '0');
              -- # we update the last three 
              peak_found <= 3;
          end if;

          -- 3. Always keep track of last three bytes
          lastThreeBytes(0) <= lastThreeBytes(1);
          lastThreeBytes(1) <= lastThreeBytes(2);
          lastThreeBytes(2) <= current_value;
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

  NextState: process(curr_state, start)
    begin
      case curr_state is
        ------------------------------------------- S0 Idle State -------------------------------------------
        when S0 =>
          -- reset created structures
          BCD2int_enable <= FALSE;
          counter <= 0;
          current_value <= (others => '0');
          peak_value <= (others => '0');
          compare_enable <= FALSE;
          peak_index <= 0;
          peak_found <= 0;
          currentBytes <= (others => (others => '0'));
          lastThreeBytes <= (others => (others => '0'));
          max_index_bcd_enable <= FALSE;
          max_index_bcd <= (others => 'X');
          store_data_result_enable <= FALSE;

          -- reset from the entity
          seqDone <= '0';
          dataReady <= '0';                      
          dataResults <= (others => 'X');
          maxIndex <= (others => 'X');


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

            -- if ctrlIn flips (received data) -> S2
          if rising_edge(ctrlIn) then
            current_value <= signed(data);
            counter <= counter + 1;
            next_state <= S2;
          end if;
        ------------------------------------------- S2 Process data bytes -------------------------------------------
        when S2 => 
          -- compare 2 bytes (current byte & current peak)
          compare_enable <= TRUE;
          -- What peakDetection process does:
          -- 1. update buffer with next three values if peak was recent
          -- 2. if a peak was found, update peak index + update the first three values of the buffer with the last three bytes 
          --    + new peak in the middle of buffer + reset the next three values of the buffer 
          -- 3. always keep track of last three bytes
          dataReady <= '1';

          if counter = numWords_int then
              next_state <= S3;
          else
            next_state <= S1;
          end if;

        ------------------------------------------- S3 Handle output -------------------------------------------
        when S3 =>
          max_index_bcd_enable <= TRUE;
          store_data_result_enable <= TRUE;
          -- send outputs
          maxIndex <= max_index_bcd;
          seqDone <= 1;
          next_state <= S0;
        when others =>
          -- default reseting
          -- reset created structures
          BCD2int_enable <= FALSE;
          counter <= 0;
          current_value <= (others => '0');
          peak_value <= (others => '0');
          compare_enable <= 0;
          peak_index <= 0;
          peak_found <= 0;
          currentBytes <= (others => (others => '0'));
          lastThreeBytes <= (others => (others => '0'));
          max_index_bcd_enable <= FALSE;
          max_index_bcd <= (others => 'X');
          store_data_result_enable <= FALSE;

          -- reset from the entity
          seqDone <= '0';
          dataReady <= '0';                      
          dataResults <= (others => 'X');
          maxIndex <= (others => 'X');
      end case;

  end process;

end Behavioral;
