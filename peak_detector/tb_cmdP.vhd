library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
--use UNISIM.VPKG.ALL;

entity tb_cmdP is
end;

architecture testbench of tb_cmdP is
    
    component cmdP is
        port (
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
    end component;
    
    signal clk,sig_txdone: std_logic := '0';
    
    signal reset, sig_enP, sig_txnow, sig_done: std_logic;
    signal sig_peakByte, sig_txData: std_logic_vector (7 downto 0);
    signal sig_maxIndex: BCD_ARRAY_TYPE (2 downto 0); 
    
    type PEAKBYTE_SEQUENCE is array (integer range<>) of std_logic_vector (7 downto 0);
    type MAXINDEX_SEQUENCE is array (integer range<>) of BCD_ARRAY_TYPE (2 downto 0);
    
    constant byteSequence: PEAKBYTE_SEQUENCE(1 to 6) := ("00000000",    --00 = 00110000, 00110000
                                                         "11111111",    --FF = 01000110, 01000110
                                                         "11110000",    --F0 = 01000110, 00110000
                                                         "00001111",    --0F = 00110000, 01000110
                                                         "10101010",    --AA = 01000001, 01000001
                                                         "01010101");   --55 = 00110101, 00110101
                           
    constant indexSequence: MAXINDEX_SEQUENCE(1 to 7) := (("0000","0000","0000"),   --000 = 00110000, 00110000, 00110000
                                                          ("1001","1001","1001"),   --999 = 00111001, 00111001, 00111001
                                                          ("0000","0000","0001"),   --001 = 00110000, 00110000, 00110001                                                    ("0000","0101","0000"),   --050
                                                          ("0000","0011","0110"),   --036 = 00110000, 00110011, 00110110
                                                          ("1000","0000","0000"),   --800 = 00111000, 00110000, 00110000
                                                          ("0010","0000","0100"),   --204 = 00110010, 00110000, 00110100
                                                          ("0111","0111","0000"));  --770 = 00110111, 00110111, 00110000
    
begin
    sig_peakByte <= byteSequence(6), byteSequence(5) after 350ns, byteSequence(4) after 470ns;
    sig_maxIndex <= indexSequence(7), indexSequence(6) after 350ns, indexSequence(5) after 470ns;
    clk <= NOT clk after 5 ns when now <200000 ms else clk;
    reset <= '0', '1' after 2 ns, '0' after 15 ns, '1' after 440ns, '0' after 460ns;
    sig_enP <= '0', '1' after 15 ns, '0' after 20 ns, '1' after 350ns, '0' after 360ns, '1' after 470ns, '0' after 480ns;
    sig_txdone <= NOT sig_txdone after 10 ns when now <200000 ms else sig_txdone;
    cmdP1: cmdP
        port map (
            clk => clk,
            reset => reset,
            en => sig_enP,
            peakByte => sig_peakByte,
            maxIndex => sig_maxIndex,
            txdone => sig_txdone,
            txData => sig_txData,
            txnow => sig_txnow,
            done => sig_done
        );

        
end testbench;
