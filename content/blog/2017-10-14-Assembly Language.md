---
layout: post  
title: Assembly Language  
description: "现在高级语言这么方便、编译器这么牛，还需要掌握汇编语言吗？我认为需要，至少要能看懂，有些对性能要求很高、希望调优的场景下，可能要直接用汇编来实现，如字符串拷贝，等等。而且高级语言借助系统调用的方式，有时也存在局限性，比如有需要开关中断的场景，就必须要借助内联汇编。所以掌握汇编至少不是一件坏事。"
date: 2017-10-14 20:13:35 +0800
tags: ["assembly"]
toc: true
---

处理器是算逻运算、控制操作的执行部件，它只能识别机器指令并执行动作。机器指令是一系列的0、1字符串，本质上对应了总线上的高低电平信号，所以机器语言都是特定于硬件的。

由于0、1字符串很难记忆，用机器语言开发是一个老大难的问题，汇编语言因此被开发出来用于代替机器语言。汇编指令只是机器指令中操作码的助记符，因此汇编语言仍然是机器强相关的，不同的处理器其对应的汇编指令也不同。

**学习汇编语言有助于理解：**

- 程序是如何与操作系统、处理器、bios进行交互的；
- 数据如何在内存中以及外设中表示的；
- 处理器如何访问、执行指令；
- 指令如何访问、处理数据；
- 程序如何访问外设；

**其他使用汇编语言的优势：**

- 消耗更少的内存和处理器执行时间；
- 允许以更简单的方式来完成硬件特定的复杂作业；
- 适用于时间敏感的作业；
- 适用于编写中断服务程序和内存驻留程序；

### 1.1 PC硬件的基本特征

机器指令是0、1字符串，分别表示ON、OFF，对应数字信号的高低电平。机器中的最低存储单位是bit，通常8bit构成一个byte，为了对数据传输过程中传输数据的有效性进行检查，通常会在数据byte发送之后再追加一个奇偶校验bit。

- 奇校验：保证8bit数据+1bit校验位中的1的个数为奇数；
- 偶校验：保证8bit数据+1bit校验位中的1的个数为偶数；

发送方、接收方遵循相同的奇偶校验规则，如果接收方收到数据后发现奇偶校验不正确，则表示可能硬件出错，或者出现了电平扰动。

**处理器支持如下数据尺寸：**

|:---|:------|
|Word|2 bytes|
|Doubleword|4 bytes|
|Quadword|8 bytes|
|Paragraph|16 bytes|
|Kilobyte|2^10 bytes|
|Megabyte|2^20 bytes|

**二进制 & 十六进制系统：**

二进制天然适用于计算机计算领域，0、1刚好代表数字电路中的高低电平；而十六进制是用于对比较长的二进制数值进行更加优雅地简写，使我们表示起来更加清晰、简单。

二进制、十六进制的相关运算，特别是涉及到原码、反码、补码、移码的运算，需要重点了解下，建议参考《计算机组成原理》相关章节。

**访问内存中的数据：**

处理器控制指令执行的过程可以简化为”取指令-指令移码-指令执行“的循环体，一个”取指令-指令译码-指令执行“周期称之为一个机器周期。

- 取指周期：根据CS、IP从内存指定位置取指令，并存储到指令寄存器IR；
- 译码周期：根据IR中的指令，分析出操作码OP、操作数或操作数地址；
- 执行周期：根据分析出的OP、操作数或操作地址信息执行相应的动作；

Intel架构的处理器在内存中存储时是采用的小端字节序，意味着一个多字节数值的低字节部分将在低地址存储，高字节部分将在高地址存储，但是在处理器寄存器中存储时低字节部分就在低字节，高字节部分就在高字节，所以在处理器寄存器、内存之间存储、加载数据时需要做字节序方面的转换。

以处理器寄存器中数值0x1234为例，现在要将其存储到内存中，处理器先将0x34存储到内存低地址，然后再见0x12存储到内存高地址；假如内存中有数据0xabcd，现在要将其加载到处理器寄存器中，加载时也会做对应的处理，将0xab放在寄存器高位，将0xcd放在寄存器低位。

指令中的操作数地址，又有多种不同的寻址方式，立即数寻址、直接寻址、间接寻址、寄存器寻址等，这里后面会做相应的介绍。

### 1.2 开发环境配置

汇编指令特定于处理器的，因此不同的处理器系列、型号对应的汇编指令可能也会有差异，这里使用的是Intel-32架构的处理器，使用汇编器NASM进行汇编操作，其他可选的汇编器还有MASM、TASM、GAS等。

### 1.3 基本语法

汇编程序通常包括3个节，分别是data、bss、text节：

- data，用于声明初始化的变量和常量；
- bss，用于声明未初始化的变量，这部分不会出现在编译后的程序中；
- text，用于保存程序指令；

text节中必须包括"**global ${entry}**"声明，${entry}是程序入口，通常定义未_start，见文生义嘛。

汇编程序中的注释均以";"开头，直到所在行结束。

汇编语言程序包括3种不同类型的语句：

- 可执行汇编指令；
- 传递给汇编器的指令或伪操作；
- 宏；

汇编语言语句遵循如下结构：
```nasm
[标识] 助记符 [操作数] [;注释]
```

>[]内部的部分是可选的，尤其是标识和注释部分，根据汇编指令的不同，有无操作数、操作数个数、操作数类型等均有所不同。汇编指令中包括了操作码和操作数相关信息，这里的助记符其实就是操作码的符号表示。

下面是应用了上述基本语法的示例程序：

***hello.asm***

```nasm
section	.text
   global _start     ;must be declared for linker (ld)
	
_start:	            ;tells linker entry point
   mov	edx,len     ;message length
   mov	ecx,msg     ;message to write
   mov	ebx,1       ;file descriptor (stdout)
   mov	eax,4       ;system call number (sys_write)
   int	0x80        ;call kernel
	
   mov	eax,1       ;system call number (sys_exit)
   int	0x80        ;call kernel

section	.data
msg db 'Hello, world!', 0xa  ;string to be printed
len equ $ - msg     ;length of the string
```

在Linux平台下由汇编文件构建可执行程序包括如下两个步骤：

- 汇编，nasm -f elf -o hello.o hello.asm
- 连接，ld -m elf_i386 -e _start -o hello hello.o

构建完成，即可在命令行执行./hello来进行测试。

### 1.4 内存分段

前面一节介绍了汇编语言中的section（节），这些节也代表着各种各样的内存segment（段）。将前面示例代码hello.asm中的section关键字用segment代替，依然可以用相同的方法构建成功并得到相同的测试结果。

汇编语言中常见的segment（段）包括：

- data segment，数据段代表了data section和bss section。其中data section用于存储初始化后的全局变量和全局变量；bss section用于声明未初始化的全局变量和静态变量，在程序运行时会被初始化未0值。
- code segment，代码段也就是text节，用于存储程序指令；
- stack segment，堆栈段用于分配临时变量、调用函数时传递参数信息等；

### 1.5 寄存器

处理器主要是用来进行计算，计算所需要的数据来自于内存，但是处理器存取内存数据需要的时间比较长，为了ALU加速存取操作数，处理器里面内置了寄存器，将内存中的数据先加载到寄存器中，然后ALU对寄存器中的数据进行计算，最后再将计算结果搬回内存。

处理器中的寄存器主要包括如下几类：

- 通用目的寄存器，包括数据寄存器（EAX、EBX、ECX、EDX）、指针寄存器（EIP、ESP、EBP）、索引寄存器（ESI、EDI）；
>函数调用过程中会形成栈帧，ebp寄存器指向的是栈帧的栈底，esp指向的值栈帧的栈顶。通过ebp便于定位传递给函数的参数、返回地址信息，栈帧开始构建的时候，首先就会将caller的ebp压栈，然后将当前栈帧栈顶esp赋值给ebp作为新的栈帧的栈底，后面esp减去一个值N,[esp-N,ebp）就是新的栈空间。
- 段寄存器，包括ECS、ESS、EDS；
>8086里面，CS包括代码段的起始地址，从80386进入保护模式开始，CS里面变成了段选择符，具体的代码段起始地址要到gdb里面去查。DS存储数据段的起始地址，SS存储堆栈段的起始地址。
- 控制寄存器，32位flags寄存器和32位指令指针寄存器共同称为控制寄存器。
>常见的flag标志位包括：OF（溢出）、DF（字符串比较方向）、IF（是否允许中断）、TF（是否单步执行）、SF（符号位）、ZF（比较结果）、AF（辅助进位）、PF（1数量是否为奇数）、CF（是否进位）。

下面是一个使用多个寄存器的示例程序：

```nasm
section	.text
   global _start	 ;must be declared for linker (gcc)
	
_start:	         ;tell linker entry point
   mov	edx,len  ;message length
   mov	ecx,msg  ;message to write
   mov	ebx,1    ;file descriptor (stdout)
   mov	eax,4    ;system call number (sys_write)
   int	0x80     ;call kernel
	
   mov	edx,9    ;message length
   mov	ecx,s2   ;message to write
   mov	ebx,1    ;file descriptor (stdout)
   mov	eax,4    ;system call number (sys_write)
   int	0x80     ;call kernel
	
   mov	eax,1    ;system call number (sys_exit)
   int	0x80     ;call kernel
	
section	.data
msg db 'Displaying 9 stars',0xa ;a message
len equ $ - msg  ;length of message
s2 times 9 db '*'
```

### 1.6 系统调用

系统调用是操作系统内核提供的用户态、内核态之间的接口，用户态通过系统调用访问内核服务。

如何通过在汇编程序里面使用系统调用呢？

- 在EAX寄存器里面设置系统调用号；
- 在EBX、ECX、EDX、ESI、EDI、EBP中设置系统调用参数（如果参数数量超过6个，则需特殊处理）；
- 调用中断服务int 0x80（系统调用都是通过中断服务的形式实现，int指令使得处理器从ring3切换到ring0，iret使处理器从ring0切换回ring3）；
- 系统调用的返回值通常保存在EAX中；

Linux下的系统调用定义在/usr/include/asm/unistd.h中，可以从中查看系统调用名称以及编号。下面是一个综合使用系统调用read、write、exit的例子，程序提示用户输入一个数字并读取用户输入，然后回显该数字。

```nasm
section .data                           ;Data segment
   userMsg db 'Please enter a number: ' ;Ask the user to enter a number
   lenUserMsg equ $-userMsg             ;The length of the message
   dispMsg db 'You have entered: '
   lenDispMsg equ $-dispMsg                 

section .bss           ;Uninitialized data
   num resb 5
	
section .text          ;Code Segment
   global _start
	
_start:                ;User prompt
   mov eax, 4
   mov ebx, 1
   mov ecx, userMsg
   mov edx, lenUserMsg
   int 80h

   ;Read and store the user input
   mov eax, 3
   mov ebx, 2
   mov ecx, num  
   mov edx, 5          ;5 bytes (numeric, 1 for sign) of that information
   int 80h
	
   ;Output the message 'The entered number is: '
   mov eax, 4
   mov ebx, 1
   mov ecx, dispMsg
   mov edx, lenDispMsg
   int 80h  

   ;Output the number entered
   mov eax, 4
   mov ebx, 1
   mov ecx, num
   mov edx, 5
   int 80h  
    
   ; Exit code
   mov eax, 1
   mov ebx, 0
   int 80h
```

### 1.7 寻址模式

汇编语言中的寻址模式可以分为两类，一类是**指令寻址**，一类是**数据寻址**：

- 指令寻址：处理器要执行的指令如何寻址，分为顺序寻址（顺序执行，pc+=1）、跳跃寻址（jmp）；
- 数据寻址：根据数据所在存储位置的不同（内存或寄存器），以及地址提供方式的不同，数据寻址方式多种多样。

数据寻址方式虽然多样，但是都遵从如下指令格式：

|:--:|:--:|:--:|
|操作码OP|寻址特征|形式地址A|

根据寻址特征以及形式地址A，可以计算出操作数的有效地址EA，不同的寻址特征对形式地址A施加的计算规则也不一样。下面总结一下常见的数据寻址方式。

- 立即寻址，A是立即数（常量），EA=A；
- 寄存器寻址，A是寄存器编号，EA=A=Ri；
- 直接内存寻址，A为数据在内存中的有效地址，即EA=A；
- 直接内存偏移量寻址，类似于基址寻址方式，EBX做基地址，A为offset；
- 间接内存寻址，(A)为数据在内存中的有效地址，即EA=(A),间接内存寻址可能还会涉及到多重间址；

>计算机组成原理中可能提到的数据寻址方式更加偏重于理论，寻址方式也更加多样，实际的汇编语言实现中可能并没有逐一实现，或者区分不明显，我们这里从实践出发，更加侧重于实用而不是理论，因此在使用术语的选择上也更加偏重于业内人员的偏好。

在汇编语言中，获取一个内存变量的有效地址的方式是：[varname]。

下面是一个综合使用了上述多种寻址方式的示例程序：

```nasm
section	.text
   global_start     ;must be declared for linker (ld)
_start:             ;tell linker entry point
	
   ;writing the name 'Zara Ali'
   mov	edx,9       ;message length
   mov	ecx, name   ;message to write
   mov	ebx,1       ;file descriptor (stdout)
   mov	eax,4       ;system call number (sys_write)
   int	0x80        ;call kernel
	
   mov	[name],  dword 'Nuha'    ; Changed the name to Nuha Ali
	
   ;writing the name 'Nuha Ali'
   mov	edx,8       ;message length
   mov	ecx,name    ;message to write
   mov	ebx,1       ;file descriptor (stdout)
   mov	eax,4       ;system call number (sys_write)
   int	0x80        ;call kernel
	
   mov	eax,1       ;system call number (sys_exit)
   int	0x80        ;call kernel

section	.data
name db 'Zara Ali '
```

### 1.8 定义变量

汇编语言中提供了多个汇编器指令用于定义变量、预留内存空间。

**section .data，为初始化的数据分配存储空间:**

```
varname define-directive initial-value[,initial-value2]
```

常用的define-directive包括DB、DW、DD、DQ、DT，分别用于定义1byte、1word、1doubleword、1quadword、10bytesd并进行初始化操作。

**section .bss，为未初始化的数据分配存储空间：**

```
[varname] reserve-directive quantity
```

常用的reserve-directie指令包括RESB、RESW、RESD、RESQ、REST，分别用于分配1byte、1word、1doubleword、1quadword、10bytes的存储空间，结合操作数quantity可以计算出需要分配多少空间。

.bss节每一个对应的define-directive语句都有一个对应的reserve-directive与之对应，reserve-directive也可以单独存在，如下所示：

```nasm
section .bss
	age db
	resb 1         ;只预留空间没关联变量
	num resb 1     ;预留空间并绑定变量
```

**times directive允许多个变量初始化为相同的值：**

```
varname times quantity define-directive [intiail-val]
```

注意times指令也可以用于.bss节，但是.bss节汇编的时候不会进行初始化，程序启动的时候才会进行0初始化。

- 如果没有提供initial-val，会提示没有初始值不进行初始化；
- 如果提供了intiail-val，会提示.bss节忽略了初始值不进行初始化操作；

### 1.9 定义常量

汇编语言中定义常量的指令包括3个，分别是EQU、%assign、%define。

```nasm
const-name EQU value ;可以定义字符串或者数值常量
%assign const-name value ;只可以定义数值常量，可以重定义
%define const-name value ;可以定义字符串或者数值常量
```

前面曾多次使用EQU进行常量定义，这里就不再提供其他示例程序了。

### 1.10 算术指令

汇编语言中的算术运算指令包括：

- INC、DEC，自增、自减一个寄存器或者内存变量的值，结果保存到当前操作数；
- ADD、SUB，加、减一个寄存器或者内存变量的值，结果保存到第一个操作数；
- MUL、IMUL，分别处理无符号、有符号数的乘法，保存存储遵循如下规则：
	- 8位乘法，如：AL * 8bit_source = AH AL，结果高8位保存到AH、低8位保存到AL；
	- 16位乘法，如：AX * 16bit_source = DX AX，结果高16位保存到DX，低16位保存到AX；
	- 32位乘法，如：EAX * 32bit_source = EDX EAX，结果高32位保存到EDX，低32位保存到EAX；
- DIV、IDIV，分别处理无符号、有符号数的除法，结果存储遵循如下规则：
	- 16位除法，如：AX / 8bit_source = AL...AH，商保存到AL，余数保存到AH；
	- 32位除法，如：DX AX / 16bit_source = AX...DX，被除数高16位在DX、低16位在AX，结果商在AX、余数在DX；
	- 64位除法，如：EDX EAX / 32bit_source = EAX...EDX，被除数高32位在EAX、低32位在EAX，结果商在EAX、余数在EDX；

### 1.11 逻辑指令

汇编语言中的逻辑运算指令包括：

- AND，逻辑与运算，结果保存到第一个操作数；
- OR，逻辑或运算，结果保存到第一个操作数；
- NOT，对当前操作数求反，结果保存到当前操作数；
- XOR，异或运算，结果保存到第一个操作数；
- TEST，测试运算，不会改变操作数的值，但运算会影响ZF标识；

### 1.12 分支控制

通过某些循环、分支指令可以实现分支语句，这里对应的汇编指令主要都是基于处理器中的标识寄存器来实现的。

**常用指令包括：**

- 比较指令  
CMP，比较两个操作数是否相同、谁大谁小，需结合其他条件转移指令使用；
- 无条件转移指令  
JMP，无条件跳转到制定的指令地址处执行；
- 条件转移指令
有符号数、无符号数通用的包括：JE/JZ，JNE/JNZ；
无符号数特有的包括：JG、JGE、JL、JLE等；
有符号数特有的包括：JA、JAE、JB、JBE等；
特殊用途的包括：JC、JNC、JO、JNO、JS、JNS等；

这里涉及到的条件转移指令比较多，这里不一一进行描述了，有需要的话读者朋友可以参考[”分支控制指令“](https://www.tutorialspoint.com/assembly_programming/assembly_conditions.htm)，或者可以参考intel指令集了解更多的细节。

### 1.13 循环控制

**借助条件转移指令实现循环**

条件转移指令可以用于实现循环控制，循环控制次数可以存储在ECX寄存器中，循环体内动作每执行一次将ECX值减1，根据ECX值是否为0决定是否进行循环。下面就是一个根据这个简单思路实现的循环体：

```nasm
MOV	CL, 10
L1:
	<LOOP-BODY>
DEC	CL
JNZ	L1
```

**借助内置的loop指令实现循环**

汇编语言内部提供了指令loop来实现循环，起实现方式跟我们上面说的是一样的，loop指令会检查当前ECX寄存器的值是否为0，为0则退出循环，大于0则执行DEC ECX并继续执行循环体。

下面是一个借助loop指令实现的循环体版本，书写上也更加简练：

```nasm
MOV	CL, 10
L1:
	<LOOP-BODY>
loop L1
```

### 1.14 数字

前面我们读入一个数位数值的时候需要将其减去'0'之后得到其真实数值，运算结果写出之前也需要将数位数值加上'0'再写出，为啥？这里涉及到ASCII码与数值之间的转换。

上述处理方式虽然比较直观，但是负载比较大，汇编语言中有更加高效的处理方式，即以二进制形式对其进行处理。

十进制数字有两种表示形式：

- ASCII码形式  
输入的十进制数字每个数位都用ASCII来表示，十进制数字1234的4个数位分别被编码为对应的ASCII码字符，各个字符对应的十进制值分别为：31 32 33 34，共占用了4个字节；
- BCD码形式  
	- 如果是unpacked BCD编码形式，输入的十进制数字每个数位都用1字节的二进制形式来表示，十进制数字1234的4个数位分别被编码为：01 02 03 04，共占用4个字节。
	- 如果是packed BCD编码形式，输入的十进制数字每个数位用4bit来表示，十进制数字1234的4个数位被编码为：12 34，共占用2个字节。

运算完成之后，可能会涉及到某些ASCII、BCD码之间的转换动作，可以借助于对应的汇编调整指令来实现。

### 1.15 字符串

**计算字符串长度**

前面我们指定一个字符串的长度的时候，可以通过变量来显示地指明，也可以通过**”$-msg“**来计算出来，使用后者的时候我们需要为msg字符串尾部添加一个哨兵字符，例如：

```nasm
msg db 'hello world',0xa
len db $-msg
```

$代表的是当前的offset，offset-db正好是msg中字符的数量，不包括0xa，如果不添加0xa这个字符哨兵的话，len就应该定义成**"$-msg+1"**。

**字符串操作指令：**

- MOVS，移动一个字符串；
- LODS，从内存中装载字符串；
- STOS，存储字符串到内存；
- CMPS，比较字符串；
- SCAS，比较寄存器和内存中的字符串；
- REP/REPZ/REPNZ，便利字符串并针对各个字符重复执行某个操作；

### 1.16 数组

定义数组，主要有如下几种方式，我们以定义一个byte数组为例分别说明。

**定义数组方式一：**

```nasm
numbers db 0,1,2,3,4,5
```

**定义数组方式二：**

```nasm
numbers db 0
        db 1
        db 2
        db 3
        db 4
        db 5
```

这种方式应该比较少用，方式一其实是这种方式的简化版。

**定义数组方式三：**

```nasm
numbers times 6 db 0
```

这种方式定义的6个byte都被初始化为相同的值0。

还是要根据自己的需要来选择合适的数组定义方式。

下面示例程序定义了一个数组byte数组x，然后以循环的形式遍历x中的元素并求和：

```nasm
section	.text
   global _start   ;must be declared for linker (ld)
	
_start:	 		
   mov  eax,3      ;number bytes to be summed 
   mov  ebx,0      ;EBX will store the sum
   mov  ecx, x     ;ECX will point to the current element to be summed

top:  add  ebx, [ecx]
   add  ecx,1      ;move pointer to next element
   dec  eax        ;decrement counter
   jnz  top        ;if counter not 0, then loop again

done: 
   add   ebx, '0'
   mov  [sum], ebx ;done, store result in "sum"

display:
   mov  edx,1      ;message length
   mov  ecx, sum   ;message to write
   mov  ebx, 1     ;file descriptor (stdout)
   mov  eax, 4     ;system call number (sys_write)
   int  0x80       ;call kernel
	
   mov  eax, 1     ;system call number (sys_exit)
   int  0x80       ;call kernel

section	.data
global x
x:    
   db  2
   db  4
   db  3

sum: 
   db  0
```

### 1.17 函数

汇编语言中函数是非常重要的一个组成部分，定义函数的语法如下：

```nasm
function_name:
	<function_body>
	ret
```

程序中调用一个函数的指令为call：

```nasm
call <function_name>
```

下面示例代码总定义了一个求和函数：

```nasm
section	.text
   global _start        ;must be declared for using gcc
	
_start:	                ;tell linker entry point
   mov	ecx,'4'
   sub     ecx, '0'
	
   mov 	edx, '5'
   sub     edx, '0'
	
   call    sum          ;call sum procedure
   mov 	[res], eax
   mov	ecx, msg	
   mov	edx, len
   mov	ebx,1	        ;file descriptor (stdout)
   mov	eax,4	        ;system call number (sys_write)
   int	0x80	        ;call kernel
	
   mov	ecx, res
   mov	edx, 1
   mov	ebx, 1	        ;file descriptor (stdout)
   mov	eax, 4	        ;system call number (sys_write)
   int	0x80	        ;call kernel
	
   mov	eax,1	        ;system call number (sys_exit)
   int	0x80	        ;call kernel
sum:
   mov     eax, ecx
   add     eax, edx
   add     eax, '0'
   ret
	
section .data
msg db "The sum is:", 0xA,0xD 
len equ $- msg   

segment .bss
res resb 1
```

栈stack，是一种后进先出LIFO的数据结构，汇编语言提供了指令push、pop来进行入栈、出栈操作。

### 1.18 递归

递归操作，指的是一个函数func在执行过程中会调用这个函数自身的情况。递归又可以细分为直接递归和间接递归。

- 直接递归，函数func的函数体中会调用自身；
- 间接递归，函数func的函数体中调用了其他的函数，而这个被调用的函数中又调用了函数func；

有些问题适合用递归算法来解决，递归比较容易理解，但是对栈空间消耗可能会超出系统允许的上限导致栈溢出问题，此时需要将递归算法转换为非递归算法。

### 1.19 宏

汇编语言中可以将常用的、可能多次重复使用的指令序列以宏macro的形式进行封装，在程序中可以多次调用。

**定义宏的形式为：**

```nasm
%macro macro_name params_quantity
	<macro_body>
%endmacro
```

**调用宏的形式为：**

```nasm
macro_name param1, param2
```

下面的示例程序中，将输出字符串的指令序列以宏的形式进行了封装：

```nasm
; A macro with two parameters
; Implements the write system call
   %macro write_string 2 
      mov   eax, 4          ;sys_write
      mov   ebx, 1          ;stdout
      mov   ecx, %1         ;param1, buf
      mov   edx, %2         ;param2, buf_len
      int   80h             ;call kernel
   %endmacro
 
section	.text
   global _start            ;must be declared for using gcc
	
_start:                     ;tell linker entry point
   write_string msg1, len1               
   write_string msg2, len2    
   write_string msg3, len3  
	
   mov eax,1                ;sys_exit
   int 0x80                 ;call kernel

section	.data
msg1 db	'Hello, programmers!',0xA,0xD 	
len1 equ $ - msg1			

msg2 db 'Welcome to the world of,', 0xA,0xD 
len2 equ $- msg2 

msg3 db 'Linux assembly programming! '
len3 equ $- msg3
```

### 1.20 文件操作

Linux内核提供了一系列文件操作的系统调用，常用的几个系统调用如下：

- sys_open
- sys_close
- sys_creat
- sys_read
- sys_write
- sys_lseek

>系统调用编号可以在/usr/include/asm/unistd.h中检查到，系统调用参数、返回值信息可以借助Linux man手册进行查询。

汇编语言里面对于上述系统调用的调用与前面sys_read、sys_write示例程序中的使用方式是一致的，都按照如下几个步骤进行调用：

- 将系统调用的编号设置到EAX；
- 将系统调用的参数依次设置到EBX、ECX、EDX、ESI、EDI、EBX；
- 触发内核中断int 80h；
- 检查EAX中保存的系统调用返回值；

如下示例程序对文件相关的系统调用进行了组合使用，首先创建一个文件并写入数据，然后关闭，再重新打开文件并读取文件内容，最后在stdout上打印文件内容。

```nasm
section	.text
   global _start         ;must be declared for using gcc
	
_start:                  ;tell linker entry point
   ;create the file
   mov  eax, 8
   mov  ebx, file_name
   mov  ecx, 0777        ;read, write and execute by all
   int  0x80             ;call kernel
	
   mov [fd_out], eax
    
   ; write into the file
   mov	edx,len          ;number of bytes
   mov	ecx, msg         ;message to write
   mov	ebx, [fd_out]    ;file descriptor 
   mov	eax,4            ;system call number (sys_write)
   int	0x80             ;call kernel
	
   ; close the file
   mov eax, 6
   mov ebx, [fd_out]
    
   ; write the message indicating end of file write
   mov eax, 4
   mov ebx, 1
   mov ecx, msg_done
   mov edx, len_done
   int  0x80
    
   ;open the file for reading
   mov eax, 5
   mov ebx, file_name
   mov ecx, 0             ;for read only access
   mov edx, 0777          ;read, write and execute by all
   int  0x80
	
   mov  [fd_in], eax
    
   ;read from file
   mov eax, 3
   mov ebx, [fd_in]
   mov ecx, info
   mov edx, 26
   int 0x80
    
   ; close the file
   mov eax, 6
   mov ebx, [fd_in]
    
   ; print the info 
   mov eax, 4
   mov ebx, 1
   mov ecx, info
   mov edx, 26
   int 0x80
       
   mov	eax,1             ;system call number (sys_exit)
   int	0x80              ;call kernel

section	.data
file_name db 'myfile.txt'
msg db 'Welcome to Tutorials Point'
len equ  $-msg

msg_done db 'Written to file', 0xa
len_done equ $-msg_done

section .bss
fd_out resb 1
fd_in  resb 1
info resb  26
```

### 1.21 内存管理

Linux内核提供了系统调用sys_brk来分配堆内存区域，sys_brk实际上是增加了进程最大可动态申请的内存地址的上限，brk分配的内存区域（堆）仅仅挨着.data节，系统调用sys_brk参数为0时会返回当前可申请内存的最大地址，参数不为0时会调整当前brk边界。

下面的示例程序通过系统调用sys_brk来动态分配了16KB的内存空间：

```nasm
section	.text
   global _start         ;must be declared for using gcc
	
_start:	                 ;tell linker entry point

   mov	eax, 45		 ;sys_brk
   xor	ebx, ebx
   int	80h

   add	eax, 16384	 ;number of bytes to be reserved
   mov	ebx, eax
   mov	eax, 45		 ;sys_brk
   int	80h
	
   cmp	eax, 0
   jl	exit	;exit, if error 
   mov	edi, eax	 ;EDI = highest available address
   sub	edi, 4		 ;pointing to the last DWORD  
   mov	ecx, 4096	 ;number of DWORDs allocated
   xor	eax, eax	 ;clear eax
   std			 ;backward
   rep	stosd            ;repete for entire allocated area
   cld			 ;put DF flag to normal state
	
   mov	eax, 4
   mov	ebx, 1
   mov	ecx, msg
   mov	edx, len
   int	80h		 ;print a message

exit:
   mov	eax, 1
   xor	ebx, ebx
   int	80h
	
section	.data
msg    	db	"Allocated 16 kb of memory!", 10
len     equ	$ - msg
```

### 1.22 总结

这里结合tutorialspoint上的汇编语言教程对相关的知识点进行了简要回顾，也有所收获，这里也分享给需要的同学。
