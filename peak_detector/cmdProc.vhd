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
    type state_type is (INIT);
    signal curState, nextState: state_type; 
    signal R_rxnow
BEGIN
-----------------------------------------------------
    combi_nextState: process(curState)
    BEGIN
        case curState is
            when INIT =>
                if cond1 then
                    ...
                else
                    ...
                
            when ... =>
            when OTHERS =>
                nextState => INIT;
        END case;
    END process;
-----------------------------------------------------
    combi_out: PROCESS(curState)
    BEGIN
        y <= '0'; -- assign default value
        IF curState = S3 AND x_reg='1' AND c2 = "10000" THEN
            y <= '1';
        END IF;
    END PROCESS; -- combi_output
  -----------------------------------------------------
    combi_in: PROCESS(CLK)
    BEGIN
	    IF CLK'event AND CLK='1' THEN
	    
	    END IF;
	  END PROCESS;
  -----------------------------------------------------
    seq_state: PROCESS (CLK, RESET)
    BEGIN
        IF CLK'EVENT AND CLK='1' THEN
            IF RESET = '1' THEN
                curState <= S0;
            ELSE
                curState <= nextState;
            END IF;
        END IF;
    END PROCESS; 
  -----------------------------------------------------
END arch; 

