; Optimized
[ORG 0x7c00]
xor    ax,ax
mov    ds,ax
mov    es,ax
mov    ss,ax
mov    sp,0x7c00
cld    
mov	   ch,0x5	   ; cx = 0x500, enough to clear rest of screen
mov    di,0x7e00   ; starting at this coord
rep stosb
mov    al, 0x13
int    0x10
jmp    init  
readkey:
  mov    ah,0x10   ; Read expanded keyboard character 
  int    0x16      ; keyoard call
  mov    ah,0x0    ; clear buffer
  ret   
sleep:
  pusha            ; Save register states 
  mov    ah,0x86   ; sleep
  mov    cl,0x2    ; 150,000 microseconds, each integer counts for 75,000 usecs it seems
  xor    dx,dx
  int    0x15      ; int15/ah=86h: sleep in microseconds
  popa             ; Restore register states
  ret   
gameover:
  int 0x19         ; Reboot the system and restart the game.
check_keys:
  mov    ah,0x11   ; Obtain status of the expanded keyboard buffer 
  int    0x16      ; keyboard call
  jne    readkey   ; if there's a key, read the character
  xor    ax,ax     ; clear buffer
  ret   
init:
  mov    si,0x1              ; Start motion is 1 (going right)
  mov    BYTE [0x7e00],0x6   ; Init the length to 6
  mov    ax,0xa000           ; VGA Segment
  mov    es,ax               ; gets it into es  
  gameloop:
    call   check_keys
	test   al,al             ; was there a key?
	je     growth_check      ; no keys, just keep going in same direction
    ; 00 = a - left /-1
    ; 01 = s - down / 0x100
    ; 10 = d - right / 1
    ; 11 = w - up / -0x100
    ; Extract bits 1 and 2 and lookup motion in table above. We do no
    ; validation of the key so other keys will go in random directions
    ; but oh well    
	sar    al,1			; asdw conveniently unique to bits 1 and 2, this shaves off bit 0
	and    ax,0x3		; just keep these 2 bits at the end now, and use as offset to lookup
	mov    si,WORD [eax+eax*1+direction]   ; Get decoded motion from direction lookup
  growth_check:
	mov    di,si
	add    di,WORD [0x7e20]      ; new position based on motion direction
	cmp    WORD [0x7e04],di      ; does new head equal food?
	jne    advance_init          ; if not, don't grow snake and put out new food
    ; Predictable RNG behavior here for food placement
	imul   ax,di,0x6255          ; 25173
	inc    WORD [0x7e00]         ; increment length
	add    ax,0x3619             ; 13849
	and    ax,0xf1f              ; game area mask
	mov    [0x7e04],ax           ; new food value is: food * 25173 + 13849 AND game mask
  ; Advance snake
  advance_init:
	mov    bx,WORD [0x7e00]            ; length into bx
  advance:
    test   bx,bx                       ; keep going until all of length has been processed
	je     boundscheck                 ; if done, do bounds check
	dec    bx                          ; process next peice of length
	mov    ax,WORD [ebx+ebx*1+0x7e20]  ; stored snake motion/direction
    cmp    di,ax                       ; compare it to video coord
	jne    notded                      ; see if new location is on it's own body, skip if not
	call   gameover
  notded:
	mov    WORD [ebx+ebx*1+0x7e22],ax  ; store body part in array
    jmp    advance                     ; and go to next body part
  ; See if snake got out of bounds
  boundscheck:
	mov    ax,si               ; get location
	add    ax,WORD [0x7e20]    ; add stored coordinate
	test   ax,0xf0e0           ; test with bounds at end of screen
	mov    [0x7e20],ax         ; put processed value back into memory
	je     inbounds            ; if equal, in bounds
	call   gameover            ; otherwise, gameover
  inbounds:
	call   clear_screen
	; Draw the food
    movsx  eax,WORD [0x7e04]   ; Food location
	push   dx
	push   dx
	push   word 0x9            ; Push Blue Apple as argument
	push   ax                  ; Push food location as argument
	push   ax                  ; Just for stack adjustment
	call   draw_cell
  drawsnake:
    ; Loop to draw rest of snake
	add    sp,0x0a             ; Adjust stack
	cmp    WORD [0x7e00],bx    ; Has bx reached length?
	jle    snakedrawn          ; then done drawing
	push   ax
	push   ax
	movsx  eax,WORD [ebx+ebx*1+0x7e20] ; Get stored body part
  push   dword 0xf                   ; Body part is white, push that to stack
	inc    bx                  ; next body part
	push   ax                  ; location of body part
	push   ax                  ; Just for stack adjustment
	call   draw_cell           ; draw it
	jmp    drawsnake           ; draw next part
  snakedrawn:
	call   sleep
	jmp    gameloop
clear_screen:
  pusha  
  mov    ch,0xc8         ; 320 * 160
  xor    di,di           ; init corner of screen
  mov    al,0x14         ; grey
  rep stosb 
  popa   
  ret   
draw_cell:
  ; Requires argument of coordinate and color prepopulated in stack
  pushad 
  mov    bp,sp
  mov    bx,0xa                ; Cell size (10)
draw_line:
  dec    bx                    ; decrement Y counter
  ; Calculate intiial VGA X offset into di
  mov    ax,WORD [bp+0x24]     ; load X coord into al, Y coord into ah
  mov    dl,ah                 ; load Y coord into dl
  mov    cl,0xa                ; cx will have cell size
  mul    cl                    ; mul X coord by 10, store in ax
  mov    di,ax                 ; store result into di
  mov    al,dl                 ; load Y coord into dl?
  mul    cl                    ; mul by 10
  add    ax,bx                 ; add on current Y counter
  mov    cx,0x140              ; Get X resolution into cx
  mul    cx                    ; multiply by X resolution
  add    di,ax                 ; add to video memory coord
  ; write a row of pixels of the given color
  mov    cx,0xa                ; so 10 goes into cx
  mov    al,BYTE [bp+0x26]     ; Cell Color
  rep stosb                    ; draw it
  cmp    bx,0x0                ; is Y counter finished?
  jne    draw_line             ; If not, keep going
  popad   
  ret   

; Data lookup table, 4 16-bit values: -1(left), 256(down), 1(right), -256(up)
direction:
  db 0xff, 0xff, 0x00, 0x01, 0x01, 0x00, 0x00, 0xff

;BIOS sig and padding
times 510-($-$$) db 0
dw 0xAA55
