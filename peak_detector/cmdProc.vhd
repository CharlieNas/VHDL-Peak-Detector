library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
use UNISIM.VPKG.ALL;

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
    type state_type is (INIT, VALID, A, P, L);
    signal curState, nextState: state_type; 
    signal enA, enP, enL: std_logic; 
    signal doneA, doneP, doneL: std_logic;
    signal seq_Available: std_logic;
    signal rxnow_reg, txdone_reg, dataReady_reg, seqDone_reg: std_logic;
    signal rxData_reg, byte_reg: std_logic_vector (7 downto 0);
    signal maxIndex_reg: BCD_ARRAY_TYPE(2 downto 0);  
    signal dataResults_reg: CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
    
    --Declare command components
    COMPONENT cmdP IS
        PORT (
            clk:		in std_logic;                           --i
            reset:		in std_logic;                           --i
            en:         in std_logic;                           --i
            peakByte:   in std_logic_vector (7 downto 0);       --i
            maxIndex:   in BCD_ARRAY_TYPE(2 downto 0);          --i
            txdone:		in std_logic;                           --i
            txData:	    out std_logic_vector (7 downto 0);      --o
            txnow:		out std_logic;                          --o
            done:       out std_logic                           --o
        );
    END COMPONENT;
    
BEGIN
    -----------------------------------------------------
    --Create component entities
    p1: cmdP port map (clk, reset, enP, dataResults(3), maxIndex_reg, txdone, txData, txnow, doneP);
    -----------------------------------------------------
    seq_input: PROCESS(CLK)
    BEGIN
        IF CLK'EVENT AND CLK='1' THEN
            rxnow_reg <= rxnow;
            txdone_reg <= txdone;
            dataReady_reg <= dataReady;
            seqDone_reg <= seqDone;
            rxData_reg <= rxData;
            byte_reg <= byte;
            maxIndex_reg <= maxIndex;
            dataResults_reg <= dataResults;
        END IF;
    END PROCESS;
    -----------------------------------------------------       
    combi_nextState: PROCESS(curState, rxnow_reg, rxData_reg, seq_Available, doneA, doneL, doneP)
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
                    nextState <= A;
                ELSIF (rxData_reg = "01010000" OR rxData_reg = "01110000") and seq_Available = '1' THEN
                    nextState <= P;
                ELSIF (rxData_reg = "01001100" OR rxData_reg = "01101100") and seq_Available = '1' THEN
                    nextState <= L;
                ELSE 
                    nextState <= INIT;
                END IF;
            WHEN A => 
                IF doneA = '1' THEN
                    nextState <= INIT;
                ELSE
                    nextState <= A;
                END IF;
            WHEN P => 
                IF doneP = '1' THEN
                    nextState <= INIT;
                ELSE
                    nextState <= P;
                END IF;
            WHEN L => 
                IF doneL = '1' THEN
                    nextState <= INIT;
                ELSE
                    nextState <= L;
                END IF;
            when OTHERS =>
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
        IF curState = VALID THEN 
            rxdone <= '1';
        ELSIF curState = A AND doneA = '0' THEN 
            enA <= '1';
        ELSIF curState = P AND doneP = '0' THEN 
            enP <= '1';
        ELSIF curState = L AND doneL = '0' THEN 
            enL <= '1';
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
