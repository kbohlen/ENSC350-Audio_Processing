package Codec is
	Type RegOp is (hold, set, init, shift);
	Attribute enum_encoding : string;
	Attribute enum_encoding of RegOp : type is "00 01 10 11";
end Codec;

Use Work.Codec.all;

Library ieee;
Use ieee.std_logic_1164.all;

Library altera;
Use altera.altera_syn_attributes.all;
use altera.altera_primitives_components.all;

Entity I2CTx is
	port (
		DataPacket : in std_logic_vector( 15 downto 0 );
		I2CClk, Sdin, Strobe : in std_logic;
		Sdout, Sclk, Busy : out std_logic );
End Entity I2CTx;

Architecture Structural of I2CTx is
	Signal Op : RegOp;
Begin
	DP: Entity Work.I2CTxDp port map (I2CClk, DataPacket, Sdout, Op);
	CU: Entity Work.I2CTxCu(NestedFSM) port map (I2CClk, Strobe, Sdin, Op, Busy, Sclk);
End Architecture Structural;



--********************************************************************
-- The Transmitter shift register.
--********************************************************************
Use Work.Codec.all;

Library ieee;
Use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

Entity I2CTxDp is
	port (
		Clk : in std_logic;
		Data16 : in std_logic_vector( 15 downto 0 );
		LeftOut : out std_logic;
		Op : in RegOp );
End Entity I2CTxDp;

Architecture Reg29bit of I2CTxDp is
	Signal RegQ, RegD : std_logic_vector( 28 downto 0 ); --24 bit of data, 3 dummy, 2 framing.
Begin
	RegQ <= RegD when (rising_edge(Clk));
	with (op) select
		RegD <= 	RegQ when hold,
					RegQ( 27 downto 0) & '1' when shift,
					"11111111111111111111111111111" when set,
					'0'& "00110100" & '1' & Data16(15 downto 8) & '1' & Data16(7 downto 0) & '1' & '0' when init;
	LeftOut <= RegQ(28);
End Architecture Reg29bit;
--********************************************************************
