module reg_sync_async #(parameter DATAWIDTH=18,RSTTYPE="SYNC") (input CLK,rst,en,input [DATAWIDTH-1:0]d,output reg[DATAWIDTH-1:0] Q);
generate
    if (RSTTYPE=="SYNC")begin
        always@(posedge CLK)begin
        if(rst)
        Q<=0;
        else if(en) begin
            Q<=d;
    end
    end
    end
    else if(RSTTYPE=="ASYNC")begin
    always@(posedge CLK or posedge rst )begin
        if(rst)
        Q<=0;
        else if(en) begin
            Q<=d;
        end
    end
    end
endgenerate
endmodule

module dsp48A1(A,B,C,D,CLK,CARRYIN,OPMODE,BCIN,RSTA,RSTB,RSTC,RSTD,RSTCARRYIN,RSTOPMODE,RSTM,CEA,
RSTP,CEB,CEM,CEP,CEC,CED,CECARRYIN,CEOPMODE,PCIN,BCOUT,PCOUT,P,M,CARRYOUT,CARRYOUTF);
parameter A0REG=0,A1REG=1,B0REG=0,B1REG=1;
parameter CREG=1,DREG=1,MREG=1,PREG=1,CARRYINREG=1,CARRYOUTREG=1,OPMODEREG=1;
parameter CARRYINSEL="OPMODE5",B_INPUT="DIRECT",RSTTYPE="SYNC";
input [17:0]A,B,D,BCIN;input [47:0]C;
input CARRYIN;
output  [35:0]M;output [47:0]P;output CARRYOUT,CARRYOUTF;         //data ports

input CLK,CEA,CEB,CED,CEM,CECARRYIN,CEC,CEOPMODE;input [7:0]OPMODE;
input RSTA,RSTB,RSTC,RSTCARRYIN,CEP,RSTD,RSTM,RSTOPMODE,RSTP;

output [47:0]PCOUT;output [17:0]BCOUT;input [48:0]PCIN;
wire [17:0]A_reg,B_reg,D_reg;
reg [17:0]A0_stage,B0_stage,D_stage,add_sub_out1,B_OP_STAGE;
wire [47:0]C_reg;wire [47:0]concat;reg [47:0]C_stage;
wire [17:0]A1_reg,B1_reg,B_SEL,A1_stage,B1_stage;
wire [35:0]mult_A_B,M_STAGE;
wire [35:0]mult_reg;
reg [47:0]x_out,z_out;
wire carry_stage,carry_sel;reg [47:0]post_add_sub;
wire carry_out_reg;
reg carry_out;
wire [7:0]op_reg;
wire [47:0]P_reg;
wire [47:0]M_STAGE_ext;

assign B_SEL=(B_INPUT=="DIRECT")?B:BCIN;

reg_sync_async A0_reg(.CLK(CLK),.rst(RSTA),.en(CEA),.d(A),.Q(A_reg));
reg_sync_async B0_reg(.CLK(CLK),.rst(RSTB),.en(CEB),.d(B_SEL),.Q(B_reg));
reg_sync_async #(.DATAWIDTH(48)) C0_reg(.CLK(CLK),.rst(RSTC),.en(CEC),.d(C),.Q(C_reg));
reg_sync_async D0_reg(.CLK(CLK),.rst(RSTD),.en(CED),.d(D),.Q(D_reg));
reg_sync_async #(.DATAWIDTH(8)) op_reg0(.CLK(CLK),.rst(RSTOPMODE),.en(CEOPMODE),.d(OPMODE),.Q(op_reg));
always@(*)begin
    A0_stage=(A0REG==0)?A:A_reg;
    B0_stage=(B0REG==0)?B_SEL:B_reg;
    C_stage=(CREG==0)?C:C_reg;
    D_stage=(DREG==0)?D:D_reg;
    case(op_reg[6])
    1'b0: add_sub_out1=D_stage+B0_stage;
    1'b1: add_sub_out1=D_stage-B0_stage;
    endcase
    case(op_reg[4])
    1'b0 :B_OP_STAGE =B0_stage;
    1'b1 :B_OP_STAGE =add_sub_out1;
endcase
end
reg_sync_async A1_rege(.CLK(CLK),.rst(RSTA),.en(CEA),.d(A0_stage),.Q(A1_reg));
reg_sync_async B1_rege(.CLK(CLK),.rst(RSTB),.en(CEB),.d(B_OP_STAGE),.Q(B1_reg));

assign A1_stage=(A1REG)?A1_reg:A0_stage;
assign B1_stage=(B1REG)?B1_reg:B0_stage;

assign BCOUT=B1_stage;
assign mult_A_B=A1_stage*B1_stage;

reg_sync_async #(.DATAWIDTH(36)) mult_rege(.CLK(CLK),.rst(RSTM),.en(CEM),.d(mult_A_B),.Q(mult_reg));
assign M_STAGE=(MREG)?mult_reg:mult_A_B;
assign M=M_STAGE;
assign M_STAGE_ext={12'b0, M_STAGE};

assign carry_sel=(CARRYINSEL=="OPMODE5")?op_reg[5]:(CARRYINSEL=="CARRYIN")?CARRYIN:0;
reg_sync_async #(.DATAWIDTH(1)) CYI(.CLK(CLK),.rst(RSTCARRYIN),.en(CECARRYIN),.d(carry_sel),.Q(carry_reg));
assign carry_stage =(CARRYINREG)?carry_reg:carry_sel;

assign concat={D[11:0],A[17:0],B[17:0]};

always@(*)begin
    case(op_reg[1:0])
    2'h0 : x_out=0;
    2'h1 : x_out=M_STAGE_ext;
    2'h2 : x_out=PCOUT;
    2'h3 : x_out=concat;
    endcase
    case(op_reg[3:2])
    2'h0 : z_out=0;
    2'h1 : z_out=PCIN;
    2'h2 : z_out=PCOUT;
    2'h3 : z_out=C_stage;
endcase
{carry_out, post_add_sub}=(op_reg[7])?(z_out-(x_out+carry_stage)):(z_out+x_out+carry_stage);
end
reg_sync_async #(.DATAWIDTH(1)) CYO(.CLK(CLK),.rst(RSTCARRYIN),.en(CECARRYIN),.d(carry_out),.Q(carry_out_reg));
assign CARRYOUT=(CARRYOUTREG)?carry_out_reg:carry_out;
assign CARRYOUTF=CARRYOUT;

reg_sync_async #(.DATAWIDTH(48)) p_REG(.CLK(CLK),.rst(RSTP),.en(CEP),.d(post_add_sub),.Q(P_reg));
assign P=(PREG)?P_reg:post_add_sub;
assign PCOUT=P;

endmodule

module tb_dsp48A1();
parameter A0REG=0,A1REG=1,B0REG=0,B1REG=1;
parameter CREG=1,DREG=1,MREG=1,PREG=1,CARRYINREG=1,CARRYOUTREG=1,OPMODEREG=1;
parameter CARRYINSEL="OPMODE5",B_INPUT="DIRECT",RSTTYPE="SYNC";
reg [17:0]A_TB,B_TB,D_TB,BCIN_TB;
reg [47:0]C_TB;
reg CARRYIN_TB;
wire  [35:0]M_tb;wire [47:0]P_tb;
wire CARRYOUT_TB,CARRYOUTF_TB;         //data ports

reg CLK,CEA,CEB,CED,CEM,CECARRYIN,CEC,CEOPMODE;reg [7:0]OPMODE_TB;
reg RSTA,RSTB,RSTC,RSTCARRYIN,CEP,RSTD,RSTM,RSTOPMODE,RSTP;

wire [47:0]PCOUT_TB;wire [17:0]BCOUT_TB;reg [48:0]PCIN_TB;

dsp48A1 DUT(.CLK(CLK),.A(A_TB),.B(B_TB),.C(C_TB),.D(D_TB),.CARRYIN(CARRYIN_TB),.OPMODE(OPMODE_TB),.BCIN(BCIN_TB)
,.RSTA(RSTA),.RSTB(RSTB),.RSTC(RSTC),.RSTD(RSTD),.RSTCARRYIN(RSTCARRYIN),.RSTM(RSTM),.RSTOPMODE(RSTOPMODE)
,.RSTP(RSTP),.CEA(CEA),.CEB(CEB),.CEC(CEC),.CECARRYIN(CECARRYIN),.CED(CED),.CEM(CEM),.CEOPMODE(CEOPMODE),.CEP(CEP)
,.PCIN(PCIN_TB),.PCOUT(PCOUT_TB),.BCOUT(BCOUT_TB),.CARRYOUT(CARRYOUT_TB),.CARRYOUTF(CARRYOUTF_TB),.M(M_tb),.P(P_tb));


initial begin
    CLK=0;
    forever
    #1 CLK=~CLK;
end
initial begin
    RSTA=1;
    RSTB=1;
    RSTC=1;
    RSTCARRYIN=1;
    RSTD=1;
    RSTM=1;
    RSTOPMODE=1;
    RSTP=1;
    A_TB=$random;
    B_TB=$random;
    C_TB=$random;
    D_TB=$random;
    BCIN_TB=$random;
    OPMODE_TB=$random;
    CARRYIN_TB=$random;
    PCIN_TB=$random;
    CEA=$random;
    CEB=$random;
    CEC=$random;
    CED=$random;
    CECARRYIN=$random;
    CEM=$random;
    CEOPMODE=$random;
    CEP=$random;
    @(negedge CLK);
    if(~(CARRYOUT_TB==0&&CARRYOUTF_TB==0&&P_tb==0&&PCOUT_TB==0&&BCOUT_TB==0&&M_tb==0))begin
        $display("error in rst");
        $stop;
    end

    RSTA=0;
    RSTB=0;
    RSTC=0;
    RSTCARRYIN=0;
    RSTD=0;
    RSTM=0;
    RSTOPMODE=0;
    RSTP=0;
    A_TB=20;
    B_TB=10;
    C_TB=350;
    D_TB=25;
    BCIN_TB=$random;
    OPMODE_TB=8'b11011101;
    CARRYIN_TB=$random;
    PCIN_TB=$random;
    CEA=1;
    CEB=1;
    CEC=1;
    CED=1;
    CECARRYIN=1;
    CEM=1;
    CEOPMODE=1;
    CEP=1;
    repeat(4)@(negedge CLK);
    if(~(BCOUT_TB=='hf && M_tb=='h12c && PCOUT_TB=='h32 && P_tb=='h32 && CARRYOUT_TB==0 && CARRYOUTF_TB==0))begin
        $display(" error in path1 ");
        $stop;
    end

    OPMODE_TB=8'b00010000;
    repeat(3)@(negedge CLK);
    if(~(BCOUT_TB=='h23 && M_tb=='h2bc && PCOUT_TB=='h0&& P_tb=='h0 && CARRYOUT_TB==0 && CARRYOUTF_TB==0))begin
        $display(" error in path2 ");
        $stop;
    end
    OPMODE_TB=8'b00001010;
    repeat(3)@(negedge CLK);
    if(~(BCOUT_TB=='ha && M_tb=='hc8 && P_tb==PCOUT_TB && CARRYOUT_TB==CARRYOUTF_TB))begin
        $display(" error in path3 ");
        $stop;
    end

    OPMODE_TB=8'b10100111;
    A_TB=5;
    B_TB=6;
    PCIN_TB=3000;
    repeat(3)@(negedge CLK);
    if(~(BCOUT_TB=='h6 && M_tb=='h1e && P_tb=='hfe6fffec0bb1 &&PCOUT_TB=='hfe6fffec0bb1 && CARRYOUT_TB==1 && CARRYOUTF_TB==1))begin
        $display(" error in path4 ");
        $stop;
    end
    $stop;
end
endmodule




