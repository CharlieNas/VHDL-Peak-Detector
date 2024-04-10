--Print.vhd
--To use it set en signal to 1 and dataIn to the byte you are printing in the same clock cycle
--Similar to tx and rx you then set en to 0 to prevent printing again after finishing
--When it is done it will set finished to 1

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
      txDone:		in std_logic;                           --i
      txData:	    out std_logic_vector (7 downto 0);      --o
      txnow:		out std_logic;                          --o
      finished:     out std_logic                           --o
    );
end printer;

architecture arch of printer is
    TYPE state_type IS (IDLE, PRINTING, WAITING);
    SIGNAL curState, nextState: state_type; 
    SIGNAL en_reg, txDone_reg: std_logic;
    SIGNAL dataIn_reg : std_logic_vector (7 downto 0);
BEGIN
    -----------------------------------------------------
    combi_nextState: PROCESS(curState, en_reg, txDone_reg)
    BEGIN
        CASE curState IS
	    -- IDLE: not in use, waits to be enabled
            WHEN IDLE =>
                IF en_reg = '1' THEN
                    nextState <= WAITING;
                ELSE
                    nextState <= IDLE;
                END IF;
            WHEN WAITING =>
                IF txDone_reg = '0' THEN
                    nextState <= PRINTING;
                ELSE
                    nextState <= WAITING;
                END IF;
	    -- PRINTING: sends the byte to tx then waits for it to complete
            WHEN PRINTING =>
                IF txDone_reg = '1' THEN
                    nextState <= IDLE;
                ELSE
                    nextState <= PRINTING;
                END IF;
            WHEN OTHERS =>
                nextState <= IDLE;
        END CASE;
    END PROCESS;
    -----------------------------------------------------
    combi_out: PROCESS(curState, txDone_reg, dataIn_reg, en_reg)
    BEGIN
        finished <= '0';
        txnow <= '0';
        txData <= dataIn_reg;
        IF curState = IDLE AND en_reg='1' THEN
            txnow <= '1';
        ELSIF curState = PRINTING AND txDone_reg = '1' THEN
            finished <= '1';
        END IF;
    END PROCESS; -- combi_output
  -----------------------------------------------------
    seq_in: PROCESS(clk)
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
