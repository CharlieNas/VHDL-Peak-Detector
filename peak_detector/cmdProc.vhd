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
    type state_type is (INIT, VALID, PRINT_A, PRINT_P, PRINT_L, N2, N1, N0, ECHO, DATAPROC, STOREBYTE, HEX1, HEX2, SPACE, P, L, CARRIAGE_RETURN, LINE_FEED);
    signal curState, nextState: state_type; 
    signal enP, enL, en: std_logic; 
    signal doneP, doneL, finished: std_logic;
    signal seq_Available: std_logic;
    signal rxnow_reg, txdone_reg, dataReady_reg, seqDone_reg: std_logic;
    signal rxData_reg, byte_reg, dataIn: std_logic_vector (7 downto 0);
    signal maxIndex_reg: BCD_ARRAY_TYPE(2 downto 0);  
    signal dataResults_reg: CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
    signal direction_reg: std_logic;
    signal route_reg: std_logic_vector (1 downto 0);
    signal N_reg: std_logic_vector (2 downto 0);
    SIGNAL NNN: BCD_ARRAY_TYPE(2 DOWNTO 0);
    SIGNAL storedByte: UNSIGNED(7 DOWNTO 0);
    --signals for main:
    signal txnow_M: std_logic;
    signal txdata_M: std_logic_vector(7 downto 0);
    --signals for A:
    signal rxdone_A, txnow_A: std_logic;
    signal txData_A: std_logic_vector(7 downto 0);
    --signals for P
    signal txdata_P: std_logic_vector(7 downto 0);
    signal txnow_P: std_logic;
    --signals for L
    signal txdata_L: std_logic_vector(7 downto 0);
    signal txnow_L: std_logic;     
    ---------------------------
    -- Component Definitions
    ---------------------------
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


BEGIN
    print:     printer port map (clk, reset, en, dataIn, txDone, txData_M, txNow_M, finished);
    command_P: cmdP port map (clk, reset, enP, dataResults_reg(3), maxIndex_reg, txdone_reg, txData_P, txNow_P, doneP);
    command_L: cmdL port map (clk, reset, enL, dataResults_reg, txdone, txData_L, txNow_L, doneL);
    
    
    assign_tx: PROCESS(curState, txNow_M, txNow_A, txNow_L, txNow_P, txData_M, txData_A, txData_L, txData_P, rxdone_a)
    BEGIN          
        IF curState=L THEN
            txData <= txData_L;
            txNow <= txNow_L;
        ELSIF curState=P THEN
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
                    nextState <= N2;
                END IF;
            WHEN N2 => 
                IF rxnow_reg = '1' THEN
                    nextState <= ECHO;
                ELSE
                    nextState <= N2;
                END IF;
            WHEN N1 => 
                IF rxnow_reg = '1' THEN
                    nextState <= ECHO;
                ELSE
                    nextState <= N1;
                END IF;
            WHEN N0 => 
                IF rxnow_reg = '1' THEN
                    nextState <= ECHO;
                ELSE
                    nextState <= N0;
                END IF;
            WHEN ECHO =>
                IF finished = '1' and N_reg = "000" THEN -- Came from N2 and digit
                    nextState <= N1;
                ELSIF finished = '1' and N_reg = "001" THEN -- Came from N1 and digit
                    nextState <= N0;
                ELSIF finished = '1' and N_reg = "010" THEN -- Came from N0 and digit
                    nextState <= CARRIAGE_RETURN;
                ELSIF finished = '1' and N_reg = "011" THEN -- Recvieved another A
                    nextState <= PRINT_A;
                ELSIF finished = '0' THEN
                    nextState <= ECHO;
                ELSE 
                    nextState <= INIT;
                END IF;
            WHEN CARRIAGE_RETURN =>
                IF finished = '1' THEN
                    nextState <= LINE_FEED;
                END IF;
            WHEN LINE_FEED =>
                IF finished = '1' AND route_reg = "00" AND direction_reg = '0' THEN
                    nextState <= P;
                ELSIF finished = '1' AND route_reg = "01" AND direction_reg = '0' THEN
                    nextState <= L;
                ELSIF finished = '1' AND route_reg = "10" AND direction_reg = '0' THEN
                    nextState <= DATAPROC;
                ELSIF finished = '1' AND direction_reg = '1' THEN
                    nextState <= INIT;
                END IF;
            WHEN DATAPROC =>
                IF dataReady_reg='1' THEN
                  nextState <= STOREBYTE;
                ELSE
                  nextState <= DATAPROC;
                END IF; 
            WHEN STOREBYTE =>
                nextState <= HEX1; 
            WHEN HEX1 =>
                IF finished ='1' THEN
                  nextState <= HEX2;
                ELSE
                  nextState <= HEX1;
                END IF;
            WHEN HEX2 =>
                IF finished ='1' THEN
                    IF seq_Available ='1' THEN ----------------------------------------------------- 
                        nextState <= INIT;
                    ELSE
                        nextState <= SPACE;
                    END IF;
                ELSE
                  nextState <= HEX2;
                END IF;
            WHEN SPACE =>
                IF finished ='1' THEN
                    nextState <= DATAPROC;
                ELSE
                    nextState <= SPACE;
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
            WHEN PRINT_P => 
                IF finished = '1' THEN
                    nextState <= CARRIAGE_RETURN;
                END IF;
            WHEN PRINT_L => 
                IF finished = '1' THEN
                    nextState <= CARRIAGE_RETURN;
                END IF;
            WHEN OTHERS =>
                nextState <= INIT;
        END CASE;
    END PROCESS;

    -- ---------------------------
    -- -- Combinatorial Outputs
    -- ---------------------------
    -- combi_out: PROCESS(curState, finished, rxData_reg, dataReady_reg, N_reg, storedByte)
    -- BEGIN
    --     enP <= '0';
    --     enL <= '0';
    --     en <= '0';
    --     rxDone <= '0';
    --     start <= '0';
    --     IF curState = VALID THEN 
    --         dataIn <= rxData_reg;
    --         en <= '1';
    --         rxDone <= '1';
    --     ELSIF rxnow_reg = '1' THEN  
    --         dataIn <= rxData_reg;
    --         IF curState = N2 AND rxData_reg <= "00111001" AND rxData_reg >= "00110000" THEN 
    --             N_reg <= "000";
    --             NNN(2) <= rxData_reg(3 downto 0);
    --         ELSIF curState = N1 AND rxData_reg <= "00111001" AND rxData_reg >= "00110000" THEN 
    --             N_reg <= "001";
    --             NNN(1) <= rxData_reg(3 downto 0);
    --         ELSIF curState = N0 AND rxData_reg <= "00111001" AND rxData_reg >= "00110000" THEN 
    --             N_reg <= "010";
    --             NNN(0) <= rxData_reg(3 downto 0);
    --         ELSIF rxData_reg = "01000001" OR rxData_reg = "01100001" THEN 
    --             N_reg <= "011";
    --         ELSIF curState /= ECHO THEN -- Otherwise will change to go back to INIT
    --             N_reg <= "111"; 
    --         END IF;
    --         rxDone <= '1';
    --         en <= '1';
    --     ELSIF curState = ECHO THEN
    --         IF finished = '1' and N_reg = "010" THEN -- Came from N0 and digit
    --             dataIn <= "00001101";
    --             en <= '1';
    --         END IF;
    --     ELSIF curState = PRINT_P THEN
    --         route_reg <= "00";
    --         direction_reg <= '0';
    --     ELSIF curState = PRINT_L THEN
    --         route_reg <= "01";
    --         direction_reg <= '0';
    --     ELSIF curState = PRINT_A THEN 
    --         route_reg <= "10";
    --         direction_reg <= '0';
    --     ELSIF curState = CARRIAGE_RETURN THEN
    --         dataIn <= "00001010";
    --         en <= '1';
    --     ELSIF curState = LINE_FEED THEN
    --         IF N_reg = "010" THEN
    --             start <= '1'; 
    --             numWords_bcd <= NNN;
    --         END IF;
    --     ELSIF curState = SPACE THEN
    --         dataIn <= "00100000";
    --         en <= '1';
    --         start <= '1';
    --     ELSIF curState = DATAPROC THEN
    --         IF dataReady_reg='1' THEN
    --             storedByte <= UNSIGNED(byte_reg);
    --         END IF;
    --     ELSIF curState = STOREBYTE THEN
    --         IF storedByte(7 DOWNTO 4) >= "1010" AND storedByte(7 DOWNTO 4) <= "1111" THEN
    --             dataIn <= STD_LOGIC_VECTOR(storedByte(7 DOWNTO 4) + "00110111");
    --         ELSE
    --             dataIn <= STD_LOGIC_VECTOR(storedByte(7 DOWNTO 4) + "00110000");
    --         END IF;
    --         en <= '1';
    --     ELSIF curState = HEX1 THEN
    --         IF finished ='1' THEN
    --             IF storedByte(3 DOWNTO 0) >= "1010" AND storedByte(3 DOWNTO 0) <= "1111" THEN
    --                 dataIN <= STD_LOGIC_VECTOR(storedByte(3 DOWNTO 0) + "00110111");
    --             ELSE
    --                 dataIN <= STD_LOGIC_VECTOR(storedByte(3 DOWNTO 0) + "00110000");
    --             END IF;
    --             en <= '1';
    --         END IF;
    --     ELSIF curState = HEX2 THEN
    --         IF finished ='1' AND seqDone_reg /= '1' THEN
    --             dataIN <= "00100000";
    --             en <= '1';
    --         END IF; 
    --     ELSIF curState = P THEN 
    --         enP <= '1';
    --         direction_reg <= '1';
    --     ELSIF curState = L THEN 
    --         enL <= '1';
    --         direction_reg <= '1';
    --     END IF;
    -- END PROCESS;

    ---------------------------
    -- Combinatorial Outputs
    ---------------------------
    combi_out: PROCESS(curState, finished, rxData_reg, dataReady_reg, N_reg, storedByte)
    BEGIN
        enP <= '0';
        enL <= '0';
        en <= '0';
        rxDone <= '0';
        start <= '0';
        CASE curState is
            WHEN VALID =>
                dataIn <= rxData_reg;
                en <= '1';
                rxDone <= '1';
            WHEN PRINT_A => 
                route_reg <= "10";
                direction_reg <= '0';
            WHEN N2 =>
                IF rxnow_reg = '1' THEN 
                    dataIn <= rxData_reg;
                    rxDone <= '1';
                    en <= '1';
                    IF rxData_reg <= "00111001" AND rxData_reg >= "00110000" THEN 
                        N_reg <= "000";
                        NNN(2) <= rxData_reg(3 downto 0);
                    ELSIF rxData_reg = "01000001" OR rxData_reg = "01100001" THEN 
                        N_reg <= "011";
                    ELSE 
                        N_reg <= "111";
                    END IF;
                END IF;
            WHEN N1 => 
                IF rxnow_reg = '1' THEN 
                    dataIn <= rxData_reg;
                    rxDone <= '1';
                    en <= '1';
                    IF rxData_reg <= "00111001" AND rxData_reg >= "00110000" THEN 
                        N_reg <= "001";
                        NNN(1) <= rxData_reg(3 downto 0);
                    ELSIF rxData_reg = "01000001" OR rxData_reg = "01100001" THEN 
                        N_reg <= "011";
                    ELSE 
                    N_reg <= "111";
                    END IF;
                END IF;
            WHEN N0 => 
                IF rxnow_reg = '1' THEN 
                    dataIn <= rxData_reg;
                    rxDone <= '1';
                    en <= '1';
                    IF rxData_reg <= "00111001" AND rxData_reg >= "00110000" THEN 
                        N_reg <= "010";
                        NNN(0) <= rxData_reg(3 downto 0);
                    ELSIF rxData_reg = "01000001" OR rxData_reg = "01100001" THEN 
                        N_reg <= "011";
                    ELSE 
                        N_reg <= "111";
                    END IF;
                END IF;
            WHEN ECHO =>
                IF finished = '1' and N_reg = "010" THEN -- Came from N0 and digit
                    dataIn <= "00001101";
                    en <= '1';
                END IF;
            WHEN CARRIAGE_RETURN =>
                dataIn <= "00001010";
                en <= '1';
            WHEN LINE_FEED =>
                IF N_reg = "010" THEN
                    start <= '1'; 
                    numWords_bcd <= NNN;
                END IF;
            WHEN DATAPROC =>
                IF dataReady_reg='1' THEN
                    storedByte <= UNSIGNED(byte_reg);
                END IF;
            WHEN STOREBYTE =>
                IF storedByte(7 DOWNTO 4) >= "1010" AND storedByte(7 DOWNTO 4) <= "1111" THEN
                    dataIn <= STD_LOGIC_VECTOR(storedByte(7 DOWNTO 4) + "00110111");
                ELSE
                    dataIn <= STD_LOGIC_VECTOR(storedByte(7 DOWNTO 4) + "00110000");
                END IF;
                en <= '1';
            WHEN HEX1 =>
                IF finished ='1' THEN
                    IF storedByte(3 DOWNTO 0) >= "1010" AND storedByte(3 DOWNTO 0) <= "1111" THEN
                        dataIN <= STD_LOGIC_VECTOR(storedByte(3 DOWNTO 0) + "00110111");
                    ELSE
                        dataIN <= STD_LOGIC_VECTOR(storedByte(3 DOWNTO 0) + "00110000");
                    END IF;
                    en <= '1';
                END IF;
            WHEN HEX2 =>
                IF finished ='1' AND seqDone_reg /= '1' THEN
                    dataIN <= "00100000";
                    en <= '1';
                END IF; 
            WHEN SPACE =>
                dataIn <= "00100000";
                en <= '1';
                start <= '1';
            WHEN P => 
                enP <= '1';
                direction_reg <= '1';
            WHEN L => 
                enL <= '1';
                direction_reg <= '1';
            WHEN PRINT_P => 
                route_reg <= "00";
                direction_reg <= '0';
            WHEN PRINT_L => 
                route_reg <= "01";
                direction_reg <= '0';
            WHEN OTHERS =>
        END CASE;
    END PROCESS;

    ---------------------------
    -- seq_Available Managing
    ---------------------------
    sequencing: PROCESS (clk, reset, seqDone_reg)
    BEGIN
        IF CLK'EVENT AND CLK='1' THEN
            IF RESET = '1' THEN
                seq_Available <= '0';
            ELSIF seqDone_reg = '1' THEN
                seq_Available <= '1';
            END IF;
        END IF;
    END PROCESS; 


    ---------------------------
    -- Input registering
    ---------------------------
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

    ---------------------------
    -- Sequential state updating
    ---------------------------
    seq_state: PROCESS (clk, reset)
    BEGIN
        IF CLK'EVENT AND CLK='1' THEN
            IF RESET = '1' THEN
                curState <= INIT;
            ELSE
                curState <= nextState;
            END IF;
        END IF;
    END PROCESS; 
END arch; 
