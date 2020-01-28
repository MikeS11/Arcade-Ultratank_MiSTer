//============================================================================
//  Ultratank port to MiSTer
//  Copyright (c) 2020 Aitor Pelaez - NeuroRulez
//  EMU level .sv based on Alan Steremberg - alanswx work
//
//   
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        VGA_CLK,

	//Multiple resolutions are supported using different VGA_CE rates.
	//Must be based on CLK_VIDEO
	output        VGA_CE,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,

	//Base video clock. Usually equals to CLK_SYS.
	output        HDMI_CLK,

	//Multiple resolutions are supported using different HDMI_CE rates.
	//Must be based on CLK_VIDEO
	output        HDMI_CE,

	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_DE,   // = ~(VBlank | HBlank)
	output  [1:0] HDMI_SL,   // scanlines fx

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] HDMI_ARX,
	output  [7:0] HDMI_ARY,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,    // 1 - signed audio samples, 0 - unsigned

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT
);

assign VGA_F1    = 0;
assign USER_OUT  = '1;
assign LED_USER  = ioctl_download;
assign LED_DISK  = lamp2;
assign LED_POWER = lamp1;

assign HDMI_ARX = status[1] ? 8'd16 : 8'd4;
assign HDMI_ARY = status[1] ? 8'd9  : 8'd3;


`include "build_id.v"
localparam CONF_STR = {
	"A.ULTRATNK;;",
	"O1,Aspect Ratio,Original,Wide;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",  
	"-;",
	"O89,Extended Play,none,25pts,50pts,75pts;",
	"OAB,Game time,150 Sec,120 Sec,90 Sec,60 Sec;",
	"OC,Color,Off,On;",
	"OD,Test,Off,On;",
	"OE,Invisible tanks,Off,On;",
	"OF,Rebounding shells,Off,On;",
	"OG,Barriers,On,Off;",
	"-;",
	"R0,Reset;",
	"J1,Fire,Start 1P,Start 2P,Coin;",
	"V,v",`BUILD_DATE
};



wire [31:0] status;
wire  [1:0] buttons;
wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [7:0] ioctl_data;

wire        forced_scandoubler;
wire [21:0] gamma_bus;
wire [10:0] ps2_key;

wire [15:0] joy1, joy2;


hps_io #(.STRLEN(($size(CONF_STR)>>3) )) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),
	
	.buttons(buttons),
	.status(status),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),


	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),
	
	.joystick_0(joy1),
	.joystick_1(joy2),
	.ps2_key(ps2_key)
);



wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];
	
	if(old_state != ps2_key[10]) begin
		casex(code)
			'hX75: btn_up          <= pressed; // up
			'hX72: btn_down        <= pressed; // down
			'hX6B: btn_left        <= pressed; // left
			'hX74: btn_right       <= pressed; // right
			'h014: btn_fire        <= pressed; // ctrl			

			'h005: btn_one_player  <= pressed; // F1
			'h006: btn_two_players <= pressed; // F2
			'h004: btn_coin        <= pressed; // F3
			
			// JPAC/IPAC/MAME Style Codes
			'h016: btn_start_1     <= pressed; // 1
			'h01E: btn_start_2     <= pressed; // 2
			'h02E: btn_coin_1      <= pressed; // 5
			'h036: btn_coin_2      <= pressed; // 6

			'h02D: btn_up_2        <= pressed; // R
			'h02B: btn_down_2      <= pressed; // F
			'h023: btn_left_2      <= pressed; // D
			'h034: btn_right_2     <= pressed; // G
			'h01C: btn_fire_2      <= pressed; // A
		endcase
	end
end

reg btn_up    = 0;
reg btn_down  = 0;
reg btn_right = 0;
reg btn_left  = 0;
reg btn_fire  = 0;

reg btn_one_player  = 0;
reg btn_two_players = 0;

reg btn_start_1=0;
reg btn_start_2=0;
reg btn_coin  = 0;
reg btn_coin_1=0;
reg btn_coin_2=0;
reg btn_up_2=0;
reg btn_down_2=0;
reg btn_left_2=0;
reg btn_right_2=0;
reg btn_fire_2=0;

wire m_fire     = btn_fire    | joy1[4];
wire m_fire_2   = btn_fire_2  | joy2[4];
wire m_start    = btn_start_1 | joy1[5] | joy2[5];
wire m_start_2  = btn_start_2 | joy1[6] | joy2[6];
wire m_coin     = btn_coin    | joy1[7] | joy2[7] | btn_coin_1 | btn_coin_2;

wire m_up      = btn_up      | joy1[3];
wire m_down    = btn_down    | joy1[2];
wire m_left    = btn_left    | joy1[1];
wire m_right   = btn_right   | joy1[0];
wire m_up_2    = btn_up_2    | joy2[3];
wire m_down_2  = btn_down_2  | joy2[2];
wire m_left_2  = btn_left_2  | joy2[1];
wire m_right_2 = btn_right_2 | joy2[0];

//Convert from Two Levels to a Joystick
/*
	       Up_Left   |  Up    |    Up_Right    |  Right  |  Down_Right   | Down  |  Down_Left | Left
JoyY_Fw	           |   x    |       x        |    x    |               |       |            |
JoyY_Bk	           |        |                |         |      x        |   x   |            |  x
JoyZ_Fw      x      |   x    |                |         |               |       |            |  x
JoyZ_Bk             |        |                |    x    |               |   x   |      x     |
*/  
reg JoyW_Fw,JoyW_Bk,JoyX_Fw,JoyX_Bk;
reg JoyY_Fw,JoyY_Bk,JoyZ_Fw,JoyZ_Bk;
always @(posedge clk_sys) begin 
	case ({m_up,m_down,m_left,m_right}) // Up,down,Left,Right
		4'b1010: begin JoyW_Fw=0; JoyW_Bk=0; JoyX_Fw=1; JoyX_Bk=0; end //Up_Left
		4'b1000: begin JoyW_Fw=1; JoyW_Bk=0; JoyX_Fw=1; JoyX_Bk=0; end //Up
		4'b1001: begin JoyW_Fw=1; JoyW_Bk=0; JoyX_Fw=0; JoyX_Bk=0; end //Up_Right
		4'b0001: begin JoyW_Fw=1; JoyW_Bk=0; JoyX_Fw=0; JoyX_Bk=1; end //Right
		4'b0101: begin JoyW_Fw=0; JoyW_Bk=1; JoyX_Fw=0; JoyX_Bk=0; end //Down_Right
		4'b0100: begin JoyW_Fw=0; JoyW_Bk=1; JoyX_Fw=0; JoyX_Bk=1; end //Down
		4'b0110: begin JoyW_Fw=0; JoyW_Bk=0; JoyX_Fw=0; JoyX_Bk=1; end //Down_Left
		4'b0010: begin JoyW_Fw=0; JoyW_Bk=1; JoyX_Fw=1; JoyX_Bk=0; end //Left
		default: begin JoyW_Fw=0; JoyW_Bk=0; JoyX_Fw=0; JoyX_Bk=0; end
	endcase
	case ({m_up_2,m_down_2,m_left_2,m_right_2}) // Up,down,Left,Right
		4'b1010: begin JoyY_Fw=0; JoyY_Bk=0; JoyZ_Fw=1; JoyZ_Bk=0; end //Arriba_Izda
		4'b1000: begin JoyY_Fw=1; JoyY_Bk=0; JoyZ_Fw=1; JoyZ_Bk=0; end //Arriba
		4'b1001: begin JoyY_Fw=1; JoyY_Bk=0; JoyZ_Fw=0; JoyZ_Bk=0; end //Arriba_Derecha
		4'b0001: begin JoyY_Fw=1; JoyY_Bk=0; JoyZ_Fw=0; JoyZ_Bk=1; end //Derecha
		4'b0101: begin JoyY_Fw=0; JoyY_Bk=1; JoyZ_Fw=0; JoyZ_Bk=0; end //Abajo_Derecha		
		4'b0100: begin JoyY_Fw=0; JoyY_Bk=1; JoyZ_Fw=0; JoyZ_Bk=1; end //Abajo
		4'b0110: begin JoyY_Fw=0; JoyY_Bk=0; JoyZ_Fw=0; JoyZ_Bk=1; end //Abajo_Izquierda
		4'b0010: begin JoyY_Fw=0; JoyY_Bk=1; JoyZ_Fw=1; JoyZ_Bk=0; end //Izquierda
		default: begin JoyY_Fw=0; JoyY_Bk=0; JoyZ_Fw=0; JoyZ_Bk=0; end
	endcase
end


/*
-- Configuration DIP switches, these can be brought out to external switches if desired
-- See Ultra Tank manual page 6 for complete information. Active low (0 = On, 1 = Off)
--    1 	2							Extended Play		(11 - 75pts, 01 - 50pts, 10 - 25pts, 00 - None)
--   			3	4					Game Length			(11 - 60sec, 10 - 90sec, 01 - 120sec, 00 - 150sec) 
--						5	6			Game Cost   		(10 - 1 Coin, 1 Play, 01 - 2 Plays, 1 Coin, 11 - 2 Coins, 1 Play)
--								7	8	Unused?
*/

wire [7:0] SW1 = {2'b11, status[9:8], status[11:10],2'b10,2'b11}; //2'b10= 1 Coin = 1 Play

wire videowht,videoblk,compositesync,lamp1,lamp2;
wire video_r,video_g,video_b;

ultra_tank ultra_tank(
	.Clk_50_I(CLK_50M),
	.Reset_n(~(RESET | status[0]  | buttons[1] | ioctl_download)),

	.dn_addr(ioctl_addr[15:0]),
	.dn_data(ioctl_data),
	.dn_wr(ioctl_wr),

	.Video1_O(videowht),
	.Video2_O(videoblk),
	.CC0_O(video_b),
	.CC1_O(video_g),
	.CC2_O(video_r),
	.Sync_O(compositesync),
	.Audio1_O(audio1),
	.Audio2_O(audio2),
	
	.Coin1_I(~(m_coin|btn_coin_1)),
	.Coin2_I(~(m_coin|btn_coin_2)),
	.Start1_I(~(m_start1|btn_start_1)),
	.Start2_I(~(m_start2|btn_start_2)),
	.Invisible_I(~status[14]),
	.Rebound_I(~status[15]),
	.Barrier_I(~status[16]),
	
	.JoyW_Fw_I( ~JoyW_Fw ),
	.JoyW_Bk_I( ~JoyW_Bk ),
	.JoyX_Fw_I( ~JoyX_Fw ),
	.JoyX_Bk_I( ~JoyX_Bk ),
	.JoyY_Fw_I( ~JoyY_Fw ),
	.JoyY_Bk_I( ~JoyY_Bk ),
	.JoyZ_Fw_I( ~JoyZ_Fw ),
	.JoyZ_Bk_I( ~JoyZ_Bk ),
	.FireA_I(m_fire),
	.FireB_I(m_fire_2),
	
	.Test_I	(~status[13]),
	.Slam_I (1'b1),
	.LED1_O(lamp1),
	.LED2_O(lamp2),
	
	.hs_O(hs),
	.vs_O(vs),
	.hblank_O(hblank),
	.vblank_O(vblank),
	.clk_12(clk_12),
	.clk_6_O(CLK_VIDEO_2),
	.SW1(SW1)
	);
			
wire [6:0] audio1;
wire [6:0] audio2;
wire [1:0] video;
wire [3:0] videor;
///////////////////////////////////////////////////
wire clk_24,clk_12,CLK_VIDEO_2;
wire clk_sys,locked;
reg [7:0] vid_mono;

always @(posedge clk_sys) begin
		casex({videowht,videoblk})
			2'b01: vid_mono<=8'b01110000;
			2'b10: vid_mono<=8'b10000110;
			2'b11: vid_mono<=8'b11111111;
			2'b00: vid_mono<=8'b00000000;
		endcase
end

assign r=status[12] ? {3{video_r}} : vid_mono[7:5];
assign g=status[12] ? {3{video_g}} : vid_mono[7:5];
assign b=status[12] ? {3{video_b}} : vid_mono[7:5];
assign AUDIO_L={audio1,1'b0,8'b00000000};
assign AUDIO_R={audio2,1'b0,8'b00000000};
assign AUDIO_S = 0;

wire hblank, vblank;
wire hs, vs;
wire [2:0] r,g;
wire [2:0] b;

reg ce_pix;
always @(posedge clk_24) begin
        reg old_clk;

        old_clk <= CLK_VIDEO_2;
        ce_pix <= old_clk & ~CLK_VIDEO_2;
end

arcade_video #(320,9) arcade_video
(
        .*,

        .clk_video(clk_24),

        .RGB_in({r,g,b}),
        .HBlank(hblank),
        .VBlank(vblank),
        .HSync(hs),
        .VSync(vs),

        .fx(status[5:3]),
		  .rotate_ccw(0),
	     .no_rotate(1)		  
);

pll pll (
	.refclk ( CLK_50M   ),
	.rst(0),
	.locked 		( locked    ),        // PLL is running stable
	.outclk_0	( clk_24	),        // 24 MHz
	.outclk_1	( clk_12	)        // 12 MHz
	 );

assign clk_sys=clk_12;

endmodule
