`timescale 1ns / 1ps
module test_sbox_dual_direct (
    input  wire       is_inv,
    input  wire [7:0] byte_in,
    output wire [7:0] byte_out
);

    (* rom_style = "distributed" *)
    reg [7:0] fwd_rom [0:255];
    (* rom_style = "distributed" *)
    reg [7:0] inv_rom [0:255];

    initial begin
        fwd_rom[8'h00]=8'h63; fwd_rom[8'h01]=8'h7c; fwd_rom[8'h02]=8'h77; fwd_rom[8'h03]=8'h7b;
        fwd_rom[8'h04]=8'hf2; fwd_rom[8'h05]=8'h6b; fwd_rom[8'h06]=8'h6f; fwd_rom[8'h07]=8'hc5;
        fwd_rom[8'h08]=8'h30; fwd_rom[8'h09]=8'h01; fwd_rom[8'h0a]=8'h67; fwd_rom[8'h0b]=8'h2b;
        fwd_rom[8'h0c]=8'hfe; fwd_rom[8'h0d]=8'hd7; fwd_rom[8'h0e]=8'hab; fwd_rom[8'h0f]=8'h76;
        fwd_rom[8'h10]=8'hca; fwd_rom[8'h11]=8'h82; fwd_rom[8'h12]=8'hc9; fwd_rom[8'h13]=8'h7d;
        fwd_rom[8'h14]=8'hfa; fwd_rom[8'h15]=8'h59; fwd_rom[8'h16]=8'h47; fwd_rom[8'h17]=8'hf0;
        fwd_rom[8'h18]=8'had; fwd_rom[8'h19]=8'hd4; fwd_rom[8'h1a]=8'ha2; fwd_rom[8'h1b]=8'haf;
        fwd_rom[8'h1c]=8'h9c; fwd_rom[8'h1d]=8'ha4; fwd_rom[8'h1e]=8'h72; fwd_rom[8'h1f]=8'hc0;
        fwd_rom[8'h20]=8'hb7; fwd_rom[8'h21]=8'hfd; fwd_rom[8'h22]=8'h93; fwd_rom[8'h23]=8'h26;
        fwd_rom[8'h24]=8'h36; fwd_rom[8'h25]=8'h3f; fwd_rom[8'h26]=8'hf7; fwd_rom[8'h27]=8'hcc;
        fwd_rom[8'h28]=8'h34; fwd_rom[8'h29]=8'ha5; fwd_rom[8'h2a]=8'he5; fwd_rom[8'h2b]=8'hf1;
        fwd_rom[8'h2c]=8'h71; fwd_rom[8'h2d]=8'hd8; fwd_rom[8'h2e]=8'h31; fwd_rom[8'h2f]=8'h15;
        fwd_rom[8'h30]=8'h04; fwd_rom[8'h31]=8'hc7; fwd_rom[8'h32]=8'h23; fwd_rom[8'h33]=8'hc3;
        fwd_rom[8'h34]=8'h18; fwd_rom[8'h35]=8'h96; fwd_rom[8'h36]=8'h05; fwd_rom[8'h37]=8'h9a;
        fwd_rom[8'h38]=8'h07; fwd_rom[8'h39]=8'h12; fwd_rom[8'h3a]=8'h80; fwd_rom[8'h3b]=8'he2;
        fwd_rom[8'h3c]=8'heb; fwd_rom[8'h3d]=8'h27; fwd_rom[8'h3e]=8'hb2; fwd_rom[8'h3f]=8'h75;
        fwd_rom[8'h40]=8'h09; fwd_rom[8'h41]=8'h83; fwd_rom[8'h42]=8'h2c; fwd_rom[8'h43]=8'h1a;
        fwd_rom[8'h44]=8'h1b; fwd_rom[8'h45]=8'h6e; fwd_rom[8'h46]=8'h5a; fwd_rom[8'h47]=8'ha0;
        fwd_rom[8'h48]=8'h52; fwd_rom[8'h49]=8'h3b; fwd_rom[8'h4a]=8'hd6; fwd_rom[8'h4b]=8'hb3;
        fwd_rom[8'h4c]=8'h29; fwd_rom[8'h4d]=8'he3; fwd_rom[8'h4e]=8'h2f; fwd_rom[8'h4f]=8'h84;
        fwd_rom[8'h50]=8'h53; fwd_rom[8'h51]=8'hd1; fwd_rom[8'h52]=8'h00; fwd_rom[8'h53]=8'hed;
        fwd_rom[8'h54]=8'h20; fwd_rom[8'h55]=8'hfc; fwd_rom[8'h56]=8'hb1; fwd_rom[8'h57]=8'h5b;
        fwd_rom[8'h58]=8'h6a; fwd_rom[8'h59]=8'hcb; fwd_rom[8'h5a]=8'hbe; fwd_rom[8'h5b]=8'h39;
        fwd_rom[8'h5c]=8'h4a; fwd_rom[8'h5d]=8'h4c; fwd_rom[8'h5e]=8'h58; fwd_rom[8'h5f]=8'hcf;
        fwd_rom[8'h60]=8'hd0; fwd_rom[8'h61]=8'hef; fwd_rom[8'h62]=8'haa; fwd_rom[8'h63]=8'hfb;
        fwd_rom[8'h64]=8'h43; fwd_rom[8'h65]=8'h4d; fwd_rom[8'h66]=8'h33; fwd_rom[8'h67]=8'h85;
        fwd_rom[8'h68]=8'h45; fwd_rom[8'h69]=8'hf9; fwd_rom[8'h6a]=8'h02; fwd_rom[8'h6b]=8'h7f;
        fwd_rom[8'h6c]=8'h50; fwd_rom[8'h6d]=8'h3c; fwd_rom[8'h6e]=8'h9f; fwd_rom[8'h6f]=8'ha8;
        fwd_rom[8'h70]=8'h51; fwd_rom[8'h71]=8'ha3; fwd_rom[8'h72]=8'h40; fwd_rom[8'h73]=8'h8f;
        fwd_rom[8'h74]=8'h92; fwd_rom[8'h75]=8'h9d; fwd_rom[8'h76]=8'h38; fwd_rom[8'h77]=8'hf5;
        fwd_rom[8'h78]=8'hbc; fwd_rom[8'h79]=8'hb6; fwd_rom[8'h7a]=8'hda; fwd_rom[8'h7b]=8'h21;
        fwd_rom[8'h7c]=8'h10; fwd_rom[8'h7d]=8'hff; fwd_rom[8'h7e]=8'hf3; fwd_rom[8'h7f]=8'hd2;
        fwd_rom[8'h80]=8'hcd; fwd_rom[8'h81]=8'h0c; fwd_rom[8'h82]=8'h13; fwd_rom[8'h83]=8'hec;
        fwd_rom[8'h84]=8'h5f; fwd_rom[8'h85]=8'h97; fwd_rom[8'h86]=8'h44; fwd_rom[8'h87]=8'h17;
        fwd_rom[8'h88]=8'hc4; fwd_rom[8'h89]=8'ha7; fwd_rom[8'h8a]=8'h7e; fwd_rom[8'h8b]=8'h3d;
        fwd_rom[8'h8c]=8'h64; fwd_rom[8'h8d]=8'h5d; fwd_rom[8'h8e]=8'h19; fwd_rom[8'h8f]=8'h73;
        fwd_rom[8'h90]=8'h60; fwd_rom[8'h91]=8'h81; fwd_rom[8'h92]=8'h4f; fwd_rom[8'h93]=8'hdc;
        fwd_rom[8'h94]=8'h22; fwd_rom[8'h95]=8'h2a; fwd_rom[8'h96]=8'h90; fwd_rom[8'h97]=8'h88;
        fwd_rom[8'h98]=8'h46; fwd_rom[8'h99]=8'hee; fwd_rom[8'h9a]=8'hb8; fwd_rom[8'h9b]=8'h14;
        fwd_rom[8'h9c]=8'hde; fwd_rom[8'h9d]=8'h5e; fwd_rom[8'h9e]=8'h0b; fwd_rom[8'h9f]=8'hdb;
        fwd_rom[8'ha0]=8'he0; fwd_rom[8'ha1]=8'h32; fwd_rom[8'ha2]=8'h3a; fwd_rom[8'ha3]=8'h0a;
        fwd_rom[8'ha4]=8'h49; fwd_rom[8'ha5]=8'h06; fwd_rom[8'ha6]=8'h24; fwd_rom[8'ha7]=8'h5c;
        fwd_rom[8'ha8]=8'hc2; fwd_rom[8'ha9]=8'hd3; fwd_rom[8'haa]=8'hac; fwd_rom[8'hab]=8'h62;
        fwd_rom[8'hac]=8'h91; fwd_rom[8'had]=8'h95; fwd_rom[8'hae]=8'he4; fwd_rom[8'haf]=8'h79;
        fwd_rom[8'hb0]=8'he7; fwd_rom[8'hb1]=8'hc8; fwd_rom[8'hb2]=8'h37; fwd_rom[8'hb3]=8'h6d;
        fwd_rom[8'hb4]=8'h8d; fwd_rom[8'hb5]=8'hd5; fwd_rom[8'hb6]=8'h4e; fwd_rom[8'hb7]=8'ha9;
        fwd_rom[8'hb8]=8'h6c; fwd_rom[8'hb9]=8'h56; fwd_rom[8'hba]=8'hf4; fwd_rom[8'hbb]=8'hea;
        fwd_rom[8'hbc]=8'h65; fwd_rom[8'hbd]=8'h7a; fwd_rom[8'hbe]=8'hae; fwd_rom[8'hbf]=8'h08;
        fwd_rom[8'hc0]=8'hba; fwd_rom[8'hc1]=8'h78; fwd_rom[8'hc2]=8'h25; fwd_rom[8'hc3]=8'h2e;
        fwd_rom[8'hc4]=8'h1c; fwd_rom[8'hc5]=8'ha6; fwd_rom[8'hc6]=8'hb4; fwd_rom[8'hc7]=8'hc6;
        fwd_rom[8'hc8]=8'he8; fwd_rom[8'hc9]=8'hdd; fwd_rom[8'hca]=8'h74; fwd_rom[8'hcb]=8'h1f;
        fwd_rom[8'hcc]=8'h4b; fwd_rom[8'hcd]=8'hbd; fwd_rom[8'hce]=8'h8b; fwd_rom[8'hcf]=8'h8a;
        fwd_rom[8'hd0]=8'h70; fwd_rom[8'hd1]=8'h3e; fwd_rom[8'hd2]=8'hb5; fwd_rom[8'hd3]=8'h66;
        fwd_rom[8'hd4]=8'h48; fwd_rom[8'hd5]=8'h03; fwd_rom[8'hd6]=8'hf6; fwd_rom[8'hd7]=8'h0e;
        fwd_rom[8'hd8]=8'h61; fwd_rom[8'hd9]=8'h35; fwd_rom[8'hda]=8'h57; fwd_rom[8'hdb]=8'hb9;
        fwd_rom[8'hdc]=8'h86; fwd_rom[8'hdd]=8'hc1; fwd_rom[8'hde]=8'h1d; fwd_rom[8'hdf]=8'h9e;
        fwd_rom[8'he0]=8'he1; fwd_rom[8'he1]=8'hf8; fwd_rom[8'he2]=8'h98; fwd_rom[8'he3]=8'h11;
        fwd_rom[8'he4]=8'h69; fwd_rom[8'he5]=8'hd9; fwd_rom[8'he6]=8'h8e; fwd_rom[8'he7]=8'h94;
        fwd_rom[8'he8]=8'h9b; fwd_rom[8'he9]=8'h1e; fwd_rom[8'hea]=8'h87; fwd_rom[8'heb]=8'he9;
        fwd_rom[8'hec]=8'hce; fwd_rom[8'hed]=8'h55; fwd_rom[8'hee]=8'h28; fwd_rom[8'hef]=8'hdf;
        fwd_rom[8'hf0]=8'h8c; fwd_rom[8'hf1]=8'ha1; fwd_rom[8'hf2]=8'h89; fwd_rom[8'hf3]=8'h0d;
        fwd_rom[8'hf4]=8'hbf; fwd_rom[8'hf5]=8'he6; fwd_rom[8'hf6]=8'h42; fwd_rom[8'hf7]=8'h68;
        fwd_rom[8'hf8]=8'h41; fwd_rom[8'hf9]=8'h99; fwd_rom[8'hfa]=8'h2d; fwd_rom[8'hfb]=8'h0f;
        fwd_rom[8'hfc]=8'hb0; fwd_rom[8'hfd]=8'h54; fwd_rom[8'hfe]=8'hbb; fwd_rom[8'hff]=8'h16;

        inv_rom[8'h00]=8'h52; inv_rom[8'h01]=8'h09; inv_rom[8'h02]=8'h6a; inv_rom[8'h03]=8'hd5;
        inv_rom[8'h04]=8'h30; inv_rom[8'h05]=8'h36; inv_rom[8'h06]=8'ha5; inv_rom[8'h07]=8'h38;
        inv_rom[8'h08]=8'hbf; inv_rom[8'h09]=8'h40; inv_rom[8'h0a]=8'ha3; inv_rom[8'h0b]=8'h9e;
        inv_rom[8'h0c]=8'h81; inv_rom[8'h0d]=8'hf3; inv_rom[8'h0e]=8'hd7; inv_rom[8'h0f]=8'hfb;
        inv_rom[8'h10]=8'h7c; inv_rom[8'h11]=8'he3; inv_rom[8'h12]=8'h39; inv_rom[8'h13]=8'h82;
        inv_rom[8'h14]=8'h9b; inv_rom[8'h15]=8'h2f; inv_rom[8'h16]=8'hff; inv_rom[8'h17]=8'h87;
        inv_rom[8'h18]=8'h34; inv_rom[8'h19]=8'h8e; inv_rom[8'h1a]=8'h43; inv_rom[8'h1b]=8'h44;
        inv_rom[8'h1c]=8'hc4; inv_rom[8'h1d]=8'hde; inv_rom[8'h1e]=8'he9; inv_rom[8'h1f]=8'hcb;
        inv_rom[8'h20]=8'h54; inv_rom[8'h21]=8'h7b; inv_rom[8'h22]=8'h94; inv_rom[8'h23]=8'h32;
        inv_rom[8'h24]=8'ha6; inv_rom[8'h25]=8'hc2; inv_rom[8'h26]=8'h23; inv_rom[8'h27]=8'h3d;
        inv_rom[8'h28]=8'hee; inv_rom[8'h29]=8'h4c; inv_rom[8'h2a]=8'h95; inv_rom[8'h2b]=8'h0b;
        inv_rom[8'h2c]=8'h42; inv_rom[8'h2d]=8'hfa; inv_rom[8'h2e]=8'hc3; inv_rom[8'h2f]=8'h4e;
        inv_rom[8'h30]=8'h08; inv_rom[8'h31]=8'h2e; inv_rom[8'h32]=8'ha1; inv_rom[8'h33]=8'h66;
        inv_rom[8'h34]=8'h28; inv_rom[8'h35]=8'hd9; inv_rom[8'h36]=8'h24; inv_rom[8'h37]=8'hb2;
        inv_rom[8'h38]=8'h76; inv_rom[8'h39]=8'h5b; inv_rom[8'h3a]=8'ha2; inv_rom[8'h3b]=8'h49;
        inv_rom[8'h3c]=8'h6d; inv_rom[8'h3d]=8'h8b; inv_rom[8'h3e]=8'hd1; inv_rom[8'h3f]=8'h25;
        inv_rom[8'h40]=8'h72; inv_rom[8'h41]=8'hf8; inv_rom[8'h42]=8'hf6; inv_rom[8'h43]=8'h64;
        inv_rom[8'h44]=8'h86; inv_rom[8'h45]=8'h68; inv_rom[8'h46]=8'h98; inv_rom[8'h47]=8'h16;
        inv_rom[8'h48]=8'hd4; inv_rom[8'h49]=8'ha4; inv_rom[8'h4a]=8'h5c; inv_rom[8'h4b]=8'hcc;
        inv_rom[8'h4c]=8'h5d; inv_rom[8'h4d]=8'h65; inv_rom[8'h4e]=8'hb6; inv_rom[8'h4f]=8'h92;
        inv_rom[8'h50]=8'h6c; inv_rom[8'h51]=8'h70; inv_rom[8'h52]=8'h48; inv_rom[8'h53]=8'h50;
        inv_rom[8'h54]=8'hfd; inv_rom[8'h55]=8'hed; inv_rom[8'h56]=8'hb9; inv_rom[8'h57]=8'hda;
        inv_rom[8'h58]=8'h5e; inv_rom[8'h59]=8'h15; inv_rom[8'h5a]=8'h46; inv_rom[8'h5b]=8'h57;
        inv_rom[8'h5c]=8'ha7; inv_rom[8'h5d]=8'h8d; inv_rom[8'h5e]=8'h9d; inv_rom[8'h5f]=8'h84;
        inv_rom[8'h60]=8'h90; inv_rom[8'h61]=8'hd8; inv_rom[8'h62]=8'hab; inv_rom[8'h63]=8'h00;
        inv_rom[8'h64]=8'h8c; inv_rom[8'h65]=8'hbc; inv_rom[8'h66]=8'hd3; inv_rom[8'h67]=8'h0a;
        inv_rom[8'h68]=8'hf7; inv_rom[8'h69]=8'he4; inv_rom[8'h6a]=8'h58; inv_rom[8'h6b]=8'h05;
        inv_rom[8'h6c]=8'hb8; inv_rom[8'h6d]=8'hb3; inv_rom[8'h6e]=8'h45; inv_rom[8'h6f]=8'h06;
        inv_rom[8'h70]=8'hd0; inv_rom[8'h71]=8'h2c; inv_rom[8'h72]=8'h1e; inv_rom[8'h73]=8'h8f;
        inv_rom[8'h74]=8'hca; inv_rom[8'h75]=8'h3f; inv_rom[8'h76]=8'h0f; inv_rom[8'h77]=8'h02;
        inv_rom[8'h78]=8'hc1; inv_rom[8'h79]=8'haf; inv_rom[8'h7a]=8'hbd; inv_rom[8'h7b]=8'h03;
        inv_rom[8'h7c]=8'h01; inv_rom[8'h7d]=8'h13; inv_rom[8'h7e]=8'h8a; inv_rom[8'h7f]=8'h6b;
        inv_rom[8'h80]=8'h3a; inv_rom[8'h81]=8'h91; inv_rom[8'h82]=8'h11; inv_rom[8'h83]=8'h41;
        inv_rom[8'h84]=8'h4f; inv_rom[8'h85]=8'h67; inv_rom[8'h86]=8'hdc; inv_rom[8'h87]=8'hea;
        inv_rom[8'h88]=8'h97; inv_rom[8'h89]=8'hf2; inv_rom[8'h8a]=8'hcf; inv_rom[8'h8b]=8'hce;
        inv_rom[8'h8c]=8'hf0; inv_rom[8'h8d]=8'hb4; inv_rom[8'h8e]=8'he6; inv_rom[8'h8f]=8'h73;
        inv_rom[8'h90]=8'h96; inv_rom[8'h91]=8'hac; inv_rom[8'h92]=8'h74; inv_rom[8'h93]=8'h22;
        inv_rom[8'h94]=8'he7; inv_rom[8'h95]=8'had; inv_rom[8'h96]=8'h35; inv_rom[8'h97]=8'h85;
        inv_rom[8'h98]=8'he2; inv_rom[8'h99]=8'hf9; inv_rom[8'h9a]=8'h37; inv_rom[8'h9b]=8'he8;
        inv_rom[8'h9c]=8'h1c; inv_rom[8'h9d]=8'h75; inv_rom[8'h9e]=8'hdf; inv_rom[8'h9f]=8'h6e;
        inv_rom[8'ha0]=8'h47; inv_rom[8'ha1]=8'hf1; inv_rom[8'ha2]=8'h1a; inv_rom[8'ha3]=8'h71;
        inv_rom[8'ha4]=8'h1d; inv_rom[8'ha5]=8'h29; inv_rom[8'ha6]=8'hc5; inv_rom[8'ha7]=8'h89;
        inv_rom[8'ha8]=8'h6f; inv_rom[8'ha9]=8'hb7; inv_rom[8'haa]=8'h62; inv_rom[8'hab]=8'h0e;
        inv_rom[8'hac]=8'haa; inv_rom[8'had]=8'h18; inv_rom[8'hae]=8'hbe; inv_rom[8'haf]=8'h1b;
        inv_rom[8'hb0]=8'hfc; inv_rom[8'hb1]=8'h56; inv_rom[8'hb2]=8'h3e; inv_rom[8'hb3]=8'h4b;
        inv_rom[8'hb4]=8'hc6; inv_rom[8'hb5]=8'hd2; inv_rom[8'hb6]=8'h79; inv_rom[8'hb7]=8'h20;
        inv_rom[8'hb8]=8'h9a; inv_rom[8'hb9]=8'hdb; inv_rom[8'hba]=8'hc0; inv_rom[8'hbb]=8'hfe;
        inv_rom[8'hbc]=8'h78; inv_rom[8'hbd]=8'hcd; inv_rom[8'hbe]=8'h5a; inv_rom[8'hbf]=8'hf4;
        inv_rom[8'hc0]=8'h1f; inv_rom[8'hc1]=8'hdd; inv_rom[8'hc2]=8'ha8; inv_rom[8'hc3]=8'h33;
        inv_rom[8'hc4]=8'h88; inv_rom[8'hc5]=8'h07; inv_rom[8'hc6]=8'hc7; inv_rom[8'hc7]=8'h31;
        inv_rom[8'hc8]=8'hb1; inv_rom[8'hc9]=8'h12; inv_rom[8'hca]=8'h10; inv_rom[8'hcb]=8'h59;
        inv_rom[8'hcc]=8'h27; inv_rom[8'hcd]=8'h80; inv_rom[8'hce]=8'hec; inv_rom[8'hcf]=8'h5f;
        inv_rom[8'hd0]=8'h60; inv_rom[8'hd1]=8'h51; inv_rom[8'hd2]=8'h7f; inv_rom[8'hd3]=8'ha9;
        inv_rom[8'hd4]=8'h19; inv_rom[8'hd5]=8'hb5; inv_rom[8'hd6]=8'h4a; inv_rom[8'hd7]=8'h0d;
        inv_rom[8'hd8]=8'h2d; inv_rom[8'hd9]=8'he5; inv_rom[8'hda]=8'h7a; inv_rom[8'hdb]=8'h9f;
        inv_rom[8'hdc]=8'h93; inv_rom[8'hdd]=8'hc9; inv_rom[8'hde]=8'h9c; inv_rom[8'hdf]=8'hef;
        inv_rom[8'he0]=8'ha0; inv_rom[8'he1]=8'he0; inv_rom[8'he2]=8'h3b; inv_rom[8'he3]=8'h4d;
        inv_rom[8'he4]=8'hae; inv_rom[8'he5]=8'h2a; inv_rom[8'he6]=8'hf5; inv_rom[8'he7]=8'hb0;
        inv_rom[8'he8]=8'hc8; inv_rom[8'he9]=8'heb; inv_rom[8'hea]=8'hbb; inv_rom[8'heb]=8'h3c;
        inv_rom[8'hec]=8'h83; inv_rom[8'hed]=8'h53; inv_rom[8'hee]=8'h99; inv_rom[8'hef]=8'h61;
        inv_rom[8'hf0]=8'h17; inv_rom[8'hf1]=8'h2b; inv_rom[8'hf2]=8'h04; inv_rom[8'hf3]=8'h7e;
        inv_rom[8'hf4]=8'hba; inv_rom[8'hf5]=8'h77; inv_rom[8'hf6]=8'hd6; inv_rom[8'hf7]=8'h26;
        inv_rom[8'hf8]=8'he1; inv_rom[8'hf9]=8'h69; inv_rom[8'hfa]=8'h14; inv_rom[8'hfb]=8'h63;
        inv_rom[8'hfc]=8'h55; inv_rom[8'hfd]=8'h21; inv_rom[8'hfe]=8'h0c; inv_rom[8'hff]=8'h7d;
    end

    assign byte_out = is_inv ? inv_rom[byte_in] : fwd_rom[byte_in];

endmodule
