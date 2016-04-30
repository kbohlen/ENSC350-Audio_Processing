library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all; 

package HighPass_FIR_package is
  constant SIZE : positive := 16;
  constant TAPS : positive := 35;
  type coefficients is array (0 to taps-1) of integer;
  constant C : coefficients := (-759,
  3893,
  -3928,
  1878,
  -5103,
  4346,
  -5235,
  7489,
  -5306,
  9952,
  -6927,
  9725,
  -11372,
  6311,
  -17521,
  1909,
  -22068,
  65438,
  -22068,
  1909,
  -17521,
  6311,
  -11372,
  9725,
  -6927,
  9952,
  -5306,
  7489,
  -5235,
  4346,
  -5103,
  1878,
  -3928,
  3893,
  -759);
end package;