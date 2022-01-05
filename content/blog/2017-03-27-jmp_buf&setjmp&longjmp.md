---
layout: post  
title: jmp_buf & setjmp & longjmp  
description: "最近在看spp & libco源码，他们实现协程上下文切换的过程中，都或多或少借鉴了jmp_buf的设计，用以保存协程执行时的现场。协程切换的时候保存当前协程的现场，然后恢复待调度协程的现场。理解是很容易理解，但是总感觉还是有点浅尝辄止了，于是就抽点时间看了下jmp_buf、setjmp、longjmp相关的代码，大体理了下思路。"
date: 2017-03-27 21:31:13 +0800
tags: ["context", "jmp_buf", "setjmp", "longjmp", "coroutine"]
toc: true
reward: true
---

最近在看spp & libco源码，他们实现协程上下文切换的过程中，都或多或少借鉴了jmp_buf的设计，用以保存协程执行时的现场。协程切换的时候保存当前协程的现场，然后恢复待调度协程的现场。理解是很容易理解，但是总感觉还是有点浅尝辄止了，于是就抽点时间看了下jmp_buf、setjmp、longjmp相关的代码，大体理了下思路。

学习整理了一下关于jmp_buf & setjmp & longjmp的内容。

linux 4.0内核中jmp_buf这个结构体用于记录硬件上下文信息，可以用于函数内、函数外跳转，goto只能实现函数内跳转。先来看下这个结构体的定义吧，i386架构的处理器与x86_64架构的处理器，对应的jmp_buf结构体定义稍微有些不同，这个很容易理解，寄存器位宽、数量等都有些不同。

i386架构：

```c
// 处理器架构：i386
// - Linux/arch/x86/um/shared/sysdep/archsetjmp_32.h
struct __jmp_buf {
 unsigned int __ebx; // 通用数据寄存器之一
 unsigned int __esp; // 栈指针寄存器(进程栈空间由高地址向低地址方向增长)
 unsigned int __ebp; // 基址指针寄存器(记录了当前栈帧的起始地址(进入一个函数后首先执行的便是push %ebp; mov %esp, %ebp))
 unsigned int __esi; // 源变址寄存器
 unsigned int __edi; // 目的编制寄存器
 unsigned int __eip; // 指令指针寄存器(程序计数器PC=CS:IP,二者结合起来确定下一条待执行的机器指令地址)
};
typedef struct __jmp_buf jmp_buf[1];
```

x86_64架构：

```c
// 处理器架构：x86_64
// - Linux/arch/x86/um/shared/sysdep/archsetjmp_64.h
struct __jmp_buf {
 unsigned long __rbx; // 通用数据寄存器之一
 unsigned long __rsp; // 栈指针寄存器
 unsigned long __rbp; // 基址指针寄存器
 unsigned long __r12;
 unsigned long __r13;
 unsigned long __r14;
 unsigned long __r15;
 unsigned long __rip;
};

typedef struct __jmp_buf jmp_buf[1];
```

但是呢，glibc里面重新定义了这个类型，这里面还对信号掩码进行了考虑。

```c
struct __jmp_buf_tag
{
 /* NOTE: The machine-dependent definitions of `__sigsetjmp'
 assume that a `jmp_buf' begins with a `__jmp_buf' and that
 `__mask_was_saved' follows it. Do not move these members
 or add others before it. */
 __jmp_buf __jmpbuf; /* Calling environment. */
 int __mask_was_saved; /* Saved the signal mask? */
 __sigset_t __saved_mask; /* Saved signal mask. */
};
typedef struct __jmp_buf_tag jmp_buf[1];
```

这个__jmp_buf_tag主要就是用于记录下当前的进程的硬件上下文信息、信号掩码信息，保存操作是通过setjmp来完成的，而在执行过程中caller1->... ->caller${i}-> ... ->callerN中如果希望跳转到在caller${i}中的某个位置时(该位置已经通过__jmp_buf_tag进行了保存)，通过调用longjmp来将指定__jmp_buf_tag变体中保存的硬件上下文信息还原到处理器的各个寄存器中，并将进程信号掩码信息也进行还原，之后机器会回到caller${i}中调用setjmp的下一行代码处开始执行。
glibc在此基础上针对c和c++分别实现了setjmp和longjmp，c下只保存硬件上下文信息，c++中除此之外还保存信号掩码信息，注意是有区别的。

setjmp：

```c
// __BEGIN_NAMESPACE_STD是一个宏，表示namespace std {
__BEGIN_NAMESPACE_STD
 // STD这个命名空间内是既保存硬件上下文信息，也保存信号掩码
 typedef struct __jmp_buf_tag jmp_buf[1];
 extern int _setjmp(struct __jmp_buf_tag __env[1]) __THROWNL;
 #define setjmp(env) _setjmp(env)
__END_NAMESPACE_STD
// __END_NAMESPACE_STD是一个宏，表示}
// c下这个保存硬件上下文信息，并且保存__savemask指定的信号掩码
extern int __sigsetjmp (struct __jmp_buf_tag __env[1], int __savemask) __THROWNL;
// c下这个只保存硬件上下文信息
extern int _setjmp (struct __jmp_buf_tag __env[1]) __THROWNL;
// c下setjmp只保存硬件上下文信息
#define setjmp(env) _setjmp (env)`
```

longjmp:

```c
typedef struct __jmp_buf_tag sigjmp_buf[1];

void __libc_siglongjmp (sigjmp_buf env, int val)
{
 /* Perform any cleanups needed by the frames being unwound. */
 _longjmp_unwind (env, val);
 if (env[0].__mask_was_saved)
 /* Restore the saved signal mask. */
 (void) __sigprocmask (SIG_SETMASK, &env[0].__saved_mask, (sigset_t *) NULL);
 /* Call the machine-dependent function to restore machine state. */
 __longjmp (env[0].__jmpbuf, val ?: 1);
}
// 如果没有定义这个宏__libc_siglongjmp则执行下面这些别名创建操作
// 什么情况下会定义这个宏呢？先不管，不影响整体的理解！fixme!!!
#ifndef __libc_siglongjmp
 strong_alias (__libc_siglongjmp, __libc_longjmp)
 libc_hidden_def (__libc_longjmp)
 weak_alias (__libc_siglongjmp, _longjmp)
 weak_alias (__libc_siglongjmp, longjmp)
 weak_alias (__libc_siglongjmp, siglongjmp)
#endif
```

这里对上面几个特殊的宏进行一下说明(以weak_alias为例，其他几个类似的处理方式)：

```c
// weak_alias(a,b)就是创建一个与a的别名b
/* Define ALIASNAME as a weak alias for NAME.
 If weak aliases are not available, this defines a strong alias.*/
#define weak_alias(name, aliasname) _weak_alias (name, aliasname)
#define _weak_alias(name, aliasname) \
 extern __typeof (name) aliasname __attribute__ ((weak, alias (#name)));
```

现在整体流程已经大体清楚了，现在来看下setjmp以及longjmp的实现：
- setjmp就不需要说了吧，也就是通过gcc扩展的内联汇编取出需要的寄存器的值，甚至是取出当前进程的task_struct中的信号掩码信息，然后保存到jmp_buf中；
- longjmp就是将参数中指定的jmp_buf取出来并进行还原，还原处理器的硬件上下文信息，还原进程的信号掩码信息，这里我们来说一下;

下面看下几个关键的函数。

- 第一个函数，_longjmp_unwind，这个是在执行实际的jmp之前先对unwind操作所经过的现有栈帧执行一定的处理动作，不过我看默认的/gnu/glibc/setjmp/jmp-unwind.c中没有做任何处理，可能需要用户自己hook一下？为啥要处理这里的栈帧呢，可能有必要可能没必要，只要jmp回去了，从栈低地址回到了高地址之后，之前低地址的栈也就全部作废了，因为栈又要从当前位置开始向低地址增长，之前生成的低地址栈空间会被覆盖。

- 第二个函数，_sigprocmask，这个是执行还原jmp_buf中的信号掩码信息的。

```c
static void __set_task_blocked(struct task_struct *tsk, const sigset_t *newset)
{
 if (signal_pending(tsk) && !thread_group_empty(tsk)) {
 sigset_t newblocked;
 /* A set of now blocked but previously unblocked signals. */
 sigandnsets(&newblocked, newset, ¤t->blocked);
 retarget_shared_pending(tsk, &newblocked);
 }
 tsk->blocked = *newset;
 recalc_sigpending();
}
```

文件/gnu/glibc/sysdeps/unix/sysv/linux/x86_64/sigprocmask.c

这个是glibc中定义的信号掩码处理函数，最终会通过系统调用进入内核来处理，因为毕竟要修改进程pcb中的某些状态字段，只有内核才具备此权限。

```c
/* Get and/or change the set of blocked signals. */
int __sigprocmask (int how, const sigset_t *set, sigset_t *oset)
{
 /* XXX The size argument hopefully will have to be changed to the
 real size of the user-level sigset_t. */
 return INLINE_SYSCALL (rt_sigprocmask, 4, how, set, oset, _NSIG / 8);
}
weak_alias (__sigprocmask, sigprocmask)
```

内核中的信号掩码处理函数，及根据操作类型来决定对进程信号掩码做何种处理，这里毫无疑问应该是set操作。

```c
int sigprocmask(int how, sigset_t *set, sigset_t *oldset)
{
 struct task_struct *tsk = current;
 sigset_t newset;
 /* Lockless, only current can change ->blocked, never from irq */
 if (oldset)
 *oldset = tsk->blocked;
 switch (how) {
 case SIG_BLOCK:
 sigorsets(&newset, &tsk->blocked, set);
 break;
 case SIG_UNBLOCK:
 sigandnsets(&newset, &tsk->blocked, set);
 break;
 case SIG_SETMASK:
 newset = *set;
 break;
 default:
 return -EINVAL;
 }
 __set_current_blocked(&newset);
 return 0;
}
```

获取当前进程的任务结构体，对其中的sighand加锁然后开始信号相关的设置操作，也就是屏蔽newset中指定的信号。

```c
void __set_current_blocked(const sigset_t *newset)
{
 struct task_struct *tsk = current;
 spin_lock_irq(&tsk->sighand->siglock);
 __set_task_blocked(tsk, newset);
 spin_unlock_irq(&tsk->sighand->siglock);
}
```

更新当前进程任务结构体task_struct中的信号掩码信息，至于更新的过程中做了何种处理，这里先暂时不做详细介绍了，感兴趣的话可以自己查看下源码。

- 第三个函数执行实际的jmp动作，也就是还原硬件上下文信息：

```c
/* Jump to the position specified by ENV, causing the
 setjmp call there to return VAL, or 1 if VAL is 0.
 void __longjmp (__jmp_buf env, int val). */
.text
ENTRY(__longjmp)
 /* Restore registers. */
 mov (JB_RSP*8)(%rdi),%R8_LP
 mov (JB_RBP*8)(%rdi),%R9_LP
 mov (JB_PC*8)(%rdi),%RDX_LP
 #ifdef PTR_DEMANGLE
 PTR_DEMANGLE (%R8_LP)
 PTR_DEMANGLE (%R9_LP)
 PTR_DEMANGLE (%RDX_LP)
 #ifdef __ILP32__
 /* We ignored the high bits of the %rbp value because only the low
 bits are mangled. But we cannot presume that %rbp is being used
 as a pointer and truncate it, so recover the high bits. */
 movl (JB_RBP*8 + 4)(%rdi), %eax
 shlq 2, %rax
 orq %rax, %r9
 # endif
 #endif
 LIBC_PROBE (longjmp, 3, LP_SIZE@%RDI_LP, -4@%esi, LP_SIZE@%RDX_LP)
 /* We add unwind information for the target here. */
 cfi_def_cfa(%rdi, 0)
 cfi_register(%rsp,%r8)
 cfi_register(%rbp,%r9)
 cfi_register(%rip,%rdx)
 cfi_offset(%rbx,JB_RBX*8)
 cfi_offset(%r12,JB_R12*8)
 cfi_offset(%r13,JB_R13*8)
 cfi_offset(%r14,JB_R14*8)
 cfi_offset(%r15,JB_R15*8)
 movq (JB_RBX*8)(%rdi),%rbx
 movq (JB_R12*8)(%rdi),%r12
 movq (JB_R13*8)(%rdi),%r13
 movq (JB_R14*8)(%rdi),%r14
 movq (JB_R15*8)(%rdi),%r15
 /* Set return value for setjmp. */
 mov %esi, %eax
 mov %R8_LP,%RSP_LP
 movq %r9,%rbp
 LIBC_PROBE (longjmp_target, 3, LP_SIZE@%RDI_LP, -4@%eax, LP_SIZE@%RDX_LP)
 jmpq *%rdx
END (__longjmp)
```

上面的代码在文件/gnu/glibc/sysdeps/x86_64/__longjmp.S中，通过.text中的汇编代码来执行还原硬件上下文的操作，上面的代码中还用到了两个宏：

```c
/* Define an entry point visible from C. */
#define ENTRY(name) \
 .globl C_SYMBOL_NAME(name); \
 .type C_SYMBOL_NAME(name),@function; \
 .align ALIGNARG(4); \
 C_LABEL(name) \
 cfi_startproc; \
 CALL_MCOUNT
#undef END
#define END(name) \
 cfi_endproc; \
 ASM_SIZE_DIRECTIVE(name)
```

这两个宏就比较巧了，ENTRY其实直接定义了一个在c中具有可见性的函数name，在我们这个情境下就是__longjmp，然后就直接追加上前面还原硬件上下文的汇编代码作为函数体，最后通过END结束函数体。

注意这里的代码__longjmp其实是个用户态中的函数，并非是内核来处理的。这样这个函数执行完成之后，下面就会自动回到setjmp语句的下一行语句处执行。

setjmp、longjmp的大致实现过程就介绍到这里，介可能有些地方描述不到位或者有错误，也请大家能给我指出来。

