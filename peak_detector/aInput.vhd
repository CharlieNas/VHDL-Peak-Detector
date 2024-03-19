LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.common_pack.ALL;

ENTITY aInput IS
PORT (
  clk: IN STD_LOGIC;
  reset: IN STD_LOGIC;
  
  rxDone: OUT STD_LOGIC;
  rxData: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
  rxNow: IN STD_LOGIC;
  ovErr: IN STD_LOGIC;
  framErr: IN STD_LOGIC
  
  en: IN STD_LOGIC;
  
);
END aInput;

ARCHITECTURE arch OF aInput IS
  TYPE state_type IS (IDLE, READY, ECHO1,...);
  SIGNAL curState, nextState: state_type;
  SIGNAL NNN_reg: BCD_ARRAY_TYPE(2 DOWNTO 0);
  SIGNAL curN: STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL enN: STD_LOGIC;
  
BEGIN
  store_N: PROCESS(clk)
  BEGIN
    IF clk'EVENT AND clk='1' THEN
      IF enN = '1' THEN
        curN <= rxData;
      END IF;
    END IF;
  END PROCESS;
  
  
END aInput;