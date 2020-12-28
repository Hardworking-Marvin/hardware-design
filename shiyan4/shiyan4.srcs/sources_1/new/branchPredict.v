`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/11/16 12:51:08
// Design Name: 
// Module Name: branch_predict
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


/*
���ȫ����ʷԤ��Ĵ��룺
��Ҫ����GHR,һ������Ԥ��׶ξͽ��и��£�һ������MEM�׶ν��и���
��ΪGHR��BHRͬ��һ��PHT������GHR��λ����BHR��ͬ
*/
module branch_predict (
    input wire clk, rst,
    
//    input wire flushD, //zh
    input wire stallD,

    input wire [31:0] pcF,
    input wire [31:0] pcM,
    
    input wire branchM,         // M�׶��Ƿ��Ƿ�ָ֧��
    input wire actual_takeM,    // ʵ���Ƿ�Ӧ����ת
    input wire takeM,           //ʵ���Ƿ���ת
    input wire [31:0] pcMp4,
    input wire [31:0] pcMbranch,


    input wire branchD,        // ����׶��Ƿ�����תָ�
//    output wire pred_takeD,      // Ԥ���Ƿ���ת  ����ָ��Ҫ����PCֵ�ĸ���


    output wire final_pred,
    output wire flushD, flushE, flushM, //����֧Ԥ�����MEM�׶ν����Żᴦ�������������������ָ��Ǵ����
    output wire actual_add, //����֧Ԥ�����ʵ����Ӧ����ת�ĵ�ַ
    output wire controlPC //���ڿ���pcֵ�ĵڶ�����·ѡ������źţ��ڶ�����·ѡ������Ҫ���ڴ�����޸�
);
    wire pred_takeD_local;
    wire pred_takeD_global;
//�ֲ���ʷԤ��
    wire pred_takeF;
    reg pred_takeF_r;
//ȫ����ʷԤ��
    wire pred_takeF_global;
    reg pred_takeF_global_r;
//����
    wire pred_choice; //����ѡ������Ԥ�ⷽʽ
    reg pred_choice_r;
    wire [1:0] cmp; //���ڱȽϾֲ�Ԥ���ȫ��Ԥ���ĸ�Ԥ����ˡ���Ԥ���Ϊ11���ֲ���ȫ�ִ�10���ֲ���ȫ�ֶ�01,����Ϊ00
    
    

// �������
    parameter Strongly_not_taken = 2'b00, Weakly_not_taken = 2'b01, Weakly_taken = 2'b11, Strongly_taken = 2'b10;
    parameter Strongly_local = 2'b00, Weakly_local = 2'b01, Weakly_global = 2'b11, Strongly_global = 2'b10;
    parameter PHT_DEPTH = 6;
    parameter BHT_DEPTH = 10;

    reg [5:0] BHT [(1<<BHT_DEPTH)-1 : 0];
    reg [1:0] PHT [(1<<PHT_DEPTH)-1:0];
//���ȫ�ַ�֧Ԥ������Ҫ�ļĴ���GHR
    reg [5:0] GHR;
//��Ӿ�����֧Ԥ������Ҫ��CPHT
    reg [1:0] CPHT [(1<<PHT_DEPTH)-1:0];
    
    integer i,j;
    wire [(PHT_DEPTH-1):0] PHT_index;
    wire [(BHT_DEPTH-1):0] BHT_index;
    wire [(PHT_DEPTH-1):0] BHR_value;

// ---------------------------------------Ԥ���߼�---------------------------------------

    assign BHT_index = pcF[11:2];     
    assign BHR_value = BHT[BHT_index];  
    assign PHT_index = BHR_value;
    assign pred_takeF = PHT[PHT_index][1];      // ��ȡָ�׶�Ԥ���Ƿ����ת����������ˮ�ߴ��ݸ�����׶Ρ�
    
    
//    assign val = pcF[7:2];
    assign PHT_index_global = GHR ^ pcF[7:2]; //��GHR��ֵ��PC�Ĳ��ֵ�ַ���������Ϊ����PHT�ĵ�ַ
    assign pred_takeF_global = PHT[PHT_index_global][1];
    
    assign pred_choice = CPHT[PHT_index_global][1]; //ѡ��CPHT�������Ǻ�ȫ����ʷԤ��ʱ��������ͬ�� ��Ϊ1��ִ��ȫ��Ԥ�⣬����ִ�оֲ�Ԥ��

        // --------------------------pipeline------------------------------
            always @(posedge clk) begin
                if(rst | flushD) begin
                    pred_takeF_r <= 0;
                    pred_takeF_global_r <= 0;
                    pred_choice_r <= 0;
                end
                else if(~stallD) begin
                    pred_takeF_r <= pred_takeF;
                    pred_takeF_global_r <= pred_takeF_global;
                    pred_choice_r <= pred_choice;
                end
            end
            
        // --------------------------pipeline------------------------------
        
    // ����׶�������յ�Ԥ����
        assign pred_takeD_local = branchD & pred_takeF_r;  
        assign pred_takeD_global = branchD & pred_takeF_global_r;
        assign final_pred = (pred_choice_r == 1) ? pred_takeD_global : pred_takeD_local;
        
        
        //Ϊ�˽�IF�׶�ȫ�ֺ;ֲ���Ԥ�������ݵ�MEM����ˮ�߼Ĵ����ϣ�Ҫͨ��ID,EXE�׶ε���ˮ�߼Ĵ�������
        //������������Щ�����Ĵ��롣��
        reg pred_local_ID_r;
        reg pred_global_ID_r;
        always @(posedge clk) begin
            if(rst) begin
                pred_local_ID_r <= 0;
                pred_global_ID_r <= 0;
            end
            else begin
                pred_local_ID_r <= pred_takeD_local;
                pred_global_ID_r <= pred_takeD_global;
            end
        end
        wire pred_local_ID;
        wire pred_global_ID;
        assign pred_local_ID = pred_local_ID_r;
        assign pred_global_ID = pred_global_ID_r;        
        reg pred_local_EXE_r;
        reg pred_global_EXE_r;
        always @(posedge clk) begin
            if(rst) begin
                pred_local_EXE_r <= 0;
                pred_global_EXE_r <= 0;
            end
            else begin
                pred_local_EXE_r <= pred_local_ID;
                pred_global_EXE_r <= pred_global_ID;
            end
        end
        wire pred_local_EXE;
        wire pred_global_EXE;
        assign pred_local_EXE = pred_local_EXE_r;
        assign pred_global_EXE = pred_global_EXE_r;   
        reg pred_local_MEM_r;
        reg pred_global_MEM_r;   
        always @(posedge clk) begin
            if(rst) begin
                pred_local_MEM_r <= 0;
                pred_global_MEM_r <= 0;
            end
            else begin
                pred_local_MEM_r <= pred_local_EXE_r;
                pred_global_MEM_r <= pred_global_EXE_r;
            end
        end 
        assign cmp = {pred_local_MEM_r == actual_takeM, pred_global_MEM_r == actual_takeM};

        
// ---------------------------------------Ԥ���߼�---------------------------------------


// ---------------------------------------BHT��ʼ���Լ�����---------------------------------------
    wire [(PHT_DEPTH-1):0] update_PHT_index;
    wire [(BHT_DEPTH-1):0] update_BHT_index;
    wire [(PHT_DEPTH-1):0] update_BHR_value;
    wire [(PHT_DEPTH-1):0] global_cpht_index;
    wire [(PHT_DEPTH-1):0] update_PHT_global_index;

    assign update_BHT_index = pcM[11:2];     
    assign update_BHR_value = BHT[update_BHT_index];  
    assign update_PHT_index = update_BHR_value;
    assign update_PHT_global_index = pcM[7:2] ^ GHR;
    assign global_cpht_index = pcM[7:2] ^ GHR;

    always@(posedge clk) begin
        if(rst) begin
            for(j = 0; j < (1<<BHT_DEPTH); j=j+1) begin
                BHT[j] <= 0;
            end
        end
        else if(branchM) begin //ֻ���Ƿ�ָ֧��Ż���MEM�׶θ���BHR,��ָ���BHR���ƣ�ͬʱ����actual_takeM�Ľ��д��BHR
//            assign new_BHR_value = update_BHR_value << 1 | actual_takeM;
//            BHT[update_BHT_index] <= new_BHR_value;
              BHT[update_BHT_index] <= update_BHR_value << 1 | actual_takeM;
        end
    end
// ---------------------------------------BHT��ʼ���Լ�����---------------------------------------


// ---------------------------------------PHT��ʼ���Լ�����---------------------------------------
//PHT����Ҫ��������ghr��ֵ����bhr��ֵ���¶�Ӧ��pht������Ҫ��ID�׶�ѡ�����ֵ�����Ԥ��ģʽͨ����ˮ�߼Ĵ������ݵ�MEM�׶�
    always @(posedge clk) begin
        if(rst) begin
            for(i = 0; i < (1<<PHT_DEPTH); i=i+1) begin
                PHT[i] <= Weakly_taken;
            end
        end
        else if(branchM) begin //����Դ����û���ж��Ƿ���branchM���������,Ҳ����˵��ָ���Ƿ�ָ֧��ʱ���Ŷ�PHT�еĶ�Ӧ���ݸ���
                case(PHT[update_PHT_global_index])
                    2'b00: begin
                        if(actual_takeM) begin
                            PHT[update_PHT_global_index] <= 2'b01;
                        end
                        else begin
                            PHT[update_PHT_global_index] <= 2'b00;
                        end
                    end
                    2'b01: begin
                        if(actual_takeM) begin
                            PHT[update_PHT_global_index] <= 2'b11;
                        end
                        else begin
                            PHT[update_PHT_global_index] <= 2'b00;
                        end
                    end
                    2'b10: begin
                        if(actual_takeM) begin
                            PHT[update_PHT_global_index] <= 2'b10;
                        end
                        else begin
                            PHT[update_PHT_global_index] <= 2'b11;
                        end
                    end
                    2'b11: begin
                        if(actual_takeM) begin
                            PHT[update_PHT_global_index] <= 2'b10;
                        end
                        else begin
                            PHT[update_PHT_global_index] <= 2'b01;
                        end                
                    end
                endcase 
                
                case(PHT[update_PHT_index])
                    2'b00: begin
                        if(actual_takeM) begin
                            PHT[update_PHT_index] <= 2'b01;
                        end
                        else begin
                            PHT[update_PHT_index] <= 2'b00;
                        end
                    end
                    2'b01: begin
                        if(actual_takeM) begin
                            PHT[update_PHT_index] <= 2'b11;
                        end
                        else begin
                            PHT[update_PHT_index] <= 2'b00;
                        end
                    end
                    2'b10: begin
                        if(actual_takeM) begin
                            PHT[update_PHT_index] <= 2'b10;
                        end
                        else begin
                            PHT[update_PHT_index] <= 2'b11;
                        end
                    end
                    2'b11: begin
                        if(actual_takeM) begin
                            PHT[update_PHT_index] <= 2'b10;
                        end
                        else begin
                            PHT[update_PHT_index] <= 2'b01;
                        end                
                    end
                endcase 
        end
    end
// ---------------------------------------PHT��ʼ���Լ�����---------------------------------------

// ---------------------------------------CPHT��ʼ���Լ�����---------------------------------------
//CPHT�ĸ���Ҫ֪����ID�׶�global��local����Ԥ��Ľ����Ҫͨ���Ĵ������ݵ�MEM�׶�
    always @(posedge clk) begin
        if(rst) begin
            for(i = 0; i < (1<<PHT_DEPTH); i=i+1) begin
                CPHT[i] <= Weakly_taken;
            end
        end
        else if(branchM) begin
            case(CPHT[global_cpht_index])
                //״̬��4��״̬��ת��
                2'b00: begin
                    if(cmp == 2'b01) begin
                        CPHT[global_cpht_index] <= 2'b01;
                    end
                end
                2'b01: begin
                    if(cmp == 2'b01) begin
                        CPHT[global_cpht_index] <= 2'b11;
                    end
                    else if(cmp == 2'b10) begin
                        CPHT[global_cpht_index] <= 2'b00;
                    end
                end
                2'b10: begin
                    if(cmp == 2'b10) begin
                         CPHT[global_cpht_index] <= 2'b11;
                    end                   
                end
                2'b11: begin
                    if(cmp == 2'b01) begin
                        CPHT[global_cpht_index] <= 2'b10;
                    end
                    else if(cmp == 2'b10) begin
                        CPHT[global_cpht_index] <= 2'b01;
                    end               
                end
            endcase 
        end
    end
// ---------------------------------------CPHT��ʼ���Լ�����---------------------------------------


// ---------------------------------------GHR��ʼ���Լ�����---------------------------------------
//ȫ����ʷԤ���ڱ�ʵ���У���Ҫ�ȵ�ID�׶��ж��Ƿ�Ϊ��ָ֧���ž�������ָ��ĵ�ַ�������弶��ˮ�ߴ�����ͬ��������������ȣ�
//ִ�н׶�ͬȡַ�׶���ȼ�����ڲ�������Ϊ�˼�ʵ����ִ�н׶ν��и���GHR������MEM��ʼ��ʱ���ϱ���
    always@(posedge clk) begin
        if(rst) begin
            GHR <= 0;
        end
        else if(branchM) begin // GHR����IF�׶θ��£�ʵ��������IF����ID��ʼ��ʱ���ϱ��ظ���
            GHR  <= GHR << 1 | actual_takeM;
        end
    end  
// ---------------------------------------GHR��ʼ���Լ�����---------------------------------------


// ---------------------------------------��ת������---------------------------------------
//�ܹ���Ҫ��5��ֵ��ID�׶ξ���EXE��ˮ�߼Ĵ�����MEM��ˮ�߼Ĵ������ݹ����������ֵΪtakeM,actual_takeM,pc+4,pc+4+branch,branchD
//��takeM��actual_takeM�Ƚϣ�����ͬ����������Ҫ������ȷ��PCֵ��ͬʱ�������ִ�н׶�flush��
//��Ҫ��ԭʵ��4����ˮ�߼Ĵ�������Ϊ֮ǰ����Щ��ˮ�߼Ĵ�������flush�ź�
//takeM��ID�׶η�֧Ԥ��Ľ�� actual_takeM��ID�׶�ʵ�ʷ�֧�жϵĽ��
    assign flushD = (branchM && (takeM != actual_takeM)) ? 1 : 0;
    assign flushE = (branchM && (takeM != actual_takeM)) ? 1 : 0;
    assign flushM = (branchM && (takeM != actual_takeM)) ? 1 : 0;
    assign controlPC = (branchM && (takeM != actual_takeM)) ? 1 : 0;
    assign actual_add = (actual_takeM == 1) ? pcMbranch : pcMp4;
// ---------------------------------------��ת������---------------------------------------


endmodule
