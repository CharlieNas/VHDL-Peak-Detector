----------------------------------------------------------------------------
--	tb_dataGenConsume.vhd -- A testbench that simulates the full system.
----------------------------------------------------------------------------
-- Author:  Dinesh Pamunuwa
----------------------------------------------------------------------------
--
----------------------------------------------------------------------------
-- This testbench instantiates all the components. It includes synthesised 
-- versions of the Command Processor and the Data Processor as structural 
-- implementations.
--
-- The simulation issues two start commands with 2 and 13 bytes respectively,
-- followed by print list (L) and print peak (P) commands by driving the input 
-- line of the UART Receiver. Run the simulation for at least 160 ms to see 
-- the full simulation for these commands.
-- 
-- In order to replace the Command Processor (Data Processor) module in this 
-- testbench with your own you should delete the "cmdProc_wrapper.vhd" and 
-- "cmdProc_synthesised.vhd" ("dataConsume_synthesised.vhd" and 
-- "dataConsume_wrapper.vhd") files from the ModelSim project, and add the 
-- file which you should name "cmdProc.vhd" ("dataConsume.vhd") that contains 
-- the new source.
--
-- This testbech is supplied as a template to demonstrate how the different 
-- components work together and system-level timing. You should expand this 
-- testbench to test for other patterns in order to test your components 
-- properly.
----------------------------------------------------------------------------
--
----------------------------------------------------------------------------
-- Version:			1.0
-- Revision History:
-- 09/02/2014 (Dinesh): Created using Modelsim
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.common_pack.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
use UNISIM.VPKG.ALL;

entity tb_dataGenConsume is 
end;

architecture test of tb_dataGenConsume is 

  component UART_TX_CTRL is
    port ( 
      SEND : in  STD_LOGIC;
      DATA : in  STD_LOGIC_VECTOR (7 downto 0);
      CLK : in  STD_LOGIC;
      READY : out  STD_LOGIC;
      UART_TX : out  STD_LOGIC
    );
  end component;  
  
  component UART_RX_CTRL is
    port(
      RxD: in std_logic;                -- serial data in
      sysclk: in std_logic; 		-- system clock
      reset: in std_logic;		--	synchronous reset
      rxDone: in std_logic;		-- data succesfully read (active high)
      rcvDataReg: out std_logic_vector(7 downto 0); -- received data
      dataReady: out std_logic;	        -- data ready to be read
      setOE: out std_logic;		-- overrun error (active high)
      setFE: out std_logic		-- frame error (active high)
    );
  end component; 

  component dataGen is
    port (
      clk:		in std_logic;
      reset:		in std_logic; -- synchronous reset
      ctrlIn: in std_logic;
      ctrlOut: out std_logic;
      data: out std_logic_vector(7 downto 0)
    );
  end component;
  
  component dataConsume is
    port (
      clk:		in std_logic;
      reset:		in std_logic; -- synchronous reset
      start: in std_logic;
      numWords_bcd: in BCD_ARRAY_TYPE(2 downto 0);
      ctrlIn: in std_logic;
      ctrlOut: out std_logic;
      data: in std_logic_vector(7 downto 0);
      dataReady: out std_logic;
      byte: out std_logic_vector(7 downto 0);
      seqDone: out std_logic;
      maxIndex: out BCD_ARRAY_TYPE(2 downto 0);
      dataResults: out CHAR_ARRAY_TYPE(0 to 6) 
    );
  end component;
  
  component cmdProc is
    port (
      clk:		in std_logic;
      reset:		in std_logic;
      rxnow:		in std_logic;
      rxData:			in std_logic_vector (7 downto 0);
      txData:			out std_logic_vector (7 downto 0);
      rxdone:		out std_logic;
      ovErr:		in std_logic;
      framErr:	in std_logic;
      txnow:		out std_logic;
      txdone:		in std_logic;
      start: out std_logic;
      numWords_bcd: out BCD_ARRAY_TYPE(2 downto 0);
      dataReady: in std_logic;
      byte: in std_logic_vector(7 downto 0);
      maxIndex: in BCD_ARRAY_TYPE(2 downto 0);
      dataResults: in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
      seqDone: in std_logic
    );
  end component;
  
  signal clk: std_logic := '0';
  signal reset, sig_start, ctrl_genDriv, ctrl_consDriv, sig_dataReady, sig_seqDone: std_logic;
  signal sig_rxDone, sig_rxNow, sig_ovErr, sig_framErr, sig_txNow, sig_txDone: std_logic;
  signal sig_rx, sig_tx, sig_rx_debug: std_logic;
  
  signal sig_rxData, sig_txData, sig_byte: std_logic_vector(7 downto 0);
  signal sig_maxIndex: BCD_ARRAY_TYPE(2 downto 0);
  
  signal sig_dataResults: CHAR_ARRAY_TYPE(0 to 6);
  signal sig_numWords_bcd: BCD_ARRAY_TYPE(2 downto 0);
  
  signal sig_data: std_logic_vector(7 downto 0);
  signal seqCount: integer :=0;
  
  constant SEQ_COUNT_MAX : integer := 1; -- defines how many runs to test
  type ARRAY3D_TYPE is array (0 to SEQ_COUNT_MAX) of CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
  type ARRAY3D_BCD_TYPE is array (0 to SEQ_COUNT_MAX) of BCD_ARRAY_TYPE(2 downto 0);
  
 
--  constant RESULTS : ARRAY3D_TYPE :=((X"92", X"C7", X"71", X"F9", X"93", X"A8", X"68"),
--                                     (X"5D", X"49", X"52", X"EB", X"70", X"3B", X"39"));

constant RESULTS : ARRAY3D_TYPE :=((X"68", X"A8", X"93", X"F9", X"71", X"C7", X"92"),
                                     (X"39", X"3B", X"70", X"EB", X"52", X"49", X"5D"));
  constant peak : ARRAY3D_BCD_TYPE :=((X"0",X"0",X"7"),(X"0",X"0",X"5"));
                                      
  -- function to convert std_logic_vector having '1's and '0's to string
  -- for use in assert statements
  function vec2str(vec : std_logic_vector) return string is
    variable str : string(vec'LEFT+1 DOWNTO 1);
  begin
    for i in vec'REVERSE_RANGE loop
      if vec(i) = '1' then
        str(i+1) := '1';
      elsif vec(i) = '0' then
        str(i+1) := '0';
      else
        str(i+1) := 'X';
      end if;
    end loop;
    return str;
  end vec2str;
  
  
begin
  clk <= NOT clk after 5 ns when now <2000 ms else clk;
  reset <= '0', '1' after 2 ns, '0' after 15 ns, '0' after 3600 ns, '0' after 3615 ns;
  
 
  seqCounter:	process(sig_seqDone)
  begin
    if reset = '1' then
      seqCount <= 0;
    elsif rising_edge(sig_seqDone) then -- clearly only acceptable in a TB
       seqCount <= seqCount + 1;

       assert false report "Sequence No." & INTEGER'IMAGE(seqCount) severity note;
       
       for i in 0 to RESULT_BYTE_NUM-1 loop
          -- byte ordering may be different in different implementations
          -- try changing (RESULT_BYTE_NUM-1-i) to (i) if there is a mismatch between all bytes except the peak
          -- it is important that the implementations of the data consumer and command processor within
          -- the same group follow the same format
          assert sig_dataResults(RESULT_BYTE_NUM-1-i) = RESULTS(seqCount)(i) report "Mismatch for seq " & INTEGER'IMAGE(seqCount) 
          & ":" & CR & "byte " & INTEGER'IMAGE(i) & " should be " & vec2str(RESULTS(seqCount)(i))
          & CR & "but is           " & vec2str(sig_dataResults(RESULT_BYTE_NUM-1-i)) severity warning;
       end loop;
       
       assert sig_maxIndex = peak(seqCount) report "Mismatch for seq " & INTEGER'IMAGE(seqCount) 
          & ":" & CR & "peak " & INTEGER'IMAGE(seqCount) & " should be {" 
          & vec2str(peak(seqCount)(2)) & "} {" &vec2str(peak(seqCount)(1)) & "} {" &vec2str(peak(seqCount)(0)) &"}"
          & CR & "but is           {" & vec2str(sig_maxIndex(2)) & "} {" & vec2str(sig_maxIndex(1)) & "} {" & vec2str(sig_maxIndex(0)) &"}" severity warning;
      
    end if;
  end process;


  ------------------------
  -- issue first read cmd A012
  ------------------------
  -- A: 1, 0, 1000_0010, 1 (idle - 1, start bit - 0, A (0100_0001) in order of LSB first, stop bit -1)
  sig_rx <= '1', '0' after 1 us, '1' after 105 us, '0' after 209 us,  '0' after 313 us,  '0' after 417 us,  
  '0' after 521 us,  '0' after 625 us,  '1' after 729 us,  '0' after 833 us, '1' after 937 us, 
  -- 0: 0, 0000_1100, 1 (start bit - 0, decimal 0 (0011_0000) in order of LSB first, stop bit -1)
  '0' after 1200 us, '0' after 1304 us, '0' after 1408 us, '0' after 1512 us,  '0' after 1616 us,  
  '1' after 1720 us, '1' after 1824 us,  '0' after 1928 us,  '0' after 2032 us,  '1' after 2136 us, 
  -- 1: 0, 10001100, 1 (start bit - 0, decimal 0 (0011_0001) in order of LSB first, stop bit -1)
    '0' after 2500 us, '1' after 2604 us, '0' after 2708 us, '0' after 2812 us, '0' after 2916 us,
    '1' after 3020 us,  '1' after 3124 us,  '0' after 3228 us,  '0' after 3332 us,  '1' after 3436 us,  
  -- 2: 0, 0100_1100, 1 (start bit - 0, decimal 2 (0011_0010) in order of LSB first, stop bit -1)
  '0' after 3800 us, '0' after 3904 us, '1' after 4008 us, '0' after 4112 us, '0' after 4216 us, 
  '1' after 4320 us, '1' after 4424 us, '0' after 4528 us, '0' after 4632 us, '1' after 4736 us,
  ------------------------
  -- issue second read cmd A013
  ------------------------
  -- A: 1, 01000010, 1 (idle - 1, start bit - 0, A (0100_0001) in order of LSB first, stop bit -1)
  '1' after 132000 us, '0' after 132001 us, '1' after 132105 us, '0' after 132209 us,  '0' after 132313 us,  '0' after 132417 us,  
  '0' after 132521 us,  '0' after 132625 us,  '1' after 132729 us,  '0' after 132833 us, '1' after 132937 us, 
  -- 0: 0, 00001100, 1 (start bit - 0, decimal 0 (0011_0000) in order of LSB first, stop bit -1)
  '0' after 133200 us, '0' after 133304 us, '0' after 133408 us, '0' after 133512 us,  '0' after 133616 us,  
  '1' after 133720 us, '1' after 133824 us,  '0' after 133928 us,  '0' after 134032 us,  '1' after 134136 us, 
  -- 1: 0, 10001100, 1 (start bit - 0, decimal 0 (0011_0001) in order of LSB first, stop bit -1)
  '0' after 134500 us, '1' after 134604 us, '0' after 134708 us, '0' after 134812 us, '0' after 134916 us,
  '1' after 135020 us,  '1' after 135124 us,  '0' after 135228 us,  '0' after 135332 us,  '1' after 135436 us,  
  -- 3: 0, 11001100, 1 (start bit - 0, decimal 2 (0011_0011) in order of LSB first, stop bit -1)
  '0' after 135800 us, '1' after 135904 us, '1' after 136008 us, '0' after 136112 us, '0' after 136216 us, 
  '1' after 136320 us, '1' after 136424 us, '0' after 136528 us, '0' after 136632 us, '1' after 136736 us,
  ------------------------
  -- issue print results cmd L
  ------------------------ 
  -- L: 0, 0011_0010, 1 (start bit - 0, A (0100_1100) in order of LSB first, stop bit -1)
  '0' after 190001 us, '0' after 190105 us, '0' after 190209 us,  '1' after 190313 us,  '1' after 190417 us,  
  '0' after 190521 us,  '0' after 190625 us,  '1' after 190729 us,  '0' after 190833 us, '1' after 190937 us,
  ------------------------
  -- issue print results cmd P
  ------------------------ 
  -- P: 0, 0000_1010, 1 (start bit - 0, P (0101_0000) in order of LSB first, stop bit -1)
  '0' after 236001 us, '0' after 236105 us, '0' after 236209 us,  '0' after 236313 us,  '0' after 236417 us,  
  '1' after 236521 us,  '0' after 236625 us,  '1' after 236729 us,  '0' after 236833 us, '1' after 236937 us;
  
  
  dataGen1: dataGen
    port map (
      clk => clk,
      reset => reset,
      ctrlIn => ctrl_consDriv,
      ctrlOut => ctrl_genDriv,
      data => sig_data
    );
    
  dataConsume1: dataConsume
    port map (
      clk => clk,
      reset => reset,
      start => sig_start,
      numWords_bcd => sig_numWords_bcd,
      ctrlIn => ctrl_genDriv,
      ctrlOut => ctrl_consDriv,
      dataReady => sig_dataReady,
      byte => sig_byte,
      data => sig_data,
      seqDone => sig_seqDone,
      maxIndex => sig_maxIndex,
      dataResults => sig_dataResults
    );
    
  cmdProc1: cmdProc
    port map (
      clk => clk,
      reset => reset,
      rxNow => sig_rxNow,
      rxData => sig_rxData,
      txData => sig_txData,
      rxDone => sig_rxDone,
      ovErr => sig_ovErr,
      framErr => sig_framErr,
      txNow => sig_txNow,
      txDone => sig_txDone,
      start => sig_start,
      numWords_bcd => sig_numWords_bcd,
      dataReady => sig_dataReady,
      byte => sig_byte,
      maxIndex => sig_maxIndex,
      seqDone => sig_seqDone,
      dataResults => sig_dataResults
    );
    	
  tx: UART_TX_CTRL
    port map (
      SEND => sig_txNow,
      DATA => sig_txData,
      CLK => clk,
      READY => sig_txDone,
      UART_TX => sig_tx
    );    	
  	
  rx : UART_RX_CTRL
   port map(
     RxD => sig_rx, -- input serial line
     sysclk => clk,
     reset => reset, 
     rxDone => sig_rxdone,
     rcvDataReg => sig_rxData,
     dataReady => sig_rxNow,
     setOE => sig_ovErr,
     setFE =>  sig_framerr
   );   	
  	
 end test;
