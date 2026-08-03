module Controller(
    input logic clk, rst_n, run, load_wgt,
    input logic [9:0] base_addr_wgt, base_addr_act,
    input logic [9:0] num_act,
    input logic inject_ena,

    output logic enb_wgt, enb_act,
    output logic [9:0] addr_wgt, addr_act,
    output logic load_en, start
);

    parameter IDLE = 3'b001, LOAD_wgt = 3'b010, STREAM = 3'b100;

    logic [3:0] current_state, next_state;
    logic [1:0] wgt_offset;
    logic [9:0] act_offset;


    assign enb_wgt = (current_state == LOAD_wgt);
    assign enb_act = (current_state == STREAM) && inject_ena && (act_offset < num_act);
    assign addr_wgt = base_addr_wgt + wgt_offset;
    assign addr_act = base_addr_act + act_offset;


    always_ff@(posedge clk) begin
        if(!rst_n) current_state <= IDLE;
        else current_state <= next_state;
    end

    always_comb begin
        case(current_state)
            IDLE: begin
                if(load_wgt) next_state = LOAD_wgt;
                
                else if(run) next_state = STREAM;
                
                else next_state = IDLE;
            end
            LOAD_wgt: begin
                if(wgt_offset == 2'b00) next_state = IDLE;
                else next_state = LOAD_wgt;
            end
            
            STREAM: begin
                if(act_offset == num_act) next_state = IDLE;
                else next_state = STREAM;
            end

            default: next_state = IDLE;

        endcase
            
    end


    always_ff@(posedge clk) begin
        if(!rst_n) begin
            load_en <= 0;
            start <= 0;

            wgt_offset <= 3;
            act_offset <= 0;

        end
        
        else begin
            case(current_state)
                IDLE: begin
                    load_en <= 0;
                    wgt_offset <= 2'b11;
                    act_offset <= 2'b00;
                end
           
                LOAD_wgt: begin
                    load_en <= 1;
                    wgt_offset <= wgt_offset - 1;
                end
                STREAM: begin
                    if(inject_ena && act_offset < num_act) begin
                        start <= 1;
                        act_offset <= act_offset + 1;
                    end
                    else begin
                        start <= 0;
                    end
                end
            endcase 
        end
    end



endmodule


