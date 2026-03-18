; =====================================================================
; ASCII Mandelbrot Fractal
; Target: Custom 68K-MON Hardware
; 
; Assembles to RAM at $010100
; Uses Fixed-Point 4.12 Arithmetic to avoid FPU requirement
;
; Utilizes the 68K-MON absolute API vectors starting at $0400.
; =====================================================================

    ORG $010100

; Monitor API Vectors
PUTCHAR     EQU $0406       ; Expects char in D0.B
EXIT_PROG   EQU $041E       ; Clean exit back to prompt

START:
    movem.l D0-D7/A2-A3, -(SP)  ; Save registers (good practice)

    move.w  #-12, D7            ; Y = -12
.loop_y:
    move.w  #-39, D6            ; X = -39
.loop_x:

    ; 30 CA = X * .0458  (4.12 Fixed point -> 0.0458 * 4096 = 188)
    move.w  D6, D0
    muls    #188, D0
    move.l  D0, A2              ; Save CA in A2
    
    ; 40 CB = Y * .08333 (4.12 Fixed point -> 0.08333 * 4096 = 341)
    move.w  D7, D0
    muls    #341, D0
    move.l  D0, A3              ; Save CB in A3

    ; 50 A=CA
    move.l  A2, D4              ; D4 will be A
    ; 60 B=CB
    move.l  A3, D3              ; D3 will be B

    ; 70 FOR I = 0 TO 15
    moveq   #0, D5              ; D5 will be I
    
.loop_i:
    ; Calculate A*A
    move.w  D4, D1
    muls    D1, D1              ; A * A
    asr.l   #8, D1              ; 68000 max immediate shift is 8...
    asr.l   #4, D1              ; ...so we shift 8 then 4 to get 12! (Restores 4.12 format)
    
    ; Calculate B*B
    move.w  D3, D2
    muls    D2, D2              ; B * B
    asr.l   #8, D2              ; Shift right 12 total
    asr.l   #4, D2
    
    ; 110 IF (A*A + B*B) > 4 GOTO 200
    move.l  D1, D0
    add.l   D2, D0              ; A*A + B*B
    cmp.l   #16384, D0          ; 4.0 in 4.12 format is 16384 ($4000)
    bgt     .bailout
    
    ; 90 B = 2*A*B + CB
    move.w  D4, D0              ; Copy A
    muls    D3, D0              ; A * B
    asr.l   #8, D0              ; Right shift 11 total divides by 2048
    asr.l   #3, D0              ; (effectively doing *2 and /4096 in one step!)
    add.l   A3, D0              ; + CB
    move.l  D0, -(SP)           ; Save new B onto stack temporarily
    
    ; 80 T = A*A - B*B + CA
    ; 100 A = T
    move.l  D1, D4              ; Move A*A into A
    sub.l   D2, D4              ; - B*B
    add.l   A2, D4              ; + CA
    
    ; Apply new B from stack
    move.l  (SP)+, D3           
    
    ; 120 NEXT I
    addq.w  #1, D5              ; I++
    cmp.w   #16, D5
    blt     .loop_i             ; Loop while I < 16
    
.bailout:
    cmp.w   #16, D5             ; Did we finish all 16 iterations?
    beq     .print_space        ; 130 PRINT " ";
    
    ; 200 IF I>9 THEN I=I+7
    move.w  D5, D0
    cmp.w   #9, D0
    ble     .print_digit
    addq.w  #7, D0              ; Adjust to print A, B, C, D, E, F
.print_digit:
    ; 205 PRINT CHR$(48+I);
    add.w   #'0', D0            ; Convert to ASCII
    bra     .do_print
    
.print_space:
    move.w  #' ', D0
.do_print:
    jsr     PUTCHAR             ; Hit the API jump table to print the char
    
    ; 210 NEXT X
    addq.w  #1, D6
    cmp.w   #39, D6
    ble     .loop_x
    
    ; 220 PRINT
    move.w  #$0D, D0            ; CR
    jsr     PUTCHAR
    move.w  #$0A, D0            ; LF
    jsr     PUTCHAR
    
    ; 230 NEXT Y
    addq.w  #1, D7
    cmp.w   #12, D7
    ble     .loop_y

    ; Done! Safely return to the monitor prompt.
    movem.l (SP)+, D0-D7/A2-A3  ; Restore registers
    jmp     EXIT_PROG           ; Using the proper Monitor API Exit Vector!

    END     START
*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
