library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
--use UNISIM.VPKG.ALL;

entity printer is
    port (
      en:           in std_logic;                           --i
      dataIn:       in std_logic_vector (7 downto 0);       --i
      clk:		    in std_logic;                           --i
      reset:		in std_logic;                           --i
      txdone:		in std_logic;                           --i
      txData:	    out std_logic_vector (7 downto 0);      --o
      txnow:		out std_logic;                          --o
      finished:     out std_logic                           --o
    );
end printer;

architecture arch of printer is
    TYPE state_type IS (IDLE, PRINT, WAITING);
    SIGNAL curState, nextState: state_type; 
    SIGNAL en_reg, txDone_reg: std_logic;
    SIGNAL dataIn_reg : std_logic_vector (7 downto 0);
BEGIN
    -----------------------------------------------------
    combi_nextState: PROCESS(curState, en_reg, txDone_reg)
    BEGIN
        case curState is
            when IDLE =>
                IF en_reg = '1' THEN
                    nextState <= PRINT;
                ELSE
                    nextState <= IDLE;
                END IF;   
            when PRINT =>
                nextState <= WAITING;
            when WAITING =>
                IF txDone_reg = '1' THEN
                    nextState <= IDLE;
                ELSE
                    nextState <= WAITING;
                END IF;    
            when OTHERS =>
                nextState <= IDLE;
        END case;
    END process;
    -----------------------------------------------------
    combi_out: PROCESS(curState)
    BEGIN
        finished <= '0';
        txnow <= '0';
        txData <= dataIn_reg;
        IF curState = PRINT THEN
            txnow <= '1';
        ELSIF curState = WAITING AND txDone_reg = '1' THEN
            finished <= '1';
        END IF;
    END PROCESS; -- combi_output
  -----------------------------------------------------
    combi_in: PROCESS(clk)
    BEGIN
	    IF clk'event AND clk='1' THEN
	           en_reg <= en;
	           txDone_reg <= txdone;
	           dataIn_reg <= dataIn;
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
END arch; 
