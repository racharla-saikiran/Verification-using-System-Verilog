`timescale 1ns / 1ps

class transaction;
    rand bit oper;
    bit rd,wr;
    bit [7:0] din;
    bit [7:0] dout;
    bit empty,full;
    
    constraint oper_con { oper dist {1:/65 , 0 :/35}; }
endclass 

class generator;
    transaction tr;
    mailbox #(transaction) mbx;
    event next, done;
    int count =0;
    int i=0;
    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
        tr = new();
        endfunction 
        
    task run();
        repeat(count) begin 
            assert(tr.randomize) else $error("Randomization Failed.");
            i++;
            mbx.put(tr);
            $display("[GEN] : Oper : %0d iteration : : %0d", tr.oper, i);
            @(next);
        end 
        ->done;
    endtask 
endclass 

class driver;
    transaction tr;
    mailbox #(transaction) mbx;
    virtual fifo_if fif;
    
    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
    endfunction 
    
    task reset();
        fif.rst <=1;
        fif.rd<=0;
        fif.wr<=0;
        fif.din<=0;
        repeat(5) @(posedge fif.clk);
        fif.rst<=0;
        $display("[DRV] : RESET DONE");
        $display("-----------------------------------------------------");
    endtask 
    
    task write();
        @(posedge fif.clk);
        fif.rst<=0;
        fif.rd<=0;
        fif.wr<=1;
        fif.din<= $urandom_range(1,10);
        @(posedge fif.clk);
        fif.wr<=0;
        $display("[DRV] : Data written. Data = %0d.",fif.din);
        @(posedge fif.clk);
    endtask  
    
    task read();
        @(posedge fif.clk);
        fif.rst<=0;
        fif.rd<=1;
        fif.wr<=0;
        @(posedge fif.clk);
        fif.rd<=0;
        $display("[DRV] : Data Read");
        @(posedge fif.clk);
    endtask  

    task run();
        forever begin 
            mbx.get(tr);
            if(tr.oper==1) write();
            else read();
        end 
    endtask 

endclass 


class monitor;
    transaction tr;
    mailbox #(transaction) mbx;
    virtual fifo_if fif;
    
    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
    endfunction 
    
    task run();
        tr = new();
        
        forever begin 
        repeat(2) @(posedge fif.clk);
            tr.wr = fif.wr;
            tr.rd = fif.rd;
            tr.din = fif.din;
            tr.empty = fif.empty;
            tr.full = fif.full;
            @(posedge fif.clk);
            tr.dout = fif.dout;
            
            mbx.put(tr);
            $display("[MON] : wr : %0d, rd : %0d, din : %0d, dout : %0d, full : %0d, empty : %0d",fif.wr,fif.rd,fif.din,fif.dout,fif.full,fif.empty);       
        end     
    endtask 
endclass 

class scoreboard;
    transaction tr;
    mailbox #(transaction) mbx;
    event next;
    
    function new(mailbox #(transaction) mbx);
        this.mbx = mbx;
    endfunction 
    
    bit [7:0] din[$];
    bit[7:0]temp;
    int err=0;
    
    task run();
        forever begin 
            mbx.get(tr);
            $display("[SCO] : wr : %0d, rd : %0d, din : %0d, dout : %0d, full : %0d, empty : %0d",tr.wr,tr.rd,tr.din,tr.dout,tr.full,tr.empty);       
            
            if(tr.wr) begin 
                if(tr.full==0) begin 
                    din.push_front(tr.din);
                    $display("[SCO] : Data stored in queue : %0d", tr.din);
                end 
                else begin $display("[SCO] : FIFO is full");
                end
                $display("----------------------------------------------");
            end 
                
            if(tr.rd) begin 
                if(tr.empty==0) begin 
                    temp = din.pop_back();
                    if(tr.dout==temp) $display("[SCO] : Data match");
                    else begin 
                        $error("[SCO] : Data Mismatch");
                        err++;
                    end 
                end 
                else begin 
                    $display("[SCO] : FIFO is Empty");
                                   
                end
                $display("-------------------------------------------------");
            end     
            ->next; 
        end  
    
    endtask 

endclass 

class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard sco;
    
    mailbox #(transaction) gdmbx,msmbx;
    event next;
    virtual fifo_if fif;
    
    function new(virtual fifo_if fif);
        gdmbx = new();
        msmbx = new();
        gen = new(gdmbx);
        drv = new(gdmbx);
        mon = new(msmbx);
        sco = new(msmbx);
        this.fif = fif;
        drv.fif = this.fif;
        mon.fif = this.fif;
        
        gen.next = next;
        sco.next = next;
        
    endfunction 

    task pre_test; 
        drv.reset();
        endtask 
    task test();
        fork 
            gen.run();
            drv.run();
            mon.run();
            sco.run();
        join_any 
    endtask 
    
    task post_test();
        wait(gen.done.triggered);
        $display("---------------------------------------------------");
        $display("Error Count : %0d", sco.err);
        $display("---------------------------------------------------");
        $finish();    
    endtask 
    
    task run();
        pre_test();
        test();
        post_test();
    endtask 

endclass 



module tb;
    fifo_if fif();
    
    FIFO DUT(fif.clk,fif.rst,fif.wr,fif.rd,fif.din,fif.dout,fif.empty,fif.full);
    
    initial fif.clk<=0;
    always #10 fif.clk <= ~fif.clk;
    
    environment env;
    
    initial begin 
        env = new(fif);
        env.gen.count = 10;
        env.run(); 
    
    end 
    
    initial begin 
        $dumpfile("dump.vcd");
        $dumpvars;
    end 
         
endmodule
