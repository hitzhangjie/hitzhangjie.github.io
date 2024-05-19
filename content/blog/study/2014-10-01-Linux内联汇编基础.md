---
layout: post  
title: Linux内联汇编基础
description: ""
date: 2014-10-01 00:16:34 +0800
categories: ["过去的学习笔记"]
tags: ["unix","linux","assembly","c","cpp"]
toc: true
reward: true
draft: false
---

迁移自 hitzhangjie/Study 项目下的内容，本文主要总结的是阅读内核源码《Linux内核源码情景分析》时对内联汇编的一些总结。

```
1.full template

__asm__(assembler template
		:output operands				/* optional */
		:input operands					/* optional */
		:list of clobbered registers	/* optional */
	   );

2.x86 registers

eax,ebx,ecx,edx
edi,esi
ebp,esp
eip
eflags

3.linux代码中很多地方都使用了这种形式的汇编语言，嵌入汇编程序的格式如下：
　　__asm__ __volatile__ (
		　　asm statements
		　　: outputs
		　　: inputs
		　　: registers-modified
		　　);
　　asm statements是一组AT&T格式的汇编语言语句，每个语句一行，由\n分隔各行。所有的语句都被包裹在一对双引号内。其中使用的寄存器前面要加两个%%做前缀(%n表示参数,n:数字)；转移指令多是局部转移，因此多使用数字标号。
　　inputs指明程序的输入参数，每个输入参数都括在一对圆括号内，各参数用逗号分开。每个参数前加一个用双引号括起来的标志，告诉编译器把该参数装入到何处。
　　可用的标志有：
　　“g”：让编译器决定如何装入它；
　　“a”：装入到ax/eax；
　　“b”：装入到bx/ebx；
　　“c”：装入到cx/ecx；
　　“d”：装入到dx/edx；
　　“D”：装入到di/edi；
　　“S”：装入到si/esi；
　　“q”：a、b、c、d寄存器等；
　　“r”：任一通用寄存器；
　　“i”：整立即数；
　　“I”：0-31 之间的立即数（用于32位移位指令）；
　　“J”：0-63 之间的立即数（用于64 位移位指令）；
　　“N”：0-255 ，之间的立即数（用于out 指令）；
　　“n”：立即数，有些系统不支持除字以外的立即数，这些系统应该使用“n”而不是“i”；
　　“p”：有效内存地址；
　　“m”：内存变量；
　　“o”：操作数为内存变量，但是其寻址方式是偏移量类型，也即是基址寻址，或者是基址加变址寻址；
　　“V”：操作数为内存变量，但寻址方式不是偏移量类型；
　　“,”：操作数为内存变量，但寻址方式为自动增量；
　　“X”：操作数可以是任何类型；
　　“f”：浮点数；
　　“t”：第一个浮点寄存器；
　　“u”：第二个浮点寄存器；
　　“G”：标准的80387；
　　%  ：浮点常数,该操作数可以和下一个操作数交换位置；
　　“=”：输出；
　　“+”：既是输入又是输出；
　　“&”：改变其值之前写,分配一个独立的寄存器,使得函数返回值和该变量不因为重复使用同一个寄存器,出现数据覆盖；
　　“%”：与下一个操作数之间可互换；
　　“#”：忽略其后的字符，直到逗号；
　　“*”：当优先选择寄存器时，忽略下面的字符；
　　“0”~“9”：指定一个操作数，它既做输入又做输出。通常用“g”；
　　outputs指明程序的输出位置，通常是变量。每个输出变量都括在一对圆括号内，各个输出变量间用逗号隔开。每个输出变量前加一个标志，告诉编译器从何处输出。
　　可用的标志与输入参数用的标志相同，只是前面加“=”。如“=g”。输出操作数必须是左值，而且必须是只写的。如果一个操作数即做输出又做输 入，那么必须将它们分开：一个只写操作数，一个输入操作数。输入操作数前加一个数字限制（0~9），指出输出操作数的序号，告诉编译器它们必须在同一个物 理位置。两个操作数可以是同一个表达式，也可以是不同的表达式。
　　registers-modified告诉编译器程序中将要修改的寄存器。每个寄存器都用双引号括起来，并用逗号隔开。如“ax”。如果汇编程 序中引用了某个特定的硬件寄存器，就应该在此处列出这些寄存器，以告诉编译器这些寄存器的值被改变了。如果汇编程序中用某种不可预测的方式修改了内存，应 该在此处加上“memory”。这样以来，在整个汇编程序中，编译器就不会把它的值缓存在寄存器中了。
　　如:
　　“cc”：你使用的指令会改变CPU的条件寄存器cc；
　　“memory”：你使用的指令会修改内存；
　　__volatile__是可选的，它防止编译器修改该段汇编语句（重排序、重组、删除等）。
　　输入参数和输出变量按顺序编号，先输出后输入，编号从0开始。程序中用编号代表输入参数和输出变量（加%做前缀）。
　　输入、输出、寄存器部分都可有可无。如有，顺序不能变；如无，应保留“：”，除非不引起二意性。
　　看一个在C语言中使用at&t的嵌入汇编程序的例子，c语言中的3个int变量，一般会是三个内存地址。每个操作数的长度则要根据操作系统和编译器来决定，一般32位操作系统为32位，则每个操作数占用4个字节：
　　int i=0, j=1, k=0;
　　__asm__ __volatile__("
		　　pushl %%eax\n //asm statement
		　　movl %1, %%eax\n //asm statement
		　　addl %2, %%eax\n //asm statement
		　　movl %%eax, %0\n //...
		　　popl %%eax" //...
		　　: "=g" (k) //outputs
		　　: "g" (i), "g" (j) //inputs
		　　: "ax", "memory" //registers modified
		　　);
　　按照参数编号原则输出参数参数k为%0,输入参数i和j依次为%1和%2。值得注意的是输出和输入标志都使用了"g",所以我们不必关心这些参数究竟是使用了寄存器还是内存操作数，编译器自己会决定。

4.linux/windows汇编指令的区别
Note:
	汇编指令的执行需要汇编程序将其翻译成机器代码，由于汇编程序是系统程序的一部分，而linux跟windows本身设计上存在很多不同，汇编程序当然不例外，所以，他们支持的汇编指令的格式也存在很多不同。

DOS/Windows 下的汇编语言代码都是 Intel 风格的。但在 Unix 和 Linux 系统中，更多采用的还是 AT&T 格式，两者在语法格式上有着很大的不同：  

在 AT&T 汇编格式中，寄存器名要加上 '%' 作为前缀；而在 Intel 汇编格式中，寄存器名不需要加前缀。例如：  
AT&T 格式  pushl %eax  
Intel 格式 push eax  

在 AT&T 汇编格式中，用 '\$' 前缀表示一个立即操作数；而在 Intel 汇编格式中，立即数的表示不用带任何前缀。例如：  
AT&T 格式 pushl $1  
Intel 格式 push 1  

AT&T 和 Intel 格式中的源操作数和目标操作数的位置正好相反。在 Intel 汇编格式中，目标操作数在源操作数的左边；而在 AT&T 汇编格式中，目标操作数在源操作数的右边。例如：  
AT&T 格式 addl $1, %eax  
Intel 格式 add eax, 1  

在 AT&T 汇编格式中，操作数的字长由操作符的最后一个字母决定，后缀'b'、'w'、'l'分别表示操作数为字节（byte，8 比特）、字（word，16 比特）和长字（long，32比特）；而在 Intel 汇编格式中，操作数的字长是用 "byte ptr" 和 "word ptr" 等前缀来表示的。例如：  
AT&T 格式  
movb val, %al  
Intel 格式 mov al, byte ptr val  

在 AT&T 汇编格式中，绝对转移和调用指令（jump/call）的操作数前要加上'*'作为前缀，而在 Intel 格式中则不需要。

远程转移指令和远程子调用指令的操作码，在 AT&T 汇编格式中为 "ljump" 和 "lcall"，而在 Intel 汇编格式中则为 "jmp far" 和 "call far"，即：  
AT&T 格式 ljump $section, $offset     lcall $section, $offset  
Intel 格式 jmp far section:offset     call far section:offset  

与之相应的远程返回指令则为：  
AT&T 格式 lret $stack_adjust  
Intel 格式 ret far stack_adjust  

在 AT&T 汇编格式中，内存操作数的寻址方式是  
section:disp(base, index, scale)  

而在 Intel 汇编格式中，内存操作数的寻址方式为：  
section:[base + index*scale + disp]  
```
