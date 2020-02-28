; Assembly source version of game, mostly true to original in all ways possible, based on objdump disasembly. So, unoptimized

[ORG 0x7c00]
	xor    ax,ax
	mov    ds,ax
	mov    es,ax
	mov    ss,ax
	mov    esp,0x7c00
	jmp    0:sub13
sub13:
	cld    
	mov    cx,0x424
	mov    di,0x7e00
	rep stosb
	mov    ah,0x0
	mov    al,0x13
	int    0x10
	call   dword subce
	cli    
	hlt    
	xchg   eax,eax
	xchg   eax,eax
	xchg   eax,eax
sub30:
	mov    ah,0x11
	int    0x16
	jne    sub3d
	mov    eax,0x0
	retf   
sub3d:
	mov    ah,0x10
	int    0x16
	mov    ah,0x0
	retf   
sub44:
	pushad  
	mov    ah,0x86
	mov    cx,0x2
	xor    dx,dx
	int    0x15
	popad   
	retf   
sub52:
	pushad 
	mov    ebp,esp
	mov    eax,0xa000
	mov    es,ax
	mov    ebx,0xa
sub65:
	dec    bx
	mov    eax,DWORD [ds:ebp+0x24]
	mov    dl,ah
	mov    ecx,0xa
	mul    cl
	mov    edi,eax
	mov    al,dl
	mul    cl
	add    ax,bx
	mov    ecx,0x140
	mul    cx
	add    di,ax
	mov    ecx,0xa
	mov    al,BYTE [ds:ebp+0x28]
	rep stosb
	cmp    bx,0x0
	jne    sub65
	xor    ax,ax
	mov    es,ax
	mov    esp,ebp
	popad   
	retf   
suba5:
	pushad  
	mov    ax,0xa000
	mov    es,ax
	mov    cx,0xc800
	xor    di,di
	mov    al,0x14
	rep stosb 
	xor    ax,ax
	mov    es,ax
	popad   
	retf   
subbc:
	mov    ax,0x5301
	xor    bx,bx
	int    0x15 
	mov    ax,0x5307
	mov    bx,0x1
	mov    cx,0x3
	int    0x15
subce:
	lea    ecx,[esp+0x4]
	and    esp,0xfffffff0 
	push   DWORD [ecx-0x4]
	push   ebp 
	mov    ebp,esp
	push   edi
	push   esi
	push   ebx
	push   ecx
	mov    esi,0x1
	sub    esp,0x18
	mov    DWORD [0x7e00],0x6
subfd:
	call   dword sub30
	test   al,al
	je     sub115
	sar    al,1
	and    eax,0x3
	mov    si,WORD [eax+eax*1+datastuff]
sub115:
	mov    edi,esi
	add    edi,DWORD [0x7e20]
	cmp    WORD [0x7e04],di
	jne    sub135
	imul   ax,di,0x6255
	inc    DWORD [0x7e00]
	add    ax,0x3619
	and    ax,0xf1f
	mov    [0x7e04],ax
sub135:
	mov    ebx,DWORD [0x7e00]
sub13a:
  test   ebx,ebx
	je     sub167
	dec    ebx
	mov    ax,WORD [ebx+ebx*1+0x7e20]
  cmp    di,ax
	jne    sub15d
	mov    DWORD [ebp-0x1c],eax
	call   dword subbc
	mov    eax,DWORD [ebp-0x1c]
sub15d:
	mov    WORD [ebx+ebx*1+0x7e22],ax
  jmp    sub13a
sub167:
	mov    eax,esi
	add    eax,DWORD [0x7e20]
	test   eax,0xf0e0
	mov    [0x7e20],ax
	je     sub180
	call   dword subbc
sub180:
	call   dword suba5
	movsx  eax,WORD [0x7e04]
	push   edx
	push   edx
	push   dword 0x9
	push   eax
	call   dword sub52
sub19b:
	add    esp,0x10
	cmp    DWORD [0x7e00],ebx
	jle    sub1c3
	push   eax
	push   eax
	movsx  eax,WORD [ebx+ebx*1+0x7e20]
  push   dword 0xf
	inc    ebx
	push   eax
	call   dword sub52
	jmp    sub19b
sub1c3:
	call   dword sub44
	jmp    subfd
datastuff:
  db 0xff, 0xff, 0x00, 0x01, 0x01, 0x00, 0x00, 0xff, 0x00

;BIOS sig and padding
times 510-($-$$) db 0
dw 0xAA55
