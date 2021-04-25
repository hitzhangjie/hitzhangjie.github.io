---
title: "04我们应该选择哪种kafka"
date: 2021-04-26 02:00:00 +0800
categories: ["kafka核心技术与实战"]
tags: ["kafka"]
toc: true
hide: true
---

## pk其他流处理平台

Apache Storm、Apache Spark Streaming 亦或是 Apache Flink，它们在大规模流处理领域可都是响当当的名字。

令人高兴的是，Kafka 经过这么长时间不断的迭代，现在已经能够**稍稍比肩**这些框架了。我在这里使用了“稍稍”这个字眼，一方面想表达 Kafka 社区对于这些框架心存敬意；另一方面也想表达目前国内**鲜有大厂将 Kafka 用于流处理**的尴尬境地，毕竟 Kafka 是从消息引擎“半路出家”转型成流处理平台的，它在流处理方面的表现还需要经过时间的检验。

> kafka connect，扩展了kafka的流式处理生态

## 你知道几种kafka？

- apache kafka，社区版，是后续所有版本的基础
- confluent kafka，提供了一些其他功能，如跨数据中心备份、集群监控工具等
- cloudera/hortonworks kafka，提供的CDH和HDP是非常有名的大数据平台，里面集成了目前主流的大数据框架，现在两个公司已经合并，都集成了apache kafka。



## apache kafka的优缺点

优点：

- 开发人数多、活跃，版本迭代快

缺点：

- 仅仅提供最基础的组件
- kafka connect，仅提供一种读写文件的连接器，其他的要自己实现
- 没有任何监控框架或者工具，要借助第三方监控框架来监控（如kafka manager）



confluent kafka、cdh/hdp kafka的优缺点就不多说了，国内大公司很少有使用的。