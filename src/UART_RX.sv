module UART_RX #(
    parameter CLKS_PER_BIT = 234
)(
    input logic clk, rst_n, rx,

    output logic [7:0] rx_byte,
    output logic rx_valid
);


    parameter IDLE = 4'b0001, START = 4'b0010, DATA = 4'b0100, STOP = 4'b1000;

    logic [3:0] next_state, current_state;
    logic [3:0] bit_counter;
    logic [7:0] st_counter, str_counter, da_counter;
    logic [7:0] shift_reg;
    logic rx_meta, rx_sync;
    logic [4:0] idle_high_cnt;
    localparam IDLE_CONFIRM = 16;

    always_ff@(posedge clk) begin
        if(!rst_n) current_state <= IDLE;
        else current_state <= next_state;
    end

    always_ff@(posedge clk) begin
        if(!rst_n) begin
            rx_meta <=1'b1;
            rx_sync <=1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    always_ff@(posedge clk) begin
        if(!rst_n) idle_high_cnt <= 0;
        else if(rx_sync) idle_high_cnt <= (idle_high_cnt == IDLE_CONFIRM) ? idle_high_cnt : idle_high_cnt + 1;
        else idle_high_cnt <= 0;
    end

    wire line_idle_confirmed = (idle_high_cnt == IDLE_CONFIRM);



    always_comb begin

        case(current_state)
        
            IDLE: begin
                if(!rx_sync && line_idle_confirmed) next_state = START;
                else next_state = IDLE;
            end

            START: begin
                if(!rx_sync) begin
                    if(str_counter == CLKS_PER_BIT/2 - 1) next_state = DATA;
                    else next_state = START;
                end else begin
                    next_state = IDLE;
                end
            end

            DATA: begin
                if((bit_counter == 8)) next_state = STOP;
                else next_state = DATA;
            end

            STOP: begin
                if(rx_sync) begin
                    if(st_counter == CLKS_PER_BIT-1) next_state = IDLE;
                    else next_state = STOP;
                end else begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase

    end

    always_ff@(posedge clk) begin

        if(!rst_n) begin
            st_counter <=0;
            str_counter <=0;
            bit_counter <=0;
            da_counter <=0;
            shift_reg <=0;
            rx_byte <=0;
            rx_valid<=0;
        end

        else begin 
            rx_valid <=0;
            
            case(current_state)

                IDLE: begin
                    str_counter <=0;
                    da_counter <=0;
                    st_counter <=0;
                    bit_counter <=0;
                end

                START: begin
                    str_counter <= str_counter + 1; 
                end

                DATA: begin
                    if(bit_counter == 8) begin 
                        rx_byte <= shift_reg;
                        rx_valid <= 1;
                    end
                    else begin
                        if(da_counter == CLKS_PER_BIT - 1) begin
                            da_counter <= 0;
                            shift_reg <= {rx_sync, shift_reg[7:1]};
                            bit_counter <= bit_counter + 1;
                        end
                        else da_counter <=da_counter +1;                    
                        end
                end

                STOP: begin
                    st_counter <= st_counter + 1;
                end
            endcase
        end
    end
endmodule 
