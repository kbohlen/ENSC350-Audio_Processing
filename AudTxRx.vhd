--***************************************************************************
-- The Serial transmitter for audio data to the DAC.
-- Double buffering introduces a one sample delay. The commented code is for 
-- double buffering.
-- The clock triggering statement for the shiftregister is crap. REDO.
-- The design should realy only need a single shift register and no output
-- Multiplexer,
--***************************************************************************
Library ieee;
Use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

Entity AudTx is
	Port ( Bclk, DacLrc : in std_logic;
			 Dacdat : out std_logic;
			 LAudio, RAudio : in signed( 31 downto 0 ) );
End Entity AudTx;

Architecture dataflow of AudTx is
	Signal LdataReg, RdataReg : signed( 31 downto 0 );
	Signal LTxShiftReg, RTxShiftReg : signed( 31 downto 0 );
Begin
	LdataReg <= LAudio when Rising_Edge( DacLrc ) else LdataReg;
	RdataReg <= RAudio when Falling_Edge( DacLrc ) else RdataReg;
--***************************************************************************
-- The Data registers introduce one-cycle latency. These registers are not
-- necessary if LR clock is used to transfer the parallel data. We would need
-- these registers if we used an independent clock to latch the data.
--***************************************************************************
--	LTxShiftReg <= LdataReg when (Falling_Edge(Bclk) and DacLrc = '1') else
--						LTxShiftReg(30 downto 0) & '0' when (Falling_Edge(Bclk) and DacLrc = '0')
--						else LTxShiftReg;
--	RTxShiftReg <= RdataReg when (Falling_Edge(Bclk) and DacLrc = '0') else
--						RTxShiftReg(30 downto 0) & '0' when (Falling_Edge(Bclk) and DacLrc = '1')
--						else RTxShiftReg;
	LTxShiftReg <= LAudio when (Falling_Edge(Bclk) and DacLrc = '0') else
						LTxShiftReg(30 downto 0) & '0' when (Falling_Edge(Bclk) and DacLrc = '1')
						else LTxShiftReg;
	RTxShiftReg <= RAudio when (Falling_Edge(Bclk) and DacLrc = '1') else
						RTxShiftReg(30 downto 0) & '0' when (Falling_Edge(Bclk) and DacLrc = '0')
						else RTxShiftReg;
				
	DacDat <= LTxShiftReg(31) when DacLrc = '1' else RTxShiftReg(31);
End Architecture dataflow;
--***************************************************************************
-- The Serial receiver for audio data from the ADC.
--***************************************************************************
Library ieee;
Use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

Entity AudRx is
	Port (
		Bclk, AdcLrc : in std_logic;
		AdcDat : in std_logic;
		LAudio, RAudio : out signed( 31 downto 0 ) );
End Entity AudRx;

Architecture dataflow of AudRx is
	Signal RxShiftReg : signed( 31 downto 0 );
	Signal LdataReg, RdataReg : signed( 31 downto 0 );
Begin
	RxShiftReg <= RxShiftReg(30 downto 0) & AdcDat when Rising_Edge(Bclk) else RxShiftReg;
	LdataReg <= RxShiftReg when Falling_Edge(AdcLrc) else LdataReg;
	LAudio <= LdataReg;
	RdataReg <= RxShiftReg when Rising_Edge(AdcLrc) else RdataReg;
	RAudio <= RdataReg;
End Architecture dataflow;