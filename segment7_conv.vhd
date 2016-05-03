library ieee;
use ieee.std_logic_1164.all;

entity segment7_conv is
port (  D : in std_logic_vector(4 downto 0);  -- HEX input
        O : out std_logic_vector(6 downto 0)  -- 7 bit decoded output.
     );
end segment7_conv;

architecture Behavioral of segment7_conv is

begin
PROCESS (D)
		BEGIN
			CASE D IS
				WHEN "00000"=> O<="1000000";
				WHEN "00001"=> O<="1111001";
				WHEN "00010"=> O<="0100100";
				WHEN "00011"=> O<="0110000";
				WHEN "00100"=> O<="0011001";
				WHEN "00101"=> O<="0010010";
				WHEN "00110"=> O<="0000010";
				WHEN "00111"=> O<="1111000";
				WHEN "01000"=> O<="0000000";
				WHEN "01001"=> O<="0010000";
				WHEN "01010"=> O<="0001000";
				WHEN "01011"=> O<="0000011";
				WHEN "01100"=> O<="1000110";
				WHEN "01101"=> O<="0100001";
				WHEN "01110"=> O<="0000110";
				WHEN "01111"=> O<="0001110";
				when "11111"=> O<="1111111"; -- blank
				when "11110"=> O<="0111111"; -- negative sign
				when "11101"=> O<="1000111"; -- 'L'
				when "11100"=> O<="0101111"; -- 'r'
				when "11011"=> O<="1000001"; -- 'V'
				WHEN OTHERS=> O<="1111111";
			END CASE;
	END PROCESS;
 

end Behavioral;