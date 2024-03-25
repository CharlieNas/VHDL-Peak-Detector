library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
--use UNISIM.VPKG.ALL;

ENTITY tb_cmdA IS END;

ARCHITECTURE behav OF tb_cmdA IS
  COMPONENT cmdA 
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
  END COMPONENT;
  
  FOR t_cmdA: cmdA USE ENTITY WORK.cmdA(arch);
  
  -- inputs
  SIGNAL clk, reset, ovErr, framErr, dataReady, seqDone, enA: STD_LOGIC :='0';
  SIGNAL rxNow, txDone: STD_LOGIC := '1';
  SIGNAL rxData, byte: STD_LOGIC_VECTOR(7 DOWNTO 0) :="00000000";
  -- outputs
  SIGNAL rxDone, txNow, start, doneA: STD_LOGIC;
  SIGNAL txData: STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL numWords: BCD_ARRAY_TYPE(2 DOWNTO 0);
  -- test receiver
  TYPE state_type IS (R1, R2, R3, R4, R5, R6, R7, R8, R9, V1, V2, V3, V4, V5, V6, V7, V8, V9);
  SIGNAL curState, nextState: state_type;
BEGIN
  t_cmdA: cmdA PORT MAP(clk, reset, rxDone, rxData, rxNow, ovErr, framErr, txData, txNow, txDone, start, numWords, dataReady, byte, seqDone, enA, doneA);

  -- generate clk
  clk <= NOT clk AFTER 50 ns WHEN NOW < 40 us ELSE clk;
  
  reset <= '1',
    '0' AFTER 100 ns;
  
  enA <= '0',
    '1' AFTER 350 ns,
    '0' AFTER 450 ns;
    
  dataReady <= '0',
    '1' AFTER 26050 ns,
    '0' AFTER 26150 ns,
    '1' AFTER 30050 ns,
    '0' AFTER 30150 ns;
    
  byte <= "00000000",
    "01011111" AFTER 26050 ns,
    "00000000" AFTER 26150 ns,
    "10110011" AFTER 30050 ns,
    "00000000" AFTER 30150 ns;
    
  seqDone <= '0',
    '1' AFTER 30050 ns,
    '0' AFTER 30150 ns;
  
  transmitter: PROCESS(txNow)
  BEGIN
    IF txNow='1' THEN
      txDone <= '0',
        '1' AFTER 1000 ns;
    END IF;
  END PROCESS;
  
  seq_receiver: PROCESS(clk)
  BEGIN
    IF clk'EVENT AND clk='1' THEN
      IF reset='1' THEN
        curState <= R1;
      ELSE
        curState <= nextState;
      END IF;
    END IF;
  END PROCESS;
  
  combi_receiver: PROCESS(curState, rxDone)
  BEGIN
    CASE curState IS
      WHEN R1 =>
        nextState <= V1 AFTER 1 us;
        rxNow <= '0';
      WHEN V1 =>
        IF rxDone='1' THEN
          nextState <= R2;
        END IF;
        rxNow <= '1';
        rxData <= "01100001";
      WHEN R2 =>
        nextState <= V2 AFTER 1 us;
        rxNow <= '0';
      WHEN V2 =>
        IF rxDone='1' THEN
          nextState <= R3;
        END IF;
        rxNow <= '1';
        rxData <= "00110011";
      WHEN R3 =>
        nextState <= V3 AFTER 1 us;
        rxNow <= '0';
      WHEN V3 =>
        IF rxDone='1' THEN
          nextState <= R4;
        END IF;
        rxNow <= '1';
        rxData <= "01000001";
      WHEN R4 =>
        nextState <= V4 AFTER 1 us;
        rxNow <= '0';
      WHEN V4 =>
        IF rxDone='1' THEN
          nextState <= R5;
        END IF;
        rxNow <= '1';
        rxData <= "00110110";
      WHEN R5 =>
        nextState <= V5 AFTER 1 us;
        rxNow <= '0';
      WHEN V5 =>
        IF rxDone='1' THEN
          nextState <= R6;
        END IF;
        rxNow <= '1';
        rxData <= "00110010";
      WHEN R6 =>
        nextState <= V6 AFTER 1 us;
        rxNow <= '0';
      WHEN V6 =>
        IF rxDone='1' THEN
          nextState <= R7;
        END IF;
        rxNow <= '1';
        rxData <= "01100001";
      WHEN R7 =>
        nextState <= V7 AFTER 1 us;
        rxNow <= '0';
      WHEN V7 =>
        IF rxDone='1' THEN
          nextState <= R8;
        END IF;
        rxNow <= '1';
        rxData <= "00110100";
      WHEN R8 =>
        nextState <= V8 AFTER 1 us;
        rxNow <= '0';
      WHEN V8 =>
        IF rxDone='1' THEN
          nextState <= R9;
        END IF;
        rxNow <= '1';
        rxData <= "00110001";
      WHEN R9 =>
        nextState <= V9 AFTER 1 us;
        rxNow <= '0';
      WHEN V9 =>
        IF rxDone='1' THEN
          nextState <= R1;
        END IF;
        rxNow <= '1';
        rxData <= "00111001";
      WHEN OTHERS =>
        nextState <= R1;
    END CASE;
  END PROCESS;
  
END behav;