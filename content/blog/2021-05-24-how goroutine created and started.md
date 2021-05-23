---
layout: post  
title: how goroutine created and started
date: 2021-05-24 00:14:01 +0800
tags: ["go","goroutine","runtime"]
---

goroutine创建：runtime.newproc(siz int32, fn *funcval)
- go fn()，传递给fn的参数实际上是紧跟着存在fn压栈后的地址后面，在newproc1的栈帧里面，但是不出现在签名参数列表中，因为这些参数类型、数量不一样，也无法出现在签名参数列表中；
- newproc1创建g；
- getg().m.p.ptr()拿到当前p；
- runqput将当前g放入p的local queue中，如果满则放到global queue中；
- g等待被调度器调度执行；

大致创建执行goroutine的逻辑是这样的，下面的逻辑都是切到系统栈上去执行的。

1 newproc1逻辑

查看源码发现，goroutine初始创建时对函数参数大小是有限制的，如果参数占内存空间很大，比如超过初始栈帧大小2KB，那么goroutine创建会失败："fatal error: newproc: function arguments too large for new goroutine"，比如，`go func(a [1024]int) {}([1024]int{})`。

每个p内部都有一个空闲goroutine队列gFree，这个就是用来执行fn的goroutine，是可以复用的，不用的时候可以丢给调度器schedt.gFree供其他p复用。这里空闲的goroutines，一部分存在于p.gFree，如果gfput(p, gp)时发现p.gFree队列太长说明过剩了，就转移一部分到调度器schedt.gFree中供其他p复用。

goroutine执行完毕后运行时并不急于将其销毁，而是会考虑goroutine的复用，gfput，前面提过了。希望go func()通过协程执行时，也不必每次创建新的goroutine，gfget，可以复用p.gFree中的goroutine，如果p.gFree空或者过少（32）且调度器schedt.gFree中有空闲，则转移一部分过来给p复用。但是goroutine的栈有可能会被销毁，如果复用到栈被销毁的goroutine就需要stackalloc重新为其分配新栈帧。

如果没有空闲的g可供复用，那就只能malg从头新建一个goroutine了。

goroutine创建成功、栈空间也ok了之后，就要把goroutine要执行的函数对应的函数参数给拷贝到这个栈空间里面来，通过memmove(spArg, argp, uintptr(narg))来完成。完成后调整newg的调度上下文相关的寄存器值，等调度器调度它时，还原其中的上下文信息，pc就指向其对应的函数地址了，对应的数据也会指向其对应的栈空间。

然后，通过gostartcallfn→gostartcall(buf, fn, ctxt)，之前已经拷贝了函数fn的参数到goroutine栈空间了，这里面再继续在栈内设置fn返回地址、gobuf.sp+gobuf.pc信息。

上述调整完成之后，将goroutine的状态从_Gdead调整为_Grunnable，等待调度器调度。新创建的时候其状态是_Gidle，一定会将其调整为_Gdead然后再进行上述准备工作，一切就绪后才调整为_Grunnable让其参与调度。

2 runqput(p, gp, next)
这里的逻辑是，希望将gp放到p的local queue中，但是也有头插、尾插两种方式。
- 如果next为true，可以认为是头插，其实是放到p.runnext中，比p.queue中的得到优先调度。如果之前p.runnext有值，还要该值对应的g放入p.queue中；
- 如果next为false，则尝试将其放置到p.queue中，这里也有快慢两种情况，快的情况就是，因为p.queue这个本地队列长度最大为256，如果有空余位置放入就返回，这是快的情况。慢的情况就是如果p.queue满了就要先转移1/2到调度器全局队列schedt.queue中，然后再放入，这个过程就慢一些。

放置过程中，如果p.runqueue满了怎么办，将其放置到调度器schedt.queue这个全局队列中。

3 wakeup()逻辑

这个函数内部执行startm(p, spinning)，来找一个m来执行goroutine，具体是怎么做的呢？

- 如果没有指定p，比如新建goroutine时，此时会尝试检查有没有空闲的p，没有的话就直接返回了，相当于当前一次没有执行成功，那么只能下次调度的时候再执行这个新建的goroutine了；

- 现在有空闲的p，我们还缺什么，m！然后mget找一个空闲的m，如果没有空闲的，就newm创建一个新的，本质上是通过clone系统调用创建的新的线程。然后将这个m和这个p关联起来，m.nextp = p。值得一提的是clone出来的线程对应的线程处理函数是mstart，mstart使用汇编写的，内部实际调用的是mstart0，它内部又请求mstart1，获取当前g：
- 如果g.m==&m0，则执行mstartm0完成信号处理注册，继续执行其他；
- 获取当前m.mstartfn，即线程处理函数，执行该函数，如果该函数会执行结束那还要继续执行；
- 如果当前g.m不是m0，那么要将g.m.nextp与当前m关联起来，为什么呢？m执行调度时用这个p呗，执行它的queue中的goroutine呗；
- 执行调度schedule()逻辑，这个函数调用一次就是执行一轮调度，逻辑就是寻找一个可运行的goroutine然后执行。这个函数比较有意思了，有些goroutine是通过lockOSThread绑定了执行它的线程的，这样的goroutine只能用那个绑定的m来执行，未绑定的则无此限制。
lockedg：这个schedule函数先获取当前g，如果发现当前g.m.lockedg不为0，表示有一个g通过lockOSThread绑定到了g.m，这个时候先停掉当前m，让其把p交出来，等下次有线程schedule里面调度执行lockedg时再唤醒该m，此时m被parked，p被空出来了。再调用execute(lockedg, inheritTime)，将该lockedg设置为当前g.m.curg，并修改装改为_Grunning，然后下面gogo(&gp.sched)恢复该待执行goroutine的上下文，执行之，execute函数never returns。可以想象下，如果一个m有g locked，那么每次调度都会先优先执行该goroutine？
剩下的逻辑：获取当前g.m.p，.....一堆有的没的逻辑，会通过findRunnable找一个可以运行的g来执行，最后也是调用execute来执行gp。
netpoller：值得一提的是这个函数里面会通过findRunnable来查找一个可执行的g，除了从p.queue、schedt.queue、其他p.queue中找可运行的goroutine外，也包括从netpoller中获取等待网络IO事件就绪的g。

到这里就可以算是结束了，到这里基本就了解了整个goroutine从创建到执行的完整逻辑了。当然这个后面还有点逻辑，目前也没搞懂写来干嘛的，先不管后面这个逻辑吧。

- 然后notewakeup唤醒阻塞在&m.park上的一个proc，这个是做什么呢？意思是说，如果之前m执行（执行某个goroutine的代码）时，因为某个原因阻塞了（这个原因通常用目标对象的事件地址来表示，如&m.park），现在这个条件满足了，现在将其唤醒继续执行。我们不禁想问，这里的&m.park表示的是什么呢？

ps：这里用到了futex来实现轻量级地锁获取+获取失败阻塞、锁释放+唤醒阻塞线程操作，see https://lwn.net/Articles/360699/。





