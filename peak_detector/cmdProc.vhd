library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
-- use UNISIM.VPKG.ALL;

ENTITY cmdProc IS
    PORT (
      clk:		IN std_logic;                                    --i
      reset:		IN std_logic;                                --i
      rxnow:		IN std_logic;                                --i
      rxData:			IN std_logic_vector (7 DOWNTO 0);        --i
      txData:			OUT std_logic_vector (7 DOWNTO 0);       --o
      rxdone:		OUT std_logic;                               --o
      ovErr:		IN std_logic;                                --i
      framErr:	IN std_logic;                                    --i
      txnow:		OUT std_logic;                               --o
      txdone:		IN std_logic;                                --i
      start: OUT std_logic;                                      --o
      numWords_bcd: OUT BCD_ARRAY_TYPE(2 DOWNTO 0);              --o
      dataReady: IN std_logic;                                   --i
      byte: IN std_logic_vector(7 DOWNTO 0);                     --i
      maxIndex: IN BCD_ARRAY_TYPE(2 DOWNTO 0);                   --i
      dataResults: IN CHAR_ARRAY_TYPE(0 TO RESULT_BYTE_NUM-1);   --i
      seqDone: IN std_logic                                      --i
    );
end cmdProc;

ARCHITECTURE arch OF cmdProc IS
    TYPE state_type IS (INIT, RESTART, VALID, PRINT_A, PRINT_P, PRINT_L, PRINT_N2, PRINT_N1, PRINT_N0, N2, N1, N0, WAIT_CARRIAGE, CARRIAGE_RETURN, WAIT_LINE, LINE_FEED, WAIT_CARRIAGE2, CARRIAGE_RETURN2, WAIT_LINE2, LINE_FEED2, STARTING, DATAPROC, PREP_HEX1, HEX1, PREP_HEX2, HEX2, PREP_SPACE, SPACE, PREP_P, PREP_L, P, L);
    SIGNAL curState, nextState: state_type; 
    SIGNAL enP, enL, en: std_logic; 
    SIGNAL doneP, doneL, finished: std_logic;
    SIGNAL seq_Available: std_logic;
    -- Registered INPUTS
    SIGNAL rxNow_reg, txDone_reg, dataReady_reg, seqDone_reg: std_logic;
    SIGNAL rxData_reg, byte_reg, dataIn: std_logic_vector (7 DOWNTO 0);
    SIGNAL maxIndex_reg: BCD_ARRAY_TYPE(2 DOWNTO 0);  
    SIGNAL dataResults_reg: CHAR_ARRAY_TYPE(0 TO RESULT_BYTE_NUM-1);
    SIGNAL maxIndex_stored: BCD_ARRAY_TYPE(2 DOWNTO 0);  
    SIGNAL dataResults_stored: CHAR_ARRAY_TYPE(0 TO RESULT_BYTE_NUM-1);
    -- Enabling Registers
    SIGNAL en_NNN_2, en_NNN_1, en_NNN_0, en_storedByte, en_numWords: STD_LOGIC;
    SIGNAL NNN: BCD_ARRAY_TYPE(2 DOWNTO 0);
    SIGNAL NNN_val: STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL storedByte: UNSIGNED(7 DOWNTO 0);
    --signals for main:
    SIGNAL txnow_M: std_logic;
    SIGNAL txdata_M: std_logic_vector(7 DOWNTO 0);
    --signals for P
    SIGNAL txdata_P: std_logic_vector(7 DOWNTO 0);
    SIGNAL txnow_P: std_logic;
    --signals for L
    SIGNAL txdata_L: std_logic_vector(7 DOWNTO 0);
    SIGNAL txnow_L: std_logic;

    ---------------------------
    -- Component Definitions
    ---------------------------
    COMPONENT printer IS
        PORT (
          clk:		    IN std_logic;                               --i
          reset:		IN std_logic;                               --i
          en:           IN std_logic;                               --i
          dataIn:       IN std_logic_vector (7 DOWNTO 0);           --i
          txDone:		IN std_logic;                               --i
          txData:	    OUT std_logic_vector (7 DOWNTO 0);          --o
          txnow:		OUT std_logic;                              --o
          finished:     OUT std_logic                               --o
        );
    END COMPONENT printer;

    COMPONENT cmdP IS
        PORT (
            clk:		IN std_logic;                               --i
            reset:		IN std_logic;                               --i
            en:         IN std_logic;                               --i
            peakByte:   IN std_logic_vector (7 DOWNTO 0);           --i
            maxIndex:   IN BCD_ARRAY_TYPE(2 DOWNTO 0);              --i
            txdone:		IN std_logic;                               --i
            txData:	    OUT std_logic_vector (7 DOWNTO 0);          --o
            txnow:		OUT std_logic;                              --o
            doneP:      OUT std_logic                               --o
        );
    END COMPONENT cmdP;

    COMPONENT cmdL IS
        PORT (  
          clk:		    IN std_logic;                               --i
          reset:		IN std_logic;                               --i  
          enL:          IN std_logic;                               --i
          dataResults:  IN CHAR_ARRAY_TYPE(0 TO RESULT_BYTE_NUM-1); --i                       
          txdone:		IN std_logic;                               --i
          txData:	    OUT std_logic_vector (7 DOWNTO 0);          --o
          txnow:		OUT std_logic;                              --o    
          doneL:        OUT std_logic                               --o
        );
    END COMPONENT cmdL;


BEGIN
    print:     printer PORT MAP (clk, reset, en, dataIn, txDone, txData_M, txNow_M, finished);
    command_P: cmdP PORT MAP (clk, reset, enP, dataResults_stored(3), maxIndex_stored, txdone_reg, txData_P, txNow_P, doneP);
    command_L: cmdL PORT MAP (clk, reset, enL, dataResults_stored, txdone, txData_L, txNow_L, doneL);
    
    ---------------------------
    --  Multiple driver control
    ---------------------------
    assign_tx: PROCESS(curState, txNow_M, txNow_L, txNow_P, txData_M, txData_L, txData_P)
    BEGIN          
        IF curState = L THEN
            txData <= txData_L;
            txNow <= txNow_L;
        ELSIF curState = P THEN
            txData <= txData_P;
            txNow <= txNow_P;
        ELSE
            txData <= txData_M;
            txNow <= txNow_M;
        END IF;
    END PROCESS;
    

    ---------------------------
    -- Combinatorial Inputs
    ---------------------------
    combi_nextState: PROCESS(curState, rxnow_reg, rxData_reg, seq_Available, doneL, doneP, finished, dataReady_reg)
    BEGIN
        CASE curState IS
            ---------------------------------------------------------------------------------
            -- Central FSM
            ---------------------------------------------------------------------------------
            WHEN RESTART => -- Wait for printing after invalid input
                IF finished = '1' THEN 
                    nextState <= INIT;
                ELSE 
                    nextState <= RESTART;
                END IF;
            WHEN INIT => -- Wait for rxNow to give valid rx input
                IF rxNow_reg = '1' THEN
                    nextState <= VALID;
                ELSE 
                    nextState <= INIT;
                END IF; 
            WHEN VALID => -- Check if A/P/L or otherwise restart
                IF rxData_reg = "01000001" OR rxData_reg = "01100001" THEN
                    nextState <= PRINT_A;
                ELSIF (rxData_reg = "01010000" OR rxData_reg = "01110000") and seq_Available = '1' THEN
                    nextState <= PRINT_P;
                ELSIF (rxData_reg = "01001100" OR rxData_reg = "01101100") and seq_Available = '1' THEN
                    nextState <= PRINT_L;
                ELSE 
                    nextState <= RESTART;
                END IF;
            ---------------------------------------------------------------------------------
            -- A command Inputs
            ---------------------------------------------------------------------------------
            WHEN PRINT_A => -- Wait for A to print
                IF finished = '1' THEN
                    nextState <= N2;
                ELSE 
                    nextState <= PRINT_A;
                END IF;
            WHEN N2 => -- Wait for next input
                IF rxnow_reg = '1' THEN
                    nextState <= PRINT_N2;
                ELSE
                    nextState <= N2;
                END IF;
            WHEN PRINT_N2 =>
                IF finished = '1' THEN
                    IF rxData_reg <= "00111001" AND rxData_reg >= "00110000" THEN -- If received a digit
                        nextState <= N1;
                    ELSIF rxData_reg = "01000001" OR rxData_reg = "01100001" THEN  -- If received an A
                        nextState <= N2;
                    ELSIF (rxData_reg = "01010000" OR rxData_reg = "01110000") and seq_Available = '1' THEN -- If received a P
                        nextState <= PREP_P;
                    ELSIF (rxData_reg = "01001100" OR rxData_reg = "01101100") and seq_Available = '1' THEN -- If received an L
                        nextState <= PREP_L;
                    ELSE 
                        nextState <= INIT;
                    END IF;
                ELSE 
                    nextState <= PRINT_N2;
                END IF;
            WHEN N1 => -- Wait for next input
                IF rxnow_reg = '1' THEN
                    nextState <= PRINT_N1;
                ELSE
                    nextState <= N1;
                END IF;
            WHEN PRINT_N1 =>
                IF finished = '1' THEN
                    IF rxData_reg <= "00111001" AND rxData_reg >= "00110000" THEN -- If received a digit
                        nextState <= N0;
                    ELSIF rxData_reg = "01000001" OR rxData_reg = "01100001" THEN  -- If received an A
                        nextState <= N2;
                    ELSIF (rxData_reg = "01010000" OR rxData_reg = "01110000") and seq_Available = '1' THEN -- If received a P
                        nextState <= PREP_P;
                    ELSIF (rxData_reg = "01001100" OR rxData_reg = "01101100") and seq_Available = '1' THEN -- If received an L
                        nextState <= PREP_L;
                    ELSE 
                        nextState <= INIT;
                    END IF;
                ELSE 
                    nextState <= PRINT_N1;
                END IF;
            WHEN N0 => -- Wait for next input
                IF rxnow_reg = '1' THEN
                    nextState <= PRINT_N0;
                ELSE
                    nextState <= N0;
                END IF;
            WHEN PRINT_N0 =>
                IF finished = '1' THEN
                    IF rxData_reg <= "00111001" AND rxData_reg >= "00110000" THEN -- If received a digit
                        nextState <= WAIT_CARRIAGE;
                    ELSIF rxData_reg = "01000001" OR rxData_reg = "01100001" THEN  -- If received an A
                        nextState <= N2;
                    ELSIF (rxData_reg = "01010000" OR rxData_reg = "01110000") and seq_Available = '1' THEN -- If received a P
                        nextState <= PREP_P;
                    ELSIF (rxData_reg = "01001100" OR rxData_reg = "01101100") and seq_Available = '1' THEN -- If received an L
                        nextState <= PREP_L;
                    ELSE 
                        nextState <= INIT;
                    END IF;
                ELSE 
                    nextState <= PRINT_N0;
                END IF;
            ---------------------------------------------------------------------------------
            -- Carriage Return and Line Feed
            ---------------------------------------------------------------------------------
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
                    nextState <= STARTING;
                ELSE 
                    nextState <= LINE_FEED; 
                END IF;
            ---------------------------------------------------------------------------------
            -- Data Processor communication and bytes printed
            ---------------------------------------------------------------------------------
            WHEN STARTING => -- Set start and numWords
                nextState <= DATAPROC;
            WHEN DATAPROC => -- Wait for data from data Processor
                IF dataReady_reg='1' THEN
                  nextState <= PREP_HEX1;
                ELSE
                  nextState <= DATAPROC;
                END IF; 
            WHEN PREP_HEX1 => -- Prep printing for first Hex Digit
                nextState <= HEX1; 
            WHEN HEX1 => -- Wait for printing for first Hex Digit
                IF finished ='1' THEN
                  nextState <= PREP_HEX2;
                ELSE
                  nextState <= HEX1;
                END IF;
            WHEN PREP_HEX2 => -- Prep printing for first Hex Digit
                nextState <= HEX2;
            WHEN HEX2 => -- Wait for printing for second Hex Digit
                IF finished ='1' THEN
                    IF seq_Available ='1' THEN ----------------------------------------------------- 
                        nextState <= WAIT_CARRIAGE2;
                    ELSE
                        nextState <= PREP_SPACE;
                    END IF;
                ELSE
                  nextState <= HEX2;
                END IF;
            WHEN PREP_SPACE => -- Prep printing for space
                nextState <= SPACE;
            WHEN SPACE => -- Wait for space to be printed
                IF finished ='1' THEN
                    nextState <= STARTING;
                ELSE
                    nextState <= SPACE;
                END IF;
            ---------------------------------------------------------------------------------
            -- Carriage Return and Line Feed
            ---------------------------------------------------------------------------------
            WHEN WAIT_CARRIAGE2 => -- Prep printing for carriage return
                nextState <= CARRIAGE_RETURN2;
            WHEN CARRIAGE_RETURN2 => -- Wait for carriage return to print
                IF finished = '1' THEN
                    nextState <= WAIT_LINE2;
                ELSE
                    nextState <= CARRIAGE_RETURN2;
                END IF; 
            WHEN WAIT_LINE2 =>
                nextState <= LINE_FEED2;
            WHEN LINE_FEED2 =>
                IF finished = '1' THEN
                    nextState <= INIT;
                ELSE 
                    nextState <= LINE_FEED2; 
                END IF;
            ---------------------------------------------------------------------------------
            -- P and L commands
            ---------------------------------------------------------------------------------
            WHEN PRINT_P => -- Wait for valid P character to print
                IF finished = '1' THEN
                    nextState <= PREP_P;
                ELSE 
                    nextState <= PRINT_P;
                END IF;
            WHEN PRINT_L => -- Wait for valid L character to print
                IF finished = '1' THEN
                    nextState <= PREP_L;
                ELSE   
                    nextState <= PRINT_L;
                END IF;
            WHEN PREP_P =>
                nextState <= P;
            WHEN PREP_L =>
                nextState <= L;
            WHEN P => -- P component active
                IF doneP = '1' THEN
                    nextState <= WAIT_CARRIAGE2;
                ELSE
                    nextState <= P;
                END IF;
            WHEN L => -- L component active
                IF doneL = '1' THEN
                    nextState <= WAIT_CARRIAGE2;
                ELSE
                    nextState <= L;
                END IF;
            WHEN OTHERS =>
                nextState <= INIT;
        END CASE;
    END PROCESS;
    
    ---------------------------
    -- Combinatorial Outputs
    ---------------------------
    combi_out: PROCESS(curState, finished, rxData_reg, dataReady_reg, storedByte, rxNow_reg, seqDone_reg)
    BEGIN
        en <= '0';
        en_storedByte <= '0';
        enP <= '0';
        enL <= '0';
        en_NNN_2 <= '0';
        en_NNN_1 <= '0';
        en_NNN_0 <= '0';
        en_numWords <= '0';
        rxDone <= '0';
        start <= '0';
        NNN_val <= "0000";
        dataIn <= "00000000";
        CASE curState IS
            ---------------------------------------------------------------------------------
            -- Central FSM
            ---------------------------------------------------------------------------------
            WHEN VALID => -- Prep to echo initial input
                dataIn <= rxData_reg;
                en <= '1';
                rxDone <= '1';
            ---------------------------------------------------------------------------------
            -- A command Inputs
            ---------------------------------------------------------------------------------
            WHEN N2 => -- Prep to echo input, fill N_reg depending on input, if digit input fill NNN
                IF rxnow_reg = '1' THEN 
                    dataIn <= rxData_reg;
                    en <= '1';
                    IF rxData_reg <= "00111001" AND rxData_reg >= "00110000" THEN -- If received a digit
                        NNN_val <= rxData_reg(3 downto 0); -- Store first digit in NNN
                        en_NNN_2 <= '1';
                    END IF;
                END IF;
            WHEN N1 => -- Prep to echo input, fill N_reg depending on input, if digit input fill NNN
                IF rxnow_reg = '1' THEN 
                    dataIn <= rxData_reg;
                    en <= '1';
                    IF rxData_reg <= "00111001" AND rxData_reg >= "00110000" THEN -- If received a digit
                        NNN_val <= rxData_reg(3 downto 0); -- Store second digit in NNN
                        en_NNN_1 <= '1';
                    END IF;
                END IF;
            WHEN N0 => -- Prep to echo input, fill N_reg depending on input, if digit input fill NNN
                IF rxnow_reg = '1' THEN 
                    dataIn <= rxData_reg;
                    en <= '1';
                    IF rxData_reg <= "00111001" AND rxData_reg >= "00110000" THEN -- If received a digit
                        NNN_val <= rxData_reg(3 downto 0); -- Store first digit in NNN
                        en_NNN_0 <= '1';
                    END IF;
                END IF;
            WHEN PRINT_N2 =>
                rxDone <= '1';
            WHEN PRINT_N1 =>
                rxDone <= '1';
            WHEN PRINT_N0 =>
                rxDone <= '1';
            ---------------------------------------------------------------------------------
            -- Carriage Return and Line Feed
            ---------------------------------------------------------------------------------
            WHEN WAIT_CARRIAGE => -- Prep printing for carriage return
                dataIn <= "00001101";
                en <= '1';
            WHEN WAIT_LINE => -- Prep printing for line feed
                dataIn <= "00001010";
                en <= '1';
                en_numWords <= '1';
            WHEN WAIT_CARRIAGE2 => -- Prep printing for carriage return
                dataIn <= "00001101";
                en <= '1';
            WHEN WAIT_LINE2 => -- Prep printing for line feed
                dataIn <= "00001010";
                en <= '1';
            ---------------------------------------------------------------------------------
            -- Data Processor communication and bytes printed
            ---------------------------------------------------------------------------------
            WHEN STARTING => -- Set start and numWords
                start <= '1';
            WHEN DATAPROC => -- Store byte once received
                IF dataReady_reg = '1' THEN
                    en_storedByte <= '1';
                END IF;
            WHEN PREP_HEX1 => -- Prep printing for first Hex Digit
                IF storedByte(7 DOWNTO 4) >= "1010" AND storedByte(7 DOWNTO 4) <= "1111" THEN
                    dataIn <= STD_LOGIC_VECTOR(storedByte(7 DOWNTO 4) + "00110111");
                ELSE
                    dataIn <= STD_LOGIC_VECTOR(storedByte(7 DOWNTO 4) + "00110000");
                END IF;
                en <= '1';
            WHEN PREP_HEX2 => -- Prep printing for second Hex Digit  
                IF storedByte(3 DOWNTO 0) >= "1010" AND storedByte(3 DOWNTO 0) <= "1111" THEN
                    dataIN <= STD_LOGIC_VECTOR(storedByte(3 DOWNTO 0) + "00110111");
                ELSE
                    dataIN <= STD_LOGIC_VECTOR(storedByte(3 DOWNTO 0) + "00110000");
                END IF;
                en <= '1';
            WHEN PREP_SPACE => -- Prep printing for space
                IF seqDone_reg /= '1' THEN
                    dataIN <= "00100000";
                    en <= '1';
                END IF; 
            ---------------------------------------------------------------------------------
            -- P and L commands
            ---------------------------------------------------------------------------------
            WHEN PREP_P => 
                enP <= '1';
            WHEN PREP_L => -- Fill route and direction reg
                enL <= '1';
            WHEN OTHERS =>
        END CASE;
    END PROCESS;

    ---------------------------
    -- seq_Available Managing
    ---------------------------
    sequencing: PROCESS (clk)
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF RESET = '1' THEN
                seq_Available <= '0';
            ELSIF curState = STARTING THEN
                seq_Available <= '0';
            ELSIF seqDone_reg = '1' THEN
                seq_Available <= '1';
            END IF;
        END IF;
    END PROCESS; 

    ---------------------------
    -- Data Results and Max Index Managing
    ---------------------------
    data: PROCESS (clk)
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF RESET = '1' THEN
                maxIndex_stored <= ("0000", "0000", "0000");
                dataResults_stored <= ("00000000", "00000000", "00000000", "00000000", "00000000", "00000000", "00000000");
            ELSIF seqDone_reg = '1' THEN
                maxIndex_stored <= maxIndex_reg;
                dataResults_stored <= dataResults_reg;
            END IF;
        END IF;
    END PROCESS; 

    ---------------------------
    -- Sequential storage logic for NNN/ store_Byte
    ---------------------------
    store_NNN: PROCESS(clk)
    BEGIN
        IF clk'EVENT AND clk='1' THEN
          IF en_NNN_2='1' THEN
            NNN(2) <= NNN_val;
          ELSIF en_NNN_1='1' THEN
            NNN(1) <= NNN_val;
          ELSIF en_NNN_0='1' THEN
            NNN(0) <= NNN_val;
          END IF;
        END IF;
    END PROCESS;
    
    store_byte: PROCESS(clk)
    BEGIN
        IF clk'EVENT AND clk='1' THEN
          IF en_storedByte='1' THEN
            storedByte <= UNSIGNED(byte_reg);
          END IF;
        END IF;
    END PROCESS;
    
    seq_numWords: PROCESS(clk)
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF en_numWords = '1' THEN
                numWords_bcd <= NNN;
            END IF;
        END IF;
     END PROCESS;
    
    ---------------------------
    -- Input registering
    ---------------------------
    seq_input: PROCESS(clk)
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            rxnow_reg <=        rxnow;
            txdone_reg <=       txdone;
            dataReady_reg <=    dataReady;
            seqDone_reg <=      seqDone;
            rxData_reg <=       rxData;
            byte_reg <=         byte;
            maxIndex_reg <=     maxIndex;
            dataResults_reg <=  dataResults;
        END IF;
    END PROCESS;

    ---------------------------
    -- Sequential state updating
    ---------------------------
    seq_state: PROCESS (clk)
    BEGIN
        IF clk'EVENT AND clk='1' THEN
            IF RESET = '1' THEN
                curState <= INIT;
            ELSE
                curState <= nextState;
            END IF;
        END IF;
    END PROCESS; 
END arch; 
