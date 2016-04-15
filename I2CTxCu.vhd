Use Work.Codec.all;

Library ieee;
Use ieee.std_logic_1164.all;

Entity I2CTxCu is
	port (
		Clk, Go, Sdin : in std_logic;
		Op : out RegOp;
		Busy, Sclk : out std_logic );
End Entity I2CTxCu;


Architecture NestedFSM of I2CTxCu is
	Type MainCode is ( idle, start, Packet0, Packet1, Packet2, stop, Mwait );
	Type PacketCode is ( D7, D6, D5, D4, D3, D2, D1, D0, Ack );
	Type CycleCode is ( C0, C1, C2, C3 );
	
	Attribute syn_encoding : string;
	Attribute syn_encoding of MainCode : type is "compact";
	Attribute syn_encoding of PacketCode : type is "compact";
	Attribute syn_encoding of CycleCode : type is "compact";
	
	Signal MainState, NextMainState : MainCode;
	Signal PacketState, NextPacketState : PacketCode;
	Signal CycleState, NextCycleState : CycleCode;

	Signal EOC, EOP, BadAck : std_logic;
	
	Attribute keep : boolean;
	Attribute keep of BadAck : signal is true;
Begin

MSR:	MainState <= NextMainState when (rising_edge(Clk)) else MainState;
MIFL:	NextMainState <= 
			idle when MainState = idle and Go = '0' else
			Mwait when MainState = Mwait and Go = '1' else
			idle when BadAck = '1' else 

			start when MainState = start and EOC = '0' else
			stop when MainState = stop and EOC = '0' else
			Packet0 when MainState = Packet0 and (EOC = '0' or EOP = '0') else 
			Packet1 when MainState = Packet1 and (EOC = '0' or EOP = '0') else 
			Packet2 when MainState = Packet2 and (EOC = '0' or EOP = '0') else 

			start when MainState = idle and Go = '1' else 
			Packet0 when MainState = start and EOC = '1' else
			Packet1 when MainState = Packet0 and EOC = '1' and EOP = '1' else
			Packet2 when MainState = Packet1 and EOC = '1' and EOP = '1' else

			stop when MainState = Packet2 and EOC = '1' and EOP = '1' else
			Mwait when MainState = stop and EOC = '1' else
			idle when MainState = Mwait and Go = '0' else
			idle;
			
CSR:	CycleState <= NextCycleState when (rising_edge(Clk)) else CycleState;
CIFL:	NextCycleState <= 
			C0 when CycleState = C0 and MainState = idle else
			C0 when CycleState = C0 and MainState = Mwait else
			C0 when CycleState = C1 and MainState = start else
			C0 when CycleState = C2 and MainState = stop else
			C0 when CycleState = C3 and (MainState = Packet0 or MainState = Packet1 or MainState = Packet2) else
			C1 when CycleState = C0 and MainState /= idle else
			C0 when BadAck = '1' else
			C2 when CycleState = C1 and MainState /= start else
			C3 when CycleState = C2 and MainState /= stop else
			C0;
COFL:	EOC <=
			'1' when CycleState = C0 and MainState = Idle else
			'1' when CycleState = C1 and MainState = start else
			'1' when CycleState = C2 and MainState = stop else
			'1' when CycleState = C3 else
			'0';
		BadAck <= '1' when PacketState = ack and CycleState = C1 and Sdin = '1' else '0'; 
			
PSR:	PacketState <= NextPacketState when (rising_edge(Clk)) else PacketState;
PIFL:	NextPacketState <=
			D7 when BadAck = '1' else
			D7 when PacketState = D7 and EOC = '0' else
			D6 when PacketState = D6 and EOC = '0' else
			D5 when PacketState = D5 and EOC = '0' else
			D4 when PacketState = D4 and EOC = '0' else
			D3 when PacketState = D3 and EOC = '0' else
			D2 when PacketState = D2 and EOC = '0' else
			D1 when PacketState = D1 and EOC = '0' else
			D0 when PacketState = D0 and EOC = '0' else
			ack when PacketState = ack and EOC = '0' else
			D7 when PacketState = D7 and
					(MainState = start or MainState = stop or
					 MainState = idle  or MainState = Mwait) else
			D6 when PacketState = D7 and
					(MainState = Packet0 or MainState = Packet1 or MainState = Packet2) else
			D5 when PacketState = D6 and EOC = '1' else
			D4 when PacketState = D5 and EOC = '1' else
			D3 when PacketState = D4 and EOC = '1' else
			D2 when PacketState = D3 and EOC = '1' else
			D1 when PacketState = D2 and EOC = '1' else
			D0 when PacketState = D1 and EOC = '1' else
			ack when PacketState = D0 and EOC = '1' else
			D7;
			
POFL:	EOP <= '1' when PacketState = ack else '0';

		Busy <= '0' when MainState = idle else '1';

		Op <= shift when CycleState = C3 else
				shift when CycleState = C1 and ( MainState = start or MainState = stop ) else
				set when MainState = idle else
				init when CycleState = C0 and MainState = start else
				hold;

		Sclk <= 
			'1' when CycleState = C1 or CycleState = C2 else
			'1' when MainState = start or MainState = idle or mainState = Mwait else
			'0';
End Architecture NestedFSM;