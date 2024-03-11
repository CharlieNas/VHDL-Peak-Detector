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
    SIGNAL i: natural;

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
    
    BEGIN
    p1: printer port map(en, dataIn, clk, reset, txdone, txData, txnow, finished);
    -----------------------------------------------------
    combi_nextState: PROCESS(curState, enL, finished, i)
    BEGIN
        CASE curState IS
            WHEN IDLE =>
                IF enL = '1' THEN 
                    nextState <= CHAR2;
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
                IF i = 6 THEN 
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
    combi_out: PROCESS(curState, i, finished)
    VARIABLE halfByte : unsigned (7 downto 0);
    BEGIN
        doneL <= '0';
        en <= '0';
        IF curState = CHECK AND i = 6 THEN
            doneL <= '1';
            i <= 0;
        ELSIF curState = CHAR2 AND finished = '1' THEN
            i <= i + 1;
        ELSIF curState = CHAR1 THEN
            halfByte(3 downto 0) := unsigned(dataResults(i)(7 downto 4));
            IF halfByte >= 10 THEN
                dataIn <= std_logic_vector(halfByte + 55);
            ELSE 
                dataIn <= std_logic_vector(halfByte + 48);
            en <= '1';
            END IF;
        ELSIF curState = CHAR2 THEN
            halfByte(3 downto 0) := unsigned(dataResults(i)(3 downto 0));
            IF halfByte >= 10 THEN
                dataIn <= std_logic_vector(halfByte + 55);
            ELSE 
                dataIn <= std_logic_vector(halfByte + 48);
            en <= '1';
            END IF;
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