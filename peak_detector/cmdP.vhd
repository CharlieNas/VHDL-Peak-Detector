library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
--use UNISIM.VPKG.ALL;

ENTITY cmdP IS
    PORT (
        clk:		in std_logic;                           --i
        reset:		in std_logic;                           --i
        enP:         in std_logic;                           --i
        peakByte:   in std_logic_vector (7 downto 0);       --i
        maxIndex:   in BCD_ARRAY_TYPE(2 downto 0);          --i
        txdone:		in std_logic;                           --i
        txData:	    out std_logic_vector (7 downto 0);      --o
        txnow:		out std_logic;                          --o
        done:       out std_logic                           --o
    );
END cmdP;

ARCHITECTURE arch of cmdP IS
    TYPE state_type IS (IDLE, FORMATTING, PRINTING, WAITING);
    SIGNAL curState, nextState: state_type; 
    SIGNAL enP_reg: STD_LOGIC;
    SIGNAL peakByte_reg : STD_LOGIC_VECTOR (7 downto 0);
    SIGNAL b_index: natural; --byte index
    SIGNAL en: STD_LOGIC;
    SIGNAL finished: STD_LOGIC;
    SIGNAL dataIn : STD_LOGIC_VECTOR (7 downto 0);
    SIGNAL fullData: std_logic_vector(47 downto 0);
    COMPONENT printer IS
        PORT(
            enp, clk, reset, txdone : in std_logic;
            dataIn: in std_logic_vector(7 downto 0);
            txData: out std_logic_vector(7 downto 0);
            txnow, finished: out std_logic
            );
    END COMPONENT;
    
BEGIN
     -----------------------------------------------------

    p1: printer port map (en, clk, reset, txdone, dataIn, txData, txnow, finished);
    
    -----------------------------------------------------
    combi_nextState: PROCESS(curState, enP_reg)
    BEGIN
        CASE curState is
            WHEN IDLE =>
                IF enP_reg = '1' THEN
                    nextState <= FORMATTING;
                ELSE
                    nextState <= IDLE;
                END IF;   
            WHEN FORMATTING =>
                nextState <= PRINTING;
            WHEN PRINTING =>
                nextState <= WAITING;
            WHEN WAITING =>
                IF finished = '1' AND b_index = 7 THEN
                    nextState <= IDLE;
                ELSE
                    nextState <= PRINTING;
                END IF;    
            WHEN OTHERS =>
                nextState <= IDLE;
        END CASE;
    END PROCESS;
    -----------------------------------------------------
    combi_out: PROCESS(curState)
    BEGIN
        done <= '0';
        en <= '0';
        IF curState = PRINTING THEN
            en <= '1';
            dataIn <= fullData(8*b_index-1 downto b_index);
            b_index <= b_index + 1;
        ELSIF curState = WAITING AND finished = '1' THEN
            IF b_index = 7 THEN
                done <= '1';
                b_index <= 0;
            END IF;
        END IF;
    END PROCESS; -- combi_output
  -----------------------------------------------------
    combi_in: PROCESS(clk)
    BEGIN
	    IF clk'event AND clk='1' THEN
	           en_reg <= en;
	           
	    END IF;
	  END PROCESS;
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
    format_chars: PROCESS (clk)
    VARIABLE half_byte: unsigned(7 downto 0);
    BEGIN
        FOR i IN 0 to 1 LOOP
            half_byte(3 downto 0) := unsigned(peakByte_reg(4*i+3 downto 4*i));
            IF half_byte >= 10 THEN
                half_byte := half_byte + 55;
            ELSE
                half_byte := half_byte + 48;             
            END IF;
            
            IF i = 1 THEN
                -- 16^0 digit: printed first
                fullData(7 downto 0) <= std_logic_vector(half_byte);
            ELSE
                -- 16^1 character: printed second
                fullData(15 downto 8) <= std_logic_vector(half_byte);
            END IF;
        END LOOP;
        fullData(23 downto 16) <= "00100000"; --space character: printed third
        FOR i IN 2 downto 0 LOOP
            half_byte(3 downto 0) := unsigned(maxIndex(i));
            half_byte := half_byte + 48;
            IF i = 2 THEN
                --Hundredth digit: printed fourth
                fullData(31 downto 24) <= std_logic_vector(half_byte);
            ELSIF i = 1 THEN
                --Tenth digit: printed fifth
                fullData(39 downto 32) <= std_logic_vector(half_byte);
            ELSE
                --Unit digit: printed sixth
                fullData(47 downto 40) <= std_logic_vector(half_byte);
            END IF;
            
        --END RESULT: FF 999 (example)
        END LOOP;   
    END PROCESS; 
  -----------------------------------------------------
END arch;

