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
    byte: out std_logic_vector(7 downto 0); -- send the number to the command processor after process the number (S1)
    maxIndex: out BCD_ARRAY_TYPE(2 downto 0); -- index of the largest number (peak) in dataResults
    dataResults: out CHAR_ARRAY_TYPE(0 to 6) -- array of 7 numbers (bytes) with the largest one in the middle
  )
END dataConsume;

------------------------------------------------------------------------------------------------------------------------------------

architecture Behavioral of dataConsume is
  type state_type is (S0, S1, S2);
  signal curr_state, next_state: state_type;

  -- signals for BCDToInteger process
  signal BCD2int_enable: boolean := FALSE;
  signal numWords_int: integer := 0;
  signal data_received_counter: integer := 0;

  signal peak_value: signed(7 downto 0) := (others => '0');
  signal peak_index: integer := 0;  
  signal binary_buffer: array(0 to 499) of signed(7 downto 0);
  signal data_ready: std_logic := '0';


  -- signals 
  signal A, B: std_logic_vector(7 DOWNTO 0) := (OTHERS => 'X');
  
  begin
  -- transform 3-bit BCD array into an integer
  BCDToInteger: process(clk, BCD2int_enable, numWords_bcd)
  begin
    if BCD2int_enable then
      numWords_int <= to_integer(unsigned(numWords_bcd(2))) * 100 +
                      to_integer(unsigned(numWords_bcd(1))) * 10 + 
                      to_integer(unsigned(numWords_bcd(0))); 
    end if;
  end process;


  DataStorage: process(clk)
  begin
      if rising_edge(clk) and dataReady = '1' then
          binary_buffer(data_received_counter) <= signed(data);
      end if;
  end process DataStorage;


  PeakDetection: process(clk)
  begin
      if rising_edge(clk) and dataReady = '1' then
          if data_received_counter = 0 or signed(data) > peak_value then
              peak_value <= signed(data);
              peak_index <= data_received_counter;
          end if;
      end if;
  end process PeakDetection;


  CounterUpdate: process(clk)
  begin
      if rising_edge(clk) and dataReady = '1' then
          data_received_counter <= data_received_counter + 1;
      end if;
  end process CounterUpdate;


  ByteOutput: process(clk)
  begin
      if rising_edge(clk) and dataReady = '1' then
          byte <= data; -- Output the processed data
      end if;
  end process ByteOutput;


  ----------------------------------------------------------------------------------------------------------------------------
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
        -- IDLE STATE
        when S0 =>
          BCD2int_enable <= FALSE;
          seqDone <= '0';
          dataReady <= '0';                      
          dataResults <= (others => 'X');
          maxIndex <= (OTHERS => 'X');

          if start = '1' then
            BCD2int_enable <= TRUE;
            seqDone <= '0';
            dataReady <= '0';                          
            dataResults <= (others => 'X');
            maxIndex <= (OTHERS => 'X');

            -- NEXT STATE
            next_state <= S1;
          else
            next_state <= S0;
          end if;
        -- process data and find peak  
        when S1 => 
          if data_received_counter < numWords_int then
            -- activate and compare
            -- update counter
            -- update max_value 
            -- update index
            -- byte output process
            next_state <= S1;
          else
            next_state <= S2;
          end if;
        -- preapre output data  
        when S2 =>
          -- Compile dataResults and convert to BCD as needed
          -- Set seqDone high to indicate completion
          next_state <= S0; 
        when others => 
          next_state <= S0;
      end case;
  end process;

end Behavioral;


