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
    byte: out std_logic_vector(7 downto 0); -- bytes (numbers) to store in dataResults = the peak and the values souround it 
    maxIndex: out BCD_ARRAY_TYPE(2 downto 0); -- index of the largest number (peak) in dataResults
    dataResults: out CHAR_ARRAY_TYPE(0 to 6) -- array of 7 numbers (bytes) with the largest one in the middle
  )
END dataConsume;
------------------------------------------------------------------------------------------------------------------------------------

architecture Behavioral of dataConsume is
  -- SIGNALS

  begin

  -- transform binary string to 3-bit BCD array
  BinaryToBCD: process()
  end process;

  -- transform 3-bit BCD array into a binary string
  BCDToBinary: process()
  end process;

  -- store the values of the current max index 
  CurrentMaxIndex: process()
  end process;

  -- compare to numbers
  CompareNumbers: process()
  end process;

  ----------------------------------------------------------------------------------------------------------------------------
  Temp1: process()
  end process;

  Temp2: process()
  end process;

  Temp3: process()
  end process;

  Temp4: process()
  end process;

  ----------------------------------------------------------------------------------------------------------------------------
  PeakAdd1: process()
  end process;

  PeakAdd2: process()
  end process;

  PeakAdd3: process()
  end process;
  ----------------------------------------------------------------------------------------------------------------------------
  PeakMinus1: process()
  end process;

  PeakMinus2: process()
  end process;

  PeakMinus3: process()
  end process;

  ----------------------------------------------------------------------------------------------------------------------------

end Behavioral;


