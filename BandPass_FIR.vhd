library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all; 
library work;
use work.bandpass_fir_package.all;

entity BandPassFIR is
  port( clk, resetn : in std_logic;
    in1 :in std_logic_vector(size-1 downto 0);
    out1 :out std_logic_vector(2*size-1 downto 0) );
end BandPassFIR;

architecture Behavioral of BandPassFIR is
  
type delay_signal is array (0 to taps) of Std_logic_vector( size-1 downto 0);
signal delay_in,delay_out : delay_signal;

type mul_out_signal is array (0 to taps-1) of Std_logic_vector(2*size -1 downto 0);
signal mul_out : mul_out_signal;

signal sum : std_logic_vector(2*size-1 downto 0);
signal sample : std_logic_vector(2*size-1 downto 0);
 
begin

delay_in(0) <= in1;
--out1 <= sum;
out1 <= sample;
  
TAPS_logic: for i in 0 to taps-1 generate
  delay_in(i+1) <= delay_out(i);
  COEFF_MUL: mul_out(i) <= std_logic_vector( signed(delay_out(i)) * C(i) );

DELAY_FF : process(clk, resetn)
  begin 
    if resetn='0' then
      delay_out(i) <= (others=>'0'); 
    elsif clk'event and clk='1' then
      delay_out(i) <= delay_in(i);
    end if;
  end process;
  
end generate TAPS_logic;

ADDER: process(mul_out)
  variable sum_var : signed(2*size-1 downto 0);
  begin
    sum_var := (others=>'0');
    for i in 0 to taps-1 loop
      sum_var := sum_var + signed(mul_out(i));
    end loop;
    sum <= std_logic_vector(sum_var);
  end process;
  
SAMPLE_FF: process(clk, resetn)
  begin 
    if resetn='0' then
      sample <= (others=>'0');
    elsif clk'event and clk='1' then
      sample <= sum;
    end if;
  end process;
  
end Behavioral;