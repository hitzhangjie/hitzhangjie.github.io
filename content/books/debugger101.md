---
title : "Debugger101: Go调试器开发内幕"
description: "授人以鱼不如授人以渔，调试器正是这样一款工具，它虽然不知道您程序中何处引入了bug或者理解不到位，但是当你想到它、捡起它，它就可以指引你一步步追根溯源。不仅要做授人以渔的工具，也要做授人以渔的人，不禁要问读者，你们可曾了解过调试器的内部实现？它是如何控制你程序执行的，它是如何知道指定内存地址处的指令或者数据类型的…本书旨在帮助读者打通对编译、调试工具链、调试信息标准以及操作系统之间的认识，使具备一定的调试器定制化开发的能力。"
lead: ""
date: 2020-10-06T08:48:23+00:00
lastmod: 2020-10-06T08:48:23+00:00
draft: false
book: "/debugger101.io" 
cover : "assets/debugger.png"
images: []
tags: ["debugger","dwarf","delve"]
---

授人以鱼不如授人以渔，调试器正是这样一款工具，它虽然不知道您程序中何处引入了bug或者理解不到位，但是当你想到它、捡起它，它就可以指引你一步步追根溯源。

不仅要做授人以渔的工具，也要做授人以渔的人，不禁要问读者，你们可曾了解过调试器的内部实现？它是如何控制你程序执行的，它是如何知道指定内存地址处的指令或者数据类型的…本书旨在帮助读者打通对编译、调试工具链、调试信息标准以及操作系统之间的认识，使具备一定的调试器定制化开发的能力。

<div align="center" style="padding-bottom:1rem;">
<img alt="debugger" src="/books/assets/debugger.png" style="width:600px;"/>
</div>

由于本书内容涉及大量系统原理、调试信息标准、设计实现、go源码分析内容，篇幅很大，很难用几篇博文讲述清楚，因此单独写一本电子书，《[Debugger101：go调试器开发内幕](/debugger101.io)》。

欢迎阅读，如您在阅读过程中遇到错误、疏漏、建议，不要犹豫，请给我提issue。