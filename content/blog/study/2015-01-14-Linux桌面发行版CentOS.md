---
layout: post  
title: Linux桌面发行版CentOS
description: ""
date: 2015-01-14 00:30:02 +0800
categories: ["过去的学习笔记"]
tags: ["unix","linux","distro"]
toc: true
reward: true
draft: false
---

迁移自 hitzhangjie/Study 项目下的内容，本文主要总结的是Linux发行版使用过程中一些常用设置。

1. 中文输入法
	安装完centos之后，在输入法中默认是没有添加中文输入法的，这个时候，运行
ibus-setup添加上中文输入法，具体的方式是，首先选择语言为中文，然后找到展开中文
就可以看到下面的好几个输入法，选择简体中文。然后通过system settings->input
method selector选择输入法框架为ibus，登出后重新登陆即可。

	经过安装测试，在fedora 21中进行了安装测试，配置过程是一样的。
	但是测试后也发现，在fedora中的ibus-pinyin工作起来不如在centos下效果好，经
过一段时间的使用之后换成了fcitx，目前还在使用过程中，其实我想的是，如果 fcitx
中自带的输入法如果不好用的话，后面我就直接换成sogou输入法。

2. 从本地安装源安装软件
	我之前下载的是centos-everything.iso，大约有7个G，里面包含了很多软件，为了
减少下载软件花费的时间，我们可以将这个压缩包解压到指定目录，然后将其作为本地安
装源进行软件的安装。
	在实际安装之前，我们需要首先在/etc/yum.repos.d/下面创建一个配置文件，该配
置文件告诉yum在搜索软件包的时候优先搜索本地软件源。该配置文件内容如下：

	[Local]
	name=Local Repo
	baseurl=file:///media/cdrom
	gpgkey=file:///RPM-GPG-KEY-CentOS-7
	gpgcheck=1
	enabled=1

	该配置文件中写明了软件源为目录/media/cdrom，所以我们将iso解压后的所有内容
应该放在/media/cdrom，也可以根据实际情况更改合适的路径名。

3. 桌面环境
	我安装了kde-plasma 4和gnome 3两种桌面环境，kde是我一直以来都比较喜欢的，至
于gnome3，在ubuntu下面的gnome3真心觉得很差劲，估计是centos将其优化了以下吧，感
觉还不错。

4. 显示管理器
	centos7默认使用的显示管理器是gdm，不过我还是比较喜欢kdm，但是发现现在已经
centos官方源中已经没有kdm这个软件了。甚至，在kde的相关配置界面中，也找不到kdm
相关的login登陆相关的设置了。
	这让我想起了一件事。之前安装centos7时，安装了很多第三方软件包后，从第三方
软件库中安装了kdm，结果导致系统无法启动图形界面。估计可能是rhel官方修改了某些
重要文件，这个还得等到后面我再再行测试。

5. plymouth设置启动界面


6. 安装epel软件源，并从中安装wine。
	我是从epel上面安装的wine，但是这里安装的wine是64位的，而且epel官方也声明了
，该wine包只支持64位windows程序。注意这一点，如果非要运行windows程序，那么就要
确保该程序是64位的。

	正是因为这个原因，我新下载了foxit reader的64位版本。ubuntu上的wine既能够支
持64位，也能够支持32位。

7. 安装软件源rpmforge
	rpmforge上面有大约5000多个软件包，……，我是要解压说rar文件的时候，发现没有
这个程序，google了下发现了第三方软件源rpmforge。

    ```bash
	wget http://pkgs.rpmforge.org/rpmforge-release/
			rpmforge-release-0.5.3-1.el7.rf.x86_64.rpm
	rpm -Uvh rpmforge-release-0.5.3-1.el7.rf.x86_64.rpm
    ```

8. yum-axelget
	安装这个yum并行下载插件，大大提高下载速度。该插件利用了软件axel，它是一个
并行下载工具。

9. ntfs-3g
	epel软件源中包含了该软件，安装后可以支持ntfs分区。

10. mendeley desktop论文管理工具
	可以i线上、线下两种方式工作！
	由于epel上的wine是64位程序，只能支持64位的exe程序运行，无法运行我的32位的
foxit reader，但是好像也没有必要非得用foxit reader，用这个也挺好的。
	之前我在windows下面看的很多pdf的书籍，不少都是通过foxit reader加了批注的，
如果没有foxit reader，我就不能显示出之前所加的批注信息。

11. vim
	centos下面使用vim打开文件的时候，以前关闭该文件的时候停留在哪一行，打开之
后就停留在哪一行。估计是运行vim的时候加了某些配置参数，才能实现这个功能。

12. plymouth
	centos中，plymouth相关的命令包括plymouthd、plymouth-set-default-theme、
plymouth。
	其中plymouthd是服务，plymouth-set-default-theme可以用来查看、设置、设置并
更新initrd。plymouth是一个客户程序，可以用来查看splash等等。

	如果想测试plymouth的主题，需要切换到运行级2或3，然后运行plymouthd，再运行
plymouth-set-default-theme设置主题，然后运行plymouth --show-splash，所有运行
的命令，都需要root权限。测试完成后，运行plymouth --quit退出测试。
	如果已经选定了中意的主题，可以通过plymouth-set-default-theme <theme> -R来
重建initrd，这样下次启动的时候，就可以显示新设置的主题了。
	为什么要重建initrd，因为plymouth主题是从initrd中加载的，当然要更新initrd。

13. 打造自己的桌面环境

Redhat Trinity Repo Installation
	1)安装epel，我的为7.5，官方说明中是7.2，但是它的官网上已经更新到了7.5，7.2的
包已经被删除。我是直接从centos的官方源中安装的epel。
	2)Nux Desktop：A desktop and multimedia oriented RPM repository for EL。这个
包依赖于前面安装的epel，安装方式：
    ```bash
	rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/ \
			nux-dextop-release-0-1.el7.nux.noarch.rpm
    ```
	如果之前没有安装epel，可以这样安装：
    ```bash
    rpm -Uvh https://dl.fedoraproject.org/pub/epel/7/x86_64/e/ \
			epel-release-7-2.noarch.rpm \
	&& \
	rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/ \
			nux-dextop-release-0-1.el7.nux.noarch.rpm
    ```
	3)install trinity
    ```bash
	rpm -Uvh http://ppa.quickbuild.pearsoncomputing.net/trinity/trinity/rpm/ \
			el7/trinity-3.5.13/RPMS/noarch/extras/ \
			trinity-repo-3.5.13.2-2.el7.opt.noarch.rpm
    ```
	4)这个时候我们希望安装kdm，yum search kdm的时候，找到的相关软件包括
	system-switch-displaymanager.noarch。
	但是运行后发现这个只是用来切换的，并不包含显示管理器的安装包。
	不过安装了2）中d软件源之后，确实增加了很多之前搜索不到的软件，比如smplayer
	等。


