---
layout: post  
title: gdb调试常用操作
description: ""
date: 2017-05-28 23:56:48 +0800
categories: ["过去的学习笔记"]
tags: ["gdb","debug","c","cpp"]
toc: true
reward: true
draft: false
---

迁移自 hitzhangjie/Study 项目下的内容，本文主要总结的是gdb调试的常用操作。

```
### execute and trace step by step

help <topic/cmd>

list
list -				: list lines before last printed
list +				: list lines after last printed
list 3
list 3,7
list filename:3,7
list function
list filename:function
list *address

n/ni/next : next
s/si/step : next exactly
rni           : reverse ni, see also mozilla rr
sni	         : reverse si, see also mozilla rr

r/run
start
finish		 : finish current function
bt/backtrace : look stack frame and parameters
f/frame 2 	 : select stack frame
i/info locals  : show local vars 
p/print var/expression	 : print var value
set var varname=value

### breakpoints

display var
undisplay varNum

b/break lineNum/function
b/break lineNum/function [if expression]

delete breakpoints			: delete all breakpoints
delete breakpoints bpNum	: delete specified breakpoint

disable breakpoints bpNum
enable breakpoints bpNum

c/continue

info breakpoints

### watchpoints

x/7b baseAddress	: print mem data

watch varName/expression

i/info watchpoints

### backtrace 

segmentation faults generally are caused by addresses of memory spaces.
bt/backtrace : to find out which stack frame caused the error

#0,#1,#2,...,#N : #N call some function,then #N-1 created,...,#1 call some function,then #0 created,...,
if error occur in #0,it maybe caused in #1,#2,or #3,...,or #N.

### trace and debug multi-process app

fork():	how to trace and debug multi-process app

gdb:
	(1) set follow-fork-mode child
	(2) break linenumber
	note: before 'run',finish (1)(2),then 'run',we can see the output information of parent process after '(gdb)' prompt.
		  but app is interrupted by breakpoints of child process,now we can use 'n','c',... to debug the child process.

similarly,we can use 'set follow-fork-mode parent' to trace the parent process.

ps: sometimes, we may find the proper function name. `strace` may help us trace all system calls, its parameters and returned values: `strace ./a.out`.
```
