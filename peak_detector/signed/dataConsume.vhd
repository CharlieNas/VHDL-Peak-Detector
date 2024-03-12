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
  signal counter: integer := 0;


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

  -- transform binary string to 3-bit BCD array
  BinaryToBCD: process()
  end process;

  -- store the values of the current max index 
  CurrentMaxIndex: process()
  end process;

  -- compare to numbers
  CompareNumbers: process()
  end process;

  AddSorroundingValues: process()
  end process;

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

  NextState: process(curr_state)
    begin
      case curr_state is
        when S0 =>
          BCD2int_enable <= FALSE
          seqDone <= '0';
          dataReady <= '0';                      
          dataResults(0) <= (OTHERS => 'X');
          dataResults(1) <= (OTHERS => 'X');
          dataResults(2) <= (OTHERS => 'X');
          dataResults(3) <= (OTHERS => 'X');
          dataResults(4) <= (OTHERS => 'X');
          dataResults(5) <= (OTHERS => 'X');
          dataResults(6) <= (OTHERS => 'X');
          maxIndex(2) <= (OTHERS => 'X');
          maxIndex(1) <= (OTHERS => 'X');
          maxIndex(0) <= (OTHERS => 'X');

          if start = '1' then
            BCD2int_enable <= TRUE
            seqDone <= '0';
            dataReady <= '0';                          
            dataResults(0) <= (OTHERS => 'X');
            dataResults(1) <= (OTHERS => 'X');
            dataResults(2) <= (OTHERS => 'X');
            dataResults(3) <= (OTHERS => 'X');
            dataResults(4) <= (OTHERS => 'X');
            dataResults(5) <= (OTHERS => 'X');
            dataResults(6) <= (OTHERS => 'X');
            maxIndex(2) <= (OTHERS => 'X');
            maxIndex(1) <= (OTHERS => 'X');
            maxIndex(0) <= (OTHERS => 'X');

            -- NEXT STATE
            next_state <= S1;
          else
            next_state <= S0;
          end if;
          
        when S1 => 
          if counter < numWords_int then
            -- Data processing logic here (e.g., compare, update counter)
            -- Update max_value if current data > max_value
            next_state <= S1;
          else
            next_state <= S2;
          end if;
          
        when S2 =>
          -- Compile dataResults and convert to BCD as needed
          -- Set seqDone high to indicate completion
          next_state <= S0; -- Or stay in S2 depending on design
          
        when others => 
          next_state <= S0;
      end case;
  end process;

end Behavioral;


