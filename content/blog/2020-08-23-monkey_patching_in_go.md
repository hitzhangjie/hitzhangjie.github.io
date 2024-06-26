---
layout: post  
title: Monkey Patching in Go
description: "很多go开发者使用gomonkey来写mock测试，但是很多连原理都没搞明白，本文从0开始介绍如何实现monkey patching，希望读者能了解这里的实现原理，以及从原理认识到gomonkey的优缺点。"
date: 2020-08-23 15:41:28 +0800
tags: ["go","monkey-patching","mock"]
toc: true
---

前几天写了篇[x64汇编开发介绍](https://hitzhangjie.github.io/blog/2020-08-20-x64%E6%B1%87%E7%BC%96%E5%BC%80%E5%8F%91%E4%BB%8B%E7%BB%8D/)的文章，当时有提到接下来会介绍下go中如何实现monkey patching，嗯，今天就来说下这个事情。

# Monkey Patching 简介

monkey patching，一说到这个，很多熟悉go的同学可能会联想起gomonkey这个mock测试框架。该术语的定义取决于使用它的社区。在Ruby，Python 和许多其他动态编程语言中，“monkey patching”一词仅指在运行时对类或模块的动态修改，其目的是为了修补现有的第三方代码，以此作为解决方法。错误或功能无法正常运行。根据其不同的意图，在运行时修改类的其他形式也具有不同的名称。例如，在Zope和Plone中，安全补丁通常是使用动态类修改来提供的，但它们被称为热修补程序(hot fixes)。

monkey patching，它常用于如下场景：

- 在运行时替换方法/类/属性/函数，例如在测试过程中取消功能；
- 修改/扩展第三方产品的行为，而无需维护源代码的私有副本；
- 在运行时将补丁程序的结果应用于内存中的状态，而不是磁盘上的源代码；
- 分发与原始源代码一起存在的安全性或行为修复程序（例如，将其作为Ruby on Rails平台的插件分发）；
- 探索各种自动修复程序以提供自我修复。

# Monkey Patching in Go

最近在写mock测试的时候，有些场景下用到了gomonkey，这个测试框架挺好用的，之前也简单了解过大致的实现，最近也在看些底层工具链相关的东西，就想整理分享下。

首先我会简单介绍下go函数的实现、指令patching的概念，然后看下反汇编、指令级调试如何帮助快速定位问题，然后通过几个简单的demo来演示下如何实现指令patch，然后我们再回到go实现monkey patching。

> 如果不感兴趣就真的不要看了，就好像别人骑车摔破头也觉得很爽，但是有人觉得10几万的车也没啥吸引人的，所以我极少主动转发、群里推送这些文章，我更希望它是被主动发现的。

## Go函数表示

### demo1

下面定义了一个简单的函数`a()`，然后再main函数中调用它，然后调用通过print打印出它的返回值。

file: main.go

```go
package main

func a() int { return 1 }

func main() {
  print(a())
}
```

这个函数非常简单，monkey patching离不开汇编，所以我们先看下其对应的汇编代码，了解这个程序干了些啥。

这里顺便推荐几个工具:
- dlv，适用于go的调试器
- radare2，静态分析工具，类似的还有IDA、Hopper

我这里就先试用radare2（下文简称r2）来演示如何操作了。

```bash
$ go build -gcflags="all=-N -l" -o main main.go
$ r2 ./main
-- give | and > a try piping and redirection
[0x00454330]> s sym.main.main
[0x00459270]> af
[0x00459270]> pdf
            ; CODE XREF from sym.main.main @ 0x4592c2
┌ 84: sym.main.main ();
│           ; var int64_t var_10h @ rsp+0x8
│           ; var int64_t var_8h @ rsp+0x10
│       ┌─> 0x00459270      64488b0c25f8.  mov rcx, qword fs:[0xfffffffffffffff8] ;; 这里是go函数栈检查
│       ╎   0x00459279      483b6110       cmp rsp, qword [rcx + 0x10]
│      ┌──< 0x0045927d      763e           jbe 0x4592bd
│      │╎   0x0045927f      4883ec18       sub rsp, 0x18                          ;; 栈没问题开始执行
│      │╎   0x00459283      48896c2410     mov qword [var_8h], rbp
│      │╎   0x00459288      488d6c2410     lea rbp, qword [var_8h]
│      │╎   0x0045928d      e8beffffff     call sym.main.a                        ;; 调用函数sym.main.a
│      │╎   0x00459292      488b0424       mov rax, qword [rsp]
│      │╎   0x00459296      4889442408     mov qword [var_10h], rax
│      │╎   0x0045929b      e83003fdff     call sym.runtime.printlock
│      │╎   0x004592a0      488b442408     mov rax, qword [var_10h]
│      │╎   0x004592a5      48890424       mov qword [rsp], rax
│      │╎   0x004592a9      e8a20afdff     call sym.runtime.printint
│      │╎   0x004592ae      e89d03fdff     call sym.runtime.printunlock
│      │╎   0x004592b3      488b6c2410     mov rbp, qword [var_8h]
│      │╎   0x004592b8      4883c418       add rsp, 0x18
│      │╎   0x004592bc      c3             ret
│      └──> 0x004592bd      e83e7affff     call sym.runtime.morestack_noctxt
└       └─< 0x004592c2      ebac           jmp sym.main.main
[0x00459270]> s sym.main.a                                                        ;; 查看sym.main.a地址为0x00459250
[0x00459250]>
```

函数main中调用函数a的过程就这么简单`call sym.main.a`，也就是call 0x00459250，再看下a这个函数，它很简单将返回值1存储到[arg_8h]中，就是前一个栈帧中的一个8字节空间，之后的我们就先不关心了。

```bash
[0x00459250]> af
[0x00459250]> pdf
            ; CALL XREF from sym.main.main @ 0x45928d
┌ 19: sym.main.a (int64_t arg_8h);
│           ; arg int64_t arg_8h @ rsp+0x8
│           0x00459250      48c744240800.  mov qword [arg_8h], 0
│           0x00459259      48c744240801.  mov qword [arg_8h], 1
└           0x00459262      c3             ret
```

### demo2

看完上面这个，我们看点跟monkey patching相关的一个demo。

这个demo也很简单，定义了一个函数a，然后定义了一个变量f，将a赋值给f。有过cc++基础的同学，会自然联想到函数指针，我也是写cc++过来的，所以很自然会想到，f是一个函数指针，它指向a这个函数。下面的打印语句呢，它应该打印出函数a的地址。

file: main2.go

```go
package main

import (
  "fmt"
  "unsafe"
)

func a() int { return 1 }

func main() {
  f := a
  fmt.Printf("%p\n", a)
  fmt.Printf("0x%x\n", *(*uintptr)(unsafe.Pointer(&f)))
}
```

测试下看下结果：
```bash
$ go build -gcflags="all=-N -l" -o main2 main2.go
$ ./main2

0x4abf20
0x4ecc28
```

发现这两个地址并不相同，说明什么，说明我们对go函数值的理解有偏差，至少可以确定的是它不是一个函数指针。要想理解go的函数值表示，可以参考[funcval表示](https://github.com/golang/go/blob/e9d9d0befc634f6e9f906b5ef7476fbd7ebd25e3/src/runtime/runtime2.go#L75-L78)。

那这么看应该是一个指针的指针，验证一下：
```bash
[0x0045c410]> px/1ag 0x4ecc28
0x004ecc28  0x004abf20 0x00000000                         .J.....
```

px/1ag就是类似gdb调试器里面的x/FMT或者dlv里面的x -FMT hex -len 8 address。我们打印地址0x4ecc28地址处的一个8字节地址出来，发现刚好就是函数a的地址0x004abf20。所以，上述`f := a` 关于f结构的猜想就得到了验证，它就是一个funcval，并非cc++意义上的函数指针。

### demo3

理解了funcval之后，再来一个demo，再来一个修改版的demo，这下应该可以打印出相同的地址了。

```go
package main

import (
  "fmt"
  "unsafe"
)

func a() int { return 1 }

func main() {
  f := a
  fmt.Printf("%p\n", a)
  fmt.Printf("0x%x\n", **(**uintptr)(unsafe.Pointer(&f)))
}
```

运行一下：

```bash
$ go build -gcflags="all=-N -l" -o main3 main3.go
$ ./main3
0x4abf20
0x4abf20
```

OK，到这里，我们理解了funcval，那么当我们调用 `f()` 的时候，编译器安插了什么指令来实现对a这个函数的调用呢？

file: main4.go

```go
package main() 

func a() int { return 1 }

func main() {
    f := a
    f()
}
```

运行以下操作：

```bash
$ go build -gcflags="all=-N -l" -o main4 main4.go
$
$ r2 ./main4
 -- Enable ascii-art jump lines in disassembly by setting 'e asm.lines=true'. asm.lines.out and asm.linestyle may interest you as well
[0x00454330]> s sym.main.main
[0x00459270]> af
[0x00459270]> pdf
            ; CODE XREF from sym.main.main @ 0x4592b1
┌ 67: sym.main.main ();
│           ; var int64_t var_10h @ rsp+0x8
│           ; var int64_t var_8h @ rsp+0x10
│       ┌─> 0x00459270      64488b0c25f8.  mov rcx, qword fs:[0xfffffffffffffff8]
│       ╎   0x00459279      483b6110       cmp rsp, qword [rcx + 0x10]
│      ┌──< 0x0045927d      762d           jbe 0x4592ac
│      │╎   0x0045927f      4883ec18       sub rsp, 0x18
│      │╎   0x00459283      48896c2410     mov qword [var_8h], rbp
│      │╎   0x00459288      488d6c2410     lea rbp, qword [var_8h]
│      │╎   0x0045928d      488d15fc7002.  lea rdx, qword [0x00480390]
│      │╎   0x00459294      4889542408     mov qword [var_10h], rdx
│      │╎   0x00459299      488b05f07002.  mov rax, qword [0x00480390] ; [0x480390:8]=0x459250 sym.main.a
│      │╎   0x004592a0      ffd0           call rax
│      │╎   0x004592a2      488b6c2410     mov rbp, qword [var_8h]
│      │╎   0x004592a7      4883c418       add rsp, 0x18
│      │╎   0x004592ab      c3             ret
│      └──> 0x004592ac      e84f7affff     call sym.runtime.morestack_noctxt
└       └─< 0x004592b1      ebbd           jmp sym.main.main
```

这里其实可以确定的是，0x00480390 就是变量f这个funcval的地址，下面又取 [0x00480390] 这个内存单元中的内容送rax，此时rax中的内容也就是函数a的地址了，最后 `call rax` 完成函数调用。

这里其实实现了一个操作，本来f也可以指向另一个函数b，但是我却通过赋值操作 `f := a` 将其执行了另一个函数a去执行。这样类似的操作，提炼下是否可以拿来用于实现monkey patching呢？可以。

现在要在程序运行的时候，动态调整一个函数要执行的目的代码，其实也可以通过类似的操作。

## 指令Patching

指令patching是一个比monkey patching覆盖面更广的范畴，意思就是运行时修改程序执行的指令。其实，指令patching技术大家都已经用过无数次了，只不过不是你亲自操作的。

比如，当你调试一个程序的时候，就需要指令patch让你的被调试任务（俗称tracee）停下来，这个时候就需要将tracee下一条要执行的指令的首字节篡改为`0xcc`，处理器遇到这个指令就会让你的程序停下来。通常`int3`用来生成一字节指令`0xcc`，处理器取值、译码、执行完之后就会停下来触发中断，然后内核提供的中断服务程序开始执行。正常BIOS提供的都是16位中断服务程序，以Linux为例，内核初始化的时候会重建保护模式下的32/64中断服务程序，意思也就是说，碰到这个指令之后，内核就相当于收到了通知来处理tracee的暂停工作。等tracee停下来之后就会通知tracer（也就是调试器），tracer就可以通过系统调用等手段来检查tracee的运行时信息，包括registers、ram等等。

这里的monkey patching呢，其实也是有点类似，简单一句就是篡改指令而已。问题是这里该怎么篡改？

其实这里的改法，也比较简单，假如我们有这样的一个函数 `func a() int {return 1}`，我们希望main函数中调用`a()`的时候，执行的是`func b() int {return 2}`，那怎么搞呢？我们可以写一个函数`replace(a, b)`将对a的调用替换成对b的调用。

```go
package main

func a() int { return 1 }
func b() int { return 2 }

func main() {
	replace(a, b)
	print(a())
}
```

## 大致实现

因为是在运行时修改，在运行时能干什么呢？我们不能修改a的地址，只能再a的地址处玩些花招：指令patch，篡改这里的指令。怎么篡改呢？

- 前面讲过，我们是可以拿到一个funcval变量中保存的目的函数地址的；
- 操作系统，提供了一些可以使用的系统调用来让我们修改进程地址空间中的数据；

两个条件都具备了，我们可以通过ptrace+peekdata/pokedata来读写指令，也可以获取函数对应的页面（注意对齐），然后申请对这个页面的读写执行权限。两种办法应该都可行。更安全、细粒度的控制，ptrace+peekdata/pokedata要好些，这里纯粹是为了演示，就用后面这个办法了。大致实现如下。

file5: main5.go
```go
package main

import (
	"syscall"
	"unsafe"
)

func a() int { return 1 }
func b() int { return 2 }

func rawMemoryAccess(b uintptr) []byte {
	return (*(*[0xFF]byte)(unsafe.Pointer(b)))[:]
}

func assembleJump(f func() int) []byte {
	funcVal := *(*uintptr)(unsafe.Pointer(&f))
	return []byte{
        // TODO 动态生成跳转到函数funcval f目的地址的指令

		// MOV rdx, funcVal
		// JMP [rdx]
	}
}

func replace(orig, replacement func() int) {
	bytes := assembleJump(replacement)
	functionLocation := **(**uintptr)(unsafe.Pointer(&orig))
	window := rawMemoryAccess(functionLocation)

	copy(window, bytes)
}

func main() {
	replace(a, b)           // 将对a的调用替换成对b的调用
	print(a())              // 这里输出的不是1，是2，注意禁用内联-gcflags="all=-N -l"
}
```

大致实现思路就是上面这样，replace内部：
- 会首先生成跳转到函数b的汇编指令，
- 然后再找到函数a的内存地址，
- 再将生成的跳转指令拷贝到函数a的地址处，覆盖a原来的指令；

这样当程序跑起来之后，跑到a的地址处，立即就JMP到函数b的地址处执行函数b的指令。我们这里不考虑将a数据恢复的问题，其实要做也很简单，你记录一下哪个地址，覆写了多少哪些数据就行了。调试器调试安插0xcc指令的时候都是需要做好保存、恢复类操作的，不然生成的端点（0xcc）就把指令弄乱套了。我们这里就不做这些了。

OK，那这里的函数 `assembleJump(f func() int)` 如何动态生成它的跳转指令呢？这里可以先借助指令级调试先自己测试下。

## 指令级调试

调试器，大家都熟悉吧？其实调试器也是可以分成好几类比较通俗的分类是源码级调试器、指令级调试器。

指令级调试器，大家听说过的应该有IDA、OlleDbg、Hopper、Cutter、Radare2，指令级调试器一般工作在汇编指令层级，对上层高级语言的东西不怎么理解，它理解的就是一些最原始的信息，指令、数据、寄存器、内存，没有文件、源码、行号、变量名...各自有各自的用途，一些符号级调试器如dlv、gdb、lldb等等的也会支持一些基础的指令级调试的能力，比如反汇编、step、step reverse等等的。

我们这里希望在指令级完成调试，比如修改些指令看看效果之类的，一般的工具还是不方便的。Radare2支持指令级调试、指令修改、根据调用约定动态生成调用图等之类的，还是很方便的。

今天就用Radare2来演示下这个如何操作，要调试的是下面这段代码。我们在函数跳转到a地址执行之后，将a地址处的指令篡改下，比如写个JMP到b函数地址的指令，看能不能正常跳转到b处执行，调试成功应该输出`2 2`。

file: mainx.go

```go
package main

func a() int { return 1 }
func b() int { return 2 }

func main() {
	println(a(), b())
}
```

运行以下操作：

```bash
$ go build -gcflags="all=-N -l" -o mainx mainx.go
$
$ r2 -w ./mainx
$ r2 -w ./mainx
 -- To debug a program, you can call r2 with 'dbg://<path-to-program>' or '-d <path..>'
[0x00454330]> s sym.main.
sym.main.a      sym.main.b      sym.main.main
[0x00454330]> s sym.main.a                          ; 发现函数a的低质是0x00454330
[0x00459250]> af
[0x00459250]> s sym.main.b                          ; 发现函数b的地址是0x00459250
[0x00459270]> af
```

好，我们接着操作看下在sym.main.a地址处写入个跳转到b的指令。
```bash
[0x00459270]> s sym.main.a
[0x00459250]> pdf
┌ 19: sym.main.a (int64_t arg_8h);
│           ; arg int64_t arg_8h @ rsp+0x8
│           0x00459250      48c744240800.  mov qword [arg_8h], 0
│           0x00459259      48c744240801.  mov qword [arg_8h], 1
└           0x00459262      c3             ret
[0x00459250]>
```

我们看到函数a处的逻辑是返回值1，我们从起起始地址0x00459250处开始，用JMP bAddress的指令覆盖。

我们希望写到此处的指令有：

```bash
mov rdx, 0x00459270   ; 首先将函数b地址放到rdx寄存器
jmp rdx               ; 然后直接跳转过去执行
```

这里有这么两个办法：
- r2 -w写模式下，直接用`wa+汇编指令`替换函数a的指令；
- r2附带工具生成汇编对应的16进制数据，用`wx+16进制数`来覆写指令；
- 其实你也可以用一些[在线的汇编工具](https://defuse.ca/online-x86-assembler.htm#disassembly)生成，再用其他16进制工具打开可执行程序，然后修改替换。

### r2: wa+汇编指令

通过wa来直接写入汇编指令，这个比较省事，不用单独运行rasm2去得到汇编后的指令16禁止数据再去覆写。

```bash
[root@centos test]# r2 -w ./mainx
 -- The '?' command can be used to evaluate math expressions. Like this: '? (0x34+22)*4'
[0x00454330]> s sym.main.b
[0x00459270]> af
[0x00459270]> s sym.main.a
[0x00459250]> af
[0x00459250]> pdf
┌ 19: sym.main.a (int64_t arg_8h);
│           ; arg int64_t arg_8h @ rsp+0x8
│           0x00459250      48c744240800.  mov qword [arg_8h], 0
│           0x00459259      48c744240801.  mov qword [arg_8h], 1
└           0x00459262      c3             ret
[0x00459250]> wa mov rdx, 0x00459270                                ;; 写mov指令，提示成功，写入了7个字节
Written 7 byte(s) (mov rdx, 0x00459270) = wx 48c7c270924500
[0x00459250]> wa jmp rdx @0x00459257                                ;; 写jmp指令，提示成功，写入了2个字节
Written 2 byte(s) (jmp rdx) = wx ffe2
[0x00459250]> px/20xb 0x00459250                                    ;; 校验一下写入的9个字节
[0x00459250]> wci                                                   ;; 保存退出
[0x00459250]> q
```

注意一下，就是我们写入指令之后，直接运行命令pdf（print disassembly function）看到的指令有些是没正常显示的，不过我们`px/`校验数据是成功写入的就ok。

运行下patch之后的程序：

```bash
$ ./mainx
2 2
```

完全符合预期。

### r2: wx+hex

那我们得看下这些汇编指令对应的机器指令是啥样的，radare2也提供了工具来处理。

汇编、机器指令都是平台相关的，汇编前先看下平台相关信息，好，我的是Intel x86_64, 64位。

```bash
$ uname -a Linux centos 4.19.76-linuxkit #1 SMP Tue May 26 11:42:35 UTC 2020 x86_64 x86_64 x86_64 GNU/Linux
$
$ rasm2 -a x86 -b 64 'mov rdx, 0x00459270'
48c7c270924500
$ rasm2 -a x86 -b 64 'jump rdx'
ffe2
```
生成机器指令后，在r2会话窗口中执行：
```bash
[0x00459250] wx 48c7c270924500ffe2
[0x00459250]> px/9xb
- offset -   0 1  2 3  4 5  6 7  8 9  A B  C D  E F  0123456789ABCDEF
0x00459250  48c7 c270 9245 00ff e2                   H..p.E...          ;; 写入成功了
[0x00459250]> wci                                                       ;; 保存退出
[0x00459250]> q
```

运行下patch之后的程序：

```bash
$ ./mainx
2 2
```

上面只是为了测试下，行还是不行，肯定是行啊，我只是想炫耀下radare2有多强大好玩而已。

### Monkey Patching

上面兜了个圈子，给大家演示了下radare2怎么使用，接下来我们运行时patch下指令测试下。还是mainx.go这个程序。

```go
package main

func a() int { return 1 }
func b() int { return 2 }

func main() {
	println(a(), b())
}
```

前面radare2都是运行在修改模式下，这次运行再调试模式下`radare2 -d`。

执行如下操作：

```bash
$ r2 -d ./mainx
Process with PID 1243 started...                                            ;; 显示已经attach到tracee
= attach 1243 1243
bin.baddr 0x00400000
Using 0x400000
asm.bits 64
 -- Use 'e' and 't' in Visual mode to edit configuration and track flags.
[0x00454330]> s sym.main.b                                                  ;; 继续看下b函数地址
[0x00459270]> af
[0x00459270]> s sym.main.a                                                  ;; 继续看下a函数地址
[0x00459250]> af
[0x00459250]> pdf                                                           ;; 看下a函数包含的指令
┌ 9: sym.main.a ();
│ bp: 0 (vars 0, args 0)
│ sp: 0 (vars 0, args 0)
│ rg: 0 (vars 0, args 0)
│           0x00459250      48c7c2709245.  mov rdx, sym.main.b         ; 0x459270 ; "H\xc7D$\b"
└           0x00459257      ffe2           jmp rdx
[0x00459250]> wx 48c7c270924500ffe2                                         ;; 跟前面讲的一样，指令patch，调到b去
[0x00459250]> 
[0x00459250]> s sym.main.main                                               ;; 定位到main函数
[0x00459290]> af                                                            ;; 分析main函数
[0x00459290]> pdf                                                           ;; 看下main函数指令集调用关系
            ; CODE XREF from sym.main.main @ 0x459308
┌ 122: sym.main.main ();
│           ; var int64_t var_18h @ rsp+0x8
│           ; var int64_t var_10h @ rsp+0x10
│           ; var int64_t var_8h @ rsp+0x18
│       ┌─> 0x00459290      64488b0c25f8.  mov rcx, qword fs:[0xfffffffffffffff8]
│       ╎   0x00459299      483b6110       cmp rsp, qword [rcx + 0x10]
│      ┌──< 0x0045929d      7664           jbe 0x459303
│      │╎   0x0045929f      4883ec20       sub rsp, 0x20
│      │╎   0x004592a3      48896c2418     mov qword [var_8h], rbp
│      │╎   0x004592a8      488d6c2418     lea rbp, qword [var_8h]
│      │╎   0x004592ad      e89effffff     call sym.main.a
│      │╎   0x004592b2      488b0424       mov rax, qword [rsp]
│      │╎   0x004592b6      4889442410     mov qword [var_10h], rax
│      │╎   0x004592bb      e8b0ffffff     call sym.main.b
│      │╎   0x004592c0      488b0424       mov rax, qword [rsp]
│      │╎   0x004592c4      4889442408     mov qword [var_18h], rax
│      │╎   0x004592c9      e80203fdff     call sym.runtime.printlock
│      │╎   0x004592ce      488b442410     mov rax, qword [var_10h]
│      │╎   0x004592d3      48890424       mov qword [rsp], rax
│      │╎   0x004592d7      e8740afdff     call sym.runtime.printint
│      │╎   0x004592dc      e82f05fdff     call sym.runtime.printsp
│      │╎   0x004592e1      488b442408     mov rax, qword [var_18h]
│      │╎   0x004592e6      48890424       mov qword [rsp], rax
│      │╎   0x004592ea      e8610afdff     call sym.runtime.printint
│      │╎   0x004592ef      e86c05fdff     call sym.runtime.printnl
│      │╎   0x004592f4      e85703fdff     call sym.runtime.printunlock
│      │╎   0x004592f9      488b6c2418     mov rbp, qword [var_8h]
│      │╎   0x004592fe      4883c420       add rsp, 0x20
│      │╎   0x00459302      c3             ret
│      └──> 0x00459303      e8f879ffff     call sym.runtime.morestack_noctxt
└       └─< 0x00459308      eb86           jmp sym.main.main
[0x00459290]> dc                                                            ;; 我们这里没有什么加断点的必要了，直接continue
(1243) Created thread 1244
(1243) Created thread 1245
PTRACE_CONT: No such process
(1243) Created thread 1246
PTRACE_CONT: No such process
[+] SIGNAL 19 errno=0 addr=0x00000000 code=0 ret=0
[+] signal 19 aka SIGSTOP received 0
[0x004549f3]> dc                                                            ;; 再来一次，continue到tracee结束
2 2                                                                         ;; 输出了结果 `2 2`
```

OK，经过上面相关的演示之后，应该已经了解了我们patch的大致方法及实际效果了，也介绍了radare2的常用操作。

## Put It Together

现在我们收一下，将前面掌握的技能点综合起来，来实现我们前面遗留的任务：

```go
func assembleJump(f func() int) []byte {
	funcVal := *(*uintptr)(unsafe.Pointer(&f))
	return []byte{
        // TODO 动态生成跳转到函数funcval f目的地址的指令

		// MOV rdx, funcVal
		// JMP [rdx]
	}
}
```

那这里就很简单了，就是填充这里的`[]byte{}`，构造出我们前面`radare2 wx`命令写入的数据而已。
多次测试下rasm2对jmp指令的编码你可以发现：
- mov操作码编码为`48c7`
- rdx编码为为`c2`
- 接下来是要移动的数据funcval地址，这个通过移位运算符搞下就行了，多少个字节呢？看mov操作码知道操作数位宽32bits，所以4个字节

那么 `MOV rdx, funcVal` 对应的就是:
```go
[]byte{
    0x48, 0xC7, 0xC2,
    byte(funcVal >> 0),
	byte(funcVal >> 8),
	byte(funcVal >> 16),
	byte(funcVal >> 24), // MOV rdx, funcVal
```

再看下 `JMP [rdx]`，注意这里和我们前面举的例子不同，前面是对`JMP rdx`编码的，这两种方式涉及到处理器寻址方式的差异。

- `JMP [rdx]`，是说rdx中存储的是地址，取出这个地址对应内存单元中的数据作为有效地址；
- `JMP rdx`，是说rdx中存储的就是有效地址，前面的例子中我们是直接将`func b`的地址拿来用的；

这里的assembleJump函数接受的参数是funcVal，拿到的是funcVal的地址，需要再解一次引用，才能拿到`func b`的有效地址。

说这么多，应该没有歧义了，使用rasm2继续对`JMP [rdx]`编码得到`ff22`:

```bash
$ rasm2 -a x86 -b 64 'jmp [rdx]'
$ ff22
```
那我们这个函数就可以写完了：

```go
func assembleJump(f func() int) []byte {
	funcVal := *(*uintptr)(unsafe.Pointer(&f))
	return []byte{
        // TODO 动态生成跳转到函数funcval f目的地址的指令
        0x48, 0xC7, 0xC2,
        byte(funcVal >> 0),
	    byte(funcVal >> 8),
	    byte(funcVal >> 16),
	    byte(funcVal >> 24), // MOV rdx, funcVal
		0xff, 0x22,          // JMP [rdx]
	}
}

```

那最后的示例就是这样的，你可以直接运行下面的程序来测试下，期望的结果是输出`2`，而不是`1`。

如果你测试的时候输出了1，说明你可能忽视了一个问题：**这里的monkey patching是基于函数地址处的指令patch来实现的。如果编译过程中，不巧期望被patch的函数被go inline处理掉了，那这里的patch铁定就失效了**。

所以测试的时候记得禁用内联，比如`go run -gcflags="all=-N -l" jump.go`。

```go
package main

import (
	"fmt"
	"syscall"
	"unsafe"
)

func a() int { return 1 }
func b() int { return 2 }

func getPage(p uintptr) []byte {
	return (*(*[0xFFFFFF]byte)(unsafe.Pointer(p & ^uintptr(syscall.Getpagesize()-1))))[:syscall.Getpagesize()]
}

func rawMemoryAccess(b uintptr) []byte {
	return (*(*[0xFF]byte)(unsafe.Pointer(b)))[:]
}

func assembleJump(f func() int) []byte {
	funcVal := *(*uintptr)(unsafe.Pointer(&f))
	fmt.Printf("target address: %#x\n", funcVal)
	return []byte{
		0x48, 0xC7, 0xC2,
		byte(funcVal >> 0),
		byte(funcVal >> 8),
		byte(funcVal >> 16),
		byte(funcVal >> 24), // MOV rdx, funcVal
		0xFF, 0x22,          // JMP rdx
	}
}

func replace(orig, replacement func() int) {
	bytes := assembleJump(replacement)
	functionLocation := **(**uintptr)(unsafe.Pointer(&orig))
	fmt.Printf("orig address: %#x\n", functionLocation)

	window := rawMemoryAccess(functionLocation)

	page := getPage(functionLocation)
	syscall.Mprotect(page, syscall.PROT_READ|syscall.PROT_WRITE|syscall.PROT_EXEC)

	copy(window, bytes)
	fmt.Printf("bytes: %v\n", bytes)
	fmt.Printf("wind: %v\n", window[0:len(bytes)])
}

func main() {

	fmt.Printf("a address: %p\n", a)
	fmt.Printf("b address: %p\n", b)

	replace(a, b)
	print(a())
}
```

运行测试下：

```bash
$ go run -gcflags="all=-N -l" jump.gomonkey
2
```

gomonkey写mock测试，对函数的处理大致就是这个这么实现的，这里就不继续说gomonkey的具体实现细节了。

# 总结

本文所提内容并非原创，在了解gomonkey的过程中看到了《monkey-patching-in-go》这篇文章，结合自己的一些理解重新解释下背后的原理。

其实本没有必要解释这么多，我可以一句话总结完，”go funcval + 指令patch“。但是呢，”纸上得来终觉浅”，没有经过实践检验的“懂”也只是自己骗自己罢了。

大篇幅介绍了radare2调试器的一些使用，应该有读者会对调试器工作原理、底层实现比较感兴趣，这也是大篇幅介绍的一点小小的私心。

从2018年开始陆续整理调试原理的一些知识，将这些整理的内容放在了github上[golang-debugger-book](https://github.com/hitzhangjie/golang-debugger-book)。原理的部分大致已经介绍完了，现在还需要结合一个实现来辅助使内容更加详实一点，这里也会涉及到对go实现细节的一些知识点补充，感兴趣的可以一起来。

时间精力实在有限，拖得久了，很没有成就感。

# 参考文章

1.monkey-patching-in-go, https://bou.ke/blog/monkey-patching-in-go/

2.a-journey-into-radare2, https://www.megabeets.net/a-journey-into-radare-2-part-1/

3.monkey patching, https://en.wikipedia.org/wiki/Monkey_patch

4.radare2 book, https://radare.gitbooks.io/radare2book/content/tools/rasm2/assemble.html

