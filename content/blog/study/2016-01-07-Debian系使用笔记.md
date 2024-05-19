---
layout: post  
title: Debian系使用笔记
description: ""
date: 2016-01-07 09:43:00 +0800
categories: ["过去的学习笔记"]
tags: ["unix","linux"]
toc: true
reward: true
draft: false
---

迁移自 hitzhangjie/Study 项目下的内容，本文主要总结的是一些日常高频使用的linux命令。

```
1）linux 文件目录树与磁盘分区
一块硬盘最多有4个主分区，可以将其中的主分区设置为扩展分区，然后在扩展分区中再继续划分为多个逻辑分区，从而得道更多的分区。
linux中，磁盘分区的命名方式是hdcn（ide ata硬盘）或sdcn（scsi 硬盘/sata 硬盘/usb 硬盘等），其中的c表示编号，从a开始。比如hda和hdb分别代表ide0插口上的主盘和从盘，而n则是分区编号，1～4对应该磁盘的4个可能的主分区或者扩展分区，5之后的都是逻辑分区来。
比如我的电脑是划分来3个主分区，其中一个主分区被设置为扩展分区，它们的编号分别为sda1，sda2，sda3。sda3被设为扩展分区，然后将其划分成来6个逻辑分区，编号为sda5～sda10。
不管是linux还是windows系统，每个分区的文件系统都会组织成一个目录树，对于windows系统来讲，通常每棵目录树都是并列的，并且每一个分区都分配一个盘符，由此可以确定任意文件在整个系统中的确切位置。
而对于linux系统来说，所有分区都被组织在同一个目录树上，选取一个分区作为目录树的根，其余的分区上的文件系统都被挂载到这个根目录树上的某个节点上。
相比之下，可以看出linux系统这种组织方式的优点。windows系统中，如果盘符发生了变动，并且分区中如果有与系统盘中关联的程序，那么这些程序的运行将受到影响，因为他们的程序路径发生来变动，可能环境变量等等已经失效了。而在linux系统中，如果将改动了分区，那么只需要重新改动下对应分区在根分区上的挂载点就可以了。

2）内核/模块/基本库 概念
提到linux系统时，多半是指整个操作系统，但是实际上，linux仅仅是系统的内核部分。
linux不是微内核。
通常内核不直接与我们交互，他们工作在硬件和软件之间，主要完成两大类任务：帮助软件获取硬件资源的控制权，并操控硬件；协调各个软件，让他们和谐统一地工作。
内核得天独厚的优势是：拥有系统中的最高权限。
可以将程序运行状态分为：核心态和用户态。只有极少数的核心态程序才能操纵硬件。
作为核心态程序的内核提供给用户态程序的接口称为系统调用。
内核的具体工作包括内存管理/进程调度/文件系统管理/网络通信/进程间通信，这些工作都可一划分成多种工作方式，以适应不通的需求，此外还需要驱动大量的硬件工作，所以内核的工作量是非常大的。
对于内核的设计，采取如下策略，以减少内核工作量和错误发生率：
如果工作可以在用户空间完成，就不要放入内核中，这就是所谓的微内核技术，但是linux不是微内核，但是也在逐渐地将一些可以在用户空间中完成的任务放入用户空间中。
如果内核某项工作可以做成独立的模块，那么就允许将其设计为独立的模块，然后在需要该模块的时候，再将其加载运行。

3）文件与文件系统
文件在linux系统中，是个非常重要的概念，除了普通文件之外，对于所有的设备，linux也一并将其看作是文件，像对待文件一样对他们进行操作。
在linux系统中，除了一些普通文件之外，还有其他一些特殊类型的文件，这些文件在/dev目录下基本上都可以看到。
ls -l /dev：
根据开头的第一个字符判断文件类型：
-:普通文件
d:文件目录
l:符号链接文件
c:字符设备文件，如键盘
b:块设备文件，如硬盘
f:fifo文件，队列
s:socket文件，linux中，socket既可以用来进行网络通信，也可以用于进程间通信

4）环境变量与shell
父进程的环境变量可以被子进程继承，子进程对环境变量的修改不会影响父进程。

5）网络与服务
这里主要理解daemon的意思吧，也就是daemon进程，守护进程的概念。
守护进程，就是一直处于运行状态，它监视某种事件的发生，比如有客户端请求，然后它就提供必要的服务，如果没有客户端请求，那么它就处于等待状态，等待客户端请求。

6）cat命令与tac命令
cat命令是“连接”一词的缩写形式，如果指定的参数为多个文件，它会将这几个文件衔接起来，如果通过重定向的形式将内容输出到一个新的文件，就可以实现将文件合并的功能。
tac命令，跟cat命令类似，但是它是反序的。

7）gzip与bizp2
gzip与bzip2这两个压缩程序，可以与tar实现无缝衔接，tar命令在使用的时候，常常使用选项-z或者-j，分别代表gzip和bzip2，当然对应的文件扩展名有所变化，分别为*.tar.gz和*.tar.bz2。
常用的选项-c表示compress，即压缩，-x表示解压。
	  -z表示使用gzip，-j表示使用bzip2。
	  -v表示输出压缩解压缩的文件列表。
	  -f表示对文件进行压缩解压。

apt-cache 强大的apt查询工具

9）dpkg apt的底层软件工具
dpkg一个比较实用的方法使用来备份系统已经安装的软件列表，以便重装系统之后，快速恢复系统中需要的软件，相当于对系统的一次克隆。
备份软件安装列表：
dpkg --get-selections > installedApp
将安装列表中的软件安装到系统：
dpkg --set-selections < installedApp
sudo apt-get dselect-upgrade

也可以如下操作：
dpkg --get-selections | grep -v deinstall > installedApp
dpkg --set-selections < installedApp
sudo dselect

screen
可以实现在一个终端窗口中生成多个终端，方便实用，尤其是在非x-window工作状态下，screen的重要性就体现的更加明显。
ctrl+a,c	to create a session
ctrl+a,p	go previous session
ctrl+a,n	go next session
ctrl+a,N	go to the session numbered 'N'
ctrl+a,'	go to the seesion named by 'ctrl+a,A'
ctrl+a,"	list all session and choose which to go
ctrl+a,A	rename current session
ctrl+a,d	detach current screen's display,leaving current session keeping on running

mc 命令行下的文件管理器
除了对文件的相关操作之外，还可以登录ftp服务器。

12） w3m 命令行下的www浏览工具
使用上下左右箭头可以在网页中移动，当移到某个超链接上后，可以通过回车健进行跳转。如果是在页面中的输入框中输入信息，首先敲击回车键，然后就可以输入信息来。

13） wget与curl 命令行与后台下载工具

14） grub菜单举例
#default =0 # 0 is the default
timeout =5

root (hda1,6)
splashimage /boot/grub/debian-boot.xpm.gz
foreground ffffff
background d70751

title Linux
# here is the grub location,not the / file system
/Vmlinuz root=/dev/hab7hac=scsi hdd=scsi
# here 'root' is / file system

title Linux.Stable
root (hd1,6)
/vmlinuz.old root=/dev/hdb7

title Win2000
rootnoverify(hd0,0)
makeactive
chainloader +1

这个在ubuntu发行版中不存在，但是有必要了解下。

这段脚本是menu.lst中的。
这里的grub启动中，使用了一张图片，格式是xpm格式的，然后用gzip压缩，再用gimp指定14色，640x480分辨率，存放路径为/boot/grub。

另外需注意的是，windows操作系统不是开放式系统，grub无法直接引导windows操作系统启动，grub是通过引导windows的引导程序先启动，然后再把控制权交给windows引导程序，由windows引导程序引导windows系统的启动。

mount与fstab
fstab中使用mount命令加载来一些必要的文件系统，比如/proc文件系统

16）inittab

acpi(advanced configuration and interfaces)

用户和组
命令 id，可以查看当前用户的uid，gid等等信息。
命令ps -f，可以列出当前系统中的进程以及对应的用户，以及其权限，这里进程的权限也就是用户的权限。
命令ls -l，会列出文件的相关信息，包括其权限，文件的权限信息保存在每行输出结果中的前10个字符中'- xxx xxx xxx',准确地说，是后面9个字符，第一个字符，前面已经提到过，表示文件的类型，如-，d，c，b，s，l等，后面9个字符，三个一组，前三个表示文件属主的权限rwx，中间表示当前文件所属组的权限rwx，后面三个表示其他用户的权限。

	添加用户 adduser
	删除用户 deluser
	
	需要注意，每一个用户都有一个特定的uid，用户文件只与用户的id有关系，而与用户名无关,因此当删除某个特定的用户之后（删除用户不删除用户文件），
		如果再创建一个用户，并且分配的用户id与之前删除的用户的id相同的话，那么之前用户的文件就是刚创建的用户的。
				
	添加组	addgroup
	删除组	delgroup
	将用户加入到特定组中 adduser username groupname

/etc/passwd:	账户信息
/etc/group:	组信息
/etc/shadow:	账户信息/组信息中隐藏的密码存放在这里
如果密码信息直接保存在来/etc/passwd和/etc/group中，保存的密码信息也是经过加密算法之后生成的密文，也是无法直接使用的。

/etc/passwd中定义的接待用户登录的程序，定义在/etc/shells中。如果在/etc/passwd中赋予特定用户的接待程序是错误的，不存在的，或者没有在/etc/shells中声明，该用户是无法登录系统的。

20）命令du
列出用户文件所占用空间。

21）用户磁盘限额工具quota
用户磁盘限额，这里的限额有两种方式的限额：一种是限制用户文件的容量大小；一种是限制用户文件的i-node数量（linux中，每一个文件或者目录都对应一个i-node节点），也就是说用户文件的数量。通常使用的是前者。
磁盘限额工具对达到限额的后续处理有两种：一种是软上限，这种情况下，仅仅给用户必要的警告，希望用户清理文件；一种是硬上限，这种情况，禁止用户写入更多的文件。

quota，系统掉电重启后，对于高性能日志文件系统，需要重新检查文件系统故障，比较耗时，对于一般普通用户，这种检查是不可忍受的。更多的情况下，quota是用在多用户系统或者高性能高可靠性的服务器上，而非一般桌面计算机用户。

21）日志文件
所有的日志文件都保存在/var/log目录下。
系统文件日志：
	dmesg：内核加载后，一直到用户态进程创建，这期间的所有内核输出信息，都保存在dmesg文件中，通常我们不用文件编辑器或者cat命令直接读取，二十通过		专门设计的命令dmesg来读取该日志。
	syslog：这个日志是系统日志的集大成者，几乎所有的系统日志信息都保存在这个文件中，但是为了方便查看，系统中有专门的程序对该日志中的日志信息进		行归类，并分别存放到如下几个日志文件中：kern.log,user.log,damemon.log,auth.log。
		kern.log:这是排查内核错误/硬件问题的依据。
		user.log:用户程序记录的信息。
		daemon.log:守护进程记录的信息。
		auth.log:鉴权/安全性有关的信息。
	dpkg.log：与apt/dpkg相关的日志信息。
	XFree86.n.log或者Xorg.n.log：与X-window有关的日志信息，其中的n表示第（n+1）个启动的x-window。如果图形用户界面出现问题，需要从这里查找错误。
	acpi：acpid，这个守护进程的输出信息。acpi能管理负责的任务，如果出来问题，当然要到这里来查错。不过有的计算机的硬件不支持acpi。
服务日志：
	这里的服务日志，主要指的是web服务器日志，邮件服务器日志，ftp服务器日志。

22）查找命令
程序查找：apropos whatis which whereis
文件查找：locate find
	比较强悍的就是find了，应熟悉find的使用方式。
文本匹配：grep

23） 任务执行自动化
at/cron/anacron

24） update-alternatives，常用重要选项：--list/--config/--auto/--install/--remove

软件安装一般过程
.configure	:如果运行成功，将会生成makefile文件；如果失败，需要根据提示信息，调整下系统中的软件依赖，然后再次尝试。
make		:如果运行成功，会生成可执行文件，便于之后的安装过程。如果失败，当然要继续调整。
make install 	:安装。
如果程序设计的比较好的话，可能还会有卸载程序,运行make uninstall卸载程序。

26） checkinstall

27） 自己打deb包
dpkg-buildpackage

28） shell类型
shell可以分为loginshell和nologinshell。
其中的loginshell有，比如我们在x-windows下，或者在x-window下按ctrl+F1~F6，切换运行级别后再登录系统，这都是loginshell。
其中的nologinshell有，比如xterm，gnome-terminal。对于gnome-terminal，它有两个比较重要的配置文件，一个是.bash-profile,与gnome-terminal初始化过程有关；另一个是.bashrc，与gnome-terminal的便利性有关，比如我们可以在其中定义一些常用命令及其复杂选项的alias。

29） 脚本运行的两种方式
./test.sh	:新创建一个shell，让脚本在新shell中运行，复制export导出的环境变量。因此不具备之前shell中设定的环境变量。
. test.sh	:不创建新shell，让脚本在当前shell中运行，因此，共享当前shell中设定的环境。

30） shell编程

在linux shell编程中，所有的类型都是字符串类型，并且所有的变量不用初始化。不难看出，linux shell不太适合处理数值运算任务。

赋值		： var = value
引用变量值	： $var，有时需要加上{},比如${var}aaa表示valueaaa,而$varaaa表示引用变量varaaa的值
引号		： ',",`.
		：单引号，可以将字符串括起来，但是如果字符串中含有${var},变量的取值不会被引用
		：双引号，可以将字符串扩起来，但是如果字符串中含有${var},变量的取值会被引用
		：反引号，将可执行命令扩起来，如`uname -r`，就代指命令uname -r的输出结果

一种比较高级点的应用：
${filename%jpg}JPG :表示用jpg从文件名filename右端（%的作用）开始匹配，如果filename中出现来jpg字样，那么就将jpg字样从filename去掉，并追加上字符串JPG。如果filename是图片文件的名字的话，就将图片的扩展名jpg变成来大写形式。

注意：%是从右端向左端进行匹配，#是从左端往右端进行匹配，*也是一种匹配，还不清楚是怎么个匹配方式。如果使用%%，表示从右向左的最大匹配，##表示从左向右的最大匹配。**，～～～。


test命令，测试表达式是真还是假，但是更加常用的是这种形式：	[  expr  ]
主义在中括号与expr之间有空格分隔。

字符串比较：	[ str1=str2 ] 	相等
		[ str1!=str2 ] 	不相等
		[ -n str ] 	长度不为0
		[ -z str ] 	长度为0

整数比较：	[ num1 -eq num2 ] 	相等	
		-ne：不相等；-lt，小于；-le，不大于；-gt，大于；-ge，不小于

文件比较：	[ -e filename ]	文件存在
		-d：是目录；-f，是文件；-r，可读；-x，可执行；-s，大小不为0；
		[ file1 -ot file2 ] : 前者比后者旧
		[ file1 -nt file2 ] : 前者比后者新

] 		逻辑非
] 	逻辑与
] 	逻辑或

for循环：
		for var in *.jpg
		do
			mv "${var}" "${var%jpg}JPG"
		done

while循环：
		grep -v "^#" /etc/passwd |\
		while read i
		do
			echo ${i%%:*}
		done

if分支结构：
		|	if [ ... ]    ----|
		|	then		  |
				...	  |
		|	elif [ ... ]	  |
		|	then		  |
				...       |
		|	else      	  |
				...	  |
			fi	      ----|

	
case分支结构：
			case $var in   	----|
		|	start)		    |  
		|		... 	    |
		|	;;		    |
					    |	
		|	restart|reload)	    |
		|		...	    |
		|	;;		    |
					    |	
		|	*)		    |	
		|		...         |
		|	;;		    |
			esac		----|

重定向与管道
管道的几种应用举例：
tail /var/log/syslog > latest.log

head /var/log/syslog 2> /dev/null

grep /var/log/* > logfile 2>$1

ps -e | grep terminal

tar zcf  workshop  | ssh spirit tar zxf

 
32） 特殊变量
$#		：调用脚本的命令行参数的个数
$*（或$@)	：脚本的命令行参数，如果有一个参数是“two words”，用引号扩起来了，但是$*将其看作两个参数，而$@看作是一个参数
$0		：脚本命令中的第一个值，也就是命令的名字
$?		：前一个命令的返回值，如果前一个命令返回成功，则返回0；非0表示不成功
SS(还是$$)	：当前进程的id

	
lspci
list pci devices

lsusb
list usb devices

df -h
list disk free size,option -h helps us to read in recognizable characters	

	/proc/cpuinfo	:cpu relevant information
    	/proc/version	:os information,such as os kernel version
	/proc/cmdline	:startup parameters of os kernel

lsmod
ls -l /lib/modules/`uname -r`	： list all modules that can be loaded by current os kernel
lsmod	: list all modules that have been loaded by os kernel

dwww
利用本地web服务器apache，dwww，通过浏览器查看帮助文件。http://localhost/dwww。
需要注意的是，dwww这个目录是在/var/www/dwww,原来apache默认的根目录是/var/www,但是后来自己学习php的时候，更改了根目录的位置，将其更改到了/home/zhangjie/Documents/php，而且更改的方式是直接修改apache的配置文件，而不是通过符号链接将/var/www与php坐在目录链接，而dwww下面是实实在在的文件，所以需要在php目录下面创建一个符号链接文件指向这个目录/var/www/dwww。

```
