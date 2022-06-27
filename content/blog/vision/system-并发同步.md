---
layout: post
title: "并发同步"
description: "介绍下如何实现多线程、多进程间的并发同步控制，多线程场景并发控制比较常见，多进程的可能不少人都比较陌生一点吧。"
date: 2022-06-27 01:15:41 +0800
categories: ["技术视野"]
tags: []
toc: true
hide: true
---

并发同步，在并发编程中是非常重要的。当我们讨论并发编程时，我们的程序可能是通过多线程来实现，也可能通过多进程来实现。

> 我们在OS理论中了解到进程是资源分配的最小单位，线程是调度的最小单位。在Linux里面，这么讲也是成立的。更细致地说，在Linux中，线程其实就是轻量级进程LWP来表示的。对Linux调度器而言，可调度实体既可以是进程、线程也可以是一个任务组，这个任务组中又可以有其他的可调度实体。

有两个问题：

- 当我们在单进程多线程中该如何通过？

- 当我们在多个进程间进行同步时该如何同步？

**我们常用的同步的措施包括：**

- mutex/rwmutex
- semaphore
- condition variable

我们处理最多的可能就是单进程多线程情况下的同步，使用上面这些来处理没啥好说的。现在思考下，如果要实现多个进程之间的同步，有没有办法呢？

**这些玩意的实现，本质上是基于处理器指令lock addr锁总线的这一基础控制，一步步实现了CAS、Spinlock、mutex/semaphore/condvar。所以其核心就是利用了锁一个内存地址总线来实现。**

ok，那么假设我们在当前进程全局变量中初始化了一个mutex变量，然后fork下当前进程，然后**父子进程能通过这个mutex变量进行同步控制吗？**不能！因为父子进程中复制后mutex是两个不同的内存变量，这两个变量的内存地址是不同的，其实就是两个不同的锁，所以无法通过这个mutex进行正确的同步控制。

那怎么办呢？我们**只要在共享的内存空间里面来初始化这个mutex变量就可以了**（关键的就是lock的底层的内存地址一样就可以了），比如通过：

`buffer = (*buffer_t)mmap(NULL,4,devzeroFD,MAP_SHARED)`，

然后将buffer->lock作为mutex变量进行初始化，因为mmap映射的时候指定了共享模式，此时初始化写内存时也是共享的，fork的子进程初始化时其实也是同一个锁（已经初始化过不会重复初始化吧？），然后后续加解锁都是在相同的地址上了，这个很好理解，映射的是同一段内存。就能正常完成多个进程之间的同步控制。

其他的rwmutex/semaphore/condvar，理论上也可以通过相似的方法来实现。



reference:

1: 多进程并发同步控制, [Synchronization Across Process Boundaries](https://docs.oracle.com/cd/E19455-01/806-5257/6je9h032v/index.html)

2: 支持优先级继承的锁, [Priority Inheritance Mutex](https://sourcegraph.com/github.com/torvalds/linux/-/blob/Documentation/locking/rt-mutex.rst)

