module UART_TX#(
    parameter CLKS_PER_BIT = 234
)(
    input logic clk, rst_n,
    input logic [7:0] tx_data,
    input logic trigger,

    output logic busy,
    output logic tx

);
    parameter IDLE = 4'b0001, START = 4'b0010, DATA = 4'b0100, STOP = 4'b1000;

    logic [3:0] current_state, next_state;
    logic [7:0] str_counter, st_counter, da_counter;
    logic [3:0] bit_counter;
    logic [7:0] shift_reg;

    always_ff@(posedge clk) begin
        if(!rst_n) current_state <= IDLE;
        else current_state <= next_state;
    end

    always_comb begin
        
        case(current_state)
            IDLE: begin
                if(trigger) next_state = START;
                else next_state = IDLE;
            end

            START: begin
                if(str_counter == CLKS_PER_BIT - 1) next_state = DATA;
                else next_state = START;
            end

            DATA: begin
                if(bit_counter == 8) next_state = STOP;
                else next_state = DATA;
            end

            STOP: begin
                if(st_counter == CLKS_PER_BIT - 1) next_state = IDLE;
                else next_state = STOP;
            end

            default: next_state = IDLE;
        endcase
    end

    always_ff@(posedge clk)begin
        if(!rst_n)begin
            busy <= 0;
            tx <= 0;
            str_counter <= 0;
            st_counter <= 0;
            bit_counter <= 0;
            da_counter <= 0;
        end

        else begin
            busy <= 0;

            case(current_state)
                IDLE: begin
                    tx <= 1;
                    str_counter <= 0;
                    st_counter <= 0;
                    bit_counter <=0;
                    da_counter <=0;
                    if(trigger == 1) shift_reg <= tx_data;
                end

                START: begin
                    tx <= 0;
                    busy <= 1;
                    str_counter <= str_counter + 1;
                end

                DATA: begin
                    busy <= 1;
                    if(bit_counter != 8) begin
                        tx <= shift_reg[0];
                        if(da_counter == CLKS_PER_BIT - 1) begin
                            da_counter <= 0;
                            bit_counter <= bit_counter + 1;
                            shift_reg <= {1'b0, shift_reg[7 : 1]};
                        end
                        else da_counter <= da_counter + 1;
                    end
                end

                STOP: begin
                    busy <= 1;
                    tx <= 1;
                    st_counter <= st_counter + 1;
                end
            endcase
        end
    end

endmodule
