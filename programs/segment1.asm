; The Segment 1 test program, now in readable form.
MOVI R0, 10
MOVI R1, 5
ADD  R2, R0, R1     ; 15
SUB  R3, R0, R1     ; 5
MUL  R2, R0, R1     ; overwrites R2 with 50
HALT
