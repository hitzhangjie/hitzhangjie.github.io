---
title : "libmill: go风格协程库设计实现"
description: "我们只想要一个协程化的开发能力以及基于CSP的数据共享，难道我们就需要一门新的语言，比如golang？有很多开发人员曾经提出类似的质疑，笔者刚接触go时也抱着类似的想法。那么不妨思考下如果用c/c++的话，如果要实现上述功能，我们应该如何实现呢？ZeroMQ之父Martin Sustrik就用1w多行代码实现了一个非常优雅的go风格协程库，不妨来一起学习下。"
date: 2020-10-06T08:48:23+00:00
lastmod: 2020-10-06T08:48:23+00:00
draft: false
book: "/libmill-book"
cover : "assets/libmill.png"
images: []
---

我们只想要一个协程化的开发能力以及基于CSP的数据共享，难道我们就需要一门新的语言，比如golang？有很多开发人员曾经提出类似的质疑，笔者刚接触go时也抱着类似的想法。那么不妨思考下如果用c/c++的话，如果要实现上述功能，应该如何实现呢？

<div class="center" align="center" style="padding-bottom: 1rem;">
<img alt="libmill" src="/books/assets/libmill.png"/>
</div>

ZeroMQ之父Martin Sustrik就用1w多行代码实现了一个非常优雅的go风格协程库，不妨来一起学习下。

本内容涉及大量的系统基础知识、设计实现细节，为了保证知识点的系统性，单独写了一本电子书，《[libmill：go风格协程库设计实现](/libmill-book)》。

欢迎阅读，如果您在阅读过程中发现有错误、疏漏、建议，不要犹豫，请给我提issue。