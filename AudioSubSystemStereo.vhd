Library ieee;
Use ieee.std_logic_1164.all;
Use ieee.numeric_std.all;

Library altera;
use altera.altera_primitives_components.all;


Entity AudioSubSystemStereo is
	Port (
		iClk_50 : in std_logic;
		AudMclk : out std_logic;
		Init : in std_logic; --  +ve edge initiates I2C data.

		I2C_Sclk : out std_logic;
		I2C_Sdat : inout std_logic;
		
		Bclk, AdcLrc, DacLrc, AdcDat : in std_logic;
		DacDat : out std_logic;

		AudioOutL : in signed(15 downto 0);
		AudioOutR : in signed(15 downto 0);
		AudioInL : out signed(15 downto 0);
		AudioInR : out signed(15 downto 0);
		SamClk : out std_logic );
End Entity AudioSubSystemStereo;

Architecture Structural of AudioSubSystemStereo is
	Signal I2CClk : std_logic;
	Signal Sdout, Sdin, Sclk : std_logic;

	Signal LStreamIN, LStreamOUT, RStreamIN, RStreamOUT : signed( 31 downto 0 );
	Signal Ch0In, Ch1In, Ch0Out, Ch1Out : signed(15 downto 0);
	Signal Ch0InAlign : signed(15 downto 0);
	Signal AddOut : signed(16 downto 0);
Begin

CG: Entity Work.ClockGen port map (iClk_50, I2CClk, AudMclk);

--****************************************************************************
-- The I2C system initializes the Codec.
--****************************************************************************
	I2C_Sclk <= Sclk;
	Sdin <= I2C_SDat;
	ODB: OPNDRN port map (a_in => Sdout, a_out => I2C_SDat);
CI: Entity Work.CodecInit port map ( ModeIn => "10",
							I2CClk => I2CClk, Sclk => Sclk, Sdin => Sdin, Sdout => Sdout,
							Init => Init,	SwitchWord => (others=>'0') );

							
--****************************************************************************
-- The Audio interface to the Codec..
--****************************************************************************
AI: Entity Work.AudRx
		port map ( Bclk => Bclk , AdcLrc => AdcLrc,	AdcDat => AdcDat,
					  LAudio => LStreamIN, RAudio => RStreamIN );
AO: Entity Work.AudTx
		port map ( Bclk => Bclk , DacLrc => DacLrc, DacDat => DacDat,
					  LAudio => LStreamOUT, RAudio => RStreamOUT );

--*********************************************************************	
-- Entity Intermediate Audio Processing.
-- Assume 2 Channels, 16-bit sample words at 50 kSPS	
-- Assume that both input and output have the same sample rates.
--*********************************************************************
	AudioInL <= LStreamIN(31 downto 16);
	AudioInR <= RStreamIN(31 downto 16);

	SamClk <= AdcLrc;

	Ch0Out <= AudioOutL;
	Ch1Out <= AudioOutR;
	LStreamOUT(31 downto 16) <= Ch0Out;
	RStreamOUT(31 downto 16) <= Ch1Out; 
	LStreamOUT(15 downto 0) <= (others => '0');								
	RStreamOUT(15 downto 0) <= (others => '0');

End Architecture Structural;