---
layout: post  
title: "TCP/IP网络安全篇"
description: ""
date: 2013-09-30 02:08:29 +0800
categories: ["过去的学习笔记"]
tags: ["network","tcp/ip","security"]
toc: true
reward: true
draft: false
---

《TCP/IP 网络安全篇》，作者是日本的寺田真敏 萱岛 信。

感谢作者理论与实践结合的教学方式，简单地介绍了网络安全的方方面面，让
我学起来也是很有兴趣，真诚地向寺田真敏先生道一声谢谢。

下面是我对本书学习过程中的一个总结，难免有理解偏差之处，还需在以后的
学习实践过程中，进一步体会、纠正。

---

# 1 TCP/IP的基础知识

## 1.1 TCP/IP与因特网

OSI 7-layer model

```markdown

Host layers:	applications	Message
				presentation
				session
				--------------------------
				transport		Message segment
				--------------------------
media layer:	network			packet/datagram
				--------------------------
				data link		frame
				--------------------------
				physical		bit
```

用于分组交换的设备，IMP（Interface Message Processor）接口报文处理机
的第一号机被设计制成。

TCP/IP协议，是以tcp协议和ip协议为中心，构成的协议族的总称。
TCP/IP协议，从最底层开始，是由网络接口层、网络层、传输层、应用层构成。
像这样的构成层次，可以使开发工作形成模块式开发。

## 1.2 IP

### IP地址与网络分类

IP数据包的数据最大长度为65535字节。

**IP地址由网络号与主机号组成**。可以类对网络进行划分，根据网络的规模，从
A类到C类，也存在用于多播通信的D类，其他用于实验的地址还有E类。

但是在目前，为了有效利用已经濒临枯竭的IPv4地址，采用了不依赖于类的IP
地址分配方法——**CIDR（Classless Inter Domain Routing，无类域间路由）**。
而且为了解决IPv4地址的资源枯竭问题，也开发了具有128位长度的IPv6。

### 无类域间路由CIDR

无类域间路由中关键的就是子网掩码。**子网掩码，是为了改变网络号与主机号的分界位置**而采用的方法，如192.168.0.0/24，表示网络号24位，主机号8位，这个子网掩码设置就比之前分类的方式要灵活多了。

**特殊的IP地址:**
**1)本地环路地址**:linux下常见的回环接口lo，地址127.0.0.1，其ip地址可以
根据需要任意设定，也称为localhost。常被用于同一计算机上的通信。
**2)广播地址**:主机号字段全部为1。
**3)多播地址**:224.0.0.0～239.255.255.255,常被用于特定工作组中的通信。
**4)私有IP地址**:限定于内部网络使用而分配的地址，rfc1597中，建议使用以下
的地址段:
A类中，10.0.0.0～10.255.255.255
B类中，172.16.0.0～172.31.255.255
C类中，192.168.0.0～192.168.255.255
与私有IP地址相对，对于那些只使用于因特网上的IP地址，我们称为全局IP地址。

**注意IP数据包的Header，其中与分片有关的标识、标志、片偏移**，其中的片偏移
的值若为N，表示其承载数据的初始字节在原始未分片的数据包中的偏移量为64*N位。
同时，在本科学习的时候，老师几乎对选项字段没有介绍，其实，选项字段还是
非常重要的，比如选项9可以用来源路由，选项7可以记录路由路径等。

**路由控制:**
**IP数据包的传输，有两种方式**。如果发送端与接收端位于同一网络上时，则可以
直接将IP数据包传送到作为接收端的主机上，这种传输方式称为**直接传输**；另一
种方式，如果接收端处于通过路由器等中继装置连接的其他网络上，需要通过中
继装置传输数据，这种传输方式称为**间接传输**。

间接传输方式下，在经过怎样的路径将数据包传送到目的网络及主机方面，
有两种方式:一是**通过指定路径来传送数据包（源路由）**；另一种是**在路由器中**
**预先配置路由表**。

Q:关于路由时Metric与Hop的计算？
值得注意的是，跳数越少，不一定应答性能就好。

**静态路由**:手工配置路由表。
**动态路由**:通过在路由器上运行某些选路协议，动态配置更新路由表

**路由协议**:路由协议包括在网络与网关管理上群组化的AS中使用的**IGPs（Interior**
**Gateway Protocols，内部网关协议）**与**EGPs（Exterior Gateway Protocols）**。

- IGPs:有RIP和OSPF，主要是这两种。
- EGPs:主要有BGP。

IP源路由，包括两种，一个是从源到目的地指定了部分路由路径的松散源路由，
一个是指定了完全的路由路径的严格源路由。
松散源路由中指定的路由，可以是不连续的，比如说从源到端如果通过路径a->b
->c->d->e可达的话，可以只选择b,d作为源路由中的路由。书上没有提，不过我
觉得松散源路由的话，应该是这样的。

IP的错误处理，离不开ICMP。

IP与数据链路
为了IP数据包通过网络接口层，在相邻层之间进行数据传输，必须考虑到数据链
路层级的地址体系以及最大传输单元MTU。
链路层，或者说网络接口层，通过MAC（介质访问控制）地址进行数据帧的转发，
查MAC地址需要用到ARP协议。ARP查询在链路层被触发，ARP查询是通过子网内广
播的方式进行查询，理论上只能为同一子网内的主机提供ARP查询服务，但是其
实不然，如果在两个处于不是同一网段的主机A，B上，在A，B中通过添加路由，
使A，B间可以直接相互转发IP数据包，比如A的IP地址为192.168.0.1/24，而B的
IP地址位:10.0.0.1/24。

在A中添加路由:
route add -host 10.0.0.1/24 gw 192.168.0.1 metric 1 dev eth0
在B中添加路由:
route add -host 192.168.0.1/24 gw 10.0.0.1 metric 1 dev eth0

然后用一根双绞线将A，B各自的eth0适配器连接起来，那么这样的话，如果A要
给B发IP数据包的话，A首先检查路由表发现有一条路由表项，该表项指示应该将
数据包从eth0接口转发出去，那么理所当然地，到达链路层的时候，ARP请求会
通过设备eth0发出去，当B收到ARP请求之后，发现询问的正是自己的MAC地址，
然后它就把自己的MAC地址发给了A，A然后将IP数据包封装形成的数据帧发送给B，
B收到后拆掉链路层Header，提交给网络层。
在源路由的过程中，通过路由表查找下一跳路由器，找到之后，通过对应的接口
发送出ARP请求，也是相同的工作方式。

IP数据包的分割，发生在网络层，是由于链路层的MTU决定的。而链路层帧的有
效载荷的限制，不只是限制最大尺寸MTU，其实，对于最小尺寸也有限制，为什
么要限制最小尺寸呢？这在研究生计算机网络课程上提到过，有线以太网上的话
，运行CSMA/CD协议，为了能够使发送方成功检测出碰撞，通过一系列计算得出
了这个最小值。

Q:在网络核心的话，这个限制存在吗？
在用gns模拟器进行模拟的时候发现，路由器与局域网互联的时候是通过4E模块，
表示4个 以太网接口；而在路由器之间进行互联的时候，用的模块是4T，表示4
个串口。完全不一样 的接口模块，我觉得4E的口连接的链路上是有最小帧长度
限制的，而4T的口连接的链路上不会有这种限制。而且，路由器之间不处于以太
网中，不会运行CSMA/CD,加上最小帧长度限制也没有什么意义。

IP数据包分片的组装，在目的接收方进行组装，这个目的接收方可以使目的主机，
也可以是路由器，比如源路由的时候，源路由路径比较长，就可能会引起数据包
的分片，但是为了能够正确地找出下一跳的路由地址，必须对分片后的数据包进
行重组。

IP地址与主机名
DNS记录的缓存,在ubuntu 12.04 lts中是通过dnsmasq来实现的,并且dnsmasq被内
置进了network-manager中,并且随着network-manager的启动而启动,默认地,
dnsmasq的缓存机制被禁用了,从/var/log/syslog中可以找到相应的证据.

DNS查询,可以通过dig或者nslookup来实现.

1) dig hostname [option list]

+short
+nocomments		+comments
+noauthority	+authority
+noaddtional	+additional
+nostats		+stats
+noanswer		+answer
+noquestion		+question
+noall

"dig hostname +nocomments +noauthority +noaddtional +nostats +noquestion"
is equivalent to
"dig hostname +noall +answer".

-t soa
-t a
-t ns
-t mx
-t any
-t cname ??? acutally, non-existent

-x ptr, reverse lookup for PTR record
   how does reverse lookup works ???

@dnsserver to use a specified dns server for lookup
example:
	dig @202.12.27.33 redhat.com -t ns +noall +answer
	202.12.27.33 is one of the 13 root domain name servers

-f to use data file to query several hostnames
example:
	dig -f filename -t ns +noall +answer

you can also query several hostnames in one command line:
	dig hostname1 -t type1 [op-list] hostname2 -t type2 [op-list]
example:
	dig redhat.com -t ns +noall +answer centos.org -t a +answer

~/.digrc
	add options within this file to set the default query options.

example:
	append text '+noall +answer' within file .digrc, then next time
	when you start dig, options '+noall' and '+answer' will be auto
	-matically appended to the cmd option list, but these options 
	won't be displayed.

2) nslookup, using interactive mode to lookup is very convenient.

common interactive cmds:
server: specify a domain name server
host  : spefify a hostname that you want to lookup, usually host cmd 
		can be neglected, i.e, you can directly type in the hostname.
set q=type:
		set the query type, ns/a/cname/mx/ptr/soa.
set q=ns, then type '.' to display all 13 root domain name servers.
exit  : exit programme

DNS records
1) for CNAME record:

usually we think the format of CNAME record is :
|| Alias Hostname | CNAME | Canonical Hostname ||
but actually, it may be not set as you supposed, for example, right 
field 'Canonial Hostname' may not a canonical name but another alias
hostname, this leads to so-called 'alias chain' or 'alias cycle'.
so, you may not be able to use one single lookup through all CNAME 
records to find out the canonical hostname.
but, among all presented alias chains, we can pick out the right side
hostnames and put them together, all of them must appear in the alias
chains in some order, so we can find out which of them is the canonical
hostname by comparison.

if 'alias cycle' among CNAME records occurs, CNAME type query should 
respond an error message.

2) for PTR record:

the best option is to resolve the IP address to the Canonical Hostname.

rfc doesn't point out dns must implement the reverse query, it is opti
-onal. if the dns receives an unsupported query request, it should res
-ponded an error message.

rfc doesn't require we must set only one PTR record for the same one IP
address. so, some people may set multiple PTR records on the same on IP 
address. it is not reccommended !
why ?
first, if we set multiple PTR records for the same one IP address. among
the multiple PTR records, several alias hostname and canonical hostname
are contained. when an PTR type request comes, dns works in round-robin
for load-sharing, and the PTR records matched are resorted in round-robin
and then responded to your client programme. usally, the programme select
the first PTR record and resolve the IP address to the hostname. if the 
resolved hostname is an alias hostname, when we access it, something wrong 
may happen if some other hosts has an same alias hostname. it leads to a 
problem, Hosts : IP = n : 1, it is unacceptable.
so, as mentioned above, one IP should always be resolved to the canonical
Hostname.

so, dig -x, usally can  resolve the IP address to the Canonical Hostname.
while, nslookup -cname, can process ordinary "alias | cname | canonical"
format CNAME record, 'alias chain' and 'alias cycle' format CNAME records
to find out the Canonical Hostname.

dig can't directly lookup the Canonical Hostname with the Alias Hostname 
through CNAME type records.
you have to lookup the A type record to find out the IP address, then 
lookup the PTR type record to find it.

note:
	one IP address should have only one PTR record.
	but one domain, such as 10.in_addr.arpa, can have several PTR 
	records, because one domain, i.e, one network, can have multiple 
	gateways.

######################################################################

# 2 网络安全的基础知识

## 2.1 因特网上的安全

### 2.1.1 网络层

伪造IP地址
伪造ARP
伪造路径控制信息
恶意使用源路由
利用IP/ICMP数据包的DoS攻击

### 2.1.2 传输层

预测TCP初始序号
利用TCP/UDP数据包的DoS攻击

### 2.1.3 应用层

搜索/扫描
DNS欺骗
窃听
攻击程序缺陷
代理服务器的非法使用
利用电子邮件进行DoS攻击
病毒
蠕虫
木马

### 2.1.4 用户层

社交工程攻击:利用人的心理，诱使人作出某种行为，实现攻击者的目标

## 2.2 安全技术概要

### 2.2.1 加密技术

两大密钥系统，共享密钥系统和公开密钥系统。
区别:
1)共享密钥系统，加密和解密使用同一个密钥。
2)公开密钥系统，由信息的接收方，生成一对密钥，分别称为公钥和私钥。
这一对密钥，由两种使用方式。
一种是希望他人在发送给自己数据之前对数据进行加密处理,然后只有自己可以
解密，此时，密钥对的制作者，可以将公钥发布出去，对方用公钥对发送数据
进行加密然后发送给自己，然后自己通过私钥进行解密。由于私钥只有制作者
拥有，并且通过公钥无法推测 出私钥，所以即使截获了公钥，也无法解密别人
发送来的数据。
另一种是，密钥对的制作者，希望对自己发送出去的数据进行一种签名，向信息
的接收方表明，发布此信息的人确实是自己。此时，密钥对的制作者通过私钥对
信息进行签名，然后将签名和原始数据发送给对方，对方接收后利用公钥对签名
进行处理，如果还原出的数据与收到的原始数据相同，表示发送此信息的人确实
是密钥对制作者本人，这样就提供了一种身份的识别功能。
由于签名时是利用私钥进行处理，而只有密钥对制作者本人拥有私钥，所以其他
任何人无法伪造该签名，同时制作者一旦对数据进行签名，也不可以不承认这确
实是自己的签名。

3)共享密钥系统，加密解密，处理速度快，但是不够安全。
4)公开密钥系统，加密解密，处理速度慢，但是比共享密钥系统更安全。

混合密钥系统:
综合共享密钥系统和公开密钥系统的优缺点，人们在网络通信过程中，通常使用
混合密钥系统。
对于通信数据的加密解密采用共享密钥系统，因为它处理速度快。而将公开密钥
系统应用于对共享密钥的加密解密，为共享密钥的安全性提供保护。
这样既利用了公开密钥系统安全性好的优势，又利用了共享密钥系统速度快的优
势。

DES，3DES，IDEA，RC5等，这些都是共享密钥系统。
RSA等，这些是公开密钥系统。

分组密码和流式密码:
流式密码是对数据中的每一位逐位进行加密，分组密码是根据一定的分组长度对
数据先进行分组，然后逐组进行加密。

分组密码，逐组进行加密，也会分为两种。
一种是ECB（Electric Code Book）电子密码本方式，在用密钥对分组进行加密
之前，分组中的数据不再参加某些变化，因此，相同的明文分组加密后总是被加
密成相同的密文分组。
另一种是，CBC（Cipher Block Chaining）分组密码连接，后一个明文分组在进
行加密之前，需要与前一个明文分组加密后的密文分组进行异或运算，然后再用
密钥对其进行加密处理，这样，即使相同的明文分组，也会被加密成不同的密文
分组。
	

### 2.2.2 访问管理技术

为保护电子化信息，需要一定的访问管理技术，即，不能让没有正当权限的用户，
访问计算机以及计算机中的文件，这样的技术称为访问管理技术。

识别: 用户名或者ID
认证: 密码
授权: 对特定文件的读写执行权限

密码认证的危险因素
1）预防在登录时泄漏密码
例如，启动了伪造的登录程序
2）穷举尝试登录
连续登录数次失败后，禁止登录；
验证码打断穷举攻击；

利用密钥文件的认证
/etc/passwd:
	loginname:password:uid:gid:username:homefolder:shell
	password field is set to x.
/etc/shadow:
	loginname:encryptedpassword:lastchange:.......

一次性口令:
1)挑战/回答方式
通过询问/回答的每一次改变，可以预防重放攻击。
2)时间戳方式
服务器端生成随机数，在规定的时间内要求客户端输入正确的随机数。

采用加密技术的认证:
1）利用共享密钥的认证

--------                    | R-b |                        ---------
|      | <------------------------------------------------ |       |
|      |                 | R-a | *R-b |                    |       |
| User | ------------------------------------------------> | User  |
|      |                    | *R-a |                       |       |
|  A   | <------------------------------------------------ |   B   |
|      |                                                   |       |
--------                                                   ---------

这种认证方式，是挑战回答方式的一种，它利用了挑战的随机数。作为对挑战的
回答，使用双方,利用共享的密钥加密随机数，来认证能够正确解密的对方。

首先B发起认证，发送明文随机数R-b，用户A用共享密钥进行加密，得到*R-b，
同时生成随机数R-a，一并发给B，B收到后，利用共享密钥对*R-b进行解密，将
解密后的明文与R-b比较，若相同，则B可以获知，A确实可以正确地加密，B认证
A的工作结束，但是A还要认证B，所以B继续用共享密钥加密R-a，得到*R-a，发
给A，A收到后，用共享密钥解密，与R-a比较，若相同，则A可以获知，B确实可
以对*R-b进行正确的解密，并能对R-a进行正确的加密，A认证B的工作也结束。
双方认证完成。

2）利用公开密钥的认证 

-----------------            | R-b |                ------------------
|               | <-------------------------------- |                |
|               |   | R-a | *R-b | Public-key-A |   |                |
|    User A     | --------------------------------> |    User B      |
|               |      | *R-a | Public-key-B |      |                |
| Private-key-A | <-------------------------------- | Private-key-B  |
|               |                                   |                |
|               |                                   |                |

-----------------                                   ------------------

这种方式，也是挑战回答方式之一，它也利用了挑战的随机数。回答是利用发送
端的私有密钥加密的随机数，而将利用发送端的公开密钥进行正确解密的一方确
认为用户本人。

首先B发送明文随机数R-b给A，A收到后，用A的私钥对R-b进行加密，连同生成的
随机数以及A的公钥发给B，B收到后，用A的公钥对*R-b进行解密，将解密后的明
文与R-b比较，若相同，B可以获知，自己确实可以正确地解密A发送的数据，然
后B用自己的私钥对R-a加密，发送给A，A用B的公钥进行解密，并与R-a比较，若
相同，表示A自己确实可以正确地解密B发送的数据。

如果不存在第三者干扰的话，那么这里的公开密钥认证过程，B可以确认A就是A
本人，A也可以确认B就是B本人。
但是问题在哪呢？问题是B先发起向A的认证请求，这个请求有可能被第三方截获，
也就是说与B通信的对方可能并不是A。例如用户C截获了B发给A的R-b，兵通过C
自己的私钥进行加密发给B，B就无法知道C其实并非目的接收方A。
如果解决这个问题呢？公开密钥证书。通过一个认证机构来证明该公开密钥确实
是为某个人所有。比如可以通过公开密钥证书获知，C的公钥是属于C的而不是属
于A，那么B就会知道自己发送给A的数据被第三方截获了。

CA: Certificate Authority
in cryptography, a certificate authority or certification authority (CA),
is an entity that issues digital certificates.The digital certificate 
certifies the ownership of a public key by the named subject of the 
certificate. This allows others (relying parties) to rely upon signatures
or assertions made by the private key that corresponds to the public key 
that is certified. In this model of trust relationships, a CA is a trusted
third party that is trusted by both the subject (owner) of the certificate
and the party relying upon the certificate. CAs are characteristic of many
public key infrastructure schemes.

commercial CAs charge to issue certificates that will automatically be 
trusted by most web browsers (Mozilla maintains a list of at least 57 
trusted root CAs, though multiple commercial CAs or their resellers may
share the same trusted root). The number of web browsers and other devices
and applications that trust a particular certificate authority is referred
to as ubiquity.

aside from commercial CAs, some providers issue digital certificates to 
the public at no cost. Large institutions or government entities may have
their own CAs.

授权
对文件的读写执行权限的授权，可执行位setuid，setgid，以及粘贴位。

数字签名技术

2.3 计算机反应机关
最长听到的就是CERT了。

######################################################################

# 3 非法访问技术

## 3.1 扫描与搜索

网络扫描，扫描网络中那些主机处于启动状态，比如使用ping命令，ping某台主
机，如果收到了响应，则表示该主机处于运行状态。

端口扫描，对某台运行中的主机扫描其打开的端口，通过编制程序对某台主机上
从MinPortNum到MaxPortNum范围内的端口进行连接，例如connect函数，并通过
getservbyport（）函数获取指定端口号处运行的服务名称，因为某些周知端口
运行什么服务都是已经规定了的。这样就可以获知目的主机上开启了哪些服务，
然后针对这些特定的服务的漏洞展开攻击。

ping
getservbyport
telnet (Attack)

## 3.2 窃听WireTapping

窃听，数据包嗅探，通过对截获的数据包的分析获取某些敏感的信息。
可以使用Wireshark或者tcpdump来进行抓包.

tcpdump: dump packets on interface

-i :interface
-X :it's very handy
-A :display data in ascii

-w :store captured packets into file
-r :read packets data from file

tcpdump filter options:
dst host
src host
host
port
tcp
udp
...

how to extract the username and password or other something ?
when we submit something, for example, a username, the server side will
respond to the client side with status code.
around the status code, there may be something which you will be intersted 
in.

convert from ascii to hex:

	hexdump -x
	od -x

convert from hex to ascii:

	echo -e "\xHH\xHH\xHH\xHH"

convert hex to decimal:
	
	echo $((0xaa))

## 3.3 数据篡改

A checksum or hash sum is a small-size datum computed from an arbitrary
block of digital data for the purpose of detecting errors that may have
been introduced during its transmission or storage.
The actual procedure that yields the checksum, given a data input, is 
called a checksum function or checksum algorithm.

checksum can be used to check the data's integrity, but it can't be used
to check data's authentication.
we should use hash function to check whether data has been changed.

if data is changed, maybe the checksum stays the same, but the hash 
value is largely sure to change.

利用检验和，检测数据错误
如果检验和出错，数据一定是错的；
如果检验和正确，数据有可能是正确的，但是也有可能是错的，因为数据可以被
人为的修改，并且保证检验和不变，要想检测数据是否经过篡改，需要散列函数。
checksum tools:
	cksum

利用散列函数，检测数据篡改
hash tools:
	'md5sum'
	is equivalent to
	'openssl dgst -md5'

## 3.4 伪装Masquerade

密码跟踪

伪装IP地址，通过强加路由或者源路由
on samsung pc:
add route info:
	ifconfig eth0 up
	ifconfig eth0 10.0.0.1/24
	route add -net 192.168.1.0/24 gw 10.0.0.1 metric 1 dev eth0

on thinkpad x61:
	ifconfig eth0 up
	ifconfig eth0 192.168.1.1/24
	route add -net 10.0.0.1/24 gw 192.168.1.1 metric 1 dev eth0

Then, from either pc, you can ping the other one  and get the response.

Arp, itself, works within the same subnet boundary. but it still works
out of the same subnet with the help of route table. 
How does it works?
For example, ping from samsung to thinkpad. Within the network layer,
when routing, it finds a route table item:
192.168.1.0 255.255.255.0 gw 10.0.0.1 metric 1 eth0
it knows the packet should be sent out through the device 'eth0'. But
before sending, the target MAC must be available, so it sends out ARP
request through device 'eth0', then the target responds with the ARP
request.


linux下设置录由的方法:
route -n
route add -net/netmask | -host(default) .../.. | .. gw ... metric .. device
route del -net/netmask | -host(default) .../.. | ..

非法路由控制

IP源路由
源路由的实现:
在IP Header中通过设置源路由选项9,可以在数据字段中存储要经过的指定的路
由器IP,同时会在头部字段中设置一个指针字段pointer,单位字节,用来指示当前
使用的转发代理(Forward Agent,FA,即当前源路由节点向下一个源路由节点转发
数据时,下一个源路由节点的地址)的IP数据在数据字段中的偏移量,如果当前字
段pointer字段没有超出数据字段的最大长度,则pointer=pointer+4,表示当下一
个源路由节点收到该报文时,可以根据pointer的值确定应该使用的FA.
注意松散源路由的时候,除了源路由节点之外,还有其他的路由节点,而且,源路由
节点之间也可能有其他路由节点.IP Header中pointer字段的值,只有事先指定的
源路由节点才可以对其进行修改.

当pointer的值大于等于数据的最大长度时,

	Host-A ------------>-------------- Host-B
				|						|
				\/						/\	
				|						|
				|--- Host-C ------------


	Host-A: 192.168.1.1/24
	Host-B: 10.0.0.1/24
	Host-C: 192.168.1.2/24

Target:
	To ping from Host-A to Host-B,
	and specify Host-C as the next hop of loosen source route.

Configure:
in Host-A:
	sudo route add -net 10.0.0.0/24 gw 192.168.1.1 metric 1 dev wlan0
in Host-B:
	sudo route add -net 192.168.1.0/24 gw 10.0.0.1 metric 1 dev wlan0
in Host-C:
	sudo route add -net 10.0.0.0/24 gw 192.168.1.2 metric 1 dev wlan0

in Host-C:
	enable IP source route function
	
	check the following configruation files:
	
	/proc/sys/net/ipv4/conf/wlan0/accept_source_route		default 1
	/proc/sys/net/ipv4/conf/wlan0/forwarding				default 0
	/proc/sys/net/ipv4/conf/all/accept_source_route			default 0
	/proc/sys/net/ipv4/conf/all/forwarding					default 0
	
	set all of them to 1 temporarily.

Test:
windows:
	ping [-j loosenSourceRouter-list] [-k strictSourceRoute-list] Addr
	ping -j 192.168.1.2 10.0.0.1

windows下,ping -j, Loose Source Route; ping -k, Strict Source Route.
linux下,ping好像不可以实现源路由.
linux下:
ping : send ICMP echo_request to network hosts and wait for the echo_reply.
-c :count
-f :flood ping
-i :interval
-D :time
-s :packet size
	why 8 bytes added to the specified size ?
	because size of ICMP header data is 8 bytes.
-b :allows ping a broadcast address

	ICMP header format ???
-t :time to live,>=1

关于ping的时候,ping -T tsonly IP.
ping -T tsonly localhost时,是有响应的,但是将IP换成是远程IP地址时,就没
有响应了,针对这个问题,展开了一些思考.
我好像找到原因了，http://www.rikfarrow.com/Network/net0700.html，这里
的ping部分，说了，ping是发送icmp echo request包，然后目的主机或路由器
给予响应。除了echo请求响应，icmp还有子类型，称为code，比如提过的
timestamp。当我们ping的时候，发送echo请求的同时，可以设置对应的选项，
就是code，比如-T tsonly。目的主机或路由器端可以配置是否响应这种请求，
http://www.rapid7.com/db/vulnerabilities/generic-icmp-timestamp。

## 3.5 非授权使用

缓存溢出
关于这一点，请参看QQ空间中关于C Function Stack的说明，以及C Modify 
Return Address的说明，对缓存溢出的理解会更深入.
缓存溢出,不仅可能导致程序崩溃,精心策划的缓存溢出,例如将恶意代码的二进
制数据覆盖源程序的输入缓存,如一个数组,假定这段数据足够长,以致于把远程
序的代码也覆盖了,而且该数据的最后还有精心设计好的一个地址,用这个地址覆
盖原函数的返回地址,这样一来,就可以使函数返回时,跳转到恶意代码开始处执
行.

64-bit computing
In computer architecture, 64-bit computing is the use of processors that
have datapath widths, integer size, and memory addresss widths of 64 bits. 
Also, 64-bit CPU and ALU architetures are those that based on registers,
address buses, or data buses of that size. 
From the software perspective, 64-bit computing means the use of code 
with 64-bit virtual memory address.

computer artechture    : function
computer composition   : logical implementation
computer implementation: physical implementation

uname -m: machine hardware name 
uname -p: processor type
uname -i: hardware platform ( supported hardware platform by current 
		  operating system, implicitly indicating the current operating
		  system type )

Machine hardware name (family) means the cpu family, 'cat /proc/cpuinfo',
if the 'cpu family' is 6, it is i686, similar for 3, 4, 5.
Processor type means the same as the machine hardware name.

######################################################################

# 4 远程终端访问所面临的危险以及防范对策  

危险的发现与对策的方案:
危险的发现与对策的立案,是指在明确需要保护的信息资产的同时,发现可能发生
的危险,并且在此基础上,研讨针对各种危险所要采取的对策.
安全对策方针的制定:
针对各种危险,需要采取具体的对策.对于具体对策的制定,可以从以下四点进行
研讨,即:用于阻止非法行为以及危险发生的"抑制",用于保护防范威信的"预防",
用来检查伴随危险所发生的问题及影响的"发现",以及伴随危险所发生的相应问
题及影响的"恢复".

对策:数据机密通信技术
SSL: Secure Socket Layer
SSH: Secure Shell
IPSec: 对原始IP Header以及数据进行加密处理,只有目的接收方才可以进行解
密.通过对比telnet,ssh远程登陆的实验可以验证,ssh是对数据进行加密处理的.

ssh端口转发:
利用ssh加密通信的功能,可以将不采用加密通信的程序通过ssh的端口转发功能
来进行更安全的通信,如telnet本身没有对数据进行加密的功能,通过端口的转发
功能,可以通过ssh的端口转发功能,可以对telnet通信进行加密,从而进行更安全
的通信.

1) local port redirect, aims to access remote host through local port

ssh -L localPort:remoteHost:remoteHostPort remoteHost
telnet localhost localPort

note:
ssh -p: port that will be used by the ssh server on remote host.
ssh -D: port that will be used by the ssh client on local host.

Providing ssh server on remote host uses PORT-R, ssh client on local 
host uses PORT-L, then ssh local port redirect works as following:
-- ssh creates a connection between PORT-L and PORT-R to communicate 
with ssh protocol.
- ssh on the local host redirects input from 'localPort' to 'PORT-L',
and encrypted the message, then send it to PORT-R on the remote host.
- ssh on the remote host receives message from PORT-R, unencrypted it,
then redirects it to remoteHostPort.

2) remote port redirect, aims to access local host through remote host

ssh -R remoteHostPort:localhost:localPort remoteHost
on remote host:
telnet localhost remoteHostPort

######################################################################

# 5 电子邮件所面临的威胁及其安全对策 

1 电子邮件的概要

电子邮件地址格式:  username@domain

电子邮件系统的消息是以接力的方式发送的:
从发送端user@hitachi.co.jp发送往user@ohmasha.co.jp的电子邮件,它首先从
客户端被发送到邮件服务器X,然后从邮件服务器X到服务器Y,最后邮件被转发到
服务器Z上.
此时,邮件服务器Z成为拥有邮件地址user@ohmasha.co.jp的用户的邮件服务器,
当阅读邮件时,该邮件酒会 从邮件服务器Z上下载到用户的接收设备上.
在电子邮件的传送过程中,电子邮件是从邮件服务器X到Y,再到Z上,但是各个邮件
服务器是一边查询电子邮件的传送路径信息,一边接力传送邮件的.

1) telnet, send emails

telnet smtp.163.com 25
helo hhhh
auth login
base64-username
base64-passwd
mail from:<username1@163.com>	: can't masquerade
rcpt to:<username2@domain>		: one recipient, one 'rcpt to:<...>'
data
from:							: masquerade from, to and subject for 
								  inexperienced computer users
to:
subject:
hhhhhhhhhhhhhhhhhhh
.								: end input
quit

note:
	1)for experienced computer users, they may check the source content, 
	where they can check the 'Sender' to identify whom this mail comes 
	from on earth.

	2)echo -n username | base64, add option -n to delete the trailing 
	newline character.

2) telnet, receive emails

telnet pop3.163.com 110
user username
pass password
stat								: check mail status
list								: list emails
top emailNum lines					: display email's header
retr emailNum						: display email's content
dele emailNum						: delete email
quit

电子邮件所面临的威胁:
对服务器的威胁:
	恶意利用sendmail、popd等程序漏洞进行攻击，夺取服务器控制权限，从而
	进行入侵；或者，通过向服务器发送大量超过其处理能力的电子邮件或大量
	的电子邮件，以影响服务器正常运行或导致其瘫痪。
通信过程中所面临的威胁:
	主要是在连接邮件服务器的pop3时，对所传输的用户名以及密码等用户认证
	信息的窃听。
客户端所面临的威胁:
	利用得到的帐号及密码，伪装用户进行非法活动，此外，还包括合法用户可
	能辉收到从未谋面的第三者发送的大量的广告邮件、垃圾邮件甚至附带病毒
	的邮件等。
用户所面临的危险:
	用户所面临的危险，指的是，利用人的心理以诱使其进行某种有目的的活动，
	这称为社交工程攻击。

数字签名技术
适用于电子邮件的签名技术有PGP和S/MIME。

######################################################################

# 6 Web所面临的威胁机器对策

CGI程序，我认为指的就是一些可以处理HTTP请求的一些脚本，比如JSP、PHP等。

Web所面临的威胁有:
对服务器的威胁:
	恶意利用httpd、CGI等程序的弱点，进行夺取服务器控制权限的非法侵入；
	通过对服务器进行超过服务器处理能力的、大量的访问，使服务器的正常运
	行收到干扰甚至瘫痪。
通信信道中的威胁:
	当访问Web服务器提供的、有一定限制的网页时，使用的帐号名、密码等用户
	认证信息以及网上购物所涉及的信用卡号等，都存在被窃听的危险。
客户端所面临的威胁:
	如果在Web服务器提供的信息中混入了病毒等非法程序，那么通过这些信息就
	可能使客户端蒙受灾难。
用户所面临的威胁:
	用户可能会收到伪装的Web服务器的诱骗，或者被花言巧语所蒙骗，将密码、
	信用卡等信息送至服务器，而使自己遭受损失。

对策:防火墙
在因特网与组织内部网络的节点上，防火墙在事先所确定的基准下，通过对“允
许某些数据通信，拒绝某些数据通信”的访问控制，可以控制数据的流入流出路
径。这样就可以组织外部的非法入侵，预防内部机密信息的无意流出，进行流入
流出信息的管理，限制风险发生的范围，同时有重点地实施安全对策（监察、认
证、监控等）。

防火墙分类
1）根据保护对象进行分类
网络型和主机型。网络型防火墙设置在内部网络与外部网络之间，主机型防火墙
是安装在主机上。
2）根据采用的方式进行分类
包过滤:
	包过滤是在网络层进行控制的方法，它利用路由器等具有路径控制功能的装
	置，在传送到路由器的数据包中，让满足条件的数据包通过，而丢弃不满足
	条件的数据包。IP数据包中的源IP地址、目的IP地址、源端口号、目的端口
	号、标志常作为包过滤的访问控制条件。
传输网关:
	传输网关是在OSI模型中的传输层进行访问控制的方式，也称为电路网关。
	源IP地址或源主机名、目的IP地址或目的主机名、目的端口号常作为访问控
	制的条件。
应用网关:
	应用网关是在OSI模型中应用层进行访问控制的方式，应用网关需要准备可
	以解析所使用的协议的中继程序。应用网关必须对每一个应用准备中继程
	序，而且会有损网络的透明性。
	在应用网关的访问控制中，可以对每个应用协议设定条件。除了源端及目的
	端的IP地址、源端及目的端的主机名以及目的端口号以外，应用网关的访问
	控制可以了解具体的应用协议，可以实施用户认证、选择可用的命令以及应
	用所具有的访问控制。因此，能够获得非常细致的访问控制以及利用状况等
	的记录。

---

先总结道这里……