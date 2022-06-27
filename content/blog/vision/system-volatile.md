---
title: "对volatile的认识"
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