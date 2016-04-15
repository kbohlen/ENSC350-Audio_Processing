Library ieee;
Use ieee.std_logic_1164.all;
Use ieee.numeric_std.all;

Entity ClockGen is
	Port (
		MainClk : in std_logic;
		I2CClk, AudMclk : out std_logic );
End Entity ClockGen;

Architecture dataflow of ClockGen is
	Signal DivChain : unsigned( 26 downto 0 );
-- Number of 20 ns clocks for each state of I2CTx CU.
	Constant	Period : integer := 64;
	Constant	PWidth : integer := 16;
Begin
--Modulo M synchronous counter for clock generation.
CB:Block ( rising_edge( MainClk ) )
	Begin
		DivChain <= guarded ( others => '0' ) when DivChain >= Period-1 else DivChain + 1;
	End Block CB;
	I2CClk <= '1' when DivChain < PWidth else '0';

	AudMclk <= DivChain(1); -- is 12.5 Mhz, 50% duty cycle
End Architecture dataflow;