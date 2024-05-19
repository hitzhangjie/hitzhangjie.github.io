---
layout: post  
title: Bash常用命令
description: ""
date: 2024-05-19 09:10:25 +0800
categories: ["过去的学习笔记"]
tags: ["unix","linux","shell","bash"]
toc: true
reward: true
draft: false
---

迁移自 hitzhangjie/Study 项目下的内容，本文主要总结的是一些日常高频使用的linux命令。

```
lp	: submit files and print
pwd	: print current work directory
match pattern in bash : ? * []
extension of '{}' : b{ed,olt,ar}s
					   ls *.{c,h,o}
i/o	:
		cat	: copy input to output
		grep: match lines from input
		sort: sort lines from input
		cut : extract columns from input
			
		how to set the delimiter to space?
		note: 
			-d' ' only specify space as the delimiter,not including tab,so it's inconvenient when files contain both of space and tab.
			cut -d' ' -f2 filename
		note:
			awk regard tab and space as the delimiter,maybe it's more convenient.
			cat filename | awk '{print $2}'

		sed : edit the input
		tr  : convert input characters to others
background jobs
	& : background jobs have no access to the terminal input,i.e.background jobs cann't listen the terminal input
	jobs : list background jobs
diff	: compare files line by line
		diff -s -y file1 file2
		diff -q -y file1 file2
modify the priority of jobs
	nice -n num cmd

control key
	ctrl-c	: interrupt current cmd
	ctrl-d	: end input
	ctrl-\	: quit
	ctrl-s	: stop outputing to current screen
	ctrl-q	: restart outputing to current screen
	ctrl-u	: delete the whole cmd line
	ctrl-z	: suspend current cmd

source .bashrc
	note:after you modified file .bashrc to customize the bash environment,use cmd 'source .bashrc' to execute the cmds in file .bashrc,
	the customized bash environment will be updated!

Bash Shell Programming and Debug
	....
	....
	....
	....
	Learn it in details !

note:	set the new owner of files
	chown -R newuser dirname
	chown newuser filename

	note:   set the new group of files
	chgrp -R newgrp dirname
	chgrp newgrp filename

adduser linux
	adduser user group

	deluser linux ; sudo rm -r linux
	deluser user group

	////

	addgroup
	delgroup

	////

	passwd user		: change passwd for account user
	passwd -l user	: lock and disable login of user
					  when user try to login,he will get a message 'login incorrect'
	passwd -u user	: unlock user account
	passwd -d user	: remove password of user account

tar : packet and compress files
	
	packet:
		tar -cvf xxx.tar files	: packet files into xxx.tar
			tar cvf
	packet and compress:
		tar -zcvf xxx.tar.gz files	: packet and compress files into xxx.tar.gz by gzip
			tar cvfz
		tar -jcvf xxx.tar.bz2 files : packet and compress files into xxx.tar.bz2 by bzip2
			tar cvfj
	uncompress:
		tar -xvf xxx.tar
			tar xvf
		tar -zxvf xxx.tar.gz 
			tar xvfz
		tar -jxvf xxx.tar.bzip2
			tar xvfj

mount/umount:
	
	for cdrom:
		mount -t iso9660 /dev/cdrom	/mnt/dirname
	for u-disk:
		mount -t vfat /dev/disk/by-label/diskname /mnt/dirname

	umount /mnt/dirname

network configuration
	
	ifconfig	: show configuration
	ifconfig eth0 xxx.xxx.xxx.xxx netmask xxx.xxx.xxx.xxx	: set ipaddr and netmask for eth0,broadcast will be automatically calculated
	ifconfig eth0 down	: disable eth0
	ifconfig eth0 up	: enable eth0

	eth0	：有线以太网卡
	wlan0	：无线网卡
	lo		：回环测试网卡

at
	
	sudo service atd start
	
	at 12:10
	at>mpg123 -C -Z dir/*.mp3
	at><EOT>	

	at now +3 week
	at>..
	at>..
	at><EOT>

	note : press ctrl-d to generate a EOT signal

process management

	ps -aux	: display all processes(-a),display users(-u),display background processess(-x)
	ps -ef	: display all running processes including background processes(-e),display parental process id(-f)
	ps		: display processes running on current terminal

	pstree		: display processes tree in system
	pstree -p	: ................................,displaying their pid

	top			: dynamically display processes in system

kill process
	
	sudo kill pid
	sudo kill -9 pid	: -9,kill process forcefully

	sudo kill `cat /var/run/processname.pid`	

	note : every running process,providing its name is ABC,stores their pid in a file,named /var/run/ABC.pid

date
	
	date : display date and time
	date -s "20121224 16:40" : set date and time according to the given string

df	: display the disk space usage of every file system
	
	df -h : -h,readable for human
	
	du  : display the disk space usage of files or directories

	du -h filename	: readable for human,display file size
	du -h dirname	: ..................,display every file or dir size within specified dir
	du -sh dirname	: ..................,display total size of specified dir

wc	: count quantities of new lines,bytes,....
	
	wc -m	: count quantites of characters
	wc -c	: .................. bytes
	wc -w	: .................. words
	wc -l	: .................. lines

```
