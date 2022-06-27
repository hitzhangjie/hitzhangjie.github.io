---
title: "为什么需要内存对齐，以及如何控制对齐"
description: "介绍下内存对齐访问（aligned access）的重要性，以及不对齐访问的情况下不同处理器的不同的行为，以及如何规避这些问题，比如编译期层面可能有哪些措施。也描述了下如何通过GCC扩展来控制aligned boundary或者packed。"
date: 2022-06-26 23:57:00.299 +0800
categories: ["技术视野"]
tags: ["内存对齐","alignment","padding","packed"]
toc: true
hide: true
---

## 什么是内存对齐？

所谓的内存对齐，指的是我们的一些数据在内存中组织的时候，为了后续访问时效率更高，需要将其起始地址进行一定的对齐处理，最常见的就是讲结构体各个成员起始地址分别对齐，非结构体比如一个普通的int数也会对齐处理的。

举个int数的例子：

```c
int n = 100;
printf("n: %d\n", n);
printf("sizeof(int): %lu, address: %p\n", sizeof(n), &n);
```

运行后发现n的大小是4字节，地址是0x16d216c4c，hex 'c'对应二进制数为1100，低位是00，00表示是4字节对齐的，那这个int数在内存中组织就是4字节对齐的。

再看个struct结构体：

```c
typedef struct {
    char sex;
    int age;
} Person;

Person p;
printf("sizeof(person): %lu\n", sizeof(p));
printf("person.sex address: %p\n", &p.sex);
printf("person.age address: %p\n", &p.age);
```

运行后发现p的大小是8个字节，我们书本上学习过，sex放在地址0，age放在地址4处，sex后有3个padding char，这样整个是8个字节。然后我们继续看下地址:

```bash
person address: 0x16fdbac44
person.sex address: 0x16fdbac44
person.age address: 0x16fdbac48
```

struct的首地址跟第一个成员的首地址是相同的，低位的44表示01000100，说明这个结构体本身以及内部成员sex都是4字节对齐的，然后age地址低位是01001000，其实这个是8字节对齐的，自然也是4字节对齐的。这么看下来这个结构体中各个字段都是4字节对齐的。在sex和age之间padding了3个char。

这就是内存对齐了，至少直观地知道是什么了。

> 简单地说，当我们希望读取的数据字节数是N，该数据起始地址是addr，假设 `addr % N == 0` 就是aligned access，反之就是unaligned access。

## 为什么需要对齐？

那么为什么要填充些padding数据呢？这就涉及到处理器访存的工作过程了，我们怎么控制处理器访问内存数据的？一般就是通过mov指令来将内存数据搬迁到内存后者寄存器中。mov指令，指令译码、指令执行，其实就是把一个内存地址放到地址总线上通过内存总线控制对应地址可读，然后通过数据总线从指定起始地址处连续读取数据总线位宽的数据到MDR（存储器数据寄存器）然后进一步加载到指定寄存器或者内存中。

这里有什么要关注的吗？有，比如8086 20位的地址线可以寻址1MB的内存，内存以字节编址，那么20位地址线可以寻址内存空间为2^20=1MB，一次读取的数据量取决于数据总线位宽，比如8086位 16位数据线，一次也就读取2个字节。

假设我们一个int数吧存放在地址0处，那么我1条汇编指令mov ax, 0x0就可以完成，为啥呢，数据总线是16位的，一次就能读取出来放到ax里。

那么如果这个int数不在地址0处，而是在0x1处呢？此时一条mov ax, 0x0就不够了，只读了8个字节，还有8个字节在0x2处，最后就只能movb al, 0x1, movb ah, 0x2。和内存对齐的相比，这种就多了一次访存操作，执行效率自然就慢了啊。

上面这个例子基本总结了内存对齐的原因，就是为了尽量通过内存对齐充分发挥硬件访问内存的效率，避免因为未合理对齐导致的编译器需要安插一些其他更多的内存访问指令，每条指令执行都需要经过取指、译码、执行等过程，而且还是访存，访存和处理器计算的效率是不在一个数量级的。所以要内存对齐。

> 准确地说，unaligned access的坏处主要包含这些，跟平台有关系：
>
> - 有的平台会透明处理这些问题，只不过是性能上会有些下降；
> - 有的平台可能会抛异常，异常处理函数来解决，性能开销更大；
> - 有的平台可能会抛异常，异常信息不明确，无法修复；
> - 有的平台可能不能正常处理，请求了错误的内存地址的数据，导致bug；
>
> 一般编译器会考虑不同平台的差异性，尽量生成aligned access的指令。
>
> see：[linux unaligned memory access](https://sourcegraph.com/github.com/torvalds/linux/-/blob/Documentation/core-api/unaligned-memory-access.rst)。

## 内存对齐基本规则？

内存对齐规则，大面上的大家都清楚，就是算呗，按那几条对齐规则来。

举个例子：

```c
typedef struct {
	char sex;
  int age;
} Student;
```

sex占1个字节，放在地址p处1字节对齐；age是4个字节的话应该4字节对齐，这样sex后应该填充3个padding char，age放在地址p+0x4处，本身为4字节。这样整个struct大小为8字节，各字段也合理对齐了。

读者可以自行找些网上的相关资料了解更多对齐的信息。

## 如何认为控制对齐？

对于编译期默认是如何控制对齐的，我们可以写程序轻松验证出来。其实gcc编译期扩展可以通过attribute进行修饰，对结构体对齐、结构体字段的对齐规则进行精细控制。

这部分我们就通过程序来验证学习下，不做过多解释了，注释可以说明一切。

```c
#include <stdio.h>

typedef struct {
    char sex;
    int age;
} Person;

// because it's packed, so sizeof is 5 bytes
// 1 + 4 = 5 bytes
typedef struct __attribute__ ((packed))
{
    char sex;
    int age;
} Student;

// this way: 1 + 4 + 3padding + 4 = 12 bytes
struct StudentX {
    char sex __attribute__ ((aligned (1)));
    int age __attribute__ ((packed));
    int xxx __attribute__ ((aligned(4)));
};

// this way, the sizeof StudentY will be 16 bytes
// 8 + 8 = 16 bytes
struct StudentY {
    char sex __attribute__ ((aligned (8)));
    int age __attribute__ ((aligned (8)));
};

// this way, add attributes to the struct means this struct:
// - aligned(4) : sizeof is 8
// - aligned(8) : sizeof is 8
// - aligned(16) : sizeof is 16
// - aligned(32) : sizeof is 32
//
// i don't know how aligned affects struct members, it looks like
// telling the compiler to try to align the struct members in this way:
// - if aligned (n) is too small, use default value, like char:1 int:4
// - if aligned (n) is bigger than default values, try to align to bigger boundary.
typedef struct __attribute__ ((aligned (4))) 
{
    char sex ;
    int age ;
} StudentZ;

int main(int argc, char **argv)
{
    int n = 100;
    printf("n: %d\n", n);
    printf("sizeof(int): %lu, address: %p\n", sizeof(n), &n);

    Person p;
    printf("sizeof(person): %lu\n", sizeof(p));
    printf("person address: %p\n", &p);
    printf("person.sex address: %p\n", &p.sex);
    printf("person.age address: %p\n", &p.age);

    Student s;
    printf("sizeof(student): %lu\n", sizeof(s));
    struct StudentX x;
    printf("sizeof(studentx): %lu\n", sizeof(x));

    struct StudentY y;
    printf("sizeof(studenty): %lu\n", sizeof(y));

    StudentZ z;
    printf("sizeof(studentz): %lu\n", sizeof(z));
    printf("address of z: %p\n", &z);

    return 0;
}
```

运行程序进行测试：

```bash
n: 100
sizeof(int): 4, address: 0x16b356c4c
sizeof(person): 8
person address: 0x16b356c44
person.sex address: 0x16b356c44
person.age address: 0x16b356c48
sizeof(student): 5
sizeof(studentx): 12
sizeof(studenty): 16
sizeof(studentz): 8
address of z: 0x16b356c18

```

通过这里的测试程序，以及输出的结果，我们应该能推断出编译期扩展 `__attribute__ ((aligned (n))) `与` __attribute__((packed))`的差异。packed表示不再对其进行padding，aligned表示了按照多少字节控制对齐，如果不超过指定的n就不能完成对对齐，就用默认可行的值，如果n超过了最小阈值则安n进行。

## 总结

本文小结了数据、结构体及其字段在内存中的对齐，并通过实例解释了gcc扩展对对齐的控制。之前天美J3面试时有问及计算sizeof时又没有例外情况，当时也没想起来。除了平台原因（比如int数大小不是4字节），再或者如果是采用的gcc attributes对其进行了扩展，比如padding或者比较大的aligned value也会导致计算结果不一样的问题。