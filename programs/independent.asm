; No dependency closer than 3 instructions, so even an unprotected
; pipeline gets this right. Expected final: R0=9 R1=3 R2=1 R3=1
MOVI R0, 6
MOVI R1, 3
MOVI R2, 2
MOVI R3, 9
ADD  R0, R0, R1     ; 6+3 = 9
SUB  R3, R1, R2     ; 3-2 = 1  (differs from MOVI value 9, so a lost write shows up)
XOR  R2, R1, R2     ; 3^2 = 1
HALT
