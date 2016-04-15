Library ieee;
Use ieee.std_logic_1164.all;
Use ieee.numeric_std.all;

--Library altera;
--Use altera.altera_syn_attributes.all;

--***************************************************************************
-- Notes: Init is active high. SwitchWord is latched on the next clock.
-- the I2C sequencing begins when init = '1' and is NOT retriggerable
-- Mode 01 = Avalon Slave ignores init.
--***************************************************************************
Entity CodecInit is
	Port (
		ModeIn : in std_logic_vector(1 downto 0);
		I2CClk : in std_logic;
		Sdin, Init : in std_logic;
		Sdout, Sclk : out std_logic;
		SwitchWord : in std_logic_vector(15 downto 0) );
End Entity CodecInit;

Architecture Source4 of CodecInit is
	Signal Go, Busy : std_logic;
	Signal Mode : std_logic_vector(1 downto 0);
	Signal MuxOut, Rom1Data, Rom2Data, SwitchReg, SlaveReg : std_logic_vector(15 downto 0);
	Signal AddrCnt, NextCnt : unsigned(3 downto 0);
	Signal LatchEn, IncRomAddr, ClrRomAddr : std_logic;
Begin
--***************************************************************************
-- 16 bit Data from Avalon Bus is latched into SlaveReg using Init.
-- Handshakes with CU using SlaveRegFull and ClrFullFlag signals.
--***************************************************************************
	SlaveReg <= SwitchWord when ( Rising_Edge(I2CClk) and LatchEn = '1' ) else SlaveReg;
--***************************************************************************
-- 16 bit Data incoming on SwitchWord is latched into SwitchReg usint Init.
--***************************************************************************
	SwitchReg <= SwitchWord when ( Rising_Edge(I2CClk) and LatchEn = '1' ) else SwitchReg;
--***************************************************************************
-- Store the 2 mode bits using the rising edge of Init.
-- 00 => manual, 01 => avalon slave, 10 => ROM1, 11 => ROM2
-- Build MUX to selct Data source using the Mode bits
--***************************************************************************
	Mode <= ModeIn when ( Rising_Edge(I2CClk) and LatchEn = '1' ) else Mode;
	With Mode select MuxOut <=
		SwitchReg when "00", SlaveReg when "01",
		Rom1Data when "10", Rom2Data when "11",
		SwitchReg when others;		
--***************************************************************************
-- Build a two 16x16 ROMs as we have a spare MUX channel.
--***************************************************************************
RB:	Block
			Signal	Rom1Addr, Rom2Addr : unsigned(3 downto 0);
		Begin
			Rom1Addr <= AddrCnt;
			with Rom1Addr select Rom1Data <=
			--LOWER BANK
				-- reset and power up
				"0001111" & "000000000" when "0000",
				"0000110" & "000000000" when "0001",
				-- amplifiers and mute - full volume
				"0000000" & "100011111" when "0010",
				"0000010" & "101111111" when "0011",
				-- audio path - LineIn to ADC and DAC to HP, Bypass is OFF
				"0000100" & "011010010" when "0100",
				-- remove soft mute on DAC
				"0000101" & "000000000" when "0101",
				-- data format - MASTER, 16 bits left justified
				"0000111" & "001000001" when "0110",
				-- sample rate - 4Mclk=1Bclk, 32 Bclks per channel
				"0001000" & "000000000" when "0111",
				-- activate the data interface
				"0001001" & "000000001" when "1000",
				-- do nothing
				"0000000" & "000000000" when others;
			--UPPER BANK
			Rom2Addr <= AddrCnt;
			with Rom2Addr select Rom2Data <=
				-- reset and power up
				"0001111" & "000000000" when "0000",
				"0000110" & "000000000" when "0001",
				-- amplifiers and mute - full volume
				"0000000" & "100011111" when "0010",
				"0000010" & "101111111" when "0011",
				-- audio path - LineIn to ADC, DAC to HP, Bypass is OFF
				"0000100" & "011010010" when "0100",
				-- remove soft mute on DAC
				"0000101" & "000000000" when "0101",
				-- data format - MASTER, 24 bits right justified
				"0000111" & "001001000" when "0110",
				-- sample rate - 6Mclk=1Bclk, 32 Bclks per channel
				"0001000" & "000000010" when "0111",
				-- activate the interface
				"0001001" & "000000001" when "1000",
				-- do nothing
				"0000000" & "000000000" when others;
			End Block RB;
--***************************************************************************
-- Both ROMs share an address counter.
-- Initialize RON address to -1 -- NEED TO RETHINK THIS.
--***************************************************************************
			AddrCnt <= NextCnt when ( Rising_Edge(I2CClk) ) else AddrCnt;
			NextCnt <= "1111" when ClrRomAddr = '1' else
						AddrCnt + 1 when IncRomAddr = '1' else AddrCnt;
--***************************************************************************
-- The Control Unit to sequence the data to the Serial Transmotter.
--***************************************************************************
CU:	Block ( Rising_Edge(I2CClk) )
			Type StateName is ( Idle, WE, W0, X0, W1, X1, W2, X2, W3, X3,
										 W4, X4, W5, X5, W6, X6, W7, X7, W8, X8 );
			Attribute syn_encoding : string;
			Attribute syn_encoding of StateName : type is "compact";
										 
			Signal State, NextState : StateName;
		Begin
			State <= guarded NextState;
			NextState <= Idle when State = Idle and init = '0' else
							W0   when State = Idle and init = '1' else

							W0   when State = W0   and busy = '1' else
							X0   when State = W0   and busy = '0' else
							WE   when State = X0   and Mode(1) = '0' else
							W1   when State = X0   and Mode(1) = '1' else
							
							W1   when State = W1   and busy = '1' else
							X1   when State = W1   and busy = '0' else
							W2   when State = X1   else
							W2   when State = W2   and busy = '1' else
							X2   when State = W2   and busy = '0' else
							W3   when State = X2   else
							W3   when State = W3   and busy = '1' else
							X3   when State = W3   and busy = '0' else
							W4   when State = X3   else
							W4   when State = W4   and busy = '1' else
							X4   when State = W4   and busy = '0' else
							W5   when State = X4   else
							W5   when State = W5   and busy = '1' else
							X5   when State = W5   and busy = '0' else
							W6   when State = X5   else
							W6   when State = W6   and busy = '1' else
							X6   when State = W6   and busy = '0' else
							W7   when State = X6   else
							W7   when State = W7   and busy = '1' else
							X7   when State = W7   and busy = '0' else
							W8   when State = X7   else
							W8   when State = W8   and busy = '1' else
							X8   when State = W8   and busy = '0' else
							WE   when State = X8   else

							WE   when State = WE   and init = '1' else
							Idle when State = WE   and init = '0' else
							Idle;
-- LatchEn is used to setup the SwitchReg and Clear the Address Counter.							
			LatchEn <= '1' when State = Idle and init = '1' else '0';
			ClrRomAddr <= LatchEn;
-- Go is used to transfer the output of the MUX to the transmitter.
-- The same signal can be used to increment the ROM position.
			with State select Go <= '1' when X0 | X1 | X2 | X3 |
														X4 | X5 | X6 | X7 | X8 ,
										   '0' when others;

			IncRomAddr <= Go;
		End Block CU;

--***************************************************************************
-- This is the Serial Transmitter that has a 16-bit input and handshakes
-- with Go and Busy.
--***************************************************************************
TX: Entity Work.I2CTx port map( MuxOut, I2CClk, Sdin, Go, Sdout, Sclk, Busy );
End Architecture Source4;