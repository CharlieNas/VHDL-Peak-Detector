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
  framErr: IN STD_LOGIC;
  
  txData: OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
  txNow: OUT STD_LOGIC;
  txDone: IN STD_LOGIC;
  
  enInput: IN STD_LOGIC;
  doneInput: OUT STD_LOGIC;
  isA: OUT STD_LOGIC;
  isDigit: OUT STD_LOGIC;
  digit: OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
);
END aInput;

ARCHITECTURE arch OF aInput IS

  COMPONENT printer
    PORT (
      en:           in std_logic;                           --i
      dataIn:       in std_logic_vector (7 downto 0);       --i
      clk:		    in std_logic;                           --i
      reset:		in std_logic;                           --i
      txDone:		in std_logic;                           --i
      txData:	    out std_logic_vector (7 downto 0);      --o
      txNow:		out std_logic;                          --o
      finished:     out std_logic                           --o
    );
  END COMPONENT;
    
  FOR aInput_printer: printer USE ENTITY WORK.printer(arch);

  TYPE state_type IS (IDLE, READY, ECHO, CHECK);
  SIGNAL curState, nextState: state_type;
  -- signals for register holding input character
  SIGNAL enN: STD_LOGIC;
  SIGNAL curN: UNSIGNED(7 DOWNTO 0);
  -- signals related to printer module
  SIGNAL dataPrint: STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL enPrint, donePrint: STD_LOGIC;
  -- registered input signals
  SIGNAL enInput_reg, ovErr_reg, framErr_reg, rxNow_reg, donePrint_reg: STD_LOGIC;
  SIGNAL rxData_reg: STD_LOGIC_VECTOR(7 DOWNTO 0);
  
BEGIN
  aInput_printer: printer PORT MAP(enPrint, dataPrint, clk, reset, txDone, txData, txNow, donePrint);

  store_N: PROCESS(clk)
  BEGIN
    IF clk'EVENT AND clk='1' THEN
      IF enN = '1' THEN
        curN <= UNSIGNED(rxData);
      END IF;
    END IF;
  END PROCESS;
  
  digit <= STD_LOGIC_VECTOR(curN(3 DOWNTO 0));
  
  seq_input: PROCESS(clk)
  BEGIN
    IF clk'EVENT AND clk='1' THEN
      enInput_reg <= enInput; 
      ovErr_reg <= ovErr;
      framErr_reg <= framErr;
      rxNow_reg <= rxNow;
      rxData_reg <= rxData;
      donePrint_reg <= donePrint;
    END IF;
  END PROCESS;
  
  seq_state: PROCESS(clk)
  BEGIN
    IF clk'EVENT AND clk='1' THEN
      IF reset='1' THEN
        curState <= IDLE ;
      ELSE
        curState <= nextState;
      END IF;
    END IF;
  END PROCESS;
  
  combi_nextState: PROCESS(curState, enInput_reg, ovErr_reg, framErr_reg, rxNow_reg, rxData_reg, donePrint_reg)
  BEGIN
    CASE curState IS
      WHEN IDLE =>
        IF enInput_reg='1' THEN
          nextState <= READY;
        ELSE
          nextState <= IDLE;
        END IF;
        
      WHEN READY =>
        IF rxNow_reg='1' THEN
          nextState <= ECHO;
        ELSE
          nextState <= READY;
        END IF;
        
      WHEN ECHO =>
        IF donePrint_reg='1' THEN
          nextState <= CHECK;
        ELSE
          nextState <= ECHO;
        END IF;
        
      WHEN OTHERS =>
        nextState <= IDLE;
      
    END CASE;
  END PROCESS;
  
  combi_out: PROCESS(curState, enInput_reg, ovErr_reg, framErr_reg, rxNow_reg, rxData_reg, donePrint_reg)
  BEGIN
    enN <= '0';
    dataPrint <= "00000000";
    enPrint <= '0';
    isA <= '0';
    isDigit <= '0';
    doneInput <= '0';
    rxDone <= '0';
    
    CASE curState IS
      WHEN READY =>
        IF rxNow_reg='1' THEN
          enN <= '1';
          dataPrint <= rxData_reg;
          enPrint <= '1';
        END IF;
        
      WHEN CHECK =>
        rxDone <= '1';
        doneInput <= '1';
        IF curN = "01000001" OR curN = "01100001" THEN
          isA <= '1';
        ELSIF curN >= "00110000" AND curN <= "00111001" THEN
          isDigit <= '1';
        END IF;
      WHEN OTHERS =>
    END CASE;
  END PROCESS;
END arch;