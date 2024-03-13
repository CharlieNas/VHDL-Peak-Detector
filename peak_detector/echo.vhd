LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.common_pack.ALL;

ENTITY echo IS
PORT (
  clk : IN STD_ULOGIC;
  reset : IN STD_ULOGIC;
  enEcho : IN STD_ULOGIC;
  doneEcho : OUT STD_ULOGIC;
  
  rxDone: OUT STD_ULOGIC;
  rxData:	IN STD_ULOGIC_VECTOR(7 downto 0);
 
  txData:	OUT STD_ULOGIC_VECTOR(7 downto 0);
  txNow: OUT STD_ULOGIC;
  txDone: IN STD_ULOGIC);
END echo;

ARCHITECTURE echo_arch OF echo IS
  TYPE state_type IS (IDLE, READY, PRINT);
  SIGNAL curState, nextState: state_type;
  SIGNAL enEcho_reg, txDone_reg: STD_ULOGIC;
  SIGNAL rxData_reg: STD_ULOGIC_VECTOR(7 downto 0);
  
BEGIN
  
  seq_input: PROCESS(clk)
  BEGIN
    IF clk'EVENT AND clk='1' THEN
      enEcho_reg <= enEcho;
      txDone_reg <= txDone;
      rxData_reg <= rxData;
    END IF;
  END PROCESS;

  seq_state: PROCESS (clk, reset)
  BEGIN
    IF clk'EVENT AND clk='1' THEN
      IF reset = '1' THEN
        curState <= IDLE;
      ELSE
        curState <= nextState;
      END IF;
    END IF;
  END PROCESS;
  
  combi_nextState: PROCESS(curState, enEcho_reg, txDone_reg)
  BEGIN
    CASE curState IS
      WHEN IDLE =>
        IF enEcho_reg = '1' THEN
          nextState <= READY;
        ELSE
          nextState <= IDLE;
        END IF;
        
      WHEN READY =>
        IF txDone_reg = '1' THEN
          nextState <= PRINT;
        ELSE
          nextState <= READY;
        END IF;
        
      WHEN OTHERS =>
        nextState <= IDLE;
    END CASE;
  END PROCESS;
  
  combi_out: PROCESS(curState, enEcho_reg, txDone_reg, rxData_reg)
  BEGIN
    doneEcho <= '0';
    txData <= "00000000";
    txNow <= '0';
    IF curState = READY AND txDone_reg = '1' THEN
      txData <= rxData_reg;
      txNow <= '1';
      rxDone <= '1';
    ELSIF curState = PRINT THEN
      doneEcho <= '1';
    END IF;
  END PROCESS;
  
END echo_arch;