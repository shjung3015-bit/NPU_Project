module UART_Bridge(
    input logic clk, rst_n, 
    input logic rx,
    input logic signed [3:0][31:0] result,
    input logic result_valid,

    output logic tx,
    output logic run, load_wgt, 
    output logic ena_act, wea_act, ena_wgt, wea_wgt,
    output logic [9:0] addr_act_wt, addr_wgt_wt,
    output logic [9:0] base_addr_wgt, base_addr_act,
    output logic [31:0] din_wgt, din_act,
    output logic pop_ena,
    output logic [9:0] num_act,
    output logic bridge_busy,
    output logic [4:0] dbg_state

);

    // Active-low so the LED for the *current* state lights up (Tang Nano 9K
    // LEDs are wired to the 1.8V bank and light when driven low).
    assign dbg_state = ~current_state;

    parameter WAIT_CMD= 5'b00001, WAIT_ADDR = 5'b00010, WAIT_DATA = 5'b00100, COMMIT = 5'b01000, SEND = 5'b10000;
    parameter WRITE = 1'b0, READ = 1'b1;

    logic [7:0] tx_data;
    logic tx_trigger;
    logic [4:0] current_state, next_state;
    logic [7:0] cmd, addr;
    logic [4:0] byte_remain;
    logic [1:0] byte_ide;
    logic [7:0] temp_buf [3:0];
    logic [7:0] tx_payload [0:16];
    logic [4:0] tx_ide;
    logic sent_started, tx_busy_seen, rx_valid, busy;
    logic [7:0] rx_byte;


    assign tx_data = tx_payload[tx_ide];
    assign tx_trigger = (current_state == SEND) && !sent_started;
    assign bridge_busy = (current_state != WAIT_CMD);

    UART_RX  U_rx(
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),

        .rx_byte(rx_byte),
        .rx_valid(rx_valid)
    );

    UART_TX U_tx(
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(tx_data),
        .trigger(tx_trigger),

        .busy(busy),
        .tx(tx)
    );


always_ff@(posedge clk) begin
    if(!rst_n) current_state <= WAIT_CMD;
    else current_state <= next_state;
end

always_ff@(posedge clk) begin 
    if(!rst_n) begin
        cmd <= 0;
        addr <= 0;
        byte_remain <= 0;
        temp_buf[0] <= 0;
        temp_buf[1] <= 0;
        temp_buf[2] <= 0;
        temp_buf[3] <= 0;
        tx_ide <= 0;
        sent_started <= 0;
        tx_busy_seen <= 0;

        {run, load_wgt, pop_ena} <= 0;
        {ena_act, wea_act, ena_wgt, wea_wgt} <= 0;
        addr_act_wt <= 0;
        addr_wgt_wt <= 0;
        base_addr_act <= 0;
        base_addr_wgt <= 0;
        num_act <= 0;
        din_act <= 0;
        din_wgt <= 0;

    end
    else begin
        case (current_state)
            WAIT_CMD: begin
                if(rx_valid) begin
                    cmd <= rx_byte;
                end
            end

            WAIT_ADDR: begin
                if(rx_valid) begin
                    addr <= rx_byte;
                    byte_ide <= 0;
                    case(rx_byte) 
                        8'h00: byte_remain <= 1;
                        8'h01: byte_remain <= 1;
                        8'h02: byte_remain <= 2;
                        8'h03: byte_remain <= 2;
                        8'h04: byte_remain <= 2;
                        8'h05: byte_remain <= 2;
                        8'h06: byte_remain <= 2;
                        8'h07: byte_remain <= 4;
                        8'h08: byte_remain <= 4;
                        8'h09: byte_remain <= 17;
                    endcase
                end
            end

            WAIT_DATA: begin
                if(rx_valid) begin
                    temp_buf[byte_ide] <= rx_byte;
                    byte_ide <= byte_ide + 1;
                    byte_remain <= byte_remain - 1;
                end

            end

            COMMIT: begin
                if(cmd == WRITE) begin
                    case (addr)
                        8'h00: {run, load_wgt, pop_ena} <= temp_buf[0][2:0];
                        8'h01: {ena_act, wea_act, ena_wgt, wea_wgt} <= temp_buf[0][3:0];
                        8'h02: addr_act_wt <= {temp_buf[0], temp_buf[1]};
                        8'h03: addr_wgt_wt <= {temp_buf[0], temp_buf[1]};
                        8'h04: base_addr_act <= {temp_buf[0], temp_buf[1]};
                        8'h05: base_addr_wgt <= {temp_buf[0], temp_buf[1]};
                        8'h06: num_act <= {temp_buf[0], temp_buf[1]};
                        8'h07: din_act <= {temp_buf[0], temp_buf[1], temp_buf[2], temp_buf[3]};
                        8'h08: din_wgt <= {temp_buf[0], temp_buf[1], temp_buf[2], temp_buf[3]};
                        default : ;
                    endcase
                end
                else if (cmd == READ) tx_ide <= 0;
            end

            SEND: begin
                if(tx_trigger) begin
                    sent_started <= 1;
                    tx_busy_seen <= 0;
                end
                else if (sent_started) begin
                    if (busy) tx_busy_seen <= 1;
                    else if (tx_busy_seen) begin
                        sent_started <= 0;
                        tx_ide <= tx_ide + 1;
                    end
                end
            end

        endcase
    end
end

    always_comb begin
        tx_payload [0] = {7'b0, result_valid};
        for(int i=0; i<4; i++)begin
            tx_payload[1+i*4 + 0] = result[i][31:24];
            tx_payload[1+i*4 + 1] = result[i][23:16];
            tx_payload[1+i*4 + 2] = result[i][15:8];
            tx_payload[1+i*4 + 3] = result[i][7:0];
        end
    end


    always_comb begin

        case(current_state) 
            WAIT_CMD: begin
                if(rx_valid) next_state = WAIT_ADDR;
                else next_state = WAIT_CMD;
            end

            WAIT_ADDR: begin
                if(rx_valid) begin
                    if(cmd == WRITE) next_state = WAIT_DATA;
                    else if(cmd == READ) next_state = COMMIT;
                    else next_state = WAIT_ADDR;
                end
                else next_state = WAIT_ADDR;
            end

            WAIT_DATA: begin
                if((rx_valid)&&(byte_remain == 1)) next_state = COMMIT;
                else next_state = WAIT_DATA;

            end

            COMMIT: begin 
                if(cmd == WRITE )next_state = WAIT_CMD;
                else if(cmd == READ) next_state = SEND;
                else next_state = WAIT_CMD;
            end

            SEND: begin
                if(tx_ide < 16) next_state = SEND;
                else if(sent_started && tx_busy_seen && !busy) next_state = WAIT_CMD;
                else next_state = SEND;
            end

            default: next_state = WAIT_CMD;
        
        endcase

    end

endmodule
