---
layout: post  
title: Coroutine-Switching
color: pink
width: 4
height: 1  
date: 2017-04-26 16:23:49 +0800
tags: ["coroutine","ucontext","libtask"]
toc: true
---


### 1. 协程Coroutine

#### 1.1. 协程coroutine声明

file: coroutine.h

```c
#include <stdint.h>

typedef int64_t (*EntryCallback)(void*);

//硬件上下文信息
struct stRegister
{
    uint64_t rax;
    uint64_t rbx;
    uint64_t rcx;
    uint64_t rdx;

    uint64_t rsi;
    uint64_t rdi;

    uint64_t r8;
    uint64_t r9;
    uint64_t r10;
    uint64_t r11;
    uint64_t r12;
    uint64_t r13;
    uint64_t r14;
    uint64_t r15;

    uint64_t rbp;
    uint64_t rsp;

    uint64_t rip;
};

//协程上下文
struct stContext
{
    struct stRegister cpu_register;
    void *arg;
    uint8_t *stack;
};

typedef struct stContext Coroutine;

//创建协程
Coroutine* CreateCoroutine(EntryCallback entry, void *arg);

//删除协程
void DeleteCoroutine(Coroutine *ptr);

//设置协程栈尺寸
void SetStackSize(uint32_t size);

//协程切换
void __SwitchCoroutine__(Coroutine *cur, const Coroutine *next);
```

#### 1.2. 协程Coroutine实现

file: coroutine.c

```c
#include "coroutine.h"
#include <stdlib.h>

#define OFFSET(t, m) (&(((t*)0)->m))

uint32_t g_stack_size = 100 * 1024;

Coroutine* CreateCoroutine(EntryCallback entry, void *arg)
{
    int size = g_stack_size + sizeof(Coroutine);
    Coroutine *c = (Coroutine *)calloc(size, 1);
    if (NULL == c)
    {
        return NULL;
    }
    
    uint8_t *start = (uint8_t*)c;
    c->arg = arg;
    //函数入口
    c->cpu_register.rip = (uint64_t)entry;
    //第一个参数
    c->cpu_register.rdi = (uint64_t)arg;
    //rbp 栈底
    c->cpu_register.rbp = (uint64_t)(start + size);
    //rsp 当前栈顶
    c->cpu_register.rsp = c->cpu_register.rbp;

    return c;
}

void DeleteCoroutine(Coroutine *ptr)
{
    free(ptr);
}

void SetStackSize(uint32_t size) 
{
    g_stack_size = size;
}
```

### 2. 协程Coroutine上下文切换

file: switch.s 

```c
//这里协程库是基于有栈协程的设计来实现，协程硬件上下文信息需通过%rsp来计算访问地址

//__SwitchCoroutine__(current_coroutine, next_coroutine)
//- rdi, current_coroutine
//- rsi, next_coroutine 
.globl __SwitchCoroutine__
__SwitchCoroutine__:
    //save rsp of calling function, here %rsp equals to return address
    mov %rsp, %rax
    //set rsp to end of coroutine.stRegister, to push rip, 
	//when rdi coroutine return, it will return the rip to continue exec
    mov %rdi, %rsp
    add $136, %rsp
	push (%rax)
    //+8 to skip return address to get end address of calling function's %rsp
    add $8, %rax
	push %rax
    //store the current_coroutine's state(stRegister)
    push %rbp
    push %r15
    push %r14
    push %r13
    push %r12
    push %r11
    push %r10
    push %r9
    push %r8
    push %rdi
    push %rsi
    push %rdx
    push %rcx
    push %rbx
    push %rax
    //ready switch to next_coroutine
    mov %rsi, %rsp
    //restore the next_coroutine's stRegister to cpu 
    pop %rax
    pop %rbx
    pop %rcx
    pop %rdx
    pop %rsi
    pop %rdi
    pop %r8
    pop %r9
    pop %r10
    pop %r11
    pop %r12
    pop %r13
    pop %r14
    pop %r15
    pop %rbp
    //move return address to %rax
    mov 8(%rsp), %rax
    pop %rsp
    //jmp to next_coroutine, ram indirect access to fetch the target address
    jmp *%rax
```

### 3. Coroutine使用 & 测试


#### 3.1. 测试程序

file: main.c

```c
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "coroutine.h"

Coroutine *coroutines[3];

int64_t callback(void *arg)
{
    while(1) {
        if(strcmp((char *)arg, "coroutine-a")==0) {
            printf("[%s] ready to switch to coroutine-b\n", (char *)arg);
            __SwitchCoroutine__(coroutines[0], coroutines[1]);
        }
        else if(strcmp((char *)arg, "coroutine-b")==0) {
            printf("[%s] ready to switch to coroutine-c\n", (char *)arg);
            __SwitchCoroutine__(coroutines[1], coroutines[2]);
        }
        else if(strcmp((char *)arg, "coroutine-c")==0) {
            printf("[%s] ready to switch to coroutine-a\n", (char *)arg);
            __SwitchCoroutine__(coroutines[2], coroutines[0]);
        }
        sleep(1);
    }

    return 0;
}

int main()
{
    printf("initialize coroutine's callback\n");
    EntryCallback cb = callback;

    printf("create 3 coroutines\n");
    Coroutine *coo = CreateCoroutine(cb, (void *)"coroutine-o");
    Coroutine *coa = CreateCoroutine(cb, (void *)"coroutine-a");
    Coroutine *cob = CreateCoroutine(cb, (void *)"coroutine-b");
    Coroutine *coc = CreateCoroutine(cb, (void *)"coroutine-c");

    coroutines[0] = coa;
    coroutines[1] = cob;
    coroutines[2] = coc;

    printf("ready to start coroutine switching\n");
    __SwitchCoroutine__(coo, coa);

    printf("ready to exit\n");

    return 0;
}
```

#### 3.2. 测试程序build

file: Makefile

```makefile
all: *.c *.h *.s
	@echo "==> build the coroutine test module"
	gcc -g -o main *.c *.h *.s
	@echo "==> build successful"
test: all
	@echo "==> run the coroutine test module"
	./main
clean:
	@echo "==> delete the build file 'main'"
	rm main
```

#### 3.3. 测试结果

```
make 
make test

==> build the coroutine test module
gcc -g -o main *.c *.h *.s
==> build successful
==> run the coroutine test module
./main
initialize coroutine's callback
create 3 coroutines
ready to start coroutine switching
[coroutine-a] ready to switch to coroutine-b
[coroutine-b] ready to switch to coroutine-c
[coroutine-c] ready to switch to coroutine-a
[coroutine-a] ready to switch to coroutine-b
[coroutine-b] ready to switch to coroutine-c
[coroutine-c] ready to switch to coroutine-a
[coroutine-a] ready to switch to coroutine-b
```
