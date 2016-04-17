library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.LowPass_fir_package.all;

entity InputMixer is

	port 
	(
		SW : in std_logic_vector(17 downto 0);
		KEY : in std_logic_vector(3 downto 0);
		CLOCK_50 : in std_logic;
		LEDG : out std_logic_vector (8 downto 0);
		LEDR : out std_logic_vector (17 downto 0);
		HEX0 : out std_logic_vector(6 downto 0);
		HEX1 : out std_logic_vector(6 downto 0);
		HEX2 : out std_logic_vector(6 downto 0);
		HEX3 : out std_logic_vector(6 downto 0);
		HEX4 : out std_logic_vector(6 downto 0);
		HEX5 : out std_logic_vector(6 downto 0);
		HEX6 : out std_logic_vector(6 downto 0);
		HEX7 : out std_logic_vector(6 downto 0);
		
		--AUDIO
		AUD_XCK : out std_logic;
		I2C_SCLK : out std_logic;
		I2C_SDAT : inout std_logic;
		AUD_BCLK, AUD_ADCLRCK, AUD_DACLRCK, AUD_ADCDAT : in std_logic;
		AUD_DACDAT : out std_logic;
		SamClk : out std_logic 
	);

end entity;

architecture behave of InputMixer is

	component FIFO is
		generic(
			constant DATA_WIDTH : positive := 2;
			constant FIFO_DEPTH	: positive := 256 );
		port( 
			CLK		: in  STD_LOGIC;
			RST		: in  STD_LOGIC;
			WriteEn	: in  STD_LOGIC;
			DataIn	: in  SIGNED (DATA_WIDTH - 1 downto 0);
			ReadEn	: in  STD_LOGIC;
			DataOut	: out SIGNED (DATA_WIDTH - 1 downto 0);
			Empty	: out STD_LOGIC;
			Full	: out STD_LOGIC );
	end component;
	
	component delay is
		generic(
			constant d : integer := 100 ); --number of clock cycles by which input should be delayed. --500 good
		port(
			Clk : in std_logic;
			valid_data : in std_logic; -- goes high when the input is valid.
			data_in : in std_logic; -- the data input
			data_out : out std_logic ); --the delayed input data.
	end component;
	
	component HighPassFIR is
		port( clk, resetn : in std_logic;
				in1 :in std_logic_vector(size-1 downto 0);
				out1 :out std_logic_vector(2*size-1 downto 0) );
	end component;
	
	component LowPassFIR is
		port( clk, resetn : in std_logic;
				in1 :in std_logic_vector(size-1 downto 0);
				out1 :out std_logic_vector(2*size-1 downto 0) );
	end component;
	
	component BandPassFIR is
		port( clk, resetn : in std_logic;
				in1 :in std_logic_vector(size-1 downto 0);
				out1 :out std_logic_vector(2*size-1 downto 0) );
	end component;

	component segment7_conv
		port( D : in std_logic_vector(4 downto 0);  -- HEX input
				O : out std_logic_vector(6 downto 0) );  -- 7 bit decoded output.
	end component;

		signal myAudioOutL : signed(15 downto 0);
		signal myAudioOutR : signed(15 downto 0);
		signal myAudioInL : signed(15 downto 0);
		signal myAudioInR : signed(15 downto 0);
		
		signal AuSamClk : std_logic;
		
		signal funct_sel : std_logic;
	
		signal key2_pressed : std_logic;
		-----MONO-----
		signal myMonoOutL : signed(15 downto 0);
		signal myMonoOutR : signed(15 downto 0);
		-----VOLUME-----
		signal vol_down_action : std_logic;
		signal vol_up_action : std_logic;
		signal vol_value : signed(3 downto 0);
		signal vol_value_sign : std_logic;
		signal vol_key0_pressed : std_logic;
		signal vol_key1_pressed : std_logic;
		signal vol_shift_value : signed(3 downto 0);
		signal myVolumeOutL : signed(15 downto 0);
		signal myVolumeOutR : signed(15 downto 0);
		-----BALANCE-----
		signal bal_right_action : std_logic;
		signal bal_left_action : std_logic;
		signal bal_value : signed(3 downto 0);
		signal bal_value_sign : std_logic;
		signal bal_key0_pressed : std_logic;
		signal bal_key1_pressed : std_logic;
		signal bal_shift_value : signed(3 downto 0);
		signal myBalanceOutL : signed(15 downto 0);
		signal myBalanceOutR : signed(15 downto 0);
		-----FIFO-----
		signal c : integer := 0;
		constant d : integer := 100; --number of clock cycles by which input should be delayed.
		signal data_temp : std_logic := '0';
		type state_type is (idle,delay_c); --defintion of state machine type
		signal next_s : state_type; --declare the state machine signal.
		signal FifoReadEnL : STD_LOGIC;
		signal FifoReadEnR : STD_LOGIC;
		signal myFIFOOutL : signed(15 downto 0);
		signal myFIFOOutR : signed(15 downto 0);
		signal myEchoOutL : signed(15 downto 0);
		signal myEchoOutR : signed(15 downto 0); 
		-----LOW PASS-----
		signal myLowPassOutRawL : std_logic_vector(31 downto 0);
		signal myLowPassOutRawR : std_logic_vector(31 downto 0);
		signal myLowPassOutL : signed(15 downto 0);
		signal myLowPassOutR : signed(15 downto 0);
		-----HIGH PASS-----
		signal myHighPassOutRawL : std_logic_vector(31 downto 0);
		signal myHighPassOutRawR : std_logic_vector(31 downto 0);
		signal myHighPassOutL : signed(15 downto 0);
		signal myHighPassOutR : signed(15 downto 0);
		-----BAND PASS-----
		signal myBandPassOutRawL : std_logic_vector(31 downto 0);
		signal myBandPassOutRawR : std_logic_vector(31 downto 0);
		signal myBandPassOutL : signed(15 downto 0);
		signal myBandPassOutR : signed(15 downto 0);
		-----DISPLAY-----
		signal letter_2 : std_logic_vector(4 downto 0);
		signal letter_1 : std_logic_vector(4 downto 0);
		signal letter_0 : std_logic_vector(4 downto 0);
		
begin

-------------------------- AUDIO ------------------------
ASSS: Entity Work.AudioSubSystemStereo 
port map (
	 iClk_50 	=> Clock_50,
	 AudMclk 	=> AUD_XCK,
	 Init 		=> not Key(3),				-- This is to initialize the Audio codec
	 I2C_Sclk 	=> I2C_SCLK,				-- CDC Reg initiation serial interface
	 I2C_Sdat 	=> I2C_SDAT,				-- CDC Reg initiation serial interface
	 Bclk 		=> AUD_BCLK,				-- CDC audio dout clk
	 AdcLrc 	=> AUD_ADCLRCK,				-- A/D Channel select signal
	 DacLrc 	=> AUD_DACLRCK,				-- D/A Channel select signal
	 AdcDat 	=> AUD_ADCDAT,
	 DacDat 	=> AUD_DACDAT,
	 SamClk 	=> AuSamClk, 				-- Sampling CLK
	 
	 AudioOutL 	=> myAudioOutL,				-- Outgoing  audio samples
	 AudioOutR 	=> myAudioOutR,				-- Outgoing  audio samples
	 AudioInL 	=> myAudioInL,				-- Incomming audio samples
	 AudioInR 	=> myAudioInR				-- Incomming audio samples
	 
 );
 
 SamClk <= AuSamClk;
-------------- Audio LoopBack ---------

-----BEGIN MONO-----

	myMonoOutR <= shift_right((myAudioInR + myAudioInL), 1) when SW(17) = '1' else myAudioInR;
	myMonoOutL <= shift_right((myAudioInR + myAudioInL), 1) when SW(17) = '1' else myAudioInL;	

-----END MONO-----

-----BEGIN FUNCTION SELECTOR-----
FUNCT_SELECT: process(clock_50)
	begin
	if (rising_edge(clock_50)) then
		if (key(2) = '0' and key2_pressed = '0') then
			if funct_sel = '0' then
				funct_sel <= '1';
				letter_2 <= "01011"; -- 'b'
				letter_1 <= "01010"; -- 'A'
			else
				funct_sel <= '0';
				letter_2 <= "11011"; -- 'V'
				letter_1 <= "00000"; -- 'O'
			end if;
		end if;
		
		key2_pressed <= not key(2);
		
		
	end if;
	end process;
-----END FUNCTION SELECTOR-----

-----BEGIN VOLUME-----
VOLUME: process(clock_50)
	begin
	if (rising_edge(clock_50) and funct_sel = '0') then
		if (key(0) = '0' and vol_key0_pressed = '0') then
			if vol_value > -8 then
				vol_value <= vol_value - 1;
			else
				vol_value <= x"8";
			end if;
		end if;

		if (key(1) = '0' and vol_key1_pressed = '0') then
			if vol_value < 7 then
				vol_value <= vol_value + 1;
			else 
				vol_value <= x"7";
			end if;
		end if;
		
		vol_key0_pressed <= not key(0);
		vol_key1_pressed <= not key(1);
		
		if vol_value < 0 then
			vol_value_sign <= '0';
			vol_down_action <= '1';
			vol_up_action <= '0';
			vol_shift_value <= 0 - vol_value;
		elsif vol_value > 0 then
			vol_up_action <= '1';
			vol_down_action <= '0';
			vol_shift_value <= vol_value;
		else
			vol_value_sign <= '1';
			vol_shift_value <= "0000";
			vol_up_action <= '0';
			vol_down_action <= '0';
		end if;
	end if;
end process;

myVolumeOutL <= shift_right(signed(myMonoOutL), to_integer(vol_shift_value)) when vol_down_action = '1' else
						shift_left(signed(myMonoOutL), to_integer(vol_shift_value)) when vol_up_action = '1' else  
						myMonoOutL;
						
myVolumeOutR <= shift_right(signed(myMonoOutR), to_integer(vol_shift_value)) when vol_down_action = '1' else
						shift_left(signed(myMonoOutR), to_integer(vol_shift_value)) when vol_up_action = '1' else
						myMonoOutR;	
						
-----END VOLUME-----
	
-----BEGIN BALANCE-----
BALANCE : process(clock_50)
	begin
	if (rising_edge(clock_50) and funct_sel = '1') then
		if (key(0) = '0' and bal_key0_pressed = '0') then
			if bal_value > -8 then
				bal_value <= bal_value - 1;
			else
				bal_value <= x"8";
			end if;
		end if;

		if (key(1) = '0' and bal_key1_pressed = '0') then
			if bal_value < 7 then
				bal_value <= bal_value + 1;
			else 
				bal_value <= x"7";
			end if;
		end if;
		
		bal_key0_pressed <= not key(0);
		bal_key1_pressed <= not key(1);
		
		if bal_value < 0 then
			bal_value_sign <= '0';
			bal_right_action <= '1';
			bal_left_action <= '0';
			bal_shift_value <= 0 - bal_value;
		elsif bal_value > 0 then
			bal_left_action <= '1';
			bal_right_action <= '0';
			bal_shift_value <= bal_value;
		else
			bal_value_sign <= '1';
			bal_shift_value <= "0000";
			bal_left_action <= '0';
			bal_right_action <= '0';
		end if;
	end if;
end process;

	myBalanceOutL <= shift_right(signed(myVolumeOutL), to_integer(bal_shift_value)) when bal_right_action = '1' else  
							myVolumeOutL;
	myBalanceOutR <= shift_right(signed(myVolumeOutR), to_integer(bal_shift_value)) when bal_left_action = '1' else
							myVolumeOutR;		
-----END BALANCE-----

-----BEGIN ECHO-----

	-- Left Echo
	FIFO_DelayL : delay 
		generic map (1000) 
		port map (clock_50, '1', '1', FifoReadEnL);

	FIFO_EchoL : FIFO 
		generic map (16, 32768) 
		port map(clock_50, not KEY(3), '1', myBalanceOutL, FifoReadEnL, myFIFOOutL, open, open);
	
	-- Right Echo
	FIFO_DelayR : delay 
		generic map (1000) 
		port map (clock_50, '1', '1', FifoReadEnR);

	FIFO_EchoR : FIFO 
		generic map (16, 32768) 
		port map(clock_50, not KEY(3), '1', myBalanceOutR, FifoReadEnR, myFIFOOutR, open, open);
	
	myEchoOutL <= shift_right((myFIFOOutL + myBalanceOutL), 1) when SW(16) = '1' else
						myBalanceOutL;
	myEchoOutR <= shift_right((myFIFOOutR + myBalanceOutR), 1) when SW(16) = '1' else 
						myBalanceOutR;

-----END ECHO-----

-----BEGIN FILTERS-----

LowPassFIRL : LowPassFIR
	port map (AuSamClk, KEY(3), std_logic_vector(myEchoOutL), myLowPassOutRawL);

LowPassFIRR : LowPassFIR
	port map (AuSamClk, KEY(3), std_logic_vector(myEchoOutR), myLowPassOutRawR);
			
	myLowPassOutL <= signed(myLowPassOutRawL(31 downto 16)) when sw(2) = '1' else myEchoOutL;
	myLowPassOutR <= signed(myLowPassOutRawR(31 downto 16)) when sw(2) = '1' else myEchoOutR;
	
BandPassFIRL : BandPassFIR
	port map (AuSamClk, KEY(3), std_logic_vector(myLowPassOutL), myBandPassOutRawL);

BandPassFIRR : BandPassFIR
	port map (AuSamClk, KEY(3), std_logic_vector(myLowPassOutR), myBandPassOutRawR);
			
	myBandPassOutL <= signed(myBandPassOutRawL(31 downto 16)) when sw(1) = '1' else myLowPassOutL;
	myBandPassOutR <= signed(myBandPassOutRawR(31 downto 16)) when sw(1) = '1' else myLowPassOutR;
	
HighPassFIRL : HighPassFIR
	port map (AuSamClk, KEY(3), std_logic_vector(myBandPassOutL), myHighPassOutRawL);

HighPassFIRR : HighPassFIR
	port map (AuSamClk, KEY(3), std_logic_vector(myBandPassOutR), myHighPassOutRawR);
			
	myHighPassOutL <= signed(myHighPassOutRawL(31 downto 16)) when sw(0) = '1' else myBandPassOutL;
	myHighPassOutR <= signed(myHighPassOutRawR(31 downto 16)) when sw(0) = '1' else myBandPassOutR;	

-----END FILTERS-----

-----LED DISPLAY-----
LEDG_DISPLAY: process(vol_value, bal_value, sw(17))
	begin
	-----VOLUME-----
	if funct_sel = '0' then
		if (vol_value > -1 or vol_value < -7) then	 --Volume level 0  and  Volume level -8
			LEDG(0) <= '1';
		else
			LEDG(0) <= '0'; 
		end if;
		if (vol_value > 0 or vol_value < -6) then	 --Volume level 1 and Volume level -7
			LEDG(1) <= '1';
		else
			LEDG(1) <= '0';
		end if;
		if (vol_value > 1 or vol_value < -5) then   --Volume level 2  and Volume level -6
			LEDG(2) <= '1';
		else
			LEDG(2) <= '0';
		end if;
		if (vol_value > 2 or vol_value < -4) then	 --Volume level 3 and Volume level -5
			LEDG(3) <= '1';
		else
			LEDG(3) <= '0';
		end if;
		if (vol_value > 3 or vol_value < -3) then	 --Volume level 4  and Volume level -4
			LEDG(4) <= '1';
		else
			LEDG(4) <= '0';
		end if;
		if (vol_value > 4 or vol_value < -2) then	 --Volume level 5 and  Volume level -3
			LEDG(5) <= '1';
		else
			LEDG(5) <= '0';
		end if;
		if (vol_value > 5 or vol_value < -1) then	 --Volume level 6 and Volume level -2
			LEDG(6) <= '1';
		else
			LEDG(6) <= '0';
		end if;
		if (vol_value > 6 or vol_value < 0) then	 --Volume level 7 and Volume level -1
			LEDG(7) <= '1';
		else
			LEDG(7) <= '0';
		end if;
	end if;
	
	-----BALANCE-----
	if funct_sel = '1' then
		if (bal_value > -1 or bal_value < -7) then	 --Balance level 0  and  Balance level -8
			LEDG(0) <= '1';
		else
			LEDG(0) <= '0'; 
		end if;
		if (bal_value > 0 or bal_value < -6) then	 --Balance level 1 and Balance level -7
			LEDG(1) <= '1';
		else
			LEDG(1) <= '0';
		end if;
		if (bal_value > 1 or bal_value < -5) then   --Balance level 2  and Balance level -6
			LEDG(2) <= '1';
		else
			LEDG(2) <= '0';
		end if;
		if (bal_value > 2 or bal_value < -4) then	 --Balance level 3 and Balance level -5
			LEDG(3) <= '1';
		else
			LEDG(3) <= '0';
		end if;
		if (bal_value > 3 or bal_value < -3) then	 --Balance level 4  and Balance level -4
			LEDG(4) <= '1';
		else
			LEDG(4) <= '0';
		end if;
		if (bal_value > 4 or bal_value < -2) then	 --Balance level 5 and  Balance level -3
			LEDG(5) <= '1';
		else
			LEDG(5) <= '0';
		end if;
		if (bal_value > 5 or bal_value < -1) then	 --Balance level 6 and Balance level -2
			LEDG(6) <= '1';
		else
			LEDG(6) <= '0';
		end if;
		if (bal_value > 6 or bal_value < 0) then	 --Balance level 7 and Balance level -1
			LEDG(7) <= '1';
		else
			LEDG(7) <= '0';
		end if;
	end if;
	
	-----MONO-----
	if sw(17) = '1' then
		LEDG(8) <= '1';
	else
		LEDG(8) <= '0';
	end if;
	
end process;
-----END LED DISPLAY-----

-----INTENSIY-----
bumpinLEDSR : process (myAudioOutR)
	begin

	if (myAudioOutR > 5 or myAudioOutR < -5) then
		LEDR(8) <= '1';
	else
		LEDR(8) <= '0';
	end if;
	if (myAudioOutR > 10 or myAudioOutR < -10) then
		LEDR(7) <= '1';
	else
		LEDR(7) <= '0';
	end if;
	if (myAudioOutR > 30 or myAudioOutR < -30) then
		LEDR(6) <= '1';
	else
		LEDR(6) <= '0';
	end if;
	if (myAudioOutR > 60 or myAudioOutR < -60) then
		LEDR(5) <= '1';
	else
		LEDR(5) <= '0';
	end if;
	if (myAudioOutR > 100 or myAudioOutR < -100) then
		LEDR(4) <= '1';
	else
		LEDR(4) <= '0';
	end if;
	if (myAudioOutR > 200 or myAudioOutR < -200) then
		LEDR(3) <= '1';
	else
		LEDR(3) <= '0';
	end if;
	if (myAudioOutR > 400 or myAudioOutR < -400) then
		LEDR(2) <= '1';
	else
		LEDR(2) <= '0';
	end if;
	if (myAudioOutR > 800 or myAudioOutR < -800) then
		LEDR(1) <= '1';
	else
		LEDR(1) <= '0';
	end if;
	if (myAudioOutR > 1600 or myAudioOutR < -1600) then
		LEDR(0) <= '1';
	else
		LEDR(0) <= '0';
	end if;
end process;

bumpinLEDSL : process (myAudioOutL)
	begin
	
	if (myAudioOutL > 5 or myAudioOutL < -5) then
		LEDR(9) <= '1';
	else
		LEDR(9) <= '0';
	end if;
	if (myAudioOutL > 10 or myAudioOutL < -10) then
		LEDR(10) <= '1';
	else
		LEDR(10) <= '0';
	end if;
	if (myAudioOutL > 30 or myAudioOutL < -30) then
		LEDR(11) <= '1';
	else
		LEDR(11) <= '0';
	end if;
	if (myAudioOutL > 60 or myAudioOutL < -60) then
		LEDR(12) <= '1';
	else
		LEDR(12) <= '0';
	end if;
	if (myAudioOutL > 100 or myAudioOutL < -100) then
		LEDR(13) <= '1';
	else
		LEDR(13) <= '0';
	end if;
	if (myAudioOutL > 200 or myAudioOutL < -200) then
		LEDR(14) <= '1';
	else
		LEDR(14) <= '0';
	end if;
	if (myAudioOutL > 400 or myAudioOutL < -400) then
		LEDR(15) <= '1';
	else
		LEDR(15) <= '0';
	end if;
	if (myAudioOutL > 800 or myAudioOutL < -800) then
		LEDR(16) <= '1';
	else
		LEDR(16) <= '0';
	end if;
	if (myAudioOutL > 1600 or myAudioOutL < -1600) then
		LEDR(17) <= '1';
	else
		LEDR(17) <= '0';
	end if;
end process;
-----END INTENSITY-----	
	
-----7 SEG DISPLAY-----
	volume_display : segment7_conv 
		port map (std_logic_vector('0' & vol_shift_value), HEX6);
		
	volume_display_sign : segment7_conv
		port map (("1111" & vol_value_sign), HEX7);
		
	balance_display : segment7_conv
		port map (std_logic_vector('0' & bal_shift_value), HEX4);
		
	balance_display_direction : segment7_conv
		port map (("1110" & bal_value_sign), HEX5);
	
	seg3 : segment7_conv
		port map ("11111", HEX3);
		
	seg2 : segment7_conv
		port map (letter_2, HEX2);
		
	seg1 : segment7_conv
		port map (letter_1, HEX1);
		
	seg0 : segment7_conv
		port map ("11101", HEX0);
-----END 7 SEG DISPLAY-----

-----AUDIO OUT-----
-----BEGIN MUTE-----
	myAudioOutL <= myHighPassOutL when SW(15) = '0' else (others => '0');
	myAudioOutR <= myHighPassOutR when SW(15) = '0' else (others => '0');
-----END MUTE-----	
	
end behave;
