---
layout: post  
title: The L4 MicroKernel
date: 2021-06-19 00:41:02 +0800
tags: ["microkernel", "L4", "L4Ka"]
reward: true
---

## L4简介

L4是在L3基础上开发的，改进了IO和IPC等，L4致力于打造一个通用的微内核，以便允许在其基础上进一步定制化来满足场景需求，L4衍生了不少微内核实现。

现在也有些工作组致力于将Linux在L4上运行起来（L4Linux），将Windows在L4上运行起来（L4Windows），著名的GNU Hurd已经从老的Mach微内核迁移到了L4微内核。

## 内核划分依据

微内核相比于宏内核，主要是微内核提供的核心更小，区别二者的依据并非源码多少，而是内核中提供功能的多寡。GNU Hurd中有提供宏内核、微内核、混合内核的对比示意图，[点击查看](https://en.wikipedia.org/wiki/GNU_Hurd#/media/File:OS-structure2.svg)。注意，宏内核有时记作monolithic kernel，也记作macro kernel。

ps：通常微内核源码会比宏内核少很多，如L4::Pistachio/ia32只有1w+左右的代码，但是Linux有几百万行。

微内核通常将内核功能限定在下面几个方面：
- 进程管理；
- 虚拟内存管理；
- 进程通信、同步机制；

其他宏内核中常见的文件系统、设备驱动、网络功能在微内核中都是在用户态实现，这些功能可能在single-server中全部实现，也可能在multi-server中实现，进程通过内核IPC机制与server之间进行通信来。

因为微内核中用户程序请求一些用户态的server（如文件系统、网络等服务）都需要借助IPC来完成，IPC用的非常多，改进其性能就显得尤为重要。早期的微内核实现IPC性能比较差，L4及以后的微内核设计都将提升IPC性能作为一个重要方向，L4中已经做的不错了，一起来了解下是如何实现的。

## 微内核优缺点

### 优点

- robustness：微内核中将很多功能在用户态实现，比如以multi-server的方式实现，假如文件系统服务出故障了，直接重启该服务即可，无需重启整个内核。而且这些服务是在用户态运行的，无权访问核心态数据，对整个内核无破坏性。微内核体积小也更方便维护、调试、定位、修复。

- security：安全是系统很重要的方面，root用户可以访问一切资源，宏内核中root的权限、可支配范围相当大，root权限被滥用会导致严重问题，如Linux 2.4以前版本ptrace可以加载任意模块包括恶意模块。微内核中这样对权限收的更紧，没那么多系统调用，自然获得root权限的入口更少，更容易约束。

- memory usage：内核的代码、数据需要常驻内存，宏内核中即便某些部分不常用到也不能够换出到交换区，会浪费内存空间，也影响用户程序执行效率。在微内核中，微内核本身体积小，宏内核中的一些核心服务被放到用户态中实现了，使用不频繁的内存区可以换出到交换区。

- performance：当想在微内核核心态执行操作时，通常要关闭中断，以避免一些重要的处理过程被中断，这么做顶多会导致当前的一些程序、服务没有处理中断请求。如果考虑实时处理的话，则需要考虑这点。

### 缺点

微内核的缺点就是程序之间、程序和某些系统服务之间的通信都需要通过IPC来完成，如果IPC性能差则会导致整体性能差，所以有很多研究如何提高IPC性能的研究。L4Ka的研究人员可以证明，能够将IPC的开销从100ms降低到5ms及以下。

see: https://www.youtube.com/watch?v=wCoLTnHUwEY.

## L4Ka的设计

L4表示第二代微内核，它吸收了第一代微内核设计上的一些经验教训，第一代微内核中Mach是最有名的实现之一。Mach和当时的其他微内核实现类似，没有自底向上地思考到底哪些功能应该在内核中实现，哪些不应该在内核中实现。其实它们看上去更像是拿到一个宏内核，然后再尝试将一些内核中的系统服务搞到用户层去。

L4考虑了这些问题，比如哪些服务在用户态运行并且不损失安全性和功能。比如L4内核甚至都没必要引入threads或scheduler的概念，只提供实现进程抢占的系统调用就可以（尽管实际情况是L4支持用户级线程）。微内核就是这样，提供最基础的功能，在不同场景中用户可以执行特定的策略来实现更加复杂的功能。

看L4Ka的详细设计之前，先来了解几个概念。

### L4Ka基本概念

- threads：线程是最基本的调度实体，只有线程可以被调度。线程之间的同学是通过IPC来完成的，每个线程都有一个寄存器集合（IP、SP、user-visible registers、processor table）、一个关联的task、进程地址空间、pagefault handler（页式管理器，通过IPC接收pagefault请求）、exception handler、preempters和一些其他的调度参数（优先级、时间片等）。

- tasks：task提供了进程执行需要的环境，它包括了一个虚地址空间、通信端口，一个task至少包括了一个thread，最新的L4实现不限制线程数量。task中创建的所有线程（除了主线程）创建后都需要显示启动，通过系统调用lthread_ex_regs()来启动。一个clan可以包括一个或多个tasks，其中只有一个是chief task，一个task创建另一个task，前者成为后者的chief task。task只可以被chief task kill掉，或者因为chief task被kill掉而间接被kill掉。

ps：这里clan、task、chief task的关系，可以联系下Linux下的会话session、会话首进程、进程组、组长进程、父进程之类的来理解。

- flexpages and Virtual Address Space：flexpages指的是flexible large memory pages，L4通过这些内存来访问主存和设备IO内存。进程虚地址空间也是由flexpages构成的，提供了两个系统调用来管理flexpages：grant、map、flush。grant将内存页从一个user交给另一个user，前者失去访问权限；map将内存页共享给另一个task，二者均可以访问；如果一个内存页已经映射给其他用户使用了，flush将清空对应地址空间。

### IO实现

L4并没有在内核中实现IO，而是将其放到了内核外的用户层去实现。内核只是接受IO相关的中断请求（IPC请求的形式），然后将其转发给对应的设备驱动来完成处理。访问外设IO都是以这种方式进行的。


### IPC实现

假如task A的线程发送给task B中的线程一个消息M，需要经历这么几步：
- A: load B的id
- A: load data of M
- A: call kernel
- kernel: read IPC request，load B的id
- kernel：switch rsp to B's rsp
- kernel：switch VMA to B's VMA
- kernel: load A的id并设置
- kernel：return to userspace（B's VMA)
- B: receive A发送的M（来自kernel load A的id并设置这步）

ps：这里的设计实现see：https://www.youtube.com/watch?v=mRr1lCJse_I。据说现在宏内核之所以还能活的好好的，主要是之前的微内核IPC性能实在太差。

如果是发送小消息，拷贝数据到用户态深圳可以用寄存器来搞定，速度快；如果是发送大消息，则需要减少这里的两次拷贝到一次拷贝，怎么搞呢？让B先设置一个共享内存区，然后A将M写入后call kernel，内核直接切换到B，从共享内存区中recieve数据。

Linux中的IPC涉及很多操作：数据copy、syscall、ctxt switch、blocking、waking，但是微内核L4设计中可以去掉scheduler导致的blocking、waking开销，数据拷贝也可以分为寄存区、共享内存区方式来减少往内核缓冲区的一次拷贝，系统调用中做的工作也简单，整体可以去掉不少开销。

本分析中测试给出的数据（不确定一次通信传输了多少数据）：
- Linux IPC开销~4500 cycles，约2微秒
- L4 IPC开销~900 cycles，约0.33微秒

L4 IPC性能大致是Linux的5倍，之前有个L4 fast inter-process communication的分享提到L4是L3 IPC性能的20倍。

微内核IPC设计及优化，不止上面这点，详细地可以参考：[GW AdvOS: Microkernel IPC Design and Optimizationm](https://www.youtube.com/watch?v=wCoLTnHUwEY)。

### 安全性实现

L4安全性机制是基于secure domains来实现的，即tasks、clans、chiefs。之前有提到过L4中进程通信不是基于channel的而是基于IPC请求的。如果是同一个clans中的task通信，那么直接用普通的IPC通信即可，但是如果是不同clans中的task通信，IPC消息必须转到发送方的clans的chief task处理后（chief可以对消息做些操作），才能发送给请求方所在clans的chief task，然后chief task转发给目标task。

如果是跨越机器的通信，可以把IPC换成协议TCP/IP。

ps: 至于为什么不用channels来通信的方式，简单提一下，channels通信势必要引入chan sender、receiver，sender、receiver要根据chan状态进行同步，还要考虑阻塞、唤醒问题，也不得不考虑scheduler的问题，这里的开销就上来了，会导致IPC性能很差。前面也提过了，微内核IPC设计中优化掉了部分操作来减少开销。

## 总结

本文介绍了微内核、宏内核的划分方法，介绍了L4的一些背景，以及L4中IO、IPC、安全性的实现方法。

微内核相对于宏内核来说也具有一定的优势，并且第一代微内核IPC性能差的问题已经得到了明显改善。在如今万物互联的趋势下，微内核对资源占用小的优势应该也更适合资源有限的IoT设备。现在华为也在大力推动自己鸿蒙微内核liteos_a的开源协同，微内核将来还是有很大的市场空间的。

本文就算是，我迈出了认真学习微内核设计、开发的第一步吧。


## 参考内容

1. L4 and Fast Interprocess Communication, https://www.youtube.com/watch?v=mRr1lCJse_I
2. GW AdvOS: Microkernel IPC Design and Optimizationm, https://www.youtube.com/watch?v=wCoLTnHUwEY
