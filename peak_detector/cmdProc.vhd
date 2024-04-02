library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
-- use UNISIM.VPKG.ALL;

entity cmdProc is
    port (
      clk:		in std_logic;                                    --i
      reset:		in std_logic;                                --i
      rxnow:		in std_logic;                                --i
      rxData:			in std_logic_vector (7 downto 0);        --i
      txData:			out std_logic_vector (7 downto 0);       --o
      rxdone:		out std_logic;                               --o
      ovErr:		in std_logic;                                --i
      framErr:	in std_logic;                                    --i
      txnow:		out std_logic;                               --o
      txdone:		in std_logic;                                --i
      start: out std_logic;                                      --o
      numWords_bcd: out BCD_ARRAY_TYPE(2 downto 0);              --o
      dataReady: in std_logic;                                   --i
      byte: in std_logic_vector(7 downto 0);                     --i
      maxIndex: in BCD_ARRAY_TYPE(2 downto 0);                   --i
      dataResults: in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);   --i
      seqDone: in std_logic                                      --i
    );
end cmdProc;

architecture arch of cmdProc is
    type state_type is (INIT, VALID, PRINT_A, PRINT_P, PRINT_L, A, P, L, CARRIAGE_RETURN, LINE_FEED);
    signal curState, nextState: state_type; 
    signal enA, enP, enL, en: std_logic; 
    signal doneA, doneP, doneL, finished: std_logic;
    signal seq_Available: std_logic;
    signal rxnow_reg, txdone_reg, dataReady_reg, seqDone_reg: std_logic;
    signal rxData_reg, byte_reg, dataIn: std_logic_vector (7 downto 0);
    signal maxIndex_reg: BCD_ARRAY_TYPE(2 downto 0);  
    signal dataResults_reg: CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
    signal route_reg, direction_reg: std_logic;
    -- signals to assign to outputs
    signal rxDone_main, rxDone_a, txNow_printer, txNow_a, txNow_l, txNow_p: std_logic;
    signal txData_printer, txData_a, txData_l, txData_p: std_logic_vector(7 downto 0);
    -----------------------------------------------------
    COMPONENT printer is
        port (
          clk:		    in std_logic;                               --i
          reset:		in std_logic;                               --i
          en:           in std_logic;                               --i
          dataIn:       in std_logic_vector (7 downto 0);           --i
          txDone:		in std_logic;                               --i
          txData:	    out std_logic_vector (7 downto 0);          --o
          txnow:		out std_logic;                              --o
          finished:     out std_logic                               --o
        );
    END COMPONENT printer;
    -----------------------------------------------------
    COMPONENT cmdP IS
        PORT (
            clk:		in std_logic;                               --i
            reset:		in std_logic;                               --i
            en:         in std_logic;                               --i
            peakByte:   in std_logic_vector (7 downto 0);           --i
            maxIndex:   in BCD_ARRAY_TYPE(2 downto 0);              --i
            txdone:		in std_logic;                               --i
            txData:	    out std_logic_vector (7 downto 0);          --o
            txnow:		out std_logic;                              --o
            doneP:      out std_logic                               --o
        );
    END COMPONENT cmdP;
    -----------------------------------------------------
    COMPONENT cmdL IS
        PORT (  
          clk:		    in std_logic;                               --i
          reset:		in std_logic;                               --i  
          enL:          in std_logic;                               --i
          dataResults:  in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1); --i                       
          txdone:		in std_logic;                               --i
          txData:	    out std_logic_vector (7 downto 0);          --o
          txnow:		out std_logic;                              --o    
          doneL:        out std_logic                               --o
        );
    END COMPONENT cmdL;
    -----------------------------------------------------
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
    -----------------------------------------------------
BEGIN
    print:     printer port map (clk, reset, en, dataIn, txDone, txData_printer, txNow_printer, finished);
    command_P: cmdP port map (clk, reset, enP, dataResults_reg(3), maxIndex_reg, txdone_reg, txData_p, txNow_p, doneP);
    command_L: cmdL port map (clk, reset, enL, dataResults_reg, txdone_reg, txData_l, txNow_l, doneL);
    command_A: cmdA port map (clk, reset, rxDone_a, rxData_reg, rxNow_reg, ovErr, framErr, txData_a, txNow_a, txdone_reg, start, numWords_bcd, dataReady_reg, byte_reg, seqDone_reg, enA, doneA);
    -----------------------------------------------------
    assign_tx: PROCESS(curState, txNow_printer, txNow_a, txNow_l, txNow_p, txData_printer, txData_a, txData_l, txData_p)
      BEGIN
        IF curState=PRINT_A OR curState=PRINT_L OR curState=PRINT_P OR curState=CARRIAGE_RETURN OR curState=LINE_FEED THEN
          txData <= txData_printer;
          txNow <= txNow_printer;
        ELSIF curState=A THEN
          txData <= txData_a;
          txNow <= txNow_a;
        ELSIF curState=L THEN
          txData <= txData_l;
          txNow <= txNow_l;
        ELSIF curState=P THEN
          txData <= txData_p;
          txNow <= txNow_p;
        ELSE
          rxDone <= '0';
          txData <= "00000000";
          txNow <= '0';
        END IF;
      END PROCESS;
      
    assign_rx: PROCESS(curState, rxDone_main, rxDone_a)
      BEGIN
        IF curState=A THEN
          rxDone <= rxDone_a;
        ELSE
          rxDone <= rxDone_main;
        END IF;
      END PROCESS;
    
    seq_input: PROCESS(CLK)
    BEGIN
        IF CLK'EVENT AND CLK='1' THEN
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
    -----------------------------------------------------       
    combi_nextState: PROCESS(curState, rxnow_reg, rxData_reg, seq_Available, doneA, doneL, doneP, finished)
    BEGIN
        CASE curState is
            WHEN INIT =>
                IF rxnow_reg = '1' THEN
                    nextState <= VALID;
                ELSE 
                    nextState <= INIT;
                END IF; 
            WHEN VALID =>
                IF rxData_reg = "01000001" OR rxData_reg = "01100001" THEN
                    nextState <= PRINT_A;
                ELSIF (rxData_reg = "01010000" OR rxData_reg = "01110000") and seq_Available = '1' THEN
                    nextState <= PRINT_P;
                ELSIF (rxData_reg = "01001100" OR rxData_reg = "01101100") and seq_Available = '1' THEN
                    nextState <= PRINT_L;
                ELSE 
                    nextState <= INIT;
                END IF; 
            WHEN PRINT_A => 
                IF finished = '1' THEN
                    nextState <= A;
                END IF;
            WHEN PRINT_P => 
                IF finished = '1' THEN
                    nextState <= CARRIAGE_RETURN;
                END IF;
            WHEN PRINT_L => 
                IF finished = '1' THEN
                    nextState <= CARRIAGE_RETURN;
                END IF;
            WHEN CARRIAGE_RETURN =>
                IF finished = '1' THEN
                    nextState <= LINE_FEED;
                END IF;
            WHEN LINE_FEED =>
                IF finished = '1' AND route_reg = '0' AND direction_reg = '0' THEN
                    nextState <= P;
                ELSIF finished = '1' AND route_reg = '1' AND direction_reg = '0' THEN
                    nextState <= L;
                ELSIF finished = '1' AND direction_reg = '1' THEN
                    nextState <= INIT;
                END IF;
            WHEN A => 
                IF doneA = '1' THEN
                    nextState <= CARRIAGE_RETURN;
                ELSE
                    nextState <= A;
                END IF;
            WHEN P => 
                IF doneP = '1' THEN
                    nextState <= CARRIAGE_RETURN;
                ELSE
                    nextState <= P;
                END IF;
            WHEN L => 
                IF doneL = '1' THEN
                    nextState <= CARRIAGE_RETURN;
                ELSE
                    nextState <= L;
                END IF;
            WHEN OTHERS =>
                nextState <= INIT;
        END CASE;
    END PROCESS;
    -----------------------------------------------------
    sequencing : PROCESS(seqDone_reg, clk)
    BEGIN 
        IF CLK'EVENT AND CLK='1' THEN
            IF seqDone_reg = '1' THEN
                seq_Available <= '1';
            END IF;
        END IF;
    END PROCESS;
    -----------------------------------------------------   
    combi_out: PROCESS(curState)
    BEGIN
        enA <= '0';
        enP <= '0';
        enL <= '0';
        en <= '0';
        rxDone_main <= '0';
        IF curState = VALID THEN 
            rxDone_main <= '1';
            dataIn <= rxData_reg;
            -- Set printer enable high for 1 clock cycle if going into printing state
            IF (rxData_reg = "01000001" OR rxData_reg = "01100001") OR 
               ((rxData_reg = "01010000" OR rxData_reg = "01110000") and seq_Available = '1') OR
               ((rxData_reg = "01001100" OR rxData_reg = "01101100") and seq_Available = '1') THEN
               en <= '1';
            END IF;
        -- Set command enable signals high for 1 clock cycle if done printing
        ELSIF curState = A THEN 
            enA <= '1';
            direction_reg <= '1';
        ELSIF curState = P THEN 
            enP <= '1';
            direction_reg <= '1';
        ELSIF curState = L THEN 
            enL <= '1';
            direction_reg <= '1';
        ELSIF curState = PRINT_P THEN
            route_reg <= '0';
            direction_reg <= '0';
        ELSIF curState = PRINT_L THEN
            route_reg <= '1';
            direction_reg <= '0';
        ELSIF curState = CARRIAGE_RETURN THEN
            dataIn <= "00001101";
            en <= '1';
        ELSIF curState = LINE_FEED THEN
            dataIn <= "00001010";
            en <= '1';
        END IF;
    END PROCESS;
    -----------------------------------------------------
    seq_state: PROCESS (clk, reset)
    BEGIN
        IF CLK'EVENT AND CLK='1' THEN
            IF RESET = '1' THEN
                curState <= INIT;
                seq_Available <= '0';
            ELSE
                curState <= nextState;
            END IF;
        END IF;
    END PROCESS; 
    -----------------------------------------------------
END arch; 
