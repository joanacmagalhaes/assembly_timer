.global _start

.equ JTAG_UART_BASE, 0xFF201000   // Base address for JTAG UART
.equ SEVEN_SEG_BASE, 0xFF200020   // Base address for seven-segment displays
.equ TIMER_LIMIT, 999999           // Timer limit

_start:
    LDR R0, =SEVEN_SEG_BASE       // Load seven-segment display address
    LDR R1, =JTAG_UART_BASE       // Load JTAG UART address
    MOV R2, #0                    // Initialize timer value (R2 = 0)
    MOV R3, #1                    // Timer running flag (1 = running)
    BL print_menu                 // Print menu

main_loop:
    BL update_display             // Update display with current timer value
    BL check_uart_input           // Check user input
    CMP R3, #1                    // Is timer running?
    BEQ increment_timer           // If yes, increment
    B main_loop                   // Loop

increment_timer:
    ADD R2, R2, #1                // Increment timer
    LDR R4, =TIMER_LIMIT          // Load timer limit
    CMP R2, R4                    // Check if timer >= limit
    BLT no_reset                  // If not, continue
    MOV R2, #0                    // Reset timer to 0
no_reset:
    BL delay                      // Add delay
    B main_loop                   // Loop

@-------------------------------------------------
@ Update Display (Combine all digits into one 32-bit value)
@-------------------------------------------------
update_display:
    PUSH {R4-R8, LR}              // Save registers
    LDR R4, =SEVEN_SEG_BASE       // Seven-segment base address
    LDR R5, =seven_seg_digits     // Load segment codes

    @ Extract digits (units, tens, hundreds, thousands)
    MOV R6, R2                    // Copy timer value to R6
    MOV R7, #0                    // Initialize combined value

    @ Units digit (bits 0-7)
    MOV R0, R6
    BL div10                      // R0 = quotient, R1 = remainder (units)
    LDRB R8, [R5, R12]             // Load segment code for units
    ORR R7, R7, R8                // Add to combined value

    @ Tens digit (bits 8-15)
    MOV R0, R0
    BL div10                      // R0 = quotient, R1 = remainder (tens)
    LDRB R8, [R5, R12]
    ORR R7, R7, R8, LSL #8        // Shift left by 8 bits

    @ Hundreds digit (bits 16-23)
    MOV R0, R0
    BL div10                      // R0 = quotient, R1 = remainder (hundreds)
    LDRB R8, [R5, R12]
    ORR R7, R7, R8, LSL #16       // Shift left by 16 bits

    @ Thousands digit (bits 24-31)
    MOV R0, R0
    BL div10                      // R0 = quotient, R1 = remainder (thousands)
    LDRB R8, [R5, R12]
    ORR R7, R7, R8, LSL #24       // Shift left by 24 bits

    STR R7, [R4]                  // Write all digits to display
    POP {R4-R8, LR}               // Restore registers
    BX LR

@-------------------------------------------------
@ Division by 10 
@-------------------------------------------------
div10:
    PUSH {R2, LR}
    MOV R2, R0
    MOV R0, #0
div10_loop:
    CMP R2, #10
    BLT div10_end
    SUB R2, R2, #10
    ADD R0, R0, #1
    B div10_loop
div10_end:
    MOV R12, R2
    POP {R2, LR}
    BX LR

@-------------------------------------------------
@ JTAG UART Input Handling 
@-------------------------------------------------
check_uart_input:
    PUSH {R4, R5, LR}
    LDR R4, [R1]
    AND R5, R4, #0xFF
    CMP R5, #'1'
    BEQ reset_timer
    CMP R5, #'2'
    BEQ stop_timer
    CMP R5, #'3'
    BEQ continue_timer
    B check_uart_input_end	// Exit input check

reset_timer:
    MOV R2, #0
    B check_uart_input_end	// Exit input check

stop_timer:
    MOV R3, #0
    B check_uart_input_end	// Exit input check

continue_timer:
    MOV R3, #1
    B check_uart_input_end        // Exit input check

check_uart_input_end:
    POP {R4, R5, LR}
    BX LR

@-------------------------------------------------
@ Delay Function 
@-------------------------------------------------
delay:
    PUSH {R6, LR}
    LDR R6, =1000000
delay_loop:
    SUBS R6, R6, #1
    BNE delay_loop
    POP {R6, LR}
    BX LR

@-------------------------------------------------
@ Send Character to JTAG UART 
@-------------------------------------------------
send_char:
    PUSH {R4, R5, R6, LR}
    LDR R4, =JTAG_UART_BASE
    LDR R5, =0xFFFF0000
send_char_loop:
    LDR R6, [R4, #4]
    AND R6, R6, R5
    CMP R6, #0
    BEQ send_char_loop
    STR R0, [R4]
    POP {R4, R5, R6, LR}
    BX LR

@-------------------------------------------------
@ Print Menu 
@-------------------------------------------------
print_menu:
    PUSH {R4, R5, LR}
    LDR R4, =menu_string
print_menu_loop:
    LDRB R5, [R4], #1
    CMP R5, #0
    BEQ print_menu_end
    MOV R0, R5
    BL send_char
    B print_menu_loop
print_menu_end:
    POP {R4, R5, LR}
    BX LR

@-------------------------------------------------
@ Data Section
@-------------------------------------------------
.section .data
.align 4
menu_string:
    .asciz "1: Reset\n2: Stop\n3: Continue\n"

seven_seg_digits:
    .byte 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F  // 0-9 (common cathode)