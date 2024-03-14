library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
--use UNISIM.VPKG.ALL;

ENTITY tb_cmdL IS END;

ARCHITECTURE behav OF tb_cmdL IS

    COMPONENT cmdL IS
    PORT (  
    clk:		    in std_logic;                           
    reset:		in std_logic;       
    enL:           in std_logic;
    dataResults:  in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);                          
    txdone:		in std_logic;                           
    txData:	    out std_logic_vector (7 downto 0);      
    txnow:		out std_logic;
    doneL:         out std_logic                     
    );
    END COMPONENT;
  
  FOR t_cmdL: cmdL USE ENTITY WORK.cmdL(arch);
  
  -- inputs
  SIGNAL enL, clk, reset, txdone: STD_LOGIC :='0';
  SIGNAL dataResults: CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
  -- outputs
  SIGNAL txnow, doneL: STD_LOGIC;
  SIGNAL txData: STD_LOGIC_VECTOR(7 DOWNTO 0);

BEGIN
  -- generate clk
  clk <= NOT clk AFTER 50 ns WHEN NOW < 5 us ELSE clk; 
  
  reset <= '1',
    '0' AFTER 100 ns;

  dataResults <= (X"13", X"20", X"60", X"90", X"A2", X"A8", X"C5") after 200 ns;

  enL <= '0',
  '1' AFTER 300 ns;

  txdone <= '0',
  '1' AFTER 750 ns,
  '0' AFTER 850 ns,
  '1' AFTER 1550 ns,
  '0' AFTER 1650 ns,
  '1' AFTER 2350 ns,
  '0' AFTER 2450 ns,
  '1' AFTER 3150 ns,
  '0' AFTER 3250 ns,
  '1' AFTER 3950 ns,
  '0' AFTER 4050 ns;
   
  t_cmdL: cmdL PORT MAP(clk, reset, enL, dataResults, txdone, txData, txnow, doneL);
END behav;