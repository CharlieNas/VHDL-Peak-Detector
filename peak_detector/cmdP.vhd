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
        en:         in std_logic;                           --i
        peakByte:   in std_logic_vector (7 downto 0);       --i
        maxIndex:   in BCD_ARRAY_TYPE(2 downto 0);          --i
        txdone:		in std_logic;                           --i
        txData:	    out std_logic_vector (7 downto 0);      --o
        txnow:		out std_logic;                          --o
        doneP:       out std_logic                           --o
    );
END cmdP;

ARCHITECTURE arch of cmdP IS
    TYPE state_type IS (IDLE, PRINTING, WAITING);
    SIGNAL curState, nextState: state_type;
    
    TYPE ASCII_SEQUENCE IS array (0 to 7) of std_logic_vector (7 downto 0);
    SIGNAL fullData: ASCII_SEQUENCE;
    
    SIGNAL enP_reg, print_en, finished: STD_LOGIC;
    SIGNAL b_index: natural := 0; --byte index
    SIGNAL peakByte_reg : STD_LOGIC_VECTOR (7 downto 0);
    SIGNAL maxIndex_reg: BCD_ARRAY_TYPE(2 downto 0);
    SIGNAL dataIn : STD_LOGIC_VECTOR (7 downto 0);
    SIGNAL finished_reg: STD_LOGIC;
    COMPONENT printer IS
        PORT(
            en, clk, reset, txdone : in std_logic;
            dataIn: in std_logic_vector(7 downto 0);
            txData: out std_logic_vector(7 downto 0);
            txnow, finished: out std_logic
            );
    END COMPONENT;
    
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
    
BEGIN
     -----------------------------------------------------

    pr: printer port map (print_en, clk, reset, txdone, dataIn, txData, txnow, finished);
    
    -----------------------------------------------------
    combi_nextState: PROCESS(curState, enP_reg, finished_reg)
    BEGIN
        CASE curState is
            WHEN IDLE =>
                IF enP_reg = '1' THEN
                    nextState <= PRINTING;
                ELSE
                    nextState <= IDLE;
                END IF;   
            WHEN PRINTING =>
                nextState <= WAITING;
            WHEN WAITING =>
                IF finished_reg = '1' THEN
                    IF b_index = 8 THEN
                        nextState <= IDLE;
                    ELSE
                        nextState <= PRINTING;
                    END IF;
                ELSE
                    nextState <= WAITING;
                END IF; 
            WHEN OTHERS =>
                nextState <= IDLE;
        END CASE;
    END PROCESS;
    -----------------------------------------------------
    combi_out: PROCESS(curState, finished_reg)
    BEGIN
        doneP <= '0';
        print_en <= '0';
        IF curState = IDLE THEN
            b_index <= 0;
        ELSIF curState = PRINTING THEN
            print_en <= '1';
            dataIn <= fullData(b_index);
            b_index <= b_index + 1;
        ELSIF curState = WAITING AND finished_reg = '1' THEN
            IF b_index = 8 THEN
                doneP <= '1';
                b_index <= 0;
            END IF;
        END IF;
    END PROCESS; -- combi_output
  -----------------------------------------------------
    combi_in: PROCESS(clk)
    BEGIN
	    IF clk'event AND clk='1' THEN
	           enP_reg <= en;
	           peakByte_reg <= peakByte;
	           maxIndex_reg <= maxIndex;
	           finished_reg <= finished;
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
    BEGIN
        IF curState = IDLE AND enP_reg = '1' THEN
            fullData(0) <= NIB_TO_ASCII(peakByte_reg(7 DOWNTO 4));  -- 16^1 char: first
            fullData(1) <= NIB_TO_ASCII(peakByte_reg(3 DOWNTO 0));  -- 16^0 char: second
            fullData(2) <= "00100000";                              -- " "  char: third
            fullData(3) <= NIB_TO_ASCII(maxIndex(2));               -- 10^2 char: fourth
            fullData(4) <= NIB_TO_ASCII(maxIndex(1));               -- 10^1 char: fitfh
            fullData(5) <= NIB_TO_ASCII(maxIndex(0));               -- 10^0 char: sixth
            fullData(6) <= "00001010";                              -- Line Feed (\n): seventh
            fullData(7) <= "00001101";                              -- Carriage Return (\r): eighth
        END IF;
    END PROCESS; 
  -----------------------------------------------------
END arch;