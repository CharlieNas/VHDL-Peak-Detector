LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY tb_printer IS END;

ARCHITECTURE behav OF tb_printer IS
  COMPONENT printer 
  PORT (
    en:           in std_logic;                           --i
    dataIn:       in std_logic_vector (7 downto 0);       --i
    clk:		    in std_logic;                           --i
    reset:		in std_logic;                           --i
    txdone:		in std_logic;                           --i
    txData:	    out std_logic_vector (7 downto 0);      --o
    txnow:		out std_logic;                          --o
    finished:     out std_logic                           --o
  );
  END COMPONENT;
  
  FOR t_printer: printer USE ENTITY WORK.printer(arch);
  
  -- inputs
  SIGNAL en, clk, reset, txDone: STD_LOGIC :='0';
  SIGNAL dataIn: STD_LOGIC_VECTOR(7 DOWNTO 0) :="00000000";
  -- outputs
  SIGNAL txnow, finished: STD_LOGIC;
  SIGNAL txData: STD_LOGIC_VECTOR(7 DOWNTO 0);
  -- test signal
  SIGNAL test: STD_LOGIC_VECTOR(7 DOWNTO 0);

BEGIN
  -- generate clk
  clk <= NOT clk AFTER 50 ns WHEN NOW < 3 us ELSE clk; 
  
  reset <= '1',
    '0' AFTER 100 ns;
  
  en <= '0',
    '1' AFTER 350 ns,
    '0' AFTER 450 ns;
    
  dataIn <= "00000000",
    "01010101" AFTER 350 ns,
    "00000000" AFTER 450 ns;
  
  txDone <= '0',
    '1' AFTER 1550 ns;
    
  test_out: PROCESS(clk)
  BEGIN
    IF clk'EVENT AND clk='1' THEN
      IF txnow = '1' THEN
        test <= txData;
      END IF;
    END IF;
  END PROCESS;
   
  t_printer: printer PORT MAP(en, dataIn, clk, reset, txDone, txData, txnow, finished);
END behav;