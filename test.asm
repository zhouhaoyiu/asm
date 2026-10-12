DATAS SEGMENT
  Monday    DB 'Monday',13,10,'$'
  Tuesday   DB 'Tuesday',13,10,'$'
  Wednesday DB 'Wednesday',13,10,'$'
  Thursday  DB 'Thursday',13,10,'$'
  Friday    DB 'Friday',13,10,'$'
  Saturday  DB 'Saturday',13,10,'$'
  Sunday    DB 'Sunday',13,10,'$'
  Unknown   DB 'Unknown',13,10,'$'
  Weekdays  DW OFFSET Sunday, OFFSET Monday, OFFSET Tuesday
            DW OFFSET Wednesday, OFFSET Thursday, OFFSET Friday, OFFSET Saturday
  RTCMode   DB 0
DATAS ENDS

STACKS SEGMENT PARA STACK 'STACK'
  DB 256 DUP (?)
STACKS ENDS

CODES SEGMENT
  ASSUME CS:CODES, DS:DATAS, SS:STACKS
  START:
        MOV  AX,DATAS
        MOV  DS,AX

        ; Register B: bit 2 = binary data, bit 1 = 24-hour clock.
        MOV  AL,0Bh
        CALL ReadRTC
        MOV  RTCMode,AL

        MOV  AL,9
        CALL ReadRTC
        CALL DecodeValue
        CALL PrintDecimal
        MOV  DL,'-'
        CALL PrintCharacter

        MOV  AL,8
        CALL ReadRTC
        CALL DecodeValue
        CALL PrintDecimal
        MOV  DL,'-'
        CALL PrintCharacter

        MOV  AL,7
        CALL ReadRTC
        CALL DecodeValue
        CALL PrintDecimal
        MOV  DL,' '
        CALL PrintCharacter

        MOV  AL,4
        CALL ReadRTC
        CALL DecodeHour
        CALL PrintDecimal
        MOV  DL,':'
        CALL PrintCharacter

        MOV  AL,2
        CALL ReadRTC
        CALL DecodeValue
        CALL PrintDecimal
        MOV  DL,' '
        CALL PrintCharacter

        MOV  AL,6
        CALL ReadRTC
        CALL Week

        MOV  AX,4C00h
        INT  21h

ReadRTC PROC
        OUT  70h,AL
        IN   AL,71h
        RET
ReadRTC ENDP

; Convert a BCD or binary RTC field to an unsigned integer in AL.
DecodeValue PROC
        PUSH BX
        PUSH CX
        TEST RTCMode,4
        JNZ  ValueReady
        MOV  BL,AL
        AND  AL,0Fh
        MOV  BH,AL
        MOV  CL,4
        SHR  BL,CL
        MOV  AL,BL
        MOV  BL,10
        MUL  BL
        ADD  AL,BH
ValueReady:
        POP  CX
        POP  BX
        RET
DecodeValue ENDP

; Normalize either RTC hour format to 00..23. In 12-hour mode bit 7 is PM.
DecodeHour PROC
        PUSH BX
        MOV  BL,AL
        AND  AL,7Fh
        CALL DecodeValue
        TEST RTCMode,2
        JNZ  HourReady
        CMP  AL,12
        JNE  CheckPM
        SUB  AL,12
CheckPM:
        TEST BL,80h
        JZ   HourReady
        ADD  AL,12
HourReady:
        POP  BX
        RET
DecodeHour ENDP

; Print an unsigned value 0..99 using two decimal digits.
PrintDecimal PROC
        PUSH AX
        PUSH BX
        PUSH DX
        XOR  AH,AH
        MOV  BL,10
        DIV  BL
        MOV  BH,AH
        MOV  DL,AL
        ADD  DL,'0'
        CALL PrintCharacter
        MOV  DL,BH
        ADD  DL,'0'
        CALL PrintCharacter
        POP  DX
        POP  BX
        POP  AX
        RET
PrintDecimal ENDP

PrintCharacter PROC
        MOV  AH,2
        INT  21h
        RET
PrintCharacter ENDP

; DS12887 convention: Sunday = 1, ... Saturday = 7 in both data modes.
Week PROC
        PUSH BX
        LEA  DX,Unknown
        CMP  AL,1
        JB   PrintWeek
        CMP  AL,7
        JA   PrintWeek
        DEC  AL
        XOR  AH,AH
        MOV  BX,AX
        SHL  BX,1
        MOV  DX,Weekdays[BX]
PrintWeek:
        MOV  AH,9
        INT  21h
        POP  BX
        RET
Week ENDP

CODES ENDS
END START
