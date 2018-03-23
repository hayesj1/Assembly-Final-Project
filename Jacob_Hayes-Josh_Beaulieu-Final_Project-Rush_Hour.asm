INCLUDE \masm32\include\masm32rt.inc
INCLUDE \masm32\procs\textcolors.asm
INCLUDE \masm32\include\Macros.inc
INCLUDE \masm32\include\Irvine32.inc
INCLUDELIB \masm32\lib\Irvine32.lib

INCLUDE util.asm

;------------------------------------------------------
Car STRUCT
;
; Models a Car on the GameBoard,
;    drawn by a uniquely colored and labeled rectangle
;
; Tag: The Car's label and Fill character,
;   labels changed from the standard game for reduce confusion during user input
; Len: The length of the car, in Standard RushHour:
;   2 for small cars, and 3 for big cars
; Color: The Car's Color, which is as close to the standard game as possible
; BndRctPtr: Pointer to the car's BoundingRect, defines
;   the position and orientation of the car(Vertical or Horizontal).
;------------------------------------------------------
    Tag BYTE '?'
    Len BYTE ?
    Color BYTE ?
  ALIGN DWORD
    BndRctPtr DWORD ?
Car ENDS

CarP TYPEDEF PTR Car

initCars PROTO
drawCars PROTO

;------------------------------------------------------
mGetOrientation MACRO bndngRct:REQ
LOCAL HorizontalOrient, InvalidOrient, VerticalOrient, EndGetOrientationM
; gets the orientation, Horizontal or Vertical, of the
;    passed BoundingRect.
; Receives: bndngRct = a BoundingRect struct.
; Returns: eax =
;    0 if the rect is invalid,
;    1 if it is Horizontal, or
;    2 if it is Vertical.
; Avoid passing EAX as the argument.
;------------------------------------------------------
    push ebx

    mSplitCoord bndngRct.Pt1
    mov ebx, eax

    mSplitCoord bndngRct.Pt2

    sub al, bl
    sub ah, bh

    cmp al, ah
    jg HorizontalOrient
    je InvalidOrient
    jl VerticalOrient

  HorizontalOrient:
    mov eax, Horizontal
    jmp EndGetOrientationM

  InvalidOrient:
    mov eax, Invalid
    jmp EndGetOrientationM

  VerticalOrient:
    mov eax, Vertical
    jmp EndGetOrientationM


  EndGetOrientationM:
    pop ebx
ENDM

mSetTextColorGrid MACRO
    mSetTextColor GameGridColorF, GameGridColorB
ENDM

mSetTextColorTile MACRO
    mSetTextColor GameTileColorF, GameTileColorB
ENDM


.data
  ; Number of Tiles along either axis
    GridDim EQU 6

  ; The width in characters of a Tile
    TileWidth EQU 6

  ; The height in lines of a Tile
    TileHeight EQU 3

  ; The thickness of vertical grid lines
  ; Horizontal grid lines are one line thick
    GridWidth EQU 3

  ; Color specification of the grid
    GameGridColorF EQU lightGray
    GameGridColorB EQU Gray

  ; Color specification of UnBlocked Tiles
    GameTileColorF EQU black
    GameTileColorB EQU lightGray

  ; Total possible cars in a game using all cars
    NumCars EQU 16

  ; Number of Cars in play for the setup in use, minus player's car
    NumCarsInPlay EQU 8

  ; Length of the regular cars
    CarLen EQU 2

  ; Length of the big cars
    BigCarLen EQU 3

  ; Column Constants for regular cars
    HorCarCols EQU (CarLen * TileWidth) + ((CarLen -1) * GridWidth)
    VerCarCols EQU TileWidth

  ; Column Constants for big cars
    HorBigCarCols EQU (BigCarLen * TileWidth) + ((BigCarLen -1) * GridWidth)
    VerBigCarCols EQU TileWidth

  ; Row Constants for regular cars
    HorCarRows EQU TileHeight
    VerCarRows EQU (CarLen * TileHeight) + (CarLen -1)

  ; Row Constants for big cars
    HorBigCarRows EQU TileHeight
    VerBigCarRows EQU (BigCarLen * TileHeight) + (BigCarLen -1)

  ; Orientation Constants
    Invalid EQU 0
    Horizontal EQU 1
    Vertical EQU 2

  ; Directional Key Constants
    Up EQU 'w'
    Left EQU  'a'
    Right EQU  'd'
    Down EQU 's'


    selectPrompt BYTE "Enter a Tile Coord (RowCol) ", 0h
    movePrompt BYTE "Press W(Up), (S)Down, (A)Left, or (D)Right to move the selected car ", 0h

    carPositions BYTE 1Dh, 2Dh, 2Eh, 2Fh,
                      3Dh, 4Dh, 4Eh, 4Fh,
                      5Dh, 5Eh, 5Fh, 6Fh, 0h,
                      1Ah, 3Ah, 4Ch, 6Ch

  ALIGN DWORD
    cars Car NumCars DUP(<>)
    selectedCoord GameCoord ?
    playerCar Car <>
    plyrBndRct BoundingRect <3Bh, 3Ch>

.code
main PROC
; Program Start
  ; Init Game
    ; Init Cars
      mov edi, OFFSET cars
      mov esi, OFFSET carPositions
      INVOKE initCars

    ; Init Player's Car
      mov playerCar.Tag, 'X'
      mov playerCar.Len, CarLen
      mov playerCar.Color, lightRed+(16*red)
      mov ax, plyrBndRct
      mov [playerCar.BndRctPtr], eax

    ; Init GameGrid
    DrawScreen:
      CALL drawGameBoard

    ; Init Car Placement
      INVOKE drawCars

  ; Start Game
      mGotoxy GridWidth, (6*TileHeight+8)
  SelectInput:
    ; Get Player's Selection
      mov edx, OFFSET selectPrompt
      CALL WriteString

      CALL ReadHex
      push eax

      mov selectedCoord, al

      mSplitCoord selectedCoord

    ; Validate Selection
      cmp al, 0Fh;
      jg SelectInput
      cmp al, 0Ah
      jl SelectInput

      cmp ah, 06h;
      jg SelectInput
      cmp ah, 01h
      jl SelectInput

      pop eax
      mov edi, OFFSET cars
      mov ecx, NumCars -1
    LGetSelectedCar:
      push eax
      INVOKE coordInBndngRect, selectedCoord, (Car PTR [edi]).BndRctPtr

      cmp eax, 0
      je LGetSelectedCarUpdt
      jmp MoveInput

    LGetSelectedCarUpdt:
      pop eax
      add edi, TYPE Car

    LOOP LGetSelectedCar
    jmp SelectInput

  MoveInput:
  ; Get Player's Move
      mov edx, OFFSET movePrompt
      CALL WriteString

      CALL ReadChar

  ; Validate Move
      cmp al, 0
      je MoveInput

      push eax
      mGetOrientation (BoundingRect PTR [(Car PTR [edi]).BndRctPtr])
      cmp eax, Horizontal
      jg Vert

  ; Hori:
      pop eax
      cmp al, Left
      je MoveCar
      cmp al, Right
      je MoveCar
      jmp MoveInput

    Vert:
      pop eax
      cmp al, Up
      je MoveCar
      cmp al, Down
      je MoveCar
      jmp MoveInput

    MoveCar:
      push eax
      mSplitCoord (BoundingRect PTR [(Car PTR [edi]).BndRctPtr]).Pt1
      mov ebx, eax
      mSplitCoord (BoundingRect PTR [(Car PTR [edi]).BndRctPtr]).Pt2
      mov edx, eax
      pop eax

      cmp al, Up
      je MoveUp
      cmp al, Down
      je MoveDown
      cmp al, Left
      je MoveLeft

  ; MoveRight:
      inc bl
      inc dl
      mComputeCoord bl, bh
      mov (BoundingRect PTR [(Car PTR [edi]).BndRctPtr]).Pt1, al
      mComputeCoord dl, dh
      mov (BoundingRect PTR [(Car PTR [edi]).BndRctPtr]).Pt2, al
      jmp ReDraw

    MoveLeft:
      dec bl
      dec dl
      mComputeCoord bl, bh
      mov (BoundingRect PTR [(Car PTR [edi]).BndRctPtr]).Pt1, al
      mComputeCoord dl, dh
      mov (BoundingRect PTR [(Car PTR [edi]).BndRctPtr]).Pt2, al
      jmp ReDraw

    MoveDown:
      inc bh
      inc dh
      mComputeCoord bl, bh
      mov (BoundingRect PTR [(Car PTR [edi]).BndRctPtr]).Pt1, al
      mComputeCoord dl, dh
      mov (BoundingRect PTR [(Car PTR [edi]).BndRctPtr]).Pt2, al
      jmp ReDraw

    MoveUp:
      dec bh
      dec dh
      mComputeCoord bl, bh
      mov (BoundingRect PTR [(Car PTR [edi]).BndRctPtr]).Pt1, al
      mComputeCoord dl, dh
      mov (BoundingRect PTR [(Car PTR [edi]).BndRctPtr]).Pt2, al

    ReDraw:
      print "Press any key to continue..."
      CALL ReadChar
      CALL Clrscr
      mov edi, OFFSET cars
      jmp DrawScreen

; Program Done
    print "Press any key to continue..."
    CALL ReadChar
    INVOKE ExitProcess, 0

main ENDP

;------------------------------------------------------
initCars PROC USES eax ebx ecx edx esi edi
;
; Receives: EDI = OFFSET of array of Cars
;           ESI = OFFSET of array of Cars' positions
;           plyrCar = the pointer to the player's car
; Returns: nothing.
; Avoid passing EAX as the argument.
;------------------------------------------------------
    mov ecx, NumCars-1 ; don't init player's car
    mov dl, 'G'
    mov bh, gray
    mov bl, black
    push edi

    LInitCars1:
      InitColor:
        mComputeColorAttr bh, bl
          
        cmp al, (lightRed+16*red)
        jne InitCarColor

      InitSkipPlayerCarColor:
        inc bh
        inc bl
        mComputeColorAttr bh, bl

      InitCarColor:
        mov (Car PTR [edi]).Color, al

      InitCarTag:
        mov (Car PTR [edi]).Tag, dl
        jmp InitCarLen

      InitCarLen:
        cmp dl, 52h ; Car 'R' is the first big car
        jl InitSmallCarLen

    ; InitBigCarLen
        mov (Car PTR [edi]).Len, BigCarLen
        jmp LInitCars1Updt

      InitSmallCarLen:
        mov (Car PTR [edi]).Len, CarLen


      LInitCars1Updt:
        inc dl
        inc bh
        inc bl
        add edi, TYPE Car
    LOOP LInitCars1

    pop edi
    CALL initCarsPos

    RET
initCars ENDP

;------------------------------------------------------
initCarsPos PROC USES eax ecx esi edi
;
; Receives: EDI = OFFSET array of Cars
;           ESI = OFFSET of array of Cars' positions
; Returns: nothing.
;------------------------------------------------------
    xor eax, eax
    mov ecx, NumCarsInPlay

    LInitCarsPos:
        mov al, [esi]
        mov ah, [esi+1]

        cmp al, 0h
        je InitBigCarsPos2

        mov (BoundingRect PTR [(Car PTR [edi]).BndRctPtr]).Pt1, al
        mov (BoundingRect PTR [(Car PTR [edi]).BndRctPtr]).Pt2, ah

        add edi, TYPE Car
        add esi, 2
    LOOP LInitCarsPos

    InitBigCarsPos1:
        mov (BoundingRect PTR [(Car PTR [edi]).BndRctPtr]).Pt1, 0h
        mov (BoundingRect PTR [(Car PTR [edi]).BndRctPtr]).Pt2, 0h
        add edi, TYPE Car

    InitBigCarsPos2:
        mov al, (Car PTR [edi]).Tag
        cmp al, 'R'
        jl InitBigCarsPos1

        inc esi

    LInitBigCarsPos:
        mov al, [esi]
        mov ah, [esi+1]

        mov (BoundingRect PTR [(Car PTR [edi]).BndRctPtr]).Pt1, al
        mov (BoundingRect PTR [(Car PTR [edi]).BndRctPtr]).Pt2, ah

        add edi, TYPE Car
        add esi, 2
    LOOP LInitBigCarsPos

    mov ecx, NumCars - NumCarsInPlay - 1
    cmp ecx, 0
    je EndInitCarsPosP

    LInitOtherCars:
        mov (BoundingRect PTR [(Car PTR [edi]).BndRctPtr]).Pt1, 0h
        mov (BoundingRect PTR [(Car PTR [edi]).BndRctPtr]).Pt2, 0h

        add edi, TYPE Car
    LOOP LInitOtherCars

  EndInitCarsPosP:
    RET
initCarsPos ENDP

;------------------------------------------------------
drawGameBoard PROC USES eax ebx ecx
;
; Draws the GameBoard into the terminal
; Receives: nothing.
; Returns: nothing.
;------------------------------------------------------
    mSetTextColorGrid
    mWriteSpace GridWidth
    
    mov al, 'A'
    mov ecx, GridDim

    LDrawGB1:
        mWriteSpace (TileWidth / 2) -1
        CALL WriteChar
        mWriteSpace (TileWidth / 2) + GridWidth
        inc al
    LOOP LDrawGB1

    mSetTextColor
    CALL Crlf

    mov al, '1'
    mov ecx, GridDim
    
    LDrawGB2:
        push ecx
          CALL drawRow
          mSetTextColorGrid
          mWriteSpace ((TileWidth * 6) + (GridWidth * 6) + GridWidth)
          mSetTextColor
        pop ecx

        cmp al, '3'
        jne LDrawGB2Updt
        push eax
          mov ah, (GridWidth * 7) + (TileWidth * 6)
          mov al, (3) + (2 * TileHeight) + 1
          mGotoxy ah, al
          mWrite "--> EXIT"
          add al, 2
          mGotoxy ah, al
        pop eax

      LDrawGB2Updt:
        CALL Crlf
        inc al
    LOOP LDrawGB2
    
    mSetTextColor
    CALL Crlf
    
    RET
drawGameBoard ENDP
  
;------------------------------------------------------
drawRow PROC USES eax ecx
;
; Draws one row of the GameBoard into the terminal
; Receives: al: the label for the row to be drawn
; Returns: nothing.
;------------------------------------------------------
    mov ecx, TileHeight
    LDrawRow:
      push ecx
        mSetTextColorGrid
      pop ecx
      push ecx
        cmp ecx, (TileHeight / 2 + 1)
        jne DrawEmptyLabel

      ; DrawLabel:
          mWriteSpace (GridWidth-1) / 2
          CALL WriteChar
          
          mov ebx, 0
          cmp ebx, (GridWidth - 1)
          je DrawRow
          
          mWriteSpace (GridWidth-1) / 2
          jmp DrawRow

        DrawEmptyLabel:
            mWriteSpace GridWidth

        DrawRow:
          CALL drawInnerRow
          mSetTextColor
          CALL Crlf
      pop ecx
    LOOP LDrawRow

    RET
drawRow ENDP

;------------------------------------------------------
drawInnerRow PROC USES ecx
;
; Draws one line of one row of the GameBoard into
;   the terminal, minus the first vertical grid-line
; Receives: nothing.
; Returns: nothing.
;------------------------------------------------------
    mov ecx, GridDim
    
    LDrawInnerRow:
      push ecx
        mSetTextColorTile
        mWriteSpace TileWidth
      
        mSetTextColorGrid
        mWriteSpace GridWidth
      pop ecx
    LOOP LDrawInnerRow
    
    RET
drawInnerRow ENDP

;------------------------------------------------------
drawCars PROC USES eax ebx ecx edx edi
;
; Draws the cars onto the gameboard
; Receives:
;    EDI = pointer to cars array
; Returns: nothing.
;------------------------------------------------------
    mov ecx, NumCars-1

    LDrawCars1:
      push ecx
      mov bl, (BoundingRect PTR [(Car PTR [edi]).BndRctPtr]).Pt1

      cmp bl, 0h
      je LDrawCarsUpdt

      mGetOrientation (BoundingRect PTR [(Car PTR [edi]).BndRctPtr])
      cmp eax, Horizontal
      je HorOrient

  ; VerOrient:
      xor eax, eax
      xor ebx, ebx
      mov al, (Car PTR [edi]).Len
      mov bl, TileHeight
      mul bl
      mov bl, al
      mov al, (Car PTR [edi]).Len
      sub al, 1
      add bl, al
      mov eax, TileWidth
      jmp DrawCar

    HorOrient:
      xor eax, eax
      xor ebx, ebx
      mov al, (Car PTR [edi]).Len
      mov bl, TileWidth
      mul bl

      push eax
      mov al, (Car PTR [edi]).Len
      sub al, 1
      mov bl, GridWidth
      mul bl

      mov bl, al
      pop eax
      
      add al, bl
      mov ebx, TileHeight

    DrawCar:
      mov ecx, ebx
      mov ebx, eax

      xor eax, eax
      INVOKE coordToXY, (BoundingRect PTR [(Car PTR [edi]).BndRctPtr]).Pt1
      mov dl, (Car PTR [edi]).Tag

      CALL drawCar

    LDrawCarsUpdt:
      add edi, TYPE Car
      pop ecx
  ; LOOP LDrawCars1
      dec ecx
      cmp ecx, 0
      jne LDrawCars1

    RET
drawCars ENDP

;------------------------------------------------------
drawCar PROC USES eax ebx ecx edx
;
; Draws a car on the gameboard
; Receives:
;     AL = Starting X/Col Coord
;     AH = Starting Y/Row Coord
;    EBX = The Width of the car
;    ECX = the Height of the car
;     DL = The car's Tag
; Returns: nothing.
;------------------------------------------------------
    LDrawCar:
        mGotoxy al, ah
        push ecx
        push eax

        mov al, dl
        mov ecx, ebx
        LDrawCar2:
            CALL WriteChar
        LOOP LDrawCar2

        pop eax
        pop ecx
        inc ah
    LOOP LDrawCar

    RET
drawCar ENDP
END main