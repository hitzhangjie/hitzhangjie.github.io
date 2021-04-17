---
title: "01一条SQL查询语句是如何执行的"
date: 2021-04-17 13:08:00 +0800
categories: ["MySQL设计实现"]
tags: ["MySQL","select"]
toc: true
hide: true
---

MySQL基础架构

mysql基础架构示意图，及主要流程介绍

mysql 连接及内存管理

mysql 8.0删除了查询缓存，为什么：https://mysqlserverteam.com/mysql-8-0-retiring-support-for-the-query-cache/

优化器：存在多个索引，应该用哪一个？

mysql select语句中不存在的列，是在哪个阶段分析出来的呢？分析器



mysqld程序入口: 

- main: https://sourcegraph.com/github.com/mysql/mysql-server/-/blob/sql/main.cc#L23:12
- mysqld_main: https://sourcegraph.com/github.com/mysql/mysql-server/-/blob/sql/mysqld.cc#L7680:5

