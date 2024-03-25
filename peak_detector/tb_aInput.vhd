LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY tb_aInput IS END;

ARCHITECTURE behav OF tb_aInput IS
  COMPONENT aInput 
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
    validInput: OUT STD_LOGIC
  );
  END COMPONENT;
  
  FOR t_aInput: aInput USE ENTITY WORK.aInput(arch);
  
  -- inputs
  SIGNAL clk, reset, rxNow, ovErr, framErr, txDone, enInput: STD_LOGIC :='0';
  SIGNAL rxData: STD_LOGIC_VECTOR(7 DOWNTO 0) :="00000000";
  -- outputs
  SIGNAL rxDone, txNow, doneInput, validInput: STD_LOGIC;
  SIGNAL txData: STD_LOGIC_VECTOR(7 DOWNTO 0);
  -- test signal
  SIGNAL test: STD_LOGIC_VECTOR(7 DOWNTO 0);

BEGIN
  -- generate clk
  clk <= NOT clk AFTER 50 ns WHEN NOW < 3 us ELSE clk; 
  
  reset <= '1',
    '0' AFTER 100 ns;
  
  enInput <= '0',
    '1' AFTER 350 ns,
    '0' AFTER 450 ns;
    
  ovErr <= '0',
    '1' AFTER 650 ns,
    '0' AFTER 750 ns;
  
  framErr <= '0',
    '1' AFTER 750 ns,
    '0' AFTER 850 ns;
    
  rxNow <= '0',
    '1' AFTER 650 ns;
  
  txDone <= '0',
    '1' AFTER 1350 ns;
    
  rxData <= "00111010";
    
  t_aInput: aInput PORT MAP(clk, reset, rxDone, rxData, rxNow, ovErr, framErr, txData, txNow, txDone, enInput, doneInput, validInput);
END behav;