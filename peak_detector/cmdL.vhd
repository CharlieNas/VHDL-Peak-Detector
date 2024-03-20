library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
--use UNISIM.VPKG.ALL;

entity cmdL is
    port (  
      clk:		    in std_logic;                           
      reset:		in std_logic;       
      enL:           in std_logic;
      dataResults:  in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);                          
      txdone:		in std_logic;                           
      txData:	    out std_logic_vector (7 downto 0);      
      txnow:		out std_logic;
      doneL:         out std_logic                     
    );
end cmdL;

architecture arch of cmdL is
    TYPE state_type IS (IDLE, CHAR1, CHAR2, CHECK, SPACE);
    SIGNAL curState, nextState: state_type; 
    SIGNAL dataIn: std_logic_vector (7 downto 0);
    SIGNAL finished: std_logic;
    SIGNAL en: std_logic;
    SIGNAL i: natural := 0;

    -----------------------------------------------------
    COMPONENT printer IS
        port(
            en:           in std_logic;                           
            dataIn:       in std_logic_vector (7 downto 0);       
            clk:		    in std_logic;                          
            reset:		in std_logic;                           
            txdone:		in std_logic;                           
            txData:	    out std_logic_vector (7 downto 0);      
            txnow:		out std_logic;                          
            finished:     out std_logic   
        );
    END COMPONENT;
    -----------------------------------------------------
    -- NIB_TO_ASCII: Converts a 4-bit nibble representation of a hex digit to its 8-bit ASCII equivalent.
    FUNCTION NIB_TO_ASCII (
        v_in: IN STD_LOGIC_VECTOR(3 DOWNTO 0))
        RETURN STD_LOGIC_VECTOR IS
        VARIABLE v_temp: UNSIGNED(7 DOWNTO 0);
        VARIABLE v_out: STD_LOGIC_VECTOR(7 DOWNTO 0);
    BEGIN
        v_temp := "0000" & UNSIGNED(v_in);
        IF v_temp >= 10 THEN
            v_temp := v_temp + X"37"; -- Add 55, offset to A-Z
        ELSE
            v_temp := v_temp + X"30"; -- Add 48, offset to 0-9
        END IF;
        v_out := STD_LOGIC_VECTOR(v_temp);
        RETURN v_out;
    END NIB_TO_ASCII;
    -----------------------------------------------------
    BEGIN
    p1: printer port map(en, dataIn, clk, reset, txdone, txData, txnow, finished);
    -----------------------------------------------------
    combi_nextState: PROCESS(curState, enL, finished, i)
    BEGIN
        CASE curState IS
            WHEN IDLE =>
                IF enL = '1' THEN 
                    nextState <= CHAR1;
                ELSE 
                    nextState <= IDLE;
                END IF;
            WHEN CHAR1 =>
                IF finished = '1' THEN 
                    nextState <= CHAR2;
                ELSE 
                    nextState <= CHAR1;
                END IF;
            WHEN CHAR2 => 
                IF finished = '1' THEN 
                    nextState <= CHECK;
                ELSE 
                    nextState <= CHAR2;
                END IF;
            WHEN CHECK =>
                IF i = 7 THEN 
                    nextState <= IDLE;
                ELSE 
                    nextState <= SPACE;
                END IF;
            WHEN SPACE =>
                IF finished = '1' THEN 
                    nextState <= CHAR1;
                END IF;
        END case;
    END process;
    -----------------------------------------------------
    combi_out: PROCESS(curState, nextState)
    VARIABLE halfByte : unsigned (7 downto 0) := "00000000";
    BEGIN
        doneL <= '0';
        en <= '0';
        IF curState = CHECK AND i = 7 THEN
            doneL <= '1';
            dataIn <= "00000000";
        ELSIF curState = CHAR2 AND nextState = CHECK and finished = '1' THEN
            i <= i + 1;
        ELSIF curState = CHAR1 THEN
            dataIn <= NIB_TO_ASCII(dataResults(i)(7 downto 4));
            en <= '1';
        ELSIF curState = CHAR2 THEN
            dataIn <= NIB_TO_ASCII(dataResults(i)(3 downto 0));
            en <= '1';
        ELSIF curState = SPACE THEN
            dataIn <= "00100000";
            en <= '1';
        ELSIF curState = IDLE and enL <= '1' THEN
            i <= 0;
        END IF;
    END PROCESS; -- combi_output
  -----------------------------------------------------
    seq_state: PROCESS (clk)
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF reset = '1' THEN
                curState <= IDLE;
            ELSE
                curState <= nextState;
            END IF;
        END IF;
    END PROCESS; 
  -----------------------------------------------------
END arch; 