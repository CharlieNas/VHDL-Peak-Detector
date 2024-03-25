LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE work.common_pack.ALL;

ENTITY cmdA IS
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
  
    start: OUT STD_LOGIC;
    numWords: OUT BCD_ARRAY_TYPE(2 DOWNTO 0);
    dataReady: IN STD_LOGIC;
    byte: IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    seqDone: IN STD_LOGIC;
    
    enA: IN STD_LOGIC;
    doneA: OUT STD_LOGIC
  );
END cmdA;

ARCHITECTURE arch OF cmdA IS

  COMPONENT aInput
    PORT(
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
  END COMPONENT;
  
  for a_input: aInput USE ENTITY WORK.aInput(arch);
  
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
  
  FOR a_printer: printer USE ENTITY WORK.printer(arch);
  
  TYPE state_type IS (IDLE, N2, N1, N0, CARRIAGERETURN, LINEFEED, DATAPROC, STOREBYTE, HEX1, HEX2, SPACE);
  SIGNAL curState, nextState: state_type;
  -- signals for aInput
  SIGNAL enInput, doneInput, isA, isDigit, txNow_aInput: STD_LOGIC;
  SIGNAL txData_aInput: STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL digit: STD_LOGIC_VECTOR(3 DOWNTO 0);
  -- signals related to printer module
  SIGNAL dataPrint, txData_printer: STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL enPrint, donePrint, txNow_printer: STD_LOGIC;
  -- signals related to NNN register
  SIGNAL NNN: BCD_ARRAY_TYPE(2 DOWNTO 0);
  SIGNAL enN0, enN1, enN2: STD_LOGIC;
  -- signals related to data processor output registers
  SIGNAL storedByte: UNSIGNED(7 DOWNTO 0);
  SIGNAL storedSeqDone: STD_LOGIC:='0';
  SIGNAL enByteReg: STD_LOGIC;
  -- registered input signals
  SIGNAL enA_reg, dataReady_reg, seqDone_reg, doneInput_reg, isA_reg, isDigit_reg, donePrint_reg: STD_LOGIC;
  SIGNAL byte_reg: STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL digit_reg: STD_LOGIC_VECTOR(3 DOWNTO 0);
  
BEGIN
  a_input: aInput PORT MAP(clk, reset, rxDone, rxData, rxNow, ovErr, framErr, txData_aInput, txNow_aInput, txDone, enInput, doneInput, isA, isDigit, digit);
  a_printer: printer PORT MAP(enPrint, dataPrint, clk, reset, txDone, txData_printer, txNow_printer, donePrint);
  
assign_tx: PROCESS(curState, txData_aInput, txNow_aInput, txData_printer, txNow_printer)
BEGIN
  IF curState=N0 OR curState=N1 OR curState=N2 THEN
    txData <= txData_aInput;
    txNow <= txNow_aInput;
  ELSE
    txData <= txData_printer;
    txNow <= txNow_printer;
  END IF;
END PROCESS;

store_NNN: PROCESS(clk)
  BEGIN
    IF clk'EVENT AND clk='1' THEN
      IF enN0='1' THEN
        NNN(0) <= digit_reg;
      ELSIF enN1='1' THEN
        NNN(1) <= digit_reg;
      ELSIF enN2='1' THEN
        NNN(2) <= digit_reg;
      END IF;
    END IF;
  END PROCESS;
  
  store_byte: PROCESS(clk)
  BEGIN
    IF clk'EVENT AND clk='1' THEN
      IF enByteReg='1' THEN
        storedByte <= UNSIGNED(byte_reg);
      END IF;
    END IF;
  END PROCESS;
  
  store_seqDone: PROCESS(clk)
  BEGIN
    IF clk'EVENT AND clk='1' THEN
      IF seqDone_reg='1' THEN
        storedSeqDone <= '1';
      END IF;
    END IF;
  END PROCESS;
  
  seq_input: PROCESS(clk)
  BEGIN
    IF clk'EVENT AND clk='1' THEN
      enA_reg <= enA;
      dataReady_reg <= dataReady;
      seqDone_reg <= seqDone;
      doneInput_reg <= doneInput;
      isA_reg <= isA;
      isDigit_reg <= isDigit;
      donePrint_reg <= donePrint;
      byte_reg <= byte;
      digit_reg <= digit;
    END IF;
  END PROCESS;
  
  seq_state: PROCESS(clk)
  BEGIN
    IF clk'EVENT AND clk='1' THEN
      IF reset='1' THEN
        curState <= IDLE;
      ELSE
        curState <= nextState;
      END IF;
    END IF;
  END PROCESS;
  
  combi_nextState: PROCESS(curState, enA_reg, doneInput_reg, isA_reg, isDigit_reg, digit_reg, donePrint_reg, dataReady_reg, storedSeqDone)
  BEGIN
    CASE curState IS
      WHEN IDLE =>
        IF enA_reg='1' THEN
          nextState <= N2;
        ELSE
          nextState <= IDLE;
        END IF;
        
      WHEN N2 =>
        IF doneInput_reg='1' THEN
          IF isA_reg='1' THEN
            nextState <= N2;
          ELSIF isDigit_reg='1' THEN
            nextState <= N1;
          ELSE
            nextState <= IDLE;
          END IF;
        ELSE
          nextState <= N2;
        END IF;
        
      WHEN N1 =>
        IF doneInput_reg='1' THEN
          IF isA_reg='1' THEN
            nextState <= N2;
          ELSIF isDigit_reg='1' THEN
            nextState <= N0;
          ELSE
            nextState <= IDLE;
          END IF;
        ELSE
          nextState <= N1;
        END IF;
        
      WHEN N0 =>
        IF doneInput_reg='1' THEN
          IF isA_reg='1' THEN
            nextState <= N2;
          ELSIF isDigit_reg='1' THEN
            nextState <= CARRIAGERETURN;
          ELSE
            nextState <= IDLE;
          END IF;
        ELSE
          nextState <= N0;
        END IF;
        
      WHEN CARRIAGERETURN =>
        IF donePrint_reg='1' THEN
          nextState <= LINEFEED;
        ELSE
          nextState <= CARRIAGERETURN;
        END IF;
      
      WHEN LINEFEED =>
        IF donePrint_reg='1' THEN
          nextState <= DATAPROC;
        ELSE
          nextState <= LINEFEED;
        END IF;
      
      WHEN DATAPROC =>
        IF dataReady_reg='1' THEN
          nextState <= STOREBYTE;
        ELSE
          nextState <= DATAPROC;
        END IF;
        
      WHEN STOREBYTE =>
        nextState <= HEX1;
        
      WHEN HEX1 =>
        IF donePrint_reg='1' THEN
          nextState <= HEX2;
        ELSE
          nextState <= HEX1;
        END IF;
      
      WHEN HEX2 =>
        IF donePrint_reg='1' THEN
          IF storedSeqDone='1' THEN
            nextState <= IDLE;
          ELSE
            nextState <= SPACE;
          END IF;
        ELSE
          nextState <= HEX2;
        END IF;
        
      WHEN SPACE =>
        IF donePrint_reg='1' THEN
          nextState <= DATAPROC;
        ELSE
          nextState <= SPACE;
        END IF;
        
      WHEN OTHERS =>
        nextState <= IDLE;
      
    END CASE;
  END PROCESS;
  
  combi_out: PROCESS(curState, enA_reg, doneInput_reg, isA_reg, isDigit_reg, digit_reg, donePrint_reg, dataReady_reg, storedByte, storedSeqDone)
  BEGIN
    enInput <= '0';
    enN0 <= '0';
    enN1 <= '0';
    enN2 <= '0';
    doneA <= '0';
    enPrint <= '0';
    dataPrint <= "00000000";
    start <= '0';
    numWords <= (OTHERS => "0000");
    enByteReg <= '0';
    
    CASE curState IS
      WHEN IDLE =>
        IF enA_reg='1' THEN
          enInput <= '1';
        END IF;
        
      WHEN N2 =>
        IF doneInput_reg='1' THEN
          IF isA_reg='1' THEN
            enInput <= '1';
          ELSIF isDigit_reg='1' THEN
            enInput <= '1';
            enN2 <= '1';
          ELSE
            doneA <= '1';
          END IF;
        END IF;
        
      WHEN N1 =>
        IF doneInput_reg='1' THEN
          IF isA_reg='1' THEN
            enInput <= '1';
          ELSIF isDigit_reg='1' THEN
            enInput <= '1';
            enN1 <= '1';
          ELSE
            doneA <= '1';
          END IF;
        END IF;
        
      WHEN N0 =>
        IF doneInput_reg='1' THEN
          IF isA_reg='1' THEN
            enInput <= '1';
          ELSIF isDigit_reg='1' THEN
            enN0 <= '1';
            enPrint <= '1';
            dataPrint <= "00001101";
          ELSE
            doneA <= '1';
          END IF;
        END IF;
        
      WHEN CARRIAGERETURN =>
        IF donePrint_reg='1' THEN
          enPrint <= '1';
          dataPrint <= "00001010";
        END IF;
      
      WHEN LINEFEED =>
        IF donePrint_reg='1' THEN
          start <= '1';
          numWords <= NNN;
        END IF;
      
      WHEN DATAPROC =>
        IF dataReady_reg='1' THEN
          enByteReg <= '1';
        END IF;
        
      WHEN STOREBYTE =>
        enPrint <= '1';
        IF storedByte(7 DOWNTO 4) >= "1010" AND storedByte(7 DOWNTO 4) <= "1111" THEN
          dataPrint <= STD_LOGIC_VECTOR(storedByte(7 DOWNTO 4) + "00110111");
        ELSE
          dataPrint <= STD_LOGIC_VECTOR(storedByte(7 DOWNTO 4) + "00110000");
        END IF;
        
      WHEN HEX1 =>
        IF donePrint_reg='1' THEN
          enPrint <= '1';
          IF storedByte(3 DOWNTO 0) >= "1010" AND storedByte(3 DOWNTO 0) <= "1111" THEN
            dataPrint <= STD_LOGIC_VECTOR(storedByte(3 DOWNTO 0) + "00110111");
          ELSE
            dataPrint <= STD_LOGIC_VECTOR(storedByte(3 DOWNTO 0) + "00110000");
          END IF;
        END IF;
      
      WHEN HEX2 =>
        IF donePrint_reg='1' THEN
          IF storedSeqDone='1' THEN
            doneA <= '1';
          ELSE
            enPrint <= '1';
            dataPrint <= "00100000";
          END IF;
        END IF;
        
      WHEN SPACE =>
        IF donePrint_reg='1' THEN
          start <= '1';
        END IF;
      
    END CASE;
  END PROCESS;
END arch;

