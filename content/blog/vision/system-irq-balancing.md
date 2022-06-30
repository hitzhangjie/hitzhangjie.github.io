---
layout: post
title: 中断请求负载均衡
description: "在多CPU系统上，如何对设备的中断请求进行负载均衡，以提升中断处理效率。本文以多队列、单队列网卡为例介绍了中断的负载均衡方法。"
date: 2022-06-30 07:45:47 +0800
tags: ["irq","balancing","nic"]
toc: true
hide: true
---

如果网卡NIC支持多队列，可以直接设置NIC多个队列的irq affinity到不同的CPU来实现负载均衡；
如果网卡NIC是单队列的，也可以通过RFS或者RPS在soft interrupt层面进行模拟，来实现负载均衡；
RPS、RFS这种方式主要是针对单队列NIC的优化。

我们是以网卡中断作为示例，对其他不同的设备其实也可以做类似处理。
并不是说所有的设备中断都需要绑定到多个cpu来实现负载均衡，因为有的外设的中断请求数可能并不多，就没必要了。

多队列网卡ethtool -l eth0可以看到combined字段，该字段表明NIC有几个队列，如果有多个队列，比如8个，
那么对应的cpu affinity可以直接设置成ff，表示CPU0-7都可以收NIC中断请求来实现负载均衡。

lspci -vvv可以看到不同的设备对应的中断号，如网卡设别可能是：pin A routed to IRQ 10，我们就知道10是其中断号。

TODO:

- [ ] irq affinity设定了情况下，OS和硬件是如何交互的？如何负载均衡的，是在硬件层面实现的？
- [ ] RPS/RFS，这种软中断层面的处理，具体细节是怎样的？

see [alibabacloud.com/blog/597128][1]

see [https://serverfault.com/a/514016][2]

[1]: https://www.alibabacloud.com/blog/597128
[ 2 ]: https://serverfault.com/a/514016

