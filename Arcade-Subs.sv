//============================================================================
//  Subs port to MiSTer
//  Copyright (c) 2021 Alan Steremberg - alanswx
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
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign VGA_F1    = 0;
assign VGA_SCALER= 0;
assign HDMI_FREEZE = 0;
assign VGA_DISABLE=0;

assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  
assign BUTTONS = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;
assign AUDIO_MIX = 0;






wire [1:0] ar = status[15:14];

assign VIDEO_ARX =  (!ar) ? ( 8'd4) : (ar - 1'd1);
assign VIDEO_ARY =  (!ar) ? ( 8'd3) : 12'd0;



`include "build_id.v"
localparam CONF_STR = {
	"A.SUBS;;",
	"H0OEF,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",  
	"-;",
	"DIP;",
	"-;",
	//"F2,OVR,Load Overlay;",
	"O1,Test,Off,On;",
	"O6,Overlay,On,Off;",
	//"O2,Monitor ,1,2;",
	// overlay alpha is useful for debugging
	//"OG,Overlay Alpha,On,Off;",
	// blend the vector with the overlay
	//"OH,Color Vector,Overlay On,White always;",
	//  tint the vector towards white
	//"OI,Tint Vector White,On,Off;",	
	"R0,Reset;",
	"J1,Fire,Start 1P,Coin;",
	"jn,A,Start,R;",
	"V,v",`BUILD_DATE
};


wire [31:0] status;
wire [15:0] sdram_sz;
wire  [1:0] buttons;
wire  		video_rotated=0;
wire        forced_scandoubler;
wire        direct_video;


wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [7:0]	ioctl_dout;
wire [15:0] ioctl_index;

wire [10:0] ps2_key;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy = joystick_0 | joystick_1;
wire [21:0] gamma_bus;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.status(status),
	.status_menumask(direct_video),
	.forced_scandoubler(forced_scandoubler),
	.video_rotated(video_rotated),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_index(ioctl_index),
	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	
	.sdram_sz(sdram_sz),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1)
);

reg [7:0] sw[8];
always @(posedge clk_sys) if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;


wire m_left     =  joy[1];
wire m_right    =  joy[0];
wire m_fireA    =  joy[4];
wire m_start1   =  joy[5];
wire m_coin     =  joy[6];



/*
-- Configuration DIP switches, these can be brought out to external switches if desired

// See Subs manual for complete information. Active low (0 = On, 1 = Off)  * indicates Default
//    1 								Ping in attract mode [*(0-On) (1-Off)]
//	      2							Time/Cred				[*(0-Each coin buys time) (1-1 Coin/Player fixed)]
//   			3	4					Language					[*(00-English) (10-French) (01-Spanish) (11-German)]
//						5				Free play				[*(0-Coin per play) (1-Free Play)]
//							6	7	8	Time						[(000-0:30) (100-1:00) *(010-1:30) (110-2:00) (001-2:30) (101-3:00) (011-3:30) (111-4:00)]
--SW1 <= "01000101"; -- Config dip switches

Game Time:
0 0 - 150 seconds
0 1 - 120 seconds
1 0 -  90 seconds
1 1 - 60 seconds

*/





wire Steer_1A, Steer_1B;

wire  [7:0] DIP_Sw = 8'b10000000;		

wire	 		Display_1, Display_2;
wire vid = status[2] ? Display_2 : Display_1;
wire m_tilt=0;

subs_core subs_core(		
	.clk_12(clk_12),
	.Clk_50_I(),
	.Reset_I(~(status[0] | buttons[1])),
	.dn_addr(ioctl_addr[16:0]),
	.dn_dout(ioctl_dout),
	.dn_wr(ioctl_wr && ioctl_index==0),

	.Vid1_O(Display_1),
	.Vid2_O(Display_2),
	.CompSync_O(),
	.CompBlank_O(),
	.HBlank(hblank),
	.VBlank(vblank),
	.HSync(hs),
	.VSync(vs),
	.Coin1_I(~m_coin),
	.Coin2_I(1'b1),//On player only, we have only one Video Output
	.Start1_I(~m_start1),
	.Start2_I(1'b1),//On player only, we have only one Video Output
	.Fire1_I(~m_fireA),
	.Fire2_I(1'b1),//On player only, we have only one Video Output
	.Steer_1A_I(Steer_1A),
	.Steer_1B_I(Steer_1B),
	.Steer_2A_I(),//On player only, we have only one Video Output
	.Steer_2B_I(),//On player only, we have only one Video Output
	.Test_I(~status[1]),
	.DiagStep_I(1'b1),
	.DiagHold_I(1'b1),
	.Slam_I(~m_tilt),
	.DIP_Sw(sw[0]),
	.P1_audio(audio_l),
	.P2_audio(audio_r),
	.LED1_O(),
	.LED2_O(),
	.CCounter_O()
	);
	
joy2quad joy2quad(
	.CLK(clk_12),
	.clkdiv(45000),	
	.c_right(m_right),
	.c_left(m_left),
	.steerA(Steer_1A),
	.steerB(Steer_1B)
);	


			
wire [6:0] audio;
wire [1:0] video;

///////////////////////////////////////////////////
wire clk_48,clk_12,CLK_VIDEO_2;
wire clk_sys,locked;




assign r={8{vid}};
assign g={8{vid}};
assign b={8{vid}};
wire  [7:0]	audio_l, audio_r;

assign AUDIO_L= { 2'b0,audio_l,6'b0};
assign AUDIO_R= { 2'b0,audio_r,6'b0};
assign AUDIO_S = 0;

wire hblank, vblank;
wire hs, vs;


reg ce_pix;
always @(posedge clk_48) begin
        reg [2:0] div;

        div <= div + 1'd1;
        ce_pix <= !div;
end

arcade_video #(320,24) arcade_video
(
        .*,

        .clk_video(clk_48),

        .RGB_in(~status[6] ? {new_r,new_g,new_b} : {r,g,b }),
        .HBlank(hblank),
        .VBlank(vblank),
        .HSync(hs),
        .VSync(vs),

        .fx(status[5:3])
);


pll pll (
	.refclk ( CLK_50M   ),
	.rst(0),
	.locked 		( locked    ),        // PLL is running stable
	.outclk_0	( clk_48),        // 24 MHz
	.outclk_1	( clk_12	)        // 12 MHz
	 );

assign clk_sys=clk_12;
wire clk_mem=clk_48;


//
// Load 16bit color data from the ioctl as a file load
//
// the format is RBGA with each channel taking 4 bits
//
wire bg_download  = ioctl_download && ((ioctl_index[4:0] == 2) || (ioctl_index[9:8] == 1));

reg [7:0] ioctl_dout_r;
always @(posedge clk_sys) if(ioctl_wr & ~ioctl_addr[0]) ioctl_dout_r <= ioctl_dout;

wire [31:0] sd_data;
wire ram_ready;
sdram sdram
(
	.*,
	
	.init(~locked),
	.clk(clk_mem),
	.ch1_addr(bg_download ? ioctl_addr[24:1] : {pic_addr[24:2],1'b0}),
	.ch1_dout(sd_data),
	.ch1_din({ioctl_dout, ioctl_dout_r}),
	.ch1_req(bg_download ? (ioctl_wr & ioctl_addr[0]) : pic_req),
	.ch1_rnw(~bg_download)
);

//
// Alpha Blend is a table lookup to mix the color with black
//
// we can't hardcode it, because when the light comes through
// the overlay we need the original color
//


//assign VGA_R = bg_r;
wire [7:0] r,g,b;
wire fg = vid;
wire bg = |{bg_r,bg_g,bg_b};
//
// if fg is non zero, then the beam is at this pixel
//    make the color either:
//       -- the background color (no alpha) if pixel is dark
//       -- the background color tinted towards white if the beam is bright
// if fg is zero, we use the background after an alpha * black has been applied

wire [7:0] new_r = fg  ? a_bbrw : ~status[16] ? bga_r : {bg_r,bg_r};
wire [7:0] new_g = fg  ? a_bbgw : ~status[16] ? bga_g : {bg_g,bg_g};
wire [7:0] new_b = fg  ? a_bbbw : ~status[16] ? bga_b : {bg_b,bg_b};


wire [7:0] a_bbrw = (bg_a=='hF) ? {bg_r,bg_r} : bbrw;
wire [7:0] a_bbgw = (bg_a=='hF) ? {bg_g,bg_g} : bbgw;
wire [7:0] a_bbbw = (bg_a=='hF) ? {bg_b,bg_b} : bbbw;


wire [7:0] bbrw = ~status[18] ? blend_r_w : blend_r;
wire [7:0] bbgw = ~status[18] ? blend_g_w : blend_g;
wire [7:0] bbbw = ~status[18] ? blend_b_w : blend_b;

// tint it towards white when it is brighter, otherwise use the background
// color (no alpha)
// r + (255-r)*tint
// to simplify we want tint ~ 3/4 =  ( 1/4 + 1/2 )
wire [7:0] blend_r_w = r > 108 ? (blend_r + ((8'd255-blend_r)>>1) + ((8'd255-blend_r)>>2) ) : blend_r;
wire [7:0] blend_g_w = g > 108 ? (blend_g + ((8'd255-blend_g)>>1) + ((8'd255-blend_g)>>2) ) : blend_g;
wire [7:0] blend_b_w = b > 108 ? (blend_b + ((8'd255-blend_b)>>1) + ((8'd255-blend_b)>>2) ) : blend_b;


wire [7:0] blend_r = ~status[17] ? bg ? { bg_r << 2 | bg_r[0] , bg_r << 2 | bg_r[0]} : r : r;
wire [7:0] blend_g = ~status[17] ? bg ? { bg_g << 2 | bg_g[0] , bg_g << 2 | bg_g[0]} : g : g;
wire [7:0] blend_b = ~status[17] ? bg ? { bg_b << 2 | bg_b[0] , bg_b << 2 | bg_b[0]} : b : b;

wire [7:0] bga_r,bga_g,bga_b;
alphablend alphablend(
	.clk(clk_48),
	.bg_a(bg_a),
	.bg_r(bg_r),
	.bg_g(bg_g),
	.bg_b(bg_b),
	.bga_r(bga_r),
	.bga_g(bga_g),
	.bga_b(bga_b)
);

wire VSync = VGA_VS;
reg [15:0] pic_data[2];
reg        pic_req;
reg [24:1] pic_addr;
reg  [3:0] bg_r,bg_g,bg_b,bg_a;
always @(posedge clk_48) begin
	reg old_vs;
	reg use_bg = 0;
	reg [1:0] cnt;
	
	if(bg_download && sdram_sz[2:0]) use_bg <= 1;

	pic_req <= 0;

	if(use_bg & ~bg_download) begin
		if(ce_pix) begin
			
			cnt <= cnt >> 1;
			if(cnt[0]) {pic_data[1],pic_data[0]} <= sd_data;
			
			old_vs <= VSync;
			if(~(hblank|vblank)) begin
				{bg_a,bg_b,bg_g,bg_r} <= pic_data[~pic_addr[1]];
				pic_addr <= pic_addr + 2'd1;
				if(pic_addr[1]) begin
					pic_req <= 1;
					cnt <= 2;
				end
			end
			
			if(~old_vs & VSync) begin
				pic_addr <= 0;
				pic_req <= 1;
				cnt <= 2;
			end
		end
	end
	else begin
		{bg_a,bg_b,bg_g,bg_r} <= 0;
	end
end



endmodule
