`timescale 1ns / 1ps
//==============================================================================
// AES Shared Forward / Inverse S-box Module (512-Byte Distributed ROM)
// PS06 AES-128 AXI-MM Hardware Accelerator — VELTRAXX '26
//==============================================================================
// Unified 512-byte distributed ROM: address[8:0] = {is_inv, byte_in}.
// Fast MuxF7/F8 cascade path, critical path ~1.2 ns.
//==============================================================================

module aes_sbox_shared (
    input  wire       is_inv,
    input  wire [7:0] byte_in,
    output wire [7:0] byte_out
);

    (* rom_style = "distributed" *)
    reg [7:0] rom [0:511];

    initial begin
        // 0..255: Forward S-box
        rom[9'h000]=8'h63; rom[9'h001]=8'h7c; rom[9'h002]=8'h77; rom[9'h003]=8'h7b;
        rom[9'h004]=8'hf2; rom[9'h005]=8'h6b; rom[9'h006]=8'h6f; rom[9'h007]=8'hc5;
        rom[9'h008]=8'h30; rom[9'h009]=8'h01; rom[9'h00a]=8'h67; rom[9'h00b]=8'h2b;
        rom[9'h00c]=8'hfe; rom[9'h00d]=8'hd7; rom[9'h00e]=8'hab; rom[9'h00f]=8'h76;
        rom[9'h010]=8'hca; rom[9'h011]=8'h82; rom[9'h012]=8'hc9; rom[9'h013]=8'h7d;
        rom[9'h014]=8'hfa; rom[9'h015]=8'h59; rom[9'h016]=8'h47; rom[9'h017]=8'hf0;
        rom[9'h018]=8'had; rom[9'h019]=8'hd4; rom[9'h01a]=8'ha2; rom[9'h01b]=8'haf;
        rom[9'h01c]=8'h9c; rom[9'h01d]=8'ha4; rom[9'h01e]=8'h72; rom[9'h01f]=8'hc0;
        rom[9'h020]=8'hb7; rom[9'h021]=8'hfd; rom[9'h022]=8'h93; rom[9'h023]=8'h26;
        rom[9'h024]=8'h36; rom[9'h025]=8'h3f; rom[9'h026]=8'hf7; rom[9'h027]=8'hcc;
        rom[9'h028]=8'h34; rom[9'h029]=8'ha5; rom[9'h02a]=8'he5; rom[9'h02b]=8'hf1;
        rom[9'h02c]=8'h71; rom[9'h02d]=8'hd8; rom[9'h02e]=8'h31; rom[9'h02f]=8'h15;
        rom[9'h030]=8'h04; rom[9'h031]=8'hc7; rom[9'h032]=8'h23; rom[9'h033]=8'hc3;
        rom[9'h034]=8'h18; rom[9'h035]=8'h96; rom[9'h036]=8'h05; rom[9'h037]=8'h9a;
        rom[9'h038]=8'h07; rom[9'h039]=8'h12; rom[9'h03a]=8'h80; rom[9'h03b]=8'he2;
        rom[9'h03c]=8'heb; rom[9'h03d]=8'h27; rom[9'h03e]=8'hb2; rom[9'h03f]=8'h75;
        rom[9'h040]=8'h09; rom[9'h041]=8'h83; rom[9'h042]=8'h2c; rom[9'h043]=8'h1a;
        rom[9'h044]=8'h1b; rom[9'h045]=8'h6e; rom[9'h046]=8'h5a; rom[9'h047]=8'ha0;
        rom[9'h048]=8'h52; rom[9'h049]=8'h3b; rom[9'h04a]=8'hd6; rom[9'h04b]=8'hb3;
        rom[9'h04c]=8'h29; rom[9'h04d]=8'he3; rom[9'h04e]=8'h2f; rom[9'h04f]=8'h84;
        rom[9'h050]=8'h53; rom[9'h051]=8'hd1; rom[9'h052]=8'h00; rom[9'h053]=8'hed;
        rom[9'h054]=8'h20; rom[9'h055]=8'hfc; rom[9'h056]=8'hb1; rom[9'h057]=8'h5b;
        rom[9'h058]=8'h6a; rom[9'h059]=8'hcb; rom[9'h05a]=8'hbe; rom[9'h05b]=8'h39;
        rom[9'h05c]=8'h4a; rom[9'h05d]=8'h4c; rom[9'h05e]=8'h58; rom[9'h05f]=8'hcf;
        rom[9'h060]=8'hd0; rom[9'h061]=8'hef; rom[9'h062]=8'haa; rom[9'h063]=8'hfb;
        rom[9'h064]=8'h43; rom[9'h065]=8'h4d; rom[9'h066]=8'h33; rom[9'h067]=8'h85;
        rom[9'h068]=8'h45; rom[9'h069]=8'hf9; rom[9'h06a]=8'h02; rom[9'h06b]=8'h7f;
        rom[9'h06c]=8'h50; rom[9'h06d]=8'h3c; rom[9'h06e]=8'h9f; rom[9'h06f]=8'ha8;
        rom[9'h070]=8'h51; rom[9'h071]=8'ha3; rom[9'h072]=8'h40; rom[9'h073]=8'h8f;
        rom[9'h074]=8'h92; rom[9'h075]=8'h9d; rom[9'h076]=8'h38; rom[9'h077]=8'hf5;
        rom[9'h078]=8'hbc; rom[9'h079]=8'hb6; rom[9'h07a]=8'hda; rom[9'h07b]=8'h21;
        rom[9'h07c]=8'h10; rom[9'h07d]=8'hff; rom[9'h07e]=8'hf3; rom[9'h07f]=8'hd2;
        rom[9'h080]=8'hcd; rom[9'h081]=8'h0c; rom[9'h082]=8'h13; rom[9'h083]=8'hec;
        rom[9'h084]=8'h5f; rom[9'h085]=8'h97; rom[9'h086]=8'h44; rom[9'h087]=8'h17;
        rom[9'h088]=8'hc4; rom[9'h089]=8'ha7; rom[9'h08a]=8'h7e; rom[9'h08b]=8'h3d;
        rom[9'h08c]=8'h64; rom[9'h08d]=8'h5d; rom[9'h08e]=8'h19; rom[9'h08f]=8'h73;
        rom[9'h090]=8'h60; rom[9'h091]=8'h81; rom[9'h092]=8'h4f; rom[9'h093]=8'hdc;
        rom[9'h094]=8'h22; rom[9'h095]=8'h2a; rom[9'h096]=8'h90; rom[9'h097]=8'h88;
        rom[9'h098]=8'h46; rom[9'h099]=8'hee; rom[9'h09a]=8'hb8; rom[9'h09b]=8'h14;
        rom[9'h09c]=8'hde; rom[9'h09d]=8'h5e; rom[9'h09e]=8'h0b; rom[9'h09f]=8'hdb;
        rom[9'h0a0]=8'he0; rom[9'h0a1]=8'h32; rom[9'h0a2]=8'h3a; rom[9'h0a3]=8'h0a;
        rom[9'h0a4]=8'h49; rom[9'h0a5]=8'h06; rom[9'h0a6]=8'h24; rom[9'h0a7]=8'h5c;
        rom[9'h0a8]=8'hc2; rom[9'h0a9]=8'hd3; rom[9'h0aa]=8'hac; rom[9'h0ab]=8'h62;
        rom[9'h0ac]=8'h91; rom[9'h0ad]=8'h95; rom[9'h0ae]=8'he4; rom[9'h0af]=8'h79;
        rom[9'h0b0]=8'he7; rom[9'h0b1]=8'hc8; rom[9'h0b2]=8'h37; rom[9'h0b3]=8'h6d;
        rom[9'h0b4]=8'h8d; rom[9'h0b5]=8'hd5; rom[9'h0b6]=8'h4e; rom[9'h0b7]=8'ha9;
        rom[9'h0b8]=8'h6c; rom[9'h0b9]=8'h56; rom[9'h0ba]=8'hf4; rom[9'h0bb]=8'hea;
        rom[9'h0bc]=8'h65; rom[9'h0bd]=8'h7a; rom[9'h0be]=8'hae; rom[9'h0bf]=8'h08;
        rom[9'h0c0]=8'hba; rom[9'h0c1]=8'h78; rom[9'h0c2]=8'h25; rom[9'h0c3]=8'h2e;
        rom[9'h0c4]=8'h1c; rom[9'h0c5]=8'ha6; rom[9'h0c6]=8'hb4; rom[9'h0c7]=8'hc6;
        rom[9'h0c8]=8'he8; rom[9'h0c9]=8'hdd; rom[9'h0ca]=8'h74; rom[9'h0cb]=8'h1f;
        rom[9'h0cc]=8'h4b; rom[9'h0cd]=8'hbd; rom[9'h0ce]=8'h8b; rom[9'h0cf]=8'h8a;
        rom[9'h0d0]=8'h70; rom[9'h0d1]=8'h3e; rom[9'h0d2]=8'hb5; rom[9'h0d3]=8'h66;
        rom[9'h0d4]=8'h48; rom[9'h0d5]=8'h03; rom[9'h0d6]=8'hf6; rom[9'h0d7]=8'h0e;
        rom[9'h0d8]=8'h61; rom[9'h0d9]=8'h35; rom[9'h0da]=8'h57; rom[9'h0db]=8'hb9;
        rom[9'h0dc]=8'h86; rom[9'h0dd]=8'hc1; rom[9'h0de]=8'h1d; rom[9'h0df]=8'h9e;
        rom[9'h0e0]=8'he1; rom[9'h0e1]=8'hf8; rom[9'h0e2]=8'h98; rom[9'h0e3]=8'h11;
        rom[9'h0e4]=8'h69; rom[9'h0e5]=8'hd9; rom[9'h0e6]=8'h8e; rom[9'h0e7]=8'h94;
        rom[9'h0e8]=8'h9b; rom[9'h0e9]=8'h1e; rom[9'h0ea]=8'h87; rom[9'h0eb]=8'he9;
        rom[9'h0ec]=8'hce; rom[9'h0ed]=8'h55; rom[9'h0ee]=8'h28; rom[9'h0ef]=8'hdf;
        rom[9'h0f0]=8'h8c; rom[9'h0f1]=8'ha1; rom[9'h0f2]=8'h89; rom[9'h0f3]=8'h0d;
        rom[9'h0f4]=8'hbf; rom[9'h0f5]=8'he6; rom[9'h0f6]=8'h42; rom[9'h0f7]=8'h68;
        rom[9'h0f8]=8'h41; rom[9'h0f9]=8'h99; rom[9'h0fa]=8'h2d; rom[9'h0fb]=8'h0f;
        rom[9'h0fc]=8'hb0; rom[9'h0fd]=8'h54; rom[9'h0fe]=8'hbb; rom[9'h0ff]=8'h16;

        // 256..511: Inverse S-box
        rom[9'h100]=8'h52; rom[9'h101]=8'h09; rom[9'h102]=8'h6a; rom[9'h103]=8'hd5;
        rom[9'h104]=8'h30; rom[9'h105]=8'h36; rom[9'h106]=8'ha5; rom[9'h107]=8'h38;
        rom[9'h108]=8'hbf; rom[9'h109]=8'h40; rom[9'h10a]=8'ha3; rom[9'h10b]=8'h9e;
        rom[9'h10c]=8'h81; rom[9'h10d]=8'hf3; rom[9'h10e]=8'hd7; rom[9'h10f]=8'hfb;
        rom[9'h110]=8'h7c; rom[9'h111]=8'he3; rom[9'h112]=8'h39; rom[9'h113]=8'h82;
        rom[9'h114]=8'h9b; rom[9'h115]=8'h2f; rom[9'h116]=8'hff; rom[9'h117]=8'h87;
        rom[9'h118]=8'h34; rom[9'h119]=8'h8e; rom[9'h11a]=8'h43; rom[9'h11b]=8'h44;
        rom[9'h11c]=8'hc4; rom[9'h11d]=8'hde; rom[9'h11e]=8'he9; rom[9'h11f]=8'hcb;
        rom[9'h120]=8'h54; rom[9'h121]=8'h7b; rom[9'h122]=8'h94; rom[9'h123]=8'h32;
        rom[9'h124]=8'ha6; rom[9'h125]=8'hc2; rom[9'h126]=8'h23; rom[9'h127]=8'h3d;
        rom[9'h128]=8'hee; rom[9'h129]=8'h4c; rom[9'h12a]=8'h95; rom[9'h12b]=8'h0b;
        rom[9'h12c]=8'h42; rom[9'h12d]=8'hfa; rom[9'h12e]=8'hc3; rom[9'h12f]=8'h4e;
        rom[9'h130]=8'h08; rom[9'h131]=8'h2e; rom[9'h132]=8'ha1; rom[9'h133]=8'h66;
        rom[9'h134]=8'h28; rom[9'h135]=8'hd9; rom[9'h136]=8'h24; rom[9'h137]=8'hb2;
        rom[9'h138]=8'h76; rom[9'h139]=8'h5b; rom[9'h13a]=8'ha2; rom[9'h13b]=8'h49;
        rom[9'h13c]=8'h6d; rom[9'h13d]=8'h8b; rom[9'h13e]=8'hd1; rom[9'h13f]=8'h25;
        rom[9'h140]=8'h72; rom[9'h141]=8'hf8; rom[9'h142]=8'hf6; rom[9'h143]=8'h64;
        rom[9'h144]=8'h86; rom[9'h145]=8'h68; rom[9'h146]=8'h98; rom[9'h147]=8'h16;
        rom[9'h148]=8'hd4; rom[9'h149]=8'ha4; rom[9'h14a]=8'h5c; rom[9'h14b]=8'hcc;
        rom[9'h14c]=8'h5d; rom[9'h14d]=8'h65; rom[9'h14e]=8'hb6; rom[9'h14f]=8'h92;
        rom[9'h150]=8'h6c; rom[9'h151]=8'h70; rom[9'h152]=8'h48; rom[9'h153]=8'h50;
        rom[9'h154]=8'hfd; rom[9'h155]=8'hed; rom[9'h156]=8'hb9; rom[9'h157]=8'hda;
        rom[9'h158]=8'h5e; rom[9'h159]=8'h15; rom[9'h15a]=8'h46; rom[9'h15b]=8'h57;
        rom[9'h15c]=8'ha7; rom[9'h15d]=8'h8d; rom[9'h15e]=8'h9d; rom[9'h15f]=8'h84;
        rom[9'h160]=8'h90; rom[9'h161]=8'hd8; rom[9'h162]=8'hab; rom[9'h163]=8'h00;
        rom[9'h164]=8'h8c; rom[9'h165]=8'hbc; rom[9'h166]=8'hd3; rom[9'h167]=8'h0a;
        rom[9'h168]=8'hf7; rom[9'h169]=8'he4; rom[9'h16a]=8'h58; rom[9'h16b]=8'h05;
        rom[9'h16c]=8'hb8; rom[9'h16d]=8'hb3; rom[9'h16e]=8'h45; rom[9'h16f]=8'h06;
        rom[9'h170]=8'hd0; rom[9'h171]=8'h2c; rom[9'h172]=8'h1e; rom[9'h173]=8'h8f;
        rom[9'h174]=8'hca; rom[9'h175]=8'h3f; rom[9'h176]=8'h0f; rom[9'h177]=8'h02;
        rom[9'h178]=8'hc1; rom[9'h179]=8'haf; rom[9'h17a]=8'hbd; rom[9'h17b]=8'h03;
        rom[9'h17c]=8'h01; rom[9'h17d]=8'h13; rom[9'h17e]=8'h8a; rom[9'h17f]=8'h6b;
        rom[9'h180]=8'h3a; rom[9'h181]=8'h91; rom[9'h182]=8'h11; rom[9'h183]=8'h41;
        rom[9'h184]=8'h4f; rom[9'h185]=8'h67; rom[9'h186]=8'hdc; rom[9'h187]=8'hea;
        rom[9'h188]=8'h97; rom[9'h189]=8'hf2; rom[9'h18a]=8'hcf; rom[9'h18b]=8'hce;
        rom[9'h18c]=8'hf0; rom[9'h18d]=8'hb4; rom[9'h18e]=8'he6; rom[9'h18f]=8'h73;
        rom[9'h190]=8'h96; rom[9'h191]=8'hac; rom[9'h192]=8'h74; rom[9'h193]=8'h22;
        rom[9'h194]=8'he7; rom[9'h195]=8'had; rom[9'h196]=8'h35; rom[9'h197]=8'h85;
        rom[9'h198]=8'he2; rom[9'h199]=8'hf9; rom[9'h19a]=8'h37; rom[9'h19b]=8'he8;
        rom[9'h19c]=8'h1c; rom[9'h19d]=8'h75; rom[9'h19e]=8'hdf; rom[9'h19f]=8'h6e;
        rom[9'h1a0]=8'h47; rom[9'h1a1]=8'hf1; rom[9'h1a2]=8'h1a; rom[9'h1a3]=8'h71;
        rom[9'h1a4]=8'h1d; rom[9'h1a5]=8'h29; rom[9'h1a6]=8'hc5; rom[9'h1a7]=8'h89;
        rom[9'h1a8]=8'h6f; rom[9'h1a9]=8'hb7; rom[9'h1aa]=8'h62; rom[9'h1ab]=8'h0e;
        rom[9'h1ac]=8'haa; rom[9'h1ad]=8'h18; rom[9'h1ae]=8'hbe; rom[9'h1af]=8'h1b;
        rom[9'h1b0]=8'hfc; rom[9'h1b1]=8'h56; rom[9'h1b2]=8'h3e; rom[9'h1b3]=8'h4b;
        rom[9'h1b4]=8'hc6; rom[9'h1b5]=8'hd2; rom[9'h1b6]=8'h79; rom[9'h1b7]=8'h20;
        rom[9'h1b8]=8'h9a; rom[9'h1b9]=8'hdb; rom[9'h1ba]=8'hc0; rom[9'h1bb]=8'hfe;
        rom[9'h1bc]=8'h78; rom[9'h1bd]=8'hcd; rom[9'h1be]=8'h5a; rom[9'h1bf]=8'hf4;
        rom[9'h1c0]=8'h1f; rom[9'h1c1]=8'hdd; rom[9'h1c2]=8'ha8; rom[9'h1c3]=8'h33;
        rom[9'h1c4]=8'h88; rom[9'h1c5]=8'h07; rom[9'h1c6]=8'hc7; rom[9'h1c7]=8'h31;
        rom[9'h1c8]=8'hb1; rom[9'h1c9]=8'h12; rom[9'h1ca]=8'h10; rom[9'h1cb]=8'h59;
        rom[9'h1cc]=8'h27; rom[9'h1cd]=8'h80; rom[9'h1ce]=8'hec; rom[9'h1cf]=8'h5f;
        rom[9'h1d0]=8'h60; rom[9'h1d1]=8'h51; rom[9'h1d2]=8'h7f; rom[9'h1d3]=8'ha9;
        rom[9'h1d4]=8'h19; rom[9'h1d5]=8'hb5; rom[9'h1d6]=8'h4a; rom[9'h1d7]=8'h0d;
        rom[9'h1d8]=8'h2d; rom[9'h1d9]=8'he5; rom[9'h1da]=8'h7a; rom[9'h1db]=8'h9f;
        rom[9'h1dc]=8'h93; rom[9'h1dd]=8'hc9; rom[9'h1de]=8'h9c; rom[9'h1df]=8'hef;
        rom[9'h1e0]=8'ha0; rom[9'h1e1]=8'he0; rom[9'h1e2]=8'h3b; rom[9'h1e3]=8'h4d;
        rom[9'h1e4]=8'hae; rom[9'h1e5]=8'h2a; rom[9'h1e6]=8'hf5; rom[9'h1e7]=8'hb0;
        rom[9'h1e8]=8'hc8; rom[9'h1e9]=8'heb; rom[9'h1ea]=8'hbb; rom[9'h1eb]=8'h3c;
        rom[9'h1ec]=8'h83; rom[9'h1ed]=8'h53; rom[9'h1ee]=8'h99; rom[9'h1ef]=8'h61;
        rom[9'h1f0]=8'h17; rom[9'h1f1]=8'h2b; rom[9'h1f2]=8'h04; rom[9'h1f3]=8'h7e;
        rom[9'h1f4]=8'hba; rom[9'h1f5]=8'h77; rom[9'h1f6]=8'hd6; rom[9'h1f7]=8'h26;
        rom[9'h1f8]=8'he1; rom[9'h1f9]=8'h69; rom[9'h1fa]=8'h14; rom[9'h1fb]=8'h63;
        rom[9'h1fc]=8'h55; rom[9'h1fd]=8'h21; rom[9'h1fe]=8'h0c; rom[9'h1ff]=8'h7d;
    end

    assign byte_out = rom[{is_inv, byte_in}];

endmodule
