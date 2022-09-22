DATAS SEGMENT
  Monday    DB 'Monday',13,10,'$'
  Tuesday   DB 'Tuesday',13,10,'$'
  Wednesday DB 'Wednesday',13,10,'$'
  Thursday  DB 'Thursday',13,10,'$'
  Friday    DB 'Friday ',13,10,'$'
  Saturday  DB 'Saturday',13,10,'$'
  Sunday    DB 'Sunday',13,10,'$'
DATAS ENDS
 
STACKS SEGMENT
  ;
STACKS ENDS
 
CODES SEGMENT
  
  START:
        MOV  AX,DATAS
        MOV  DS,AX
    
        MOV  al,9
        OUT  70h,al
        IN   al,71h
        CALL BCD
    
        MOV  dl,45
        MOV  ah,2
        INT  21h
   
        MOV  al,8
        OUT  70h,al
        IN   al,71h
        CALL BCD
        MOV  dl,45
        MOV  ah,2
        INT  21h
    
        MOV  al,7
        OUT  70h,al
        IN   al,71h
        CALL BCD
     
        MOV  dl,32
        MOV  ah,2
        INT  21h
    
        MOV  al,4
        OUT  70h,al
        IN   al,71h
        CALL BCD
    
        MOV  dl,58
        MOV  ah,2
        INT  21h
    
        MOV  al,2
        OUT  70h,al
        IN   al,71h
        CALL BCD
    
        MOV  dl,32
        MOV  ah,2
        INT  21h
    
        MOV  al,6
        OUT  70h,al
        IN   al,71h
        AND  al,15
        CALL week
  
        MOV  AH,4CH
        INT  21H
    
BCD proc
        PUSH bx
        PUSH cx
     
        MOV  bl,al
        ROL  bl,1
        ROL  bl,1
        ROL  bl,1
        ROL  bl,1
        AND  bl,15
        MOV  dl,bl
        MOV  bl,al
        ADD  dl,48
        MOV  ah,2
     
        INT  21h
        AND  bl,15
        MOV  dl,bl
        ADD  dl,48
        MOV  ah,2
        INT  21h
        POP  cx
        POP  bx
     
        ret
bcd endp
 
week proc
        CMP  al,1
        JNE  l1
        LEA  DX,Monday
        MOV  AH,9
        INT  21H
  l1:   
        CMP  al,2
        JNE  l2
        LEA  DX,Tuesday
        MOV  AH,9
        INT  21H
  l2:   
        CMP  al,3
        JNE  l3
        LEA  DX,Wednesday
        MOV  AH,9
        INT  21H
  l3:   
        CMP  al,4
        JNE  l4
        LEA  DX,Thursday
        MOV  AH,9
        INT  21H
  l4:   
        CMP  al,6
        JNE  l6
        LEA  DX,Friday
        MOV  AH,9
        INT  21H
  l6:   
        CMP  al,5
        JNE  l5
        LEA  DX,Saturday
        MOV  AH,9
        INT  21H
  l5:   
        CMP  al,7
        JNE  l7
        LEA  DX,Sunday
        MOV  AH,9
        INT  21H
  l7:   
        ret
week endp
     
CODES ENDS
    END START
