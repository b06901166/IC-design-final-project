module RNN(clk,reset,busy,ready,i_en,idata,mdata_w,mce,mdata_r,maddr,msel);
input           clk, reset;
input           ready;
input    [31:0] idata;
input    [19:0] mdata_r;

output          busy;
output          i_en;
output          mce;
output   [16:0] maddr;
output   [19:0] mdata_w;
output    [2:0] msel;

// Please DO NOT modified the I/O signal
// TODO
//==== input/output definition ============================
    reg [31:0] x_t, x_t_next;
    reg        busy, busy_next;
    reg        i_en, i_en_next;
    reg        mce, mce_next;
    reg [16:0] maddr, maddr_next;
    reg  [2:0] msel, msel_next;
    reg [19:0] mdata_r_blk, mdata_r_blk_next;
//==== state definition ===================================
    parameter IDLE = 4'd0; // reset
    parameter TIME = 4'd1; // get total time
    parameter PRER = 4'd2;
    parameter READ = 4'd3; // read all current data
    parameter ENDR = 4'd4;
    parameter GWHH = 4'd5;
    parameter PREC = 4'd6;
    parameter ENDP = 4'd7;
    parameter GWIH = 4'd8;
    parameter CALC = 4'd9; // calculate h_t
    parameter ENDC = 4'd10;
    parameter CALD = 4'd11;
    parameter BCAL = 4'd12;
    parameter ANSW = 4'd13; // write ans
    reg  [3:0] state, state_next;
//==== wire/reg definition ================================
    // storing data length
    reg        [19:0] data_length, data_length_next;
    // counting
    reg        [19:0] current_t, current_t_next;
    // parameter storing
        // h_t = sigma(W_ih * x_t + B_ih + W_hh * h_t_last + B_hh)
    reg signed [19:0] W_ih, W_ih_next;
    reg signed [19:0] W_hh, W_hh_next;
    reg signed [19:0] B[0:63], B_next[0:63];
    reg signed [19:0] h_t[0:63], h_t_next[0:63];
    reg signed [19:0] pre_h_t[0:63], pre_h_t_next[0:63];
    reg signed [19:0] calc_h, calc_h_next;
    reg               check_x, check_x_next;
    reg        [19:0] calc_B, calc_B_next;
    // calculation
    reg         [5:0] B_addr, B_addr_next;
    reg        [19:0] B_sum, B_sum_next;
    reg         [5:0] current_calc, current_calc_next;
    reg signed [39:0] prec_sum, prec_sum_next;
    reg signed [11:0] W_ih_addr, W_ih_addr_next;
    reg        [12:0] W_hh_addr, W_hh_addr_next;
//==== combinational circuit ==============================
    integer a, b;
    // state
    always@(*) begin
        // state
        state_next = state;
        // io
        x_t_next = x_t;
        busy_next = busy;
        i_en_next = i_en;
        mce_next = mce;
        maddr_next = maddr;
        msel_next = msel;
        mdata_r_blk_next = mdata_r_blk;
        // storing data length
        data_length_next = data_length;
        // counting
        current_t_next = current_t;
        // parameter storing
        B_addr_next = B_addr;
        B_sum_next = B_sum;
        W_ih_next = W_ih;
        W_hh_next = W_hh;
        W_ih_addr_next = W_ih_addr;
        W_hh_addr_next = W_hh_addr;
        for(a = 0; a < 64; a = a + 1) begin
            B_next[a] = B[a];
            h_t_next[a] = h_t[a];
            pre_h_t_next[a] = pre_h_t[a];
        end
        calc_h_next = calc_h;
        check_x_next = check_x;
        calc_B_next = calc_B;
        // calculation
        prec_sum_next = prec_sum;
        current_calc_next = current_calc;
        // state case
        case(state)
            IDLE: begin
                if(~reset) begin
                    state_next = TIME;
                    busy_next = 1'b1;
                    // mem read
                    mce_next = 1'b1;
                    maddr_next = 17'd0;
                    msel_next = 3'b100;
                end
            end
            TIME: begin
                state_next = PRER;
                data_length_next = mdata_r; // store data length
                current_t_next = 0; // reset current time
                // mem read
                maddr_next = 17'd0;
                msel_next = 3'b001;
            end
            PRER: begin
                // maddr_next = maddr + 1;
                // B_addr_next = maddr[5:0];
                // mdata_r_blk_next = mdata_r;
                // state_next = READ;
                B_addr_next = maddr[5:0];
                mdata_r_blk_next = mdata_r;
                state_next = READ;
                msel_next = 3'b011;
            end
            READ: begin
                // B_next[B_addr] = B[B_addr] + mdata_r_blk;
                // maddr_next = maddr + 1;
                // B_addr_next = maddr[5:0];
                // mdata_r_blk_next = mdata_r;
                // if(maddr == 63 && msel[1] == 1'b0) begin
                //     maddr_next = 0;
                //     msel_next = 3'b011;
                // end
                // else if(maddr == 63) begin
                //     maddr_next = 0;
                //     W_hh_addr_next = 1;
                //     W_ih_addr_next = 0;
                //     current_calc_next = 0;
                //     msel_next = 3'b010;
                //     mce_next = 0;
                //     state_next = ENDR;
                //     // data read
                // end
                
                B_addr_next = maddr[5:0];
                mdata_r_blk_next = mdata_r;
                if(msel == 3'b011) begin
                    B_sum_next = mdata_r_blk;
                    maddr_next = maddr + 1;
                    msel_next = 3'b001;
                end
                else begin
                    B_next[B_addr] = B_sum + mdata_r_blk;
                    msel_next = 3'b011;
                end
                if(maddr == 63 && msel[1] == 1'b1) begin
                    maddr_next = 0;
                    W_hh_addr_next = 1;
                    W_ih_addr_next = 0;
                    current_calc_next = 0;
                    msel_next = 3'b010;
                    mce_next = 0;
                    state_next = ENDR;
                    // data read
                end
            end
            ENDR: begin
                B_next[B_addr] = B_sum + mdata_r_blk;
                state_next = GWHH;
                i_en_next = 1'b1;
                mce_next = 1;
            end
            GWHH: begin
                if(i_en) begin
                    i_en_next = 1'b0;
                    x_t_next = idata;
                end
                W_hh_next = mdata_r;
                maddr_next = {4'b0000, W_hh_addr};
                W_hh_addr_next = W_hh_addr + 1;
                prec_sum_next = 0;
                calc_h_next = pre_h_t[maddr[5:0]];
                state_next = PREC;
            end
            PREC: begin
                // get next W_hh
                W_hh_next = mdata_r;
                maddr_next = {4'b0000, W_hh_addr};
                W_hh_addr_next = W_hh_addr + 1;
                calc_h_next = pre_h_t[maddr[5:0]];
                // calculate W_hh * h_t
                prec_sum_next = prec_sum + W_hh * calc_h;
                if(maddr[5:0] == 63) begin
                    state_next = ENDP;
                    maddr_next = {5'b00000, W_ih_addr};
                    W_ih_addr_next = W_ih_addr + 1;
                    msel_next = 3'b000;
                    W_hh_addr_next = W_hh_addr;
                end
                else begin
                    state_next = PREC;
                end
            end
            ENDP: begin
                // check prec
                prec_sum_next = prec_sum + W_hh * calc_h;
                if(prec_sum_next[15]) begin
                    prec_sum_next[35:16] = prec_sum_next[35:16] + 1;
                end
                state_next = GWIH;
            end
            GWIH: begin 
                // get W_ih
                W_ih_next = mdata_r;
                maddr_next = {5'b00000, W_ih_addr};
                W_ih_addr_next = W_ih_addr + 1;
                calc_h_next = prec_sum[35:16];
                check_x_next = x_t[maddr[4:0]];
                state_next = CALC;
            end

            CALC: begin
                // get W_ih
                W_ih_next = mdata_r;
                maddr_next = {5'b00000, W_ih_addr};
                W_ih_addr_next = W_ih_addr + 1;
                check_x_next = x_t[maddr[4:0]];
                state_next = CALC;
                // calculate W_ih * x_t
                if(check_x) calc_h_next = calc_h + W_ih;
                
                if(maddr[4:0] == 31) begin
                    state_next = ENDC;
                    mce_next = 0;
                    W_ih_addr_next = W_ih_addr;
                end
                else begin
                    state_next = CALC;
                end

            end
            ENDC: begin
                if(check_x) calc_h_next = calc_h + W_ih;
                calc_B_next = B[current_calc];
                state_next = CALD;
            end
            CALD: begin
                calc_h_next = calc_h + calc_B;
                state_next = BCAL;
            end
            BCAL: begin
                h_t_next[current_calc] = calc_h;
                if($signed(calc_h[19:16]) >= 1) begin
                    h_t_next[current_calc][19:16] = 1;
                    h_t_next[current_calc][15:0] = 0;
                end
                else if($signed(calc_h[19:16]) < -1) begin
                    h_t_next[current_calc][19:16] = -1;
                    h_t_next[current_calc][15:0] = 0;
                end

                mce_next = 1;
                msel_next = 3'b101;
                state_next = ANSW;
                maddr_next = {current_t[10:0], current_calc[5:0]};
                
            end
            ANSW: begin
                if(current_calc == 63) begin
                    if(current_t == data_length) begin
                        state_next = IDLE;
                        busy_next = 1'b0;
                    end
                    else begin
                        maddr_next = 0;
                        state_next = GWHH;
                        current_calc_next = 0;
                        current_t_next = current_t + 1;
                        msel_next = 3'b010;
                        mce_next = 1;
                        W_hh_addr_next = 1;
                        W_ih_addr_next = 0;
                        // data read
                        i_en_next = 1'b1;
                        for(a = 0; a < 64; a = a + 1) begin
                            pre_h_t_next[a] = h_t[a];
                        end
                    end
                end
                else begin
                    state_next = GWHH;
                    mce_next = 1'b1;
                    msel_next = 3'b010;
                    maddr_next = {4'b0000, W_hh_addr};
                    W_hh_addr_next = W_hh_addr + 1;
                    current_calc_next = current_calc + 1;
                end
            end
            default: state_next = state;
        endcase
    end
    assign mdata_w = h_t[maddr[5:0]];
//==== sequential circuit =================================
    integer i, j;
    always@(posedge clk or posedge reset) begin
        if(reset) begin
            // state
            state <= 0;
            // io
            x_t <= 0;
            busy <= 0;
            i_en <= 0;
            mce <= 0;
            maddr <= 0;
            msel <= 0;
            mdata_r_blk <= 0;
            B_addr <= 0;
            B_sum <= 0;
            // storing data length
            data_length <= 0;
            // counting
            current_t <= 0;
            // parameter storing
            W_hh <= 0;
            W_ih <= 0;
            W_ih_addr <= 0;
            W_hh_addr <= 0;
            for(i = 0; i < 64; i = i + 1) begin
                B[i] <= 0;
                h_t[i] <= 0;
                pre_h_t[i] <= 0;
            end
            calc_h <= 0;
            check_x <= 0;
            calc_B <= 0;
            // calculation
            current_calc <= 0;
            prec_sum <= 0;
        end
        else begin
            // state
            state <= state_next;
            // io
            x_t <= x_t_next;
            busy <= busy_next;
            i_en <= i_en_next;
            mce <= mce_next;
            maddr <= maddr_next;
            msel <= msel_next;
            mdata_r_blk <= mdata_r_blk_next;
            B_addr <= B_addr_next;
            B_sum <= B_sum_next;
            // storing data length
            data_length <= data_length_next;
            // counting
            current_t <= current_t_next;
            // parameter storing
            W_ih<= W_ih_next;
            W_hh <= W_hh_next;
            W_ih_addr <= W_ih_addr_next;
            W_hh_addr <= W_hh_addr_next;
            for(i = 0; i < 64; i = i + 1) begin
                B[i] <= B_next[i];
                h_t[i] <= h_t_next[i];
                pre_h_t[i] <= pre_h_t_next[i];
            end
            calc_h <= calc_h_next;
            check_x <= check_x_next;
            calc_B <= calc_B_next;
            // calculation
            current_calc <= current_calc_next;
            prec_sum <= prec_sum_next;
        end
    end

endmodule

