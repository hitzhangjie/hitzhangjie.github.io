---
layout: post
title: git鬼故事 - How `git rebase` Works
description: "深入分析git merge 的工作原理，探讨为什么在多线修改场景下git rebase可能不会报告冲突，导致代码重复插入的问题。然后还与git cherrypick做了对比。通过源码调试和案例分析，揭示git合并策略的设计哲学，并提供避免此类问题的实践建议。"
date: 2025-11-06 08:00:00 +0800
tags: ["git", "merge", "cherry-pick", "rebase", "apply", "conflict", "version-control"]
toc: true
reward: true
---

{{< tencent_doc src="https://docs.qq.com/doc/DYmhCZXNiYXhLVHFK" >}}

