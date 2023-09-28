---
layout: post
title: "eBPF案例及分析：gofuncgraph"
description: "可观测性（observability）是这几年开始被频繁提及的一个词，特别是在微服务领域可观测性已经成为了微服务治理的一项关键的平台化技术手段，在CNCF孵化的项目中我们看到Opentelemetry如火如荼的发展背后也逐渐出现了一些成熟的解决方案。在腾讯内部也有类似天机阁、蓝鲸、wxg等不同的解决方案。这些往往配合框架解决了微服务RPC层面 的可观测性问题，实际上借助eBPF这项革命性技术，我们还可以做更多。"
date: 2023-09-15 23:00:22 +0800
categories: ["ebpf原理及实践"]
tags: ["ebpf","observability","ftrace","gofuncgraph"]
toc: true
---

## 前言

可观测性（observability）是这几年开始被频繁提及的一个词，特别是在微服务领域可观测性已经成为了微服务治理的一项关键的平台化技术手段，在CNCF孵化的项目中我们看到Opentelemetry如火如荼的发展背后也逐渐出现了一些成熟的解决方案。在腾讯内部也有类似天机阁、蓝鲸、wxg等不同的解决方案。这些往往配合框架解决了微服务RPC层面 的可观测性问题，实际上借助eBPF这项革命性技术，我们还可以做更多。

## 背景

不久前，在做一个关于序列化方面的优化工作，先说下项目情况：项目中使用的go框架采用了pb+protoc-gen-gogofast来生成桩代码，RPC通信的时候使用pb序列化。另外呢，为了方便开发人员查看pb message对应的log信息，项目的日志库使用了pbjson将pb message格式化为json后输出到log，RPC interceptor也会使用相同的方式序列化req、rsp后将其上报到链路跟踪系统。

大致就是这样一个问题，当时对比了pbjson序列化、stdlib encoding/json序列化，segmentio/encoding/json序列化，以及bytedance/sonic序列化。哈哈，这个顺序其实就是由慢到快的一个顺序，bytedance/sonic凭借优化反射、simd等技术“遥遥领先”其他集中方案。除了benchmark的手段，我还想看看上线前后的一些详细的优化效果，比如不同包大小（比如按1KB分桶）的序列化耗时（纳秒）分布。

摆在我面前有两个办法：

- 改源码，统计下序列化前后的执行耗时，然后打log，写个工具分析下log；
- 改源码，统计下序列化前后的执行耗时，然后上报到监控，看看统计直方图；

其实都可以，但是我有点懒，我既不想去改源码（更不用说改很多）去写log、报监控，分析完了还需要再把这堆代码删掉。改完代码我还需要编译、发布，我们每次编译发布流程都要10min左右，我很不想去干这些事。

总之我既想要灵活的分析工具（能灵活指定函数名称），又不侵入业务代码，调研之后发现有开发者实现了这样的工具，[jschwinger233/gofuncgraph](https://jschwinger233/gofuncgraph)，它借鉴了内核函数图跟踪工具[ftrace](https://en.wikipedia.org/wiki/Ftrace)的设计，执行效果大致如下。借助funcgraph，很快解决了我的问题。

![gofuncgraph](assets/2023-09-15-eBPF案例及分析：gofuncgraph/image-20230915232356599.png)

## 工具介绍

gofuncgraph是借鉴了Linux内核函数图工具ftrace（function tracer）的功能，然后为go程序开发的一个函数图工具，如上图所示，你可以指定要跟踪的函数的匹配模式，然后该工具会将程序中匹配的函数名全部作为uprobe去注册，并注册上对应的回调处理函数。

处理函数中会根据是进入函数、退出函数来生成一些这样的events，每个event都有时间，这样就可以准确统计出函数的执行耗时了。然后利用调用栈信息，也可以绘制出函数调用图。最终输出上述函数图。

> 一个小插曲，[help: how to use gofuncgraph](https://github.com/jschwinger233/gofuncgraph/issues/2)，最开始我以为是要用这个工具去启动个程序才可以执行测试，是我理解有误。和作者沟通过程中，作者提到之前阅读过我写的调试器相关的电子书，并说质量很高。大家互相分享互相学习，挺好的。现在我也来学习作者的gofuncgraph，除了学习ebpf程序的写法外，我也想了解下为什么调试器的知识会用在这个程序里。

## 剖析实现

本节先介绍该工具的用户界面设计实现，然后再介绍其内部的工作逻辑，工作逻辑中会层层深入把必要的DWARF、eBPF、编译链接加载等相关的关键内容都逐一介绍下。

为了后续方便自己学习、维护、定制，我fork了作者的项目并做了一些优化、重构，如使用spf13/cobra来代替了原先的命令行框架，spf13/cobra支持长、短选项，对用户更友好。另外也对项目代码进行了一些可读性方面的优化。后续介绍将继续我修改的这个版本介绍 [hitzhangjie/gofuncgraph (dev)](https://github.com/hitzhangjie/gofuncgraph/tree/dev)。

### 命令行界面

执行 `gofuncgraph help` 查看帮助信息，简要介绍了它的用途，你可以执行`gofuncgraph --help`来查看更完整的帮助信息。

简要帮助信息：

```bash
$ ./gofuncgraph
bpf(2)-based ftrace(1)-like function graph tracer for Go! 

for now, only support following cases:
- OS: Linux (always little endian)
- arch: x86-64
- binary: go ELF executable built with non-stripped non-PIE mode

Usage:
  gofuncgraph [-u wildcards|-x|-d] <binary> [fetch] [flags]

Flags:
  -d, --debug                      enable debug logging
  -x, --exclude-vendor             exclude vendor (default true)
  -h, --help                       help for gofuncgraph
  -t, --toggle                     Help message for toggle
  -u, --uprobe-wildcards strings   wildcards for code to add uprobes
```

详细帮助信息：

```bash
$ ./gofuncgraph --help
gofuncgraph is a bpf(2)-based ftrace(1)-like function graph tracer for Go!

here're some tracing examples:

1 trace a specific function in etcd client "go.etcd.io/etcd/client/v3/concurrency.(*Mutex).tryAcquire"
  gofuncgraph --uprobe-wildcards 'go.etcd.io/etcd/client/v3/concurrency.(*Mutex).tryAcquire' ./binary

2 trace all functions in etcd client
  gofuncgraph --uprobe-wildcards 'go.etcd.io/etcd/client/v3/*' ./binary 

3 trace a specific function and include runtime.chan* builtins
  gofuncgraph -u 'go.etcd.io/etcd/client/v3/concurrency.(*Mutex).tryAcquire' -u 'runtime.chan*' ./binary 

4 trace a specific function with some arguemnts
  gofuncgraph -u 'go.etcd.io/etcd/client/v3/concurrency.(*Mutex).tryAcquire(pfx=+0(+8(%ax)):c512, n_pfx=+16(%ax):u64, m.s.id=16(0(%ax)):u64 )' ./binary

Usage:
  gofuncgraph [-u wildcards|-x|-d] <binary> [fetch] [flags]

Flags:
  -d, --debug                      enable debug logging
  -x, --exclude-vendor             exclude vendor (default true)
  -h, --help                       help for gofuncgraph
  -t, --toggle                     Help message for toggle
  -u, --uprobe-wildcards strings   wildcards for code to add uprobes
```

这里使用spf13/cobra来组织程序cmd、选项管理、帮助信息查看，说下参数设计吧：

- -d，主要是为了gofuncgraph执行时打印更多的调试信息
- -x，主要是为了将vendor包中定义的函数给排除掉
- -h，查看详细帮助信息
- -u，指定要添加uprobe探针的用户态函数名的匹配模式，支持多个，支持同时获取函数参数信息，-u是必填选项。

如何自定义帮助信息，可以改写rootCmd.Short和rootCmd.Long，这样就可以了。

如果提前熟悉spf13/cobra的话，要实现上述功能就很简单、敲一会键盘就搞定。

### 查找待跟踪函数

- 加载elf文件构造elf.File对象
- 遍历elf.symtab中的每个symbol
- 检查sym中 ST_TYPE==函数类型的symbol
- 检查symbol.Name是否匹配 `--uprobe-wildcards|-u`来决定是否要跟踪
- 检查命令行参数中的fetch中的函数名。如果指定了函数名那么最终就只输出该函数的信息，反之就输出--uprobe-wildcards匹配的所有的函数信息。

到这里，要跟踪的函数已经基本确定下来了。

### 执行uprobe注册

- 检查命令行参数中的fetch中的函数参数读取规则（实际上是和上一步同时完成的）。生成参数值提取的规则，实际上寄存器操作、栈操作的序列，这个序列能得到一个内存有效地址。读取该地址处的、指定数据类型大小的数据，就相当于读取出了参数值。

- 将筛选出来的函数名、入口地址、返回地址等封装下交给uprobe去注册。咦，怎么没有像BCC+Python那样显示注册handler呢？作者是用Cilium来开发的，Cilium有自己的类似注解的宏，它是能知道添加uprobe时如何知道handler的。

### 执行uprobe回调

- 当对应的uprobe被触发就会执行注册的回调函数，也是用C语言实现的。
  作者将其编译为ebpf后（格式为\*.o）通过//go:embed嵌入到go中的[]byte全局变量中，然后再将其提交到ebpf子系统。
- 回调函数就是将收到的通知转换为一个处理事件event，里面包含了一些区分是进入函数、退出函数的标识，以及时间戳、goid、ip等寄存器信息，交给个chan去处理。

### 处理uprobe回调

- 有个eventmanager不断地poll其中的event并进行处理，也就是说去根据这个去计算每个函数的调用栈、每个函数的执行开始时间、结束时间信息。
- 最后再显示到命令行输出界面上。

## 本文小结

至此就介绍了gofuncgraph的工作原理。gofuncgraph输出的函数调用栈信息，要通过DWARF .debug_frame来确定调用栈信息，所以这里又是一个DWARF的使用场景。

