;------------------------------------------------------
GameCoord TYPEDEF BYTE
;
; References a Tile on the gameboard by its Row and Column
;    (coordinate system inspired by the games like BattleShip and Chess)
;
;    Tile Formula: (Col#) + (16*Row#), where
;       Row# is an integer in the range 1-6, and
;       Col# is an integer in the range 0Ah-0Fh
;------------------------------------------------------


;------------------------------------------------------
BoundingRect STRUCT
;
; Defines a Rectangle, used its upperleft and bottomright corners
;
; Pt1: Upper-Left Corner
; Pt2: Bottom-Right Corner
;------------------------------------------------------
    Pt1 GameCoord ?
    Pt2 GameCoord ?
BoundingRect ENDS


;------------------------------------------------------
mOutputTraceMsg MACRO cntxt:=<Not Provided>
  LOCAL msg
; Outputs a debug message
; Receives: cntxt = Any extra info the caller wants to print
; Returns: Nothing.
;------------------------------------------------------
  .data
    msg BYTE "Tracing: Context: ", 22h, "&cntxt&", 22h, 0Dh, 0Ah, 0h
  .code
    push edx
    mov edx, OFFSET msg
    CALL WriteString
    CALL Crlf
    pop edx
ENDM

;------------------------------------------------------
mComputeCoord MACRO col:REQ, row:REQ
;
; Receives:
;    col = The Column
;    row = The Row
; Returns:
;    eax = col#+(16*Row#) (the GameCoord)
; Avoid passing EAX as the argument.
;------------------------------------------------------
    xor eax, eax
    movzx eax, row
    shl eax, 4
    or al, col
ENDM

;------------------------------------------------------
mSplitCoord MACRO gmCrd:REQ
;
; Receives: a GameCoord: col#+(16*Row#)
; Returns:
;    al = Col#,
;    ah = Row#
; Avoid passing EAX as the argument.
;------------------------------------------------------
    xor eax, eax
    movzx ax, gmCrd
    shl ax, 4
    shr al, 4
ENDM

;------------------------------------------------------
mComputeColorAttr MACRO colorF:REQ, colorB:REQ
;
; Receives: the foreground color and the background color.
; Returns: al = the ColorAttribute defined by:
;    fgColor+16*bgColor.
; Avoid passing EAX as the arguments.
;------------------------------------------------------
      xor eax, eax
      mov al, colorB
      shl al, 4
      or al, colorF
ENDM

;------------------------------------------------------
mSplitColorAttr MACRO ColorAttr:REQ
;
; Receives: a ColorAttribute: fgColor+16*bgColor.
; Returns:
;    al = foreground color,
;    ah = background color
; Avoid passing EAX as the argument.
;------------------------------------------------------
    movzx eax, ColorAttr
    shl ax, 4
    shr al, 4
ENDM

;------------------------------------------------------
mSetTextColor MACRO colorF:=<white>, colorB:=<black>
;
; Receives:
;    colorF = desired foreground color if provided, otherwise white.
;    colorB = desired background color if provided, otherwise black.
; Returns: Nothing.
;------------------------------------------------------
    push eax
    INVOKE SetTextColor, colorF, colorB
    pop eax
ENDM

;------------------------------------------------------
mAttrSetTextColor MACRO colorAttr:REQ
;
; Receives: a ColorAttribute: fgColor+16*bgColor.
; Returns: Nothing.
; Avoid passing EAX as the argument.
;------------------------------------------------------
    push eax
    push ebx

    xor ebx, ebx
    mSplitColorAttr colorAttr
    shl al, 4
    shr ax, 4
    mov bx, ax
    mSetTextColor bl, bh
    xor ebx, ebx

    pop ebx
    pop eax
ENDM


;------------------------------------------------------
coordInBndngRect PROC USES ebx ecx edx, gmCrd:GameCoord, brAddr:DWORD
;
; Checks if the GameCoord pointed by coordAddr is within
;    the BoundingRect pointed by brAddr.
; Receives: the OFFSETs of the GameCoord (coordAddr)
;    and BoundingRect(brAddr).
; Returns: EAX: 1 if coordAddr is within brAddr, 0 otherwise
; Avoid passing EAX, EBX, ECX, and EDX as arguments.
;------------------------------------------------------
    mSplitCoord (BoundingRect PTR [brAddr]).Pt2 ; al = quotient = col, ah = remainder= row

    mov bh, ah
    mov bl, al

    mSplitCoord (BoundingRect PTR [brAddr]).Pt1 ; al = quotient = col, ah = remainder= row

    mov dh, ah
    mov dl, al

    mSplitCoord gmCrd ; al = quotient = col, ah = remainder = row

; X-Compare:
    cmp al, dl
    je YComp
    jne PtXComp

  YComp:
    cmp ah, dh
    je Yes
    jne No

  PtXComp:
    cmp al, bl
    je PtYComp
    jne No

  PtYComp:
    cmp ah, bh
    je Yes
    jne No

  Yes:
    mov eax, 1
    jmp Endf1

  No:
    mov eax, 0

  Endf1:
    RET
coordInBndngRect ENDP

;------------------------------------------------------
coordToXY PROC USES ebx ecx, gmCrd:GameCoord
  LOCAL row:BYTE, col:BYTE
; Receives: gmCrd = The pointer to the GameCoord
; Returns:
;    al = Col# = X val
;    ah = Row# = Y val
;------------------------------------------------------
;
; Formulas:
; Row# = GameCoord / 16
; Col# = GameCoord mod 16
; X = (Col# - 9) * GridWidth + (Col# - 10) * TileWidth
; Y = Row# + (Row# - 1) * TileHeight
;------------------------------------------------------
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx

    mov cl, 16
    movzx ax, gmCrd
    div cl

    mov row, al
    mov col, ah

    mov al, row
    sub al, 1
    mov bl, TileHeight
    mul bl
    add row, al ; max value dealt with is 16d*0Fh + 6d, which does not exceed 255, so we can disgard ah

    mov al, col
    sub al, 9
    mov bl, GridWidth
    mul bl
    mov cx, ax

    mov al, col
    sub al, 10
    mov bl, TileWidth
    mul bl

    add al, cl ; max value dealt with is 16d*0Fh + 6d, which does not exceed 255, so we can disgard ah
    mov col, al

    xor eax, eax
    
    mov al, col
    mov ah, row

    RET
coordToXY ENDP