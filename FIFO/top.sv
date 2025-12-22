`timescale 1ns / 1ps
module FIFO(
    input clk,rst,wr,rd,input [7:0] din, output reg [7:0]dout,output empty,full
    );
    
    reg [3:0] rptr=0,wptr=0;
    reg [4:0] count=0;
    reg [7:0] mem [15:0];
    
    always @(posedge clk) begin 
        if(rst) begin
        wptr<=0;
        rptr<=0;
        count<=0;
        end 
        else if(wr && !full)begin
            mem[wptr] <=din;
            wptr <=wptr+1;
            count <= count+1;
                    
        end 
        else if (rd && !empty) begin 
            dout<=mem[rptr];
            rptr <=rptr+1;
            count<=count-1;
               
        end    
    end 
        assign full = (count==16);
        assign empty = (count==0);
endmodule


interface fifo_if;
    logic clk,rst,rd,wr,full, empty;
    logic [7:0] din,dout;
   
endinterface    





