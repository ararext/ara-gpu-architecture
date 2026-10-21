; Dense chain of read-after-write dependencies, built to break an
; unprotected pipeline. Expected final: R0=7 R1=21 R2=14 R3=27
MOVI R0, 5
MOVI R0, 7          ; WAW on R0: the younger value (7) must win
ADD  R1, R0, R0     ; R1 = 14   (R0: distance 1 from 2nd MOVI)
ADD  R1, R1, R0     ; R1 = 21   (R1 distance 1, R0 distance 2)
SUB  R2, R1, R0     ; R2 = 14   (R1 distance 1)
XOR  R3, R2, R1     ; R3 = 27   (R2 distance 1, R1 distance 2)
HALT
