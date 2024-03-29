---
layout: post  
title: go风格协程库libmill之源码分析 
description: "我们只想要一个协程化的开发能力以及基于CSP的数据共享，难道我们就需要一门新的语言，比如golang？有很多开发人员曾经提出类似的质疑，笔者刚接触go时也抱着类似的想法。那么不妨思考下如果用c/c++的话，如果要实现上述功能，我们应该如何实现呢？ZeroMQ之父Martin Sustrik就用1w多行代码实现了一个非常优雅的go风格协程库，不妨来一起学习下。"
date: 2017-12-03 16:49:09 +0800
tags: ["libmill","coroutine","goroutine","go"]
draft: true
toc: true
reward: true
---

<style>
img {width:680px;}
</style>

# 1 Preface

libmill, 是Martin Sustrik发起的一个面向unix平台下c语言开发的协程库，实现了一种类似goroutine风格的协程，也支持channel，“通过通信共享数据，而非通过共享数据来完成通信”。

觉得挺有意思的，就抽周末时间看了下。大神的代码干净利索，也看到了不少令自己眼前一亮的tricks，举几个例子吧。

**1 通用链表及迭代器实现**

**offsetof**可以计算结构体中的成员的offset，如果我们知道一个struct的类型、其成员名、成员地址，我们就可以计算出struct的地址：

```c
#define mill_cont(ptr, type, member) \
        (ptr ? ((type*) (((char*) ptr) - offsetof(type, member))) : NULL)
```

基于此可以进一步实现一个通用链表，怎么搞呢？

```c
struct list_item {
    struct list_item * next;
};

struct my_struct {
    void * data; 
    struct list_item * iter;
};
```

我们通过list_item来构建链表，并在自定义my_struct中增加一个list_item成员，将其用作迭代器。当我们希望构建一个my_struct类型的链表时实际上构建的是list_item的列表，当我们遍历my_struct类型的链表时遍历的也是list_item构成的链表。加入现在遍历到了链表中的某个list_item item，就可以结合前面提到的mill_cont(&item, struct list_item, iter)来获得包括成员的结构体地址，进而就可以访问结构体中的data了。

其实这里Martin Sustrik的实现方式与Linux下的通用链表相关的宏实现类似，只是使用起来感觉更加自然一些，也更容易被接受。

**2 栈指针调整（分配协程栈）**

栈的分配有两个时机，一个是编译时，一个是运行时。对于编译时可以确定占用空间大小的就在编译时生成对应的汇编指令来分配，如：```sub 0x16, %rsp```；对于运行时才可以确定占用空间大小的就要在运行时分配，如：```int n = srand()%16; int buf[n];```，这个如何分配呢？Linux下有个库函数alloca可以在当前栈帧上继续分配空间，但是呢？它不会检查是否出现越界的行为，注意了，因为内存分配后，栈顶会发生变化，寄存器%rsp会受到影响，也是基于这个side effect，就可以实现让指定的函数go(func)将新分配的内存空间当做自己的栈帧继续运行。这样每个协程都有自己的栈空间，再存储一下协程上下文就可以很方便地实现协程切换。

```c
#define mill_go_(fn) \
    do {\
        void *mill_sp;\
        mill_ctx ctx = mill_getctx_();\
        if(!mill_setjmp_(ctx)) {\
            mill_sp = mill_prologue_(MILL_HERE_);\
            int mill_anchor[mill_unoptimisable1_];\
            mill_unoptimisable2_ = &mill_anchor;\
            char mill_filler[(char*)&mill_anchor - (char*)(mill_sp)];\
            mill_unoptimisable2_ = &mill_filler;\
            fn;\
            mill_epilogue_();\
        }\
    } while(0)
```

**3 其他惊喜**

惊喜的点不在多，一两三个也是令人开心的 ...

理解了这个goroutine风格协程库的实现，但是也更多地看到了好的设计思想，看大神的代码就是有种“听君一席话，胜读十年书”的感觉。

感慨：路漫漫其修远兮，吾将上下而求索！

# 2 Introduction

## 2.1 libmill简介

**libmill**是一个面向c语言的协程库，其下载地址、文档可以在这里找到：[libmill](http://libmill.org/)， 其源代码托管在github上，点击这里查看：[libmill-source](https://github.com/sustrik/libmill)。

## 2.2 libmill vs goroutine

libmill协程库是基于goroutine移植的，libmill的api友好，与golang中的api非常接近，如下图所示。

![libmill_vs_goroutine]

虽然二者api比较一致，但是在实现上还是有较大区别，所以这里说“**libmill是goroutine风格的协程库**”只是api上接近。

- 在libmill里面所有的协程调度都是在当前线程中的
也就是说一个单线程程序使用了libmill实现的协程，并且协程执行过程中使用了阻塞的系统调用，这样会阻塞整个进程。
- goroutine中创建的协程会被分摊到多个物理线程上去执行
  goroutine中创建的协程，一个协程中使用了阻塞的系统调用只会阻塞当前线程，并不会阻塞进程中的其他线程运行。

    >备注：这里需要注意下，linux下的线程库有两个，比较早的是LinuxThreads线程库，现在用的一般都是Native POSIX Threads Library（nptl），也就是pthread线程库。其中LinuxThreads是用户级线程库，创建的线程内核无感知，调度也是用户态线程调度器自己实现的；而pthread线程库创建的线程都是一个LWP进程，它使用sys_clone()并传递CLONE_THREAD选项来创建一个线程（本质上还是LWP）并且线程所属进程id相同。

上面是libmill的简单介绍，下面开始详细介绍了。

# 3 Coroutine

## 3.1 libmill

### 3.1.1 ABI版本

```c
// ABI应用程序二进制接口
#define MILL_VERSION_CURRENT 19         // 主版本
#define MILL_VERSION_REVISION 1         // 修订版本
#define MILL_VERSION_AGE 1              // 支持过去的几个版本
```

### 3.1.2 符号可见性

libmill这里是要编译成共享库的，共享库应该将实现相关的细节屏蔽，只暴露接口给外部调用就好，因此在共享库中有个“**符号可见性**”的问题（可参考下面的引文）。该工程在在Makefile里通过编译器选项```-fvisibility inlines=hidden```来设置默认对外隐藏工程中的符号，对于提供给外部使用的接口使用可见性属性```__attribute__((visibility("default")))```来单独设置其可见性。

>Functions with default visibility have a global scope and can be called from other shared objects. Functions with hidden visibility have a local scope and cannot be called from other shared objects. Visibility can be controlled by using either compiler options or visibility attributes.
>更多关于符号可见性的描述，可以参考：[点击查看](https://www.ibm.com/support/knowledgecenter/en/SSB23S_1.1.0.14/gtpl2/export.html)。    

```c
#if !defined __GNUC__ && !defined __clang__
#error "Unsupported compiler!"
#endif

#if defined MILL_NO_EXPORTS
#   define MILL_EXPORT
#else
#   if defined _WIN32
#      ......
#   else
#      if defined __SUNPRO_C
#          ......
#      elif (defined __GNUC__ && __GNUC__ >= 4) || defined __INTEL_COMPILER || defined __clang__
#          define MILL_EXPORT __attribute__ ((visibility("default")))
#      else
#          define MILL_EXPORT
#      endif
#   endif
#endif
```

如果函数名前有宏**MILL_EXPORT**，表示该函数具有默认可见性，可在libmill.so外的代码中被调用。这里我们举个两字来说明一下：

```c
// mill_concat_可见性为Makefile中指定的hidden，只能在当前so中使用，对外不可见
#define mill_concat_(x,y) x##y

// mill_now_、mill_mfork_可见性为default，对外可见，可在so外部调用
MILL_EXPORT int64_t mill_now_(void);
MILL_EXPORT pid_t mill_mfork_(void);
```

libmill.h中涉及到大量的函数名导出的问题，这里由于篇幅的原因不再一一列出。

### 3.1.3 定时器精度
获取系统时间函数**gettimeofday**还是比较耗时的，对于频繁需要获取系统时间的情景下，需要对获取到的系统时间做一定的cache。为了保证时间精度，这里的cache更新时间必须要控制好。

如何决定何时更新cache的系统时间呢？**rdtsc**（read timestamp counter）指令执行只需要几个时钟周期，它返回系统启动后经过的时钟周期数。这里可以根据CPU频率指定一个时钟周期数量作为阈值，当前后两次rdtsc读取到的时钟周期数的差值超过这个阈值再调用gettimeofday来更新系统时间。这里libmill中的定时器timer就是这么实现的。

下面是**rdtsc**指令的简要说明，详情请查看：[wiki rdtsc](https://en.wikipedia.org/wiki/Time_Stamp_Counter)。

>The Time Stamp Counter (TSC) is a 64-bit register present on all x86 processors since the Pentium. It counts the number of cycles since reset. The instruction RDTSC returns the TSC in EDX:EAX. In x86-64 mode, RDTSC also clears the higher 32 bits of RAX and RDX. Its opcode is 0F 31.[1] Pentium competitors such as the Cyrix 6x86 did not always have a TSC and may consider RDTSC an illegal instruction. Cyrix included a Time Stamp Counter in their MII.

该头文件涉及源码较多，这里只列出了比较关键的代码，感兴趣的可以查看源代码来了解更多细节。

### 3.1.4 mill_fdwait关注的io事件
```c
// mill_fdwait关注的读写错误事件
#define MILL_FDW_IN_ 1
#define MILL_FDW_OUT_ 2
#define MILL_FDW_ERR_ 4
```

### 3.1.5 协程上下文的保存和切换

#### 3.1.5.1 协程上下文

```c
#if defined __x86_64__
typedef uint64_t *mill_ctx;
#else
typedef sigjmp_buf *mill_ctx;
#endif
```

#### 3.1.5.2 协程上下文的保存

```c
// x86_64平台下协程上下文保存实现
#if defined(__x86_64__)
......
// 保存当前协程运行时上下文（就是保存处理器硬件上下文到指定内存区域ctx中备用）
//
// 这里使用宏来实现可以避免函数调用堆栈创建、销毁带来的开销，实现更高效地协程切换，
// linux gcc内联汇编，汇编相关参数可以分为“指令部”、“输出部”、“输入部”、“破坏部”，
// 这里将内存变量ctx的值传入寄存器rdx，并将最后rax寄存器的值赋值给变量ret，
// 指令将rax清零，将rbx、r12、rsp、r13、r14、r15、rcx、rdi、rsi依次保存到ctx为起始地址的内存中
#define mill_setjmp_(ctx) ({\
    int ret;\
    asm("lea     LJMPRET%=(%%rip), %%rcx\n\t"\  //==>返回地址(LJMPRET标号处)送入%%rcx
        "xor     %%rax, %%rax\n\t"\
        "mov     %%rbx, (%%rdx)\n\t"\
        "mov     %%rbp, 8(%%rdx)\n\t"\
        "mov     %%r12, 16(%%rdx)\n\t"\
        "mov     %%rsp, 24(%%rdx)\n\t"\
        "mov     %%r13, 32(%%rdx)\n\t"\
        "mov     %%r14, 40(%%rdx)\n\t"\
        "mov     %%r15, 48(%%rdx)\n\t"\
        "mov     %%rcx, 56(%%rdx)\n\t"\         //==>rcx又存储到56(%%rdx)
        "mov     %%rdi, 64(%%rdx)\n\t"\
        "mov     %%rsi, 72(%%rdx)\n\t"\
        "LJMPRET%=:\n\t"\
        : "=a" (ret)\
        : "d" (ctx)\
        : "memory", "rcx", "r8", "r9", "r10", "r11",\
          "xmm0", "xmm1", "xmm2", "xmm3", "xmm4", "xmm5", "xmm6", "xmm7",\
          "xmm8", "xmm9", "xmm10", "xmm11", "xmm12", "xmm13", "xmm14", "xmm15"\
          MILL_CLOBBER\
          );\
    ret;\
})
```

#### 3.1.5.3 协程上下文的恢复

```c
// x86_64平台下协程上下文恢复实现

#if defined(__x86_64__)
......
// 恢复协程上下文信息到处理器中（从ctx开始的内存区域中加载之前保存的处理器硬件上下文）
//
// 要恢复某个协程cr的运行时，先获取其挂起之前保存的上下文cr->ctx，然后mill_longjmp(ctx)即可，
// 将ctx值加载到rax，采用相对寻址依次加载ctx为起始地址的内存区域中保存的上下文信息到寄存器，
// 最后回复执行
#define mill_longjmp_(ctx) \
    asm("movq   (%%rax), %%rbx\n\t"\
	    "movq   8(%%rax), %%rbp\n\t"\
	    "movq   16(%%rax), %%r12\n\t"\
	    "movq   24(%%rax), %%rdx\n\t"\
	    "movq   32(%%rax), %%r13\n\t"\
	    "movq   40(%%rax), %%r14\n\t"\
	    "mov    %%rdx, %%rsp\n\t"\
	    "movq   48(%%rax), %%r15\n\t"\
	    "movq   56(%%rax), %%rdx\n\t"\     //==>56(%%rax)中地址为返回地址，送入%%rdx
	    "movq   64(%%rax), %%rdi\n\t"\
	    "movq   72(%%rax), %%rsi\n\t"\
	    "jmp    *%%rdx\n\t"\
        : : "a" (ctx) : "rdx" \
    )
#else
// 非x86_64要借助sigsetjmp\siglongjmp来实现协程上下文切换
#define mill_setjmp_(ctx) \
    sigsetjmp(*ctx, 0)
#define mill_longjmp_(ctx) \
    siglongjmp(*ctx, 1)
#endif
```

### 3.1.6 go(func)实现

go(func)的作用是挂起当前协程，并在一个新创建的协程中运行指定的函数func，func执行完成后再销毁新创建的协程，并重新调度其他协程运行（也包括当前协程）。

mill_go_(fn)的实现，我花了不少时间才看懂，这里还要感谢libmill贡献者[**raedwulf**](https://github.com/raedwulf)对我的帮助，通过交流他一下就明白了我困惑的源头并给我指出了不该忽略的关键4行代码！

```c
...

int mill_anchor[mill_unoptimisable1_];\
mill_unoptimisable2_ = &mill_anchor;\
char mill_filler[(char*)&mill_anchor - (char*)(mill_sp)];\
mill_unoptimisable2_ = &mill_filler;\

...
```

这4行代码确实令人困惑，Stack Overflow上的朋友们看到提问的这个问题甚至给踩了好几次，同事看后也觉得有点无厘头，也难怪被raedwulf戏称为black magic around c language！

```c
// go()的实现
#define mill_go_(fn) \
    do {\
        void *mill_sp;\
        // 获取当前正在运行的协程上下文，并及时进行保存，因为我们马上要调整栈帧了
        mill_ctx ctx = mill_getctx_();\
        if(!mill_setjmp_(ctx)) {\
            // 为即将新创建的协程分配对应的内存空间，并返回stack部分的当前栈顶（等于栈底）位置
            mill_sp = mill_prologue_(MILL_HERE_);\
            // 下面4行代码困扰了我很久，原因还是对linux c、gcc、栈帧分配不够精通。
            // - 栈帧中的空间分配，对于编译时可确定尺寸的就编译时分配，通过sub <size>,%rsp来实现；
            // - 栈帧中的空间分配，运行时才可以确定的就需要运行时分配，通过alloca(size)来实现；
            // 注意：
            // - gcc在x86_64下alloca的工作主要是sub <size>,%rsp外加一些内存对齐的操作，alloca在当
            //   前栈帧中分配空间并返回空间起始地址，但是不检查栈是否越界；
            // - 另外指针运算是无符号计算，小地址减去大地址的结果会在整个虚拟内存地址空间中滚动；
            // - mill_filler数组的分配是由alloca完成，分配完成后rsp将被调整为mill_sp指向的内存空间；
            // - 新的协程将以mill_sp作为当前栈顶运行，等当前协程恢复上下文并运行时，其根本意识不
            //   到该所谓的mill_filler的存在，因为保存其上下文操作是早于栈调整操作的；
            int mill_anchor[mill_unoptimisable1_];\
            mill_unoptimisable2_ = &mill_anchor;\
            char mill_filler[(char*)&mill_anchor - (char*)(mill_sp)];\
            mill_unoptimisable2_ = &mill_filler;\
            // 在新创建的协程栈空间中调用函数fn
            fn;\
            // fn执行结束后释放占用的协程内存空间，并mill_suspend让出cpu给其他协程
            mill_epilogue_();\
        }\
    } while(0)
```

### 3.1.7 chan实现

#### 3.1.7.1 常用数据结构

```c
// 这里只是声明，定义在cr.h中
struct mill_chan_;

typedef struct{
    void *f1; 
    void *f2; 
    void *f3; 
    void *f4; 
    void *f5; 
    void *f6; 
    int f7; 
    int f8; 
    int f9;
} mill_clause_;

#define MILL_CLAUSELEN_ (sizeof(mill_clause_))
```

#### 3.1.7.2 发送数据到chan

```c
// 发送type类型的数据value到channel
#define mill_chs__(channel, type, value) \
    do {\
        type mill_val = (value);\
        mill_chs_((channel), &mill_val, sizeof(type), MILL_HERE_);\
    } while(0)
```

#### 3.1.7.3 从chan接收数据

```c
// 从channel接收type类型的数据
#define mill_chr__(channel, type) \
    (*(type*)mill_chr_((channel), sizeof(type), MILL_HERE_))
```

#### 3.1.7.4 chan操作结束

```c
// 用type类型数据value来标记channel操作结束
#define mill_chdone__(channel, type, value) \
    do {\
        type mill_val = (value);\
        mill_chdone_((channel), &mill_val, sizeof(type), MILL_HERE_);\
    } while(0)
```

### 3.1.8 choose从句实现

#### 3.1.8.1 从句初始化

```c
#define mill_choose_init__ \
    {\
        mill_choose_init_(MILL_HERE_);\
        int mill_idx = -2;\
        while(1) {\
            if(mill_idx != -2) {\
                if(0)
```

#### 3.1.8.2 读就绪事件

```c
#define mill_choose_in__(chan, type, name, idx) \
                    break;\
                }\
                goto mill_concat_(mill_label, idx);\
            }\
            char mill_concat_(mill_clause, idx)[MILL_CLAUSELEN_];\
            mill_choose_in_(\
                &mill_concat_(mill_clause, idx)[0],\
                (chan),\
                sizeof(type),\
                idx);\
            if(0) {\
                type name;\
                mill_concat_(mill_label, idx):\
                if(mill_idx == idx) {\
                    name = *(type*)mill_choose_val_(sizeof(type));\
                    goto mill_concat_(mill_dummylabel, idx);\
                    mill_concat_(mill_dummylabel, idx)
```

#### 3.1.8.3 写就绪事件

```c
#define mill_choose_out__(chan, type, val, idx) \
                    break;\
                }\
                goto mill_concat_(mill_label, idx);\
            }\
            char mill_concat_(mill_clause, idx)[MILL_CLAUSELEN_];\
            type mill_concat_(mill_val, idx) = (val);\
            mill_choose_out_(\
                &mill_concat_(mill_clause, idx)[0],\
                (chan),\
                &mill_concat_(mill_val, idx),\
                sizeof(type),\
                idx);\
            if(0) {\
                mill_concat_(mill_label, idx):\
                if(mill_idx == idx) {\
                    goto mill_concat_(mill_dummylabel, idx);\
                    mill_concat_(mill_dummylabel, idx)
```

#### 3.1.8.4 deadline实现

```c
#define mill_choose_deadline__(ddline, idx) \
                    break;\
                }\
                goto mill_concat_(mill_label, idx);\
            }\
            mill_choose_deadline_(ddline);\
            if(0) {\
                mill_concat_(mill_label, idx):\
                if(mill_idx == -1) {\
                    goto mill_concat_(mill_dummylabel, idx);\
                    mill_concat_(mill_dummylabel, idx)
```

#### 3.1.8.5 otherwise实现

```c
#define mill_choose_otherwise__(idx) \
                    break;\
                }\
                goto mill_concat_(mill_label, idx);\
            }\
            mill_choose_otherwise_();\
            if(0) {\
                mill_concat_(mill_label, idx):\
                if(mill_idx == -1) {\
                    goto mill_concat_(mill_dummylabel, idx);\
                    mill_concat_(mill_dummylabel, idx)
```

#### 3.1.8.6 从句结束

```c
#define mill_choose_end__ \
                    break;\
                }\
            }\
            mill_idx = mill_choose_wait_();\
        }
```

## 3.2 stack

stack是coroutine stack的抽象，这里coroutine stack可以看作是一个trick，我们把要并发执行的任务放在一个coroutine stack上执行，并且允许程序上下文在这些并发的任务之间来回切换，以实现更细粒度的并发。每个并发任务都有一个coroutine stack与之对应，每个任务中都涉及到对栈的操作，对栈的操作与普通程序对栈的操作一样都是从高地址向低地址方向增长的，这是由编译器决定的。

### 3.2.1 stack.h

```c
/* Purges all the existing cached stacks and preallocates 'count' new stacks
   of size 'stack_size'. Sets errno in case of error. */
void mill_preparestacks(int count, size_t stack_size);

/* Allocates new stack. Returns pointer to the *top* of the stack.
   For now we assume that the stack grows downwards. */
void *mill_allocstack(size_t *stack_size);

/* Deallocates a stack. The argument is pointer to the top of the stack. */
void mill_freestack(void *stack);
```
### 3.2.2 stack.c

```c
// 获取内存页面大小（只查询一次）
static size_t mill_page_size(void) {
    static long pgsz = 0;
    if(mill_fast(pgsz))
        return (size_t)pgsz;
    pgsz = sysconf(_SC_PAGE_SIZE);
    mill_assert(pgsz > 0);
    return (size_t)pgsz;
}

// stack size，也可以由用户指定
static size_t mill_stack_size = 256 * 1024 - 256;

// 实际的stack size
static size_t mill_sanitised_stack_size = 0;

// 获取stack size
static size_t mill_get_stack_size(void) {
#if defined HAVE_POSIX_MEMALIGN && HAVE_MPROTECT
    /* If sanitisation was already done, return the precomputed size. */
    if(mill_fast(mill_sanitised_stack_size))
        return mill_sanitised_stack_size;
    mill_assert(mill_stack_size > mill_page_size());
    /* Amount of memory allocated must be multiply of the page size otherwise
       the behaviour of posix_memalign() is undefined. */
    size_t sz = (mill_stack_size + mill_page_size() - 1) &
        ~(mill_page_size() - 1);
    /* Allocate one additional guard page. */
    mill_sanitised_stack_size = sz + mill_page_size();
    return mill_sanitised_stack_size;
#else
    return mill_stack_size;
#endif
}

// 未使用的cached的stack的最大数量
// 如果我们的代码还在一个stack上运行那就不能释放它，因此至少需要有一个cached的stack
static int mill_max_cached_stacks = 64;

// 未使用的coroutine stacks构成的stack
//
// 该stack用于快速分配coroutine stack，当一个coroutine被释放其之前的stack被放置在栈顶，
// 假如此时有新的coroutine创建，那么该stack对应的虚拟内存页面有极大的概率还在RAM中，
// 因此可以减少page miss的几率，快速分配coroutine stack的目的就达到了
static int mill_num_cached_stacks = 0;
static struct mill_slist mill_cached_stacks = {0};

// 分配coroutine stack，返回地址为stack+mill_stack_size，即栈顶（栈从高地址向低地址方向增长）
static void *mill_allocstackmem(void) {
    void *ptr;
#if defined HAVE_POSIX_MEMALIGN && HAVE_MPROTECT
    /* Allocate the stack so that it's memory-page-aligned. */
    int rc = posix_memalign(&ptr, mill_page_size(), mill_get_stack_size());
    if(mill_slow(rc != 0)) {
        errno = rc;
        return NULL;
    }
    /* The bottom page is used as a stack guard. This way stack overflow will
       cause segfault rather than randomly overwrite the heap. */
    rc = mprotect(ptr, mill_page_size(), PROT_NONE);
    if(mill_slow(rc != 0)) {
        int err = errno;
        free(ptr);
        errno = err;
        return NULL;
    }
#else
    ptr = malloc(mill_get_stack_size());
    if(mill_slow(!ptr)) {
        errno = ENOMEM;
        return NULL;
    }
#endif
    return (void*)(((char*)ptr) + mill_get_stack_size());
}

// 预分配coroutine stacks（分配count个栈尺寸为stack_size的协程栈）
void mill_preparestacks(int count, size_t stack_size) {
    // 释放cached的所有coroutine stack
    while(1) {
        struct mill_slist_item *item = mill_slist_pop(&mill_cached_stacks);
        if(!item)
            break;
        free(((char*)(item + 1)) - mill_get_stack_size());
    }
    // 现在没有分配的coroutine stacks，可以调整一下stack尺寸了
    size_t old_stack_size = mill_stack_size;
    size_t old_sanitised_stack_size = mill_sanitised_stack_size;
    mill_stack_size = stack_size;
    mill_sanitised_stack_size = 0;
    // 分配新的coroutine stacks并cache起来备用
    int i;
    for(i = 0; i != count; ++i) {
        void *ptr = mill_allocstackmem();
        if(!ptr)
            goto error;
        struct mill_slist_item *item = ((struct mill_slist_item*)ptr) - 1;
        mill_slist_push_back(&mill_cached_stacks, item);
    }
    mill_num_cached_stacks = count;
    // 确保这里分配的coroutine stacks不会被销毁，即便当前没有使用
    mill_max_cached_stacks = count;
    errno = 0;
    return;
error:
    // 如果无法分配所有的coroutine stacks，那就一个也不分配（已分配的释放），还原状态并返回错误
    while(1) {
        struct mill_slist_item *item = mill_slist_pop(&mill_cached_stacks);
        if(!item)
            break;
        free(((char*)(item + 1)) - mill_get_stack_size());
    }
    mill_num_cached_stacks = 0;
    mill_stack_size = old_stack_size;
    mill_sanitised_stack_size = old_sanitised_stack_size;
    errno = ENOMEM;
}

// 分配一个coroutine stack（先从cached stacks里面取，如果没有获取到再从内存分配）
void *mill_allocstack(size_t *stack_size) {
    if(!mill_slist_empty(&mill_cached_stacks)) {
        --mill_num_cached_stacks;
        return (void*)(mill_slist_pop(&mill_cached_stacks) + 1);
    }
    void *ptr = mill_allocstackmem();
    if(!ptr)
        mill_panic("not enough memory to allocate coroutine stack");
    if(stack_size)
        *stack_size = mill_get_stack_size();
    return ptr;
}

// 释放coroutine stack（参数stack为栈底）
// 如果当前cached stacks小于阈值则将当前待释放的stack cache起来，反之释放其内存
void mill_freestack(void *stack) {
    /* Put the stack to the list of cached stacks. */
    struct mill_slist_item *item = ((struct mill_slist_item*)stack) - 1;
    mill_slist_push_back(&mill_cached_stacks, item);
    if(mill_num_cached_stacks < mill_max_cached_stacks) {
        ++mill_num_cached_stacks;
        return;
    }
    /* We can't deallocate the stack we are running on at the moment.
       Standard C free() is not required to work when it deallocates its
       own stack from underneath itself. Instead, we'll deallocate one of
       the unused cached stacks. */
    item = mill_slist_pop(&mill_cached_stacks);
    void *ptr = ((char*)(item + 1)) - mill_get_stack_size();
#if HAVE_POSIX_MEMALIGN && HAVE_MPROTECT
    int rc = mprotect(ptr, mill_page_size(), PROT_READ|PROT_WRITE);
    mill_assert(rc == 0);
#endif
    free(ptr);
}
```

## 3.3 chan

“**通过通信来共享数据，而非通过共享数据来通信**”，这是golang里chan的设计思想，libmill中也基于这一思想实现了chan。chan可以理解为管道。

### 3.3.1 chan.h

```c
// choose语句是根据chan的状态来决定是否执行对应动作的分支控制语句
//
// 每个协程都会有一个choose数据结构来跟踪其当前正在执行的choose操作
struct mill_choosedata {
    // 每个choose语句中，又包含了多个从句构成的列表
    struct mill_slist clauses;
    // choose语句中otherwise从句是可选的，是否有otherwise从句，0否1是
    int othws;
    // 当前choose语句中，是否有指定deadline，未指定时为-1
    int64_t ddline;
    // 当前choose语句中，chan上事件就绪的从句数量
    int available;
};

// chan ep是对chan的使用者的描述，每个ep要么利用chan发送消息，要么接收消息
//
// 每个chan有一个sender和receiver，所以每个chan包括了sender、receiver两个mill_ep成员
struct mill_ep {
    // 类型（数据发送方 或 数据接收方）
    enum {MILL_SENDER, MILL_RECEIVER} type;
    // 初始化的choose操作的序号
    int seqnum;
    // choose语句中引用该mill_ep的从句数量
    int refs;
    // choose语句中引用该mill_ep并且已经处理过的数量
    int tmp;
    // choose语句中仍然在等待该mill_ep上事件就绪的从句列表
    struct mill_list clauses;
};

// chan
struct mill_chan_ {
    // channel里面存储的元素的尺寸(单位字节)
    size_t sz;
    // 每个chan上有一个seader和receiver
    // sender记录了等待在chan上执行数据发送操作的从句列表，receiver则记录了等待接收数据的从句列表
    struct mill_ep sender;
    struct mill_ep receiver;
    // 当前chan的引用计数（引用计数为0的时候chclose才会真正释放资源）
    int refcount;
    // 该chan上是否已经调用了chdone()，0否1是
    int done;
    // 存储消息数据的缓冲区紧跟在chan结构体后面
    // - bufsz代表消息缓冲区可容纳的最大消息数量
    // - items表示缓冲区中当前的消息数量
    // - first代表缓冲区中可接收的下一个消息的位置，缓冲区末尾有一个元素来存储chdone()写的数据
    size_t bufsz;
    size_t items;
    size_t first;
    // 调试信息
    struct mill_debug_chan debug;
};

// 该结构体代表choose语句中的一个从句，例如in、out、otherwise
struct mill_clause {
    // 等待this.ep事件就绪的从句列表(迭代器）
    struct mill_list_item epitem;
    // 该从句隶属的choose语句所包含的从句列表(迭代器)
    struct mill_slist_item chitem;
    // 创建该从句的协程
    struct mill_cr *cr;
    // 该从句正在等待的chan endpoint
    struct mill_ep *ep;
    // 对于out从句，val指向要发送的数据；对于in从句，val为NULL
    void *val;
    // 该从句执行完成后要跳转到第idx个从句
    int idx;
    // 是否有与当前从句匹配的pee(比如当前从句为ch上的写，是否有ch上的读从句)，0否1是
    int available;
    // 该从句是否在chan的sender或receiver列表中，0否1是
    int used;
};

// 返回包含该endpoint的chan
struct mill_chan_ *mill_getchan(struct mill_ep *ep);
```

### 3.3.2 chan.c

```c
// 每个choose语句都要分配一个单独的序号
static int mill_choose_seqnum = 0;
```

```c
// 返回包含ep的chan(根据端点类型获取)
struct mill_chan_ *mill_getchan(struct mill_ep *ep) {
    switch(ep->type) {
    case MILL_SENDER:
        return mill_cont(ep, struct mill_chan_, sender);
    case MILL_RECEIVER:
        return mill_cont(ep, struct mill_chan_, receiver);
    default:
        assert(0);
    }
}
```

```c
// 创建一个chan
struct mill_chan_ *mill_chmake_(size_t sz, size_t bufsz, const char *created) {
    mill_preserve_debug();
    // 分配消息缓冲区的时候多申请一个元素空间用于存chdone()提交的数据，
    // chdone不能写消息缓冲区，因为会因为缓冲区满而阻塞chdone()操作，
    // libmill是单线程调度，一个阻塞就会导致整个进程被阻塞了
    struct mill_chan_ *ch = 
        (struct mill_chan_*)malloc(sizeof(struct mill_chan_) + (sz * (bufsz + 1)));
    if(!ch)
        return NULL;
    mill_register_chan(&ch->debug, created);
    // 初始化chan
    ch->sz = sz;
    ch->sender.type = MILL_SENDER;
    ch->sender.seqnum = mill_choose_seqnum;
    mill_list_init(&ch->sender.clauses);
    ch->receiver.type = MILL_RECEIVER;
    ch->receiver.seqnum = mill_choose_seqnum;
    mill_list_init(&ch->receiver.clauses);
    ch->refcount = 1;
    ch->done = 0;
    ch->bufsz = bufsz;
    ch->items = 0;
    ch->first = 0;
    mill_trace(created, "<%d>=chmake(%d)", (int)ch->debug.id, (int)bufsz);
    return ch;
}
```

```c
// dup操作，只是增加chan引用计数
struct mill_chan_ *mill_chdup_(struct mill_chan_ *ch, const char *current) {
    if(mill_slow(!ch))
        mill_panic("null channel used");
    mill_trace(current, "chdup(<%d>)", (int)ch->debug.id);
    ++ch->refcount;
    return ch;
}
```

```c
// 关闭chan，实际上减少引用计数直到为0再释放chan
void mill_chclose_(struct mill_chan_ *ch, const char *current) {
    if(mill_slow(!ch))
        mill_panic("null channel used");
    mill_trace(current, "chclose(<%d>)", (int)ch->debug.id);
    assert(ch->refcount > 0);
    --ch->refcount;
    if(ch->refcount)
        return;
    // 仍有依赖该chan的从句存在的话，关闭chan会出错
    if(!mill_list_empty(&ch->sender.clauses) ||
          !mill_list_empty(&ch->receiver.clauses))
        mill_panic("attempt to close a channel while it is still being used");
    mill_unregister_chan(&ch->debug);
    // 释放chan
    free(ch);
}
```

```c
// 唤醒一个因为调用mill_choose_wait而阻塞的协程
// 
// choose从句中协程因为等待io事件而阻塞，所以这里唤醒阻塞的协程也意味着要清除掉这里的从句
static void mill_choose_unblock(struct mill_clause *cl) {
    struct mill_slist_item *it;
    struct mill_clause *itcl;
    for(it = mill_slist_begin(&cl->cr->choosedata.clauses); it; it = mill_slist_next(it)) {
        itcl = mill_cont(it, struct mill_clause, chitem);
        // 如果当前从句不再当前chan的sender/receiver列表中则不予处理；
        // 已经在的话则要将该从句删除，正式因为这个从句的io事件使得协程被阻塞的
        if(!itcl->used)
            continue;
        mill_list_erase(&itcl->ep->clauses, &itcl->epitem);
    }
    // 如果有指定deadline，也删除对应的定时器
    if(cl->cr->choosedata.ddline >= 0)
        mill_timer_rm(&cl->cr->timer);
    // 恢复该协程的执行
    mill_resume(cl->cr, cl->idx);
}
```

```c
// choose语句初始化
static void mill_choose_init(const char *current) {
    mill_set_current(&mill_running->debug, current);
    mill_slist_init(&mill_running->choosedata.clauses);
    mill_running->choosedata.othws = 0;
    mill_running->choosedata.ddline = -1;
    mill_running->choosedata.available = 0;
    ++mill_choose_seqnum;
}

void mill_choose_init_(const char *current) {
    mill_trace(current, "choose()");
    mill_running->state = MILL_CHOOSE;
    mill_choose_init(current);
}
```

```c
// choose in从句
void mill_choose_in_(void *clause, struct mill_chan_ *ch, size_t sz, int idx) {
    if(mill_slow(!ch))
        mill_panic("null channel used");
    if(mill_slow(ch->sz != sz))
        mill_panic("receive of a type not matching the channel");
    // 检查当前从句对应的可读事件是否就绪，就绪则++available记录一下
    int available = ch->done || !mill_list_empty(&ch->sender.clauses) || ch->items ? 1 : 0;
    if(available)
        ++mill_running->choosedata.available;
    // 如果当前从句可读事件未就绪，但是当前运行协程中choose语句中有从句事件就绪，返回
    if(!available && mill_running->choosedata.available)
        return;
    /* Fill in the clause entry. */
    struct mill_clause *cl = (struct mill_clause*) clause;
    cl->cr = mill_running;
    cl->ep = &ch->receiver;
    cl->val = NULL;
    cl->idx = idx;
    cl->available = available;
    cl->used = 1;
    mill_slist_push_back(&mill_running->choosedata.clauses, &cl->chitem);
    if(cl->ep->seqnum == mill_choose_seqnum) {
        ++cl->ep->refs;
        return;
    }
    cl->ep->seqnum = mill_choose_seqnum;
    cl->ep->refs = 1;
    cl->ep->tmp = -1;
}

// choose out从句
void mill_choose_out_(void *clause, struct mill_chan_ *ch, void *val, size_t sz, int idx) {
    if(mill_slow(!ch))
        mill_panic("null channel used");
    // 调用了chdone的chan不能再执行写操作
    if(mill_slow(ch->done))
        mill_panic("send to done-with channel");
    if(mill_slow(ch->sz != sz))
        mill_panic("send of a type not matching the channel");
    // 检查chan上是否写就绪
    int available = !mill_list_empty(&ch->receiver.clauses) || ch->items < ch->bufsz ? 1 : 0;
    if(available)
        ++mill_running->choosedata.available;
    // 如果chan上没有写就绪事件，但是当前协程上有其他choose从句事件就绪，返回
    if(!available && mill_running->choosedata.available)
        return;
    /* Fill in the clause entry. */
    struct mill_clause *cl = (struct mill_clause*) clause;
    cl->cr = mill_running;
    cl->ep = &ch->sender;
    cl->val = val;
    cl->available = available;
    cl->idx = idx;
    cl->used = 1;
    mill_slist_push_back(&mill_running->choosedata.clauses, &cl->chitem);
    if(cl->ep->seqnum == mill_choose_seqnum) {
        ++cl->ep->refs;
        return;
    }
    cl->ep->seqnum = mill_choose_seqnum;
    cl->ep->refs = 1;
    cl->ep->tmp = -1;
}
```

```c
// choose从句deadline对应的超时回调，销毁所有的choose从句并resume协程
static void mill_choose_callback(struct mill_timer *timer) {
    struct mill_cr *cr = mill_cont(timer, struct mill_cr, timer);
    struct mill_slist_item *it;
    for(it = mill_slist_begin(&cr->choosedata.clauses); it; it = mill_slist_next(it)) {
        struct mill_clause *itcl = mill_cont(it, struct mill_clause, chitem);
        mill_assert(itcl->used);
        mill_list_erase(&itcl->ep->clauses, &itcl->epitem);
    }
    mill_resume(cr, -1);
}

// choose deadline从句
void mill_choose_deadline_(int64_t ddline) {
    if(mill_slow(mill_running->choosedata.othws || mill_running->choosedata.ddline >= 0))
        mill_panic("multiple 'otherwise' or 'deadline' clauses in a choose statement");
    if(ddline < 0)
        return;
    mill_running->choosedata.ddline = ddline;
}

// choose otherwise从句
void mill_choose_otherwise_(void) {
    if(mill_slow(mill_running->choosedata.othws ||
          mill_running->choosedata.ddline >= 0))
        mill_panic("multiple 'otherwise' or 'deadline' clauses in a choose statement");
    mill_running->choosedata.othws = 1;
}

// 往chan追加数据val
static void mill_enqueue(struct mill_chan_ *ch, void *val) {
    // 如果chan上还有关联的receiver执行choose in从句，唤醒对应的协程收数据（当然先写数据再唤醒）
    if(!mill_list_empty(&ch->receiver.clauses)) {
        mill_assert(ch->items == 0);
        struct mill_clause *cl = mill_cont(
            mill_list_begin(&ch->receiver.clauses), struct mill_clause, epitem);
        // 写数据
        memcpy(mill_valbuf(cl->cr, ch->sz), val, ch->sz);
        // 唤醒收数据的协程
        mill_choose_unblock(cl);
        return;
    }
    // 只写数据
    assert(ch->items < ch->bufsz);
    size_t pos = (ch->first + ch->items) % ch->bufsz;
    memcpy(((char*)(ch + 1)) + (pos * ch->sz) , val, ch->sz);
    ++ch->items;
}

// 从chan中取队首的数据val
static void mill_dequeue(struct mill_chan_ *ch, void *val) {
    // 拿chan上sender的第一个choose out从句
    struct mill_clause *cl = mill_cont(
        mill_list_begin(&ch->sender.clauses), struct mill_clause, epitem);
    // chan中valbuf当前无数据可读
    if(!ch->items) {
        // 调用了chdone后肯定没有sender要发送数据了，直接拷走数据即可（chdone追加的）
        if(mill_slow(ch->done)) {
            mill_assert(!cl);
            memcpy(val, ((char*)(ch + 1)) + (ch->bufsz * ch->sz), ch->sz);
            return;
        }
        // 还没有调用chdone，直接从choose out从句中拷走数据，再唤醒因为执行choose out阻塞的协程
        mill_assert(cl);
        memcpy(val, cl->val, ch->sz);
        mill_choose_unblock(cl);
        return;
    }
    // chan中valbuf当前有数据可读
    // - 读取chan中的数据；
    // - 如果对应的choose out从句cl存在，则拷贝其数据到chan valbuf并唤醒执行该从句的协程
    memcpy(val, ((char*)(ch + 1)) + (ch->first * ch->sz), ch->sz);
    ch->first = (ch->first + 1) % ch->bufsz;
    --ch->items;
    if(cl) {
        assert(ch->items < ch->bufsz);
        size_t pos = (ch->first + ch->items) % ch->bufsz;
        memcpy(((char*)(ch + 1)) + (pos * ch->sz) , cl->val, ch->sz);
        ++ch->items;
        mill_choose_unblock(cl);
    }
}

// choose wait从句
int mill_choose_wait_(void) {
    struct mill_choosedata *cd = &mill_running->choosedata;
    struct mill_slist_item *it;
    struct mill_clause *cl;

    // 每个协程都有一个对应的choosedata数据结构
    //    
    // 如果当前有就绪的choose in/out从句，则选择一个并执行
    if(cd->available > 0) {
        // 只有1个就绪的choose从句直接去检查el->ep->type就知道干什么了
        // 如果有多个就绪的choose从句，随机选择一个就绪的从句去执行
        int chosen = cd->available == 1 ? 0 : (int)(random() % (cd->available));
        
        for(it = mill_slist_begin(&cd->clauses); it; it = mill_slist_next(it)) {
            cl = mill_cont(it, struct mill_clause, chitem);
            if(!cl->available)
                continue;
            if(!chosen)
                break;
            --chosen;
        }
        struct mill_chan_ *ch = mill_getchan(cl->ep);
        // 根据choose从句类型决定是向chan发送数据，还是从chan读取数据
        if(cl->ep->type == MILL_SENDER)
            mill_enqueue(ch, cl->val);
        else
            mill_dequeue(ch, mill_valbuf(cl->cr, ch->sz));
        mill_resume(mill_running, cl->idx);
        return mill_suspend();
    }

    // 如果没有choose in/out从句事件就绪但是有otherwise从句，直接执行otherwise从句
    // - 这里实际上相当于将当前运行的协程重新加入调度队列，然后主动挂起当前协程
    if(cd->othws) {
        mill_resume(mill_running, -1);
        return mill_suspend();
    }

    // 如果指定了deadline从句，为其启动一个定时器，并绑定超时回调
    if(cd->ddline >= 0)
        mill_timer_add(&mill_running->timer, cd->ddline, mill_choose_callback);

    // 其他情况下，将当前协程和被查询的chan进行注册，等到直到有一个choose从句unblock
    for(it = mill_slist_begin(&cd->clauses); it; it = mill_slist_next(it)) {
        cl = mill_cont(it, struct mill_clause, chitem);
        if(mill_slow(cl->ep->refs > 1)) {
            if(cl->ep->tmp == -1)
                cl->ep->tmp =
                    cl->ep->refs == 1 ? 0 : (int)(random() % cl->ep->refs);
            if(cl->ep->tmp) {
                --cl->ep->tmp;
                cl->used = 0;
                continue;
            }
            cl->ep->tmp = -2;
        }
        mill_list_insert(&cl->ep->clauses, &cl->epitem, NULL);
    }
    // 如果有多个协程并发的执行chdone，只可能有一个执行成功，其他的都必须阻塞在下面这行
    return mill_suspend();
}

// 获取正在运行的协程的chan数据存储缓冲区valbuf
void *mill_choose_val_(size_t sz) {
    return mill_valbuf(mill_running, sz);
}

// 向chan中发送数据
void mill_chs_(struct mill_chan_ *ch, void *val, size_t sz,
      const char *current) {
    if(mill_slow(!ch))
        mill_panic("null channel used");
    mill_trace(current, "chs(<%d>)", (int)ch->debug.id);
    mill_choose_init(current);
    mill_running->state = MILL_CHS;
    struct mill_clause cl;
    mill_choose_out_(&cl, ch, val, sz, 0);
    mill_choose_wait_();
}

// 从chan中接收数据
void *mill_chr_(struct mill_chan_ *ch, size_t sz, const char *current) {
    if(mill_slow(!ch))
        mill_panic("null channel used");
    mill_trace(current, "chr(<%d>)", (int)ch->debug.id);
    mill_running->state = MILL_CHR;
    mill_choose_init(current);
    struct mill_clause cl;
    mill_choose_in_(&cl, ch, sz, 0);
    mill_choose_wait_();
    return mill_choose_val_(sz);
}

// chan上的chdone操作
void mill_chdone_(struct mill_chan_ *ch, void *val, size_t sz,
      const char *current) {
    if(mill_slow(!ch))
        mill_panic("null channel used");
    mill_trace(current, "chdone(<%d>)", (int)ch->debug.id);
    if(mill_slow(ch->done))
        mill_panic("chdone on already done-with channel");
    if(mill_slow(ch->sz != sz))
        mill_panic("send of a type not matching the channel");
    /* Panic if there are other senders on the same channel. */
    if(mill_slow(!mill_list_empty(&ch->sender.clauses)))
        mill_panic("send to done-with channel");
    /* Put the channel into done-with mode. */
    ch->done = 1;
    
    // 在valbuf末尾再追加一个元素，不能chs往valbuf中写因为这样没有receiver的情况下会阻塞
    memcpy(((char*)(ch + 1)) + (ch->bufsz * ch->sz) , val, ch->sz);
    
    // 追加上述一个多余的元素后，需要唤醒chan上所有等待的receiver
    while(!mill_list_empty(&ch->receiver.clauses)) {
        struct mill_clause *cl = mill_cont(
            mill_list_begin(&ch->receiver.clauses), struct mill_clause, epitem);
        memcpy(mill_valbuf(cl->cr, ch->sz), val, ch->sz);
        mill_choose_unblock(cl);
    }
}
```

## 3.4 cr

### 3.4.1 cr.h

```c
// coroutine state
enum mill_state {
    MILL_READY,         //可以被调度
    MILL_MSLEEP,        //mill_suspend挂起等待mill_resume唤醒
    MILL_FDWAIT,        //mill_fdwait_，等待mill_poller_wait或者timer回调唤醒
    MILL_CHR,           //...
    MILL_CHS,           //...
    MILL_CHOOSE         //...
};

/* 
   协程内存布局如下：
   +----------------------------------------------------+--------+---------+
   |                                              stack | valbuf | mill_cr |
   +----------------------------------------------------+--------+---------+
   - mill_cr：包括coroutine的通用信息
   - valbuf：临时存储从chan中接收到的数据
   - stack：标准的c程序栈，栈从高地址向低地址方向增长
*/
struct mill_cr {
    // 协程状态，用于调试目的
    enum mill_state state;

    // 协程如果没有阻塞并且等待执行，会被加入到ready队列中，并设置is_ready=1；
    // 反之，设置is_ready=0，不加入ready队列中
    int is_ready;
    struct mill_slist_item ready;

    // 如果协程需要等待一个截止时间，就需要下面的定时器来实现超时回调
    struct mill_timer timer;

    // 协程在fdwait中等待fd上的io事件就绪，若fd为-1表示当前协程没关注特定fd上的io事件
    int fd;

    // 协程在fdwait中等待fd上的io就绪事件events，用于调试目的
    int events;

    // 协程执行choose语句时要使用的结构体
    struct mill_choosedata choosedata;

    // 协程暂停、恢复执行的时候需要保存、还原其上下文信息
#if defined(__x86_64__)
    uint64_t ctx[10];
#else
    sigjmp_buf ctx;
#endif

    // suspend挂起协程后resume恢复协程执行，resume第二个参数result会被设置到cr->result成员；
    // 其他协程suspend并切换到被resumed的线程时会return mill_running->result
    int result;

    // 如果协程需要的valbuf比预设的mill_valbuf要大的话，那就得从heap中动态分配；
    // 分配的内存空间地址、尺寸记录在这两个成员中
    void *valbuf;
    size_t valbuf_sz;

    // 协程本地存储（有点类似线程local存储）
    void *clsval;

#if defined MILL_VALGRIND
    /* Valgrind stack identifier. */
    int sid;
#endif

    // 调试信息
    struct mill_debug_cr debug;
};

// 主线程对应的假的coroutine
extern struct mill_cr mill_main;

// 记录当前正在运行的协程
extern struct mill_cr *mill_running;

// 挂起当前正在运行的协程，并切换到一个不同的is_ready=1的协程取运行；
// 一旦某个协程resume这个被挂起的协程，resume中传递的参数result将被该suspend函数返回
int mill_suspend(void);

// 调度之前被挂起的协程cr恢复执行，其实只是将其加入ready队列等待被调度而已
void mill_resume(struct mill_cr *cr, int result);

// 返回一个执行协程临时数据区valbuf的指针，返回的数据区容量至少为size bytes
void *mill_valbuf(struct mill_cr *cr, size_t size);

// 子进程中调用，目的是为了停止运行从父进程继承的协程
void mill_cr_postfork(void);
```

### 3.4.2 cr.c

```c
// 协程临时数据区valbuf的大小，这里的临时数据区应该合理对齐；
// 如果当前有任何分配的协程栈，就不应该改变这里的尺寸，可能会影响到协程不同内存区域的计算
size_t mill_valbuf_size = 128;

// 主线程这个假协程对应的valbuf
char mill_main_valbuf[128];

volatile int mill_unoptimisable1_ = 1;
volatile void *mill_unoptimisable2_ = NULL;

// 主协程
struct mill_cr mill_main = {0};

// 默认当前正在运行的协程就是mill_run
struct mill_cr *mill_running = &mill_main;

// 等待被调度的就绪协程队列
struct mill_slist mill_ready = {0};

// 返回当前上下文信息
inline mill_ctx mill_getctx_(void) {
#if defined __x86_64__
    return mill_running->ctx;
#else
    return &mill_running->ctx;
#endif
}

// 返回协程临时数据区valbuf的起始地址
static void *mill_getvalbuf(struct mill_cr *cr, size_t size) {
    // 如果请求较小的valbuf则不需要在heap上动态分配
    // 另外要注意主协程没有为其分配栈，但是单独为其分配了valbuf
    if(mill_fast(cr != &mill_main)) {
        if(mill_fast(size <= mill_valbuf_size))
            return (void*)(((char*)cr) - mill_valbuf_size);
    }
    else {
        if(mill_fast(size <= sizeof(mill_main_valbuf)))
            return (void*)mill_main_valbuf;
    }
    // 如果请求较大的valbuf则需要在heap上动态分配，fixme!!!
    if(mill_fast(cr->valbuf && cr->valbuf_sz <= size))
        return cr->valbuf;
    void *ptr = realloc(cr->valbuf, size);
    if(!ptr)
        return NULL;
    cr->valbuf = ptr;
    cr->valbuf_sz = size;
    return cr->valbuf;
}

// 预准备count个协程，并分别初始化其栈尺寸、valbuf、valbuf_sz
void mill_goprepare_(int count, size_t stack_size, size_t val_size) {
    if(mill_slow(mill_hascrs())) {errno = EAGAIN; return;}
    // poller初始化
    mill_poller_init();
    if(mill_slow(errno != 0)) return;
    // 可能的话尅设置val_size稍微大一点以便能合理内存对齐
    mill_valbuf_size = (val_size + 15) & ~((size_t)0xf);
    // 为主协程（假的）分配valbuf
    if(mill_slow(!mill_getvalbuf(&mill_main, mill_valbuf_size))) {
        errno = ENOMEM;
        return;
    }
    // 为协程分配栈（这里分配时计算了stack+valbuf+mill_cr，是一个完整协程的内存空间大小）
    mill_preparestacks(count, stack_size + mill_valbuf_size + sizeof(struct mill_cr));
}

// 挂起当前正在运行的协程，并切换到一个is_ready=1的协程上去执行
// 被挂起的协程需要另一个协程调用resume(cr, result)方法来恢复其执行，恢复后suspend将返回result
int mill_suspend(void) {
    /* Even if process never gets idle, we have to process external events
       once in a while. The external signal may very well be a deadline or
       a user-issued command that cancels the CPU intensive operation. */
    static int counter = 0;
    if(counter >= 103) {
        mill_wait(0);
        counter = 0;
    }
    // 保存当前协程运行时的上下文信息
    if(mill_running) {
        mill_ctx ctx = mill_getctx_();
        if (mill_setjmp_(ctx))
            return mill_running->result;
    }
    while(1) {
        // 寻找一个is_ready=1的可运行的协程并恢复其执行
        if(!mill_slist_empty(&mill_ready)) {
            ++counter;
            struct mill_slist_item *it = mill_slist_pop(&mill_ready);
            mill_running = mill_cont(it, struct mill_cr, ready);
            mill_assert(mill_running->is_ready == 1);
            mill_running->is_ready = 0;
            mill_longjmp_(mill_getctx_());
        }
        // 找不到就要wait，可能要挂起当前协程直到被外部事件唤醒（io事件或者定时器超时）
        mill_wait(1);
        mill_assert(!mill_slist_empty(&mill_ready));
        counter = 0;
    }
}

// 恢复一个协程的运行，每个协程cr都在其内部保存了其运行时上下文信息
// 这里其实只是将其重新加入就绪队列等待被调度而已
inline void mill_resume(struct mill_cr *cr, int result) {
    mill_assert(!cr->is_ready);
    cr->result = result;
    cr->state = MILL_READY;
    cr->is_ready = 1;
    mill_slist_push_back(&mill_ready, &cr->ready);
}

/* mill_prologue_() and mill_epilogue_() live in the same scope with
   libdill's stack-switching black magic. As such, they are extremely
   fragile. Therefore, the optimiser is prohibited to touch them. */
#if defined __clang__
#define dill_noopt __attribute__((optnone))
#elif defined __GNUC__
#define dill_noopt __attribute__((optimize("O0")))
#else
#error "Unsupported compiler!"
#endif

// go()开始部分，启动一个新的协程，返回指向栈顶的指针
__attribute__((noinline)) dill_noopt 
void *mill_prologue_(const char *created) {
    // 先从cache中取，取不到动态分配
    struct mill_cr *cr = ((struct mill_cr*)mill_allocstack(NULL)) - 1;
    mill_register_cr(&cr->debug, created);
    cr->is_ready = 0;
    cr->valbuf = NULL;
    cr->valbuf_sz = 0;
    cr->clsval = NULL;
    cr->timer.expiry = -1;
    cr->fd = -1;
    cr->events = 0;
    // 挂起父协程并调度新创建的协程来运行
    mill_resume(mill_running, 0); 
    mill_running = cr;
    // 计算返回valbuf栈顶尺寸
    return (void*)(((char*)cr) - mill_valbuf_size);
}

// go结束部分，协程结束的时候执行清零动作
__attribute__((noinline)) dill_noopt
void mill_epilogue_(void) {
    mill_trace(NULL, "go() done");
    mill_unregister_cr(&mill_running->debug);
    if(mill_running->valbuf)
        free(mill_running->valbuf);
#if defined MILL_VALGRIND
    //......
#endif
    mill_freestack(mill_running + 1);
    mill_running = NULL;
    // 考虑到这里没有运行中的协程了，所以mill_suspend永远不会返回了
    mill_suspend();
}

void mill_yield_(const char *current) {
    mill_trace(current, "yield()");
    mill_set_current(&mill_running->debug, current);
    // 这里看起来有点可疑，但是没问题，我们可以在挂起一个协程之前就resume它来执行；
    // 这样做的目的是为了suspend之后能够使该协程重新获得被调度执行的机会
    mill_resume(mill_running, 0);
    mill_suspend();
}

// 返回valbuf起始地址
void *mill_valbuf(struct mill_cr *cr, size_t size) {
    void *ptr = mill_getvalbuf(cr, size);
    if(!ptr)
        mill_panic("not enough memory to receive from channel");
    return ptr;
}

// 返回协程本地存储指针
void *mill_cls_(void) {
    return mill_running->clsval;
}

// 设置协程本地存储操作
void mill_setcls_(void *val) {
    mill_running->clsval = val;
}

// fork之后子进程清空就绪协程队列列表
void mill_cr_postfork(void) {
    /* Drop all coroutines in the "ready to execute" list. */
    mill_slist_init(&mill_ready);
}
```

## 3.5 mfork

```c
// 创建子进程
pid_t mill_mfork_(void) {
    pid_t pid = fork();
    if(pid != 0) {
        // 父进程
        return pid;
    }
    // 子进程，这里会对子进程进行一些特殊的处理
    // 包括重新初始化协程队列mill_ready、fd监听pollset、定时器timers list
    mill_cr_postfork();
    mill_poller_postfork();
    mill_timer_postfork();
    return 0;
}
```

# 4 Network

## 4.1 tcp

```c
// tcp接收缓冲大小
// 根据Ethernet MTU（1500字节）进行配置的，小了不是最优但是大了也没有实质好处
// 这里设置的小一点以满足IPv4/IPv6的headers，多省几个字节出来可以控制IP、TCP选项
#ifndef MILL_TCP_BUFLEN
#define MILL_TCP_BUFLEN (1500 - 68)
#endif

// tcp socket 类型
enum mill_tcptype {
   MILL_TCPLISTENER,
   MILL_TCPCONN
};

struct mill_tcpsock_ {
    enum mill_tcptype type;
};

// tcp listen socket
struct mill_tcplistener {
    struct mill_tcpsock_ sock;
    int fd;
    int port;
};

// tcp conn socket
struct mill_tcpconn {
    struct mill_tcpsock_ sock;
    int fd;
    size_t ifirst;  // 接收缓冲区剩余数据的起始位置
    size_t ilen;    // 接收缓冲区剩余数据的长度
    size_t olen;    // 发送缓冲区剩余数据的长度
    char ibuf[MILL_TCP_BUFLEN]; // 接收缓冲区
    char obuf[MILL_TCP_BUFLEN]; // 发送缓冲区
    ipaddr addr;    // peer socket地址
};

// tcp socket tune（设为非阻塞模式、地址立即可重用(主动关闭不进入timed wait）、屏蔽SIGPIPE）
static void mill_tcptune(int s) {
    /* Make the socket non-blocking. */
    int opt = fcntl(s, F_GETFL, 0);
    if (opt == -1)
        opt = 0;
    int rc = fcntl(s, F_SETFL, opt | O_NONBLOCK);
    mill_assert(rc != -1);
    /*  Allow re-using the same local address rapidly. */
    opt = 1;
    rc = setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof (opt));
    mill_assert(rc == 0);
    /* If possible, prevent SIGPIPE signal when writing to the connection
        already closed by the peer. */
#ifdef SO_NOSIGPIPE
    opt = 1;
    rc = setsockopt (s, SOL_SOCKET, SO_NOSIGPIPE, &opt, sizeof (opt));
    mill_assert (rc == 0 || errno == EINVAL);
#endif
}

// tcp conn socket 初始化
static void tcpconn_init(struct mill_tcpconn *conn, int fd) {
    conn->sock.type = MILL_TCPCONN;
    conn->fd = fd;
    conn->ifirst = 0;
    conn->ilen = 0;
    conn->olen = 0;
}

// tcp listen socket 初始化（非阻塞socket）
struct mill_tcpsock_ *mill_tcplisten_(ipaddr addr, int backlog) {
    /* Open the listening socket. */
    int s = socket(mill_ipfamily(addr), SOCK_STREAM, 0);
    if(s == -1)
        return NULL;
    mill_tcptune(s);

    /* Start listening. */
    int rc = bind(s, (struct sockaddr*)&addr, mill_iplen(addr));
    if(rc != 0)
        return NULL;
    rc = listen(s, backlog);
    if(rc != 0)
        return NULL;

    // 如果参数addr中没有指定port信息，bind的时候os回自动分配一个，这里需要获取分配的port
    int port = mill_ipport(addr);
    if(!port) {
        ipaddr baddr;
        socklen_t len = sizeof(ipaddr);
        rc = getsockname(s, (struct sockaddr*)&baddr, &len);
        if(rc == -1) {
            int err = errno;
            fdclean(s);
            close(s);
            errno = err;
            return NULL;
        }
        port = mill_ipport(baddr);
    }

    /* Create the object. */
    struct mill_tcplistener *l = malloc(sizeof(struct mill_tcplistener));
    if(!l) {
        fdclean(s);
        close(s);
        errno = ENOMEM;
        return NULL;
    }
    l->sock.type = MILL_TCPLISTENER;
    l->fd = s;
    l->port = port;
    errno = 0;
    return &l->sock;
}

// 获取peer socket对应的port信息（统一处理连接socket和监听socket）
int mill_tcpport_(struct mill_tcpsock_ *s) {
    if(s->type == MILL_TCPCONN) {
        struct mill_tcpconn *c = (struct mill_tcpconn*)s;
        return mill_ipport(c->addr);
    }
    else if(s->type == MILL_TCPLISTENER) {
        struct mill_tcplistener *l = (struct mill_tcplistener*)s;
        return l->port;
    }
    mill_assert(0);
}

// tcp listen socket 接受一个连接（非阻塞方式accept，tcp conn socket设为非阻塞）
struct mill_tcpsock_ *mill_tcpaccept_(struct mill_tcpsock_ *s, int64_t deadline) {
    if(s->type != MILL_TCPLISTENER)
        mill_panic("trying to accept on a socket that isn't listening");
    struct mill_tcplistener *l = (struct mill_tcplistener*)s;
    socklen_t addrlen;
    ipaddr addr;
    while(1) {
        /* Try to get new connection (non-blocking). */
        addrlen = sizeof(addr);
        int as = accept(l->fd, (struct sockaddr *)&addr, &addrlen);
        if (as >= 0) {
            mill_tcptune(as);
            struct mill_tcpconn *conn = malloc(sizeof(struct mill_tcpconn));
            if(!conn) {
                fdclean(as);
                close(as);
                errno = ENOMEM;
                return NULL;
            }
            tcpconn_init(conn, as);
            conn->addr = addr;
            errno = 0;
            return (tcpsock)conn;
        }
        mill_assert(as == -1);
        if(errno != EAGAIN && errno != EWOULDBLOCK)
            return NULL;
        /* Wait till new connection is available. */
        int rc = fdwait(l->fd, FDW_IN, deadline);
        if(rc == 0) {
            errno = ETIMEDOUT;
            return NULL;
        }
        if(rc & FDW_ERR)
            return NULL;
        mill_assert(rc == FDW_IN);
    }
}

// tcp conn socket 连接到指定地址（非阻塞方式）
struct mill_tcpsock_ *mill_tcpconnect_(ipaddr addr, int64_t deadline) {
    /* Open a socket. */
    int s = socket(mill_ipfamily(addr), SOCK_STREAM, 0);
    if(s == -1)
        return NULL;
    mill_tcptune(s);

    /* Connect to the remote endpoint. */
    int rc = connect(s, (struct sockaddr*)&addr, mill_iplen(addr));
    if(rc != 0) {
        mill_assert(rc == -1);
        if(errno != EINPROGRESS)
            return NULL;
        rc = fdwait(s, FDW_OUT, deadline);
        if(rc == 0) {
            errno = ETIMEDOUT;
            return NULL;
        }
        int err;
        socklen_t errsz = sizeof(err);
        rc = getsockopt(s, SOL_SOCKET, SO_ERROR, (void*)&err, &errsz);
        if(rc != 0) {
            err = errno;
            fdclean(s);
            close(s);
            errno = err;
            return NULL;
        }
        if(err != 0) {
            fdclean(s);
            close(s);
            errno = err;
            return NULL;
        }
    }

    /* Create the object. */
    struct mill_tcpconn *conn = malloc(sizeof(struct mill_tcpconn));
    if(!conn) {
        fdclean(s);
        close(s);
        errno = ENOMEM;
        return NULL;
    }
    tcpconn_init(conn, s);
    errno = 0;
    return (tcpsock)conn;
}

// tcp socket 发送（非阻塞方式）
size_t mill_tcpsend_(struct mill_tcpsock_ *s, const void *buf, size_t len, int64_t deadline) {
    if(s->type != MILL_TCPCONN)
        mill_panic("trying to send to an unconnected socket");
    struct mill_tcpconn *conn = (struct mill_tcpconn*)s;

    // 如果发送缓冲区剩余空间可以容纳待发送数据，直接拷贝到发送缓冲
    if(conn->olen + len <= MILL_TCP_BUFLEN) {
        memcpy(&conn->obuf[conn->olen], buf, len);
        conn->olen += len;
        errno = 0;
        return len;
    }

    // 如果剩余空间不太够，则先发送完发送缓冲中的数据
    tcpflush(s, deadline);
    if(errno != 0)
        return 0;

    // tcpflush不一定全部发送完（如超时返回）
    // 继续检查剩余空间是不是够容纳带发送缓冲，可以则直接拷贝到发送缓冲
    if(conn->olen + len <= MILL_TCP_BUFLEN) {
        memcpy(&conn->obuf[conn->olen], buf, len);
        conn->olen += len;
        errno = 0;
        return len;
    }

    // 尝试tcpflush之后发送缓冲还是不够大则直接就地发送，即以指定buf为发送缓冲进行发送
    char *pos = (char*)buf;
    size_t remaining = len;
    while(remaining) {
        ssize_t sz = send(conn->fd, pos, remaining, 0);
        if(sz == -1) {
            /* Operating systems are inconsistent w.r.t. returning EPIPE and
               ECONNRESET. Let's paper over it like this. */
            if(errno == EPIPE) {
                errno = ECONNRESET;
                return 0;
            }
            if(errno != EAGAIN && errno != EWOULDBLOCK)
                return 0;
            int rc = fdwait(conn->fd, FDW_OUT, deadline);
            if(rc == 0) {
                errno = ETIMEDOUT;
                return len - remaining;
            }
            continue;
        }
        pos += sz;
        remaining -= sz;
    }
    errno = 0;
    return len;
}

// tcp conn socket flush发送缓冲数据（非阻塞方式）
void mill_tcpflush_(struct mill_tcpsock_ *s, int64_t deadline) {
    if(s->type != MILL_TCPCONN)
        mill_panic("trying to send to an unconnected socket");
    struct mill_tcpconn *conn = (struct mill_tcpconn*)s;
    if(!conn->olen) {
        errno = 0;
        return;
    }
    char *pos = conn->obuf;
    size_t remaining = conn->olen;
    while(remaining) {
        ssize_t sz = send(conn->fd, pos, remaining, 0);
        if(sz == -1) {
            /* Operating systems are inconsistent w.r.t. returning EPIPE and
               ECONNRESET. Let's paper over it like this. */
            if(errno == EPIPE) {
                errno = ECONNRESET;
                return;
            }
            if(errno != EAGAIN && errno != EWOULDBLOCK)
                return;
            int rc = fdwait(conn->fd, FDW_OUT, deadline);
            if(rc == 0) {
                errno = ETIMEDOUT;
                return;
            }
            continue;
        }
        pos += sz;
        remaining -= sz;
    }
    conn->olen = 0;
    errno = 0;
}

// tcp conn socket 接收数据（非阻塞方式）
size_t mill_tcprecv_(struct mill_tcpsock_ *s, void *buf, size_t len, int64_t deadline) {
    if(s->type != MILL_TCPCONN)
        mill_panic("trying to receive from an unconnected socket");
    struct mill_tcpconn *conn = (struct mill_tcpconn*)s;

    // 如果接收缓冲中有足够多数据，则直接返回len长度的数据给buf
    if(conn->ilen >= len) {
        memcpy(buf, &conn->ibuf[conn->ifirst], len);
        conn->ifirst += len;
        conn->ilen -= len;
        errno = 0;
        return len;
    }

    // 接收缓冲中数据少于请求数据量，先拷贝已接收的部分，再继续接收数据
    char *pos = (char*)buf;
    size_t remaining = len;
    memcpy(pos, &conn->ibuf[conn->ifirst], conn->ilen);
    pos += conn->ilen;
    remaining -= conn->ilen;
    conn->ifirst = 0;
    conn->ilen = 0;

    // 继续接收剩余数据
    mill_assert(remaining);
    while(1) {

        if(remaining > MILL_TCP_BUFLEN) {
            // 如果请求数据量大于tcp接收缓冲大小，为了减少系统调用次数直接就地recv
            ssize_t sz = recv(conn->fd, pos, remaining, 0);
            if(!sz) {
		        errno = ECONNRESET;
		        return len - remaining;
            }
            if(sz == -1) {
                if(errno != EAGAIN && errno != EWOULDBLOCK)
                    return len - remaining;
                sz = 0;
            }
            if((size_t)sz == remaining) {
                errno = 0;
                return len;
            }
            pos += sz;
            remaining -= sz;
        }
        else {
            // 剩余请求数据量小于接收缓存大小，但是仍按MILL_TCP_BUFLEN进行接收，
            // 这样可以减少后续mill_tcprecv时调用系统调用recv的次数
            ssize_t sz = recv(conn->fd, conn->ibuf, MILL_TCP_BUFLEN, 0);
            if(!sz) {
		        errno = ECONNRESET;
		        return len - remaining;
            }
            if(sz == -1) {
                if(errno != EAGAIN && errno != EWOULDBLOCK)
                    return len - remaining;
                sz = 0;
            }
            if((size_t)sz < remaining) {
                memcpy(pos, conn->ibuf, sz);
                pos += sz;
                remaining -= sz;
                conn->ifirst = 0;
                conn->ilen = 0;
            }
            else {
                memcpy(pos, conn->ibuf, remaining);
                conn->ifirst = remaining;
                conn->ilen = sz - remaining;
                errno = 0;
                return len;
            }
        }

        // 等待数据可读事件就绪，继续读取更多数据
        int res = fdwait(conn->fd, FDW_IN, deadline);
        if(!res) {
            errno = ETIMEDOUT;
            return len - remaining;
        }
    }
}

// tcp conn socket 接收数据（遇到指定分界符会停止接收数据，非阻塞工作方式）
size_t mill_tcprecvuntil_(struct mill_tcpsock_ *s, void *buf, size_t len,
      const char *delims, size_t delimcount, int64_t deadline) {
    if(s->type != MILL_TCPCONN)
        mill_panic("trying to receive from an unconnected socket");
    char *pos = (char*)buf;
    size_t i;
    for(i = 0; i != len; ++i, ++pos) {
        size_t res = tcprecv(s, pos, 1, deadline);
        if(res == 1) {
            size_t j;
            for(j = 0; j != delimcount; ++j)
                if(*pos == delims[j])
                    return i + 1;
        }
        if (errno != 0)
            return i + res;
    }
    errno = ENOBUFS;
    return len;
}

// tcp conn socket 关闭（读关闭或写关闭或both）
void mill_tcpshutdown_(struct mill_tcpsock_ *s, int how) {
    mill_assert(s->type == MILL_TCPCONN);
    struct mill_tcpconn *c = (struct mill_tcpconn*)s;
    int rc = shutdown(c->fd, how);
    mill_assert(rc == 0 || errno == ENOTCONN);
}

// tcp socket 关闭（统一处理listen socket和conn socket）
void mill_tcpclose_(struct mill_tcpsock_ *s) {
    if(s->type == MILL_TCPLISTENER) {
        struct mill_tcplistener *l = (struct mill_tcplistener*)s;
        fdclean(l->fd);
        int rc = close(l->fd);
        mill_assert(rc == 0);
        free(l);
        return;
    }
    if(s->type == MILL_TCPCONN) {
        struct mill_tcpconn *c = (struct mill_tcpconn*)s;
        fdclean(c->fd);
        int rc = close(c->fd);
        mill_assert(rc == 0);
        free(c);
        return;
    }
    mill_assert(0);
}

// 获取tcp连接peer socket地址
ipaddr mill_tcpaddr_(struct mill_tcpsock_ *s) {
    if(s->type != MILL_TCPCONN)
        mill_panic("trying to get address from a socket that isn't connected");
    struct mill_tcpconn *l = (struct mill_tcpconn *)s;
    return l->addr;
}

/* This function is to be used only internally by libmill. Take into account
   that once there are data in tcpsock's tx/rx buffers, the state of fd may
   not match the state of tcpsock object. Works only on connected sockets. */
int mill_tcpfd(struct mill_tcpsock_ *s) {
    return ((struct mill_tcpconn*)s)->fd;
}
```

## 4.2 udp

```c
// udp socket
struct mill_udpsock_ {
    int fd;
    int port;
};

// udp socket tune（设置为nonblocking）
static void mill_udptune(int s) {
    /* Make the socket non-blocking. */
    int opt = fcntl(s, F_GETFL, 0);
    if (opt == -1)
        opt = 0;
    int rc = fcntl(s, F_SETFL, opt | O_NONBLOCK);
    mill_assert(rc != -1);
}

// udp listen socket 创建（socket为非阻塞）
struct mill_udpsock_ *mill_udplisten_(ipaddr addr) {
    /* Open the listening socket. */
    int s = socket(mill_ipfamily(addr), SOCK_DGRAM, 0);
    if(s == -1)
        return NULL;
    mill_udptune(s);

    /* Start listening. */
    int rc = bind(s, (struct sockaddr*)&addr, mill_iplen(addr));
    if(rc != 0)
        return NULL;

    // 参数addr中可能没有指定port信息（用户可能希望监听指定ip、自动分配的port），
    // 此时需要获取os自动分配的port信息
    int port = mill_ipport(addr);
    if(!port) {
        ipaddr baddr;
        socklen_t len = sizeof(ipaddr);
        rc = getsockname(s, (struct sockaddr*)&baddr, &len);
        if(rc == -1) {
            int err = errno;
            fdclean(s);
            close(s);
            errno = err;
            return NULL;
        }
        port = mill_ipport(baddr);
    }

    /* Create the object. */
    struct mill_udpsock_ *us = malloc(sizeof(struct mill_udpsock_));
    if(!us) {
        fdclean(s);
        close(s);
        errno = ENOMEM;
        return NULL;
    }
    us->fd = s;
    us->port = port;
    errno = 0;
    return us;
}

// unix socket 获取绑定的port
int mill_udpport_(struct mill_udpsock_ *s) {
    return s->port;
}

// udp socket 发送（socket需提前设置为非阻塞方式）
void mill_udpsend_(struct mill_udpsock_ *s, ipaddr addr, const void *buf, size_t len) {
    struct sockaddr *saddr = (struct sockaddr*) &addr;
    ssize_t ss = sendto(s->fd, buf, len, 0, saddr, saddr->sa_family ==
        AF_INET ? sizeof(struct sockaddr_in) : sizeof(struct sockaddr_in6));
    if(mill_fast(ss == (ssize_t)len)) {
        errno = 0;
        return;
    }
    mill_assert(ss < 0);
    if(errno == EAGAIN || errno == EWOULDBLOCK)
        errno = 0;
}

// udp socket 接收（socket需提前设置为非阻塞方式）
size_t mill_udprecv_(struct mill_udpsock_ *s, ipaddr *addr, void *buf, size_t len, int64_t deadline) {
    ssize_t ss;
    while(1) {
        socklen_t slen = sizeof(ipaddr);
        ss = recvfrom(s->fd, buf, len, 0, (struct sockaddr*)addr, &slen);
        if(ss >= 0)
            break;
        if(errno != EAGAIN && errno != EWOULDBLOCK)
            return 0;
        int rc = fdwait(s->fd, FDW_IN, deadline);
        if(rc == 0) {
            errno = ETIMEDOUT;
            return 0;
        }
    }
    errno = 0;
    return (size_t)ss;
}

// udp socket 关闭
void mill_udpclose_(struct mill_udpsock_ *s) {
    fdclean(s->fd);
    int rc = close(s->fd);
    mill_assert(rc == 0);
    free(s);
}
```

这里udp socket接收、发送之前需要自己显示地进行mill_udptune(int s)，这个感觉封装地不友好。

## 4.3 unix

```c
// unix socket接收缓冲大小
#ifndef MILL_UNIX_BUFLEN
#define MILL_UNIX_BUFLEN (4096)
#endif

// unix socket类型
enum mill_unixtype {
   MILL_UNIXLISTENER,
   MILL_UNIXCONN
};

// unix socket
struct mill_unixsock_ {
    enum mill_unixtype type;
};

// unix listen socket
struct mill_unixlistener {
    struct mill_unixsock_ sock;
    int fd;
};

// unix conn socket
struct mill_unixconn {
    struct mill_unixsock_ sock;
    int fd;
    size_t ifirst;  // 接收缓冲区中剩余数据起始位置
    size_t ilen;    // 接收缓冲区中剩余数据长度
    size_t olen;    // 发送缓冲区中剩余数据长度
    char ibuf[MILL_UNIX_BUFLEN];    // 接收缓冲区
    char obuf[MILL_UNIX_BUFLEN];    // 发送缓冲区
};

// unix socket tune (设为nonblocking & 屏蔽SIGPIPE)
static void mill_unixtune(int s) {
    /* Make the socket non-blocking. */
    int opt = fcntl(s, F_GETFL, 0);
    if (opt == -1)
        opt = 0;
    int rc = fcntl(s, F_SETFL, opt | O_NONBLOCK);
    mill_assert(rc != -1);
    /* If possible, prevent SIGPIPE signal when writing to the connection
        already closed by the peer. */
#ifdef SO_NOSIGPIPE
    opt = 1;
    rc = setsockopt (s, SOL_SOCKET, SO_NOSIGPIPE, &opt, sizeof (opt));
    mill_assert (rc == 0 || errno == EINVAL);
#endif
}

// unix socket 地址设置
static int mill_unixresolve(const char *addr, struct sockaddr_un *su) {
    mill_assert(su);
    if (strlen(addr) >= sizeof(su->sun_path)) {
        errno = EINVAL;
        return -1;
    }
    su->sun_family = AF_UNIX;
    strncpy(su->sun_path, addr, sizeof(su->sun_path));
    errno = 0;
    return 0;
}

// unix conn socket 初始化
static void unixconn_init(struct mill_unixconn *conn, int fd) {
    conn->sock.type = MILL_UNIXCONN;
    conn->fd = fd;
    conn->ifirst = 0;
    conn->ilen = 0;
    conn->olen = 0;
}

// unix listen socket 初始化
struct mill_unixsock_ *mill_unixlisten_(const char *addr, int backlog) {
    struct sockaddr_un su;
    int rc = mill_unixresolve(addr, &su);
    if (rc != 0) {
        return NULL;
    }
    /* Open the listening socket. */
    int s = socket(AF_UNIX, SOCK_STREAM, 0);
    if(s == -1)
        return NULL;
    mill_unixtune(s);

    /* Start listening. */
    rc = bind(s, (struct sockaddr*)&su, sizeof(struct sockaddr_un));
    if(rc != 0)
        return NULL;
    rc = listen(s, backlog);
    if(rc != 0)
        return NULL;

    /* Create the object. */
    struct mill_unixlistener *l = malloc(sizeof(struct mill_unixlistener));
    if(!l) {
        fdclean(s);
        close(s);
        errno = ENOMEM;
        return NULL;
    }
    l->sock.type = MILL_UNIXLISTENER;
    l->fd = s;
    errno = 0;
    return &l->sock;
}

// unix listen socket 接受一个连接请求（非阻塞方式）
struct mill_unixsock_ *mill_unixaccept_(struct mill_unixsock_ *s, int64_t deadline) {
    if(s->type != MILL_UNIXLISTENER)
        mill_panic("trying to accept on a socket that isn't listening");
    struct mill_unixlistener *l = (struct mill_unixlistener*)s;
    while(1) {
        /* Try to get new connection (non-blocking). */
        int as = accept(l->fd, NULL, NULL);
        if (as >= 0) {
            mill_unixtune(as);
            struct mill_unixconn *conn = malloc(sizeof(struct mill_unixconn));
            if(!conn) {
                fdclean(as);
                close(as);
                errno = ENOMEM;
                return NULL;
            }
            unixconn_init(conn, as);
            errno = 0;
            return (struct mill_unixsock_*)conn;
        }
        mill_assert(as == -1);
        if(errno != EAGAIN && errno != EWOULDBLOCK)
            return NULL;
        /* Wait till new connection is available. */
        int rc = fdwait(l->fd, FDW_IN, deadline);
        if(rc == 0) {
            errno = ETIMEDOUT;
            return NULL;
        }
        if(rc & FDW_ERR)
            return NULL;
        mill_assert(rc == FDW_IN);
    }
}

// unix socket 连接到服务地址（非阻塞方式）
struct mill_unixsock_ *mill_unixconnect_(const char *addr) {
    struct sockaddr_un su;
    int rc = mill_unixresolve(addr, &su);
    if (rc != 0) {
        return NULL;
    }

    /* Open a socket. */
    int s = socket(AF_UNIX,  SOCK_STREAM, 0);
    if(s == -1)
        return NULL;
    mill_unixtune(s);

    /* Connect to the remote endpoint. */
    rc = connect(s, (struct sockaddr*)&su, sizeof(struct sockaddr_un));
    if(rc != 0) {
        int err = errno;
        mill_assert(rc == -1);
        fdclean(s);
        close(s);
        errno = err;
        return NULL;
    }

    /* Create the object. */
    struct mill_unixconn *conn = malloc(sizeof(struct mill_unixconn));
    if(!conn) {
        fdclean(s);
        close(s);
        errno = ENOMEM;
        return NULL;
    }
    unixconn_init(conn, s);
    errno = 0;
    return (struct mill_unixsock_*)conn;
}

// 创建 unix socket pair （非阻塞方式）
void mill_unixpair_(struct mill_unixsock_ **a, struct mill_unixsock_ **b) {
    if(!a || !b) {
        errno = EINVAL;
        return;
    }
    int fd[2];
    int rc = socketpair(AF_UNIX, SOCK_STREAM, 0, fd);
    if (rc != 0)
        return;
    mill_unixtune(fd[0]);
    mill_unixtune(fd[1]);
    struct mill_unixconn *conn = malloc(sizeof(struct mill_unixconn));
    if(!conn) {
        fdclean(fd[0]);
        close(fd[0]);
        fdclean(fd[1]);
        close(fd[1]);
        errno = ENOMEM;
        return;
    }
    unixconn_init(conn, fd[0]);
    *a = (struct mill_unixsock_*)conn;
    conn = malloc(sizeof(struct mill_unixconn));
    if(!conn) {
        free(*a);
        fdclean(fd[0]);
        close(fd[0]);
        fdclean(fd[1]);
        close(fd[1]);
        errno = ENOMEM;
        return;
    }
    unixconn_init(conn, fd[1]);
    *b = (struct mill_unixsock_*)conn;
    errno = 0;
}

// unix socket send（非阻塞方式）
size_t mill_unixsend_(struct mill_unixsock_ *s, const void *buf, size_t len, int64_t deadline) {
    if(s->type != MILL_UNIXCONN)
        mill_panic("trying to send to an unconnected socket");
    struct mill_unixconn *conn = (struct mill_unixconn*)s;

    // 如果输出缓冲中剩余空间可以容纳待发送数据，则将待发送数据直接拷贝到输出缓冲
    if(conn->olen + len <= MILL_UNIX_BUFLEN) {
        memcpy(&conn->obuf[conn->olen], buf, len);
        conn->olen += len;
        errno = 0;
        return len;
    }

    // 如果输出缓冲剩余空间不能容纳待发送数据，则先发送输出缓冲中数据腾空间
    unixflush(s, deadline);
    if(errno != 0)
        return 0;

    // unixflush不一定把数据发送完（超时返回情况下），需再次检查剩余空间是否能容纳待发送数据，
    // 能容纳则直接将待发送数据拷贝到输出缓冲区中
    if(conn->olen + len <= MILL_UNIX_BUFLEN) {
        memcpy(&conn->obuf[conn->olen], buf, len);
        conn->olen += len;
        errno = 0;
        return len;
    }

    // 经过上述unixflush处理后，发送缓冲区还是无法容纳下待发送数据，则直接就地发送待发送数据
    char *pos = (char*)buf;
    size_t remaining = len;
    while(remaining) {
        ssize_t sz = send(conn->fd, pos, remaining, 0);
        if(sz == -1) {
            /* Operating systems are inconsistent w.r.t. returning EPIPE and
               ECONNRESET. Let's paper over it like this. */
            if(errno == EPIPE) {
                errno = ECONNRESET;
                return 0;
            }
            if(errno != EAGAIN && errno != EWOULDBLOCK)
                return 0;
            int rc = fdwait(conn->fd, FDW_OUT, deadline);
            if(rc == 0) {
                errno = ETIMEDOUT;
                return len - remaining;
            }
            continue;
        }
        pos += sz;
        remaining -= sz;
    }
    errno = 0;
    return len;
}

// unix socket 将发送缓冲区中的数据发送出去（非阻塞方式，超时返回停止发送）
void mill_unixflush_(struct mill_unixsock_ *s, int64_t deadline) {
    if(s->type != MILL_UNIXCONN)
        mill_panic("trying to send to an unconnected socket");
    struct mill_unixconn *conn = (struct mill_unixconn*)s;
    if(!conn->olen) {
        errno = 0;
        return;
    }
    char *pos = conn->obuf;
    size_t remaining = conn->olen;
    while(remaining) {
        ssize_t sz = send(conn->fd, pos, remaining, 0);
        if(sz == -1) {
            /* Operating systems are inconsistent w.r.t. returning EPIPE and
               ECONNRESET. Let's paper over it like this. */
            if(errno == EPIPE) {
                errno = ECONNRESET;
                return;
            }
            if(errno != EAGAIN && errno != EWOULDBLOCK)
                return;
            int rc = fdwait(conn->fd, FDW_OUT, deadline);
            if(rc == 0) {
                errno = ETIMEDOUT;
                return;
            }
            continue;
        }
        pos += sz;
        remaining -= sz;
    }
    conn->olen = 0;
    errno = 0;
}

// unix socket recv（非阻塞方式）
size_t mill_unixrecv_(struct mill_unixsock_ *s, void *buf, size_t len, int64_t deadline) {
    if(s->type != MILL_UNIXCONN)
        mill_panic("trying to receive from an unconnected socket");
    struct mill_unixconn *conn = (struct mill_unixconn*)s;

    // 如果接收缓冲区中有足够的数据，直接拷贝到用户指定buf即可
    if(conn->ilen >= len) {
        memcpy(buf, &conn->ibuf[conn->ifirst], len);
        conn->ifirst += len;
        conn->ilen -= len;
        errno = 0;
        return len;
    }

    // 如果接收缓冲区中没有足够的数据，则先拷贝有的数据到用户指定buf，再继续接收剩余数据
    char *pos = (char*)buf;
    size_t remaining = len;
    memcpy(pos, &conn->ibuf[conn->ifirst], conn->ilen);
    pos += conn->ilen;
    remaining -= conn->ilen;
    conn->ifirst = 0;
    conn->ilen = 0;

    // 继续读取剩余数据
    mill_assert(remaining);
    while(1) {
        if(remaining > MILL_UNIX_BUFLEN) {
            // 如果还有很多数据要读，为减少系统调用次数直接将数据读取到用户指定buf
            ssize_t sz = recv(conn->fd, pos, remaining, 0);
            if(!sz) {
                errno = ECONNRESET;
                return len - remaining;
            }
            if(sz == -1) {
                if(errno != EAGAIN && errno != EWOULDBLOCK)
                    return len - remaining;
                sz = 0;
            }
            if((size_t)sz == remaining) {
                errno = 0;
                return len;
            }
            pos += sz;
            remaining -= sz;
        }
        else {
            // 如果要接收的剩余数据不多了，则接收到接收缓冲区中，再拷贝到用户指定buf
            // 接收MILL_UNIX_BUFLEN的数据，目的是减少之后mill_recv可能引发的recv系统调用的次数
            ssize_t sz = recv(conn->fd, conn->ibuf, MILL_UNIX_BUFLEN, 0);
            if(!sz) {
                errno = ECONNRESET;
                return len - remaining;
            }
            if(sz == -1) {
                if(errno != EAGAIN && errno != EWOULDBLOCK)
                    return len - remaining;
                sz = 0;
            }
            if((size_t)sz < remaining) {
                memcpy(pos, conn->ibuf, sz);
                pos += sz;
                remaining -= sz;
                conn->ifirst = 0;
                conn->ilen = 0;
            }
            else {
                memcpy(pos, conn->ibuf, remaining);
                conn->ifirst = remaining;
                conn->ilen = sz - remaining;
                errno = 0;
                return len;
            }
        }

        // 继续等待后续数据可读事件到达，然后读取（若超时则返回停止接收）
        int res = fdwait(conn->fd, FDW_IN, deadline);
        if(!res) {
            errno = ETIMEDOUT;
            return len - remaining;
        }
    }
}

// unix socket recv 读取len bytes到buf，读取到指定delimiter会停止读取（非阻塞方式）
size_t mill_unixrecvuntil_(struct mill_unixsock_ *s, void *buf, size_t len,
      const char *delims, size_t delimcount, int64_t deadline) {
    if(s->type != MILL_UNIXCONN)
        mill_panic("trying to receive from an unconnected socket");
    unsigned char *pos = (unsigned char*)buf;
    size_t i;
    for(i = 0; i != len; ++i, ++pos) {
        size_t res = unixrecv(s, pos, 1, deadline);
        if(res == 1) {
            size_t j;
            for(j = 0; j != delimcount; ++j)
                if(*pos == delims[j])
                    return i + 1;
        }
        if (errno != 0)
            return i + res;
    }
    errno = ENOBUFS;
    return len;
}

// 关闭socket，写关闭或者读关闭或者both
void mill_unixshutdown_(struct mill_unixsock_ *s, int how) {
    mill_assert(s->type == MILL_UNIXCONN);
    struct mill_unixconn *c = (struct mill_unixconn*)s;
    int rc = shutdown(c->fd, how);
    mill_assert(rc == 0 || errno == ENOTCONN);
}

// 关闭unix socket（统一处理监听socket和连接socket）
void mill_unixclose_(struct mill_unixsock_ *s) {
    if(s->type == MILL_UNIXLISTENER) {
        struct mill_unixlistener *l = (struct mill_unixlistener*)s;
        fdclean(l->fd);
        int rc = close(l->fd);
        mill_assert(rc == 0);
        free(l);
        return;
    }
    if(s->type == MILL_UNIXCONN) {
        struct mill_unixconn *c = (struct mill_unixconn*)s;
        fdclean(c->fd);
        int rc = close(c->fd);
        mill_assert(rc == 0);
        free(c);
        return;
    }
    mill_assert(0);
}
```

## 4.4 ip

### 4.4.1 ip.h

```c
int mill_ipfamily(ipaddr addr);
int mill_iplen(ipaddr addr);
int mill_ipport(ipaddr addr);
```

### 4.4.2 ip.c

```c
MILL_CT_ASSERT(sizeof(ipaddr) >= sizeof(struct sockaddr_in));
MILL_CT_ASSERT(sizeof(ipaddr) >= sizeof(struct sockaddr_in6));

static struct dns_resolv_conf *mill_dns_conf = NULL;
static struct dns_hosts *mill_dns_hosts = NULL;
static struct dns_hints *mill_dns_hints = NULL;

// 创建一个ip地址为INADDR_ANY、指定端口port、mode=ipv4/ipv6的ip地址
static ipaddr mill_ipany(int port, int mode)
{
    ipaddr addr;
    if(mill_slow(port < 0 || port > 0xffff)) {
        ((struct sockaddr*)&addr)->sa_family = AF_UNSPEC;
        errno = EINVAL;
        return addr;
    }
    if (mode == 0 || mode == IPADDR_IPV4 || mode == IPADDR_PREF_IPV4) {
        struct sockaddr_in *ipv4 = (struct sockaddr_in*)&addr;
        ipv4->sin_family = AF_INET;
        ipv4->sin_addr.s_addr = htonl(INADDR_ANY);
        ipv4->sin_port = htons((uint16_t)port);
    }
    else {
        struct sockaddr_in6 *ipv6 = (struct sockaddr_in6*)&addr;
        ipv6->sin6_family = AF_INET6;
        memcpy(&ipv6->sin6_addr, &in6addr_any, sizeof(in6addr_any));
        ipv6->sin6_port = htons((uint16_t)port);
    }
    errno = 0;
    return addr;
}

// 将点分十进制ipv4地址:端口号=ip:port转换为二进制格式（已转为字节序）
static ipaddr mill_ipv4_literal(const char *addr, int port) {
    ipaddr raddr;
    struct sockaddr_in *ipv4 = (struct sockaddr_in*)&raddr;
    int rc = inet_pton(AF_INET, addr, &ipv4->sin_addr);
    mill_assert(rc >= 0);
    if(rc == 1) {
        ipv4->sin_family = AF_INET;
        ipv4->sin_port = htons((uint16_t)port);
        errno = 0;
        return raddr;
    }
    ipv4->sin_family = AF_UNSPEC;
    errno = EINVAL;
    return raddr;
}

// 将点分ipv4地址:端口号=ipv6:port转换为二进制格式（已转网络字节序）
static ipaddr mill_ipv6_literal(const char *addr, int port) {
    ipaddr raddr;
    struct sockaddr_in6 *ipv6 = (struct sockaddr_in6*)&raddr;
    int rc = inet_pton(AF_INET6, addr, &ipv6->sin6_addr);
    mill_assert(rc >= 0);
    if(rc == 1) {
        ipv6->sin6_family = AF_INET6;
        ipv6->sin6_port = htons((uint16_t)port);
        errno = 0;
        return raddr;
    }
    ipv6->sin6_family = AF_UNSPEC;
    errno = EINVAL;
    return raddr;
}

// 转换ipv4地址或者ipv6地址为二进制地址格式（组合调用上面的函数mill_ipv4/6_literal）
static ipaddr mill_ipliteral(const char *addr, int port, int mode) {
    ipaddr raddr;
    struct sockaddr *sa = (struct sockaddr*)&raddr;
    if(mill_slow(!addr || port < 0 || port > 0xffff)) {
        sa->sa_family = AF_UNSPEC;
        errno = EINVAL;
        return raddr;
    }
    switch(mode) {
        case IPADDR_IPV4:
            return mill_ipv4_literal(addr, port);
        case IPADDR_IPV6:
            return mill_ipv6_literal(addr, port);
        case 0:
        case IPADDR_PREF_IPV4:
            raddr = mill_ipv4_literal(addr, port);
            if(errno == 0)
                return raddr;
            return mill_ipv6_literal(addr, port);
        case IPADDR_PREF_IPV6:
            raddr = mill_ipv6_literal(addr, port);
            if(errno == 0)
                return raddr;
            return mill_ipv4_literal(addr, port);
        default:
            mill_assert(0);
    }
}

// 返回ip地址的地址族
int mill_ipfamily(ipaddr addr) {
    return ((struct sockaddr*)&addr)->sa_family;
}

// 返回ip地址结构体长度
int mill_iplen(ipaddr addr) {
    return mill_ipfamily(addr) == AF_INET ? 
                        sizeof(struct sockaddr_in) : sizeof(struct sockaddr_in6);
}

// 返回ip地址端口号
int mill_ipport(ipaddr addr) {
    return ntohs(mill_ipfamily(addr) == AF_INET ? 
                        ((struct sockaddr_in*)&addr)->sin_port : ((struct sockaddr_in6*)&addr)->sin6_port);
}

// 转换二进制格式的ip地址为点分ipv4或者ipv6地址格式
const char *mill_ipaddrstr_(ipaddr addr, char *ipstr) {
    if (mill_ipfamily(addr) == AF_INET) {
        return inet_ntop(AF_INET, &(((struct sockaddr_in*)&addr)->sin_addr),
            ipstr, INET_ADDRSTRLEN);
    }
    else {
        return inet_ntop(AF_INET6, &(((struct sockaddr_in6*)&addr)->sin6_addr),
            ipstr, INET6_ADDRSTRLEN);
    }
}

// 获取本地ip地址
// 二进制格式地址，name可以为空、可以为ipv4或ipv6点分表示形式、可以为接口名称
ipaddr mill_iplocal_(const char *name, int port, int mode) {
    if(!name)
        return mill_ipany(port, mode);
    ipaddr addr = mill_ipliteral(name, port, mode);
#if defined __sun
    return addr;
#else
    if(errno == 0)
       return addr;
    /* Address is not a literal. It must be an interface name then. */
    struct ifaddrs *ifaces = NULL;
    int rc = getifaddrs (&ifaces);
    mill_assert (rc == 0);
    mill_assert (ifaces);
    /*  Find first IPv4 and first IPv6 address. */
    struct ifaddrs *ipv4 = NULL;
    struct ifaddrs *ipv6 = NULL;
    struct ifaddrs *it;
    for(it = ifaces; it != NULL; it = it->ifa_next) {
        if(!it->ifa_addr)
            continue;
        if(strcmp(it->ifa_name, name) != 0)
            continue;
        switch(it->ifa_addr->sa_family) {
        case AF_INET:
            mill_assert(!ipv4);
            ipv4 = it;
            break;
        case AF_INET6:
            mill_assert(!ipv6);
            ipv6 = it;
            break;
        }
        if(ipv4 && ipv6)
            break;
    }
    /* Choose the correct address family based on mode. */
    switch(mode) {
    case IPADDR_IPV4:
        ipv6 = NULL;
        break;
    case IPADDR_IPV6:
        ipv4 = NULL;
        break;
    case 0:
    case IPADDR_PREF_IPV4:
        if(ipv4)
           ipv6 = NULL;
        break;
    case IPADDR_PREF_IPV6:
        if(ipv6)
           ipv4 = NULL;
        break;
    default:
        mill_assert(0);
    }
    if(ipv4) {
        struct sockaddr_in *inaddr = (struct sockaddr_in*)&addr;
        memcpy(inaddr, ipv4->ifa_addr, sizeof (struct sockaddr_in));
        inaddr->sin_port = htons(port);
        freeifaddrs(ifaces);
        errno = 0;
        return addr;
    }
    if(ipv6) {
        struct sockaddr_in6 *inaddr = (struct sockaddr_in6*)&addr;
        memcpy(inaddr, ipv6->ifa_addr, sizeof (struct sockaddr_in6));
        inaddr->sin6_port = htons(port);
        freeifaddrs(ifaces);
        errno = 0;
        return addr;
    }
    freeifaddrs(ifaces);
    ((struct sockaddr*)&addr)->sa_family = AF_UNSPEC;
    errno = ENODEV;
    return addr;
#endif
}

// 获取远程机器ip地址的二进制格式
// name可以是ipv4或ipv6点分表示形式、域名domain（这里要用到dns查询）
ipaddr mill_ipremote_(const char *name, int port, int mode, int64_t deadline) {
    int rc;
    ipaddr addr = mill_ipliteral(name, port, mode);
    if(errno == 0)
       return addr;
    /* Load DNS config files, unless they are already chached. */
    if(mill_slow(!mill_dns_conf)) {
        /* TODO: Maybe re-read the configuration once in a while? */
        mill_dns_conf = dns_resconf_local(&rc);
        mill_assert(mill_dns_conf);
        mill_dns_hosts = dns_hosts_local(&rc);
        mill_assert(mill_dns_hosts);
        mill_dns_hints = dns_hints_local(mill_dns_conf, &rc);
        mill_assert(mill_dns_hints);
    }
    /* Let's do asynchronous DNS query here. */
    struct dns_resolver *resolver = dns_res_open(mill_dns_conf, mill_dns_hosts,
        mill_dns_hints, NULL, dns_opts(), &rc);
    mill_assert(resolver);
    mill_assert(port >= 0 && port <= 0xffff);
    char portstr[8];
    snprintf(portstr, sizeof(portstr), "%d", port);
    struct addrinfo hints;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = PF_UNSPEC;
    struct dns_addrinfo *ai = dns_ai_open(name, portstr, DNS_T_A, &hints,
        resolver, &rc);
    mill_assert(ai);
    dns_res_close(resolver);
    struct addrinfo *ipv4 = NULL;
    struct addrinfo *ipv6 = NULL;
    struct addrinfo *it = NULL;
    while(1) {
        rc = dns_ai_nextent(&it, ai);
        if(rc == EAGAIN) {
            int fd = dns_ai_pollfd(ai);
            mill_assert(fd >= 0);
            int events = fdwait(fd, FDW_IN, deadline);
            /* There's no guarantee that the file descriptor will be reused
               in next iteration. We have to clean the fdwait cache here
               to be on the safe side. */
            fdclean(fd);
            if(mill_slow(!events)) {
                errno = ETIMEDOUT;
                return addr;
            }
            mill_assert(events == FDW_IN);
            continue;
        }
        if(rc == ENOENT)
            break;

        if(!ipv4 && it && it->ai_family == AF_INET) {
            ipv4 = it;
        }
        else if(!ipv6 && it && it->ai_family == AF_INET6) {
            ipv6 = it;
        }
        else {
            free(it);
        }
        
        if(ipv4 && ipv6)
            break;
    }
    switch(mode) {
    case IPADDR_IPV4:
        if(ipv6) {
            free(ipv6);
            ipv6 = NULL;
        }
        break;
    case IPADDR_IPV6:
        if(ipv4) {
            free(ipv4);
            ipv4 = NULL;
        }
        break;
    case 0:
    case IPADDR_PREF_IPV4:
        if(ipv4 && ipv6) {
            free(ipv6);
            ipv6 = NULL;
        }
        break;
    case IPADDR_PREF_IPV6:
        if(ipv6 && ipv4) {
            free(ipv4);
            ipv4 = NULL;
        }
        break;
    default:
        mill_assert(0);
    }
    if(ipv4) {
        struct sockaddr_in *inaddr = (struct sockaddr_in*)&addr;
        memcpy(inaddr, ipv4->ai_addr, sizeof (struct sockaddr_in));
        inaddr->sin_port = htons(port);
        dns_ai_close(ai);
        free(ipv4);
        errno = 0;
        return addr;
    }
    if(ipv6) {
        struct sockaddr_in6 *inaddr = (struct sockaddr_in6*)&addr;
        memcpy(inaddr, ipv6->ai_addr, sizeof (struct sockaddr_in6));
        inaddr->sin6_port = htons(port);
        dns_ai_close(ai);
        free(ipv6);
        errno = 0;
        return addr;
    }
    dns_ai_close(ai);
    ((struct sockaddr*)&addr)->sa_family = AF_UNSPEC;
    errno = EADDRNOTAVAIL;
    return addr;
}
```

# 5 IO Multiplex

## 5.1 poller

libmill里面网络io是基于io多路复用实现的，在linux平台下面基于epoll实现，在其他平台下面基于对应的io多路复用系统调用实现，这里只关注linux平台下的实现细节。

### 5.1.1 poller.h

```c
void mill_poller_init(void);

// poller也实现了libmill.h中定义的mill_wait()和mill_fdwait()

// 等待至少一个coroutine恢复执行
// 如果block=0，轮询事件时没有事件就绪则立即返回
// 如果block=1，轮询事件时没有事件就绪则阻塞，直到至少有一个事件就绪
void mill_wait(int block);

// 子进程中调用该函数将创建一个全新的pollset，与父进程的pollset脱离关系
void mill_poller_postfork(void);
```

### 5.1.2 poller.c

```c
/* Forward declarations for the functions implemented by specific poller
   mechanisms (poll, epoll, kqueue). */
void mill_poller_init(void);
static void mill_poller_add(int fd, int events);
static void mill_poller_rm(struct mill_cr *cr);
static void mill_poller_clean(int fd);
static int mill_poller_wait(int timeout);

// poller是否已经被初始化过，1是，0否
static int mill_poller_initialised = 0;

// 检查poller是否已初始化，没有初始化则初始化，已经初始化不处理
#define check_poller_initialised() \
do {\
    if(mill_slow(!mill_poller_initialised)) {\
        mill_poller_init();\
        mill_assert(errno == 0);\
        mill_main.fd = -1;\
        mill_main.timer.expiry = -1;\
        mill_poller_initialised = 1;\
    }\
} while(0)

// 挂起当前运行中的coroutine一定的时间
void mill_msleep_(int64_t deadline, const char *current) {
    mill_fdwait_(-1, 0, deadline, current);
}

// 
static void mill_poller_callback(struct mill_timer *timer) {
    struct mill_cr *cr = mill_cont(timer, struct mill_cr, timer);
    mill_resume(cr, -1);
    if (cr->fd != -1)
        mill_poller_rm(cr);
}

// 等待fd上的events就绪或者直到超时
int mill_fdwait_(int fd, int events, int64_t deadline, const char *current) {
    check_poller_initialised();
    // 如果指定了deadline，则添加一个定时器，超时回调mill_poller_callback唤醒定时器关联的协程
    if(deadline >= 0)
        mill_timer_add(&mill_running->timer, deadline, mill_poller_callback);
    // 如果指定了fd，则注册coroutine对该fd上的io事件监听
    if(fd >= 0)
        mill_poller_add(fd, events);
    // 执行了实际的wait，mill_suspend挂起当前协程切换到其他ready状态的协程
    mill_running->state = fd < 0 ? MILL_MSLEEP : MILL_FDWAIT;
    mill_running->fd = fd;
    mill_running->events = events;
    mill_set_current(&mill_running->debug, current);
    // 当前协程要等待其他协程调用mill_resume来唤醒当前协程才会从这里继续向下执行
    // mill_suspend返回值为mill_resume(struct mill_cr *cr, int result)中的参数result
    // 谁来唤醒当前协程呢？epfd事件轮询的时候有fd事件就绪则会唤醒等待在该fd上的协程！
    int rc = mill_suspend();
    /* Handle file descriptor events. */
    if(rc >= 0) {
        mill_assert(!mill_timer_enabled(&mill_running->timer));
        return rc;
    }
    /* Handle the timeout. */
    mill_assert(mill_running->fd == -1);
    return 0;
}

// 将fd从epfd上取消注册
void mill_fdclean_(int fd) {
    check_poller_initialised();
    mill_poller_clean(fd);
}

// 事件轮询，block=1表示阻塞直到有事件到达（这里的事件包括定时器超时事件、io就绪事件） 
void mill_wait(int block) {
    check_poller_initialised();
    while(1) {
        // 计算下次轮询的超时时间
        int timeout = block ? mill_timer_next() : 0;
        // 检查fd上的io事件
        int fd_fired = mill_poller_wait(timeout);
        // 检查定时器超时时间
        int timer_fired = mill_timer_fire();
        // 非阻塞情况下不重试
        if(!block || fd_fired || timer_fired)
            break;
        /* If timeout was hit but there were no expired timers do the poll
           again. This should not happen in theory but let's be ready for the
           case when the system timers are not precise. */
    }
}

// libmill在linux平台下基于epoll实现事件轮询
#include "epoll.inc"
```

### 5.1.3 epoll.inc

```c
#define MILL_ENDLIST 0xffffffff
#define MILL_EPOLLSETSIZE 128

// 全局pollset，linux下其实是个epfd
static int mill_efd = -1;

// epoll允许为每个fd注册一个单独的指针，我们对每个fd需要注册两个coroutine指针，
// 一个是等待从fd接收数据的coroutine指针，一个是等待向fd发送数据的coroutine指针
// 因此，我们需要创建一个coroutine指针pair数组来跟踪打开的socket fds上的io
struct mill_crpair {
    struct mill_cr *in;
    struct mill_cr *out;
    uint32_t currevs;
    // 1-based索引值，0代表不属于这个list，MILL_ENDLIST代表list结束（通过数组索引实现的链表）
    uint32_t next;
};

static struct mill_crpair *mill_crpairs = NULL;
static int mill_ncrpairs = 0;
static uint32_t mill_changelist = MILL_ENDLIST;

// poller初始化
void mill_poller_init(void) {
    // 检查系统允许的进程最大可打开文件数量
    struct rlimit rlim;
    int rc = getrlimit(RLIMIT_NOFILE, &rlim);
    if(mill_slow(rc < 0)) 
        return;
    mill_ncrpairs = rlim.rlim_max;
    // 最多可打开mill_ncrpairs个socket，每个socket应该有对应的一个struct_crpair
    mill_crpairs = (struct mill_crpair*)calloc(mill_ncrpairs, sizeof(struct mill_crpair));
    if(mill_slow(!mill_crpairs)) {
        errno = ENOMEM; 
        return;
    }
    // 创建epfd准备socket io事件进行监听
    mill_efd = epoll_create(1);
    if(mill_slow(mill_efd < 0)) {
        free(mill_crpairs);
        mill_crpairs = NULL;
        return;
    }
    errno = 0;
}

// 子进程中重新创建一个pollset，与父进程的pollset脱离了关系
void mill_poller_postfork(void) {
    if(mill_efd != -1) {
        int rc = close(mill_efd);
        mill_assert(rc == 0);
    }
    mill_efd = -1;
    mill_crpairs = NULL;
    mill_ncrpairs = 0;
    mill_changelist = MILL_ENDLIST;
    mill_poller_init();
}

// 注册当前协程对fd上events就绪的监听
static void mill_poller_add(int fd, int events) {
    // 每个fd都是从最小未被使用的整数开始分配的，因此fd取值一定在[0,rlim.rlim_max]范围内，
    // 因此，这里的mill_crpairs[fd]一定不会出现内存越界
    struct mill_crpair *crp = &mill_crpairs[fd];
    if(events & FDW_IN) {
        // 不允许多个协程wait同一个fd，不然io就乱了
        if(crp->in)
            mill_panic("multiple coroutines waiting for a single file descriptor");
        crp->in = mill_running;
    }
    if(events & FDW_OUT) {
        // 不允许多个协程wait同一个fd，不然io就乱了
        if(crp->out)
            mill_panic("multiple coroutines waiting for a single file descriptor");
        crp->out = mill_running;
    }
    if(!crp->next) {
        crp->next = mill_changelist;
        mill_changelist = fd + 1;           // 1-based索引值
    }
}

// 取消协程cr当前对fd上事件的监听
// 注意这里并没有从epfd中清除对fd的监听，其他协程还可能监听呢
static void mill_poller_rm(struct mill_cr *cr) {
    int fd = cr->fd;
    mill_assert(fd != -1);
    struct mill_crpair *crp = &mill_crpairs[fd];
    if(crp->in == cr) {
        crp->in = NULL;
        cr->fd = -1;
    }
    if(crp->out == cr) {
        crp->out = NULL;
        cr->fd = -1;
    }
    if(!crp->next) {
        crp->next = mill_changelist;
        mill_changelist = fd + 1;           // 1-based索引值
    }
}

// 从epfd中清除对fd的监听
// 注意必须所有coroutine都没有监听这个fd
static void mill_poller_clean(int fd) {
    struct mill_crpair *crp = &mill_crpairs[fd];
    // 断言必须所有coroutine都没有监听这个fd
    mill_assert(!crp->in);
    mill_assert(!crp->out);
    /* Remove the file descriptor from the pollset, if it is still present. */
    if(crp->currevs) {   
        struct epoll_event ev;
        ev.data.fd = fd;
        ev.events = 0;
        int rc = epoll_ctl(mill_efd, EPOLL_CTL_DEL, fd, &ev);
        mill_assert(rc == 0 || errno == ENOENT);
    }
    /* Clean the cache. */
    crp->currevs = 0;
    if(!crp->next) {
        crp->next = mill_changelist;
        mill_changelist = fd + 1;
    }
}

// epoll轮询事件就绪状态
static int mill_poller_wait(int timeout) {
    /* Apply any changes to the pollset.
       TODO: Use epoll_ctl_batch once available. */
    while(mill_changelist != MILL_ENDLIST) {
        int fd = mill_changelist - 1;
        struct mill_crpair *crp = &mill_crpairs[fd];
        struct epoll_event ev;
        ev.data.fd = fd;
        ev.events = 0;
        // 根据crp中是否有coroutine监听crp->fd上的io事件来更新crp->currevs，并更新epfd事件注册
        if(crp->in)
            ev.events |= EPOLLIN;
        if(crp->out)
            ev.events |= EPOLLOUT;
        if(crp->currevs != ev.events) {
            int op;
            if(!ev.events)
                 op = EPOLL_CTL_DEL;
            else if(!crp->currevs)
                 op = EPOLL_CTL_ADD;
            else
                 op = EPOLL_CTL_MOD;
            crp->currevs = ev.events;
            int rc = epoll_ctl(mill_efd, op, fd, &ev);
            mill_assert(rc == 0);
        }
        mill_changelist = crp->next;
        crp->next = 0;
    }
    // epoll_wait事件轮询，返回就绪事件
    struct epoll_event evs[MILL_EPOLLSETSIZE];
    int numevs;
    while(1) {
        numevs = epoll_wait(mill_efd, evs, MILL_EPOLLSETSIZE, timeout);
        if(numevs < 0 && errno == EINTR)
            continue;
        mill_assert(numevs >= 0);
        break;
    }
    // 遍历fd就绪的事件，并唤醒等待该fd事件就绪的coroutine
    int i;
    for(i = 0; i != numevs; ++i) {
        struct mill_crpair *crp = &mill_crpairs[evs[i].data.fd];
        int inevents = 0;
        int outevents = 0;
        /* Set the result values. */
        if(evs[i].events & EPOLLIN)
            inevents |= FDW_IN;
        if(evs[i].events & EPOLLOUT)
            outevents |= FDW_OUT;
        if(evs[i].events & (EPOLLERR | EPOLLHUP)) {
            inevents |= FDW_ERR;
            outevents |= FDW_ERR;
        }
        // 唤醒等待该fd上就绪事件的coroutine
        if(crp->in == crp->out) {
            struct mill_cr *cr = crp->in;
            mill_resume(cr, inevents | outevents);
            mill_poller_rm(cr);
            if(mill_timer_enabled(&cr->timer))
                mill_timer_rm(&cr->timer);
        }
        else {
            // 唤醒等待该fd读就绪事件的协程
            if(crp->in && inevents) {
                struct mill_cr *cr = crp->in;
                mill_resume(cr, inevents);
                mill_poller_rm(cr);
                if(mill_timer_enabled(&cr->timer))
                    mill_timer_rm(&cr->timer);
            }
            // 唤醒等待该fd写就绪事件的协程
            if(crp->out && outevents) {
                struct mill_cr *cr = crp->out;
                mill_resume(cr, outevents);
                mill_poller_rm(cr);
                if(mill_timer_enabled(&cr->timer))
                    mill_timer_rm(&cr->timer);
            }
        }
    }
    
    // 至少有一个协程被唤醒则返回1，反之返回0
    return numevs > 0 ? 1 : 0;
}
```

## 5.2 file

epoll并不支持所有的fd类型，一般将epoll应用于socket、pipe、tty以及其他有限的设备类型，epoll不支持regular file。尽管我们可以传递regular file的fd给select、poll但这只是因为select、poll在接口上允许而已，并没有什么效果（总是返回事件就绪)，既然没有什么效果，epoll接口在设计的时候就决定根本不接受regular file fd，实际上epoll也只是为了改善select、poll并没打算额外支持regular file。这里只是将epoll应用在/dev/pts设备上，stdin、stdout、stderr都事这种设备类型，并不是针对regular file的。

难道os就无法支持regular file的io多路复用吗？怎么可能不能？只是epoll不支持，bsd下kqueue就支持！

这里的一篇文章对kqueue和epoll进行了对比：[Scalable Event Multiplexing: epoll vs. kqueue](http://people.eecs.berkeley.edu/~sangjin/2012/12/21/epoll-vs-kqueue.html)

>The last issue is that epoll does not even support all kinds of file descriptors; select()/poll()/epoll do not work with regular (disk) files. This is because epoll has a strong assumption of the readiness model; you monitor the readiness of sockets, so that subsequent IO calls on the sockets do not block. However, disk files do not fit this model, since simply they are always ready.

>Disk I/O blocks when the data is not cached in memory, not because the client did not send a message. For disk files, the completion notification model fits. In this model, you simply issue I/O operations on the disk files, and get notified when they are done. kqueue supports this approach with the EVFILT_AIO filter type, in conjunction with POSIX AIO functions, such as aio_read(). In Linux, you should simply pray that disk access would not block with high cache hit rate (surprisingly common in many network servers), or have separate threads so that disk I/O blocking does not affect network socket processing (e.g., the FLASH architecture).

这里不再过分展开了，看下这里的代码吧。

```c
#ifndef MILL_FILE_BUFLEN
#define MILL_FILE_BUFLEN (4096)
#endif

// 文件
struct mill_file {
    int fd;
    size_t ifirst;  //file输入缓冲区剩余数据起始位置
    size_t ilen;    //file输入缓冲区剩余数据长度
    size_t olen;    //file输出缓冲区剩余数据长度
    char ibuf[MILL_FILE_BUFLEN];    //file输入缓冲区
    char obuf[MILL_FILE_BUFLEN];    //file输出缓冲区
};

// 文件fd tune操作（设为非阻塞）
static void mill_filetune(int fd) {
    int opt = fcntl(fd, F_GETFL, 0);
    if (opt == -1)
        opt = 0;
    int rc = fcntl(fd, F_SETFL, opt | O_NONBLOCK);
    mill_assert(rc != -1);
}

// 打开文件（fd已调优成非阻塞方式）
struct mill_file *mill_mfopen_(const char *pathname, int flags, mode_t mode) {
    /* Open the file. */
    int fd = open(pathname, flags, mode);
    if (fd == -1)
        return NULL;
    mill_filetune(fd);

    /* Create the object. */
    struct mill_file *f = malloc(sizeof(struct mill_file));
    if(!f) {
        fdclean(fd);
        close(fd);
        errno = ENOMEM;
        return NULL;
    }
    f->fd = fd;
    f->ifirst = 0;
    f->ilen = 0;
    f->olen = 0;
    errno = 0;
    return f;
}

// 文件写操作（这里的写操作对缓冲区的操作逻辑与tcp、unix socket基本一致，不再赘述）
size_t mill_mfwrite_(struct mill_file *f, const void *buf, size_t len, int64_t deadline) {
    /* If it fits into the output buffer copy it there and be done. */
    if(f->olen + len <= MILL_FILE_BUFLEN) {
        memcpy(&f->obuf[f->olen], buf, len);
        f->olen += len;
        errno = 0;
        return len;
    }

    /* If it doesn't fit, flush the output buffer first. */
    mfflush(f, deadline);
    if(errno != 0)
        return 0;

    /* Try to fit it into the buffer once again. */
    if(f->olen + len <= MILL_FILE_BUFLEN) {
        memcpy(&f->obuf[f->olen], buf, len);
        f->olen += len;
        errno = 0;
        return len;
    }

    /* The data chunk to send is longer than the output buffer. Let's do the writing in-place. */
    char *pos = (char*)buf;
    size_t remaining = len;
    while(remaining) {
        ssize_t sz = write(f->fd, pos, remaining);
        if(sz == -1) {
            if(errno != EAGAIN && errno != EWOULDBLOCK)
                return 0;
            int rc = fdwait(f->fd, FDW_OUT, deadline);
            if(rc == 0) {
                errno = ETIMEDOUT;
                return len - remaining;
            }
            mill_assert(rc == FDW_OUT);
            continue;
        }
        pos += sz;
        remaining -= sz;
    }
    return len;
}

// 文件写缓冲flush操作（这里对缓冲区的操作与对tcp、unix socket的操作基本一致，不再赘述）
void mill_mfflush_(struct mill_file *f, int64_t deadline) {
    if(!f->olen) {
        errno = 0;
        return;
    }
    char *pos = f->obuf;
    size_t remaining = f->olen;
    while(remaining) {
        ssize_t sz = write(f->fd, pos, remaining);
        if(sz == -1) {
            if(errno != EAGAIN && errno != EWOULDBLOCK)
                return;
            int rc = fdwait(f->fd, FDW_OUT, deadline);
            if(rc == 0) {
                errno = ETIMEDOUT;
                return;
            }
            mill_assert(rc == FDW_OUT);
            continue;
        }
        pos += sz;
        remaining -= sz;
    }
    f->olen = 0;
    errno = 0;
}

// 文件读操作（这里的读操作对缓冲区的操作逻辑与tcp、unix socket基本一致，不再赘述）
size_t mill_mfread_(struct mill_file *f, void *buf, size_t len, int64_t deadline) {
    /* If there's enough data in the buffer it's easy. */
    if(f->ilen >= len) {
        memcpy(buf, &f->ibuf[f->ifirst], len);
        f->ifirst += len;
        f->ilen -= len;
        errno = 0;
        return len;
    }

    /* Let's move all the data from the buffer first. */
    char *pos = (char*)buf;
    size_t remaining = len;
    memcpy(pos, &f->ibuf[f->ifirst], f->ilen);
    pos += f->ilen;
    remaining -= f->ilen;
    f->ifirst = 0;
    f->ilen = 0;

    mill_assert(remaining);
    while(1) {
        if(remaining > MILL_FILE_BUFLEN) {
            /* If we still have a lot to read try to read it in one go directly
             into the destination buffer. */
            ssize_t sz = read(f->fd, pos, remaining);
            if(!sz) {
                return len - remaining;
            }
            if(sz == -1) {
                if(errno != EAGAIN && errno != EWOULDBLOCK)
                    return len - remaining;
                sz = 0;
            }
            if((size_t)sz == remaining) {
                errno = 0;
                return len;
            }
            pos += sz;
            remaining -= sz;
            if (sz != 0 && mfeof(f)) {
                return len - remaining;
            }
        }
        else {
            /* If we have just a little to read try to read the full connection
             buffer to minimise the number of system calls. */
            ssize_t sz = read(f->fd, f->ibuf, MILL_FILE_BUFLEN);
            if(!sz) {
                return len - remaining;
            }
            if(sz == -1) {
                if(errno != EAGAIN && errno != EWOULDBLOCK)
                    return len - remaining;
                sz = 0;
            }
            if((size_t)sz < remaining) {
                memcpy(pos, f->ibuf, sz);
                pos += sz;
                remaining -= sz;
                f->ifirst = 0;
                f->ilen = 0;
            }
            else {
                memcpy(pos, f->ibuf, remaining);
                f->ifirst = remaining;
                f->ilen = sz - remaining;
                errno = 0;
                return len;
            }
            if (sz != 0 && mfeof(f)) {
                return len - remaining;
            }
        }

        /* Wait till there's more data to read. */
        int res = fdwait(f->fd, FDW_IN, deadline);
        if (!res) {
            errno = ETIMEDOUT;
            return len - remaining;
        }
    }
}

// 文件关闭
void mill_mfclose_(struct mill_file *f) {
    fdclean(f->fd);
    int rc = close(f->fd);
    mill_assert(rc == 0);
    free(f);
    return;
}

// 文件读写位置查看
off_t mill_mftell_(struct mill_file *f) {
    return lseek(f->fd, 0, SEEK_CUR) - f->ilen;
}

// 文件读写位置定位
off_t mill_mfseek_(struct mill_file *f, off_t offset) {
    f->ifirst = 0;
    f->ilen = 0;
    f->olen = 0;
    return lseek(f->fd, offset, SEEK_SET);
}

// 判断是否读到文件末尾
int mill_mfeof_(struct mill_file *f) {
    // 首先获取当前位置
    off_t current = lseek(f->fd, 0, SEEK_CUR);
    if (current == -1)
        return -1;
    // 再获取文件末尾位置
    off_t eof = lseek(f->fd, 0, SEEK_END);
    if (eof == -1)
        return -1;
    // 恢复读写位置为之前的读写位置
    off_t res = lseek(f->fd, current, SEEK_SET);
    if (res == -1)
        return -1;
    // 比较是否到达文件末尾位置
    return (current == eof);
}

// stdin
struct mill_file *mill_mfin_(void) {
    static struct mill_file f = {-1, 0, 0, 0};
    if(mill_slow(f.fd < 0)) {
        mill_filetune(STDIN_FILENO);
        f.fd = STDIN_FILENO;
    }
    return &f;
}

// stdout
struct mill_file *mill_mfout_(void) {
    static struct mill_file f = {-1, 0, 0, 0};
    if(mill_slow(f.fd < 0)) {
        mill_filetune(STDOUT_FILENO);
        f.fd = STDOUT_FILENO;
    }
    return &f;
}

// stderr
struct mill_file *mill_mferr_(void) {
    static struct mill_file f = {-1, 0, 0, 0};
    if(mill_slow(f.fd < 0)) {
        mill_filetune(STDERR_FILENO);
        f.fd = STDERR_FILENO;
    }
    return &f;
}
```

# 6 Data Structure

## 6.1 slist

**mill_slist**，它实现的是一个单链表，它也实现了**pop**、**push**、**push_back**操作，这意味着也可以把它当做stack、queue来使用。

如何当做stack来使用？push、pop！
如何当做queue来使用？push_back、pop！

对于当做单链表来使用，其使用方式与list类似，前面也分析了mill_list的相关实现，这里mill_slist的实现思路与也之类似。

### 6.1.1 slist.h

```c
struct mill_slist_item {
    struct mill_slist_item *next;
};

struct mill_slist {
    struct mill_slist_item *first;
    struct mill_slist_item *last;
};

/* Initialise the list. To statically initialise the list use = {0}. */
void mill_slist_init(struct mill_slist *self);

/* True is the list has no items. */
#define mill_slist_empty(self) (!((self)->first))

/* Returns iterator to the first item in the list or NULL if the list is empty. */
#define mill_slist_begin(self) ((self)->first)

/* Returns iterator to one past the item pointed to by 'it'. If there are no more items returns NULL. */
#define mill_slist_next(it) ((it)->next)

/* Push the item to the beginning of the list. */
void mill_slist_push(struct mill_slist *self, struct mill_slist_item *item);

/* Push the item to the end of the list. */
void mill_slist_push_back(struct mill_slist *self, struct mill_slist_item *item);

/* Pop an item from the beginning of the list. */
struct mill_slist_item *mill_slist_pop(struct mill_slist *self);
```

### 6.1.2 slist.c

```c
// slist初始化
void mill_slist_init(struct mill_slist *self) {
    self->first = NULL;
    self->last = NULL;
}

// slist push操作（插到链表头部）
void mill_slist_push(struct mill_slist *self, struct mill_slist_item *item) {
    item->next = self->first;
    self->first = item;
    if(!self->last)
        self->last = item;
}

// slist push_back（插到链表尾部）
void mill_slist_push_back(struct mill_slist *self,
      struct mill_slist_item *item) {
    item->next = NULL;
    if(!self->last)
        self->first = item;
    else
        self->last->next = item;
    self->last = item;
}

// slist pop（从链表头部pop）
struct mill_slist_item *mill_slist_pop(struct mill_slist *self) {
    if(!self->first)
        return NULL;
    struct mill_slist_item *it = self->first;
    self->first = self->first->next;
    if(!self->first)
        self->last = NULL;
    return it;
}

```

## 6.2 list

### 6.2.1 list.h

mill_list是一个双向链表，链表内部的链接通过mill_list_item来维护，mill_list_item与mill_cont相当于实现了list中的iterator。

```c
struct mill_list_item {
    struct mill_list_item *next;
    struct mill_list_item *prev;
};

struct mill_list {
    struct mill_list_item *first;
    struct mill_list_item *last;
};

/* Initialise the list. To statically initialise the list use = {0}. */
void mill_list_init(struct mill_list *self);

/* True is the list has no items. */
#define mill_list_empty(self) (!((self)->first))

/* Returns iterator to the first item in the list or NULL if
   the list is empty. */
#define mill_list_begin(self) ((self)->first)

/* Returns iterator to one past the item pointed to by 'it'. */
#define mill_list_next(it) ((it)->next)

/* Adds the item to the list before the item pointed to by 'it'.
   If 'it' is NULL the item is inserted to the end of the list. */
void mill_list_insert(struct mill_list *self, struct mill_list_item *item, struct mill_list_item *it);

/* Removes the item from the list and returns pointer to the next item in the
   list. Item must be part of the list. */
struct mill_list_item *mill_list_erase(struct mill_list *self, struct mill_list_item *item);

```

当我们创建一个list时，我们创建一个struct mill_list变量，当我们要插入元素到list中时，实际上插入的是一个mill_list_item，当我们要遍历一个list时实际上是通过mill_list.first/last以及mill_list_item.next/prev来进行遍历。

不禁要问，我们要保存的链表元素肯定不只是mill_list_item啊？struct元素是不是还要包括其他成员？是。这里就要提到**mill_cont**这个函数了，该方法可以获取包含某个member的struct结构体的地址，如果在自定义struct中额外增加一个成员mill_list_item，保存链接关系的时候使用mill_list_item成员，访问自定义struct完整信息的时候再通过该成员以及mill_cont来获取自定义结构体地址，进而解引用访问，这样问题就解决了？

我们要存储的结构体以struct Student为例，来演示一下上述操作：

```c
// 自定义struct
struct Student {
    char *name;
    int age;
    int sex;
    struct list_mill_item item;
};

// 创建链表
struct mill_list students = {0};

// 添加元素到链表
struct Student stu_x = {.name="x", .age=10, .sex=0};
struct Student stu_y = {.name="y", .age=11, .sex=1};

mill_list_init(&students, &stu_x->item, NULL);
mill_list_init(&students, &stu_y->item, NULL);

// 遍历链表元素
struct mill_list_item *iter = students.first;
while(iter) {
    struct Student *stu = (struct Student *)mill_cont(iter, struct Student, item);
    printf("student name:%s, age:%d, sex:%d\n", stu->name, stu->age, stu->sex);
    
    iter = iter->next;
}
```

### 6.1.2 list.c

```c
//初始化一个空链表
void mill_list_init(struct mill_list *self)
{
    self->first = NULL;
    self->last = NULL;
}

// 在链表self中在元素it前面插入item
void mill_list_insert(struct mill_list *self, struct mill_list_item *item, struct mill_list_item *it)
{
    item->prev = it ? it->prev : self->last;
    item->next = it;
    if(item->prev)
        item->prev->next = item;
    if(item->next)
        item->next->prev = item;
    if(!self->first || self->first == it)
        self->first = item;
    if(!it)
        self->last = item;
}

// 从链表self中删除元素item
struct mill_list_item *mill_list_erase(struct mill_list *self, struct mill_list_item *item)
{
    struct mill_list_item *next;

    if(item->prev)
        item->prev->next = item->next;
    else
        self->first = item->next;
    if(item->next)
        item->next->prev = item->prev;
    else
        self->last = item->prev;

    next = item->next;

    item->prev = NULL;
    item->next = NULL;

    return next;
}
```

# 7 Common Utils

## 7.1 utils

```c
// ptr是指向结构体type中成员member的指针，计算包含该member的结构体的地址
// - 在list等实现中，mill_cont用于获取“迭代器”对应的元素结构体地址
#define mill_cont(ptr, type, member) \
    (ptr ? ((type*) (((char*) ptr) - offsetof(type, member))) : NULL)
```

```c
// 编译时断言
#define MILL_CT_ASSERT_HELPER2(prefix, line)    prefix##line
#define MILL_CT_ASSERT_HELPER1(prefix, line)    MILL_CT_ASSERT_HELPER2(prefix, line)
#define MILL_CT_ASSERT(x) \
    typedef int MILL_CT_ASSERT_HELPER1(ct_assert_,__COUNTER__) [(x) ? 1 : -1]
```

```c
// 分支判断，便于编译器分支预测
#if defined __GNUC__ || defined __llvm__
#define mill_fast(x) __builtin_expect(!!(x), 1)
#define mill_slow(x) __builtin_expect(!!(x), 0)
#else
#define mill_fast(x) (x)
#define mill_slow(x) (x)
#endif
```

```c
// 自定义断言
#define mill_assert(x) \
    do {\
        if (mill_slow(!(x))) {\
            fprintf(stderr, "Assert failed: " #x " (%s:%d)\n",\
                __FILE__, __LINE__);\
            fflush(stderr);\
            abort();\
        }\
    } while (0)
#endif
```

## 7.2 timer

### 7.2.1 timer.h

```c
struct mill_timer {
    // mill_list_item结合mill_cont来实现了list iterator
    /* Item in the global list of all timers. */
    struct mill_list_item item;
    /* The deadline when the timer expires. -1 if the timer is not active. */
    int64_t expiry;
    /* Callback invoked when timer expires. Pfui Teufel! */
    mill_timer_callback callback;
};
```

```c
/* Test wheather the timer is active. */
#define mill_timer_enabled(tm)  ((tm)->expiry >= 0)

/* Add a timer for the running coroutine. */
void mill_timer_add(struct mill_timer *timer, int64_t deadline, mill_timer_callback callback);

/* Remove the timer associated with the running coroutine. */
void mill_timer_rm(struct mill_timer *timer);

/* Number of milliseconds till the next timer expires. If there are no timers returns -1. */
int mill_timer_next(void);

/* Resumes all coroutines whose timers have already expired. Returns zero if no coroutine was resumed, 1 otherwise. */
int mill_timer_fire(void);

/* Called after fork in the child process to deactivate all the timers inherited from the parent. */
void mill_timer_postfork(void);
```

### 7.2.2 timer.c

```c
// 定时器精度控制，rdtsc先后读取ticks差值超过这个值则gettimeofday更新last_now
#define MILL_CLOCK_PRECISION 1000000
```

```c
// 返回gettimeofday获取的系统时间，单位seconds
static int64_t mill_os_time(void) {
#if defined __APPLE__
    ...
#else
    struct timeval tv;
    int rc = gettimeofday(&tv, NULL);
    assert(rc == 0);
    return ((int64_t)tv.tv_sec) * 1000 + (((int64_t)tv.tv_usec) / 1000);
#endif
}
```

```c
// 获取当前系统时间（注意这里的时间是有cache的）
int64_t mill_now_(void) {
#if (defined __GNUC__ || defined __clang__) && (defined __i386__ || defined __x86_64__)
    // rdtsc获取系统启动后经历的cpu时钟周期数量
    uint32_t low;
    uint32_t high;
    __asm__ volatile("rdtsc" : "=a" (low), "=d" (high));
    
    int64_t tsc = (int64_t)((uint64_t)high << 32 | low);

    static int64_t last_tsc = -1;
    static int64_t last_now = -1;
    if(mill_slow(last_tsc < 0)) {
        last_tsc = tsc;
        last_now = mill_os_time();
    }
    // 如果在精度范围内返回上次获取的系统时间，超出精度范围则更新系统时间
    if(mill_fast(tsc - last_tsc <= (MILL_CLOCK_PRECISION / 2) && tsc >= last_tsc))
        return last_now;
    
    last_tsc = tsc;
    last_now = mill_os_time();
    return last_now;
#else
    return mill_os_time();
#endif
}
```

```c
// 定时器列表，列表中定时器是有序的，时间靠前的排列在前面
static struct mill_list mill_timers = {0};

// 往定时器列表中添加定时器，保证链表中定时器有序（按过期时间升序排列）
void mill_timer_add(struct mill_timer *timer, int64_t deadline, mill_timer_callback callback) {
    mill_assert(deadline >= 0);
    timer->expiry = deadline;
    timer->callback = callback;
    /* Move the timer into the right place in the ordered list
       of existing timers. TODO: This is an O(n) operation! */
    struct mill_list_item *it = mill_list_begin(&mill_timers);
    while(it) {
        struct mill_timer *tm = mill_cont(it, struct mill_timer, item);
        /* If multiple timers expire at the same momemt they will be fired
           in the order they were created in (> rather than >=). */
        if(tm->expiry > timer->expiry)
            break;
        it = mill_list_next(it);
    }
    mill_list_insert(&mill_timers, &timer->item, it);
}

// 从定时器列表中移除定时器
void mill_timer_rm(struct mill_timer *timer) {
    mill_assert(timer->expiry >= 0);
    mill_list_erase(&mill_timers, &timer->item);
    timer->expiry = -1;
}

// 返回定时器列表中首个定时器的剩余超时时间
int mill_timer_next(void) {
    if(mill_list_empty(&mill_timers))
        return -1;
    int64_t nw = now();
    int64_t expiry = mill_cont(mill_list_begin(&mill_timers), struct mill_timer, item) -> expiry;
    return (int) (nw >= expiry ? 0 : expiry - nw);
}

// 执行所有超时的定时器绑定的回调函数，返回是否有调用定时器的回调方法
int mill_timer_fire(void) {
    /* Avoid getting current time if there are no timers anyway. */
    if(mill_list_empty(&mill_timers))
        return 0;
    int64_t nw = now();
    int fired = 0;
    while(!mill_list_empty(&mill_timers)) {
        struct mill_timer *tm = mill_cont(
            mill_list_begin(&mill_timers), struct mill_timer, item);
        if(tm->expiry > nw)
            break;
        mill_list_erase(&mill_timers, mill_list_begin(&mill_timers));
        tm->expiry = -1;
        if(tm->callback)
            tm->callback(tm);
        fired = 1;
    }
    return fired;
}

// 初始化定时器列表（postfork？fixme!!!）
void mill_timer_postfork(void) {
    mill_list_init(&mill_timers);
}
```

# 8 Debug

想更好地debug libmill？

osx下面通过```brew install libmill```安装的是共享库libmill.so，很多调试信息都已经被优化掉了，调试起来不是很方便，为了更好地进行调试，可以自己从源码构建安装libmill。

```
git clone https://github.com/sustrik/libmill
cd libmill

./autogen.sh
./configure --disable-shared --enable-debug --enable-valgrind

make -j8
sudo make install
```

[libmill_vs_goroutine]:data:image/png;base64,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AgAAAAAAAAH3AAAAKAAAAfcAAAH3AADVy/YRyMMAAEAASURBVHgB7N1viBvZmfj7Z2ACbZiADfMDGxJYh12Ihyy0zAZ2BvZFPGShNeRCZByITQL3ajrwu5NdcDQbcHruvjCaDXjbG/D27A887V1wUAc2qBcc5ICDel8E2gEH9YBD94CH9oIH1DADavCABDbUfUpSqc4pVZVKf1pdan8bbP2rP6c+51TVqafOOfWSo3/CHwIIIIAAAggggAACCCCAAAIIIIAAAgggMIbASwQax9BjVgQQQAABBBBAAAEEEEAAAQQQQAABBBBoCxBopCAggAACCCCAAAIIIIAAAggggAACCCCAwNgCBBrHJmQBCCCAAAIIIIAAAggggAACCCCAAAIIIECgkTKAAAIIIIAAAggggAACCCCAAAIIIIAAAmMLEGgcm5AFIIAAAggggAACCCCAAAIIIIAAAggggACBRsoAAggggAACCCCAAAIIIIAAAggggAACCIwtQKBxbEIWgAACCCCAAAIIIIAAAggggAACCCCAAAIEGikDCCCAAAIIIIAAAggggAACCCCAAAIIIDC2AIHGsQlZAAIIIIAAAggggAACCCCAAAIIIIAAAggQaKQMIIAAAggggAACCCCAAAIIIIAAAggggMDYAgQaxyZkAQgggAACCCCAAAIIIIAAAggggAACCCBAoJEygAACCCCAAAIIIIAAAggggAACCCCAAAJjCxBoHJuQBSCAAAIIIIAAAggggAACCCCAAAIIIIAAgUbKAAIIIIAAAggggAACCCCAAAIIIIAAAgiMLUCgcWxCFoAAAggggAACCCCAAAIIIIAAAggggAACBBopAwgggAACCCCAAAIIIIAAAggggAACCCAwtgCBxrEJWQACCCCAAAIIIIAAAggggAACCCCAAAIIEGikDCCAAAIIIIAAAggggAACCCCAAAIIIIDA2AIEGscmZAEIIIAAAggggAACCCCAAAIIIIAAAgggQKCRMoAAAggggAACCCCAAAIIIIAAAggggAACYwsQaBybkAUggAACCCCAAAIIIIAAAggggAACCCCAAIFGygACCCCAAAIIIIAAAggggAACCCCAAAIIjC1AoHFsQhaAAAIIIIAAAggggAACCCCAAAIIIIAAAocbaHwu0mq1Ornwssjcy3Mi+ur9tb5oydwr+h1/CCCAAAII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EEDAEyDQ6EnwigACCCCAAAIIIIAAAggggAACCCCAAAIjCxBoHJmOGRFAAAEEEEAAAQQQQAABBBBAAAEEEEDAEyDQ6EnwigACCCCAAAIIIIAAAggggAACCCCAAAIjCxBoHJmOGRFAAAEEEEAAAQQQQAABBBBAAAEEEEDAEyDQ6EnwigACCCCAAAIIIIAAAggggAACCCCAAAIjCxBoHJmOGRFAAAEEEEAAAQQQQAABBBBAAAEEEEDAEyDQ6EnwigACCCCAAAIIIIAAAggggAACCCCAAAIjCxBoHJmOGRFAAAEEEEAAAQQQQAABBBBAAAEEEEDAEyDQ6EnwigACCCCAAAIIIIAAAggggAACCCCAAAIjCxBoHJmOGRFAAAEEEEAAAQQQQAABBBBAAAEEEEDAEyDQ6EnwigACCCCAAAIIIIAAAggggAACCCCAAAIjCxBoHJmOGRFAAAEEEEAAAQQQQAABBBBAAAEEEEDAEyDQ6EnwigACCCCAAAIIIIAAAggggAACCCCAAAIjCxBoHJmOGRFAAAEEEEAAAQQQQAABBBBAAAEEEEDAEyDQ6EnwigACCCCAAAIIIIAAAggggAACCCCAAAIjCxBoHJmOGRFAAAEEEEAAAQQQQAABBBBAAAEEEEDAEyDQ6EnwigACCCCAAAIIIIAAAggggAACCCCAAAIjCxBoHJmOGRFAAAEEEEAAAQQQQAABBBBAAAEEEEDAEyDQ6EnwigACCCCAAAIIIIAAAggggAACCCCAAAIjCxBoHJmOGRFAAAEEEEAAAQQQQAABBBBAAAEEEEDAEyDQ6EnwigACCCCAAAIIIIAAAggggAACCCCAAAIjCxBoHJmOGRFAAAEEEEAAAQQQQAABBBBAAAEEEEDAEyDQ6EnwigACCCCAAAIIIIAAAggggAACCCCAAAIjCxBoHJmOGRFAAAEEEEAAAQQQQAABBBBAAAEEEEDAEyDQ6EnwigACCCCAAAIIIIAAAggggAACCCCAAAIjCxBoHJmOGRFAAAEEEEAAAQQQQAABBBBAAAEEEEDAEyDQ6EnwigACCCCAAAIIIIAAAggggAACCCCAAAIjCxBoHJmOGRFAAAEEEEAAAQQQQAABBBBAAAEEEEDAEyDQ6EnwigACCCCAAAIIIIAAAggggAACCCCAAAIjCxBoHJmOGRFAAAEEEEAAAQQQQAABBBBAAAEE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YxHQh47PylOOCDSOZQ9ipQgggAACCCCAAAIIIIAAAggggAACCMyWAIHG2cpPUoMAAggggAACCCCAAAIIIIAAAggggMBYBAg0joWdlSKAAAIIIIAAAggggAACCCCAAAIIIDBbAgQaZys/SQ0CCCCAAAIIIIAAAggggAACCCCAAAJjESDQOBZ2VooAAggggAACCCCAAAIIIIAAAggggMBsCRBonK38JDUIIIAAAggggAACCCCAAAIIIIAAAgiMRYBA41jYWSkCCCCAAAIIIIAAAggggAACCCCAAAKzJUCgcbbyk9QggAACCCCAAAIIIIAAAggggAACCCAwFgECjWNhZ6UIIIAAAggggAACCCCAAAIIIIAAAgjMlgCBxtnKT1KDAAIIIIAAAggggAACCCCAAAIIIIDAWAQINI6FnZUigAACCCCAAAIIIIAAAggggAACCCAwWwIEGmcrP0kNAggggAACCCCAAAIIIIAAAggggAACYxEg0DgWdlaKAAIIIIAAAggggAACCCCAAAIIIIDAbAkQaJyt/CQ1CCCAAAIIIIAAAggggAACCCCAAAIIjEWAQONY2FkpAggggAACCCCAAAIIIIAAAggggAACsyVAoHG28pPUIIAAAggggAACCCCAAAIIIIAAAgggMBYBAo1jYWelCCCAAAIIIIAAAggggAACCCCAAAIIzJYAgcbZyk9SgwACCCCAAAIIIIAAAggggAACCCCAwFgECDSOhZ2VIoAAAggggAACCCCAAAIIIIAAAgggMFsCBBpnKz9JDQIIIIAAAggggAACCCCAAAIIIIAAAmMRINA4FnZWigACCCCAAAIIIIAAAggggAACCCCAwGwJEGicrfwkNQgggAACCCCAAAIIIIAAAggggAACCIxFgEDjWNhZKQIIIIAAAggggAACCCCAAAIIIIAAArMlQKBxtvKT1CCAAAIIIIAAAggggAACCCCAAAIIIDAWAQKNY2FnpQgggAACCCCAAAIIIIAAAggggAACCMyWAIHG2cpPUoMAAggggAACCCCAAAIIIIAAAggggMBYBAg0joWdlSKAAAIIIIAAAggggAACCCCAAAIIIDBbAgQaZys/SQ0CCCCAAAIIIIAAAggggAACCCCAAAJjESDQOBZ2VooAAggggAACCCCAAAIIIIAAAggggMBsCRBonK38JDUIIIAAAggggAACCCCAAAIIIIAAAgiMRYBA41jYWSkCCCCAAAIIIIAAAggggAACCCCAAAKzJUCgcbbyk9QggAACCCCAAAIIIIAAAggggAACCCAwFgECjWNhZ6UIIIAAAggggAACCCCAAAIIIIAAAgjMlgCBxtnKT1KDAAIIIIAAAggggAACCCCAAAIIIIDAWAQINI6FnZUigAACCCCAAAIIIIAAAggggAACCCAwWwIEGmcrP0kNAggggAACCCCAAAIIIIAAAggggAACYxEg0DgWdlaKAAIIIIAAAggggAACCCCAAAIIIIDAbAkQaJyt/CQ1CCCAAAIIIIAAAggggAACCCCAAAIIjEWAQONY2FkpAggggAACCCCAAAIIIIAAAggggAACsyVAoHG28pPUIIAAAggggAACCCCAAAIIIIAAAgggMBYBAo1jYWelCCCAAAIIIIAAAggggAACCCCAAAIIzJYAgcbZyk9SgwACCCCAAAIIIIAAAggggAACCCCAwFgECDSOhZ2VIoAAAggggAACCCCAAAIIIIAAAgggMFsCBBpnKz9JDQIIIIAAAggggAACCCCAAAIIIIAAAmMRINA4FnZWigACCCCAAAIIIIAAAggggAACCCCAwGwJEGicrfwkNQgggAACCCCAAAIIIIAAAggggAACCIxFgEDjWNhZKQIIIIAAAggggAACCCCAAAIIIIAAArMlQKBxtvKT1CCAAAIIIIAAAggggAACCCCAAAIIIDAWAQKNY2FnpQgggAACCCCAAAIIIIAAAggggAACCMyWAIHG2cpPUoMAAggggAACCCCAAAIIIIAAAggggMBYBAg0joWdlSKAAAIIIIAAAggggAACCCCAAAIIIDBbAgQaZys/SQ0CCCCAAAIIIIAAAgggMB6Blwey/bu78vilyLGvnZZTXz8ynu1grQgggAACYxOYukDj/l/uy+ZuRQ59wTM7kENfeUdOz70xNkBWXBfYf/pU5NAROfKlQyK1vOlO5mB/X/Y/P6jP9IVD8sYbFEq6E2RqBBBAAAEEEEBguAKUw5P77v5hU3afaV3Fm8ULun3jtKTerH1KvpApnHL/vz6Qo6evNLY8IzsvCnKih7rBFCZ9Ija5VqfS/e3IkSON+nJ3m0WdrDsvpkYAgXCB6Qo0vnws733xLVm10zK3ItXtbP0ibn/P+5EJ7P/xphz9xo+b68s/qsqFryYo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
