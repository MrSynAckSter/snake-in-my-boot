# Snake in my Boot

An implementation of Snake written in bare-metal / BIOS x86 assembly and C that
fits into an MBR bootloader.

![A screenshot of the game running in QEMU](https://raw.githubusercontent.com/w-shackleton/snake-in-my-boot/master/demo.png)

## Play

Run `make run` to start the game in QEMU.

## Design

*Check `References` for guides I used to write this*

Boot starts in `boot.asm` which sets up enough registers for C to be able to
run. This includes zeroing-out the BSS data segment created by GCC.

The "business logic" is all in C, with utility functions written in assembly.
The utility functions read the keyboard and draw the screen, both of which
require either interrupts or segments which GCC can't natively perform.

## Why not use inline asm?

I didn't want to.

## Why not write everything in asm?

I wanted to learn about how C interacts with assembly, how they are linked
together, and what bare-metal C looks like in x86.

# XlogicX Notes Below #
I forked this project because I was intrigued that someone wrote a boot sector game in c instead of assembly. I wanted to dissemble the compiled game and see how the code was generated (snake.asm). I think this was of interest of the original author as well; they did the project in c as an educational process to learn more about how it gets compiled.

My next goal after getting some assembly that I could actually assemble with nasm (not trivial actually) was to see if there was any of it that could be optimized (snake2.asm). I said the first part isn't trivial not just because of some objdump syntax that needed to be converted, but that there is also an implicit data area of the game that is instead dissembled into instructions. Once the code is good, actually assembling with nasm is super simple, no make file needed, just:
```bash
nasm -f bin snake2.asm -o snake2
```

It turns out that there were MASSIVE opportunities for optimization. In this process, my main goal was to try to stay true to the original games design and algorithms, this is because the goal was to optimize what the compiler did, not the author. I made one exception to the gameover sequence, instead of shutting the whole computer down after losing, I just reset it instead (this is a common design choice with us boot sector game programmers).

Before getting into the details, let's talk about the numbers. A boot sector game is a 512 byte image; it can be no larger. The original game compiles to 468 bytes, which isn't terrible, as it gives plenty of room to spare. That said, with some mostly simple optimizations, I was able to get it down to 290 bytes (shaving off 178 bytes of crap). This means that nearly 40% of the program that c created was unnecessary garbage. Quite a claim.

## Optimizations ##

### 32 bit to 16 bit Registers ###
The first optimization to discuss is a mostly simple one, it's a situation that could have possibly been avoided with the right nasm and gcc calls in the original makefile. I noticed that the make file has some 'nasm -f elf32' in it, when I usually do 'nasm -f bin.' I did see -m16 for gcc, which is important. I say this because it appears that the make process took every chance it could to use full 32 bit registers. The problem with this is how the machine-code is encoded in 16-bit mode. Generally, Whether using 32 bit or 16 bit registers, the encoding for the machine instruction is the same (not so for 8 bit). When in 32 bit mode, if you wanted to us a 16 bit register instead, you need to encode a 1 byte override prefix of 0x66. If in 16 bit mode, you need to use that prefix to get 32 bit registers. So, this means that the 0x66 byte is littered all over our output program, and we don't even need the full 32 bit registers! So a major optimization is to convert those instructions to the 16 bit counterparts. Below are some of the examples:
```assembly
mov    esp,0x7c00
mov    sp,0x7c00
````
```assembly
mov    ebp,esp
mov    bp,sp
````
```assembly
mov    ebx,0xa
mov    bx,0xa
````
```assembly
mov    eax,DWORD [ebp+0x24]
mov    ax,WORD [bp+0x24]
````
```assembly
mov    edi,eax
mov    di,ax
````
```assembly
mov    ecx,0x140
mov    cx,0x140
````
```assembly
mov    ecx,0xa
mov    cx,0xa
````
```assembly
mov    esi,0x1
mov    si,0x1
````
```assembly
and    eax,0x3
and    ax,0x3
````
```assembly
mov    edi,esi
mov    di,si
````
```assembly
add    edi,DWORD [0x7e20]
add    di,WORD [0x7e20]
````
```assembly
mov    ebx,DWORD [0x7e00]
mov    bx,WORD [0x7e00]
````
```assembly
test   ebx,ebx
test   bx,bx
````
```assembly
dec    ebx
dec    bx
````
```assembly
mov    eax,esi
add    eax,DWORD [0x7e20]
test   eax,0xf0e0
	mov    ax,si
	add    ax,WORD [0x7e20]
	test   ax,0xf0e0 
````
```assembly
push   edx
push   edx
push   dword 0x9
push   eax
	push   dx
	push   dx
	push   word 0x9
	push   ax
	push   ax  
````
```assembly
add    esp,0x10
add    sp,0x0a
````
```assembly
push   eax
push   eax
movsx  eax,WORD [ebx+ebx*1+0x7e20]
push   dword 0xf
inc    ebx
push   eax
	push   ax
	push   ax
	movsx  eax,WORD [ebx+ebx*1+0x7e20]
        push   dword 0xf
	inc    bx
	push   ax
	push   ax
````

### 32 bit to 16 bit Pointers ###
Similar to the above optimization, but for pointer, not register
```assembly
mov    DWORD [0x7e00],0x6
mov    BYTE [0x7e00],0x6
````
```assembly
cmp    DWORD [0x7e00],ebx
cmp    WORD [0x7e00],bx
````

### Immediate operand bloat ###
Say you have a 32 or 16 bit register that you know your program is only going to use a specific 8 bytes of, and you want to move an immediate (specific) value into it. If it's an 8 bit value, just use the 8 bit register. Doing something like 'mov eax, 1' requires 4 whole bytes to encode '1'. A better alternative would be 'mov al, 1'. Below are some examples of this conversion that don't break the functionality of the game:

```assembly
mov    ecx,0xa
mov    cl,0xa
```
```assembly
mov    cx,0x2
mov    cl,0x2
```
```assembly
mov    cx,0xc800
mov    ch,0xc8
```

### Just Don't Need ###
There were some instructions that I was able to get rid of entirely; for whatever reason, they did nothing useful for the game other than add bytes:
```assembly
mov    ah,0x0
```

These two instructions below were seen twice like this in the game
```assembly
mov    eax,0xa000
mov    es,ax
```

```assembly
mov    DWORD [ebp-0x1c],eax
```
```assembly
mov    eax,DWORD [ebp-0x1c]
```

### Stack Frame ###
It's nice to have proper stack handling and stack frame setups, especially when playing with other functions and libraries, but not at all a thing that we need in a boot sector game. I was able to delete all of the below lines of code with no hit to how the game functioned; this code was just not needed:
```assembly
lea    ecx,[esp+0x4]
and    esp,0xfffffff0 
push   DWORD [ecx-0x4]
push   ebp 
mov    ebp,esp
push   edi
push   esi
push   ebx
push   ecx
sub    esp,0x18
```

Twice:
```assembly
xor    ax,ax
mov    es,ax
```

```assembly
mov    esp,ebp
```

### The XOR 'trick' ###
As a known optimization, moving an immediate zero into a register takes bytes, as the immediate encoding below would take 4 whole bytes just to encode zero. The XOR trick is very well known instead:
```assembly
mov    eax,0x0
xor    ax,ax
```
A lot of us in the boot sector gaming community get extra squirly when clearing ah and use
```assembly
cbw
```
This trick clears ah to 0 when al is below 128, otherwise it sets ah to all 1's. This insctruction only takes 1 byte to encode. Sound to obscure? Clearing ah to 0 is more common in boot sector gaming, as it is where colors are held in textmode, and cldearing ah sets a black background.

### Better GameOver ###
Replaced Shutdown (gameover) routine with just an int 0x19 reboot. Though this shaves some bytes, it's not why I did it. I just found it irritating that the game went through a 'complex' and proper shutdown routine when a simple reboot is much more convenient for the gamer. This is the only functionality exception that I took with this game.
```assembly
mov    ax,0x5301
xor    bx,bx
int    0x15 
mov    ax,0x5307
mov    bx,0x1
mov    cx,0x3
int    0x15
```

### RET, not RETF###
Converted 5 retf instructions to ret, not a size optimization, but we definitely don't need far returns

### 16 bit PUSHA/POPA when possible ###
Converted 2 pushad/popad instructions to pusha/popa, again, to remove those 0x66 prefix bytes. This wasn't done globally throughout the game, as this does affect the stack alignment, and can mess up the game if not handled carefully. In fact, the 32 bit register push's that I converted weren't done naively, I had to adjust some stack variable addresses to keep aligned.

### Good Enough ###
Use 'Good Enough' Value in upper byte of 16-bit register. There's a routine that starts at a coordinate just below the playable game area and clears the rest of the screen black. The exact amount of 'pixels' that we need cleared is 0x424. But we could just as easily do 0x500 and clear past the viewable area with no noticeable differences to the player. If we do that, we can just write 0x5 to the upper byte of cx (ch). This saves a byte due to the immediate encoding of a byte instead of a word.
```assembly
mov    cx,0x424
mov    ch,0x5
```

### Rearrange Subs ###
Moved subroutines around for near calls, instead of full dword addresses. In the worst case we could have converted the dword calls to word calls. But the goal is always to get a relative call to somewhere less than 127 bytes away, so you can just use a byte. So I removed 8 'call dword' instructions and moved the following subroutines (names from my asm version):
	readkey
	check_keys
	sleep
	draw_cell+draw_line (moved near end as they were called near end)
	clear_screen (same situation as draw_cell)
