`ifndef ALU
`define ALU

// alu.sv
// author: Tom Riley
// date: 2025-04-30

typedef enum logic [2:0] {
    ADD      = 3'b000,
    SUB      = 3'b001,
    AND      = 3'b010,
    RESERVED = 3'b011,
    OR       = 3'b100,
    XOR      = 3'b101,
    COPY_B   = 3'b110,
    NOT_B    = 3'b111
} alu_func_e;

// This module is a simple ALU with basic add, sub, and AND / OR / XOR / NOT_B / COPY_B functions
module alu#(
    parameter int DATA_WIDTH = 8
)(
    // Inputs
    input   wire [DATA_WIDTH-1:0]   op_a,
    input   wire [DATA_WIDTH-1:0]   op_b,
    input   wire alu_func_e         func,
    // Outputs
    output  wire [DATA_WIDTH-1:0]   out,
    output  wire                    signed_overflow,
    output  wire                    carry_flag
);
    wire [DATA_WIDTH-1:0]   b_or_invert_b;
    wire [DATA_WIDTH-1:0]   arith_result;
    wire [DATA_WIDTH-1:0]   a_or_b;
    wire [DATA_WIDTH-1:0]   a_and_b;
    wire [DATA_WIDTH-1:0]   a_xor_b;
    wire [DATA_WIDTH-1:0]   or_xor_muxed;
    wire [DATA_WIDTH-1:0]   b_inverted;
    wire [1:0]              mux_sel;
    wire                    sub_or_logic_select;
    wire                    a_sign;
    wire                    b_sign;
    wire                    result_sign;
    wire                    b_xor_sub;
    wire                    a_xor_b_xor_sub;
    wire                    not_a_xor_b_xor_sub;
    wire                    a_xor_result;
    wire                    not_signed_overflow;
    
    // Wire aliases
    assign mux_sel              = func[2:1];
    assign sub_or_logic_select  = func[0];
    assign a_sign               = op_a[DATA_WIDTH-1];
    assign b_sign               = op_b[DATA_WIDTH-1];
    assign result_sign          = arith_result[DATA_WIDTH-1];

    // Combinational logic
    assign a_or_b                       = op_a | op_b;                                                          // 8-bit OR (2x 74LS32)                      
    assign a_and_b                      = op_a & op_b;                                                          // 8-bit AND (2x 74LS08)
    assign a_xor_b                      = op_a ^ op_b;                                                          // 8-bit XOR (2x 74LS86)
    assign b_inverted                   = ~op_b;                                                                // 8-bit inverter (6/6 + 2/6 74LS04)
    assign {carry_flag, arith_result}   = op_a + b_or_invert_b + {{(DATA_WIDTH){1'b0}}, sub_or_logic_select};   // 8-bit adder with carry (2x 74LS83)
    assign b_or_invert_b                = sub_or_logic_select ? b_inverted : op_b;                              // 2:1 byte mux (2x 74LS157)
    assign or_xor_muxed                 = sub_or_logic_select ? a_xor_b : a_or_b;                               // 2:1 byte mux (2x 74LS157)
    assign b_xor_sub                    = b_sign ^ sub_or_logic_select;                                         // 1-bit XOR (1/4 74LS86)
    assign a_xor_b_xor_sub              = a_sign ^ b_xor_sub;                                                   // 1-bit XOR (1/4 74LS86)
    assign a_xor_result                 = a_sign ^ result_sign;                                                 // 1-bit XOR (1/4 74LS86)
    assign not_signed_overflow          = ~(not_a_xor_b_xor_sub & a_xor_result);                                // 1-bit NAND (1/4 74LS00)
    assign not_a_xor_b_xor_sub          = ~a_xor_b_xor_sub;                                                     // 1-bit inverter (1/6 74LS04)
    assign signed_overflow              = ~not_signed_overflow;                                                 // 1-bit inverter (1/6 74LS04)

    always_comb unique case (mux_sel)                                                                           // 4:1 byte mux (4x 74LS153)
        2'b00: out = arith_result;
        2'b01: out = a_and_b;
        2'b10: out = or_xor_muxed;
        2'b11: out = b_or_invert_b;
    endcase

    // Assertions
    // The assertions are used to check the functionality of the ALU
    always @(*) begin
        assert (
            !(func == ADD) || (out == (op_a + op_b))
        ) else $error("Error on ADD. Expected 0x%2h + 0x%2h = 0x%2h, got 0x%2h", op_a, op_b, (op_a + op_b), out);
        assert (
            !(func == SUB) || (out == (op_a - op_b))
        ) else $error("Error on SUB. Expected 0x%2h - 0x%2h = 0x%2h, got 0x%2h", op_a, op_b, (op_a - op_b), out);
        assert (
            !(func == AND) || (out == (op_a & op_b))
        ) else $error("Error on AND. Expected 0x%2h & 0x%2h = 0x%2h, got 0x%2h", op_a, op_b, (op_a & op_b), out);
        assert (
            !(func == OR) || (out == (op_a | op_b))
        ) else $error("Error on OR. Expected 0x%2h | 0x%2h = 0x%2h, got 0x%2h", op_a, op_b, (op_a | op_b), out);
        assert (
            !(func == XOR) || (out == (op_a ^ op_b))
        ) else $error("Error on XOR. Expected 0x%2h ^ 0x%2h = 0x%2h, got 0x%2h", op_a, op_b, (op_a ^ op_b), out);
        assert (
            !(func == NOT_B) || (out == ~op_b)
        ) else $error("Error on NOT_B. Expected ~0x%2h = 0x%2h, got 0x%2h", op_b, ~op_b, out);
        assert (
            !(func == COPY_B) || (out == op_b)
        ) else $error("Error on COPY_B. Expected 0x%2h, got 0x%2h", op_b, out);
        assert (
            !(func == ADD && signed_overflow) || 
            ((op_a[DATA_WIDTH-1] == op_b[DATA_WIDTH-1]) && (op_a[DATA_WIDTH-1] != out[DATA_WIDTH-1]))
        ) else $error("Unexpected signed overflow on ADD. op_a: 0x%2h, op_b: 0x%2h, out: 0x%2h", op_a, op_b, out);
        assert (
            !(func == SUB && signed_overflow) || 
            ((op_a[DATA_WIDTH-1] != op_b[DATA_WIDTH-1]) && (op_a[DATA_WIDTH-1] != out[DATA_WIDTH-1]))
        ) else $error("Unexpected signed overflow on SUB. op_a: 0x%2h, op_b: 0x%2h, out: 0x%2h", op_a, op_b, out);
        assert (
            !(func == ADD && carry_flag) || 
            ({1'b0, op_a} + {1'b0, op_b} > {1'b0, {DATA_WIDTH{1'b1}}})
        ) else $error("Unexpected unsigned overflow on ADD. op_a: 0x%2h, op_b: 0x%2h, out: 0x%2h, carry_flag: 0x%2h", op_a, op_b, out, carry_flag);
        assert (
            !(func == SUB && carry_flag) || 
            ({1'b0, op_a} >= {1'b0, op_b})
        ) else $error("Unexpected carry flag on SUB. op_a: 0x%2h, op_b: 0x%2h, out: 0x%2h, carry_flag: 0x%2h", op_a, op_b, out, carry_flag);
    end

endmodule: alu

`endif // ALU
