library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
--use UNISIM.VPKG.ALL;

ENTITY cmdL IS
    PORT (  
      clk:		    IN std_logic;                           
      reset:		IN std_logic;       
      enL:           IN std_logic;
      dataResults:  IN CHAR_ARRAY_TYPE(0 TO RESULT_BYTE_NUM-1);                          
      txdone:		IN std_logic;                           
      txData:	    OUT std_logic_vector (7 DOWNTO 0);      
      txnow:		OUT std_logic;
      doneL:         OUT std_logic                     
    );
END cmdL;

ARCHITECTURE arch OF cmdL IS
    TYPE state_type IS (IDLE, CHAR1, CHAR2, CHECK, SPACE, PREP_CHAR1, PREP_CHAR2, PREP_SPACE, WAIT_CARRIAGE, CARRIAGE_RETURN, WAIT_LINE, LINE_FEED);
    SIGNAL curState, nextState: state_type; 
    SIGNAL dataIn: std_logic_vector (7 DOWNTO 0);
    SIGNAL finished: std_logic;
    SIGNAL en, en_count: std_logic;
    SIGNAL counter: natural;
    
    ---------------------------
    -- Component Definitions
    ---------------------------
    COMPONENT printer IS
        PORT(
            en:           IN std_logic;                           
            dataIn:       IN std_logic_vector (7 DOWNTO 0);       
            clk:		    IN std_logic;                          
            reset:		IN std_logic;                           
            txdone:		IN std_logic;                           
            txData:	    OUT std_logic_vector (7 DOWNTO 0);      
            txnow:		OUT std_logic;                          
            finished:     OUT std_logic   
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
    p1: printer PORT MAP(en, dataIn, clk, reset, txdone, txData, txnow, finished);

    ---------------------------
    -- Combinatorial Inputs
    ---------------------------
    combi_nextState: PROCESS(curState, enL, finished, counter)
    BEGIN
        CASE curState IS
            WHEN IDLE =>
                IF enL = '1' THEN 
                    nextState <= WAIT_CARRIAGE;
                ELSE 
                    nextState <= IDLE;
                END IF;
            WHEN WAIT_CARRIAGE => -- Prep printing for carriage return
                nextState <= CARRIAGE_RETURN;
            WHEN CARRIAGE_RETURN => -- Wait for carriage return to print
                IF finished = '1' THEN
                    nextState <= WAIT_LINE;
                ELSE
                    nextState <= CARRIAGE_RETURN;
                END IF; 
            WHEN WAIT_LINE =>
                nextState <= LINE_FEED;
            WHEN LINE_FEED =>
                IF finished = '1' THEN
                    nextState <= PREP_CHAR1;
                ELSE 
                    nextState <= LINE_FEED; 
                END IF;
            WHEN PREP_CHAR1 =>
                nextState <= CHAR1;
            WHEN CHAR1 =>
                IF finished = '1' THEN 
                    nextState <= PREP_CHAR2;
                ELSE 
                    nextState <= CHAR1;
                END IF;
            WHEN PREP_CHAR2 =>
                nextState <= CHAR2;
            WHEN CHAR2 => 
                IF finished = '1' THEN 
                    nextState <= CHECK;
                ELSE 
                    nextState <= CHAR2;
                END IF;
            WHEN CHECK =>
                IF counter = 7 THEN 
                    nextState <= IDLE;
                ELSE 
                    nextState <= PREP_SPACE;
                END IF;
            WHEN PREP_SPACE =>
                nextState <= SPACE;
            WHEN SPACE =>
                IF finished = '1' THEN 
                    nextState <= PREP_CHAR1;
                ELSE 
                    nextState <= SPACE;
                END IF;
            WHEN OTHERS =>
                nextState <= IDLE;         
        END case;
    END process;
    
    ---------------------------
    -- Combinatorial Outputs
    ---------------------------
    combi_out: PROCESS(curState, counter, dataResults)
    BEGIN
        doneL <= '0';
        en <= '0';
        en_count <= '0';
        dataIn <= "00000000";
        IF curState = CHECK AND counter = 7 THEN
            doneL <= '1'; 
        ELSIF curState = PREP_CHAR1 THEN
            dataIn <= NIB_TO_ASCII(dataResults(6 - counter)(7 downto 4));
            en <= '1';
        ELSIF curState = PREP_CHAR2 THEN
            dataIn <= NIB_TO_ASCII(dataResults(6 - counter)(3 downto 0));
            en <= '1';
            en_count <= '1';
        ELSIF curState = PREP_SPACE THEN
            dataIn <= "00100000";
            en <= '1';
        ELSIF curState =  WAIT_CARRIAGE THEN -- Prep printing for carriage return
            dataIn <= "00001101";
            en <= '1';
        ELSIF curState =  WAIT_LINE THEN -- Prep printing for line feed
            dataIn <= "00001010";
            en <= '1';
        END IF;
    END PROCESS; -- combi_output
    
    ---------------------------
    -- Sequential counting
    ---------------------------
    counting: PROCESS(clk)
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF reset = '1' THEN
                counter <= 0;
            ELSIF curState = IDLE THEN
                counter <= 0;
            ELSIF en_count = '1' THEN 
                counter <= counter + 1;
            END IF;
        END IF;
    END PROCESS;
    
    ---------------------------
    -- Sequential state updating
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
    END PROCESS; 
END arch; 
