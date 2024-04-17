library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

ENTITY cmdP IS
    PORT (
        clk:		IN std_logic;                           --i
        reset:		IN std_logic;                           --i
        en:         IN std_logic;                           --i
        peakByte:   IN std_logic_vector (7 DOWNTO 0);       --i
        maxIndex:   IN BCD_ARRAY_TYPE(2 DOWNTO 0);          --i
        txdone:		IN std_logic;                           --i
        txData:	    OUT std_logic_vector (7 DOWNTO 0);      --o
        txnow:		OUT std_logic;                          --o
        doneP:      OUT std_logic                           --o
    );
END cmdP;

ARCHITECTURE arch OF cmdP IS
    TYPE state_type IS (IDLE, PRINTING, WAITING, FINAL);
    SIGNAL curState, nextState: state_type;
    
    TYPE ASCII_SEQUENCE IS ARRAY (0 TO 7) OF std_logic_vector (7 DOWNTO 0);
    SIGNAL fullData: ASCII_SEQUENCE;
    
    SIGNAL enP_reg, print_en, finished: STD_LOGIC;
    SIGNAL b_index_en, b_index_reset, fulldata_en  : STD_LOGIC;
    SIGNAL b_index: UNSIGNED(3 DOWNTO 0) := "0000"; --byte index
    SIGNAL peakByte_reg : STD_LOGIC_VECTOR (7 DOWNTO 0);
    SIGNAL maxIndex_reg: BCD_ARRAY_TYPE(2 DOWNTO 0);
    SIGNAL dataIn : STD_LOGIC_VECTOR (7 DOWNTO 0);
    SIGNAL finished_reg: STD_LOGIC;
    
    ---------------------------
    -- Component Definitions
    ---------------------------
    COMPONENT printer IS
        PORT(
            en, clk, reset, txdone : IN std_logic;
            dataIn: IN std_logic_vector(7 DOWNTO 0);
            txData: OUT std_logic_vector(7 DOWNTO 0);
            txnow, finished: OUT std_logic
            );
    END COMPONENT;
    
    ---------------------------
    -- Function to convert nibble to ASCII
    ---------------------------
    FUNCTION NIB_TO_ASCII ( -- NIB_TO_ASCII: Converts a 4-bit nibble representation of a hex digit to its 8-bit ASCII equivalent.
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
    pr: printer PORT MAP (print_en, clk, reset, txdone, dataIn, txData, txnow, finished);
    
    ---------------------------
    -- Combinatorial Inputs
    ---------------------------
    combi_nextState: PROCESS(curState, enP_reg, finished_reg, b_index)
    BEGIN
        CASE curState IS
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
                        nextState <= FINAL;
                    ELSE
                        nextState <= PRINTING;
                    END IF;
                ELSE
                    nextState <= WAITING;
                END IF;
            WHEN FINAL =>
                    nextState <= IDLE;
            WHEN OTHERS =>
                nextState <= IDLE;
        END CASE;
    END PROCESS;
    
    ---------------------------
    -- Combinatorial Outputs
    ---------------------------
    combi_out: PROCESS(curState, finished_reg, enP_reg, fullData, b_index)
    BEGIN
        doneP <= '0';
        print_en <= '0';
        b_index_en <= '0';
        b_index_reset <= '0';
        fullData_en <= '0';
        dataIn <= "00000000";
        IF curState = IDLE THEN
            IF enP_reg <= '1' THEN
                fullData_en <= '1';
            END IF;
        ELSIF curState = PRINTING THEN
            print_en <= '1';
            dataIn <= fullData(TO_INTEGER(b_index));
            b_index_en <= '1';
        ELSIF curState = FINAL THEN
            doneP <= '1';
            b_index_reset <= '1';
        END IF;
    END PROCESS; -- combi_output
    
    ---------------------------
    -- Input registering
    ---------------------------
    seq_in: PROCESS(clk)
    BEGIN
	    IF clk'event AND clk='1' THEN
	           enP_reg <= en;
	           peakByte_reg <= peakByte;
	           maxIndex_reg <= maxIndex;
	           finished_reg <= finished;
	    END IF;
	  END PROCESS; -- seq_input
	  
    ---------------------------
    -- Change current state
    ---------------------------
    seq_state: PROCESS (clk)
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF reset = '1' THEN
                curState <= IDLE;
            ELSE
                curState <= nextState;
            END IF;
        END IF;
    END PROCESS; -- seq_state
    
    ---------------------------
    -- Counter for b_index
    ---------------------------
    b_index_counter: PROCESS(clk)
    BEGIN
		IF clk'EVENT and clk='1' THEN
            IF reset = '1' OR b_index_reset = '1' THEN -- active high reset
                b_index <= "0000";
		    ELSIF b_index_en = '1' THEN -- enable
		        b_index <= b_index + 1;
		    END IF;
		END IF;
    END PROCESS; -- b_index_counter
    
    
    ---------------------------
    -- Full data sequential management
    ---------------------------
    format_chars: PROCESS (clk)
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF reset = '1' THEN
                fullData(0) <= "00000000";
                fullData(1) <= "00000000";
                fullData(2) <= "00000000";
                fullData(3) <= "00000000";
                fullData(4) <= "00000000";
                fullData(5) <= "00000000";
                fullData(6) <= "00000000";
                fullData(7) <= "00000000";
            ELSIF fullData_en = '1' THEN
                fullData(0) <= "00001010";                              -- Line Feed (\n): seventh
                fullData(1) <= "00001101";                              -- Carriage Return (\r): eighth
                fullData(2) <= NIB_TO_ASCII(peakByte_reg(7 DOWNTO 4));  -- 16^1 char: first
                fullData(3) <= NIB_TO_ASCII(peakByte_reg(3 DOWNTO 0));  -- 16^0 char: second
                fullData(4) <= "00100000";                              -- " "  char: third
                fullData(5) <= NIB_TO_ASCII(maxIndex_reg(2));               -- 10^2 char: fourth
                fullData(6) <= NIB_TO_ASCII(maxIndex_reg(1));               -- 10^1 char: fitfh
                fullData(7) <= NIB_TO_ASCII(maxIndex_reg(0));               -- 10^0 char: sixth
            END IF;
        END IF;
    END PROCESS; -- format_chars
END arch;
