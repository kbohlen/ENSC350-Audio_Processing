-----STANDARD FIFO-----
-- 
-- Adapted from http://www.deathbylogic.com/2015/01/vhdl-first-word-fall-through-fifo/
-- 
-----END STANDARD FIFO-----

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
 
entity FIFO is
	Generic(
		constant DATA_WIDTH  : positive := 2;
		constant FIFO_DEPTH	: positive := 256 );
	Port( 
		CLK		: in  STD_LOGIC;
		RST		: in  STD_LOGIC;
		WriteEn	: in  STD_LOGIC;
		DataIn	: in  SIGNED (DATA_WIDTH - 1 downto 0);
		ReadEn	: in  STD_LOGIC;
		DataOut	: out SIGNED (DATA_WIDTH - 1 downto 0);
		Empty		: out STD_LOGIC;
		Full		: out STD_LOGIC );
end FIFO;
 
architecture Behavioral of FIFO is
 
begin
 
	-- Memory Pointer Process
	fifo_proc : process (CLK)
		type FIFO_Memory is array (0 to FIFO_DEPTH - 1) of SIGNED (DATA_WIDTH - 1 downto 0);
		variable Memory : FIFO_Memory;
		
		variable Head : natural range 0 to FIFO_DEPTH - 1;
		variable Tail : natural range 0 to FIFO_DEPTH - 1;
		
		variable Looped : boolean;
	begin
		if rising_edge(CLK) then
			if RST = '1' then
				Head := 0;
				Tail := 0;				
				Looped := false;				
				Full  <= '0';
				Empty <= '1';
			else
				if (ReadEn = '1') then
					if ((Looped = true) or (Head /= Tail)) then
						-- Update data output
						DataOut <= Memory(Tail);						
						-- Update Tail pointer as needed
						if (Tail = FIFO_DEPTH - 1) then
							Tail := 0;							
							Looped := false;
						else
							Tail := Tail + 1;
						end if;						
					end if;
				end if;
				
				if (WriteEn = '1') then
					if ((Looped = false) or (Head /= Tail)) then
						-- Write Data to Memory
						Memory(Head) := DataIn;					
						-- Increment Head pointer as needed
						if (Head = FIFO_DEPTH - 1) then
							Head := 0;						
							Looped := true;
						else
							Head := Head + 1;
						end if;
					end if;
				end if;
				
				-- Update Empty and Full flags
				if (Head = Tail) then
					if Looped then
						Full <= '1';
					else
						Empty <= '1';
					end if;
				else
					Empty	<= '0';
					Full	<= '0';
				end if;
			end if;
		end if;
	end process;
		
end Behavioral;

-----FSM Delay-----
-- 
-- Adapted from http://vhdlguru.blogspot.ca/2011/07/delay-in-vhdl-without-using-wait-for.html
-- 
-----END FSM Delay-----

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity delay is 
	generic(
		constant d : integer := 100 ); --number of clock cycles by which input should be delayed. --500 good
	port(
		Clk : in std_logic;
      valid_data : in std_logic; -- goes high when the input is valid.
      data_in : in std_logic; -- the data input
      data_out : out std_logic ); --the delayed input data.
end delay;

architecture Behavioral of delay is

	signal c : integer;
	signal data_temp : std_logic;
	type state_type is (idle,delay_c); --defintion of state machine type
	signal next_s : state_type; --declare the state machine signal.

begin

	process(Clk)
	begin
		if(rising_edge(Clk)) then
			case next_s is 
				when idle =>
					if(valid_data= '1') then
						next_s <= delay_c;
						data_temp <= data_in; --register the input data.
						c <= 1;
					end if;
				when delay_c =>
					if(c = d) then
						c <= 1; --reset the count
						data_out <= data_temp; --assign the output
						next_s <= idle; --go back to idle state and wait for another valid data.
					else
						data_out <= '0';
						c <= c + 1;
					end if;
				when others =>
					NULL;
			end case;
		end if;
	end process;    
    
end Behavioral;