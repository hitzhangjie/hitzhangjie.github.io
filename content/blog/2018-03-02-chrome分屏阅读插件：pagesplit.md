---
layout: post
title: chrome分屏阅读插件：pagesplit
Description: "chrome优秀的扩展性使得它成为很多开发人员的首选浏览器，不少开发人员在使用Vim或者IDE阅读源码时，都存在vsplit/hsplit分屏的习惯，那么在通过浏览器浏览网络上的代码或者页面时，如何在浏览器页面中实现类似Vim的分屏功能呢？本文结合作者的个人项目pagesplit来介绍下如何开发一个chrome分屏阅读插件。"
date: 2018-03-02 22:21:32 +0800
tags: ["chrome", "extension", "pagesplit", "vsplit", "hsplit"]
toc: true
reward: true
---

<style>
img {
    width: 680px;
    padding-bottom: 1rem;
}
</style>

# 前言

这几天在钻研golang，经常在网上看些源码分析的文章，既然是源码分析就少不了code和分析的各种穿插描述，文章篇幅一长或者code block块比较长，经常需要滚动鼠标上下翻页，这种阅读体验好差劲。心想要是能够将web页面进行类似于vim的vsplit或者lsplit就好了。于是就有了这个chrome扩展。

# 产品调研

chrome网上应用商店中搜索了一下，找到了几个类似功能的插件“split tabs”、“tab resize”，体验之后不太满足个人需要。原因是：这两个扩展都是通过创建一个新的浏览器窗口来打开当前web页面，然后并排显示（支持水平、垂直并排显示），如下图。
 ![图片](assets/pagesplit/dGcBAAAAAAAA&bo=hAMzAoQDMwIDMBU!.png)

这种实现方式，实际使用时存在如下几个缺点：

-   工作中，我们打开的应用程序窗口可能会很多，比如rtx，各种ide，各种终端……这样alt+tab切几次之后就难受了，需要手动将两个浏览器窗口给选择出来并排显示。不好用！

-   工作中，可能工作用的web标签页有很多，各种运维平台，各种视图，各种管理后台……如果在浏览器窗口中选择了其他的tab，再次切换回之前的tab比较困难，也不容易回到初始的并排显示状态。不好用！

# 解决方案

个人感觉还是同一个tab下能够vsplit、split比较方便，chrome网上应用商店找不到合适的了，google了一下，找到另一款扩展："Frame two pages"，这个插件在功能上能满足需要，能够实现同一个tab下vsplit、split，如下图所示：

![图片](assets/pagesplit/dPIAAAAAAAAA&bo=IAOAAoQD0AIDQJE!.png)

但是其在使用时比较繁琐，当我们打开一个web页面，希望对其进行vsplit操作时，页面会弹出一个提示窗口，输入split方式，然后会执行对应的分割方式，看上去不错，但是有几个问题让人用起来很难受：

-   没有考虑浏览器的X-Frame-Options对iframe的影响，使用过程中会“莫名其妙”地split失败，比如我正在写这篇文章，来测试一下vsplit什么效果，如下图，并没有成功vsplit；

![图片](assets/pagesplit/dGoBAAAAAAAA&bo=sQNFArEDRQIDIAU!.png)

-   不实用，如果选择的tab索引index大于0，会将index-1和index进行并排展示，至少与我的页面分割的初衷不一致；

于是乎，我想改进下这个插件为我所用，说不定也可以方便大家，本着不重复造轮子的原则，安装上了这个Frame two pages扩展看了下它的代码，了解了chrome扩展的大致写法，然后对其进行了一些修改，基本符合我的功能性要求。

# 设计实现

现在实现的功能包括：

1）点击插件按钮，选择split方式，支持对当前已经打开的web页面进行split、vsplit分割。

以垂直分割当前web页面为例，首先点击扩展图标，选择分割方式为vertical分割。

![图片](assets/pagesplit/dJEAAAAAAAAA&bo=XgJPAV4CTwEDEDU!.png)

就得到了如下效果的分割页面，这个页面是在原页面tab之后创建的一个tab，不影响原来的tab。

![图片](assets/pagesplit/dGgBAAAAAAAA&bo=hAPsAYQD7AEDIAU!.png)

2）忽略所有页面的X-Frame-Options选项，保证可以打开页面（为了安全使用者自己决定用不用吧），为了使用方便我我忽略掉了所有的X-Frame-Options，使得iframe可以正常加载。

3）某些情况下可能希望分割的两部分分别展示不同的页面，也是支持的，需要在一个空白的tab页上点击页面分割，此时会展示出如下输入url的输入框，然后点击下方的按钮就可以了。

![图片](assets/pagesplit/dGcBAAAAAAAA&bo=hAPrAYQD6wEDEDU!.png)

比如一个进百度，一个进google。

![图片](assets/pagesplit/dHMAAAAAAAAA&bo=hAPnAYQD5wEDEDU!.png)

4）我觉得存在这样的使用情景，比如正在看一个博客时，希望打开搜索引擎检索部分信息，一般我们都是打开一个新的标签页进搜索引擎，看完搜索结果后再跳回原来的tab……阅读期间可能要多次跳来跳去……希望能在已经成功vsplit、split的页面里面，将其中一个reset允许我们重新输入url打开新的页面。

于是为这个插件加了菜单：

![图片](assets/pagesplit/dFYBAAAAAAAA&bo=hAPKAYQDygEDIAU!.png)

以重置vsplit后的左半部分页面为例，选择“Split Page -> Reset left/top page”。

![图片](assets/pagesplit/dJEAAAAAAAAA&bo=hAO2AYQDtgEDIAU!.png)

左半部分就被重置到重新输入url的状态了，比如希望进入google，输入google网址，点击跳转按钮即可。

# 总结

简要了解了chrome extension的开发过程，chrome不同的版本迭代过程中增加了很多安全限制，开发、调试过程中要多注意。这只是为了平时阅读代码方便二次开发的一个小工具，另外对js了解的不多，可能存在bug，也欢迎反馈。

感兴趣的可以从github下载进行体验，仓库地址：https://github.com/hitzhangjie/PageSplit。