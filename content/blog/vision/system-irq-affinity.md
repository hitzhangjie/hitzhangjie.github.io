---
title: 中断请求亲和性
description: "计算机硬件设备，有些通过中断的方式通知CPU有数据到达进而可以对其进行处理。那么这里设备的中断请求是如何发送到各个处理器的呢，是发送到所有的处理器，还是选择一个发送，有没有可能指定响应中断的CPU列表，即本文提到的中断请求的亲和性问题。Linux内核文档中irq-affinity.rst对此进行了描述，本文参照着文档对irq affinity进行设置、测试，加深理解。"
date: 2022-06-29 20:48:50 +0800
categories: ["技术视野"]
tags: ["irq", "affinity", "interrupt"]
toc: true
hide: true
---

SMP IRQ affinity，指的是对称多处理器中的中断请求绑定。

/proc/irq/IRQ#/smp_affinity和/proc/irq/IRQ#/smp_affinity_list指明了允许接收某
个中断请求IRQ#的多个或某个cpu。它是一个位掩码smp_affinity或者一个cpu列表
smp_affinity_list，其中记录了允许接受该中断请求的cpu。不允许禁止所有cpu接收该
中断请求，如果一个中断控制器不支持中断请求绑定，那么只能采用默认值，即允许所有
cpu接收该中断请求，并且这个值不会被修改。

/proc/irq/default_smp_affinity指明了默认的中断绑定掩码，这个默认值将应用于所有
的非活动的、未激活的中断号。一旦一个中断号被分配、激活，那么它的中断绑定掩码将
被设置为这个默认值。这个默认值可以通过前面提到过的方法进行修改。这个默认掩码的
值为0xffffffff，请注意，该掩码是32位的。

这里举个例子，网卡eth1中断请求IRQ44限定发送到CPU0-3，而后再限定发送到CPU4-7。

网卡向cpu发中断请求44，下面我们对这个中断请求与cpu的绑定关系进行设置，并通过
ping命令进行测试，网卡会将接收到的icmp请求，以中断44的形式发送到绑定的cpu，通
过查看cpu接收到的中断请求数量，我们可以判断，这个44这个中断请求与cpu的绑定关系
。

```bash
[root@moon 44]# cd /proc/irq/44
[root@moon 44]# cat smp_affinity
ffffffff
```

首先，查看到44这个中断请求的默认绑定掩码为0xffffffff，说明，所有的cpu都可以接
收该中断请求。

```bash
[root@moon 44]# echo 0f > smp_affinity
[root@moon 44]# cat smp_affinity
0000000f
```

然后我们设置smp_affinity的值为0x0000000f，即使得编号为0-3的cpu允许接收该44这个
中断请求，其他的cpu都不会接收44这个中断请求。

```bash
[root@moon 44]# ping -f h
PING hell (195.4.7.3): 56 data bytes
...
--- hell ping statistics ---
6029 packets transmitted, 6027 packets received, 0% packet loss
round-trip min/avg/max = 0.1/0.1/0.4 ms
```

然后，对主机进行ping测试，这里的-f表示洪泛，h表示主机，实际测试的时候，可以修
改为localhost。这个时候，应用程序ping向主机发送了icmp请求包，网卡设备捕获到之
后，会向cpu发送中断号为44的中断请求。现在该主机上有8个cpu，由于我们设置了编号
为0-3的cpu可以接收该中断，其他的则不可以，那么如果我们查看cpu对中断44的接收情
况时，只有编号为0-3的cpu才能接收到中断请求。

```bash
[root@moon 44]# cat /proc/interrupts | grep 'CPU\|44:'
     CPU0 CPU1 CPU2 CPU3 CPU4 CPU5  CPU6 CPU7
 44: 1068 1785 1785 1783 0    0     0    0    IO-APIC-level  eth1
```

 通过查看测试结果，我们发现cpu 4-7 确实没有接收到编号为44的中断请求，但是编号
 为0-3的cpu接收到了该中断请求。

现在将其限定到CPU4-7上去：

```bash
[root@moon 44]# echo f0 > smp_affinity
[root@moon 44]# cat smp_affinity
000000f0
```

进一步进行测试，我们将允许接收编号44的中断请求的cpu设定为编号4-7，即将
smp_affinity的值设定为0x000000f0，下面再次通过ping进行测试。

```bash
[root@moon 44]# ping -f h
PING hell (195.4.7.3): 56 data bytes
..
--- hell ping statistics ---
2779 packets transmitted, 2777 packets received, 0% packet loss
round-trip min/avg/max = 0.1/0.5/585.4 ms
[root@moon 44]# cat /proc/interrupts |  'CPU\|44:'
     CPU0 CPU1 CPU2 CPU3 CPU4 CPU5  CPU6 CPU7
 44: 1068 1785 1785 1783 1784 1069  1070 1069   IO-APIC-level  eth1
```

将当前cpu接收到的中断请求44的数量，与前面一次ping测试时各个cpu接收到的中断请求
44的数量对比发现，只有编号为4-7的cpu接收到的中断请求44的数量发生了改变，说明我
们成功的设置了中断请求44的中断绑定到cpu 4-7。

如果想将中断请求限定发送到CPU1024-1031上，可以这么操作：

```bash
[root@moon 44]# echo 1024-1031 > smp_affinity
[root@moon 44]# cat smp_affinity
1024-1031
```

上面的语法可以将中断绑定到编号范围为1024-1031的cpu上。

see: [irq affinity](https://sourcegraph.com/github.com/torvalds/linux/-/blob/Documentation/core-api/irq/irq-affinity.rst)

