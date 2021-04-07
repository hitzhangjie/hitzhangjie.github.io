---
layout: post
title:  "golang select-case 实现机制"
color: blue
width:   6
height:  1
date:   2018-05-19 19:21:11 +0800
categories: jekyll update
tags: ["go","chann"]
toc: true
---

# 1 chan操作规则
在介绍select-case实现机制之前，最好先了解下chan操作规则，明白goroutine何时阻塞，又在什么时机被唤醒，这对后续理解select-case实现有帮助。所以接下来先介绍chan操作规则，然后再介绍select-case的实现。

## 1.1 chan操作规则1
当一个goroutine要从一个non-nil & non-closed chan上接收数据时，goroutine首先会去获取chan上的锁，然后执行如下操作直到某个条件被满足：

1）如果chan上的value buffer不空，这也意味着chan上的recv goroutine queue也一定是空的，该接收goroutine将从value buffer中unshift出一个value。这个时候，如果send goroutine队列不空的情况下，因为刚才value buffer中空出了一个位置，有位置可写，所以这个时候会从send goroutine queue中unshift出一个发送goroutine并让其恢复执行，让其执行把数据写入chan的操作，实际上是恢复该发送该goroutine执行，并把该发送goroutine要发送的数据push到value buffer中。然后呢，该接收goroutine也拿到了数据了，就继续执行。这种情景，channel的接收操作称为non-blocking操作。

2）另一种情况，如果value buffer是空的，但是send goroutine queue不空，这种情况下，该chan一定是unbufferred chan，不然value buffer肯定有数据嘛，这个时候接收goroutine将从send goroutine queue中unshift出一个发送goroutine，并将该发送goroutine要发送的数据接收过来（两个goroutine一个有发送数据地址，一个有接收数据地址，拷贝过来就ok），然后这个取出的发送goroutine将恢复执行，这个接收goroutine也可以继续执行。这种情况下，chan接收操作也是non-blocking操作。

3）另一种情况，如果value buffer和send goroutine queue都是空的，没有数据可接收，将把该接收goroutine push到chan的recv goroutine queue，该接收goroutine将转入blocking状态，什么时候恢复期执行呢，要等到有一个goroutine尝试向chan发送数据的时候了。这种场景下，chan接收操作是blocking操作。

## 1.2 chan操作规则2

当一个goroutine常识向一个non-nil & non-closed chan发送数据的时候，该goroutine将先尝试获取chan上的锁，然后执行如下操作直到满足其中一种情况。

1）如果chan的recv goroutine queue不空，这种情况下，value buffer一定是空的。发送goroutine将从recv goroutine queue中unshift出一个recv goroutine，然后直接将自己要发送的数据拷贝到该recv goroutine的接收地址处，然后恢复该recv goroutine的运行，当前发送goroutine也继续执行。这种情况下，chan send操作是non-blocking操作。

2）如果chan的recv goroutine queue是空的，并且value buffer不满，这种情况下，send goroutine queue一定是空的，因为value buffer不满发送goroutine可以发送完成不可能会阻塞。该发送goroutine将要发送的数据push到value buffer中然后继续执行。这种情况下，chan send操作是non-blocking操作。

3）如果chan的recv goroutine queue是空的，并且value buffer是满的，发送goroutine将被push到send goroutine queue中进入阻塞状态。等到有其他goroutine尝试从chan接收数据的时候才能将其唤醒恢复执行。这种情况下，chan send操作是blocking操作。

## 1.3 chan操作规则3

当一个goroutine尝试close一个non-nil & non-closed chan的时候，close操作将依次执行如下操作。

1）如果chan的recv goroutine queue不空，这种情况下value buffer一定是空的，因为如果value buffer如果不空，一定会继续unshift recv goroutine queue中的goroutine接收数据，直到value buffer为空（这里可以看下chan send操作，chan send写入数据之前，一定会从recv goroutine queue中unshift出一个recv goroutine）。recv goroutine queue里面所有的goroutine将一个个unshift出来并返回一个val=0值和sentBeforeClosed=false。

2）如果chan的send goroutine queue不空，所有的goroutine将被依次取出并生成一个panic for closing a close chan。在这close之前发送到chan的数据仍然在chan的value buffer中存着。

## 1.4 chan操作规则4

一旦chan被关闭了，chan recv操作就永远也不会阻塞，chan的value buffer中在close之前写入的数据仍然存在。一旦value buffer中close之前写入的数据都被取出之后，后续的接收操作将会返回val=0和sentBeforeClosed=true。

# 1.5 小结
理解这里的goroutine的blocking、non-blocking操作对于理解针对chan的select-case操作是很有帮助的。下面介绍select-case实现机制。

# 2 select-case实现

# 2.1 select-case原理简述
select-case中假如没有default分支的话，一定要等到某个case分支满足条件然后将对应的goroutine唤醒恢复执行才可以继续执行，否则代码就会阻塞在这里，即将当前goroutine push到各个case分支对应的ch的recv或者send goroutine queue中，对同一个chan也可能将当前goroutine同时push到recv、send goroutine queue这两个队列中。

不管是普通的chan send、recv操作，还是select chan send、recv操作，因为chan操作阻塞的goroutine都是依靠其他goroutine对chan的send、recv操作来唤醒的。前面我们已经讲过了goroutine被唤醒的时机，这里还要再细分一下。

chan的send、recv goroutine queue中存储的其实是一个结构体指针*sudog，成员gp *g指向对应的goroutine，elem unsafe.Pointer指向待读写的变量地址，c *hchan指向goroutine阻塞在哪个chan上，isSelect为true表示select chan send、recv，反之表示chan send、recv。g.selectDone表示select操作是否处理完成，即是否有某个case分支已经成立。

# 2 select-case执行流程

## 2.1 chan操作阻塞的goroutine唤醒时执行逻辑
下面我们先描述下chan上某个goroutine被唤醒时的处理逻辑，假如现在有个goroutine因为select chan 操作阻塞在了ch1、ch2上，那么会创建对应的sudog对象，并将对应的指针*sudog push到各个case分支对应的ch1、ch2上的send、recv goroutine queue中，等待其他协程执行(select) chan send、recv操作时将其唤醒：
1）源码文件**chan.go**，假如现在有另外一个goroutine对ch1进行了操作，然后对ch1的goroutine执行unshift操作取出一个阻塞的goroutine，在unshift时要执行方法 **func (q *waitq) dequeue() *sudog**，这个方法从ch1的等待队列中返回一个阻塞的goroutine。

```golang
func (q *waitq) dequeue() *sudog {
	for {
		sgp := q.first
		if sgp == nil {
			return nil
		}
		y := sgp.next
		if y == nil {
			q.first = nil
			q.last = nil
		} else {
			y.prev = nil
			q.first = y
			sgp.next = nil // mark as removed (see dequeueSudog)
		}

		// if a goroutine was put on this queue because of a
		// select, there is a small window between the goroutine
		// being woken up by a different case and it grabbing the
		// channel locks. Once it has the lock
		// it removes itself from the queue, so we won't see it after that.
		// We use a flag in the G struct to tell us when someone
		// else has won the race to signal this goroutine but the goroutine
		// hasn't removed itself from the queue yet.
		if sgp.isSelect {
			if !atomic.Cas(&sgp.g.selectDone, 0, 1) {
				continue
			}
		}

		return sgp
	}
}
```

假如队首元素就是之前阻塞的goroutine，那么检测到其sgp.isSelect=true，就知道这是一个因为select chan send、recv阻塞的goroutine，然后通过CAS操作将sgp.g.selectDone设为true标识当前goroutine的select操作已经处理完成，之后就可以将该goroutine返回用于从value buffer读或者向value buffer写数据了，或者直接与唤醒它的goroutine交换数据，然后该阻塞的goroutine就可以恢复执行了。

这里将sgp.g.selectDone设为true，相当于传达了该sgp.g已经从刚才阻塞它的select-case块中退出了，对应的select-case块可以作废了。有必要提提一下为什么要把这里的sgp.g.selectDone设为true呢？直接将该goroutine出队不就完了吗？不行！考虑以下对chan的操作dequeue是需要先拿到chan上的lock的，但是在尝试lock chan之前有可能同时有多个case分支对应的chan准备就绪。看个示例代码：

```golang
// g1
go func() {
  ch1 <- 1 }()

// g2
go func() {
  ch2 <- 2
}

select {
  case <- ch1:
    doSomething()
  case <- ch2:
    doSomething()
}
```

协程g1在 chan.chansend方法中执行了一般，准备lock ch1，协程g2也执行了一半，也准备lock ch2;
协程g1成功lock ch1执行dequeue操作，协程g2页成功lock ch2执行deq	ueue操作；
因为同一个select-case块中只能有一个case分支允许激活，所以在协程g里面加了个成员g.selectDone来标识该协程对应的select-case是否已经成功执行结束（一个协程在某个时刻只可能有一个select-case块在处理，要么阻塞没执行完，要么立即执行完），因此dequeue时要通过CAS操作来更新g.selectDone的值，更新成功者完成出队操作激活case分支，CAS失败的则认为该select-case已经有其他分支被激活，当前case分支作废，select-case结束。

这里的CAS操作也就是说的多个分支满足条件时，golang会随机选择一个分支执行的道理。

## 2.2 select-case块golang是如何执行处理的

源文件**select.go**中方法 **selectgo(sel *hselect)** ，实现了对select-case块的处理逻辑，但是由于代码篇幅较长，这里不再复制粘贴代码，感兴趣的可以自己查看，这里只简要描述下其执行流程。

**selectgo逻辑处理简述：**
- 预处理部分
对各个case分支按照ch地址排序，保证后续按序加锁，避免产生死锁问题；
- pass 1
部分处理各个case分支的判断逻辑，依次检查各个case分支是否有立即可满足ch读写操作的。如果当前分支有则立即执行ch读写并回，select处理结束；没有则继续处理下一分支；如果所有分支均不满足继续执行以下流程。
- pass 2
没有一个case分支上chan操作立即可就绪，当前goroutine需要阻塞，遍历所有的case分支，分别构建goroutine对应的sudog并push到case分支对应chan的对应goroutine queue中。然后gopark挂起当前goroutine，等待某个分支上chan操作完成来唤醒当前goroutine。怎么被唤醒呢？前面提到了chan.waitq.dequeue()方法中通过CAS将sudog.g.selectDone设为1之后将该sudog返回并恢复执行，其实也就是借助这个操作来唤醒。
- pass 3
整个select-case块已经结束使命，之前阻塞的goroutine已被唤醒，其他case分支没什么作用了，需要废弃掉，pass 3部分会将该goroutine从之前阻塞它的select-case块中各case分支对应的chan recv、send goroutine queue中移除，通过方法chan.waitq.dequeueSudog(sgp *sudog)来从队列中移除，队列是双向链表，通过sudog.prev和sudog.next删除sudog时间复杂度为O(1)。

# 3 总结

本文简要描述了golang中select-case的实现逻辑，介绍了goroutine与chan操作之间的协作关系。之前ZMQ作者Martin Sustrik仿着golang写过一个面向c的库，libmill，实际实现思路差不多，感兴趣的也可以翻翻看，[libmill源码分析](https://hitzhangjie.github.io/2017/12/03/go%E9%A3%8E%E6%A0%BC%E5%8D%8F%E7%A8%8B%E5%BA%93libmill%E4%B9%8B%E6%BA%90%E7%A0%81%E5%88%86%E6%9E%90.html)。
