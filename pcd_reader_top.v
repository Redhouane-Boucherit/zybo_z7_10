`timescale 1ns / 1ps

module pcd_reader_top(
    input  wire sysclk,      // 125 MHz
    input  wire btn0,        // Reset
    input  wire btn1,        // Trigger Transmission
    input  wire [3:0] sw,    // Command Selection Switches
    output wire je1,         // Output 13.56 MHz Clock to Spartan
    output wire je2,         // Output Data (Miller) to Spartan
    output wire [3:0] led    // Status LEDs
);

    // 1. Clock Generation
    wire clk_13_56;
    wire locked;
    
    clk_wiz_0 u_clk_wiz (
        .clk_out1(clk_13_56),
        .reset(btn0),
        .locked(locked),
        .clk_in1(sysclk)
    );

    // Forward Clock to Output Pin (using ODDR for clean clock output)
    ODDR #(
        .DDR_CLK_EDGE("OPPOSITE_EDGE"),
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) u_oddr_clk (
        .Q(je1),
        .C(clk_13_56),
        .CE(1'b1),
        .D1(1'b1),
        .D2(1'b0),
        .R(1'b0),
        .S(1'b0)
    );

    // 2. Frequency Divider Logic (Create the 847.5kHz timebase)
    // Your Tag divides by 16 . We must match this timing.
    reg [3:0] div_cnt; 
    reg       pulse_847;
    
    always @(posedge clk_13_56) begin
        if (btn0) begin
            div_cnt <= 0;
            pulse_847 <= 0;
        end else begin
            div_cnt <= div_cnt + 1;
            // Check for 15 (4'b1111) -> Divide by 16
            pulse_847 <= (div_cnt == 4'b1111); 
        end
    end

    // 3. Sequence Generator
    // We'll use a large case statement or a ROM to define the sequences.
    // For flexibility, let's use a "command memory" approach.
    
    // Max sequence length (approximate for largest command)
    localparam MAX_SEQ_LEN = 256; 
    
    reg [1:0] seq_mem [0:MAX_SEQ_LEN-1]; // 0=Z, 1=X, 2=Y
    reg [8:0] seq_len; // Length of current sequence
    
    integer i;

    // Command Loading Logic (Combinational - based on switches)
   // Command Loading Logic (Combinational - based on switches)
    always @* begin
        // Default: Clear memory
        for (i = 0; i < MAX_SEQ_LEN; i = i + 1) seq_mem[i] = 2'd2; // Y
        seq_len = 0;

        case (sw)
            // --------------------------------------------------------
            // CASE 0: REQA (26)
            // Sequence: Z, Z, X, X, Y, Z, X, Y, Z, Y
            // --------------------------------------------------------
            4'b0000: begin 
                seq_mem[0]=0; seq_mem[1]=0; seq_mem[2]=1; seq_mem[3]=1; 
                seq_mem[4]=2; seq_mem[5]=0; seq_mem[6]=1; seq_mem[7]=2; 
                seq_mem[8]=0; seq_mem[9]=2;
                seq_len = 10;
            end

            // --------------------------------------------------------
            // CASE 1: WUPA (52)
            // Sequence: Z, Z, X, Y, Z, X, Y, X, Y, Y
            // --------------------------------------------------------
            4'b0001: begin 
                seq_mem[0]=0; seq_mem[1]=0; seq_mem[2]=1; seq_mem[3]=2; 
                seq_mem[4]=0; seq_mem[5]=1; seq_mem[6]=2; seq_mem[7]=1; 
                seq_mem[8]=2; seq_mem[9]=2;
                seq_len = 10;
            end

            // --------------------------------------------------------
            // CASE 2: SELECT CL1 (93 20)
            // Derived from "Stimulus process 9320"
            // --------------------------------------------------------
            4'b0010: begin 
                // Z
                seq_mem[0]=0; 
                // X, X, Y, Z, X, Y, Z, X, X
                seq_mem[1]=1; seq_mem[2]=1; seq_mem[3]=2; seq_mem[4]=0; 
                seq_mem[5]=1; seq_mem[6]=2; seq_mem[7]=0; seq_mem[8]=1; seq_mem[9]=1;
                // Y, Z, Z, Z, Z, X, Y, Z, Z
                seq_mem[10]=2; seq_mem[11]=0; seq_mem[12]=0; seq_mem[13]=0; 
                seq_mem[14]=0; seq_mem[15]=1; seq_mem[16]=2; seq_mem[17]=0; seq_mem[18]=0;
                // Z, Y
                seq_mem[19]=0; seq_mem[20]=2;
                seq_len = 21;
            end

            // --------------------------------------------------------
            // CASE 3: LONG SELECT (93 70 88 11 22 33 88 FA F4)
            // Derived from "Stimulus process 93708811223388FAF4"
            // --------------------------------------------------------
            4'b0011: begin 
                // Z
                seq_mem[0]=0;
                // Byte 93: X, X, Y, Z, X, Y, Z, X, X
                seq_mem[1]=1; seq_mem[2]=1; seq_mem[3]=2; seq_mem[4]=0; seq_mem[5]=1; seq_mem[6]=2; seq_mem[7]=0; seq_mem[8]=1; seq_mem[9]=1;
                // Byte 70: Y, Z, Z, Z, X, X, X, Y, Z
                seq_mem[10]=2; seq_mem[11]=0; seq_mem[12]=0; seq_mem[13]=0; seq_mem[14]=1; seq_mem[15]=1; seq_mem[16]=1; seq_mem[17]=2; seq_mem[18]=0;
                // Byte 88: Z, Z, Z, X, Y, Z, Z, X, X
                seq_mem[19]=0; seq_mem[20]=0; seq_mem[21]=0; seq_mem[22]=1; seq_mem[23]=2; seq_mem[24]=0; seq_mem[25]=0; seq_mem[26]=1; seq_mem[27]=1;
                // Byte 11: X, Y, Z, Z, X, Y, Z, Z, X
                seq_mem[28]=1; seq_mem[29]=2; seq_mem[30]=0; seq_mem[31]=0; seq_mem[32]=1; seq_mem[33]=2; seq_mem[34]=0; seq_mem[35]=0; seq_mem[36]=1;
                // Byte 22: Y, X, Y, Z, Z, X, Y, Z, X
                seq_mem[37]=2; seq_mem[38]=1; seq_mem[39]=2; seq_mem[40]=0; seq_mem[41]=0; seq_mem[42]=1; seq_mem[43]=2; seq_mem[44]=0; seq_mem[45]=1;
                // Byte 33: X, X, Y, Z, X, X, Y, Z, X
                seq_mem[46]=1; seq_mem[47]=1; seq_mem[48]=2; seq_mem[49]=0; seq_mem[50]=1; seq_mem[51]=1; seq_mem[52]=2; seq_mem[53]=0; seq_mem[54]=1;
                // Byte 88: Y, Z, Z, Z, X, X, X, X, X (Wait, TB says X parity? Corrected to logic 1 X)
                // TB: Y Z Z Z Z Z Z Z X -- Wait, looking at your TB: 
                // TB: Y Z Z Z Z Z Z Z Z X (Byte 88 again? No, looking at lines 343 in your code)
                // Let's use the exact TB lines for 9370... 
                // ... Y Z Z Z Z Z Z Z X
                seq_mem[55]=2; seq_mem[56]=0; seq_mem[57]=0; seq_mem[58]=0; seq_mem[59]=0; seq_mem[60]=0; seq_mem[61]=0; seq_mem[62]=0; seq_mem[63]=1;
                // Byte FA: Y X Y X X X X X X
                seq_mem[64]=2; seq_mem[65]=1; seq_mem[66]=2; seq_mem[67]=1; seq_mem[68]=1; seq_mem[69]=1; seq_mem[70]=1; seq_mem[71]=1; seq_mem[72]=1;
                // Byte F4: Y Z X Y X X X X Y
                seq_mem[73]=2; seq_mem[74]=0; seq_mem[75]=1; seq_mem[76]=2; seq_mem[77]=1; seq_mem[78]=1; seq_mem[79]=1; seq_mem[80]=1; seq_mem[81]=2;
                // End: Z Y
                seq_mem[82]=0; seq_mem[83]=2;
                seq_len = 84;
            end

            // --------------------------------------------------------
            // CASE 4: HALT (50 00 57 CD)
            // Derived from "Stimulus process 500057CD"
            // --------------------------------------------------------
            4'b0100: begin 
                // Z
                seq_mem[0]=0;
                // 50: Z Z Z Z X Y X Y X
                seq_mem[1]=0; seq_mem[2]=0; seq_mem[3]=0; seq_mem[4]=0; seq_mem[5]=1; seq_mem[6]=2; seq_mem[7]=1; seq_mem[8]=2; seq_mem[9]=1;
                // 00: Y Z Z Z Z Z Z Z Z X
                seq_mem[10]=2; seq_mem[11]=0; seq_mem[12]=0; seq_mem[13]=0; seq_mem[14]=0; seq_mem[15]=0; seq_mem[16]=0; seq_mem[17]=0; seq_mem[18]=0; seq_mem[19]=1;
                // 57: X X X Y X Y X Y Z
                seq_mem[20]=1; seq_mem[21]=1; seq_mem[22]=1; seq_mem[23]=2; seq_mem[24]=1; seq_mem[25]=2; seq_mem[26]=1; seq_mem[27]=2; seq_mem[28]=0;
                // CD: X Y X X Y Z X X Y
                seq_mem[29]=1; seq_mem[30]=2; seq_mem[31]=1; seq_mem[32]=1; seq_mem[33]=2; seq_mem[34]=0; seq_mem[35]=1; seq_mem[36]=1; seq_mem[37]=2;
                // End: Z Y
                seq_mem[38]=0; seq_mem[39]=2;
                seq_len = 40;
            end

            // Default to REQA (26)
            default: begin 
                seq_mem[0]=0; seq_mem[1]=0; seq_mem[2]=1; seq_mem[3]=1; 
                seq_mem[4]=2; seq_mem[5]=0; seq_mem[6]=1; seq_mem[7]=2; 
                seq_mem[8]=0; seq_mem[9]=2;
                seq_len = 10;
            end
        endcase
    end

    // 4. Transmission Logic
    reg [8:0]  seq_index;
    reg [2:0]  bit_index;
    reg        sending;
    reg        tx_line;
    reg        btn1_d;
    
    reg [1:0]  current_seq_type;

    always @(posedge clk_13_56) begin
        if (btn0) begin
            sending <= 0;
            tx_line <= 1; // Idle High
            seq_index <= 0;
            bit_index <= 0;
            btn1_d <= 0;
        end else begin
            btn1_d <= btn1;
            
            // Trigger on button press
            if (btn1 && !btn1_d && !sending) begin
                sending <= 1;
                seq_index <= 0;
                bit_index <= 0;
            end

            // Update logic on the subcarrier tick (pulse_847)
            if (sending && pulse_847) begin
                
                // Fetch current symbol type from "memory"
                current_seq_type = seq_mem[seq_index];

                // Generate Waveform based on Type
                case (current_seq_type)
                    2'd0: begin // Z Sequence: 2 cycles LOW, 6 cycles HIGH
                        if (bit_index < 2) tx_line <= 1'b0;
                        else               tx_line <= 1'b1;
                    end
                    2'd1: begin // X Sequence: 4 HIGH, 2 LOW, 2 HIGH
                        if (bit_index >= 4 && bit_index < 6) tx_line <= 1'b0;
                        else                                 tx_line <= 1'b1;
                    end
                    2'd2: begin // Y Sequence: All HIGH
                        tx_line <= 1'b1;
                    end
                    default: tx_line <= 1'b1;
                endcase

                // Increment Counters
                if (bit_index == 3'd7) begin
                    bit_index <= 0;
                    if (seq_index == (seq_len - 1)) begin
                        sending <= 0; // Done
                        tx_line <= 1; // Return to Idle
                    end else begin
                        seq_index <= seq_index + 1;
                    end
                end else begin
                    bit_index <= bit_index + 1;
                end
            end
        end
    end

    assign je2 = tx_line;
    assign led[0] = locked;
    assign led[1] = sending;
    assign led[2] = tx_line;
    assign led[3] = 1'b0;

endmodule