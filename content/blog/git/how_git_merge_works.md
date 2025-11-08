---
layout: post
title: git鬼故事 - How `git merge` Works
description: "深入分析git merge 的工作原理，探讨为什么在多线修改场景下git merge可能不会报告冲突，导致代码重复插入的问题。然后还与git cherrypick做了对比。通过源码调试和案例分析，揭示git合并策略的设计哲学，并提供避免此类问题的实践建议。"
date: 2025-11-06 08:00:00 +0800
tags: ["git", "merge", "cherry-pick", "rebase", "apply", "conflict", "version-control"]
toc: true
reward: true
---

<style>
    /* 容器设置：定义可见区域 */
    .iframe-container {
        position: relative;
        height: 100vh; /* 使用视口高度，确保垂直空间足够 */
        overflow: hidden; /* 关键：裁剪掉 iframe 溢出的部分 */
        /* width: 100%; 不需要显式设置，默认为父元素宽度 */
    }

    .iframe-container iframe {
        /* 1. 保证 iframe 自身足够宽，以便容纳被隐藏的目录和要完整显示的右侧内容 */
        /* 假设内嵌页面原始宽度约为 1200px。如果你只用 100%，则 iframe 宽度会被容器限制，导致右侧裁剪 */
        width: 1200px; /* <--- 关键修改：设置为一个足够大的固定宽度！ */
        height: 98%;
        border: none;
        position: absolute;

        /* 2. 调整垂直位置，隐藏顶部标题（如果需要） */
        /* 假设顶部标题和分享按钮高度约 170px */
        top: -170px;
    
        /* 3. 调整水平位置，隐藏左侧目录 */
        /* 假设左侧目录宽度约 250px，我们向左偏移 250px */
        left: -386px; /* <--- 关键修改：增大负值，将目录移出视口 */
    }
</style>

<div class="iframe-container">
    <iframe src="https://docs.qq.com/doc/DYkpFcWpEdk1SZnNo"/>
</div>
