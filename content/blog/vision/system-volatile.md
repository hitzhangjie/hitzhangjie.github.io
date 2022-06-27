---
title: "对volatile的认识"
description: "介绍了为什么c/c++需要volatile，关于volatile不能保证线程可见性的说明，以及为什么在x86上似乎可以做到线程可见性的释疑，最后简单提了下mesif来说明线程可见性是要依附于cache一致性协议的。"
date: 2022-06-26 23:57:00.299 +0800
categories: ["技术视野"]
tags: ["volatile","mesi","mesif","cache consistency","thread visibility"]
toc: true
hide: true
---



关于这个我有一篇非常不错的总结，估计是全网最好的总结：[你不认识的c/c++ volatile](https://www.hitzhangjie.pro/blog/%E4%BD%A0%E4%B8%8D%E8%AE%A4%E8%AF%86%E7%9A%84cc-volatile/)，虽然标题有点“博眼球”，但是内容绝对是很多高T都可能不知道的。

今天翻之前整理的Linux内核文档笔记时，又看到了当时volatile相关的笔记，也是因为这个事情几年前听中心的高T分享时觉得他搞错了，才写的这篇总结。

这里也放个简单的文档，系统性的强调下，认识正确了对于并发编程还是很重要的。

see also [linux volatile considered harmful](https://sourcegraph.com/github.com/torvalds/linux/-/blob/Documentation/process/volatile-considered-harmful.rst)，linus torvalds大佬亲笔。

**简单总结下的话就是：**

- volatile，需要volatile，尤其是对于涉及到外设访问的情况，有些外设的设备端口是通过统一编址来的，使用某些访存指令而非专用的in/out指令的话，有可能读的数据会做优化，比如放到寄存器中，硬件cpu还可能放到cache中。对于这些设备的读操作，需要避免优化才能正常工作，所以需要volatile。这在c/c++设备驱动中应该比较有用。
- volatile，在c/c++语言设计层面，没有保证线程可见性的任何保证，切记！它只是告知编译器不要做软件级别的寄存器优化而已，对于硬件级别的cache缓存没有任何控制。
- volatile，不能保证线程可见性，但是在不同的处理器平台上却是会有不同的表现，比如在x86平台上，加了volatile修饰的变量就能够保证线程可见性。为什么呢？首先加了volatile修饰后避免了寄存器优化，现在还有cache的顾虑对吧，但是x86平台比较特殊，它使用了一种称作 tso的memory model，x86多核能够看到其他核对某个cacheline的修改，因此能感知到最新写的数据，能做到线程可见性。
- volatile在其他平台内存模型不同，不一定能和x86一样实现线程可见性。
- 要想实现线程可见性，编译器一般是结合语言本身的特性，为止生成一些内存屏障指令，这些屏障指令最终会触发cache的MESIF协议来使得当前核上的修改对其他核可见。

