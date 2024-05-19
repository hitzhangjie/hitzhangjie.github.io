---
layout: post  
title: Linux内核文档索引
description: ""
date: 2014-10-24 00:10:00 +0800
categories: ["过去的学习笔记"]
tags: ["unix","linux","kernel","documentation"]
toc: true
reward: true
draft: false
---

迁移自 hitzhangjie/Study 项目下的内容，本文是看内核源码时对文档的一个阅读、内容总结。

=============================================================================
Fri Sep 18 12:23:06 CST 2014
=============================================================================
Documentation/

[1] zorro.txt
zorro bus ii\iiioZorro II is the name of the general purpose expansion bus
used by the Amiga 2000 computer. The bus is mainly a buffered extension of the
Motorola 68000 bus, with support for bus mastering DMA. The expansion slots
use a 100-pin connector and the card form factor is the same as the IBM PC.
Zorro II cards implement the Autoconfig protocol for automatic address space
assignment (designed before, yet similar to, Plug and Play on the PC).  Zorro
II was succeeded by Zorro III.

[2] xz.txt
XZ is a general purpose data compression format with high compression ratio
and relatively fast decompression. The primary compression algorithm (filter)
is LZMA2. Additional filters can be used to improve 0010     compression
ratio even further. E.g. Branch/Call/Jump (BCJ) filters 0011     improve
compression ratio of executable data.

[3] workqueue.txt
There are many cases where an asynchronous process execution context is needed
and the workqueue (wq) API is the most commonly used mechanism for such cases.
When such an asynchronous execution context is needed, a work item describing
which function to execute is put on a queue.  An independent thread serves as
the asynchronous execution context.  The queue is called workqueue and the
thread is called worker.

**[4] volatile-considered-harmful.txt**
**C programmers have often taken volatile to mean that the variable could be**
**changed outside of the current thread of execution; as a result, they are**
**sometimes tempted to use it in kernel code when shared data structures are**
**being used.  In other words, they have been known to treat volatile types**
**kernel code is almost never correct; this document describes why.**

[5] video-output.txt
The output sysfs class driver provides an abstract video output layer that can
be used to hook platform specific methods to enable/disable video output
device through common sysfs interface. 

[6] vgaarbiter.txt
Graphic devices are accessed through ranges in I/O or memory space. While most
modern devices allow relocation of such ranges, some "Legacy" VGA devices
implemented on PCI will typically have the same "hard-decoded" addresses as
they did on ISA. For more details see "PCI Bus Binding to IEEE Std 1275-1994
Standard for Boot (Initialization Configuration) Firmware Revision 2.1"
Section 7, Legacy Devices.

[7] unshare.txt
This document describes the new system call, unshare. The document provides an
overview of the feature, why it is needed, how it can be used, its interface
specification, design, implementation and how it can be tested.

[8] unicode.txt
kernel code has been rewritten to use Unicode to map characters to fonts.  By
downloading a single Unicode-to-font table, both the eight-bit character sets
and UTF-8 mode are changed to use the font as indicated.

**[9] unaligned memory access**
**Linux runs on a wide variety of architectures which have varying behaviour**
**when it comes to memory access. This document presents some details about**
**unaligned accesses, why you need to write code that doesn't cause them, and**
**how to write such code!**

=============================================================================

Fri Sep 19 10:59:56 CST 2014
=============================================================================

[10] sysrq.txt
It is a 'magical' key combo you can hit which the kernel will respond to
regardless of whatever else it is doing, unless it is completely locked up.
Here is the list of possible values
in /proc/sys/kernel/sysrq:
0 - disable sysrq completely
1 - enable all functions of sysrq
    >1 - bitmask of allowed sysrq functions (see below for detailed function
        description):
    2 - enable control of console logging level
    4 - enable control of keyboard (SAK, unraw)
    8 - enable debugging dumps of processes etc.
    16 - enable sync command
    32 - enable remount read-only
    64 - enable signalling of processes (term, kill, oom-kill)
    128 - allow reboot/poweroff
    256 - allow nicing of all RT tasks
    
You can set the value in the file by the following command:
    echo "number" >/proc/sys/kernel/sysrq

Note that the value of /proc/sys/kernel/sysrq influences only the invocation
via a keyboard. Invocation of any operation via /proc/sysrq-trigger is always
allowed (by a user with admin privileges).

Regarding to how to make invoke the sysrq commands, please refer to the kernel
documentation, there's some differences between different architectures
including x86, spark and others. some keyboards may generate different keycode
sequences, remapping may be required, too.

[11] sysfs-rules.txt
kernel-exported sysfs exports internal kernel implementation details and
depends on internal kernel structures and layout. It is agreed upon by the
kernel developers that the Linux kernel does not provide a stable internal
API. Therefore, there are aspects of the sysfs interface that may not be
stable across kernel releases.

To minimize the risk of breaking users of sysfs, which are in most cases
low-level userspace applications, with a new kernel release, the users of
sysfs must follow some rules to use an as-abstract-as-possible way to access
this filesystem. The current udev and HAL programs already implement this and
users are encouraged to plug, if possible, into the abstractions these
programs provide instead of accessing sysfs directly.

But if you really do want or need to access sysfs directly, please follow the
following rules and then your programs should work with future versions of the
sysfs interface.

[12] svga.txt
This small document describes the "Video Mode Selection" feature which allows
the use of various special video modes supported by the video BIOS. Due to
usage of the BIOS, the selection is limited to boot time (before the kernel
decompression starts) and works only on 80X86 machines.

[13] stable_kernel_rules.txt 
Everything you ever wanted to know about Linux -stable releases.

Rules on what kind of patches are accepted, and which ones are not, into the
"-stable" tree:
  - It must be obviously correct and tested.
  - It cannot be bigger than 100 lines, with context.
  - It must fix only one thing.
  - It must fix a real bug that bothers people (not a, "This could be a
            problem..." type thing).
  - It must fix a problem that causes a build error (but not for things
            marked CONFIG_BROKEN), an oops, a hang, data corruption, a real
    security issue, or some "oh, that's not good" issue.  In short, something
    critical.
  - Serious issues as reported by a user of a distribution kernel may also
    be considered if they fix a notable performance or interactivity issue.
    As these fixes are not as obvious and have a higher risk of a subtle
    regression they should only be submitted by a distribution kernel
    maintainer and include an addendum linking to a bugzilla entry if it
    exists and additional information on the user-visible impact.
  - New device IDs and quirks are also accepted.
  - No "theoretical race condition" issues, unless an explanation of how the
    race can be exploited is also provided.
  - It cannot contain any "trivial" fixes in it (spelling changes,
            whitespace cleanups, etc).
  - It must follow the Documentation/SubmittingPatches rules.
  - It or an equivalent fix must already exist in Linus' tree (upstream).

Procedure for submitting patches to the -stable tree:
  - Send the patch, after verifying that it follows the above rules, to
    stable@vger.kernel.org.  You must note the upstream commit ID in the
    changelog of your submission.
  - To have the patch automatically included in the stable tree, add the tag
      Cc: stable@vger.kernel.org
    in the sign-off area. Once the patch is merged it will be applied to
    the stable tree without anything else needing to be done by the author
    or subsystem maintainer.
  - If the patch requires other patches as prerequisites which can be
    cherry-picked than this can be specified in the following format in
    the sign-off area:

      Cc: <stable@vger.kernel.org> # 3.3.x: a1f84a3: sched: Check for idle
      Cc: <stable@vger.kernel.org> # 3.3.x: 1b9508f: sched: Rate-limit newidle
      Cc: <stable@vger.kernel.org> # 3.3.x: fd21073: sched: Fix affinity logic
      Cc: <stable@vger.kernel.org> # 3.3.x
     Signed-off-by: Ingo Molnar <mingo@elte.hu>

    The tag sequence has the meaning of:
      git cherry-pick a1f84a3
      git cherry-pick 1b9508f
      git cherry-pick fd21073
      git cherry-pick <this commit>

  - The sender will receive an ACK when the patch has been accepted into the
    queue, or a NAK if the patch is rejected.  This response might take a few
    days, according to the developer's schedules.
  - If accepted, the patch will be added to the -stable queue, for review by
    other developers and by the relevant subsystem maintainer.
  - Security patches should not be sent to this alias, but instead to the
    documented security@kernel.org address.

Review cycle:
  - When the -stable maintainers decide for a review cycle, the patches will be
    sent to the review committee, and the maintainer of the affected area of
    the patch (unless the submitter is the maintainer of the area) and CC: to
    the linux-kernel mailing list.
  - The review committee has 48 hours in which to ACK or NAK the patch.
  - If the patch is rejected by a member of the committee, or linux-kernel
    members object to the patch, bringing up issues that the maintainers and
    members did not realize, the patch will be dropped from the queue.
  - At the end of the review cycle, the ACKed patches will be added to the
    latest -stable release, and a new -stable release will happen.
  - Security patches will be accepted into the -stable tree directly from the
    security kernel team, and not go through the normal review cycle.
    Contact the kernel security team for more details on this procedure.

[14] stable_api_nonsense.txt
This is being written to try to explain why Linux does not have a binary
kernel interface, nor does it have a stable kernel interface.  Please realize
that this article describes the _in kernel_ interfaces, not the kernel to
userspace interfaces.  The kernel to userspace interface is the one that
application programs use, the syscall interface.  That interface is _very_
stable over time, and will not break.  I have old programs that were built on
a pre 0.9something kernel that still work just fine on the latest 2.6 kernel
release.  That interface is the one that users and application programmers can
count on being stable.

there are two main topics here, binary kernel interfaces and stable kernel
source interfaces.  They both depend on each other, but we will discuss the
binary stuff first to get it out of the way.


Binary Kernel Interface
-----------------------
Assuming that we had a stable kernel source interface for the kernel, a binary
interface would naturally happen too, right?  Wrong.  Please consider the
following facts about the Linux kernel:

  - Depending on the version of the C compiler you use, different kernel
    data structures will contain different alignment of structures, and
    possibly include different functions in different ways (putting
             functions inline or not.)  The individual function organization
    isn't that important, but the different data structure padding is
    very important.
  - Depending on what kernel build options you select, a wide range of
    different things can be assumed by the kernel:
      - different structures can contain different fields
      - Some functions may not be implemented at all, (i.e. some locks
                 compile away to nothing for non-SMP builds.)
      - Memory within the kernel can be aligned in different ways,
                    depending on the build options.
      - Linux runs on a wide range of different processor architectures.
        There is no way that binary drivers from one architecture will run
        on another architecture properly.
            

Now a number of these issues can be addressed by simply compiling your module
for the exact specific kernel configuration, using the same exact C compiler
that the kernel was built with.  This is sufficient if you want to provide a
module for a specific release version of a specific Linux distribution.  But
multiply that single build by the number of different Linux distributions and
the number of different supported releases of the Linux distribution and you
quickly have a nightmare of different build options on different releases.
Also realize that each Linux distribution release contains a number of
different kernels, all tuned to different hardware types (different processor
types and different options), so for even a single release you will
need to create multiple versions of your module.
            
Trust me, you will go insane over time if you try to support this kind of
release, I learned this the hard way a long time ago...
            
            
Stable Kernel Source Interfaces
-------------------------------

This is a much more "volatile" topic if you talk to people who try to keep a
Linux kernel driver that is not in the main kernel tree up to date over time.
            
Linux kernel development is continuous and at a rapid pace, never stopping to
slow down.  As such, the kernel developers find bugs in current interfaces, or
figure out a better way to do things.  If they do that, they then fix the
current interfaces to work better.  When they do so, function names may
change, structures may grow or shrink, and function parameters may be
reworked.  If this happens, all of the instances of where this interface is
used within the kernel are fixed up at the same time, ensuring that everything
continues to work properly.

As a specific examples of this, the in-kernel USB interfaces have undergone at
least three different reworks over the lifetime of this subsystem.  These
reworks were done to address a number of different issues:
  - A change from a synchronous model of data streams to an asynchronous
    one.  This reduced the complexity of a number of drivers and
    increased the throughput of all USB drivers such that we are now
    running almost all USB devices at their maximum speed possible.

  - A change was made in the way data packets were allocated from the
    USB core by USB drivers so that all drivers now needed to provide
    more information to the USB core to fix a number of documented
    deadlocks.

This is in stark contrast to a number of closed source operating systems which
have had to maintain their older USB interfaces over time.  This provides the
ability for new developers to accidentally use the old interfaces and do
things in improper ways, causing the stability of the operating system to
suffer.

In both of these instances, all developers agreed that these were important
changes that needed to be made, and they were made, with relatively little
pain.  If Linux had to ensure that it will preserve a stable source interface,
a new interface would have been created, and the older, broken one would
have had to be maintained over time, leading to extra work for the USB
developers.  Since all Linux USB developers do their work on their own time,
asking programmers to do extra work for no gain, for free, is not a
possibility.  

Security issues are also very important for Linux.  When a security issue is
found, it is fixed in a very short amount of time.  A number of times this has
caused internal kernel interfaces to be reworked to prevent the security
problem from occurring.  When this happens, all drivers that use the
interfaces were also fixed at the same time, ensuring that the security
problem was fixed and could not come back at some future time accidentally.
If the internal interfaces were not allowed to change, fixing this kind of
security problem and insuring that it could not happen again would not be
possible.

Kernel interfaces are cleaned up over time.  If there is no one using a
current interface, it is deleted.  This ensures that the kernel remains as
small as possible, and that all potential interfaces are tested as well as
they can be (unused interfaces are pretty much impossible to test for
validity.)

**[15] spinlocks.txt**

**自旋锁，这里自旋的意思值得是线程在一个while循环中不停地检查期望的条件是否得到**
**了满足，如果没有得到满足就等待一段时间，然后继续检查，知道满足之后才会执行后续**
**的处理。**
说白了，自旋就是忙等，我们在以前学习组成原理的时候，了解到cpu与设备的通信方式
主要有3种，分别是程序查询方式（忙等）、中断请求、DMA。其中程序查询方式会中断
cpu的执行，原地踏步，影响cpu的执行效率，可能想到这的时候会认为自旋锁也是这样的
一种锁，这很自然，类比嘛，但是其中有些差别。
我们前面提及的程序查询方式是cpu与硬件设备进行通信的方式，与我们这里操作系统内
部的自旋锁还稍微有些差别，不过，确实是，自旋锁这种排它性锁对系统整体性能可能影
响是比较大的，所以我们在内核中不会用它来长时间阻塞一个线程，而是用它来短暂的阻
塞一个线程，例如将其用于进程调度、线程调度，这个时候，自旋锁在内核中还是非常高
效的。

另外，实现自旋锁还是比较复杂的，因为要保证能够正确处理可能存在的竟态条件，需要
考虑cpu架构，以及针对这种架构的特殊的汇编指令，例如原子的test、set指令来实现对
自旋锁的加锁、解锁、测试，这在高级语言中是无法做到的。
如果cpu架构中没有原子的这种test、set操作的话，则需要通过某种算法来实现类似的原
子操作。
这样看来，自旋锁是与cpu有关的，好了，现在先不多说了，在看第3个例子的时候，提到
non-irq版本的自旋锁进入临界区后，如果有相同的cpu上有中断到达，并且中断处理函数
中请求相同的自旋锁时，会引发死锁，当讲到这的时候，我们将详细描述自旋锁的实现细
节。

其实自旋锁效率高不高，还是要看应用的场景，好了下面介绍一下内核中3种常用的自旋
锁。

Lesson 1: Spin locks

The most basic primitive for locking is spinlock.

    static DEFINE_SPINLOCK(xxx_lock);
     
        unsigned long flags;
    
        spin_lock_irqsave(&xxx_lock, flags);
        ... critical section here ..
        spin_unlock_irqrestore(&xxx_lock, flags);
    
    这里的自旋锁会屏蔽后期到达的中断请求，屏蔽并不是表示忽略，而是将到达的中断
    请求暂时保存起来，即irqsave，等临界区代码执行完毕时，再将咱存的中断请求恢
    复，即irqrestore。

The above is always safe. It will disable interrupts _locally_, but the
spinlock itself will guarantee the global lock, so it will guarantee that
there is only one thread-of-control within the region(s) protected by that
lock. This works well even under UP also, so the code does _not_ need to
worry about UP vs SMP issues: the spinlocks work correctly under both.

UP: Uniprocessor，单处理器；
SMP: Symmetric Multiprocessor，对称多处理器；
spin_lock_irqsave/spin_lock_irqrestore会禁止中断，这种方式使得自旋锁在UP、SMP
两种情况下均适用。

NOTE! Implications of spin_locks for memory are further described in:

    Documentation/memory-barriers.txt
       (5) LOCK operations.
       (6) UNLOCK operations.

The above is usually pretty simple (you usually need and want only one
spinlock for most things - using more than one spinlock can make things a lot
more complex and even slower and is usually worth it only for sequences that
you _know_ need to be split up: avoid it at all cost if you aren't sure).

This is really the only really hard part about spinlocks: once you start
using spinlocks they tend to expand to areas you might not have noticed
before, because you have to make sure the spinlocks correctly protect the
shared data structures _everywhere_ they are used. The spinlocks are most
easily added to places that are completely independent of other code (for
example, internal driver data structures that nobody else ever touches).

NOTE! The spin-lock is safe only when you _also_ use the lock itself to do
locking across CPU's, which implies that EVERYTHING that touches a shared
variable has to agree about the spinlock they want to use.

----

Lesson 2: reader-writer spinlocks.

If your data accesses have a very natural pattern where you usually tend to
mostly read from the shared variables, the reader-writer locks (rw_lock)
versions of the spinlocks are sometimes useful. They allow multiple readers to
be in the same critical region at once, but if somebody wants to change the
variables it has to get an exclusive write lock.

NOTE! reader-writer locks require more atomic memory operations than simple
spinlocks.  Unless the reader critical section is long, you are better off
just using spinlocks.

其实这里考虑的还是细粒度加锁，以便提高并行、并发能力。
禁用中断的自旋锁版本是最简单的自旋锁版本，但是它由于是排它性锁，所以对并行性影
响较大；
而自旋锁的另一个版本，读写锁，在读者较多的情况下，能够适当提高并行性，提升系统
性能，但是这种情况下，最好临界区比较长，如果临界区比较短的情况下，并行性能的提
升也不会很明显，这个时候最好使用简单版本的自旋锁。

The routines look the same as above:

    rwlock_t xxx_lock = __RW_LOCK_UNLOCKED(xxx_lock);
     
         unsigned long flags;
     
         read_lock_irqsave(&xxx_lock, flags);
         .. critical section that only reads the info ...
         read_unlock_irqrestore(&xxx_lock, flags);
     
         write_lock_irqsave(&xxx_lock, flags);
         .. read and write exclusive access to the info ...
         write_unlock_irqrestore(&xxx_lock, flags);

The above kind of lock may be useful for complex data structures like linked
lists, especially searching for entries without changing the list itself.  The
read lock allows many concurrent readers.  Anything that _changes_ the list
will have to get the write lock.

NOTE! RCU is better for list traversal, but requires careful attention to
design detail (see Documentation/RCU/listRCU.txt).

Also, you cannot "upgrade" a read-lock to a write-lock, so if you at _any_
time need to do any changes (even if you don't do it every time), you have to
get the write-lock at the very beginning.

NOTE! We are working hard to remove reader-writer spinlocks in most cases, so
please don't add a new one without consensus.  (Instead, see
Documentation/RCU/rcu.txt for complete information.)

Lesson 3: spinlocks revisited.

The single spin-lock primitives above are by no means the only ones. They are
the most safe ones, and the ones that work under all circumstances, but partly
_because_ they are safe they are also fairly slow. They are slower than they'd
need to be, because they do have to disable interrupts (which is just a single
instruction on a x86, but it's an expensive one - and on other architectures
it can be worse).

这里说的因为前两个版本安全，所以它们慢，这么说的原因，是因为，它们加锁的方式限
制了并行度的提高，以牺牲其他线程的运行来保证安全，这影响了整体的运行效率。

If you have a case where you have to protect a data structure across several
CPU's and you want to use spinlocks you can potentially use cheaper versions
of the spinlocks. IF you know that the spinlocks are never used in interrupt
handlers, you can use the non-irq versions:

non-irq版本的自旋锁指的是，没有屏蔽中断的自旋锁，当线程进入临界区时，如果这个
时候有中断到达，该中断信号将会被中断处理函数处理，而不是像自旋锁中最简单的那个
版本一样将之irqsave\irqrestore。

        spin_lock(&lock);
        ...
        spin_unlock(&lock);

(and the equivalent read-write versions too, of course). The spinlock will
guarantee the same kind of exclusive access, and it will be much faster. 
This is useful if you know that the data in question is only ever
manipulated from a "process context", ie no interrupts involved. 

The reasons you mustn't use these versions if you have interrupts that
play with the spinlock is that you can get deadlocks:

        spin_lock(&lock);
        ...
                <- interrupt comes in:
                        spin_lock(&lock);
    
        如果在处理器1上加了自旋锁，在进入临界区之后，如果在相同的处理器上有中
        断请求，并且处理函数中也请求对相同的自旋锁进行加锁，此时就会发生死锁;
        如果该中断是在不同的处理器上的话，则不会引发死锁。
    
        为什么会这样呢，前面讲述各个版本的自旋锁之前，我们提到了自旋锁的实现与
        具体的cpu架构以及特殊的汇编指令有关，好的，现在我们讲一下x86架构下，一
        个non-irq版本的自旋锁的实现（详细信息参看wiki）：
    
        ; Intel syntax
         
        locked:        ; The lock variable. 1 = locked, 0 = unlocked.
             dd      0
        spin_lock:
             mov     eax, 1          ; Set the EAX register to 1.
    
             xchg    eax, [locked]   ; Atomically swap the EAX register with
                                     ; the lock variable.
                                     ; This will always store 1 to the lock, leaving
                                     ; the previous value in the EAX register.
             test    eax, eax        ; Test EAX with itself. Among other things, this will
                                     ; set the processor's Zero Flag if EAX is 0.
                                     ; If EAX is 0, then the lock was unlocked and
                                     ; we just locked it.
                                     ; Otherwise, EAX is 1 and we didn't acquire the lock.  
             jnz     spin_lock       ; Jump back to the MOV instruction if the Zero Flag is
                                     ;  not set; the lock was previously locked, and so
                                     ; we need to spin until it becomes unlocked.
             ret                     ; The lock has been acquired, return to the calling 
                                     ;  function.
        spin_unlock:
             mov     eax, 0          ; Set the EAX register to 0.
             xchg    eax, [locked]   ; Atomically swap the EAX register with
                                     ;  the lock variable.
             ret                     ; The lock has been released.

where [an interrupt] tries to lock an already locked variable. This is ok if
[the other interrupt] happens on another CPU, but it is _not_ ok if the
interrupt happens on the same CPU that already holds the lock, because the
lock will obviously never be released (because the interrupt is waiting
for the lock, and the lock-holder is interrupted by the interrupt and will
not continue until the interrupt has been processed). 

这段话很重要，我翻译翻译！ 在翻译之前，需要指明，文档中有几个地方写的不是很好
，比如 the other interrupt，其实这个the other interrupt指的就是前面的an
interrupt，不指出来理解起来就是误解。

首先non-irq版本的自旋锁不会屏蔽中断，有中断到达的时候，仍然会对其进行中断处理
，这一点要明确。

【当某个中断试图锁定一个已经被锁定的变量时，如果这个中断是在另一个cpu上到达，
  那么这种情况下是可行的：

    在当前cpu1上一个线程已经锁定了该变量（non-irq锁），这个时候中断到达到达
    cpu2，然后cpu2进入中断的中断处理函数，处理函数中请求对该变量再次加锁，这个
    时候，cpu不会允许该加锁，参考上面x86中spinlock的实现，当前[locked]中值为1
    ，xchg之后，eax为1，test eax,eax，标志寄存器Z为1，jnz spin_lock继续自旋，
    可见此时加锁没有成功，中断会继续自旋直到加锁成功。
    
    如果要加锁成功，就要等到cpu1上的持有锁的线程释放锁，只要它释放了锁，cpu2上
    的执行中断处理函数的线程就能够成功对其、进行加锁，二者不会构成死锁。
    
    所以说这种情形下，是可行的！
】

【当某个中断试图锁定一个已经被锁定的变量时，如果这个中断与当前中断在相同的cpu上
  到达，那么这种情况下是不可行的：

    在当前cpu上一个线程已经锁定了该变量（non-irq锁），这个时候中断到达，然后进
    入中断的中断处理函数，处理函数中请求对该变量再次加锁，这个时候，cpu不会允
    许该加锁，参考上面x86中spinlock的实现，当前[locked]中值为1，xchg之后，eax
    为1，test eax,eax，标志寄存器Z为1，jnz spin_lock继续自旋，可见此时加锁没有
    成功，中断1会继续自旋直到加锁成功，但是，只有持有该锁的当前线程被中断了，
    释放锁的代码不可能被执行，也就是说中断处理函数中会一直阻塞不会返回。中断处
    理函数请求加锁，而当前线程作为锁的持有者，又不释放锁，从而造成死锁。
    
    所以说这种情形下，是不可行的！
】

(This is also the reason why the irq-versions of the spinlocks only need
to disable the _local_ interrupts - it's ok to use spinlocks in interrupts
on other CPU's, because an interrupt on another CPU doesn't interrupt the
CPU that holds the lock, so the lock-holder can continue and eventually
releases the lock). 

Note that you can be clever with read-write locks and interrupts. For
example, if you know that the interrupt only ever gets a read-lock, then
you can use a non-irq version of read locks everywhere - because they
don't block on each other (and thus there is no dead-lock wrt interrupts. 
But when you do the write-lock, you have to use the irq-safe version. 

For an example of being clever with rw-locks, see the "waitqueue_lock" 
handling in kernel/sched.c - nothing ever _changes_ a wait-queue from
within an interrupt, they only read the queue in order to know whom to
wake up. So read-locks are safe (which is good: they are very common
indeed), while write-locks need to protect themselves against interrupts.

----

Reference information:

For dynamic initialization, use spin_lock_init() or rwlock_init() as
appropriate:

   spinlock_t xxx_lock;
   rwlock_t xxx_rw_lock;

   static int __init xxx_init(void)
   {
        spin_lock_init(&xxx_lock);
        rwlock_init(&xxx_rw_lock);
        ...
   }

   module_init(xxx_init);

For static initialization, use DEFINE_SPINLOCK() / DEFINE_RWLOCK() or
__SPIN_LOCK_UNLOCKED() / __RW_LOCK_UNLOCKED() as appropriate.

[16] sparse.txt
Using sparse for typechecking

[17] sgi-viws.txt

The SGI Visual Workstations (models 320 and 540) are based around the Cobalt,
Lithium, and Arsenic ASICs.  The Cobalt ASIC is the main system ASIC which
interfaces the 1-4 IA32 cpus, the memory system, and the I/O system in the
Lithium ASIC.  The Cobalt ASIC also contains the 3D gfx rendering engine which
renders to main system memory -- part of which is used as the frame buffer
which is DMA'ed to a video connector using the Arsenic ASIC.  A PIIX4 chip and
NS87307 are used to provide legacy device support (IDE, serial, floppy, and
parallel).

The Visual Workstation chipset largely conforms to the PC architecture
with some notable exceptions such as interrupt handling.

[18] sgi-ioc4.txt

The SGI IOC4 PCI device is a bit of a strange beast, so some notes on it are
in order.

First, even though the IOC4 performs multiple functions, such as an IDE
controller, a serial controller, a PS/2 keyboard/mouse controller, and an
external interrupt mechanism, it's not implemented as a multifunction device.
The consequence of this from a software standpoint is that all these functions
share a single IRQ, and they can't all register to own the same PCI device ID.
To make matters a bit worse, some of the register blocks (and even registers
        themselves) present in IOC4 are mixed-purpose between these several
functions, meaning that there's no clear "owning" device driver.
     
The solution is to organize the IOC4 driver into several independent drivers,
"ioc4", "sgiioc4", and "ioc4_serial".  Note that there is no PS/2 controller
driver as this functionality has never been wired up on a shipping IO card.

[19] serial-console.txt

Linux Serial Console

To use a serial port as console you need to compile the support into your
kernel - by default it is not compiled in. For PC style serial ports
it's the config option next to "Standard/generic (dumb) serial support".
You must compile serial support into the kernel and not as a module.

It is possible to specify multiple devices for console output. You can
define a new kernel command line option to select which device(s) to
use for console output.

The format of this option is:

console=device,options

device:         tty0 for the foreground virtual console
ttyX for any other virtual console
ttySx for a serial port
lp0 for the first parallel port
ttyUSB0 for the first USB serial device

options:        depend on the driver. For the serial port this
defines the baudrate/parity/bits/flow control of
the port, in the format BBBBPNF, where BBBB is the
speed, P is parity (n/o/e), N is number of bits,
and F is flow control ('r' for RTS). Default is
9600n8. The maximum baudrate is 115200.

You can specify multiple console= options on the kernel command line.
Output will appear on all of them. The last device will be used when
you open /dev/console. So, for example:

console=ttyS1,9600 console=tty0

defines that opening /dev/console will get you the current foreground
virtual console, and kernel messages will appear on both the VGA
console and the 2nd serial port (ttyS1 or COM2) at 9600 baud.

Note that you can only define one console per device type (serial, video).

If no console device is specified, the first device found capable of
acting as a system console will be used. At this time, the system
first looks for a VGA card and then for a serial port. So if you don't
have a VGA card in your system the first serial port will automatically
become the console.

You will need to create a new device to use /dev/console. The official
/dev/console is now character device 5,1.

(You can also use a network device as a console.  See
Documentation/networking/netconsole.txt for information on that.)

Here's an example that will use /dev/ttyS1 (COM2) as the console.
Replace the sample values as needed.

1. Create /dev/console (real console) and /dev/tty0 (master virtual
console):

cd /dev
rm -f console tty0
mknod -m 622 console c 5 1
mknod -m 622 tty0 c 4 0

2. LILO can also take input from a serial device. This is a very
useful option. To tell LILO to use the serial port:
In lilo.conf (global section): 

serial  = 1,9600n8 (ttyS1, 9600 bd, no parity, 8 bits)

3. Adjust to kernel flags for the new kernel,
again in lilo.conf (kernel section)

append = "console=ttyS1,9600" 

4. Make sure a getty runs on the serial port so that you can login to
it once the system is done booting. This is done by adding a line
like this to /etc/inittab (exact syntax depends on your getty):

S1:23:respawn:/sbin/getty -L ttyS1 9600 vt100

5. Init and /etc/ioctl.save

Sysvinit remembers its stty settings in a file in /etc, called
`/etc/ioctl.save'. REMOVE THIS FILE before using the serial
console for the first time, because otherwise init will probably
set the baudrate to 38400 (baudrate of the virtual console).

6. /dev/console and X
Programs that want to do something with the virtual console usually
open /dev/console. If you have created the new /dev/console device,
and your console is NOT the virtual console some programs will fail.
Those are programs that want to access the VT interface, and use
/dev/console instead of /dev/tty0. Some of those programs are:

Xfree86, svgalib, gpm, SVGATextMode

It should be fixed in modern versions of these programs though.

Note that if you boot without a console= option (or with
console=/dev/tty0), /dev/console is the same as /dev/tty0. In that
case everything will still work.

[20] rtc.txt

Real Time Clock (RTC) Drivers for Linux

[21] rt-mutex.txt

RT-mutex subsystem with PI support

这个地方PI指的是Priority Inheritance。

----------------------------------

RT-mutexes with priority inheritance are used to support PI-futexes, which
enable pthread_mutex_t priority inheritance attributes (PTHREAD_PRIO_INHERIT).
[See Documentation/pi-futex.txt for more details about PI-futexes.]

This technology was developed in the -rt tree and streamlined for
pthread_mutex support.

Basic principles:
-----------------

RT-mutexes extend the semantics of simple mutexes by the priority inheritance
protocol.
RT-mutexes通过优先级继承协议，扩展了简单mutex的语义。

A low priority owner of a rt-mutex inherits the priority of a higher priority
waiter until the rt-mutex is released. If the temporarily boosted owner blocks
on a rt-mutex itself it propagates the priority boosting to the owner of the
other rt_mutex it gets blocked on. The priority boosting is immediately
removed once the rt_mutex has been unlocked.

rt-mutex的一个低优先级持有者，可以继承等待该rt-mutex的一个高优先级任务的优先级
，低优先级持有者获取了高优先级任务的优先级之后，在内核任务调度时会获取更多的机
会，能够尽快执行完任务，更早地释放rt-mutex，从而让高优先级任务不用因为等待低优
先级任务释放锁而浪费太多时间。在低优先级任务释放锁之后，将恢复到以前的低优先级
。

假如一个获取了rt-mutex（记为m1）的低优先级任务继承了一个等待该锁的高优先级任务
的优先级，此时如果该低优先级任务还希望获取另一个rt-mutex（记为m2），那么该低优
先级会将继承到的高优先级任务的优先级传递给锁m2的持有者。如果m2的持有者因为获取
高优先级提前完成了任务并释放锁，那么m1的持有者也会提前获得锁m2并尽快完成任务，
并释放锁m1、m2，从而使得高优先级任务尽快获得锁m1.这样看来，rt-mutex优先级的继
承，对系统整体性能来说会是一大改进。

This approach allows us to shorten the block of high-prio tasks on mutexes
which protect shared resources. Priority inheritance is not a magic bullet for
poorly designed applications, but it allows well-designed applications to use
userspace locks in critical parts of an high priority thread, without losing
determinism.

The enqueueing of the waiters into the rtmutex waiter list is done in priority
order. For same priorities FIFO order is chosen. For each rtmutex, only the
top priority waiter is enqueued into the owner's priority waiters list. This
list too queues in priority order. Whenever the top priority waiter of a task
changes (for example it timed out or got a signal), the priority of the owner
task is readjusted. [The priority enqueueing is handled by "plists", see

等待rt-mutex的任务按照优先级顺序进入该rt-mutex的等待队列。如果任务是相同的优先
级，则按照先请求先进入队列的原则。对于每一个rt-mutex，只有优先级最高的处于等待
状态的任务会被选择进入锁持有者的优先级等待者队列中，并且这个队列也是按照优先级
进行排序。不管什么时候，这个任务的优先级等待队列的最高优先级的任务发生改变，这
个任务的优先级都会被进行重新调整。

include/linux/plist.h for more details.]

RT-mutexes are optimized for fastpath operations and have no internal locking
overhead when locking an uncontended mutex or unlocking a mutex without
waiters. The optimized fastpath operations require cmpxchg support. [If that
is not available then the rt-mutex internal spinlock is used]

The state of the rt-mutex is tracked via the owner field of the rt-mutex
structure:

rt_mutex->owner holds the task_struct pointer of the owner. Bit 0 and 1 are
used to keep track of the "owner is pending" and "rtmutex has waiters" state.

owner          bit1    bit0
NULL           0       0       mutex is free (fast acquire possible)
NULL           0       1       invalid state
NULL           1       0       Transitional state*
NULL           1       1       invalid state
taskpointer    0       0       mutex is held (fast release possible)
taskpointer    0       1       task is pending owner
taskpointer    1       0       mutex is held and has waiters
taskpointer    1       1       task is pending owner and mutex has waiters

Pending-ownership handling is a performance optimization: pending-ownership is
assigned to the first (highest priority) waiter of the mutex, when the mutex
is released. The thread is woken up and once it starts executing it can
acquire the mutex. Until the mutex is taken by it (bit 0 is cleared) a
competing higher priority thread can "steal" the mutex which puts the woken up
thread back on the waiters list.

The pending-ownership optimization is especially important for the
uninterrupted workflow of high-prio tasks which repeatedly takes/releases
locks that have lower-prio waiters. Without this optimization the higher-prio
thread would ping-pong to the lower-prio task [because at unlock time we
always assign a new owner].

(*) The "mutex has waiters" bit gets set to take the lock. If the lock doesn't
already have an owner, this bit is quickly cleared if there are no waiters.
So this is a transitional state to synchronize with looking at the owner field
of the mutex and the mutex owner releasing the lock.

[22] rt-mutex-design.txt

RT-mutex implementation design
------------------------------

This document tries to describe the design of the rtmutex.c implementation.
It doesn't describe the reasons why rtmutex.c exists. For that please see
Documentation/rt-mutex.txt.  Although this document does explain problems that
happen without this code, but that is in the concept to understand what the
code actually is doing.

这个文档解释rtmutex的具体设计，关于为什么要实现rtmutex，请参考前面21这部分。

The goal of this document is to help others understand the priority
inheritance (PI) algorithm that is used, as well as reasons for the decisions
that were made to implement PI in the manner that was done.

这个文档的目的是为了帮助别人理解使用的优先级继承算法，以及实现该算法过程中采用
的某些相关决策的原因。

Unbounded Priority Inversion
----------------------------

Priority inversion is when a lower priority process executes while a higher
priority process wants to run.  This happens for several reasons, and most of
the time it can't be helped.  Anytime a high priority process wants to use a
resource that a lower priority process has (a mutex for example), the high
priority process must wait until the lower priority process is done with the
resource.  This is a priority inversion.  What we want to prevent is something
called unbounded priority inversion.  That is when the high priority process
is prevented from running by a lower priority process for an undetermined
amount of time.

理解优先级反转，优先级反转指的是，当一个低优先级进程执行的时候，同时有一个高优
先级进程也希望执行。这在很多情况下都会发生，并且大多数情况下是无法被干预的。某
个时候，如果一个高优先级进车功能希望使用一个低优先级进程拥有的资源，例如一个锁
，高优先级进程不得不等待到低优先级进程释放这个资源，然后才能获取到该资源，并继
续执行。本来高优先级的进程应该先于低优先级进程执行，但是这里，却因为等待低优先
级进程释放资源而等待，并且等待的时间是无法确定的，这种情况我们称之为优先级反转
。
我们希望能够阻止不受限制的优先级反转，即，当一个高优先级进程被一个低优先级进程
阻塞，并且阻塞时间不缺定，我们需要阻止或者尽量避免这种情况。

The classic example of unbounded priority inversion is were you have three
processes, let's call them processes A, B, and C, where A is the highest
priority process, C is the lowest, and B is in between. A tries to grab a lock
that C owns and must wait and lets C run to release the lock. But in the
meantime, B executes, and since B is of a higher priority than C, it preempts
C, but by doing so, it is in fact preempting A which is a higher priority
process.  Now there's no way of knowing how long A will be sleeping waiting
for C to release the lock, because for all we know, B is a CPU hog and will
never give C a chance to release the lock.  This is called unbounded priority
inversion.

举个不受限制的优先级反转的例子，假定有3个进程A、B、C，优先级依次降低，现在A希
望获取一个锁，这个锁被C持有，因此A需要等待到C执行到释放锁后才能继续向下执行，
假定在C释放锁之前，B开始执行，由于B优先级比C高，有可能B会抢占CPU而先于C执行，
假定B占用的CPU时间比较长，例如B是一个while(1)循环，它不会给C机会区释放锁，因此
间接地阻止了最高优先级进程A的执行，并且A继续等待的事件会很长甚至是永久，这被称
之为不受限制的优先级反转。

 Here's a little ASCII art to show the problem.

    grab lock L1 (owned by C)
          |
     A ---+
             C preempted by B
               |
     C    +----+
     
     B         +-------->
                     B now keeps A from running.

Priority Inheritance (PI)
-------------------------

There are several ways to solve this issue, but other ways are out of scope
for this document.  Here we only discuss PI.

有很多方法来解决不受限制的优先级反转问题，但是这里值讨论优先级继承PI这种方法。

PI is where a process inherits the priority of another process if the other
process blocks on a lock owned by the current process.  To make this easier
to understand, let's use the previous example, with processes A, B, and C again.

This time, when A blocks on the lock owned by C, C would inherit the priority
of A.  So now if B becomes runnable, it would not preempt C, since C now has
the high priority of A.  As soon as C releases the lock, it loses its
inherited priority, and A then can continue with the resource that C had.

以上个例子为例，引入PI，这次，当A等待C释放锁而阻塞时，C会继承A的优先级。所以如
果B运行的时候，它不会抢占C的CPU，因为C已经继承了A的优先级，A的优先级是最高的。
一旦C释放了锁之后，它就会失去从A继承来的优先级，A然后就会获得C释放的锁并继续执
行。

Terminology
-----------

Here I explain some terminology that is used in this document to help describe
the design that is used to implement PI.

PI chain - The PI chain is an ordered series of locks and processes that cause
           processes to inherit priorities from a previous process that is
           blocked on one of its locks.  This is described in more detail
           later in this document.

           优先级继承链。

mutex    - In this document, to differentiate from locks that implement PI and
           spin locks that are used in the PI code, from now on the PI locks
           will be called a mutex.

           在这篇文档中，为了区分实现了优先级继承的锁，和实现该锁的代码中用到
           的普通的自旋锁，从现在开始，实现了优先级继承的锁，将被称为mutex。

lock     - In this document from now on, I will use the term lock when
           referring to spin locks that are used to protect parts of the PI
           algorithm.  These locks disable preemption for UP (when
                   CONFIG_PREEMPT is enabled) and on SMP prevents multiple
           CPUs from entering critical sections simultaneously.

           在这篇文档中，将使用lock指代自旋锁。

spin lock - Same as lock above.
            
            自旋锁，与我们上面提到的lock，在描述PI锁的时候，将表示相同的概念。

waiter   - A waiter is a struct that is stored on the stack of a blocked
           process.  Since the scope of the waiter is within the code for a
           process being blocked on the mutex, it is fine to allocate the
           waiter on the process's stack (local variable).  This structure
           holds a pointer to the task, as well as the mutex that the task is
           blocked on.  It also has the plist node structures to place the
           task in the waiter_list of a mutex as well as the pi_list of a
           mutex owner task (described below).

           waiter is sometimes used in reference to the task that is waiting
           on a mutex. This is the same as waiter->task.

waiters  - A list of processes that are blocked on a mutex.

top waiter - The highest priority process waiting on a specific mutex.

top pi waiter - The highest priority process waiting on one of the mutexes
                that a specific process owns.

Note:  task and process are used interchangeably in this document, mostly to
differentiate between two processes that are being described together.

PI chain
--------

The PI chain is a list of processes and mutexes that may cause priority
inheritance to take place.  Multiple chains may converge, but a chain
would never diverge, since a process can't be blocked on more than one
mutex at a time.

Example:

Process:  A, B, C, D, E
Mutexes:  L1, L2, L3, L4

    A owns: L1
            B blocked on L1
            B owns L2
                   C blocked on L2
                   C owns L3
                          D blocked on L3
                          D owns L4
                                 E blocked on L4

The chain would be:

E->L4->D->L3->C->L2->B->L1->A

To show where two chains merge, we could add another process F and another
mutex L5 where B owns L5 and F is blocked on mutex L5.

The chain for F would be:

F->L5->B->L1->A

Since a process may own more than one mutex, but never be blocked on more than
one, the chains merge.

Here we show both chains:

    E->L4->D->L3->C->L2-+
                        |
                        +->B->L1->A
                        |
                  F->L5-+

For PI to work, the processes at the right end of these chains (or we may also
call it the Top of the chain) must be equal to or higher in priority than the
processes to the left or below in the chain.

Also since a mutex may have more than one process blocked on it, we can have
multiple chains merge at mutexes.  If we add another process G that is blocked
on mutex L2:

G->L2->B->L1->A

And once again, to show how this can grow I will show the merging chains
again.

    E->L4->D->L3->C-+
                    +->L2-+
                    |     |
                  G-+     +->B->L1->A
                          |
                    F->L5-+

Plist
-----

Before I go further and talk about how the PI chain is stored through lists on
both mutexes and processes, I'll explain the plist.  This is similar to the
struct list_head functionality that is already in the kernel.  The
implementation of plist is out of scope for this document, but it is very
important to understand what it does.

There are a few differences between plist and list, the most important one
being that plist is a priority sorted linked list.  This means that the
priorities of the plist are sorted, such that it takes O(1) to retrieve the
highest priority item in the list.  Obviously this is useful to store
processes based on their priorities.

Another difference, which is important for implementation, is that, unlike
list, the head of the list is a different element than the nodes of a list.
So the head of the list is declared as struct plist_head and nodes that will
be added to the list are declared as struct plist_node.


Mutex Waiter List
-----------------

Every mutex keeps track of all the waiters that are blocked on itself. The
mutex has a plist to store these waiters by priority.  This list is protected
by a spin lock that is located in the struct of the mutex. This lock is called
wait_lock.  Since the modification of the waiter list is never done in
interrupt context, the wait_lock can be taken without disabling interrupts.


Task PI List
------------

To keep track of the PI chains, each process has its own PI list.  This is a
list of all top waiters of the mutexes that are owned by the process.  Note
that this list only holds the top waiters and not all waiters that are blocked
on mutexes owned by the process.

The top of the task's PI list is always the highest priority task that is
waiting on a mutex that is owned by the task.  So if the task has inherited a
priority, it will always be the priority of the task that is at the top of
this list.

This list is stored in the task structure of a process as a plist called
pi_list.  This list is protected by a spin lock also in the task structure,
called pi_lock.  This lock may also be taken in interrupt context, so when
locking the pi_lock, interrupts must be disabled.


Depth of the PI Chain
---------------------

The maximum depth of the PI chain is not dynamic, and could actually be
defined.  But is very complex to figure it out, since it depends on all the
nesting of mutexes.  Let's look at the example where we have 3 mutexes, L1,
L2, and L3, and four separate functions func1, func2, func3 and func4.  The
following shows a locking order of L1->L2->L3, but may not actually be
directly nested that way.

void func1(void)
{
    mutex_lock(L1);
    
    /* do anything */
    
    mutex_unlock(L1);
}

void func2(void)
{
    mutex_lock(L1);
    mutex_lock(L2);
    
    /* do something */
    
    mutex_unlock(L2);
    mutex_unlock(L1);
}

void func3(void)
{
    mutex_lock(L2);
    mutex_lock(L3);
    
    /* do something else */
    
    mutex_unlock(L3);
    mutex_unlock(L2);
}

void func4(void)
{
    mutex_lock(L3);

    /* do something again */
    
    mutex_unlock(L3);
}

Now we add 4 processes that run each of these functions separately.  Processes
A, B, C, and D which run functions func1, func2, func3 and func4 respectively,
and such that D runs first and A last.  With D being preempted in func4 in the
"do something again" area, we have a locking that follows:

D owns L3
C blocked on L3
C owns L2
B blocked on L2
B owns L1
A blocked on L1

And thus we have the chain A->L1->B->L2->C->L3->D.

This gives us a PI depth of 4 (four processes), but looking at any of the
functions individually, it seems as though they only have at most a locking
depth of two.  So, although the locking depth is defined at compile time, it
still is very difficult to find the possibilities of that depth.

Now since mutexes can be defined by user-land applications, we don't want a
DOS type of application that nests large amounts of mutexes to create a large
PI chain, and have the code holding spin locks while looking at a large amount
of data.  So to prevent this, the implementation not only implements a maximum
lock depth, but also only holds at most two different locks at a time, as it
walks the PI chain.  More about this below.


Mutex owner and flags
---------------------

The mutex structure contains a pointer to the owner of the mutex.  If the
mutex is not owned, this owner is set to NULL.  Since all architectures have
the task structure on at least a four byte alignment (and if this is not true,
the rtmutex.c code will be broken!), this allows for the two least significant
bits to be used as flags.  This part is also described in
Documentation/rt-mutex.txt, but will also be briefly described here.

Bit 0 is used as the "Pending Owner" flag.  This is described later.
Bit 1 is used as the "Has Waiters" flags.  This is also described later in
more detail, but is set whenever there are waiters on a mutex.


cmpxchg Tricks
--------------

Some architectures implement an atomic cmpxchg (Compare and Exchange).  This
is used (when applicable) to keep the fast path of grabbing and releasing
mutexes short.

cmpxchg is basically the following function performed atomically:

unsigned long _cmpxchg(unsigned long *A, unsigned long *B, unsigned long *C)
{
    unsigned long T = *A;
    if (*A == *B) {
        *A = *C;
    }
    return T;
}
#define cmpxchg(a,b,c) _cmpxchg(&a,&b,&c)

This is really nice to have, since it allows you to only update a variable if
the variable is what you expect it to be.  You know if it succeeded if the
return value (the old value of A) is equal to B.

The macro rt_mutex_cmpxchg is used to try to lock and unlock mutexes. If the
architecture does not support CMPXCHG, then this macro is simply set to fail
every time.  But if CMPXCHG is supported, then this will help out extremely to
keep the fast path short.

The use of rt_mutex_cmpxchg with the flags in the owner field help optimize
the system for architectures that support it.  This will also be explained
later in this document.


Priority adjustments
--------------------

The implementation of the PI code in rtmutex.c has several places that a
process must adjust its priority.  With the help of the pi_list of a process
this is rather easy to know what needs to be adjusted.

The functions implementing the task adjustments are rt_mutex_adjust_prio,
__rt_mutex_adjust_prio (same as the former, but expects the task pi_lock to
already be taken), rt_mutex_getprio, and rt_mutex_setprio.

rt_mutex_getprio and rt_mutex_setprio are only used in __rt_mutex_adjust_prio.

rt_mutex_getprio returns the priority that the task should have.  Either the
task's own normal priority, or if a process of a higher priority is waiting on
a mutex owned by the task, then that higher priority should be returned.
Since the pi_list of a task holds an order by priority list of all the top
waiters of all the mutexes that the task owns, rt_mutex_getprio simply needs
to compare the top pi waiter to its own normal priority, and return the higher
priority back.

(Note:  if looking at the code, you will notice that the lower number of prio
is returned.  This is because the prio field in the task structure is an
inverse order of the actual priority.  So a "prio" of 5 is of higher priority
than a "prio" of 10.)

__rt_mutex_adjust_prio examines the result of rt_mutex_getprio, and if the
result does not equal the task's current priority, then rt_mutex_setprio is
called to adjust the priority of the task to the new priority.  Note that
rt_mutex_setprio is defined in kernel/sched.c to implement the actual change
in priority.

It is interesting to note that __rt_mutex_adjust_prio can either increase or
decrease the priority of the task.  In the case that a higher priority process
has just blocked on a mutex owned by the task, __rt_mutex_adjust_prio would
increase/boost the task's priority.  But if a higher priority task were for
some reason to leave the mutex (timeout or signal), this same function would
decrease/unboost the priority of the task.  That is because the pi_list always
contains the highest priority task that is waiting on a mutex owned by the
task, so we only need to compare the priority of that top pi waiter to the
normal priority of the given task.


High level overview of the PI chain walk
----------------------------------------

The PI chain walk is implemented by the function rt_mutex_adjust_prio_chain.

The implementation has gone through several iterations, and has ended up with
what we believe is the best.  It walks the PI chain by only grabbing at most
two locks at a time, and is very efficient.

The rt_mutex_adjust_prio_chain can be used either to boost or lower process
priorities.

rt_mutex_adjust_prio_chain is called with a task to be checked for PI
(de)boosting (the owner of a mutex that a process is blocking on), a flag to
check for deadlocking, the mutex that the task owns, and a pointer to a waiter
that is the process's waiter struct that is blocked on the mutex (although
this parameter may be NULL for deboosting).

For this explanation, I will not mention deadlock detection. This explanation
will try to stay at a high level.

When this function is called, there are no locks held.  That also means that
the state of the owner and lock can change when entered into this function.

Before this function is called, the task has already had rt_mutex_adjust_prio
performed on it.  This means that the task is set to the priority that it
should be at, but the plist nodes of the task's waiter have not been updated
with the new priorities, and that this task may not be in the proper locations
in the pi_lists and wait_lists that the task is blocked on.  This function
solves all that.

A loop is entered, where task is the owner to be checked for PI changes that
was passed by parameter (for the first iteration).  The pi_lock of this task
is taken to prevent any more changes to the pi_list of the task.  This also
prevents new tasks from completing the blocking on a mutex that is owned by
this task.

If the task is not blocked on a mutex then the loop is exited.  We are at the
top of the PI chain.

A check is now done to see if the original waiter (the process that is blocked
on the current mutex) is the top pi waiter of the task.  That is, is this
waiter on the top of the task's pi_list.  If it is not, it either means that
there is another process higher in priority that is blocked on one of the
mutexes that the task owns, or that the waiter has just woken up via a signal
or timeout and has left the PI chain.  In either case, the loop is exited,
since we don't need to do any more changes to the priority of the current
task, or any task that owns a mutex that this current task is waiting on.
A priority chain walk is only needed when a new top pi waiter is made to a
task.

The next check sees if the task's waiter plist node has the priority equal to
the priority the task is set at.  If they are equal, then we are done with the
loop.  Remember that the function started with the priority of the task
adjusted, but the plist nodes that hold the task in other processes pi_lists
have not been adjusted.

Next, we look at the mutex that the task is blocked on. The mutex's wait_lock
is taken.  This is done by a spin_trylock, because the locking order of the
pi_lock and wait_lock goes in the opposite direction. If we fail to grab the
lock, the pi_lock is released, and we restart the loop.

Now that we have both the pi_lock of the task as well as the wait_lock of the
mutex the task is blocked on, we update the task's waiter's plist node that is
located on the mutex's wait_list.

Now we release the pi_lock of the task.

Next the owner of the mutex has its pi_lock taken, so we can update the task's
entry in the owner's pi_list.  If the task is the highest priority process on
the mutex's wait_list, then we remove the previous top waiter from the owner's
pi_list, and replace it with the task.

Note: It is possible that the task was the current top waiter on the mutex, in
which case the task is not yet on the pi_list of the waiter.  This is OK,
      since plist_del does nothing if the plist node is not on any list.

If the task was not the top waiter of the mutex, but it was before we did the
priority updates, that means we are deboosting/lowering the task.  In this
case, the task is removed from the pi_list of the owner, and the new top
waiter is added.

Lastly, we unlock both the pi_lock of the task, as well as the mutex's
wait_lock, and continue the loop again.  On the next iteration of the loop,
the previous owner of the mutex will be the task that will be processed.

Note: One might think that the owner of this mutex might have changed since we
just grab the mutex's wait_lock. And one could be right.  The important thing
to remember is that the owner could not have become the task that is being
processed in the PI chain, since we have taken that task's pi_lock at the
beginning of the loop.  So as long as there is an owner of this mutex that is
not the same process as the tasked being worked on, we are OK.

Looking closely at the code, one might be confused.  The check for the end of
the PI chain is when the task isn't blocked on anything or the task's waiter
structure "task" element is NULL.  This check is protected only by the task's
pi_lock.  But the code to unlock the mutex sets the task's waiter structure
"task" element to NULL with only the protection of the mutex's wait_lock,
which was not taken yet.  Isn't this a race condition if the task becomes
the new owner?

The answer is No!  The trick is the spin_trylock of the mutex's wait_lock.  If
we fail that lock, we release the pi_lock of the task and continue the loop,
doing the end of PI chain check again.

In the code to release the lock, the wait_lock of the mutex is held the entire
time, and it is not let go when we grab the pi_lock of the new owner of the
mutex.  So if the switch of a new owner were to happen after the check for end
of the PI chain and the grabbing of the wait_lock, the unlocking code would
spin on the new owner's pi_lock but never give up the wait_lock.  So the PI
chain loop is guaranteed to fail the spin_trylock on the wait_lock, release
the pi_lock, and try again.

If you don't quite understand the above, that's OK. You don't have to, unless
you really want to make a proof out of it ;)


Pending Owners and Lock stealing
--------------------------------

One of the flags in the owner field of the mutex structure is "Pending Owner".
What this means is that an owner was chosen by the process releasing the
mutex, but that owner has yet to wake up and actually take the mutex.

Why is this important?  Why can't we just give the mutex to another process
and be done with it?

The PI code is to help with real-time processes, and to let the highest
priority process run as long as possible with little latencies and delays.  If
a high priority process owns a mutex that a lower priority process is blocked
on, when the mutex is released it would be given to the lower priority
process.  What if the higher priority process wants to take that mutex again.
The high priority process would fail to take that mutex that it just gave up
and it would need to boost the lower priority process to run with full latency
of that critical section (since the low priority process just entered it).

There's no reason a high priority process that gives up a mutex should be
penalized if it tries to take that mutex again.  If the new owner of the mutex
has not woken up yet, there's no reason that the higher priority process could
not take that mutex away.

To solve this, we introduced Pending Ownership and Lock Stealing.  When a new
process is given a mutex that it was blocked on, it is only given pending
ownership.  This means that it's the new owner, unless a higher priority
process comes in and tries to grab that mutex.  If a higher priority process
does come along and wants that mutex, we let the higher priority process
"steal" the mutex from the pending owner (only if it is still pending) and
continue with the mutex.


Taking of a mutex (The walk through)
------------------------------------

OK, now let's take a look at the detailed walk through of what happens when
taking a mutex.

The first thing that is tried is the fast taking of the mutex.  This is done
when we have CMPXCHG enabled (otherwise the fast taking automatically fails).
Only when the owner field of the mutex is NULL can the lock be taken with the
CMPXCHG and nothing else needs to be done.

If there is contention on the lock, whether it is owned or pending owner we go
about the slow path (rt_mutex_slowlock).

The slow path function is where the task's waiter structure is created on the
stack.  This is because the waiter structure is only needed for the scope of
this function.  The waiter structure holds the nodes to store the task on the
wait_list of the mutex, and if need be, the pi_list of the owner.

The wait_lock of the mutex is taken since the slow path of unlocking the mutex
also takes this lock.

We then call try_to_take_rt_mutex.  This is where the architecture that does
not implement CMPXCHG would always grab the lock (if there's no contention).

try_to_take_rt_mutex is used every time the task tries to grab a mutex in the
slow path.  The first thing that is done here is an atomic setting of the "Has
Waiters" flag of the mutex's owner field.  Yes, this could really be false,
because if the mutex has no owner, there are no waiters and the current task
also won't have any waiters.  But we don't have the lock yet, so we assume we
are going to be a waiter.  The reason for this is to play nice for those
architectures that do have CMPXCHG.  By setting this flag now, the owner of
the mutex can't release the mutex without going into the slow unlock path, and
it would then need to grab the wait_lock, which this code currently holds.  So
setting the "Has Waiters" flag forces the owner to synchronize with this code.

Now that we know that we can't have any races with the owner releasing the
mutex, we check to see if we can take the ownership.  This is done if the
mutex doesn't have a owner, or if we can steal the mutex from a pending owner.
Let's look at the situations we have here.

1) Has owner that is pending
----------------------------

The mutex has a owner, but it hasn't woken up and the mutex flag "Pending
Owner" is set.  The first check is to see if the owner isn't the current task.
This is because this function is also used for the pending owner to grab the
mutex.  When a pending owner wakes up, it checks to see if it can take the
mutex, and this is done if the owner is already set to itself.  If so, we
succeed and leave the function, clearing the "Pending Owner" bit.

If the pending owner is not current, we check to see if the current priority
is higher than the pending owner.  If not, we fail the function and return.

There's also something special about a pending owner.  That is a pending owner
is never blocked on a mutex.  So there is no PI chain to worry about.  It also
means that if the mutex doesn't have any waiters, there's no accounting needed
to update the pending owner's pi_list, since we only worry about processes
blocked on the current mutex.

If there are waiters on this mutex, and we just stole the ownership, we need
to take the top waiter, remove it from the pi_list of the pending owner, and
add it to the current pi_list.  Note that at this moment, the pending owner is
no longer on the list of waiters.  This is fine, since the pending owner would
add itself back when it realizes that it had the ownership stolen from itself.
When the pending owner tries to grab the mutex, it will fail in
try_to_take_rt_mutex if the owner field points to another process.

2) No owner
-----------

If there is no owner (or we successfully stole the lock), we set the owner of
the mutex to current, and set the flag of "Has Waiters" if the current mutex
actually has waiters, or we clear the flag if it doesn't.  See, it was OK that
we set that flag early, since now it is cleared.

3) Failed to grab ownership
---------------------------

The most interesting case is when we fail to take ownership. This means that
there exists an owner, or there's a pending owner with equal or higher
priority than the current task.

We'll continue on the failed case.

If the mutex has a timeout, we set up a timer to go off to break us out of
this mutex if we failed to get it after a specified amount of time.

Now we enter a loop that will continue to try to take ownership of the mutex,
or fail from a timeout or signal.

Once again we try to take the mutex.  This will usually fail the first time in
the loop, since it had just failed to get the mutex.  But the second time in
the loop, this would likely succeed, since the task would likely be the
pending owner.

If the mutex is TASK_INTERRUPTIBLE a check for signals and timeout is done
here.

The waiter structure has a "task" field that points to the task that is
blocked on the mutex.  This field can be NULL the first time it goes through
the loop or if the task is a pending owner and had its mutex stolen.  If the
"task" field is NULL then we need to set up the accounting for it.

Task blocks on mutex
--------------------

The accounting of a mutex and process is done with the waiter structure of the
process.  The "task" field is set to the process, and the "lock" field to the
mutex.  The plist nodes are initialized to the processes current priority.

Since the wait_lock was taken at the entry of the slow lock, we can safely add
the waiter to the wait_list.  If the current process is the highest priority
process currently waiting on this mutex, then we remove the previous top
waiter process (if it exists) from the pi_list of the owner, and add the
current process to that list.  Since the pi_list of the owner has changed, we
call rt_mutex_adjust_prio on the owner to see if the owner should adjust its
priority accordingly.

If the owner is also blocked on a lock, and had its pi_list changed (or
deadlock checking is on), we unlock the wait_lock of the mutex and go ahead
and run rt_mutex_adjust_prio_chain on the owner, as described earlier.

Now all locks are released, and if the current process is still blocked on a
mutex (waiter "task" field is not NULL), then we go to sleep (call schedule).

Waking up in the loop
---------------------

The schedule can then wake up for a few reasons.
1) we were given pending ownership of the mutex.
2) we received a signal and was TASK_INTERRUPTIBLE
3) we had a timeout and was TASK_INTERRUPTIBLE

In any of these cases, we continue the loop and once again try to grab the
ownership of the mutex.  If we succeed, we exit the loop, otherwise we
continue and on signal and timeout, will exit the loop, or if we had the mutex
stolen we just simply add ourselves back on the lists and go back to sleep.

Note: For various reasons, because of timeout and signals, the steal mutex
algorithm needs to be careful. This is because the current process is still on
the wait_list. And because of dynamic changing of priorities, especially on
SCHED_OTHER tasks, the current process can be the highest priority task on the
wait_list.

Failed to get mutex on Timeout or Signal
----------------------------------------

If a timeout or signal occurred, the waiter's "task" field would not be NULL
and the task needs to be taken off the wait_list of the mutex and perhaps
pi_list of the owner.  If this process was a high priority process, then the
rt_mutex_adjust_prio_chain needs to be executed again on the owner, but this
time it will be lowering the priorities.


Unlocking the Mutex
-------------------

The unlocking of a mutex also has a fast path for those architectures with
CMPXCHG.  Since the taking of a mutex on contention always sets the "Has
Waiters" flag of the mutex's owner, we use this to know if we need to take the
slow path when unlocking the mutex.  If the mutex doesn't have any waiters,
the owner field of the mutex would equal the current process and the mutex can
be unlocked by just replacing the owner field with NULL.

If the owner field has the "Has Waiters" bit set (or CMPXCHG is not
available), the slow unlock path is taken.

The first thing done in the slow unlock path is to take the wait_lock of the
mutex.  This synchronizes the locking and unlocking of the mutex.

A check is made to see if the mutex has waiters or not.  On architectures that
do not have CMPXCHG, this is the location that the owner of the mutex will
determine if a waiter needs to be awoken or not.  On architectures that do
have CMPXCHG, that check is done in the fast path, but it is still needed in
the slow path too.  If a waiter of a mutex woke up because of a signal or
timeout between the time the owner failed the fast path CMPXCHG check and the
grabbing of the wait_lock, the mutex may not have any waiters, thus the owner
still needs to make this check. If there are no waiters then the mutex owner
field is set to NULL, the wait_lock is released and nothing more is needed.

If there are waiters, then we need to wake one up and give that waiter pending
ownership.

On the wake up code, the pi_lock of the current owner is taken.  The top
waiter of the lock is found and removed from the wait_list of the mutex as
well as the pi_list of the current owner.  The task field of the new pending
owner's waiter structure is set to NULL, and the owner field of the mutex is
set to the new owner with the "Pending Owner" bit set, as well as the "Has
Waiters" bit if there still are other processes blocked on the mutex.

The pi_lock of the previous owner is released, and the new pending owner's
pi_lock is taken.  Remember that this is the trick to prevent the race
condition in rt_mutex_adjust_prio_chain from adding itself as a waiter on the
mutex.

We now clear the "pi_blocked_on" field of the new pending owner, and if the
mutex still has waiters pending, we add the new top waiter to the pi_list of
the pending owner.

Finally we unlock the pi_lock of the pending owner and wake it up.

[23] robust-futexes.txt

Background
----------

what are robust futexes? To answer that, we first need to understand what
futexes are: normal futexes are special types of locks that in the
noncontended case can be acquired/released from userspace without having to
enter the kernel.

A futex is in essence a user-space address, e.g. a 32-bit lock variable field.
If userspace notices contention (the lock is already owned and someone else
wants to grab it too) then the lock is marked with a value that says "there's
a waiter pending", and the sys_futex(FUTEX_WAIT) syscall is used to wait for
the other guy to release it. The kernel creates a 'futex queue' internally, so
that it can later on match up the waiter with the waker - without them having
to know about each other.  When the owner thread releases the futex, it
notices (via the variable value) that there were waiter(s) pending, and does
the sys_futex(FUTEX_WAKE) syscall to wake them up.  Once all waiters have
taken and released the lock, the futex is again back to 'uncontended' state,
and there's no in-kernel state associated with it.  The kernel completely
forgets that there ever was a futex at that address.  This method makes
futexes very lightweight and scalable.

"Robustness" is about dealing with crashes while holding a lock: if a process
exits prematurely while holding a pthread_mutex_t lock that is also shared
with some other process (e.g. yum segfaults while holding a pthread_mutex_t,
or yum is kill -9-ed), then waiters for that lock need to be notified that the
last owner of the lock exited in some irregular way.

To solve such types of problems, "robust mutex" userspace APIs were created:
pthread_mutex_lock() returns an error value if the owner exits prematurely -
and the new owner can decide whether the data protected by the lock can be
recovered safely.

There is a big conceptual problem with futex based mutexes though: it is the
kernel that destroys the owner task (e.g. due to a SEGFAULT), but the kernel
cannot help with the cleanup: if there is no 'futex queue' (and in most cases
there is none, futexes being fast lightweight locks) then the kernel has no
information to clean up after the held lock!  Userspace has no chance to clean
up after the lock either - userspace is the one that crashes, so it has no
opportunity to clean up. Catch-22.

In practice, when e.g. yum is kill -9-ed (or segfaults), a system reboot is
needed to release that futex based lock. This is one of the leading bugreports
against yum.

To solve this problem, the traditional approach was to extend the vma (virtual
memory area descriptor) concept to have a notion of 'pending robust futexes
attached to this area'. This approach requires 3 new syscall variants to
sys_futex(): FUTEX_REGISTER, FUTEX_DEREGISTER and FUTEX_RECOVER. At do_exit()
time, all vmas are searched to see whether they have a robust_head set. This
approach has two fundamental problems left:

- it has quite complex locking and race scenarios. The vma-based approach had
been pending for years, but they are still not completely reliable.

- they have to scan _every_ vma at sys_exit() time, per thread!

The second disadvantage is a real killer: pthread_exit() takes around 1
microsecond on Linux, but with thousands (or tens of thousands) of vmas every
pthread_exit() takes a millisecond or more, also totally destroying the CPU's
L1 and L2 caches!

This is very much noticeable even for normal process sys_exit_group() calls:
the kernel has to do the vma scanning unconditionally! (this is because the
kernel has no knowledge about how many robust futexes there are to be cleaned
up, because a robust futex might have been registered in another task, and the
futex variable might have been simply mmap()-ed into this process's address
space).  

This huge overhead forced the creation of CONFIG_FUTEX_ROBUST so that normal
kernels can turn it off, but worse than that: the overhead makes robust
futexes impractical for any type of generic Linux distribution.

So something had to be done.

New approach to robust futexes
------------------------------

At the heart of this new approach there is a per-thread private list of robust
locks that userspace is holding (maintained by glibc) - which userspace list
is registered with the kernel via a new syscall [this registration happens at
most once per thread lifetime]. At do_exit() time, the kernel checks this
user-space list: are there any robust futex locks to be cleaned up?

In the common case, at do_exit() time, there is no list registered, so the
cost of robust futexes is just a simple current->robust_list != NULL
comparison. If the thread has registered a list, then normally the list is
empty. If the thread/process crashed or terminated in some incorrect way then
the list might be non-empty: in this case the kernel carefully walks the list
[not trusting it], and marks all locks that are owned by this thread with the
FUTEX_OWNER_DIED bit, and wakes up one waiter (if any).

The list is guaranteed to be private and per-thread at do_exit() time, so it
can be accessed by the kernel in a lockless way.

There is one race possible though: since adding to and removing from the list
is done after the futex is acquired by glibc, there is a few instructions
window for the thread (or process) to die there, leaving the futex hung. To
protect against this possibility, userspace (glibc) also maintains a simple
per-thread 'list_op_pending' field, to allow the kernel to clean up if the
thread dies after acquiring the lock, but just before it could have added
itself to the list. Glibc sets this list_op_pending field before it tries to
acquire the futex, and clears it after the list-add (or list-remove) has
finished.

That's all that is needed - all the rest of robust-futex cleanup is done in
userspace [just like with the previous patches].

Ulrich Drepper has implemented the necessary glibc support for this new
mechanism, which fully enables robust mutexes.

Key differences of this userspace-list based approach, compared to the vma
based method:

- it's much, much faster: at thread exit time, there's no need to loop over
every vma (!), which the VM-based method has to do. Only a very simple 'is the
list empty' op is done.

- no VM changes are needed - 'struct address_space' is left alone.

- no registration of individual locks is needed: robust mutexes dont need any
extra per-lock syscalls. Robust mutexes thus become a very lightweight
primitive - so they dont force the application designer to do a hard choice
between performance and robustness - robust mutexes are just as fast.

- no per-lock kernel allocation happens.

- no resource limits are needed.

- no kernel-space recovery call (FUTEX_RECOVER) is needed.

- the implementation and the locking is "obvious", and there are no
interactions with the VM.

Performance
-----------

I have benchmarked the time needed for the kernel to process a list of 1
million (!) held locks, using the new method [on a 2GHz CPU]:

- with FUTEX_WAIT set [contended mutex]: 130 msecs
- without FUTEX_WAIT set [uncontended mutex]: 30 msecs

I have also measured an approach where glibc does the lock notification [which
it currently does for !pshared robust mutexes], and that took 256 msecs -
clearly slower, due to the 1 million FUTEX_WAKE syscalls userspace had to do.

(1 million held locks are unheard of - we expect at most a handful of locks to
be held at a time. Nevertheless it's nice to know that this approach scales
nicely.)

Implementation details
----------------------

The patch adds two new syscalls: one to register the userspace list, and one
to query the registered list pointer:

asmlinkage long
sys_set_robust_list(struct robust_list_head __user *head,
size_t len);

asmlinkage long
sys_get_robust_list(int pid, struct robust_list_head __user **head_ptr,
size_t __user *len_ptr);

List registration is very fast: the pointer is simply stored in
current->robust_list. [Note that in the future, if robust futexes become
widespread, we could extend sys_clone() to register a robust-list head for new
threads, without the need of another syscall.]

So there is virtually zero overhead for tasks not using robust futexes, and
even for robust futex users, there is only one extra syscall per thread
lifetime, and the cleanup operation, if it happens, is fast and
straightforward. The kernel doesn't have any internal distinction between
robust and normal futexes.

If a futex is found to be held at exit time, the kernel sets the following bit
of the futex word:

#define FUTEX_OWNER_DIED        0x40000000

and wakes up the next futex waiter (if any). User-space does the rest of the
cleanup.

Otherwise, robust futexes are acquired by glibc by putting the TID into the
futex field atomically. Waiters set the FUTEX_WAITERS bit:

#define FUTEX_WAITERS           0x80000000

and the remaining bits are for the TID.

Testing, architecture support
-----------------------------

i've tested the new syscalls on x86 and x86_64, and have made sure the parsing
of the userspace list is robust [ ;-) ] even if the list is deliberately
corrupted.

i386 and x86_64 syscalls are wired up at the moment, and Ulrich has tested the
new glibc code (on x86_64 and i386), and it works for his robust-mutex
testcases.

All other architectures should build just fine too - but they wont have the
new syscalls yet.

Architectures need to implement the new futex_atomic_cmpxchg_inatomic() inline
function before writing up the syscalls (that function returns -ENOSYS right
        now).

[24] robust-futex-ABI.txt

The robust futex ABI
robust futex
--------------------

Robust_futexes provide a mechanism that is used in addition to normal futexes,
for kernel assist of cleanup of held locks on task exit.

robust futex除了提供futex的功能之外，它还提供了一种机制，在任务结束时用于辅助
内核对任务持有的锁进行清理。

The interesting data as to what futexes a thread is holding is kept on a
linked list in user space, where it can be updated efficiently as locks are
taken and dropped, without kernel intervention.  The only additional kernel
intervention required for robust_futexes above and beyond what is required for
futexes is:

我们关心的数据是线程持有的futexes，这些树需被保存在用户空间的一个链表中，当被
加锁或者锁被释放时，这个链表中的数据可以被高效地更新，这一过程不许要内核的干预
。针对我们上面提到的robust_futexes，内核对它的唯一干预以及它相对于futexes添加
的功能包括：

1) a one time call, per thread, to tell the kernel where its list of held
robust_futexes begins, and
2) internal kernel code at exit, to handle any listed locks held by the
exiting thread.

The existing normal futexes already provide a "Fast Userspace Locking"
mechanism, which handles uncontested locking without needing a system call,
and handles contested locking by maintaining a list of waiting threads in
the kernel.  Options on the sys_futex(2) system call support waiting on a
particular futex, and waking up the next waiter on a particular futex.

For robust_futexes to work, the user code (typically in a library such as
glibc linked with the application) has to manage and place the necessary list
elements exactly as the kernel expects them.  If it fails to do so, then
improperly listed locks will not be cleaned up on exit, probably causing
deadlock or other such failure of the other threads waiting on the same locks.

A thread that anticipates possibly using robust_futexes should first issue the
system call:

asmlinkage long
sys_set_robust_list(struct robust_list_head __user *head, size_t len);

The pointer 'head' points to a structure in the threads address space
consisting of three words.  Each word is 32 bits on 32 bit arch's, or 64 bits
on 64 bit arch's, and local byte order.  Each thread should have its own
thread private 'head'.

If a thread is running in 32 bit compatibility mode on a 64 native arch
kernel, then it can actually have two such structures - one using 32 bit words
for 32 bit compatibility mode, and one using 64 bit words for 64 bit native
mode.  The kernel, if it is a 64 bit kernel supporting 32 bit compatibility
mode, will attempt to process both lists on each task exit, if the
corresponding sys_set_robust_list() call has been made to setup that list.

The first word in the memory structure at 'head' contains a pointer to a
single linked list of 'lock entries', one per lock, as described below.  If
the list is empty, the pointer will point to itself, 'head'.  The last 'lock
entry' points back to the 'head'.

The second word, called 'offset', specifies the offset from the address of the
associated 'lock entry', plus or minus, of what will be called the 'lock
word', from that 'lock entry'.  The 'lock word' is always a 32 bit word,
unlike the other words above.  The 'lock word' holds 3 flag bits in the
upper 3 bits, and the thread id (TID) of the thread holding the lock in
the bottom 29 bits.  See further below for a description of the flag bits.

The third word, called 'list_op_pending', contains transient copy of the
address of the 'lock entry', during list insertion and removal, and is needed
to correctly resolve races should a thread exit while in the middle of a
locking or unlocking operation.

Each 'lock entry' on the single linked list starting at 'head' consists of
just a single word, pointing to the next 'lock entry', or back to 'head' if
there are no more entries.  In addition, nearby to each 'lock entry', at an
offset from the 'lock entry' specified by the 'offset' word, is one 'lock
word'.

The 'lock word' is always 32 bits, and is intended to be the same 32 bit lock
variable used by the futex mechanism, in conjunction with robust_futexes.  The
kernel will only be able to wakeup the next thread waiting for a lock on a
threads exit if that next thread used the futex mechanism to register the
address of that 'lock word' with the kernel.

For each futex lock currently held by a thread, if it wants this robust_futex
support for exit cleanup of that lock, it should have one 'lock entry' on this
list, with its associated 'lock word' at the specified 'offset'.  Should a
thread die while holding any such locks, the kernel will walk this list, mark
any such locks with a bit indicating their holder died, and wakeup the next
thread waiting for that lock using the futex mechanism.

When a thread has invoked the above system call to indicate it anticipates
using robust_futexes, the kernel stores the passed in 'head' pointer for that
task.  The task may retrieve that value later on by using the system call:

asmlinkage long
sys_get_robust_list(int pid, struct robust_list_head __user **head_ptr,
size_t __user *len_ptr);

It is anticipated that threads will use robust_futexes embedded in larger,
user level locking structures, one per lock.  The kernel robust_futex
mechanism doesn't care what else is in that structure, so long as the 'offset'
to the 'lock word' is the same for all robust_futexes used by that thread.
The thread should link those locks it currently holds using the 'lock entry'
pointers.  It may also have other links between the locks, such as the reverse
side of a double linked list, but that doesn't matter to the kernel.

By keeping its locks linked this way, on a list starting with a 'head' pointer
known to the kernel, the kernel can provide to a thread the essential service
available for robust_futexes, which is to help clean up locks held at the time
of (a perhaps unexpectedly) exit.

Actual locking and unlocking, during normal operations, is handled entirely by
user level code in the contending threads, and by the existing futex mechanism
to wait for, and wakeup, locks.  The kernels only essential involvement in
robust_futexes is to remember where the list 'head' is, and to walk the list
on thread exit, handling locks still held by the departing thread, as
described below.

There may exist thousands of futex lock structures in a threads shared memory,
on various data structures, at a given point in time. Only those lock
structures for locks currently held by that thread should be on that thread's
robust_futex linked lock list a given time.

A given futex lock structure in a user shared memory region may be held at
different times by any of the threads with access to that region. The thread
currently holding such a lock, if any, is marked with the threads TID in the
lower 29 bits of the 'lock word'.

When adding or removing a lock from its list of held locks, in order for the
kernel to correctly handle lock cleanup regardless of when the task exits
(perhaps it gets an unexpected signal 9 in the middle of manipulating this
 list), the user code must observe the following protocol on 'lock entry'
insertion and removal:

On insertion:
1) set the 'list_op_pending' word to the address of the 'lock entry' to be
inserted,
2) acquire the futex lock,
3) add the lock entry, with its thread id (TID) in the bottom 29 bits of the
'lock word', to the linked list starting at 'head', and
4) clear the 'list_op_pending' word.

On removal:
1) set the 'list_op_pending' word to the address of the 'lock entry' to be
removed,
2) remove the lock entry for this lock from the 'head' list,
2) release the futex lock, and
2) clear the 'lock_op_pending' word.

On exit, the kernel will consider the address stored in 'list_op_pending' and
the address of each 'lock word' found by walking the list starting at 'head'.
For each such address, if the bottom 29 bits of the 'lock word' at offset
'offset' from that address equals the exiting threads TID, then the kernel
will do two things:

1) if bit 31 (0x80000000) is set in that word, then attempt a futex wakeup on
that address, which will waken the next thread that has used to the futex
mechanism to wait on that address, and
2) atomically set  bit 30 (0x40000000) in the 'lock word'.

In the above, bit 31 was set by futex waiters on that lock to indicate they
were waiting, and bit 30 is set by the kernel to indicate that the lock owner
died holding the lock.

The kernel exit code will silently stop scanning the list further if at any
point:

1) the 'head' pointer or an subsequent linked list pointer is not a valid
address of a user space word
2) the calculated location of the 'lock word' (address plus 'offset') is not
the valid address of a 32 bit user space word
3) if the list contains more than 1 million (subject to future kernel
configuration changes) elements.

When the kernel sees a list entry whose 'lock word' doesn't have the current
threads TID in the lower 29 bits, it does nothing with that entry, and goes on
to the next entry.

Bit 29 (0x20000000) of the 'lock word' is reserved for future use.

=============================================================================
Sat Sep 20 00:25:48 CST 2014
=============================================================================

[25] rfkill.txt

rfkill - RF kill switch support

The rfkill subsystem provides a generic interface to disabling any radio
transmitter in the system. When a transmitter is blocked, it shall not
radiate any power.

The subsystem also provides the ability to react on button presses and
disable all transmitters of a certain type (or all). This is intended for
situations where transmitters need to be turned off, for example on
aircraft.

The rfkill subsystem has a concept of "hard" and "soft" block, which
differ little in their meaning (block == transmitters off) but rather in
whether they can be changed or not:
- hard block: read-only radio block that cannot be overriden by software
- soft block: writable radio block (need not be readable) that is set by
the system software.

[26] rbtree.txt

**What are red-black trees, and what are they for?**
------------------------------------------------

**Red-black trees are a type of self-balancing binary search tree, used for**
**storing sortable key/value data pairs.  This differs from radix trees (which**
**are used to efficiently store sparse arrays and thus use long integer indexes**
**to insert/access/delete nodes) and hash tables (which are not kept sorted to**
**be easily traversed in order, and must be tuned for a specific size and**
**hash function where rbtrees scale gracefully storing arbitrary keys).**

Red-black trees are similar to AVL trees, but provide faster real-time bounded
worst case performance for insertion and deletion (at most two rotations and
three rotations, respectively, to balance the tree), with slightly slower
(but still O(log n)) lookup time.

To quote Linux Weekly News:

There are a number of red-black trees in use in the kernel.
The deadline and CFQ I/O schedulers employ rbtrees to
track requests; the packet CD/DVD driver does the same.
The high-resolution timer code uses an rbtree to organize outstanding
timer requests.  The ext3 filesystem tracks directory entries in a
red-black tree.  Virtual memory areas (VMAs) are tracked with red-black
trees, as are epoll file descriptors, cryptographic keys, and network
packets in the "hierarchical token bucket" scheduler.

[27] ramoops.txt

Ramoops is an oops/panic logger that writes its logs to RAM before the system
crashes. It works by logging oopses and panics in a circular buffer. Ramoops
needs a system with persistent RAM so that the content of that area can
survive after a restart.

[28] prio_tree.txt

[29] printk-formats.txt

[30] preempt-locking.txt

[31] pnp.txt

Plug and Play provides a means of detecting and setting resources for legacy or
otherwise unconfigurable devices.  The Linux Plug and Play Layer provides these 
services to compatible drivers.

[32] pinctrl.txt

[33] pi-futex.txt

类似与rt-mutex的实现。

[34] parport.txt
[35] parport-lowlevel.txt

The `parport' code provides parallel-port support under Linux.  This includes
the ability to share one port between multiple device drivers.

[36] padata.txt

Padata is a mechanism by which the kernel can farm work out to be done in
parallel on multiple CPUs while retaining the ordering of tasks.  It was
developed for use with the IPsec code, which needs to be able to perform
encryption and decryption on large numbers of packets without reordering those
packets.  The crypto developers made a point of writing padata in a
sufficiently general fashion that it could be put to other uses as well.

[37] oops-tracing.txt

[38] 00-INDEX

This is a brief list of all the files in ./linux/Documentation and what they
contain. If you add a documentation file, please list it here in alphabetical
order as well, or risk being hunted down like a rabid dog.  Please try and
keep the descriptions small enough to fit on one line.

[39] Changes

This document is designed to provide a list of the minimum levels of software
necessary to run the 3.0 kernels.

=============================================================================
Sat Sep 20 10:03:48 CST 2014
=============================================================================

[40] CodingStyle.txt

                Linux kernel coding style

This is a short document describing the preferred coding style for the
linux kernel.  Coding style is very personal, and I won't _force_ my
views on anybody, but this is what goes for anything that I have to be
able to maintain, and I'd prefer it for most other things too.  Please
at least consider the points made here.

First off, I'd suggest printing out a copy of the GNU coding standards,
and NOT read it.  Burn them, it's a great symbolic gesture.

Anyway, here goes:


                Chapter 1: Indentation

Tabs are 8 characters, and thus indentations are also 8 characters.
There are heretic movements that try to make indentations 4 (or even 2!)
characters deep, and that is akin to trying to define the value of PI to
be 3.

Rationale: The whole idea behind indentation is to clearly define where
a block of control starts and ends.  Especially when you've been looking
at your screen for 20 straight hours, you'll find it a lot easier to see
how the indentation works if you have large indentations.

Now, some people will claim that having 8-character indentations makes
the code move too far to the right, and makes it hard to read on a
80-character terminal screen.  The answer to that is that if you need
more than 3 levels of indentation, you're screwed anyway, and should fix
your program.

In short, 8-char indents make things easier to read, and have the added
benefit of warning you when you're nesting your functions too deep.
Heed that warning.

The preferred way to ease multiple indentation levels in a switch statement is
to align the "switch" and its subordinate "case" labels in the same column
instead of "double-indenting" the "case" labels.  E.g.:

        switch (suffix) {
        case 'G':
        case 'g':
                mem <<= 30;
                break;
        case 'M':
        case 'm':
                mem <<= 20;
                break;
        case 'K':
        case 'k':
                mem <<= 10;
                /* fall through */
        default:
                break;
        }


Don't put multiple statements on a single line unless you have
something to hide:

        if (condition) do_this;
          do_something_everytime;

Don't put multiple assignments on a single line either.  Kernel coding style
is super simple.  Avoid tricky expressions.

Outside of comments, documentation and except in Kconfig, spaces are never
used for indentation, and the above example is deliberately broken.

Get a decent editor and don't leave whitespace at the end of lines.


                Chapter 2: Breaking long lines and strings

Coding style is all about readability and maintainability using commonly
available tools.

The limit on the length of lines is 80 columns and this is a strongly
preferred limit.

Statements longer than 80 columns will be broken into sensible chunks, unless
exceeding 80 columns significantly increases readability and does not hide
information. Descendants are always substantially shorter than the parent and
are placed substantially to the right. The same applies to function headers
with a long argument list. However, never break user-visible strings such as
printk messages, because that breaks the ability to grep for them.


                Chapter 3: Placing Braces and Spaces

The other issue that always comes up in C styling is the placement of
braces.  Unlike the indent size, there are few technical reasons to
choose one placement strategy over the other, but the preferred way, as
shown to us by the prophets Kernighan and Ritchie, is to put the opening
brace last on the line, and put the closing brace first, thusly:

        if (x is true) {
                we do y
        }

This applies to all non-function statement blocks (if, switch, for,
while, do).  E.g.:

        switch (action) {
        case KOBJ_ADD:
                return "add";
        case KOBJ_REMOVE:
                return "remove";
        case KOBJ_CHANGE:
                return "change";
        default:
                return NULL;
        }

However, there is one special case, namely functions: they have the
opening brace at the beginning of the next line, thus:

        int function(int x)
        {
                body of function
        }

Heretic people all over the world have claimed that this inconsistency
is ...  well ...  inconsistent, but all right-thinking people know that
(a) K&R are _right_ and (b) K&R are right.  Besides, functions are
special anyway (you can't nest them in C).

Note that the closing brace is empty on a line of its own, _except_ in
the cases where it is followed by a continuation of the same statement,
ie a "while" in a do-statement or an "else" in an if-statement, like
this:

        do {
                body of do-loop
        } while (condition);

and

        if (x == y) {
                ..
        } else if (x > y) {
                ...
        } else {
                ....
        }

Rationale: K&R.

Also, note that this brace-placement also minimizes the number of empty
(or almost empty) lines, without any loss of readability.  Thus, as the
supply of new-lines on your screen is not a renewable resource (think
25-line terminal screens here), you have more empty lines to put
comments on.

Do not unnecessarily use braces where a single statement will do.

if (condition)
        action();

and

if (condition)
        do_this();
else
        do_that();

This does not apply if only one branch of a conditional statement is a single
statement; in the latter case use braces in both branches:

if (condition) {
        do_this();
        do_that();
} else {
        otherwise();
}

                3.1:  Spaces

Linux kernel style for use of spaces depends (mostly) on
function-versus-keyword usage.  Use a space after (most) keywords.  The
notable exceptions are sizeof, typeof, alignof, and __attribute__, which look
somewhat like functions (and are usually used with parentheses in Linux,
although they are not required in the language, as in: "sizeof info" after
"struct fileinfo info;" is declared).

So use a space after these keywords:
        if, switch, case, for, do, while
but not with sizeof, typeof, alignof, or __attribute__.  E.g.,
        s = sizeof(struct file);

Do not add spaces around (inside) parenthesized expressions.  This example is
*bad*:

        s = sizeof( struct file );

When declaring pointer data or a function that returns a pointer type, the
preferred use of '*' is adjacent to the data name or function name and not
adjacent to the type name.  Examples:

        char *linux_banner;
        unsigned long long memparse(char *ptr, char **retptr);
        char *match_strdup(substring_t *s);

Use one space around (on each side of) most binary and ternary operators,
such as any of these:

        =  +  -  <  >  *  /  %  |  &  ^  <=  >=  ==  !=  ?  :

but no space after unary operators:
        &  *  +  -  ~  !  sizeof  typeof  alignof  __attribute__  defined

no space before the postfix increment & decrement unary operators:
        ++  --

no space after the prefix increment & decrement unary operators:
        ++  --

and no space around the '.' and "->" structure member operators.

Do not leave trailing whitespace at the ends of lines.  Some editors with
"smart" indentation will insert whitespace at the beginning of new lines as
appropriate, so you can start typing the next line of code right away.
However, some such editors do not remove the whitespace if you end up not
putting a line of code there, such as if you leave a blank line.  As a result,
you end up with lines containing trailing whitespace.

Git will warn you about patches that introduce trailing whitespace, and can
optionally strip the trailing whitespace for you; however, if applying a series
of patches, this may make later patches in the series fail by changing their
context lines.


                Chapter 4: Naming

C is a Spartan language, and so should your naming be.  Unlike Modula-2
and Pascal programmers, C programmers do not use cute names like
ThisVariableIsATemporaryCounter.  A C programmer would call that
variable "tmp", which is much easier to write, and not the least more
difficult to understand.

HOWEVER, while mixed-case names are frowned upon, descriptive names for
global variables are a must.  To call a global function "foo" is a
shooting offense.

GLOBAL variables (to be used only if you _really_ need them) need to
have descriptive names, as do global functions.  If you have a function
that counts the number of active users, you should call that
"count_active_users()" or similar, you should _not_ call it "cntusr()".

Encoding the type of a function into the name (so-called Hungarian
notation) is brain damaged - the compiler knows the types anyway and can
check those, and it only confuses the programmer.  No wonder MicroSoft
makes buggy programs.

LOCAL variable names should be short, and to the point.  If you have
some random integer loop counter, it should probably be called "i".
Calling it "loop_counter" is non-productive, if there is no chance of it
being mis-understood.  Similarly, "tmp" can be just about any type of
variable that is used to hold a temporary value.

If you are afraid to mix up your local variable names, you have another
problem, which is called the function-growth-hormone-imbalance syndrome.
See chapter 6 (Functions).


                Chapter 5: Typedefs

Please don't use things like "vps_t".

It's a _mistake_ to use typedef for structures and pointers. When you see a

        vps_t a;

in the source, what does it mean?

In contrast, if it says

        struct virtual_container *a;

you can actually tell what "a" is.

Lots of people think that typedefs "help readability". Not so. They are
useful only for:

 (a) totally opaque objects (where the typedef is actively used to _hide_
     what the object is).

     Example: "pte_t" etc. opaque objects that you can only access using
     the proper accessor functions.
    
     NOTE! Opaqueness and "accessor functions" are not good in themselves.
     The reason we have them for things like pte_t etc. is that there
     really is absolutely _zero_ portably accessible information there.

 (b) Clear integer types, where the abstraction _helps_ avoid confusion
     whether it is "int" or "long".

     u8/u16/u32 are perfectly fine typedefs, although they fit into
     category (d) better than here.
    
     NOTE! Again - there needs to be a _reason_ for this. If something is
     "unsigned long", then there's no reason to do
    
        typedef unsigned long myflags_t;
    
     but if there is a clear reason for why it under certain circumstances
     might be an "unsigned int" and under other configurations might be
     "unsigned long", then by all means go ahead and use a typedef.

 (c) when you use sparse to literally create a _new_ type for
     type-checking.

 (d) New types which are identical to standard C99 types, in certain
     exceptional circumstances.

     Although it would only take a short amount of time for the eyes and
     brain to become accustomed to the standard types like 'uint32_t',
     some people object to their use anyway.
    
     Therefore, the Linux-specific 'u8/u16/u32/u64' types and their
     signed equivalents which are identical to standard types are
     permitted -- although they are not mandatory in new code of your
     own.
    
     When editing existing code which already uses one or the other set
     of types, you should conform to the existing choices in that code.

 (e) Types safe for use in userspace.

     In certain structures which are visible to userspace, we cannot
     require C99 types and cannot use the 'u32' form above. Thus, we
     use __u32 and similar types in all structures which are shared
     with userspace.

Maybe there are other cases too, but the rule should basically be to NEVER
EVER use a typedef unless you can clearly match one of those rules.

In general, a pointer, or a struct that has elements that can reasonably
be directly accessed should _never_ be a typedef.


                Chapter 6: Functions

Functions should be short and sweet, and do just one thing.  They should
fit on one or two screenfuls of text (the ISO/ANSI screen size is 80x24,
as we all know), and do one thing and do that well.

The maximum length of a function is inversely proportional to the
complexity and indentation level of that function.  So, if you have a
conceptually simple function that is just one long (but simple)
case-statement, where you have to do lots of small things for a lot of
different cases, it's OK to have a longer function.

However, if you have a complex function, and you suspect that a
less-than-gifted first-year high-school student might not even
understand what the function is all about, you should adhere to the
maximum limits all the more closely.  Use helper functions with
descriptive names (you can ask the compiler to in-line them if you think
it's performance-critical, and it will probably do a better job of it
than you would have done).

Another measure of the function is the number of local variables.  They
shouldn't exceed 5-10, or you're doing something wrong.  Re-think the
function, and split it into smaller pieces.  A human brain can
generally easily keep track of about 7 different things, anything more
and it gets confused.  You know you're brilliant, but maybe you'd like
to understand what you did 2 weeks from now.

In source files, separate functions with one blank line.  If the function is
exported, the EXPORT* macro for it should follow immediately after the closing
function brace line.  E.g.:

int system_is_up(void)
{
        return system_state == SYSTEM_RUNNING;
}
EXPORT_SYMBOL(system_is_up);

In function prototypes, include parameter names with their data types.
Although this is not required by the C language, it is preferred in Linux
because it is a simple way to add valuable information for the reader.


                Chapter 7: Centralized exiting of functions

Albeit deprecated by some people, the equivalent of the goto statement is
used frequently by compilers in form of the unconditional jump instruction.

The goto statement comes in handy when a function exits from multiple
locations and some common work such as cleanup has to be done.

The rationale is:

- unconditional statements are easier to understand and follow
- nesting is reduced
- errors by not updating individual exit points when making
    modifications are prevented
- saves the compiler work to optimize redundant code away ;)

int fun(int a)
{
        int result = 0;
        char *buffer = kmalloc(SIZE);

        if (buffer == NULL)
                return -ENOMEM;
    
        if (condition1) {
                while (loop1) {
                        ...
                }
                result = 1;
                goto out;
        }
        ...
out:
        kfree(buffer);
        return result;
}

                Chapter 8: Commenting

Comments are good, but there is also a danger of over-commenting.  NEVER
try to explain HOW your code works in a comment: it's much better to
write the code so that the _working_ is obvious, and it's a waste of
time to explain badly written code.

Generally, you want your comments to tell WHAT your code does, not HOW.
Also, try to avoid putting comments inside a function body: if the
function is so complex that you need to separately comment parts of it,
you should probably go back to chapter 6 for a while.  You can make
small comments to note or warn about something particularly clever (or
ugly), but try to avoid excess.  Instead, put the comments at the head
of the function, telling people what it does, and possibly WHY it does
it.

When commenting the kernel API functions, please use the kernel-doc format.
See the files Documentation/kernel-doc-nano-HOWTO.txt and scripts/kernel-doc
for details.

Linux style for comments is the C89 "/* ... */" style.
Don't use C99-style "// ..." comments.

The preferred style for long (multi-line) comments is:

        /*
         * This is the preferred style for multi-line
         * comments in the Linux kernel source code.
         * Please use it consistently.
         *
         * Description:  A column of asterisks on the left side,
         * with beginning and ending almost-blank lines.
         */

It's also important to comment data, whether they are basic types or derived
types.  To this end, use just one data declaration per line (no commas for
multiple data declarations).  This leaves you room for a small comment on each
item, explaining its use.


                Chapter 9: You've made a mess of it

That's OK, we all do.  You've probably been told by your long-time Unix
user helper that "GNU emacs" automatically formats the C sources for
you, and you've noticed that yes, it does do that, but the defaults it
uses are less than desirable (in fact, they are worse than random
typing - an infinite number of monkeys typing into GNU emacs would never
make a good program).

So, you can either get rid of GNU emacs, or change it to use saner
values.  To do the latter, you can stick the following in your .emacs file:

(defun c-lineup-arglist-tabs-only (ignored)
  "Line up argument lists by tabs, not spaces"
  (let* ((anchor (c-langelem-pos c-syntactic-element))
         (column (c-langelem-2nd-pos c-syntactic-element))
         (offset (- (1+ column) anchor))
         (steps (floor offset c-basic-offset)))
    (* (max steps 1)
       c-basic-offset)))

(add-hook 'c-mode-common-hook
          (lambda ()
            ;; Add kernel style
            (c-add-style
             "linux-tabs-only"
             '("linux" (c-offsets-alist
                        (arglist-cont-nonempty
                         c-lineup-gcc-asm-reg
                         c-lineup-arglist-tabs-only))))))

(add-hook 'c-mode-hook
          (lambda ()
            (let ((filename (buffer-file-name)))
              ;; Enable kernel mode for the appropriate files
              (when (and filename
                         (string-match (expand-file-name "~/src/linux-trees")
                                       filename))
                (setq indent-tabs-mode t)
                (c-set-style "linux-tabs-only")))))

This will make emacs go better with the kernel coding style for C
files below ~/src/linux-trees.

But even if you fail in getting emacs to do sane formatting, not
everything is lost: use "indent".

Now, again, GNU indent has the same brain-dead settings that GNU emacs
has, which is why you need to give it a few command line options.
However, that's not too bad, because even the makers of GNU indent
recognize the authority of K&R (the GNU people aren't evil, they are
just severely misguided in this matter), so you just give indent the
options "-kr -i8" (stands for "K&R, 8 character indents"), or use
"scripts/Lindent", which indents in the latest style.

"indent" has a lot of options, and especially when it comes to comment
re-formatting you may want to take a look at the man page.  But
remember: "indent" is not a fix for bad programming.


                Chapter 10: Kconfig configuration files

For all of the Kconfig* configuration files throughout the source tree,
the indentation is somewhat different.  Lines under a "config" definition
are indented with one tab, while help text is indented an additional two
spaces.  Example:

config AUDIT
        bool "Auditing support"
        depends on NET
        help
          Enable auditing infrastructure that can be used with another
          kernel subsystem, such as SELinux (which requires this for
          logging of avc messages output).  Does not do system-call
          auditing without CONFIG_AUDITSYSCALL.

Features that might still be considered unstable should be defined as
dependent on "EXPERIMENTAL":

config SLUB
        depends on EXPERIMENTAL && !ARCH_USES_SLAB_PAGE_STRUCT
        bool "SLUB (Unqueued Allocator)"
        ...

while seriously dangerous features (such as write support for certain
filesystems) should advertise this prominently in their prompt string:

config ADFS_FS_RW
        bool "ADFS write support (DANGEROUS)"
        depends on ADFS_FS
        ...

For full documentation on the configuration files, see the file
Documentation/kbuild/kconfig-language.txt.


                Chapter 11: Data structures

Data structures that have visibility outside the single-threaded
environment they are created and destroyed in should always have
reference counts.  In the kernel, garbage collection doesn't exist (and
outside the kernel garbage collection is slow and inefficient), which
means that you absolutely _have_ to reference count all your uses.

Reference counting means that you can avoid locking, and allows multiple
users to have access to the data structure in parallel - and not having
to worry about the structure suddenly going away from under them just
because they slept or did something else for a while.

Note that locking is _not_ a replacement for reference counting.
Locking is used to keep data structures coherent, while reference
counting is a memory management technique.  Usually both are needed, and
they are not to be confused with each other.

Many data structures can indeed have two levels of reference counting,
when there are users of different "classes".  The subclass count counts
the number of subclass users, and decrements the global count just once
when the subclass count goes to zero.

Examples of this kind of "multi-level-reference-counting" can be found in
memory management ("struct mm_struct": mm_users and mm_count), and in
filesystem code ("struct super_block": s_count and s_active).

Remember: if another thread can find your data structure, and you don't
have a reference count on it, you almost certainly have a bug.


                Chapter 12: Macros, Enums and RTL

Names of macros defining constants and labels in enums are capitalized.

#define CONSTANT 0x12345

Enums are preferred when defining several related constants.

CAPITALIZED macro names are appreciated but macros resembling functions
may be named in lower case.

Generally, inline functions are preferable to macros resembling functions.

Macros with multiple statements should be enclosed in a do - while block:

#define macrofun(a, b, c)                       \
        do {                                    \
                if (a == 5)                     \
                        do_this(b, c);          \
        } while (0)

Things to avoid when using macros:

1) macros that affect control flow:

#define FOO(x)                                  \
        do {                                    \
                if (blah(x) < 0)                \
                        return -EBUGGERED;      \
        } while(0)

is a _very_ bad idea.  It looks like a function call but exits the "calling"
function; don't break the internal parsers of those who will read the code.

2) macros that depend on having a local variable with a magic name:

#define FOO(val) bar(index, val)

might look like a good thing, but it's confusing as hell when one reads the
code and it's prone to breakage from seemingly innocent changes.

3) macros with arguments that are used as l-values: FOO(x) = y; will
bite you if somebody e.g. turns FOO into an inline function.

4) forgetting about precedence: macros defining constants using expressions
must enclose the expression in parentheses. Beware of similar issues with
macros using parameters.

#define CONSTANT 0x4000
#define CONSTEXP (CONSTANT | 3)

The cpp manual deals with macros exhaustively. The gcc internals manual also
covers RTL which is used frequently with assembly language in the kernel.


                Chapter 13: Printing kernel messages

Kernel developers like to be seen as literate. Do mind the spelling
of kernel messages to make a good impression. Do not use crippled
words like "dont"; use "do not" or "don't" instead.  Make the messages
concise, clear, and unambiguous.

Kernel messages do not have to be terminated with a period.

Printing numbers in parentheses (%d) adds no value and should be avoided.

There are a number of driver model diagnostic macros in <linux/device.h>
which you should use to make sure messages are matched to the right device
and driver, and are tagged with the right level:  dev_err(), dev_warn(),
dev_info(), and so forth.  For messages that aren't associated with a
particular device, <linux/printk.h> defines pr_debug() and pr_info().

Coming up with good debugging messages can be quite a challenge; and once
you have them, they can be a huge help for remote troubleshooting.  Such
messages should be compiled out when the DEBUG symbol is not defined (that
is, by default they are not included).  When you use dev_dbg() or pr_debug(),
that's automatic.  Many subsystems have Kconfig options to turn on -DDEBUG.
A related convention uses VERBOSE_DEBUG to add dev_vdbg() messages to the
ones already enabled by DEBUG.


                Chapter 14: Allocating memory

The kernel provides the following general purpose memory allocators:
kmalloc(), kzalloc(), kcalloc(), vmalloc(), and vzalloc().  Please refer to
the API documentation for further information about them.

The preferred form for passing a size of a struct is the following:

        p = kmalloc(sizeof(*p), ...);

The alternative form where struct name is spelled out hurts readability and
introduces an opportunity for a bug when the pointer variable type is changed
but the corresponding sizeof that is passed to a memory allocator is not.

Casting the return value which is a void pointer is redundant. The conversion
from void pointer to any other pointer type is guaranteed by the C programming
language.


                Chapter 15: The inline disease

There appears to be a common misperception that gcc has a magic "make me
faster" speedup option called "inline". While the use of inlines can be
appropriate (for example as a means of replacing macros, see Chapter 12), it
very often is not. Abundant use of the inline keyword leads to a much bigger
kernel, which in turn slows the system as a whole down, due to a bigger
icache footprint for the CPU and simply because there is less memory
available for the pagecache. Just think about it; a pagecache miss causes a
disk seek, which easily takes 5 milliseconds. There are a LOT of cpu cycles
that can go into these 5 milliseconds.

A reasonable rule of thumb is to not put inline at functions that have more
than 3 lines of code in them. An exception to this rule are the cases where
a parameter is known to be a compiletime constant, and as a result of this
constantness you *know* the compiler will be able to optimize most of your
function away at compile time. For a good example of this later case, see
the kmalloc() inline function.

Often people argue that adding inline to functions that are static and used
only once is always a win since there is no space tradeoff. While this is
technically correct, gcc is capable of inlining these automatically without
help, and the maintenance issue of removing the inline when a second user
appears outweighs the potential value of the hint that tells gcc to do
something it would have done anyway.


                Chapter 16: Function return values and names

Functions can return values of many different kinds, and one of the
most common is a value indicating whether the function succeeded or
failed.  Such a value can be represented as an error-code integer
(-Exxx = failure, 0 = success) or a "succeeded" boolean (0 = failure,
non-zero = success).

Mixing up these two sorts of representations is a fertile source of
difficult-to-find bugs.  If the C language included a strong distinction
between integers and booleans then the compiler would find these mistakes
for us... but it doesn't.  To help prevent such bugs, always follow this
convention:

        If the name of a function is an action or an imperative command,
        the function should return an error-code integer.  If the name
        is a predicate, the function should return a "succeeded" boolean.

For example, "add work" is a command, and the add_work() function returns 0
for success or -EBUSY for failure.  In the same way, "PCI device present" is
a predicate, and the pci_dev_present() function returns 1 if it succeeds in
finding a matching device or 0 if it doesn't.

All EXPORTed functions must respect this convention, and so should all
public functions.  Private (static) functions need not, but it is
recommended that they do.

Functions whose return value is the actual result of a computation, rather
than an indication of whether the computation succeeded, are not subject to
this rule.  Generally they indicate failure by returning some out-of-range
result.  Typical examples would be functions that return pointers; they use
NULL or the ERR_PTR mechanism to report failure.


                Chapter 17:  Don't re-invent the kernel macros

The header file include/linux/kernel.h contains a number of macros that
you should use, rather than explicitly coding some variant of them yourself.
For example, if you need to calculate the length of an array, take advantage
of the macro

  #define ARRAY_SIZE(x) (sizeof(x) / sizeof((x)[0]))

Similarly, if you need to calculate the size of some structure member, use

  #define FIELD_SIZEOF(t, f) (sizeof(((t*)0)->f))

There are also min() and max() macros that do strict type checking if you
need them.  Feel free to peruse that header file to see what else is already
defined that you shouldn't reproduce in your code.


                Chapter 18:  Editor modelines and other cruft

Some editors can interpret configuration information embedded in source files,
indicated with special markers.  For example, emacs interprets lines marked
like this:

-*- mode: c -*-

Or like this:

/*
Local Variables:
compile-command: "gcc -DMAGIC_DEBUG_FLAG foo.c"
End:
*/

Vim interprets markers that look like this:

Do not include any of these in source files.  People have their own personal
editor configurations, and your source files should not override them.  This
includes markers for indentation and mode configuration.  People may use their
own custom mode, or may have some other magic method for making indentation
work correctly.

[41] BUG-HUNTING.txt

这篇文档讲述了如何定位内核中的bug，常用的方式包括通过git-bisect进行搜索，以及
通过常规的旧有方式进行搜索定位，下面对其进行简要描述。

Finding using git-bisect
------------------------

Using the provided tools with git makes finding bugs easy provided the bug is
reproducible.

Steps to do it:
- start using git for the kernel source
- read the man page for git-bisect
- have fun

Finding it the old way
----------------------

[Sat Mar  2 10:32:33 PST 1996 KERNEL_BUG-HOWTO lm@sgi.com (Larry McVoy)]

This is how to track down a bug if you know nothing about kernel hacking.
It's a brute force approach but it works pretty well.

You need:

        . A reproducible bug - it has to happen predictably (sorry)
        . All the kernel tar files from a revision that worked to the
          revision that doesn't

You will then do:

        . Rebuild a revision that you believe works, install, and verify that.
        . Do a binary search over the kernels to figure out which one
          introduced the bug.  I.e., suppose 1.3.28 didn't have the bug, but
          you know that 1.3.69 does.  Pick a kernel in the middle and build
          that, like 1.3.50.  Build & test; if it works, pick the mid point
          between .50 and .69, else the mid point between .28 and .50.
        . You'll narrow it down to the kernel that introduced the bug.  You
          can probably do better than this but it gets tricky.
    
        . Narrow it down to a subdirectory
    
          - Copy kernel that works into "test".  Let's say that 3.62 works,
            but 3.63 doesn't.  So you diff -r those two kernels and come
            up with a list of directories that changed.  For each of those
            directories:
    
                Copy the non-working directory next to the working directory
                as "dir.63".
                One directory at time, try moving the working directory to
                "dir.62" and mv dir.63 dir"time, try
    
                        mv dir dir.62
                        mv dir.63 dir
                        find dir -name '*.[oa]' -print | xargs rm -f
    
                And then rebuild and retest.  Assuming that all related
                changes were contained in the sub directory, this should
                isolate the change to a directory.
    
                Problems: changes in header files may have occurred; I've
                found in my case that they were self explanatory - you may
                or may not want to give up when that happens.
    
        . Narrow it down to a file
    
          - You can apply the same technique to each file in the directory,
            hoping that the changes in that file are self contained.
    
        . Narrow it down to a routine
    
          - You can take the old file and the new file and manually create
            a merged file that has
    
                #ifdef VER62
                routine()
                {
                        ...
                }
                #else
                routine()
                {
                        ...
                }
                #endif
    
            And then walk through that file, one routine at a time and
            prefix it with
    
                #define VER62
                /* both routines here */
                #undef VER62
    
            Then recompile, retest, move the ifdefs until you find the one
            that makes the difference.

Finally, you take all the info that you have, kernel revisions, bug
description, the extent to which you have narrowed it down, and pass
that off to whomever you believe is the maintainer of that section.
A post to linux.dev.kernel isn't such a bad idea if you've done some
work to narrow it down.

If you get it down to a routine, you'll probably get a fix in 24 hours.

My apologies to Linus and the other kernel hackers for describing this
brute force approach, it's hardly what a kernel hacker would do.  However,
it does work and it lets non-hackers help fix bugs.  And it is cool
because Linux snapshots will let you do this - something that you can't
do with vendor supplied releases.

还讲述了如何修复内核bug的方式。

Fixing the bug
==============

Nobody is going to tell you how to fix bugs. Seriously. You need to work it
out. But below are some hints on how to use the tools.

To debug a kernel, use objdump and look for the hex offset from the crash
output to find the valid line of code/assembler. Without debug symbols, you
will see the assembler code for the routine shown, but if your kernel has
debug symbols the C code will also be available. (Debug symbols can be enabled
in the kernel hacking menu of the menu configuration.) For example:

    objdump -r -S -l --disassemble net/dccp/ipv4.o

NB.: you need to be at the top level of the kernel tree for this to pick up
your C files.

If you don't have access to the code you can also debug on some crash dumps
e.g. crash dump output as shown by Dave Miller.

>    EIP is at ip_queue_xmit+0x14/0x4c0
>     ...
>    Code: 44 24 04 e8 6f 05 00 00 e9 e8 fe ff ff 8d 76 00 8d bc 27 00 00
>    00 00 55 57  56 53 81 ec bc 00 00 00 8b ac 24 d0 00 00 00 8b 5d 08
>    <8b> 83 3c 01 00 00 89 44  24 14 8b 45 28 85 c0 89 44 24 18 0f 85
>
>    Put the bytes into a "foo.s" file like this:
>
>           .text
>           .globl foo
>    foo:
>           .byte  .... /* bytes from Code: part of OOPS dump */
>
>    Compile it with "gcc -c -o foo.o foo.s" then look at the output of
>    "objdump --disassemble foo.o".
>
>    Output:
>
>    ip_queue_xmit:
>        push       %ebp
>        push       %edi
>        push       %esi
>        push       %ebx
>        sub        $0xbc, %esp
>        mov        0xd0(%esp), %ebp        ! %ebp = arg0 (skb)
>        mov        0x8(%ebp), %ebx         ! %ebx = skb->sk
>        mov        0x13c(%ebx), %eax       ! %eax = inet_sk(sk)->opt

In addition, you can use GDB to figure out the exact file and line
number of the OOPS from the vmlinux file. If you have
CONFIG_DEBUG_INFO enabled, you can simply copy the EIP value from the
OOPS:

 EIP:    0060:[<c021e50e>]    Not tainted VLI

And use GDB to translate that to human-readable form:

  gdb vmlinux
  (gdb) l *0xc021e50e

If you don't have CONFIG_DEBUG_INFO enabled, you use the function
offset from the OOPS:

 EIP is at vt_ioctl+0xda8/0x1482

And recompile the kernel with CONFIG_DEBUG_INFO enabled:

  make vmlinux
  gdb vmlinux
  (gdb) p vt_ioctl
  (gdb) l *(0x<address of vt_ioctl> + 0xda8)
or, as one command
  (gdb) l *(vt_ioctl + 0xda8)

If you have a call trace, such as :-
>Call Trace:
> [<ffffffff8802c8e9>] :jbd:log_wait_commit+0xa3/0xf5
> [<ffffffff810482d9>] autoremove_wake_function+0x0/0x2e
> [<ffffffff8802770b>] :jbd:journal_stop+0x1be/0x1ee
> ...
this shows the problem in the :jbd: module. You can load that module in gdb
and list the relevant code.
  gdb fs/jbd/jbd.ko
  (gdb) p log_wait_commit
  (gdb) l *(0x<address> + 0xa3)
or
  (gdb) l *(log_wait_commit + 0xa3)


Another very useful option of the Kernel Hacking section in menuconfig is
Debug memory allocations. This will help you see whether data has been
initialised and not set before use etc. To see the values that get assigned
with this look at mm/slab.c and search for POISON_INUSE. When using this an
Oops will often show the poisoned data instead of zero which is the default.

Once you have worked out a fix please submit it upstream. After all open
source is about sharing what you do and don't you want to be recognised for
your genius?

Please do read Documentation/SubmittingPatches though to help your code get
accepted.

[42] DMA-API-HOWTO.txt

This is a guide to device driver writers on how to use the DMA API with
example pseudo-code.  For a concise description of the API, see DMA-API.txt.

[43] DMA-API.txt

This document describes the DMA API.  For a more gentle introduction of the
API (and actual examples) see Documentation/DMA-API-HOWTO.txt.

[44] DMA-ISA-LPC.txt

This document describes how to do DMA transfers using the old ISA DMA
controller. Even though ISA is more or less dead today the LPC bus uses the
same DMA system so it will be around for quite some time.

[45] DMA-attributes.txt

This document describes the semantics of the DMA attributes that are defined
in linux/dma-attrs.h.

[46] HOWTO.txt

This is the be-all, end-all document on this topic.  It contains instructions
on how to become a Linux kernel developer and how to learn to work with the
Linux kernel development community.  It tries to not contain anything related
to the technical aspects of kernel programming, but will help point you in the
right direction for that.

[47] IPMI.txt

The Intelligent Platform Management Interface, or IPMI, is a standard for
controlling intelligent devices that monitor a system.  It provides for
dynamic discovery of sensors in the system and the ability to monitor the
sensors and be informed when the sensor's values change or go outside certain
boundaries.  It also has a standardized database for field-replaceable units
(FRUs) and a watchdog timer.

To use this, you need an interface to an IPMI controller in your system
(called a Baseboard Management Controller, or BMC) and management software
that can use the IPMI system.

This document describes how to use the IPMI driver for Linux.  If you are not
familiar with IPMI itself, see the web site at:
http://www.intel.com/design/servers/ipmi/index.htm.  
IPMI is a big subject and I can't cover it all here!

**[48] IRQ-affinity.txt**

**SMP IRQ affinity，指的是**

**对称多处理器中的中断请求绑定。**

/proc/irq/IRQ#/smp_affinity and /proc/irq/IRQ#/smp_affinity_list specify which
target CPUs are permitted for a given IRQ source.  It's a bitmask
(smp_affinity) or cpu list (smp_affinity_list) of allowed CPUs.  It's not
allowed to turn off all CPUs, and if an IRQ controller does not support IRQ
affinity then the value will not change from the default of all cpus.

/proc/irq/IRQ#/smp_affinity和/proc/irq/IRQ#/smp_affinity_list指明了允许接收某
个中断请求IRQ#的多个或某个cpu。它是一个位掩码smp_affinity或者一个cpu列表
smp_affinity_list，其中记录了允许接受该中断请求的cpu。不允许禁止所有cpu接收该
中断请求，如果一个中断控制器不支持中断请求绑定，那么只能采用默认值，即允许所有
cpu接收该中断请求，并且这个值不会被修改。

/proc/irq/default_smp_affinity specifies default affinity mask that applies to
all non-active IRQs. Once IRQ is allocated/activated its affinity bitmask will
be set to the default mask. It can then be changed as described above.
Default mask is 0xffffffff.

/proc/irq/default_smp_affinity指明了默认的中断绑定掩码，这个默认值将应用于所有
的非活动的、未激活的中断号。一旦一个中断号被分配、激活，那么它的中断绑定掩码将
被设置为这个默认值。这个默认值可以通过前面提到过的方法进行修改。这个默认掩码的
值为0xffffffff，请注意，该掩码是32位的。

Here is an example of restricting IRQ44 (eth1) to CPU0-3 then restricting
it to CPU4-7 (this is an 8-CPU SMP box):

网卡向cpu发中断请求44，下面我们对这个中断请求与cpu的绑定关系进行设置，并通过
ping命令进行测试，网卡会将接收到的icmp请求，以中断44的形式发送到绑定的cpu，通
过查看cpu接收到的中断请求数量，我们可以判断，这个44这个中断请求与cpu的绑定关系
。

[root@moon 44]# cd /proc/irq/44
[root@moon 44]# cat smp_affinity
ffffffff
首先，查看到44这个中断请求的默认绑定掩码为0xffffffff，说明，所有的cpu都可以接
收该中断请求。

[root@moon 44]# echo 0f > smp_affinity
[root@moon 44]# cat smp_affinity
0000000f

然后我们设置smp_affinity的值为0x0000000f，即使得编号为0-3的cpu允许接收该44这个
中断请求，其他的cpu都不会接收44这个中断请求。

[root@moon 44]# ping -f h
PING hell (195.4.7.3): 56 data bytes
...
--- hell ping statistics ---
6029 packets transmitted, 6027 packets received, 0% packet loss
round-trip min/avg/max = 0.1/0.1/0.4 ms

然后，对主机进行ping测试，这里的-f表示洪泛，h表示主机，实际测试的时候，可以修
改为localhost。这个时候，应用程序ping向主机发送了icmp请求包，网卡设备捕获到之
后，会向cpu发送中断号为44的中断请求。现在该主机上有8个cpu，由于我们设置了编号
为0-3的cpu可以接收该中断，其他的则不可以，那么如果我们查看cpu对中断44的接收情
况时，只有编号为0-3的cpu才能接收到中断请求。

[root@moon 44]# cat /proc/interrupts | grep 'CPU\|44:'
     CPU0 CPU1 CPU2 CPU3 CPU4 CPU5  CPU6 CPU7
 44: 1068 1785 1785 1783 0    0     0    0    IO-APIC-level  eth1

 通过查看测试结果，我们发现cpu 4-7 确实没有接收到编号为44的中断请求，但是编号
 为0-3的cpu接收到了该中断请求。

As can be seen from the line above IRQ44 was delivered only to the first four
processors (0-3).
Now lets restrict that IRQ to CPU(4-7).

[root@moon 44]# echo f0 > smp_affinity
[root@moon 44]# cat smp_affinity
000000f0

进一步进行测试，我们将允许接收编号44的中断请求的cpu设定为编号4-7，即将
smp_affinity的值设定为0x000000f0，下面再次通过ping进行测试。

[root@moon 44]# ping -f h
PING hell (195.4.7.3): 56 data bytes
..
--- hell ping statistics ---
2779 packets transmitted, 2777 packets received, 0% packet loss
round-trip min/avg/max = 0.1/0.5/585.4 ms
[root@moon 44]# cat /proc/interrupts |  'CPU\|44:'
     CPU0 CPU1 CPU2 CPU3 CPU4 CPU5  CPU6 CPU7
 44: 1068 1785 1785 1783 1784 1069  1070 1069   IO-APIC-level  eth1

This time around IRQ44 was delivered only to the last four processors.
i.e counters for the CPU0-3 did not change.

将当前cpu接收到的中断请求44的数量，与前面一次ping测试时各个cpu接收到的中断请求
44的数量对比发现，只有编号为4-7的cpu接收到的中断请求44的数量发生了改变，说明我
们成功的设置了中断请求44的中断绑定到cpu 4-7。

Here is an example of limiting that same irq (44) to cpus 1024 to 1031:

[root@moon 44]# echo 1024-1031 > smp_affinity
[root@moon 44]# cat smp_affinity
1024-1031

上面的语法可以将中断绑定到编号范围为1024-1031的cpu上。

Note that to do this with a bitmask would require 32 bitmasks of zero to
follow the pertinent one.

**[49] IRQ.txt**

**What is an IRQ?**

**An IRQ is an interrupt request from a device.  Currently they can come in over**
**a pin, or over a packet.  Several devices may be connected to the same pin**
**thus sharing an IRQ.**

An IRQ number is a kernel identifier used to talk about a hardware interrupt
source.  Typically this is an index into the global irq_desc array, but except
for what linux/interrupt.h implements the details are architecture specific.

An IRQ number is an enumeration of the possible interrupt sources on a
machine.  Typically what is enumerated is the number of input pins on all of
the interrupt controller in the system.  In the case of ISA what is enumerated
are the 16 input pins on the two i8259 interrupt controllers.

Architectures can assign additional meaning to the IRQ numbers, and are
encouraged to in the case  where there is any manual configuration of the
hardware involved.  The ISA IRQs are a classic example of assigning this kind
of additional meaning.

[50] Intel-IOMMU.txt

Linux IOMMU Support

[51] ManagementStyle.txt

Linux kernel management style

[52] SAK.txt 

SAK, 讲述的其实是系统魔法键sysrq中的一个，还是很有必要的，学习下吧。

An operating system's Secure Attention Key is a security tool which is
provided as protection against trojan password capturing programs.  It is an
undefeatable way of killing all programs which could be masquerading as login
applications.  Users need to be taught to enter this key sequence before they
log in to the system.

From the PC keyboard, Linux has two similar but different ways of providing
SAK.  One is the ALT-SYSRQ-K sequence.  You shouldn't use this sequence.  It
is only available if the kernel was compiled with sysrq support.

The proper way of generating a SAK is to define the key sequence using
`loadkeys'.  This will work whether or not sysrq support is compiled into the
kernel.

SAK works correctly when the keyboard is in raw mode.  This means that once
defined, SAK will kill a running X server.  If the system is in run level 5,
the X server will restart.  This is what you want to happen.

What key sequence should you use? Well, CTRL-ALT-DEL is used to reboot the
machine.  CTRL-ALT-BACKSPACE is magical to the X server.  We'll choose
CTRL-ALT-PAUSE.

In your rc.sysinit (or rc.local) file, add the command

echo "control alt keycode 101 = SAK" | /bin/loadkeys

And that's it!  Only the superuser may reprogram the SAK key.

NOTES
=====

1: Linux SAK is said to be not a "true SAK" as is required by systems which
implement C2 level security.  This author does not know why.

2: On the PC keyboard, SAK kills all applications which have /dev/console
opened.

Unfortunately this includes a number of things which you don't actually want
killed.  This is because these applications are incorrectly holding
/dev/console open.  Be sure to complain to your Linux distributor about this!

You can identify processes which will be killed by SAK with the command

ls -l /proc/[0-9]*/fd/* | grep console

l-wx------ 1  root  root  64 Mar 18 00:46 /proc/579/fd/0 -> /dev/console

Then:

ps aux|grep 579

root  579  0.0  0.1  1088  436 ?  S  00:43  0:00 gpm -t ps/2

So `gpm' will be killed by SAK.  This is a bug in gpm.  It should be closing
standard input.  You can work around this by finding the initscript which
launches gpm and changing it thusly:

Old:

daemon gpm

New:

daemon gpm < /dev/null

Vixie cron also seems to have this problem, and needs the same treatment.

Also, one prominent Linux distribution has the following three lines in its
rc.sysinit and rc scripts:

exec 3<&0
exec 4>&1
exec 5>&2

These commands cause *all* daemons which are launched by the initscripts to
have file descriptors 3, 4 and 5 attached to /dev/console.  So SAK kills them
all.  A workaround is to simply delete these lines, but this may cause system
management applications to malfunction - test everything well.

[53] SM501.txt

The Silicon Motion SM501 multimedia companion chip is a multifunction device
which may provide numerous interfaces including USB host controller USB
gadget, asynchronous serial ports, audio functions, and a dual display video
interface.  The device may be connected by PCI or local bus with varying
functions enabled.

[54] SecurityBugs.txt

Linux kernel developers take security very seriously.  As such, we'd like to
know when a security bug is found so that it can be fixed and disclosed as
quickly as possible.  Please report security bugs to the Linux kernel security
team.

1) Contact

The Linux kernel security team can be contacted by email at
<security@kernel.org>.  This is a private list of security officers who will
help verify the bug report and develop and release a fix.  It is possible that
the security team will bring in extra help from area maintainers to understand
and fix the security vulnerability.

As it is with any bug, the more information provided the easier it will be to
diagnose and fix.  Please review the procedure outlined in REPORTING-BUGS if
you are unclear about what information is helpful.  Any exploit code is very
helpful and will not be released without consent from the reporter unless it
has already been made public.

2) Disclosure

The goal of the Linux kernel security team is to work with the bug submitter
to bug resolution as well as disclosure.  We prefer to fully disclose the bug
as soon as possible.  It is reasonable to delay disclosure when the bug or the
fix is not yet fully understood, the solution is not well-tested or for vendor
coordination.  However, we expect these delays to be short, measurable in
days, not weeks or months.  A disclosure date is negotiated by the security
team working with the bug submitter as well as vendors.  However, the kernel
security team holds the final say when setting a disclosure date.  The
timeframe for disclosure is from immediate (esp. if it's already publicly
known) to a few weeks.  As a basic default policy, we expect report date to
disclosure date to be on the order of 7 days.

3) Non-disclosure agreements

The Linux kernel security team is not a formal body and therefore unable to
enter any non-disclosure agreements.

[55] SubmitChecklist.txt

Linux Kernel patch submission checklist


Here are some basic things that developers should do if they want to see their
kernel patch submissions accepted more quickly.

These are all above and beyond the documentation that is provided in
Documentation/SubmittingPatches and elsewhere regarding submitting Linux
kernel patches.


```
1: If you use a facility then #include the file that defines/declares
   that facility.  Don't depend on other header files pulling in ones
   that you use.

2: Builds cleanly with applicable or modified CONFIG options =y, =m, and
   =n.  No gcc warnings/errors, no linker warnings/errors.

2b: Passes allnoconfig, allmodconfig

2c: Builds successfully when using O=builddir

3: Builds on multiple CPU architectures by using local cross-compile tools
   or some other build farm.

4: ppc64 is a good architecture for cross-compilation checking because it
   tends to use `unsigned long' for 64-bit quantities.

5: Check your patch for general style as detailed in
   Documentation/CodingStyle.  Check for trivial violations with the
   patch style checker prior to submission (scripts/checkpatch.pl).
   You should be able to justify all violations that remain in
   your patch.

6: Any new or modified CONFIG options don't muck up the config menu.

7: All new Kconfig options have help text.

8: Has been carefully reviewed with respect to relevant Kconfig
   combinations.  This is very hard to get right with testing -- brainpower
   pays off here.

9: Check cleanly with sparse.

10: Use 'make checkstack' and 'make namespacecheck' and fix any problems
    that they find.  Note: checkstack does not point out problems explicitly,
             but any one function that uses more than 512 bytes on the stack is a
             candidate for change.
         
11: Include kernel-doc to document global kernel APIs.  (Not required for
                     static functions, but OK there also.) Use 'make htmldocs' or 'make mandocs' to check the kernel-doc and fix any issues.
         
12: Has been tested with CONFIG_PREEMPT, CONFIG_DEBUG_PREEMPT,
             CONFIG_DEBUG_SLAB, CONFIG_DEBUG_PAGEALLOC, CONFIG_DEBUG_MUTEXES,
             CONFIG_DEBUG_SPINLOCK, CONFIG_DEBUG_ATOMIC_SLEEP, CONFIG_PROVE_RCU
             and CONFIG_DEBUG_OBJECTS_RCU_HEAD all simultaneously enabled.
         
13: Has been build- and runtime tested with and without CONFIG_SMP and
             CONFIG_PREEMPT.
         
14: If the patch affects IO/Disk, etc: has been tested with and without
             CONFIG_LBDAF.
         
15: All codepaths have been exercised with all lockdep features enabled.
         
16: All new /proc entries are documented under Documentation/
         
17: All new kernel boot parameters are documented in
             Documentation/kernel-parameters.txt.
         
18: All new module parameters are documented with MODULE_PARM_DESC()
    
19: All new userspace interfaces are documented in Documentation/ABI/.
        See Documentation/ABI/README for more information.
        Patches that change userspace interfaces should be CCed to
        linux-api@vger.kernel.org.
    
20: Check that it all passes `make headers_check'.
    
21: Has been checked with injection of at least slab and page-allocation
        failures.  See Documentation/fault-injection/.
    
        If the new code is substantial, addition of subsystem-specific fault
        injection might be appropriate.
    
22: Newly-added code has been compiled with `gcc -W' (use "make
		EXTRA_CFLAGS=-W").  This will generate lots of noise, but is good for finding 		bugs like "warning: comparison between signed and unsigned".
    
23: Tested after it has been merged into the -mm patchset to make sure
        that it still works with all of the other queued patches and various
        changes in the VM, VFS, and other subsystems.
    
24: All memory barriers {e.g., barrier(), rmb(), wmb()} need a comment in the
        source code that explains the logic of what they are doing and why.
    
25: If any ioctl's are added by the patch, then also update
        Documentation/ioctl/ioctl-number.txt.
    
26: If your modified source code depends on or uses any of the kernel
        APIs or features that are related to the following kconfig symbols,
        then test multiple builds with the related kconfig symbols disabled
        and/or =m (if that option is available) [not all of these at the
        same time, just various/random combinations of them]:
    
        CONFIG_SMP, CONFIG_SYSFS, CONFIG_PROC_FS, CONFIG_INPUT, CONFIG_PCI,
        CONFIG_BLOCK, CONFIG_PM, CONFIG_HOTPLUG, CONFIG_MAGIC_SYSRQ,
        CONFIG_NET, CONFIG_INET=n (but latter with CONFIG_NET=y)
```

[56] SubmittingPatches.txt

 How to Get Your Change Into the Linux Kernel
 or
 Care And Operation Of Your Linus Torvalds

For a person or company who wishes to submit a change to the Linux kernel, the
process can sometimes be daunting if you're not familiar with "the system."
This text is a collection of suggestions which can greatly increase the
chances of your change being accepted.

Read Documentation/SubmitChecklist for a list of items to check before
submitting code.  If you are submitting a driver, also read
Documentation/SubmittingDrivers.

--------------------------------------------
SECTION 1 - CREATING AND SENDING YOUR CHANGE
--------------------------------------------

1) "diff -up"
------------

Use "diff -up" or "diff -uprN" to create patches.

All changes to the Linux kernel occur in the form of patches, as generated by
diff(1).  When creating your patch, make sure to create it in "unified diff"
format, as supplied by the '-u' argument to diff(1).  Also, please use the
'-p' argument which shows which C function each change is in - that makes the
resultant diff a lot easier to read.  Patches should be based in the root
kernel source directory, not in any lower subdirectory.

To create a patch for a single file, it is often sufficient to do:
     
    SRCTREE= linux-2.6
    MYFILE=  drivers/net/mydriver.c
     
    cd $SRCTREE
    cp $MYFILE $MYFILE.orig
    vi $MYFILE      # make your change
    cd ..
    diff -up $SRCTREE/$MYFILE{.orig,} > /tmp/patch

To create a patch for multiple files, you should unpack a "vanilla", or
unmodified kernel source tree, and generate a diff against your own source
tree.  For example:
     
    MYSRC= /devel/linux-2.6
     
    tar xvfz linux-2.6.12.tar.gz
    mv linux-2.6.12 linux-2.6.12-vanilla
    diff -uprN -X linux-2.6.12-vanilla/Documentation/dontdiff \
    linux-2.6.12-vanilla $MYSRC > /tmp/patch

"dontdiff" is a list of files which are generated by the kernel during the
build process, and should be ignored in any diff(1)-generated patch.  The
"dontdiff" file is included in the kernel tree in 2.6.12 and later.  For
earlier kernel versions, you can get it from
<http://www.xenotime.net/linux/doc/dontdiff>.
         
Make sure your patch does not include any extra files which do not belong in a
patch submission.  Make sure to review your patch -after- generated it with
diff(1), to ensure accuracy.
         
If your changes produce a lot of deltas, you may want to look into splitting
them into individual patches which modify things in logical stages.  This will
facilitate easier reviewing by other kernel developers, very important if you
want your patch accepted.  There are a number of scripts which can aid in
this: 
    Quilt: http://savannah.nongnu.org/projects/quilt
         
Andrew Morton's patch scripts:
http://userweb.kernel.org/~akpm/stuff/patch-scripts.tar.gz Instead of these
scripts, quilt is the recommended patch management tool (see above).
         
2) Describe your changes.

Describe the technical detail of the change(s) your patch includes.

Be as specific as possible.  The WORST descriptions possible include things
like "update driver X", "bug fix for driver X", or "this patch includes
updates for subsystem X.  Please apply."

The maintainer will thank you if you write your patch description in a form
which can be easily pulled into Linux's source code management system, git, as
a "commit log".  See #15, below.

If your description starts to get long, that's a sign that you probably need
to split up your patch.  See #3, next.

When you submit or resubmit a patch or patch series, include the complete
patch description and justification for it.  Don't just say that this is
version N of the patch (series).  Don't expect the patch merger to refer back
to earlier patch versions or referenced URLs to find the patch description and
put that into the patch.  I.e., the patch (series) and its description should
be self-contained.  This benefits both the patch merger(s) and reviewers.
Some reviewers probably didn't even receive earlier versions of the patch.

If the patch fixes a logged bug entry, refer to that bug entry by number and
URL.

3) Separate your changes.

Separate _logical changes_ into a single patch file.

For example, if your changes include both bug fixes and performance
enhancements for a single driver, separate those changes into two or more
patches.  If your changes include an API update, and a new driver which uses
that new API, separate those into two patches.

On the other hand, if you make a single change to numerous files, group those
changes into a single patch.  Thus a single logical change is contained within
a single patch.

If one patch depends on another patch in order for a change to be complete,
that is OK.  Simply note "this patch depends on patch X" in your patch
description.

If you cannot condense your patch set into a smaller set of patches, then only
post say 15 or so at a time and wait for review and integration.

4) Style check your changes.

Check your patch for basic style violations, details of which can be found in
Documentation/CodingStyle.  Failure to do so simply wastes the reviewers time
and will get your patch rejected, probably without even being read.

At a minimum you should check your patches with the patch style checker prior
to submission (scripts/checkpatch.pl).  You should be able to justify all
violations that remain in your patch.

5) Select e-mail destination.

Look through the MAINTAINERS file and the source code, and determine if your
change applies to a specific subsystem of the kernel, with an assigned
maintainer.  If so, e-mail that person.

If no maintainer is listed, or the maintainer does not respond, send your
patch to the primary Linux kernel developer's mailing list,
linux-kernel@vger.kernel.org.  Most kernel developers monitor this e-mail
list, and can comment on your changes.

Do not send more than 15 patches at once to the vger mailing lists!!!

Linus Torvalds is the final arbiter of all changes accepted into the Linux
kernel.  His e-mail address is <torvalds@linux-foundation.org>.  He gets a lot
of e-mail, so typically you should do your best to -avoid- sending him e-mail. 

Patches which are bug fixes, are "obvious" changes, or similarly require
little discussion should be sent or CC'd to Linus.  Patches which require
discussion or do not have a clear advantage should usually be sent first to
linux-kernel.  Only after the patch is discussed should the patch then be
submitted to Linus.

6) Select your CC (e-mail carbon copy) list.

Unless you have a reason NOT to do so, CC linux-kernel@vger.kernel.org.

Other kernel developers besides Linus need to be aware of your change, so that
they may comment on it and offer code review and suggestions.  linux-kernel is
the primary Linux kernel developer mailing list.  Other mailing lists are
available for specific subsystems, such as USB, framebuffer devices, the VFS,
the SCSI subsystem, etc.  See the MAINTAINERS file for a mailing list that
relates specifically to your change.

Majordomo lists of VGER.KERNEL.ORG at:
         <http://vger.kernel.org/vger-lists.html>

If changes affect userland-kernel interfaces, please send the MAN-PAGES
maintainer (as listed in the MAINTAINERS file) a man-pages patch, or at least
a notification of the change, so that some information makes its way into the
manual pages.
    
Even if the maintainer did not respond in step #5, make sure to ALWAYS copy
the maintainer when you change their code.
    
For small patches you may want to CC the Trivial Patch Monkey
trivial@kernel.org which collects "trivial" patches. Have a look into the
MAINTAINERS file for its current manager.  Trivial patches must qualify for
one of the following rules: Spelling fixes in documentation Spelling fixes
which could break grep(1) Warning fixes (cluttering with useless warnings is
bad) Compilation fixes (only if they are actually correct) Runtime fixes (only
if they actually fix things) Removing use of deprecated functions/macros (eg.
check_region) Contact detail and documentation fixes Non-portable code
replaced by portable code (even in arch-specific, since people copy, as long
as it's trivial) Any fix by the author/maintainer of the file (ie. patch
monkey in re-transmission mode)
    
    
7) No MIME, no links, no compression, no attachments.  Just plain text.
   

Linus and other kernel developers need to be able to read and comment on the
changes you are submitting.  It is important for a kernel developer to be able
to "quote" your changes, using standard e-mail tools, so that they may comment
on specific portions of your code.
    
For this reason, all patches should be submitting e-mail "inline".  WARNING:
Be wary of your editor's word-wrap corrupting your patch, if you choose to
cut-n-paste your patch.
    
Do not attach the patch as a MIME attachment, compressed or not.  Many popular
e-mail applications will not always transmit a MIME attachment as plain text,
    making it impossible to comment on your code.  A MIME attachment also
    takes Linus a bit more time to process, decreasing the likelihood of your
    MIME-attached change being accepted.
    
Exception:  If your mailer is mangling patches then someone may ask you to
re-send them using MIME.
    
See Documentation/email-clients.txt for hints about configuring your e-mail
client so that it sends your patches untouched.
    
8) E-mail size.
   

When sending patches to Linus, always follow step #7.
    
Large changes are not appropriate for mailing lists, and some maintainers.  If
your patch, uncompressed, exceeds 300 kB in size, it is preferred that you
store your patch on an Internet-accessible server, and provide instead a URL
(link) pointing to your patch.
    
9) Name your kernel version.
   

It is important to note, either in the subject line or in the patch
description, the kernel version to which this patch applies.
    
If the patch does not apply cleanly to the latest kernel version, Linus will
not apply it.
    
10) Don't get discouraged.  Re-submit.
    

After you have submitted your change, be patient and wait.  If Linus likes
your change and applies it, it will appear in the next version of the kernel
that he releases.
    
However, if your change doesn't appear in the next version of the kernel,
there could be any number of reasons.  It's YOUR job to narrow down those
reasons, correct what was wrong, and submit your updated change.
    
It is quite common for Linus to "drop" your patch without comment.  That's the
nature of the system.  If he drops your patch, it could be due to
    * Your patch did not apply cleanly to the latest kernel version.
    * Your patch was not sufficiently discussed on linux-kernel.
    * A style issue (see section 2).
    * An e-mail formatting issue (re-read this section).
    * A technical problem with your change.
    * He gets tons of e-mail, and yours got lost in the shuffle.
    * You are being annoying.
    
When in doubt, solicit comments on linux-kernel mailing list.
    
11) Include PATCH in the subject
    

Due to high e-mail traffic to Linus, and to linux-kernel, it is common
convention to prefix your subject line with [PATCH].  This lets Linus and
other kernel developers more easily distinguish patches from other e-mail
discussions.
    
12) Sign your work
    

To improve tracking of who did what, especially with patches that can
percolate to their final resting place in the kernel through several layers of
maintainers, we've introduced a "sign-off" procedure on patches that are being
emailed around.
    
The sign-off is a simple line at the end of the explanation for the patch,
which certifies that you wrote it or otherwise have the right to pass it on as
an open-source patch.  The rules are pretty simple: if you can certify the
below:
    
        Developer's Certificate of Origin 1.1
    
        By making a contribution to this project, I certify that:
    
        (a) The contribution was created in whole or in part by me and I have
            the right to submit it under the open source license indicated in
            the file; or
    
        (b) The contribution is based upon previous work that, to the best of
            my knowledge, is covered under an appropriate open source license
            and I have the right under that license to submit that work with
            modifications, whether created in whole or in part by me, under
            the same open source license (unless I am permitted to submit
                    under a different license), as indicated in the file; or
    
        (c) The contribution was provided directly to me by some other person
            who certified (a), (b) or (c) and I have not modified it.
    
        (d) I understand and agree that this project and the contribution are
            public and that a record of the contribution (including all
            personal information I submit with it, including my sign-off) is
            maintained indefinitely and may be redistributed consistent with
            this project or the open source license(s) involved.
    
    then you just add a line saying
            Signed-off-by: Random J Developer <random@developer.example.org>

using your real name (sorry, no pseudonyms or anonymous contributions.)
    
Some people also put extra tags at the end.  They'll just be ignored for now,
but you can do this to mark internal company procedures or just point out some
special detail about the sign-off. 
    
If you are a subsystem or branch maintainer, sometimes you need to slightly
modify patches you receive in order to merge them, because the code is not
exactly the same in your tree and the submitters'. If you stick strictly to
rule (c), you should ask the submitter to rediff, but this is a totally
counter-productive waste of time and energy. Rule (b) allows you to adjust the
code, but then it is very impolite to change one submitter's code and make him
endorse your bugs. To solve this problem, it is recommended that you add a
line between the last Signed-off-by header and yours, indicating the nature of
your changes. While there is nothing mandatory about this, it seems like
prepending the description with your mail and/or name, all enclosed in square
brackets, is noticeable enough to make it obvious that you are responsible for
last-minute changes. Example :
    
        Signed-off-by: Random J Developer <random@developer.example.org>
        [lucky@maintainer.example.org: struct foo moved from foo.c to foo.h]
        Signed-off-by: Lucky K Maintainer <lucky@maintainer.example.org>

This practise is particularly helpful if you maintain a stable branch and want
at the same time to credit the author, track changes, merge the fix, and
protect the submitter from complaints. Note that under no circumstances can
you change the author's identity (the From header), as it is the one which
appears in the changelog.
    
Special note to back-porters: It seems to be a common and useful practise to
insert an indication of the origin of a patch at the top of the commit message
(just after the subject line) to facilitate tracking. For instance, here's
what we see in 2.6-stable :
    
    Date:   Tue May 13 19:10:30 +0000
    
        SCSI: libiscsi regression in 2.6.25: fix nop timer handling
    
        commit 4cf1043593db6a337f10e006c23c69e5fc93e722 upstream

And here's what appears in 2.4 :
    
    Date:   Tue May 13 22:12:27 +0200
    
        wireless, airo: waitbusy() won't delay
    
        [backport of 2.6 commit b7acbdfbd1f277c1eb23f344f899cfa4cd0bf36a]

Whatever the format, this information provides a valuable help to people
tracking your trees, and to people trying to trouble-shoot bugs in your tree.
13) When to use Acked-by: and Cc:
    

The Signed-off-by: tag indicates that the signer was involved in the
development of the patch, or that he/she was in the patch's delivery path.
    
If a person was not directly involved in the preparation or handling of a
patch but wishes to signify and record their approval of it then they can
arrange to have an Acked-by: line added to the patch's changelog.
    
Acked-by: is often used by the maintainer of the affected code when that
maintainer neither contributed to nor forwarded the patch.
    
Acked-by: is not as formal as Signed-off-by:.  It is a record that the acker
has at least reviewed the patch and has indicated acceptance.  Hence patch
mergers will sometimes manually convert an acker's "yep, looks good to me"
into an Acked-by:.
    
Acked-by: does not necessarily indicate acknowledgement of the entire patch.
For example, if a patch affects multiple subsystems and has an Acked-by: from
one subsystem maintainer then this usually indicates acknowledgement of just
the part which affects that maintainer's code.  Judgement should be used here.
When in doubt people should refer to the original discussion in the mailing
list archives.
    
If a person has had the opportunity to comment on a patch, but has not
provided such comments, you may optionally add a "Cc:" tag to the patch.  This
is the only tag which might be added without an explicit action by the person
it names.  This tag documents that potentially interested parties have been
included in the discussion
    
    
14) Using Reported-by:, Tested-by: and Reviewed-by:

If this patch fixes a problem reported by somebody else, consider adding a
Reported-by: tag to credit the reporter for their contribution.  Please note
that this tag should not be added without the reporter's permission,
especially if the problem was not reported in a public forum.  That said, if
we diligently credit our bug reporters, they will, hopefully, be inspired to
help us again in the future.

A Tested-by: tag indicates that the patch has been successfully tested (in
some environment) by the person named.  This tag informs maintainers that
some testing has been performed, provides a means to locate testers for
future patches, and ensures credit for the testers.

Reviewed-by:, instead, indicates that the patch has been reviewed and found
acceptable according to the Reviewer's Statement:

        Reviewer's statement of oversight
    
        By offering my Reviewed-by: tag, I state that:
    
         (a) I have carried out a technical review of this patch to
             evaluate its appropriateness and readiness for inclusion into
             the mainline kernel.
    
         (b) Any problems, concerns, or questions relating to the patch
             have been communicated back to the submitter.  I am satisfied
             with the submitter's response to my comments.
    
         (c) While there may be things that could be improved with this
             submission, I believe that it is, at this time, (1) a
             worthwhile modification to the kernel, and (2) free of known
             issues which would argue against its inclusion.
    
         (d) While I have reviewed the patch and believe it to be sound, I
             do not (unless explicitly stated elsewhere) make any
             warranties or guarantees that it will achieve its stated
             purpose or function properly in any given situation.

A Reviewed-by tag is a statement of opinion that the patch is an appropriate
modification of the kernel without any remaining serious technical issues.
Any interested reviewer (who has done the work) can offer a Reviewed-by tag
for a patch.  This tag serves to give credit to reviewers and to inform
maintainers of the degree of review which has been done on the patch.
Reviewed-by: tags, when supplied by reviewers known to understand the subject
area and to perform thorough reviews, will normally increase the likelihood of
your patch getting into the kernel.

15) The canonical patch format

The canonical patch subject line is:

    Subject: [PATCH 001/123] subsystem: summary phrase

The canonical patch message body contains the following:

  - A "from" line specifying the patch author.

  - An empty line.

  - The body of the explanation, which will be copied to the
    permanent changelog to describe this patch.

  - The "Signed-off-by:" lines, described above, which will
    also go in the changelog.

  - A marker line containing simply "---".

  - Any additional comments not suitable for the changelog.

  - The actual patch (diff output).

The Subject line format makes it very easy to sort the emails alphabetically
by subject line - pretty much any email reader will support that - since
because the sequence number is zero-padded, the numerical and alphabetic sort
is the same.

The "subsystem" in the email's Subject should identify which area or subsystem
of the kernel is being patched.

The "summary phrase" in the email's Subject should concisely describe the
patch which that email contains.  The "summary phrase" should not be a
filename.  Do not use the same "summary phrase" for every patch in a whole
patch series (where a "patch series" is an ordered sequence of multiple,
        related patches).

Bear in mind that the "summary phrase" of your email becomes a globally-unique
identifier for that patch.  It propagates all the way into the git changelog.
The "summary phrase" may later be used in developer discussions which refer to
the patch.  People will want to google for the "summary phrase" to read
discussion regarding that patch.  It will also be the only thing that people
may quickly see when, two or three months later, they are going through
perhaps thousands of patches using tools such as "gitk" or "git log
--oneline".

For these reasons, the "summary" must be no more than 70-75 characters, and it
must describe both what the patch changes, as well as why the patch might be
necessary.  It is challenging to be both succinct and descriptive, but that is
what a well-written summary should do.

The "summary phrase" may be prefixed by tags enclosed in square brackets:
"Subject: [PATCH tag] <summary phrase>".  The tags are not considered part of
the summary phrase, but describe how the patch should be treated.  Common tags
might include a version descriptor if the multiple versions of the patch have
been sent out in response to comments (i.e., "v1, v2, v3"), or "RFC" to
indicate a request for comments.  If there are four patches in a patch series
the individual patches may be numbered like this: 1/4, 2/4, 3/4, 4/4.  This
assures that developers understand the order in which the patches should be
applied and that they have reviewed or applied all of the patches in the patch
series.

A couple of example Subjects:

    Subject: [patch 2/5] ext2: improve scalability of bitmap searching
    Subject: [PATCHv2 001/207] x86: fix eflags tracking

The "from" line must be the very first line in the message body, and has the
form:

        From: Original Author <author@example.com>

The "from" line specifies who will be credited as the author of the patch in
the permanent changelog.  If the "from" line is missing, then the "From:" line
from the email header will be used to determine the patch author in the
changelog.

The explanation body will be committed to the permanent source changelog, so
should make sense to a competent reader who has long since forgotten the
immediate details of the discussion that might have led to this patch.
Including symptoms of the failure which the patch addresses (kernel log
        messages, oops messages, etc.) is especially useful for people who
might be searching the commit logs looking for the applicable patch.  If a
patch fixes a compile failure, it may not be necessary to include _all_ of the
compile failures; just enough that it is likely that someone searching for the
patch can find it.  As in the "summary phrase", it is important to be both
succinct as well as descriptive.

The "---" marker line serves the essential purpose of marking for patch
handling tools where the changelog message ends.

One good use for the additional comments after the "---" marker is for a
diffstat, to show what files have changed, and the number of inserted and
deleted lines per file.  A diffstat is especially useful on bigger patches.
Other comments relevant only to the moment or the maintainer, not suitable for
the permanent changelog, should also go here.  A good example of such comments
might be "patch changelogs" which describe what has changed between the v1 and
v2 version of the patch.

If you are going to include a diffstat after the "---" marker, please use
diffstat options "-p 1 -w 70" so that filenames are listed from the top of the
kernel source tree and don't use too much horizontal space (easily fit in 80
        columns, maybe with some indentation).

See more details on the proper patch format in the following references.

16) Sending "git pull" requests  (from Linus emails)

Please write the git repo address and branch name alone on the same line so
that I can't even by mistake pull from the wrong branch, and so that a
triple-click just selects the whole thing.

So the proper format is something along the lines of:

        "Please pull from
    
                git://jdelvare.pck.nerim.net/jdelvare-2.6 i2c-for-linus
    
         to get these changes:"

so that I don't have to hunt-and-peck for the address and inevitably get it
wrong (actually, I've only gotten it wrong a few times, and checking against
the diffstat tells me when I get it wrong, but I'm just a lot more comfortable
when I don't have to "look for" the right thing to pull, and double-check that
I have the right branch-name).

Please use "git diff -M --stat --summary" to generate the diffstat:
the -M enables rename detection, and the summary enables a summary of
new/deleted or renamed files.

With rename detection, the statistics are rather different [...] because git
will notice that a fair number of the changes are renames.

-----------------------------------
SECTION 2 - HINTS, TIPS, AND TRICKS
-----------------------------------

This section lists many of the common "rules" associated with code submitted
to the kernel.  There are always exceptions... but you must have a really good
reason for doing so.  You could probably call this section Linus Computer
Science 101.

1) Read Documentation/CodingStyle

Nuff said.  If your code deviates too much from this, it is likely to be
rejected without further review, and without comment.

One significant exception is when moving code from one file to another -- in
this case you should not modify the moved code at all in the same patch which
moves it.  This clearly delineates the act of moving the code and your
changes.  This greatly aids review of the actual differences and allows tools
to better track the history of the code itself.

Check your patches with the patch style checker prior to submission
(scripts/checkpatch.pl).  The style checker should be viewed as a guide not as
the final word.  If your code looks better with a violation then its probably
best left alone.

The checker reports at three levels:
 - ERROR: things that are very likely to be wrong
 - WARNING: things requiring careful review
 - CHECK: things requiring thought

You should be able to justify all violations that remain in your patch.

2) #ifdefs are ugly

Code cluttered with ifdefs is difficult to read and maintain.  Don't do it.
Instead, put your ifdefs in a header, and conditionally define 'static inline'
functions, or macros, which are used in the code.  Let the compiler optimize
away the "no-op" case.

Simple example, of poor code:

        dev = alloc_etherdev (sizeof(struct funky_private));
        if (!dev)
                return -ENODEV;
        #ifdef CONFIG_NET_FUNKINESS
        init_funky_net(dev);
        #endif

Cleaned-up example:

(in header)
        #ifndef CONFIG_NET_FUNKINESS
        static inline void init_funky_net (struct net_device *d) {}
        #endif

(in the code itself)
        dev = alloc_etherdev (sizeof(struct funky_private));
        if (!dev)
                return -ENODEV;
        init_funky_net(dev);



3) 'static inline' is better than a macro

Static inline functions are greatly preferred over macros.  They provide type
safety, have no length limitations, no formatting limitations, and under gcc
they are as cheap as macros.

Macros should only be used for cases where a static inline is clearly
suboptimal [there are a few, isolated cases of this in fast paths], or where
it is impossible to use a static inline function [such as string-izing].

'static inline' is preferred over 'static __inline__', 'extern inline', and
'extern __inline__'.

4) Don't over-design.

Don't try to anticipate nebulous future cases which may or may not be useful:
"Make it as simple as you can, and no simpler."

[57] SubmittingPatches.txt

Submitting Drivers For The Linux Kernel
---------------------------------------

This document is intended to explain how to submit device drivers to the
various kernel trees. Note that if you are interested in video card drivers
you should probably talk to XFree86 (http://www.xfree86.org/) and/or X.Org
(http://x.org/) instead.

Also read the Documentation/SubmittingPatches document.


Allocating Device Numbers
-------------------------

Major and minor numbers for block and character devices are allocated by the
Linux assigned name and number authority (currently this is Torben Mathiasen).
The site is http://www.lanana.org/. This also deals with allocating numbers
for devices that are not going to be submitted to the mainstream kernel.  See
Documentation/devices.txt for more information on this.

If you don't use assigned numbers then when your device is submitted it will
be given an assigned number even if that is different from values you may have
shipped to customers before.

Who To Submit Drivers To
------------------------

Linux 2.0:
        No new drivers are accepted for this kernel tree.

Linux 2.2:
        No new drivers are accepted for this kernel tree.

Linux 2.4:
        If the code area has a general maintainer then please submit it to the
        maintainer listed in MAINTAINERS in the kernel file. If the maintainer
        does not respond or you cannot find the appropriate maintainer then
        please contact Willy Tarreau <w@1wt.eu>.

Linux 2.6:
        The same rules apply as 2.4 except that you should follow linux-kernel
        to track changes in API's. The final contact point for Linux 2.6
        submissions is Andrew Morton.

What Criteria Determine Acceptance
----------------------------------

Licensing:  The code must be released to us under the GNU General Public
            License. We don't insist on any kind of exclusive GPL licensing,
            and if you wish the driver to be useful to other communities such
            as BSD you may well wish to release under multiple licenses.  See
            accepted licenses at include/linux/module.h

Copyright:  The copyright owner must agree to use of GPL.  It's best if the
            submitter and copyright owner are the same person/entity. If not,
            the name of the person/entity authorizing use of GPL should be
            listed in case it's necessary to verify the will of the copyright
            owner.

Interfaces: If your driver uses existing interfaces and behaves like other
            drivers in the same class it will be much more likely to be
            accepted than if it invents gratuitous new ones.  If you need to
            implement a common API over Linux and NT drivers do it in
            userspace.

Code:       Please use the Linux style of code formatting as documented in
            Documentation/CodingStyle. If you have sections of code that need
            to be in other formats, for example because they are shared with a
            windows driver kit and you want to maintain them just once
            separate them out nicely and note this fact.

Portability:Pointers are not always 32bits, not all computers are little
            endian, people do not all have floating point and you shouldn't
            use inline x86 assembler in your driver without careful thought.
            Pure x86 drivers generally are not popular.  If you only have x86
            hardware it is hard to test portability but it is easy to make
            sure the code can easily be made portable.

Clarity:    It helps if anyone can see how to fix the driver. It helps you
            because you get patches not bug reports. If you submit a driver
            that intentionally obfuscates how the hardware works it will go in
            the bitbucket.

PM support:     Since Linux is used on many portable and desktop systems, your
            driver is likely to be used on such a system and therefore it
            should support basic power management by implementing, if
            necessary, the .suspend and .resume methods used during the
            system-wide suspend and resume transitions.  You should verify
            that your driver correctly handles the suspend and resume, but if
            you are unable to ensure that, please at least define the .suspend
            method returning the -ENOSYS ("Function not implemented") error.
            You should also try to make sure that your driver uses as little
            power as possible when it's not doing anything.  For the driver
            testing instructions see Documentation/power/drivers-testing.txt
            and for a relatively complete overview of the power management
            issues related to drivers see Documentation/power/devices.txt .

Control:    In general if there is active maintenance of a driver by the
            author then patches will be redirected to them unless they are
            totally obvious and without need of checking.  If you want to be
            the contact and update point for the driver it is a good idea to
            state this in the comments, and include an entry in MAINTAINERS
            for your driver.
                     
What Criteria Do Not Determine Acceptance
-----------------------------------------

Vendor:     Being the hardware vendor and maintaining the driver is often a
            good thing. If there is a stable working driver from other people
            already in the tree don't expect 'we are the vendor' to get your
            driver chosen. Ideally work with the existing driver author to
            build a single perfect driver.
                     
Author:     It doesn't matter if a large Linux company wrote the driver, or
            kernel tree. Anyone who tells you otherwise
            isn't telling the whole story.

[58] VGA-softcursor.txt

Linux now has some ability to manipulate cursor appearance. Normally, you can
set the size of hardware cursor (and also work around some ugly bugs in those
miserable Trident cards--see #define TRIDENT_GLITCH in
drivers/video/vgacon.c). You can now play a few new tricks:  you can make your
cursor look like a non-blinking red block, make it inverse background of the
character it's over or to highlight that character and still choose whether
the original hardware cursor should remain visible or not.  There may be other
things I have never thought of.

[59] applying-patches.txt

A frequently asked question on the Linux Kernel Mailing List is how to apply a
patch to the kernel or, more specifically, what base kernel a patch for one of
the many trees/branches should be applied to. Hopefully this document will
explain this to you.

[60] atomic_opts.txt

This document is intended to serve as a guide to Linux port maintainers on how
to implement atomic counter, bitops, and spinlock interfaces properly.

port这里是移植的意思。

[61] bad_memory.txt

How to deal with bad memory e.g. reported by memtest86+ ?

如何处理内存诊断工具memtest86+报告的坏内存。
#########################################################

There are three possibilities I know of:

1) Reinsert/swap the memory modules

重新插入内存条、将内存条拔下来插入其他内存槽。

2) Buy new modules (best!) or try to exchange the memory
   if you have spare-parts

购买新的内存条（这是最好的）或者试着换用其他备用的内存，如果你有的话。

3) Use BadRAM or memmap

继续使用坏内存，但是要对其中的某些坏区域进行屏蔽。

This Howto is about number 3) .


BadRAM
######
BadRAM is the actively developed and available as kernel-patch
here:  http://rick.vanrein.org/linux/badram/

For more details see the BadRAM documentation.

memmap
######

memmap is already in the kernel and usable as kernel-parameter at
boot-time.  Its syntax is slightly strange and you may need to
calculate the values by yourself!

Syntax to exclude a memory area (see kernel-parameters.txt for details):
memmap=<size>$<address>

memmap=容量:起始地址。
注意，这里容量的表示有两种方式，一种是通过十进制+容量单位，一种是通过16进制，
采用16进制的时候，默认表示容量单位为字节。
可以参照下面的示例。

Example: memtest86+ reported here errors at address 0x18691458, 0x1869and
         some others. All had 0x1869xxxx in common, so I chose a pattern of
         0x18690000,0xffff0000.

With the numbers of the example above:
memmap=64K$0x18690000
 or
memmap=0x10000$0x18690000

[62] basic_profiling.txt

[63] binfmt_misc.txt

This Kernel feature allows you to invoke almost (for restrictions see below)
every program by simply typing its name in the shell.  This includes for
example compiled Java(TM), Python or Emacs programs.

只要你在shell里面输入程序的名字，linux内核几乎允许你执行所有的程序，例如运行
java程序、python程序或者emacs程序等。

To achieve this you must tell binfmt_misc which interpreter has to be invoked
with which binary. Binfmt_misc recognises the binary-type by matching some
bytes at the beginning of the file with a magic byte sequence (masking out
specified bits) you have supplied. Binfmt_misc can also recognise a filename
extension aka '.com' or '.exe'.

A few examples (assumed you are in /proc/sys/fs/binfmt_misc):

- enable support for em86 (like binfmt_em86, for Alpha AXP only):
  echo ':i386:M::\x7fELF\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02
        \x00\x03:\xff\xff\xff\xff\xff\xfe\xfe\xff\xff\xff\xff\xff\xff\xff\xff
        \xff\xfb\xff\xff:/bin/em86:' > register
  echo ':i486:M::\x7fELF\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02
        \x00\x06:\xff\xff\xff\xff\xff\xfe\xfe\xff\xff\xff\xff\xff\xff\xff\xff
        \xff\xfb\xff\xff:/bin/em86:' > register

- enable support for packed DOS applications (pre-configured dosemu hdimages):
  echo ':DEXE:M::\x0eDEX::/usr/bin/dosexec:' > register

- enable support for Windows executables using wine:
  echo ':DOSWin:M::MZ::/usr/local/bin/wine:' > register

For java support see Documentation/java.txt

[64] braille-console.txt 

To get early boot messages on a braille device (before userspace screen
readers can start), you first need to compile the support for the usual serial
console (see serial-console.txt), and for braille device (in Device Drivers -
Accessibility).

[65] bt8xxgpio.txt

[66] btmrvl.txt

All commands are used via debugfs interface.

[67] bus-virt-phys-mapping.txt

[ NOTE: The virt_to_bus() and bus_to_virt() functions have been
        superseded by the functionality provided by the PCI DMA interface
        (see Documentation/DMA-API-HOWTO.txt).  They continue
        to be documented below for historical purposes, but new code
        must not use them. --davidm 00/12/12 ]

[ This is a mail message in response to a query on IO mapping, thus the
  strange format for a "document" ]

The AHA-is a bus-master device, and your patch makes the driver give the
controller the physical address of the buffers, which is correct on x86
(because all bus master devices see the physical memory mappings directly). 

However, on many setups, there are actually _three_ different ways of looking
at memory addresses, and in this case we actually want the third, the
so-called "bus address". 

Essentially, the three ways of addressing memory are (this is "real memory",
        that is, normal RAM--see later about other details): 
    
     - CPU untranslated.  This is the "physical" address.  Physical address 
       0 is what the CPU sees when it drives zeroes on the memory bus.
    
     - CPU translated address. This is the "virtual" address, and is 
       completely internal to the CPU itself with the CPU doing the appropriate
       translations into "CPU untranslated". 
    
     - bus address. This is the address of memory as seen by OTHER devices, 
       not the CPU. Now, in theory there could be many different bus 
       addresses, with each device seeing memory in some device-specific way, but
       happily most hardware designers aren't actually actively trying to make
       things any more complex than necessary, so you can assume that all 
       external hardware sees the memory the same way. 

Now, on normal PCs the bus address is exactly the same as the physical
address, and things are very simple indeed. However, they are that simple
because the memory and the devices share the same address space, and that is
not generally necessarily true on other PCI/ISA setups. 
    
Now, just as an example, on the PReP (PowerPC Reference Platform), the CPU
sees a memory map something like this (this is from memory):
        
    0-2 GB          "real memory"
    2 GB-3 GB       "system IO" (inb/out and similar accesses on x86)
    3 GB-4 GB       "IO memory" (shared memory over the IO bus)

Now, that looks simple enough. However, when you look at the same thing from
the viewpoint of the devices, you have the reverse, and the physical memory
address 0 actually shows up as address 2 GB for any IO master.
        
So when the CPU wants any bus master to write to physical memory 0, it has to
give the master address 0x8000as the memory address.
        
So, for example, depending on how the kernel is actually mapped on the PPC,
you can end up with a setup like this:
        
     physical address:      0
     virtual address:       0xC0000000
     bus address:           0x80000000

where all the addresses actually point to the same thing.  It's just seen
through different translations..

[68] cachetlb.txt

Cache and TLB Flushing Under Linux

转译后备缓冲器，在中国大陆也被翻译为页表缓存、转址旁路缓存，为CPU的一种缓存，
由存储器管理单元用于改进虚拟地址到物理地址的转译速度。目前所有的桌面型及服务器
型处理器皆使用TLB。TLB具有固定数目的空间槽，用于存放将虚拟地址映射至物理地址的
标签页表条目。为典型的内容可寻址存储器。其搜索关键字为虚拟内存地址，其搜索结果
为物理地址。如果请求的虚拟地址在TLB中存在，CAM 将给出一个非常快速的匹配结果，
之后就可以使用得到的物理地址访问存储器。如果请求的虚拟地址不在TLB 中，就会使用
标签页表进行虚实地址转换，而标签页表的访问速度比TLB慢很多。 

[69] circular-buffers.txt

Linux provides a number of features that can be used to implement circular
buffering.  There are two sets of such features:

linux提供了一些特征用于实现环形缓冲，这些特征主要可以分为两组：

 (1) Convenience functions for determining information about power-of-2 sized
     buffers.

     一些方便使用的函数，用于获取、设置2^x的容量的环形缓冲区中的信息。

 (2) Memory barriers for when the producer and the consumer of objects in the
     buffer don't want to share a lock.

     内存访问限制，用于保证环形缓冲区中数据对象的生产者和消费者不能共享锁。

To use these facilities, as discussed below, there needs to be just one
producer and just one consumer.  It is possible to handle multiple producers
by serialising them, and to handle multiple consumers by serialising them.

[70] coccinelle.txt

[71] cpu-hotplug.txt

CPU hotplug Support in Linux(tm) Kernel

[72] cpu-load.txt

Linux exports various bits of information via `/proc/stat' and `/proc/uptime'
that userland tools, such as top(1), use to calculate the average time system
spent in a particular state

[73] cputopology.txt

Export CPU topology info via sysfs. Items (attributes) are similar to
/proc/cpuinfo.

[74] dcdbas.txt

The Dell Systems Management Base Driver provides a sysfs interface for
systems management software such as Dell OpenManage to perform system
management interrupts and host control actions (system power cycle or power
off after OS shutdown) on certain Dell systems.

[75] debugging-modules.txt

Debugging Modules after 2.6.3

[76] debugging-via-ohci1394.txt

Using physical DMA provided by OHCI-FireWire controllers for debugging

[77] dell_rbu.txt

Purpose:
Demonstrate the usage of the new open sourced rbu (Remote BIOS Update) driver
for updating BIOS images on Dell servers and desktops.

[78] devices.txt

This list is the Linux Device List, the official registry of allocated device
numbers and /dev directory nodes for the Linux operating system.

[79] dmaengine.txt

Below is a guide to device driver writers on how to use the Slave-DMA API of
the DMA Engine. This is applicable only for slave DMA usage only

[80] dontdiff.txt

[81] dynamic-debug-howto.txt

This document describes how to use the dynamic debug (ddebug) feature.

Dynamic debug is designed to allow you to dynamically enable/disable kernel
code to obtain additional kernel information. Currently, if
CONFIG_DYNAMIC_DEBUG is set, then all pr_debug()/dev_dbg() calls can be
dynamically enabled per-callsite.

Dynamic debug has even more useful features:

 * Simple query language allows turning on and off debugging statements by
   matching any combination of:

   - source filename
   - function name
   - line number (including ranges of line numbers)
   - module name
   - format string

 * Provides a debugfs control file: <debugfs>/dynamic_debug/control which can
 * be read to display the complete list of known debug statements, to help guide
   you

[82] edac.txt

EDAC, error detection and correction.

The 'edac' kernel module goal is to detect and report errors that occur within
the computer system running under linux.

[83] eisa.txt

EISA bus support.

[84] email-clients.txt

Email clients info for Linux.
介绍了在通过email提交linux内核补丁信息时的一些与email客户端相关的注意事项，例
如使用Alphine、Evolution、Kmail、Lotus Notes、Mutt、Pine、Sylpheed、
Thunderbird、TkRat、Gmail Web等。

[85] feature-removal-schedule.txt

The following is a list of files and features that are going to be removed in
the kernel source tree.  Every entry should contain what exactly is going
away, why it is happening, and who is going to be doing the work.  When the
feature is removed from the kernel, it should also be removed from this file.

Mon Sep 29 012:03:32 CST 2014

[86] flexible-arrays.txt

Large contiguous memory allocations can be unreliable in the Linux kernel.
Kernel programmers will sometimes respond to this problem by allocating pages
with vmalloc().  This solution not ideal, though.  On 32-bit systems, memory
from vmalloc() must be mapped into a relatively small address space; it's easy
to run out.  On SMP systems, the page table changes required by vmalloc()
allocations can require expensive cross-processor interrupts on all CPUs.
And, on all systems, use of space in the vmalloc() range increases pressure on
the translation lookaside buffer (TLB), reducing the erformance of the system

[87] futex-requeue-pi.txt

Futex Requeue PI
----------------

Requeueing of tasks from a non-PI futex to a PI futex requires special
handling in order to ensure the underlying rt_mutex is never left without an
owner if it has waiters; doing so would break the PI boosting logic [see
rt-mutex-desgin.txt] For the purposes of brevity, this action will be referred
to as "requeue_pi" throughout this document.  Priority inheritance is
abbreviated throughout as "PI".

[88] gcov.txt

Using gcov with the Linux kernel

[89] gpio.txt

A "General Purpose Input/Output" (GPIO) is a flexible software-controlled
digital signal.  They are provided from many kinds of chip, and are familiar
to Linux developers working with embedded and custom hardware.

[90] highuid.txt

Notes on the change from 16-bit UIDs to 32-bit UIDs:

- kernel code MUST take into account __kernel_uid_t and __kernel_uid32_t when
communicating between user and kernel space in an ioctl or data structure.

- kernel code should use uid_t and gid_t in kernel-private structures and
code.

[91] hw_random.txt

Introduction:

The hw_random framework is software that makes use of a special hardware
feature on your CPU or motherboard, a Random Number Generator (RNG).  The
software has two parts: core providing the /dev/hw_random character device and
its sysfs support, plus a hardware-specific driver that plugs into that core.

To make the most effective use of these mechanisms, you should download the
support software as well.  Download the latest version of the "rng-tools"
package from the hw_random driver's official Web site:

        http://sourceforge.net/projects/gkernel/

Those tools use /dev/hw_random to fill the kernel entropy pool, which is used
internally and exported by the /dev/urandom and /dev/random special files.

[92] hwspinlock.txt

Hardware Spinlock Framework

[93] init.txt

Explaining the dreaded "No init found." boot hang message

[94] initrd.txt

Using the initial RAM disk (initrd)

initrd provides the capability to load a RAM disk by the boot loader.  This
RAM disk can then be mounted as the root file system and programs can be run
from it. Afterwards, a new root file system can be mounted from a different
device. The previous root (from initrd) is then moved to a directory and can
be subsequently unmounted.
    
initrd is mainly designed to allow system startup to occur in two phases,
where the kernel comes up with a minimum set of compiled-in drivers, and where
additional modules are loaded from initrd.
    
This document gives a brief overview of the use of initrd. A more detailed
discussion of the boot process can be found in [1].
        

Operation

When using initrd, the system typically boots as follows:
    
  1) the boot loader loads the kernel and the initial RAM disk

  2) the kernel converts initrd into a "normal" RAM disk and frees the memory
     used by initrd

  3) if the root device is not /dev/ram0, the old (deprecated) change_root
     procedure is followed. see the "Obsolete root change mechanism" section
     below.

  4) root device is mounted. if it is /dev/ram0, the initrd image is then
     mounted as root

  5) /sbin/init is executed (this can be any valid executable, including shell
     scripts; it is run with uid 0 and can do basically everything init can
     do).

  6) init mounts the "real" root file system

  7) init places the root file system at the root directory using the
     pivot_root system call

  8) init execs the /sbin/init on the new root filesystem, performing the
     usual boot sequence

  9) the initrd file system is removed

    Note that changing the root directory does not involve unmounting it.  It
    is therefore possible to leave processes running on initrd during that
    procedure. Also note that file systems mounted under initrd continue to be
    accessible.

[95] intel_txt.txt

Intel(R) TXT Overview:

Intel's technology for safer computing, Intel(R) Trusted Execution Technology
(Intel(R) TXT), defines platform-level enhancements that provide the building
blocks for creating trusted platforms.

Intel TXT was formerly known by the code name LaGrande Technology (LT).

Intel TXT in Brief:
o  Provides dynamic root of trust for measurement (DRTM)
o  Data protection in case of improper shutdown
o  Measurement and verification of launched environment
    
Intel TXT is part of the vPro(TM) brand and is also available some non-vPro
systems.  It is currently available on desktop systems based on the Q35, X38,
    Q45, and Q43 Express chipsets (e.g. Dell Optiplex 755, HP dc7800, etc.)
    and mobile systems based on the GM45, PM45, and GS45 Express chipsets.

[96] io-mapping.txt

The io_mapping functions in linux/io-mapping.h provide an abstraction for
efficiently mapping small regions of an I/O device to the CPU. The initial
usage is to support the large graphics aperture on 32-bit processors where
ioremap_wc cannot be used to statically map the entire aperture to the CPU as
it would consume too much of the kernel address space.

[97] io_ordering.txt

On some platforms, so-called memory-mapped I/O is weakly ordered.  On such
platforms, driver writers are responsible for ensuring that I/O writes to
memory-mapped addresses on their device arrive in the order intended.  This is
typically done by reading a 'safe' device or bridge register, causing the I/O
chipset to flush pending writes to the device before any reads are posted.  A
driver would usually use this technique immediately prior to the exit of a
critical section of code protected by spinlocks.  This would ensure that
subsequent writes to I/O space arrived only after all prior writes (much like
a memory barrier op, mb(), only with respect to I/O).

[98] iostats.txt

I/O statistics fields

Since 2.4.20 (and some versions before, with patches), and 2.5.45, more
extensive disk statistics have been introduced to help measure disk activity.
Tools such as sar and iostat typically interpret these and do the work for
you, but in case you are interested in creating your own tools, the fields are
explained here.

[99] irqflags-tracing.txt

IRQ-flags state tracing

the "irq-flags tracing" feature "traces" hardirq and softirq state, in that it
gives interested subsystems an opportunity to be notified of every
hardirqs-off/hardirqs-on, softirqs-off/softirqs-on event that happens in the
kernel.

[100] isapnp.txt

ISA Plug & Play support

[101] java.txt

Java(tm) Binary Kernel Support for Linv1.03

Linux beats them ALL! While all other OS's are TALKING about direct of Java
Binaries in the OS, Linux is doing it!

[101] kernel-doc-nano-HOWTO.txt

[102] kernel-docs.txt

这篇文档列出了很多文档的索引以及参考书目，要经常看这些书目。

Index of Documentation for People Interested in Writing and/or
Understanding the Linux Kernel.
Juan-Mariano de Goyeneche <jmseyas@dit.upm.es>

The need for a document like this one became apparent in the linux-kernel
mailing list as the same questions, asking for pointers to information,
appeared again and again.

Fortunately, as more and more people get to GNU/Linux, more and more get
interested in the Kernel. But reading the sources is not always enough. It is
easy to understand the code, but miss the concepts, the philosophy and design
decisions behind this code.

Unfortunately, not many documents are available for beginners to start.
And, even if they exist, there was no "well-known" place which kept track
of them. These lines try to cover this lack. All documents available on
line known by the author are listed, while some reference books are also
mentioned.

PLEASE, if you know any paper not listed here or write a new document,
send me an e-mail, and I'll include a reference to it here. Any
corrections, ideas or comments are also welcomed.

The papers that follow are listed in no particular order. All are
cataloged with the following fields: the document's "Title", the
"Author"/s, the "URL" where they can be found, some "Keywords" helpful
when searching for specific topics, and a brief "Description" of the
Document.

Enjoy!

ON-LINE DOCS:

* Title: "Linux Device Drivers, Third Edition"
Author: Jonathan Corbet, Alessandro Rubini, Greg Kroah-Hartman
URL: http://lwn.net/Kernel/LDD3/
Description: A 600-page book covering the (2.6.10) driver
programming API and kernel hacking in general.  Available under the
Creative Commons Attribution-ShareAlike 2.0 license.

* Title: "The Linux Kernel"
Author: David A. Rusling.
URL: http://www.tldp.org/LDP/tlk/tlk.html
Keywords: everything!, book.
Description: On line, 200 pages book describing most aspects of
the Linux Kernel. Probably, the first reference for beginners.
Lots of illustrations explaining data structures use and
relationships in the purest Richard W. Stevens' style. Contents:
"1.-Hardware Basics, 2.-Software Basics, 3.-Memory Management,
4.-Processes, 5.-Interprocess Communication Mechanisms, 6.-PCI,
7.-Interrupts and Interrupt Handling, 8.-Device Drivers, 9.-The
File system, 10.-Networks, 11.-Kernel Mechanisms, 12.-Modules,
13.-The Linux Kernel Sources, A.-Linux Data Structures, B.-The
Alpha AXP Processor, C.-Useful Web and FTP Sites, D.-The GNU
General Public License, Glossary". In short: a must have.

* Title: "Linux Device Drivers, 2nd Edition"
Author: Alessandro Rubini and Jonathan Corbet.
URL: http://www.xml.com/ldd/chapter/book/index.html
Keywords: device drivers, modules, debugging, memory, hardware,
interrupt handling, char drivers, block drivers, kmod, mmap, DMA,
buses.
Description: O'Reilly's popular book, now also on-line under the
GNU Free Documentation License.
Notes: You can also buy it in paper-form from O'Reilly. See below
under BOOKS (Not on-line).

* Title: "Conceptual Architecture of the Linux Kernel"
Author: Ivan T. Bowman.
URL: http://plg.uwaterloo.ca/
Keywords: conceptual software architecture, extracted design,
reverse engineering, system structure.
Description: Conceptual software architecture of the Linux kernel,
automatically extracted from the source code. Very detailed. Good
figures. Gives good overall kernel understanding.

* Title: "Concrete Architecture of the Linux Kernel"
Author: Ivan T. Bowman, Saheem Siddiqi, and Meyer C. Tanuan.
URL: http://plg.uwaterloo.ca/
Keywords: concrete architecture, extracted design, reverse
engineering, system structure, dependencies.
Description: Concrete architecture of the Linux kernel,
automatically extracted from the source code. Very detailed. Good
figures. Gives good overall kernel understanding. This papers
focus on lower details than its predecessor (files, variables...).

* Title: "Linux as a Case Study: Its Extracted Software
Architecture"
Author: Ivan T. Bowman, Richard C. Holt and Neil V. Brewster.
URL: http://plg.uwaterloo.ca/
Keywords: software architecture, architecture recovery,
redocumentation.
Description: Paper appeared at ICSE'99, Los Angeles, May 16-22,
1999. A mixture of the previous two documents from the same
author.

* Title: "Overview of the Virtual File System"
Author: Richard Gooch.
URL: http://www.mjmwired.net/kernel/Documentation/filesystems/vfs.txt
Keywords: VFS, File System, mounting filesystems, opening files,
dentries, dcache.
Description: Brief introduction to the Linux Virtual File System.
What is it, how it works, operations taken when opening a file or
mounting a file system and description of important data
structures explaining the purpose of each of their entries.

* Title: "The Linux RAID-1, 4, 5 Code"
Author: Ingo Molnar, Gadi Oxman and Miguel de Icaza.
URL: http://www.linuxjournal.com/article.php?sid=2391
Keywords: RAID, MD driver.
Description: Linux Journal Kernel Korner article. Here is its
abstract: "A description of the implementation of the RAID-1,
RAID-4 and RAID-5 personalities of the MD device driver in the
Linux kernel, providing users with high performance and reliable,
secondary-storage capability using software".

* Title: "Dynamic Kernels: Modularized Device Drivers"
Author: Alessandro Rubini.
URL: http://www.linuxjournal.com/article.php?sid=1219
Keywords: device driver, module, loading/unloading modules,
allocating resources.
Description: Linux Journal Kernel Korner article. Here is its
abstract: "This is the first of a series of four articles
co-authored by Alessandro Rubini and Georg Zezchwitz which present
a practical approach to writing Linux device drivers as kernel
loadable modules. This installment presents an introduction to the
topic, preparing the reader to understand next month's
installment".

* Title: "Dynamic Kernels: Discovery"
Author: Alessandro Rubini.
URL: http://www.linuxjournal.com/article.php?sid=1220
Keywords: character driver, init_module, clean_up module,
autodetection, mayor number, minor number, file operations,
open(), close().
Description: Linux Journal Kernel Korner article. Here is its
abstract: "This article, the second of four, introduces part of
the actual code to create custom module implementing a character
device driver. It describes the code for module initialization and
cleanup, as well as the open() and close() system calls".

* Title: "The Devil's in the Details"
Author: Georg v. Zezschwitz and Alessandro Rubini.
URL: http://www.linuxjournal.com/article.php?sid=1221
Keywords: read(), write(), select(), ioctl(), blocking/non
blocking mode, interrupt handler.
Description: Linux Journal Kernel Korner article. Here is its
abstract: "This article, the third of four on writing character
device drivers, introduces concepts of reading, writing, and using
ioctl-calls".

* Title: "Dissecting Interrupts and Browsing DMA"
Author: Alessandro Rubini and Georg v. Zezschwitz.
URL: http://www.linuxjournal.com/article.php?sid=1222
Keywords: interrupts, irqs, DMA, bottom halves, task queues.
Description: Linux Journal Kernel Korner article. Here is its
abstract: "This is the fourth in a series of articles about
writing character device drivers as loadable kernel modules. This
month, we further investigate the field of interrupt handling.
Though it is conceptually simple, practical limitations and
constraints make this an ``interesting'' part of device driver
writing, and several different facilities have been provided for
different situations. We also investigate the complex topic of
DMA".

* Title: "Device Drivers Concluded"
Author: Georg v. Zezschwitz.
URL: http://www.linuxjournal.com/article.php?sid=1287
Keywords: address spaces, pages, pagination, page management,
demand loading, swapping, memory protection, memory mapping, mmap,
virtual memory areas (VMAs), vremap, PCI.
Description: Finally, the above turned out into a five articles
series. This latest one's introduction reads: "This is the last of
five articles about character device drivers. In this final
section, Georg deals with memory mapping devices, beginning with
an overall description of the Linux memory management concepts".

* Title: "Network Buffers And Memory Management"
Author: Alan Cox.
URL: http://www.linuxjournal.com/article.php?sid=1312
Keywords: sk_buffs, network devices, protocol/link layer
variables, network devices flags, transmit, receive,
configuration, multicast.
Description: Linux Journal Kernel Korner. Here is the abstract:
"Writing a network device driver for Linux is fundamentally
simple---most of the complexity (other than talking to the
hardware) involves managing network packets in memory".

* Title: "Writing Linux Device Drivers"
Author: Michael K. Johnson.
URL: http://users.evitech.fi/~tk/rtos/writing_linux_device_d.html
Keywords: files, VFS, file operations, kernel interface, character
vs block devices, I/O access, hardware interrupts, DMA, access to
user memory, memory allocation, timers.
Description: Introductory 50-minutes (sic) tutorial on writing
device drivers. 12 pages written by the same author of the "Kernel
Hackers' Guide" which give a very good overview of the topic.

* Title: "The Venus kernel interface"
Author: Peter J. Braam.
URL:
http://www.coda.cs.cmu.edu/doc/html/kernel-venus-protocol.html
Keywords: coda, filesystem, venus, cache manager.
Description: "This document describes the communication between
Venus and kernel level file system code needed for the operation
of the Coda filesystem. This version document is meant to describe
the current interface (version 1.0) as well as improvements we
envisage".

* Title: "Programming PCI-Devices under Linux"
Author: Claus Schroeter.
URL:
ftp://ftp.llp.fu-berlin.de/pub/linux/LINUX-LAB/whitepapers/pcip.ps.gz
Keywords: PCI, device, busmastering.
Description: 6 pages tutorial on PCI programming under Linux.
Gives the basic concepts on the architecture of the PCI subsystem,
as long as basic functions and macros to read/write the devices
and perform busmastering.

* Title: "Writing Character Device Driver for Linux"
Author: R. Baruch and C. Schroeter.
URL:
ftp://ftp.llp.fu-berlin.de/pub/linux/LINUX-LAB/whitepapers/drivers.ps.gz
Keywords: character device drivers, I/O, signals, DMA, accessing
ports in user space, kernel environment.
Description: 68 pages paper on writing character drivers. A little
bit old (1.993, 1.994) although still useful.

* Title: "Design and Implementation of the Second Extended
Filesystem"
Author: Rémy Card, Theodore Ts'o, Stephen Tweedie.
URL: http://web.mit.edu/tytso/www/linux/ext2intro.html
Keywords: ext2, linux fs history, inode, directory, link, devices,
VFS, physical structure, performance, benchmarks, ext2fs library,
ext2fs tools, e2fsck.
Description: Paper written by three of the top ext2 hackers.
Covers Linux filesystems history, ext2 motivation, ext2 features,
design, physical structure on disk, performance, benchmarks,
e2fsck's passes description... A must read!
Notes: This paper was first published in the Proceedings of the
First Dutch International Symposium on Linux, ISBN 90-367-0385-9.

* Title: "Analysis of the Ext2fs structure"
Author: Louis-Dominique Dubeau.
URL: http://www.nondot.org/sabre/os/files/FileSystems/ext2fs/
Keywords: ext2, filesystem, ext2fs.
Description: Description of ext2's blocks, directories, inodes,
bitmaps, invariants...

* Title: "Journaling the Linux ext2fs Filesystem"
Author: Stephen C. Tweedie.
URL:
ftp://ftp.uk.linux.org/pub/linux/sct/fs/jfs/journal-design.ps.gz
Keywords: ext3, journaling.
Description: Excellent 8-pages paper explaining the journaling
capabilities added to ext2 by the author, showing different
problems faced and the alternatives chosen.

* Title: "Kernel API changes from 2.0 to 2.2"
Author: Richard Gooch.
URL:
http://www.linuxhq.com/guides/LKMPG/node28.html 
Keywords: 2.2, changes.
Description: Kernel functions/structures/variables which changed
from 2.0.x to 2.2.x.

* Title: "Kernel API changes from 2.2 to 2.4"
Author: Richard Gooch.
Keywords: 2.4, changes.
Description: Kernel functions/structures/variables which changed
from 2.2.x to 2.4.x.

* Title: "Linux Kernel Module Programming Guide"
Author: Ori Pomerantz.
URL: http://tldp.org/LDP/lkmpg/2.6/html/index.html
Keywords: modules, GPL book, /proc, ioctls, system calls,
interrupt handlers .
Description: Very nice 92 pages GPL book on the topic of modules
programming. Lots of examples.

* Title: "I/O Event Handling Under Linux"
Author: Richard Gooch.
Keywords: IO, I/O, select(2), poll(2), FDs, aio_read(2), readiness
event queues.
Description: From the Introduction: "I/O Event handling is about
how your Operating System allows you to manage a large number of
open files (file descriptors in UNIX/POSIX, or FDs) in your
application. You want the OS to notify you when FDs become active
(have data ready to be read or are ready for writing). Ideally you
want a mechanism that is scalable. This means a large number of
inactive FDs cost very little in memory and CPU time to manage".

* Title: "The Kernel Hacking HOWTO"
Author: Various Talented People, and Rusty.
Location: in kernel tree, Documentation/DocBook/kernel-hacking.tmpl
(must be built as "make {htmldocs | psdocs | pdfdocs})
Keywords: HOWTO, kernel contexts, deadlock, locking, modules,
symbols, return conventions.
Description: From the Introduction: "Please understand that I
never wanted to write this document, being grossly underqualified,
but I always wanted to read it, and this was the only way. I
simply explain some best practices, and give reading entry-points
into the kernel sources. I avoid implementation details: that's
what the code is for, and I ignore whole tracts of useful
routines. This document assumes familiarity with C, and an
understanding of what the kernel is, and how it is used. It was
originally written for the 2.3 kernels, but nearly all of it
applies to 2.2 too; 2.0 is slightly different".

* Title: "Writing an ALSA Driver"
Author: Takashi Iwai <tiwai@suse.de>
URL: http://www.alsa-project.org/~iwai/writing-an-alsa-driver/index.html
Keywords: ALSA, sound, soundcard, driver, lowlevel, hardware.
Description: Advanced Linux Sound Architecture for developers,
both at kernel and user-level sides. ALSA is the Linux kernel
sound architecture in the 2.6 kernel version.

* Title: "Programming Guide for Linux USB Device Drivers"
Author: Detlef Fliegl.
URL: http://usb.in.tum.de/usbdoc/
Keywords: USB, universal serial bus.
Description: A must-read. From the Preface: "This document should
give detailed information about the current state of the USB
subsystem and its API for USB device drivers. The first section
will deal with the basics of USB devices. You will learn about
different types of devices and their properties. Going into detail
you will see how USB devices communicate on the bus. The second
section gives an overview of the Linux USB subsystem [2] and the
device driver framework. Then the API and its data structures will
be explained step by step. The last section of this document
contains a reference of all API calls and their return codes".
Notes: Beware: the main page states: "This document may not be
published, printed or used in excerpts without explicit permission
of the author". Fortunately, it may still be read...

* Title: "Linux Kernel Mailing List Glossary"
Author: various
URL: http://kernelnewbies.org/glossary/
Keywords: glossary, terms, linux-kernel.
Description: From the introduction: "This glossary is intended as
a brief description of some of the acronyms and terms you may hear
during discussion of the Linux kernel".

* Title: "Linux Kernel Locking HOWTO"
Author: Various Talented People, and Rusty.
Location: in kernel tree, Documentation/DocBook/kernel-locking.tmpl
(must be built as "make {htmldocs | psdocs | pdfdocs})
Keywords: locks, locking, spinlock, semaphore, atomic, race
condition, bottom halves, tasklets, softirqs.
Description: The title says it all: document describing the
locking system in the Linux Kernel either in uniprocessor or SMP
systems.
Notes: "It was originally written for the later (>2.3.47) 2.3
kernels, but most of it applies to 2.2 too; 2.0 is slightly
different". Freely redistributable under the conditions of the GNU
General Public License.

* Title: "Global spinlock list and usage"
Author: Rick Lindsley.
URL: http://lse.sourceforge.net/lockhier/global-spin-lock
Keywords: spinlock.
Description: This is an attempt to document both the existence and
usage of the spinlocks in the Linux 2.4.5 kernel. Comprehensive
list of spinlocks showing when they are used, which functions
access them, how each lock is acquired, under what conditions it
is held, whether interrupts can occur or not while it is held...

* Title: "Porting Linux 2.0 Drivers To Linux 2.2: Changes and New
Features "
Author: Alan Cox.
URL: http://www.linux-mag.com/1999-05/gear_01.html
Keywords: ports, porting.
Description: Article from Linux Magazine on porting from 2.0 to
2.2 kernels.

* Title: "Porting Device Drivers To Linux 2.2: part II"
Author: Alan Cox.
URL: http://www.linux-mag.com/id/238 
Keywords: ports, porting.
Description: Second part on porting from 2.0 to 2.2 kernels.

* Title: "How To Make Sure Your Driver Will Work On The Power
Macintosh"
Author: Paul Mackerras.
URL: http://www.linux-mag.com/id/261
Keywords: Mac, Power Macintosh, porting, drivers, compatibility.
Description: The title says it all.

* Title: "An Introduction to SCSI Drivers"
Author: Alan Cox.
URL: http://www.linux-mag.com/id/284
Keywords: SCSI, device, driver.
Description: The title says it all.

* Title: "Advanced SCSI Drivers And Other Tales"
Author: Alan Cox.
URL: http://www.linux-mag.com/id/307
Keywords: SCSI, device, driver, advanced.
Description: The title says it all.

* Title: "Writing Linux Mouse Drivers"
Author: Alan Cox.
URL: http://www.linux-mag.com/id/330
Keywords: mouse, driver, gpm.
Description: The title says it all.

* Title: "More on Mouse Drivers"
Author: Alan Cox.
URL: http://www.linux-mag.com/id/356
Keywords: mouse, driver, gpm, races, asynchronous I/O.
Description: The title still says it all.

* Title: "Writing Video4linux Radio Driver"
Author: Alan Cox.
URL: http://www.linux-mag.com/id/381
Keywords: video4linux, driver, radio, radio devices.
Description: The title says it all.

* Title: "Video4linux Drivers, Part 1: Video-Capture Device"
Author: Alan Cox.
URL: http://www.linux-mag.com/id/406
Keywords: video4linux, driver, video capture, capture devices,
camera driver.
Description: The title says it all.

* Title: "Video4linux Drivers, Part 2: Video-capture Devices"
Author: Alan Cox.
URL: http://www.linux-mag.com/id/429
Keywords: video4linux, driver, video capture, capture devices,
camera driver, control, query capabilities, capability, facility.
Description: The title says it all.

* Title: "PCI Management in Linux 2.2"
Author: Alan Cox.
URL: http://www.linux-mag.com/id/452
Keywords: PCI, bus, bus-mastering.
Description: The title says it all.

* Title: "Linux 2.4 Kernel Internals"
Author: Tigran Aivazian and Christoph Hellwig.
URL: http://www.moses.uklinux.net/patches/lki.html
Keywords: Linux, kernel, booting, SMB boot, VFS, page cache.
Description: A little book used for a short training course.
Covers building the kernel image, booting (including SMP bootup),
process management, VFS and more.

* Title: "Linux IP Networking. A Guide to the Implementation and
Modification of the Linux Protocol Stack."
Author: Glenn Herrin.
URL: http://www.cs.unh.edu/cnrg/gherrin
Keywords: network, networking, protocol, IP, UDP, TCP, connection,
socket, receiving, transmitting, forwarding, routing, packets,
modules, /proc, sk_buff, FIB, tags.
Description: Excellent paper devoted to the Linux IP Networking,
explaining anything from the kernel's to the user space
configuration tools' code. Very good to get a general overview of
the kernel networking implementation and understand all steps
packets follow from the time they are received at the network
device till they are delivered to applications. The studied kernel
code is from 2.2.14 version. Provides code for a working packet
dropper example.

* Title: "Get those boards talking under Linux."
Author: Alex Ivchenko.
URL: http://www.edn.com/article/CA46968.html
Keywords: data-acquisition boards, drivers, modules, interrupts,
memory allocation.
Description: Article written for people wishing to make their data
acquisition boards work on their GNU/Linux machines. Gives a basic
overview on writing drivers, from the naming of functions to
interrupt handling.
Notes: Two-parts article. Part II is at
URL: http://www.edn.com/article/CA46998.html

* Title: "Linux PCMCIA Programmer's Guide"
Author: David Hinds.
URL: http://pcmcia-cs.sourceforge.net/ftp/doc/PCMCIA-PROG.html
Keywords: PCMCIA.
Description: "This document describes how to write kernel device
drivers for the Linux PCMCIA Card Services interface. It also
describes how to write user-mode utilities for communicating with
Card Services.

* Title: "The Linux Kernel NFSD Implementation"
Author: Neil Brown.
URL:
http://www.cse.unsw.edu.au/~neilb/oss/linux-commentary/nfsd.html
Keywords: knfsd, nfsd, NFS, RPC, lockd, mountd, statd.
Description: The title says it all.
Notes: Covers knfsd's version 1.4.7 (patch against 2.2.7 kernel).

* Title: "A Linux vm README"
Author: Kanoj Sarcar.
URL: http://kos.enix.org/pub/linux-vmm.html
Keywords: virtual memory, mm, pgd, vma, page, page flags, page
cache, swap cache, kswapd.
Description: Telegraphic, short descriptions and definitions
relating the Linux virtual memory implementation.

* Title: "(nearly) Complete Linux Loadable Kernel Modules. The
definitive guide for hackers, virus coders and system
administrators."
Author: pragmatic/THC.
URL: http://packetstormsecurity.org/docs/hack/LKM_HACKING.html
Keywords: syscalls, intercept, hide, abuse, symbol table.
Description: Interesting paper on how to abuse the Linux kernel in
order to intercept and modify syscalls, make
files/directories/processes invisible, become root, hijack ttys,
write kernel modules based virus... and solutions for admins to
avoid all those abuses.
Notes: For 2.0.x kernels. Gives guidances to port it to 2.2.x
kernels.

BOOKS: (Not on-line)

* Title: "Linux Device Drivers"
Author: Alessandro Rubini.
Publisher: O'Reilly & Associates.
Date: 1998.
Pages: 439.
ISBN: 1-56592-292-1

* Title: "Linux Device Drivers, 2nd Edition"
Author: Alessandro Rubini and Jonathan Corbet.
Publisher: O'Reilly & Associates.
Date: 2001.
Pages: 586.
ISBN: 0-59600-008-1
Notes: Further information in
http://www.oreilly.com/catalog/linuxdrive2/

* Title: "Linux Device Drivers, 3rd Edition"
Authors: Jonathan Corbet, Alessandro Rubini, and Greg Kroah-Hartman
Publisher: O'Reilly & Associates.
Date: 2005.
Pages: 636.
ISBN: 0-596-00590-3
Notes: Further information in
http://www.oreilly.com/catalog/linuxdrive3/
PDF format, URL: http://lwn.net/Kernel/LDD3/

* Title: "Linux Kernel Internals"
Author: Michael Beck.
Publisher: Addison-Wesley.
Date: 1997.
ISBN: 0-201-33143-8 (second edition)

* Title: "The Design of the UNIX Operating System"
Author: Maurice J. Bach.
Publisher: Prentice Hall.
Date: 1986.
Pages: 471.
ISBN: 0-13-201757-1

* Title: "The Design and Implementation of the 4.3 BSD UNIX
Operating System"
Author: Samuel J. Leffler, Marshall Kirk McKusick, Michael J.
Karels, John S. Quarterman.
Publisher: Addison-Wesley.
Date: 1989 (reprinted with corrections on October, 1990).
ISBN: 0-201-06196-1

* Title: "The Design and Implementation of the 4.4 BSD UNIX
Operating System"
Author: Marshall Kirk McKusick, Keith Bostic, Michael J. Karels,
John S. Quarterman.
Publisher: Addison-Wesley.
Date: 1996.
ISBN: 0-201-54979-4

* Title: "Programmation Linux 2.0 API systeme et fonctionnement du
noyau"
Author: Remy Card, Eric Dumas, Franck Mevel.
Publisher: Eyrolles.
Date: 1997.
Pages: 520.
ISBN: 2-212-08932-5
Notes: French.

* Title: "Unix internals -- the new frontiers"
Author: Uresh Vahalia.
Publisher: Prentice Hall.
Date: 1996.
Pages: 600.
ISBN: 0-13-101908-2

* Title: "Programming for the real world - POSIX.4"
Author: Bill O. Gallmeister.
Publisher: O'Reilly & Associates, Inc..
Date: 1995.
Pages: ???.
ISBN: I-56592-074-0
Notes: Though not being directly about Linux, Linux aims to be
POSIX. Good reference.

* Title:  "UNIX  Systems  for  Modern Architectures: Symmetric
Multiprocessing and Caching for Kernel Programmers"
Author: Curt Schimmel.
Publisher: Addison Wesley.
Date: June, 1994.
Pages: 432.
ISBN: 0-201-63338-8

MISCELLANEOUS:

* Name: linux/Documentation
Author: Many.
URL: Just look inside your kernel sources.
Keywords: anything, DocBook.
Description: Documentation that comes with the kernel sources,
inside the Documentation directory. Some pages from this document
(including this document itself) have been moved there, and might
be more up to date than the web version.

* Name: "Linux Kernel Source Reference"
Author: Thomas Graichen.
URL: http://marc.info/?l=linux-kernel&m=96446640102205&w=4
Keywords: CVS, web, cvsweb, browsing source code.
Description: Web interface to a CVS server with the kernel
sources. "Here you can have a look at any file of the Linux kernel
sources of any version starting from 1.0 up to the (daily updated)
current version available. Also you can check the differences
between two versions of a file".

* Name: "Cross-Referencing Linux"
URL: http://lxr.linux.no/source/
Keywords: Browsing source code.
Description: Another web-based Linux kernel source code browser.
Lots of cross references to variables and functions. You can see
where they are defined and where they are used.

* Name: "Linux Weekly News"
URL: http://lwn.net
Keywords: latest kernel news.
Description: The title says it all. There's a fixed kernel section
summarizing developers' work, bug fixes, new features and versions
produced during the week. Published every Thursday.

* Name: "Kernel Traffic"
URL: http://kt.earth.li/kernel-traffic/index.html
Keywords: linux-kernel mailing list, weekly kernel news.
Description: Weekly newsletter covering the most relevant
discussions of the linux-kernel mailing list.

* Name: "CuTTiNG.eDGe.LiNuX"
URL: http://edge.kernelnotes.org
Keywords: changelist.
Description: Site which provides the changelist for every kernel
release. What's new, what's better, what's changed. Myrdraal reads
the patches and describes them. Pointers to the patches are there,
too.

* Name: "New linux-kernel Mailing List FAQ"
URL: http://www.tux.org/lkml/
Keywords: linux-kernel mailing list FAQ.
Description: linux-kernel is a mailing list for developers to
communicate. This FAQ builds on the previous linux-kernel mailing
list FAQ maintained by Frohwalt Egerer, who no longer maintains
it. Read it to see how to join the mailing list. Dozens of
interesting questions regarding the list, Linux, developers (who
is ...?), terms (what is...?) are answered here too. Just read it.

* Name: "Linux Virtual File System"
Author: Peter J. Braam.
URL: http://www.coda.cs.cmu.edu/doc/talks/linuxvfs/
Keywords: slides, VFS, inode, superblock, dentry, dcache.
Description: Set of slides, presumably from a presentation on the
Linux VFS layer. Covers version 2.1.x, with dentries and the
dcache.

* Name: "Gary's Encyclopedia - The Linux Kernel"
Author: Gary (I suppose...).
URL: http://slencyclopedia.berlios.de/index.html
Keywords: linux, community, everything!
Description: Gary's Encyclopedia exists to allow the rapid finding
of documentation and other information of interest to GNU/Linux
users. It has about 4000 links to external pages in 150 major
categories. This link is for kernel-specific links, documents,
sites...  This list is now hosted by developer.Berlios.de,
but seems not to have been updated since sometime in 1999.

* Name: "The home page of Linux-MM"
Author: The Linux-MM team.
URL: http://linux-mm.org/
Keywords: memory management, Linux-MM, mm patches, TODO, docs,
mailing list.
Description: Site devoted to Linux Memory Management development.
Memory related patches, HOWTOs, links, mm developers... Don't miss
it if you are interested in memory management development!

* Name: "Kernel Newbies IRC Channel"
URL: http://www.kernelnewbies.org
Keywords: IRC, newbies, channel, asking doubts.
Description: #kernelnewbies on irc.openprojects.net. From the web
page: "#kernelnewbies is an IRC network dedicated to the 'newbie'
kernel hacker. The audience mostly consists of people who are
learning about the kernel, working on kernel projects or
professional kernel hackers that want to help less seasoned kernel
people. [...] #kernelnewbies is on the Open Projects IRC Network,
try irc.openprojects.net or irc.<country>.openprojects.net as your
server and then /join #kernelnewbies". It also hosts articles,
documents, FAQs...

* Name: "linux-kernel mailing list archives and search engines"
URL: http://vger.kernel.org/vger-lists.html
URL: http://www.uwsg.indiana.edu/hypermail/linux/kernel/index.html
URL: http://marc.theaimsgroup.com/?l=linux-kernel
URL: http://groups.google.com/group/mlist.linux.kernel
URL: http://www.cs.helsinki.fi/linux/linux-kernel/
URL: http://www.lib.uaa.alaska.edu/linux-kernel/
Keywords: linux-kernel, archives, search.
Description: Some of the linux-kernel mailing list archivers. If
you have a better/another one, please let me know.

[103] kernel-parameters.txt

parameters may be changed at runtime by the command
"echo -n ${value} > /sys/module/${modulename}/parameters/${parm}".

内核参数可以通过上述命令进行调整，也可以在系统引导时通过grub传递内核参数。

The parameters listed in this document are only valid if certain kernel build
options were enabled and if respective hardware is present. 

内核参数太多了，这里不予列出，请查看kernel-parameters.txt。

=============================================================================
Mon Sep 29 10:17:39 CST 2014
=============================================================================

[104] kmemcheck.txt

kmemcheck用于内核的未初始化内存的动态检测，它工作在内核态，与工作在用户态的
memcheck实现机制不同。虽然kmemcheck不如memcheck精确，但是已经足够使用的了。此外，kmemcheck会使用更多的内存，增加系统负载，仅适合用于内核的调试。

kmemcheck is a debugging feature for the Linux Kernel. More specifically, it
is a dynamic checker that detects and warns about some uses of uninitialized
memory.

Userspace programmers might be familiar with Valgrind's memcheck. The main
difference between memcheck and kmemcheck is that memcheck works for userspace
programs only, and kmemcheck works for the kernel only. The implementations
are of course vastly different. Because of this, kmemcheck is not as accurate
as memcheck, but it turns out to be good enough in practice to discover real
programmer errors that the compiler is not able to find through static
analysis.

Enabling kmemcheck on a kernel will probably slow it down to the extent that
the machine will not be usable for normal workloads such as e.g. an
interactive desktop. kmemcheck will also cause the kernel to use about twice
as much memory as normal. For this reason, kmemcheck is strictly a debugging
feature.

[105] kmemleak.txt

kmemleak是一个工作在内核态，用于检测内核中内存泄漏的工具，与工作态的内存泄漏检
测工具memcheck加参数--leak-check工作时效果类似。
为了加深对内存管理的理解，应该查看下这两个工具的源代码。

Kernel Memory Leak Detector

Kmemleak provides a way of detecting possible kernel memory leaks in a way
similar to a tracing garbage collector

(http://en.wikipedia.org/wiki/
 Garbage_collection_%28computer_science%29#Tracing_garbage_collectors),
with the difference that the orphan objects are not freed but only reported
via /sys/kernel/debug/kmemleak. A similar method is used by the Valgrind tool
(memcheck --leak-check) to detect the memory leaks in user-space applications.

[106] kobject.txt

Everything you never wanted to know about kobjects, ksets, and ktypes

过去你不曾了解的关于kobjects\ksets\ktypes的一切。

Part of the difficulty in understanding the driver model - and the kobject
abstraction upon which it is built - is that there is no obvious starting
place. Dealing with kobjects requires understanding a few different types, all
of which make reference to each other. In an attempt to make things easier,
we'll take a multi-pass approach, starting with vague terms and adding detail
as we go. To that end, here are some quick definitions of some terms we will
be working with.

理解驱动模型以及在其上抽象出来的kobject的部分难点在于，没有明显的起始点。要想
理解kobjects，需要理解多种不同的类型，而这些类型都是相互不同的。为了尽可能使其
理解起来简单，我们将从头到尾讲解多遍，先讲述一些含糊的术语，然后再往其中添加相
应的细节。下面，是我们经常提到的一些常用术语的定义。

 - A kobject is an object of type struct kobject.  Kobjects have a name and a
   reference count.  A kobject also has a parent pointer (allowing objects to
   be arranged into hierarchies), a specific type, and, usually, a
   representation in the sysfs virtual filesystem.

   一个kobject是一个kobject结构体类型。每一个kobject都有一个名字一个引用计数，
   此外还具有一个指向parent指针（通过parent指针可以将多个kobject组织成不同的层
   次）、特定的类型，通常，还包括一个在虚拟文件系统sysfs(/proc/sys)中的代表。

   Kobjects are generally not interesting on their own; instead, they are
   usually embedded within some other structure which contains the stuff the
   code is really interested in.

   kobjects本身是没有什么特别意义的，它们通常被嵌入在其他的结构体中，这些嵌入
   了kobjects的结构体，再包含其他操作相关的数据结构，就变得有意义了。

   No structure should EVER have more than one kobject embedded within it.  If
   it does, the reference counting for the object is sure to be messed up and
   incorrect, and your code will be buggy.  So do not do this.

   任意一个结构体最多嵌套1个kobject，如果不这样的话，这个对象的引用计数就会出
   错，代码就会出现bug，所以切忌嵌套超过1个kobject。

 - A ktype is the type of object that embeds a kobject.  Every structure that
   embeds a kobject needs a corresponding ktype.  The ktype controls what
   happens to the kobject when it is created and destroyed.

   1个ktype是一个嵌套了kobject结构体的类型，每一个嵌套了kobject结构体的结构体
   类型都需要一个相应的ktype。这个ktype在创建或销毁其嵌入的kobject时，可以对其
   进行适当的操作。

 - A kset is a group of kobjects.  These kobjects can be of the same ktype or
   belong to different ktypes.  The kset is the basic container type for
   collections of kobjects. Ksets contain their own kobjects, but you can
   safely ignore that implementation detail as the kset core code handles this
   kobject automatically.

   1个kset是一组kobjects。这些kobjects可以是相同的ktype类型，也可以分属不同的
   ktype类型。这个kset是用于kobjects集合的一个基本的容器类型。ksets包含了它们
   自己的kobjects，但是你可以简单地忽略这些细节，这是安全的，因为kset的核心代
   码会自动处理kobject。

   When you see a sysfs directory full of other directories, generally each of
   those directories corresponds to a kobject in the same kset.

   当你看到一个包含了其他目录的sysfs目录(一般为/proc/sys)的时候，通常这些目录
   中的每一个都对应着相同kset中的一个kobject.

We'll look at how to create and manipulate all of these types. A bottom-up
approach will be taken, so we'll go back to kobjects.

下面，我们将看一看如何创建和操作所有的这些类型，我们将自底向上地对其进行描述，
所以我们现回到kobjects。

Embedding kobjects

It is rare for kernel code to create a standalone kobject, with one major
exception explained below.  Instead, kobjects are used to control access to a
larger, domain-specific object.  To this end, kobjects will be found embedded
in other structures.  If you are used to thinking of things in object-oriented
terms, kobjects can be seen as a top-level, abstract class from which other
classes are derived.  A kobject implements a set of capabilities which are not
particularly useful by themselves, but which are nice to have in other
objects.  The C language does not allow for the direct expression of
inheritance, so other techniques - such as structure embedding - must be used.

在内核代码中创建一个独立的kobject是很少见的，下面会介绍一种例外情况。一般地，
kobjects对象被用于控制对一个大对象、特定领域的对象。kobjects经长出现在其他结构
体中。如果你了解面向对象的相关术语、思想，kobjects可以被看作一个顶层的抽象类，
嵌套了该kobject的类则相当于kobject类的派生类。一个kobject实现了某些功能，这些
功能不是本身kobject需要的，但是如果将kobject嵌入到其他对象中之后，这些对
kobject本身来说不是特别关键的功能就变得非常有意义了。由于c语言不支持面向对象、
对象继承，因此必须通过其他手段来实现类似的继承机制，这里使用的是结构体嵌套。

(As an aside, for those familiar with the kernel linked list implementation,
this is analogous as to how "list_head" structs are rarely useful on their
own, but are invariably found embedded in the larger objects of interest.)

So, for example, the UIO code in drivers/uio/uio.c has a structure that
defines the memory region associated with a uio device:

    struct uio_map {
        struct kobject kobj;
        struct uio_mem *mem;
    };

If you have a struct uio_map structure, finding its embedded kobject is just a
matter of using the kobj member.  Code that works with kobjects will often
have the opposite problem, however: given a struct kobject pointer, what is
the pointer to the containing structure?  You must avoid tricks (such as
assuming that the kobject is at the beginning of the structure) and, instead,
use the container_of() macro, found in <linux/kernel.h>:

    container_of(pointer, type, member)

where:

  * "pointer" is the pointer to the embedded kobject,
  * "type" is the type of the containing structure, and
  * "member" is the name of the structure field to which "pointer" points.

The return value from container_of() is a pointer to the corresponding
container type. So, for example, a pointer "kp" to a struct kobject embedded
*within* a struct uio_map could be converted to a pointer to the *containing*
uio_map structure with:

    struct uio_map *u_map = container_of(kp, struct uio_map, kobj);

For convenience, programmers often define a simple macro for "back-casting"
kobject pointers to the containing type.  Exactly this happens in the earlier
drivers/uio/uio.c, as you can see here:

    struct uio_map {
        struct kobject kobj;
        struct uio_mem *mem;
    };
    
    #define to_map(map) container_of(map, struct uio_map, kobj)

where the macro argument "map" is a pointer to the struct kobject in question.
That macro is subsequently invoked with:

    struct uio_map *map = to_map(kobj);


Initialization of kobjects

Code which creates a kobject must, of course, initialize that object. Some of
the internal fields are setup with a (mandatory) call to kobject_init():

    void kobject_init(struct kobject *kobj, struct kobj_type *ktype);

The ktype is required for a kobject to be created properly, as every kobject
must have an associated kobj_type.  After calling kobject_init(), to register
the kobject with sysfs, the function kobject_add() must be called:

    int kobject_add(struct kobject *kobj, struct kobject *parent, const char *fmt, ...);

This sets up the parent of the kobject and the name for the kobject properly.
If the kobject is to be associated with a specific kset, kobj->kset must be
assigned before calling kobject_add().  If a kset is associated with a
kobject, then the parent for the kobject can be set to NULL in the call to
kobject_add() and then the kobject's parent will be the kset itself.

As the name of the kobject is set when it is added to the kernel, the name of
the kobject should never be manipulated directly.  If you must change the name
of the kobject, call kobject_rename():

    int kobject_rename(struct kobject *kobj, const char *new_name);

kobject_rename does not perform any locking or have a solid notion of what
names are valid so the caller must provide their own sanity checking and
serialization.

There is a function called kobject_set_name() but that is legacy cruft and is
being removed.  If your code needs to call this function, it is incorrect and
needs to be fixed.

To properly access the name of the kobject, use the function kobject_name():

    const char *kobject_name(const struct kobject * kobj);

There is a helper function to both initialize and add the kobject to the
kernel at the same time, called surprisingly enough kobject_init_and_add():

    int kobject_init_and_add(struct kobject *kobj, struct kobj_type *ktype,
                             struct kobject *parent, const char *fmt, ...);

The arguments are the same as the individual kobject_init() and kobject_add()
functions described above.

Uevents

After a kobject has been registered with the kobject core, you need to
announce to the world that it has been created.  This can be done with a call
to kobject_uevent():

    int kobject_uevent(struct kobject *kobj, enum kobject_action action);

Use the KOBJ_ADD action for when the kobject is first added to the kernel.
This should be done only after any attributes or children of the kobject have
been initialized properly, as userspace will instantly start to look for them
when this call happens.

When the kobject is removed from the kernel (details on how to do that is
below), the uevent for KOBJ_REMOVE will be automatically created by the
kobject core, so the caller does not have to worry about doing that by hand.


Reference counts

One of the key functions of a kobject is to serve as a reference counter for
the object in which it is embedded. As long as references to the object exist,
the object (and the code which supports it) must continue to exist.  The
low-level functions for manipulating a kobject's reference counts are:

kobject对象的一个关键作用就是充当嵌入它的对象的引用计数器，只要这个对象的引用
存在，这个对象就会一直存在。操作kobject引用计数的低级操作包括如下两个函数。

    struct kobject *kobject_get(struct kobject *kobj);
    void kobject_put(struct kobject *kobj);

A successful call to kobject_get() will increment the kobject's reference
counter and return the pointer to the kobject.

成功调用kobject_get将会增加kobject的引用技术，并返回指向kobject的指针。

When a reference is released, the call to kobject_put() will decrement the
reference count and, possibly, free the object. Note that kobject_init() sets
the reference count to one, so the code which sets up the kobject will need to
do a kobject_put() eventually to release that reference.

当一个引用被创建，kobject_put的一次成功调用将会使kobject的引用计数减1，如果减
为0，则会释放这个kobject。注意kobject_init将kobject引用计数设置为1，所以创建
kobject的相关代码最后应该调用一次kobject_put来释放这个kobject对象。

Because kobjects are dynamic, they must not be declared statically or on the
stack, but instead, always allocated dynamically.  Future versions of the
kernel will contain a run-time check for kobjects that are created statically
and will warn the developer of this improper usage.

由于kobjects是根据需要动态创建的，不应该将其声明为静态的，或者在栈上创建，必须
动态分配创建在堆上。后续版本的内核将包含对kobjects的运行时检查，对于哪些静态创
建的kobjects，内核将给予警告。

If all that you want to use a kobject for is to provide a reference counter
for your structure, please use the struct kref instead; a kobject would be
overkill.  For more information on how to use struct kref, please see the file
Documentation/kref.txt in the Linux kernel source tree.

如果使用kobject的目的仅仅是为某个结构体提供一个引用计数，请使用kref结构体代替
。使用kobject有点杀鸡用牛刀的味道，没有必要。关于如何使用kref，请参考linux内核
源代码树中的文档Documentation/kref.txt。

Creating "simple" kobjects

Sometimes all that a developer wants is a way to create a simple directory in
the sysfs hierarchy, and not have to mess with the whole complication of
ksets, show and store functions, and other details.  This is the one exception
where a single kobject should be created.  To create such an entry, use the
function:

有时，开发人员指向在sysfs目录中创建一个简单的目录，不需要ksets、显示和保存函数
等其他细节。这种情况下，就是我们前面提到的在内核代码中单独使用kobject的例外情
况。在sysfs中创建这样一个简单入口，使用如下函数:

    struct kobject *kobject_create_and_add(char *name, struct kobject *parent);

This function will create a kobject and place it in sysfs in the location
underneath the specified parent kobject.  To create simple attributes
associated with this kobject, use:

这个函数创建一个kobject，并将其放置在sysfs目录中指定的parent kobject目录下面，
创建一个与该kobject相关联的简单属性，使用如下函数：

    int sysfs_create_file(struct kobject *kobj, struct attribute *attr);
        or
    int sysfs_create_group(struct kobject *kobj, struct attribute_group *grp);

Both types of attributes used here, with a kobject that has been created with
the kobject_create_and_add(), can be of type kobj_attribute, so no special
custom attribute is needed to be created.

See the example module, samples/kobject/kobject-example.c for an
implementation of a simple kobject and attributes.

ktypes and release methods

One important thing still missing from the discussion is what happens to a
kobject when its reference count reaches zero. The code which created the
kobject generally does not know when that will happen; if it did, there would
be little point in using a kobject in the first place. Even predictable object
lifecycles become more complicated when sysfs is brought in as other portions
of the kernel can get a reference on any kobject that is registered in the
system.

还有一个非常重要的问题没有讨论，就是当kobject引用计数减为0时，该如何操作。创建
kobject的代码并不知道何时该kobject的引用计数会减为0.

The end result is that a structure protected by a kobject cannot be freed
before its reference count goes to zero. The reference count is not under the
direct control of the code which created the kobject. So that code must be
notified asynchronously whenever the last reference to one of its kobjects
goes away.

受kobject保护的结构体，只要kobject引用计数不为0，那么包含它的结构体就不应该被
释放。这个引用计数并不受创建kobject的代码的直接控制。所以当kobject引用计数被减
为0时，必须异步通知创建它的那段代码，才能让创建它的代码获知kobject引用计数为0。

Once you registered your kobject via kobject_add(), you must never use kfree()
to free it directly. The only safe way is to use kobject_put(). It is good
practice to always use kobject_put() after kobject_init() to avoid errors
creeping in.

一旦通过kobject_add注册了kobject，就不能再使用kfree直接释放包含了kobject的对象
。唯一安全的方式是调用kobject_put。为了避免忘记在创建kobject代码的最后部分调用
kobject_put（kobject_init初始引用计数为1），从而造成无法成功释放的后果，在实际
编程时，在kobject_init之后调用一次kobject_put是一个不错的方法

注：
    如果init之后立即调用put不就导致引用计数为0了吗？
    举个例子:
    typedef struct T {
        struct kobject kobj;
        ....
    }TT;
    TT * tt = (TT *)malloc(sizeof(TT));    // kobj引用计数为0

    kobject *kp = 
        kobject_init(tt->kobj);            // init中初始化后kobj引用计数1
                                        // init返回指向kobj的指针，引用计数为2
    kobject_put(tt->kobj);                // kobj引用计数--后，为1
    如果是这样的话，那就不存在问题了。


This notification is done through a kobject's release() method. Usually such a
method has a form like:

    void my_object_release(struct kobject *kobj)
    {
            struct my_object *mine = container_of(kobj, struct my_object, kobj);
    
            /* Perform any additional cleanup on this object, then... */
            kfree(mine);
    }

这里的异步通知，是通过kobject提供的一个release方法实现，这里的通知好像通知的是
kobject自身，而不是包含它的结构体。kobject必须提供一个release方法，如上面的代
码所示，当kobject的引用计数为0时，就会调用kobject提供的release方法，在这个方法
体里面，通过前面提过的container_of方法获取嵌入该object对象的结构体的指针，然后
再调用kfree释放该结构体。

One important point cannot be overstated: every kobject must have a release()
method, and the kobject must persist (in a consistent state) until that method
is called. If these constraints are not met, the code is flawed.  Note that
the kernel will warn you if you forget to provide a release() method.  Do not
try to get rid of this warning by providing an "empty" release function; you
will be mocked mercilessly by the kobject maintainer if you attempt this.

一个在强调都不为过的重点：每一个kobject都必须拥有一个release方法。如果不提供该
方法，内核会发出警告，编程人员不应该提供一个空的release方法来避免该警告，必须
提供切实可行的代码。

Note, the name of the kobject is available in the release function, but it
must NOT be changed within this callback.  Otherwise there will be a memory
leak in the kobject core, which makes people unhappy.

注意，在release函数中可以获取到kobject的名字，但是不应该在这个回调函数里面改变
它的名字，否则会造成内存泄漏。

Interestingly, the release() method is not stored in the kobject itself;
instead, it is associated with the ktype. So let us introduce struct
kobj_type:

release方法并不属于结构体kobject自身，而是与一个ktype关联起来的，现面是
kobj_type的结构体定义：

    struct kobj_type {
            void (*release)(struct kobject *);
            const struct sysfs_ops *sysfs_ops;
            struct attribute    **default_attrs;
    };
    
    从这个结构体定义中，我们看到它包括一个成员release，这是一个函数指针，即我
    们前面提到的为每个kobject提供的release函数。
    前面提及必须为每个kobject指定release函数，而release方法包含在ktype结构体里
    面，这样我们就可以理解前面提及的“每个kobject都必须指定一个ktype”这个知识点
    了。

This structure is used to describe a particular type of kobject (or, more
correctly, of containing object). Every kobject needs to have an associated
kobj_type structure; a pointer to that structure must be specified when you
call kobject_init() or kobject_init_and_add().

The release field in struct kobj_type is, of course, a pointer to the
release() method for this type of kobject. The other two fields (sysfs_ops
and default_attrs) control how objects of this type are represented in
sysfs; they are beyond the scope of this document.

The default_attrs pointer is a list of default attributes that will be
automatically created for any kobject that is registered with this ktype.

ksets

A kset is merely a collection of kobjects that want to be associated with each
other.  There is no restriction that they be of the same ktype, but be very
careful if they are not.

kset仅仅是一系列希望相互间产生某种关联的kobjects的集合，kset并不限制其包含的
kobjects的种类是否相同。如果包含的kobjects类型如果不同的话，就要多加注意了。

A kset serves these functions:

kset提供了如下功能：

 - It serves as a bag containing a group of objects. A kset can be used by
   the kernel to track "all block devices" or "all PCI device drivers."

   kset可以充当一个包含了一组objects的包，可以让内核追踪所有的块设备或者所有的
   pci设备。

 - A kset is also a subdirectory in sysfs, where the associated kobjects
   with the kset can show up.  Every kset contains a kobject which can be
   set up to be the parent of other kobjects; the top-level directories of
   the sysfs hierarchy are constructed in this way.

   kset也是sysfs中的一个子目录，在这个子目录中，与当前kset对应的kobjects会被显
   示出来。每个kset包含了一个比较特殊的kobject，这个kobject可以被设置成当前
   kset下其他kobjects的parent。

 - Ksets can support the "hotplugging" of kobjects and influence how uevent
   events are reported to user space.

   ksets支持kobjects的热插拔，并且能够影响如何将uevent事件报道到用户空间。

In object-oriented terms, "kset" is the top-level container class; ksets
contain their own kobject, but that kobject is managed by the kset code and
should not be manipulated by any other user.

A kset keeps its children in a standard kernel linked list.  Kobjects point
back to their containing kset via their kset field. In almost all cases,
the kobjects belonging to a kset have that kset (or, strictly, its embedded
kobject) in their parent.

As a kset contains a kobject within it, it should always be dynamically
created and never declared statically or on the stack.  To create a new kset
use: 

  前面我们提到过kobject必须被动态创建，由于kset也包含一个kobject，所以kset 也
  必须被动态创建。

  struct kset *kset_create_and_add(const char *name,
                                   struct kset_uevent_ops *u,
                                   struct kobject *parent);

When you are finished with the kset, call:
  void kset_unregister(struct kset *kset);
to destroy it.

An example of using a kset can be seen in the samples/kobject/kset-example.c
file in the kernel tree.

If a kset wishes to control the uevent operations of the kobjects associated
with it, it can use the struct kset_uevent_ops to handle it:

struct kset_uevent_ops {
        int (*filter)(struct kset *kset, struct kobject *kobj);
        const char *(*name)(struct kset *kset, struct kobject *kobj);
        int (*uevent)(struct kset *kset, struct kobject *kobj,
                      struct kobj_uevent_env *env);
};


The filter function allows a kset to prevent a uevent from being emitted to
userspace for a specific kobject.  If the function returns 0, the uevent will
not be emitted.

The name function will be called to override the default name of the kset that
the uevent sends to userspace.  By default, the name will be the same as the
kset itself, but this function, if present, can override that name.

The uevent function will be called when the uevent is about to be sent to
userspace to allow more environment variables to be added to the uevent.

One might ask how, exactly, a kobject is added to a kset, given that no
functions which perform that function have been presented.  The answer is that
this task is handled by kobject_add().  When a kobject is passed to
kobject_add(), its kset member should point to the kset to which the kobject
will belong.  kobject_add() will handle the rest.

If the kobject belonging to a kset has no parent kobject set, it will be added
to the kset's directory.  Not all members of a kset do necessarily live in the
kset directory.  If an explicit parent kobject is assigned before the kobject
is added, the kobject is registered with the kset, but added below the parent
kobject.

Kobject removal

After a kobject has been registered with the kobject core successfully, it
must be cleaned up when the code is finished with it.  To do that, call
kobject_put().  By doing this, the kobject core will automatically clean up
all of the memory allocated by this kobject.  If a KOBJ_ADD uevent has been
sent for the object, a corresponding KOBJ_REMOVE uevent will be sent, and any
other sysfs housekeeping will be handled for the caller properly.

If you need to do a two-stage delete of the kobject (say you are not allowed
to sleep when you need to destroy the object), then call kobject_del() which
will unregister the kobject from sysfs.  This makes the kobject "invisible",
but it is not cleaned up, and the reference count of the object is still the
same.  At a later time call kobject_put() to finish the cleanup of the memory
associated with the kobject.

kobject_del() can be used to drop the reference to the parent object, if
circular references are constructed.  It is valid in some cases, that a parent
objects references a child.  Circular references _must_ be broken with an
explicit call to kobject_del(), so that a release functions will be called,
and the objects in the former circle release each other.

Example code to copy from

For a more complete example of using ksets and kobjects properly, see the
example programs samples/kobject/{kobject-example.c,kset-example.c}, which
will be built as loadable modules if you select CONFIG_SAMPLE_KOBJECT.

[107] kprobes.txt

该文档中解释了内核调试中经常使用的三种探针kprobe\jprobe\rprobe，并解释了这几种
探针的工作原理，好好看一看。

Title   : Kernel Probes (Kprobes)
Authors : Jim Keniston <jkenisto@us.ibm.com>
        : Prasanna S Panchamukhi <prasanna.panchamukhi@gmail.com>
        : Masami Hiramatsu <mhiramat@redhat.com>

CONTENTS

1. Concepts: Kprobes, Jprobes, Return Probes
2. Architectures Supported
3. Configuring Kprobes
4. API Reference
5. Kprobes Features and Limitations
6. Probe Overhead
7. TODO
8. Kprobes Example
9. Jprobes Example
10. Kretprobes Example
Appendix A: The kprobes debugfs interface
Appendix B: The kprobes sysctl interface

1. Concepts: Kprobes, Jprobes, Return Probes

Kprobes enables you to dynamically break into any kernel routine and
collect debugging and performance information non-disruptively. You
can trap at almost any kernel code address, specifying a handler
routine to be invoked when the breakpoint is hit.

There are currently three types of probes: kprobes, jprobes, and
kretprobes (also called return probes).  A kprobe can be inserted
on virtually any instruction in the kernel.  A jprobe is inserted at
the entry to a kernel function, and provides convenient access to the
function's arguments.  A return probe fires when a specified function
returns.

In the typical case, Kprobes-based instrumentation is packaged as
a kernel module.  The module's init function installs ("registers")
one or more probes, and the exit function unregisters them.  A
registration function such as register_kprobe() specifies where
the probe is to be inserted and what handler is to be called when
the probe is hit.

There are also register_/unregister_*probes() functions for batch
registration/unregistration of a group of *probes. These functions
can speed up unregistration process when you have to unregister
a lot of probes at once.

The next four subsections explain how the different types of
probes work and how jump optimization works.  They explain certain
things that you'll need to know in order to make the best use of
Kprobes -- e.g., the difference between a pre_handler and
a post_handler, and how to use the maxactive and nmissed fields of
a kretprobe.  But if you're in a hurry to start using Kprobes, you
can skip ahead to section 2.

1.1 How Does a Kprobe Work?

When a kprobe is registered, Kprobes makes a copy of the probed
instruction and replaces the first byte(s) of the probed instruction
with a breakpoint instruction (e.g., int3 on i386 and x86_64).

When a CPU hits the breakpoint instruction, a trap occurs, the CPU's
registers are saved, and control passes to Kprobes via the
notifier_call_chain mechanism.  Kprobes executes the "pre_handler"
associated with the kprobe, passing the handler the addresses of the
kprobe struct and the saved registers.

Next, Kprobes single-steps its copy of the probed instruction.
(It would be simpler to single-step the actual instruction in place,
but then Kprobes would have to temporarily remove the breakpoint
instruction.  This would open a small time window when another CPU
could sail right past the probepoint.)

After the instruction is single-stepped, Kprobes executes the
"post_handler," if any, that is associated with the kprobe.
Execution then continues with the instruction following the probepoint.

1.2 How Does a Jprobe Work?

A jprobe is implemented using a kprobe that is placed on a function's
entry point.  It employs a simple mirroring principle to allow
seamless access to the probed function's arguments.  The jprobe
handler routine should have the same signature (arg list and return
type) as the function being probed, and must always end by calling
the Kprobes function jprobe_return().

Here's how it works.  When the probe is hit, Kprobes makes a copy of
the saved registers and a generous portion of the stack (see below).
Kprobes then points the saved instruction pointer at the jprobe's
handler routine, and returns from the trap.  As a result, control
passes to the handler, which is presented with the same register and
stack contents as the probed function.  When it is done, the handler
calls jprobe_return(), which traps again to restore the original stack
contents and processor state and switch to the probed function.

By convention, the callee owns its arguments, so gcc may produce code
that unexpectedly modifies that portion of the stack.  This is why
Kprobes saves a copy of the stack and restores it after the jprobe
handler has run.  Up to MAX_STACK_SIZE bytes are copied -- e.g.,
64 bytes on i386.

Note that the probed function's args may be passed on the stack
or in registers.  The jprobe will work in either case, so long as the
handler's prototype matches that of the probed function.

1.3 Return Probes

1.3.1 How Does a Return Probe Work?

When you call register_kretprobe(), Kprobes establishes a kprobe at
the entry to the function.  When the probed function is called and this
probe is hit, Kprobes saves a copy of the return address, and replaces
the return address with the address of a "trampoline."  The trampoline
is an arbitrary piece of code -- typically just a nop instruction.
At boot time, Kprobes registers a kprobe at the trampoline.

When the probed function executes its return instruction, control
passes to the trampoline and that probe is hit.  Kprobes' trampoline
handler calls the user-specified return handler associated with the
kretprobe, then sets the saved instruction pointer to the saved return
address, and that's where execution resumes upon return from the trap.

While the probed function is executing, its return address is
stored in an object of type kretprobe_instance.  Before calling
register_kretprobe(), the user sets the maxactive field of the
kretprobe struct to specify how many instances of the specified
function can be probed simultaneously.  register_kretprobe()
pre-allocates the indicated number of kretprobe_instance objects.

For example, if the function is non-recursive and is called with a
spinlock held, maxactive = 1 should be enough.  If the function is
non-recursive and can never relinquish the CPU (e.g., via a semaphore
or preemption), NR_CPUS should be enough.  If maxactive <= 0, it is
set to a default value.  If CONFIG_PREEMPT is enabled, the default
is max(10, 2*NR_CPUS).  Otherwise, the default is NR_CPUS.

It's not a disaster if you set maxactive too low; you'll just miss
some probes.  In the kretprobe struct, the nmissed field is set to
zero when the return probe is registered, and is incremented every
time the probed function is entered but there is no kretprobe_instance
object available for establishing the return probe.

1.3.2 Kretprobe entry-handler

Kretprobes also provides an optional user-specified handler which runs
on function entry. This handler is specified by setting the entry_handler
field of the kretprobe struct. Whenever the kprobe placed by kretprobe at the
function entry is hit, the user-defined entry_handler, if any, is invoked.
If the entry_handler returns 0 (success) then a corresponding return handler
is guaranteed to be called upon function return. If the entry_handler
returns a non-zero error then Kprobes leaves the return address as is, and
the kretprobe has no further effect for that particular function instance.

Multiple entry and return handler invocations are matched using the unique
kretprobe_instance object associated with them. Additionally, a user
may also specify per return-instance private data to be part of each
kretprobe_instance object. This is especially useful when sharing private
data between corresponding user entry and return handlers. The size of each
private data object can be specified at kretprobe registration time by
setting the data_size field of the kretprobe struct. This data can be
accessed through the data field of each kretprobe_instance object.

In case probed function is entered but there is no kretprobe_instance
object available, then in addition to incrementing the nmissed count,
the user entry_handler invocation is also skipped.

1.4 How Does Jump Optimization Work?

If your kernel is built with CONFIG_OPTPROBES=y (currently this flag
is automatically set 'y' on x86/x86-64, non-preemptive kernel) and
the "debug.kprobes_optimization" kernel parameter is set to 1 (see
sysctl(8)), Kprobes tries to reduce probe-hit overhead by using a jump
instruction instead of a breakpoint instruction at each probepoint.

1.4.1 Init a Kprobe

When a probe is registered, before attempting this optimization,
Kprobes inserts an ordinary, breakpoint-based kprobe at the specified
address. So, even if it's not possible to optimize this particular
probepoint, there'll be a probe there.

1.4.2 Safety Check

Before optimizing a probe, Kprobes performs the following safety checks:

- Kprobes verifies that the region that will be replaced by the jump
instruction (the "optimized region") lies entirely within one function.
(A jump instruction is multiple bytes, and so may overlay multiple
instructions.)

- Kprobes analyzes the entire function and verifies that there is no
jump into the optimized region.  Specifically:
  - the function contains no indirect jump;
  - the function contains no instruction that causes an exception (since
  the fixup code triggered by the exception could jump back into the
  optimized region -- Kprobes checks the exception tables to verify this);
  and
  - there is no near jump to the optimized region (other than to the first
  byte).

- For each instruction in the optimized region, Kprobes verifies that
the instruction can be executed out of line.

1.4.3 Preparing Detour Buffer

Next, Kprobes prepares a "detour" buffer, which contains the following
instruction sequence:
- code to push the CPU's registers (emulating a breakpoint trap)
- a call to the trampoline code which calls user's probe handlers.
- code to restore registers
- the instructions from the optimized region
- a jump back to the original execution path.

1.4.4 Pre-optimization

After preparing the detour buffer, Kprobes verifies that none of the
following situations exist:
- The probe has either a break_handler (i.e., it's a jprobe) or a
post_handler.
- Other instructions in the optimized region are probed.
- The probe is disabled.
In any of the above cases, Kprobes won't start optimizing the probe.
Since these are temporary situations, Kprobes tries to start
optimizing it again if the situation is changed.

If the kprobe can be optimized, Kprobes enqueues the kprobe to an
optimizing list, and kicks the kprobe-optimizer workqueue to optimize
it.  If the to-be-optimized probepoint is hit before being optimized,
Kprobes returns control to the original instruction path by setting
the CPU's instruction pointer to the copied code in the detour buffer
-- thus at least avoiding the single-step.

1.4.5 Optimization

The Kprobe-optimizer doesn't insert the jump instruction immediately;
rather, it calls synchronize_sched() for safety first, because it's
possible for a CPU to be interrupted in the middle of executing the
optimized region(*).  As you know, synchronize_sched() can ensure
that all interruptions that were active when synchronize_sched()
was called are done, but only if CONFIG_PREEMPT=n.  So, this version
of kprobe optimization supports only kernels with CONFIG_PREEMPT=n.(**)

After that, the Kprobe-optimizer calls stop_machine() to replace
the optimized region with a jump instruction to the detour buffer,
using text_poke_smp().

1.4.6 Unoptimization

When an optimized kprobe is unregistered, disabled, or blocked by
another kprobe, it will be unoptimized.  If this happens before
the optimization is complete, the kprobe is just dequeued from the
optimized list.  If the optimization has been done, the jump is
replaced with the original code (except for an int3 breakpoint in
the first byte) by using text_poke_smp().

(*)Please imagine that the 2nd instruction is interrupted and then
the optimizer replaces the 2nd instruction with the jump *address*
while the interrupt handler is running. When the interrupt
returns to original address, there is no valid instruction,
and it causes an unexpected result.

(**)This optimization-safety checking may be replaced with the
stop-machine method that ksplice uses for supporting a CONFIG_PREEMPT=y
kernel.

NOTE for geeks:
The jump optimization changes the kprobe's pre_handler behavior.
Without optimization, the pre_handler can change the kernel's execution
path by changing regs->ip and returning 1.  However, when the probe
is optimized, that modification is ignored.  Thus, if you want to
tweak the kernel's execution path, you need to suppress optimization,
using one of the following techniques:
- Specify an empty function for the kprobe's post_handler or break_handler.
 or
- Execute 'sysctl -w debug.kprobes_optimization=n'

2. Architectures Supported

Kprobes, jprobes, and return probes are implemented on the following
architectures:

- i386 (Supports jump optimization)
- x86_64 (AMD-64, EM64T) (Supports jump optimization)
- ppc64
- ia64 (Does not support probes on instruction slot1.)
- sparc64 (Return probes not yet implemented.)
- arm
- ppc
- mips

3. Configuring Kprobes

When configuring the kernel using make menuconfig/xconfig/oldconfig,
ensure that CONFIG_KPROBES is set to "y".  Under "Instrumentation
Support", look for "Kprobes".

So that you can load and unload Kprobes-based instrumentation modules,
make sure "Loadable module support" (CONFIG_MODULES) and "Module
unloading" (CONFIG_MODULE_UNLOAD) are set to "y".

Also make sure that CONFIG_KALLSYMS and perhaps even CONFIG_KALLSYMS_ALL
are set to "y", since kallsyms_lookup_name() is used by the in-kernel
kprobe address resolution code.

If you need to insert a probe in the middle of a function, you may find
it useful to "Compile the kernel with debug info" (CONFIG_DEBUG_INFO),
so you can use "objdump -d -l vmlinux" to see the source-to-object
code mapping.

4. API Reference

The Kprobes API includes a "register" function and an "unregister"
function for each type of probe. The API also includes "register_*probes"
and "unregister_*probes" functions for (un)registering arrays of probes.
Here are terse, mini-man-page specifications for these functions and
the associated probe handlers that you'll write. See the files in the
samples/kprobes/ sub-directory for examples.

4.1 register_kprobe

#include <linux/kprobes.h>
int register_kprobe(struct kprobe *kp);

Sets a breakpoint at the address kp->addr.  When the breakpoint is
hit, Kprobes calls kp->pre_handler.  After the probed instruction
is single-stepped, Kprobe calls kp->post_handler.  If a fault
occurs during execution of kp->pre_handler or kp->post_handler,
or during single-stepping of the probed instruction, Kprobes calls
kp->fault_handler.  Any or all handlers can be NULL. If kp->flags
is set KPROBE_FLAG_DISABLED, that kp will be registered but disabled,
so, its handlers aren't hit until calling enable_kprobe(kp).

NOTE:
1. With the introduction of the "symbol_name" field to struct kprobe,
   the probepoint address resolution will now be taken care of by the kernel.
   The following will now work:

        kp.symbol_name = "symbol_name";

(64-bit powerpc intricacies such as function descriptors are handled
transparently)

2. Use the "offset" field of struct kprobe if the offset into the symbol
to install a probepoint is known. This field is used to calculate the
probepoint.

3. Specify either the kprobe "symbol_name" OR the "addr". If both are
specified, kprobe registration will fail with -EINVAL.

4. With CISC architectures (such as i386 and x86_64), the kprobes code
does not validate if the kprobe.addr is at an instruction boundary.
Use "offset" with caution.

register_kprobe() returns 0 on success, or a negative errno otherwise.

User's pre-handler (kp->pre_handler):
#include <linux/kprobes.h>
#include <linux/ptrace.h>
int pre_handler(struct kprobe *p, struct pt_regs *regs);

Called with p pointing to the kprobe associated with the breakpoint,
and regs pointing to the struct containing the registers saved when
the breakpoint was hit.  Return 0 here unless you're a Kprobes geek.

User's post-handler (kp->post_handler):
#include <linux/kprobes.h>
#include <linux/ptrace.h>
void post_handler(struct kprobe *p, struct pt_regs *regs,
        unsigned long flags);

p and regs are as described for the pre_handler.  flags always seems
to be zero.

User's fault-handler (kp->fault_handler):
#include <linux/kprobes.h>
#include <linux/ptrace.h>
int fault_handler(struct kprobe *p, struct pt_regs *regs, int trapnr);

p and regs are as described for the pre_handler.  trapnr is the
architecture-specific trap number associated with the fault (e.g.,
on i386, 13 for a general protection fault or 14 for a page fault).
Returns 1 if it successfully handled the exception.

4.2 register_jprobe

#include <linux/kprobes.h>
int register_jprobe(struct jprobe *jp)

Sets a breakpoint at the address jp->kp.addr, which must be the address
of the first instruction of a function.  When the breakpoint is hit,
Kprobes runs the handler whose address is jp->entry.

The handler should have the same arg list and return type as the probed
function; and just before it returns, it must call jprobe_return().
(The handler never actually returns, since jprobe_return() returns
control to Kprobes.)  If the probed function is declared asmlinkage
or anything else that affects how args are passed, the handler's
declaration must match.

register_jprobe() returns 0 on success, or a negative errno otherwise.

4.3 register_kretprobe

#include <linux/kprobes.h>
int register_kretprobe(struct kretprobe *rp);

Establishes a return probe for the function whose address is
rp->kp.addr.  When that function returns, Kprobes calls rp->handler.
You must set rp->maxactive appropriately before you call
register_kretprobe(); see "How Does a Return Probe Work?" for details.

register_kretprobe() returns 0 on success, or a negative errno
otherwise.

User's return-probe handler (rp->handler):
#include <linux/kprobes.h>
#include <linux/ptrace.h>
int kretprobe_handler(struct kretprobe_instance *ri, struct pt_regs *regs);

regs is as described for kprobe.pre_handler.  ri points to the
kretprobe_instance object, of which the following fields may be
of interest:
- ret_addr: the return address
- rp: points to the corresponding kretprobe object
- task: points to the corresponding task struct
- data: points to per return-instance private data; see "Kretprobe
        entry-handler" for details.

The regs_return_value(regs) macro provides a simple abstraction to
extract the return value from the appropriate register as defined by
the architecture's ABI.

The handler's return value is currently ignored.

4.4 unregister_*probe

#include <linux/kprobes.h>
void unregister_kprobe(struct kprobe *kp);
void unregister_jprobe(struct jprobe *jp);
void unregister_kretprobe(struct kretprobe *rp);

Removes the specified probe.  The unregister function can be called
at any time after the probe has been registered.

NOTE:
If the functions find an incorrect probe (ex. an unregistered probe),
they clear the addr field of the probe.

4.5 register_*probes

#include <linux/kprobes.h>
int register_kprobes(struct kprobe **kps, int num);
int register_kretprobes(struct kretprobe **rps, int num);
int register_jprobes(struct jprobe **jps, int num);

Registers each of the num probes in the specified array.  If any
error occurs during registration, all probes in the array, up to
the bad probe, are safely unregistered before the register_*probes
function returns.
- kps/rps/jps: an array of pointers to *probe data structures
- num: the number of the array entries.

NOTE:
You have to allocate(or define) an array of pointers and set all
of the array entries before using these functions.

4.6 unregister_*probes

#include <linux/kprobes.h>
void unregister_kprobes(struct kprobe **kps, int num);
void unregister_kretprobes(struct kretprobe **rps, int num);
void unregister_jprobes(struct jprobe **jps, int num);

Removes each of the num probes in the specified array at once.

NOTE:
If the functions find some incorrect probes (ex. unregistered
probes) in the specified array, they clear the addr field of those
incorrect probes. However, other probes in the array are
unregistered correctly.

4.7 disable_*probe

#include <linux/kprobes.h>
int disable_kprobe(struct kprobe *kp);
int disable_kretprobe(struct kretprobe *rp);
int disable_jprobe(struct jprobe *jp);

Temporarily disables the specified *probe. You can enable it again by using
enable_*probe(). You must specify the probe which has been registered.

4.8 enable_*probe

#include <linux/kprobes.h>
int enable_kprobe(struct kprobe *kp);
int enable_kretprobe(struct kretprobe *rp);
int enable_jprobe(struct jprobe *jp);

Enables *probe which has been disabled by disable_*probe(). You must specify
the probe which has been registered.

5. Kprobes Features and Limitations

Kprobes allows multiple probes at the same address.  Currently,
however, there cannot be multiple jprobes on the same function at
the same time.  Also, a probepoint for which there is a jprobe or
a post_handler cannot be optimized.  So if you install a jprobe,
or a kprobe with a post_handler, at an optimized probepoint, the
probepoint will be unoptimized automatically.

In general, you can install a probe anywhere in the kernel.
In particular, you can probe interrupt handlers.  Known exceptions
are discussed in this section.

The register_*probe functions will return -EINVAL if you attempt
to install a probe in the code that implements Kprobes (mostly
kernel/kprobes.c and arch/*/kernel/kprobes.c, but also functions such
as do_page_fault and notifier_call_chain).

If you install a probe in an inline-able function, Kprobes makes
no attempt to chase down all inline instances of the function and
install probes there.  gcc may inline a function without being asked,
so keep this in mind if you're not seeing the probe hits you expect.

A probe handler can modify the environment of the probed function
-- e.g., by modifying kernel data structures, or by modifying the
contents of the pt_regs struct (which are restored to the registers
upon return from the breakpoint).  So Kprobes can be used, for example,
to install a bug fix or to inject faults for testing.  Kprobes, of
course, has no way to distinguish the deliberately injected faults
from the accidental ones.  Don't drink and probe.

Kprobes makes no attempt to prevent probe handlers from stepping on
each other -- e.g., probing printk() and then calling printk() from a
probe handler.  If a probe handler hits a probe, that second probe's
handlers won't be run in that instance, and the kprobe.nmissed member
of the second probe will be incremented.

As of Linux v2.6.15-rc1, multiple handlers (or multiple instances of
the same handler) may run concurrently on different CPUs.

Kprobes does not use mutexes or allocate memory except during
registration and unregistration.

Probe handlers are run with preemption disabled.  Depending on the
architecture and optimization state, handlers may also run with
interrupts disabled (e.g., kretprobe handlers and optimized kprobe
handlers run without interrupt disabled on x86/x86-64).  In any case,
your handler should not yield the CPU (e.g., by attempting to acquire
a semaphore).

Since a return probe is implemented by replacing the return
address with the trampoline's address, stack backtraces and calls
to __builtin_return_address() will typically yield the trampoline's
address instead of the real return address for kretprobed functions.
(As far as we can tell, __builtin_return_address() is used only
for instrumentation and error reporting.)

If the number of times a function is called does not match the number
of times it returns, registering a return probe on that function may
produce undesirable results. In such a case, a line:
kretprobe BUG!: Processing kretprobe d000000000041aa8 @ c00000000004f48c
gets printed. With this information, one will be able to correlate the
exact instance of the kretprobe that caused the problem. We have the
do_exit() case covered. do_execve() and do_fork() are not an issue.
We're unaware of other specific cases where this could be a problem.

If, upon entry to or exit from a function, the CPU is running on
a stack other than that of the current task, registering a return
probe on that function may produce undesirable results.  For this
reason, Kprobes doesn't support return probes (or kprobes or jprobes)
on the x86_64 version of __switch_to(); the registration functions
return -EINVAL.

On x86/x86-64, since the Jump Optimization of Kprobes modifies
instructions widely, there are some limitations to optimization. To
explain it, we introduce some terminology. Imagine a 3-instruction
sequence consisting of a two 2-byte instructions and one 3-byte
instruction.

        IA
         |
[-2][-1][0][1][2][3][4][5][6][7]
        [ins1][ins2][  ins3 ]
        [<-     DCR       ->]
           [<- JTPR ->]

ins1: 1st Instruction
ins2: 2nd Instruction
ins3: 3rd Instruction
IA:  Insertion Address
JTPR: Jump Target Prohibition Region
DCR: Detoured Code Region

The instructions in DCR are copied to the out-of-line buffer
of the kprobe, because the bytes in DCR are replaced by
a 5-byte jump instruction. So there are several limitations.

a) The instructions in DCR must be relocatable.
b) The instructions in DCR must not include a call instruction.
c) JTPR must not be targeted by any jump or call instruction.
d) DCR must not straddle the border between functions.

Anyway, these limitations are checked by the in-kernel instruction
decoder, so you don't need to worry about that.

6. Probe Overhead

On a typical CPU in use in 2005, a kprobe hit takes 0.5 to 1.0
microseconds to process.  Specifically, a benchmark that hits the same
probepoint repeatedly, firing a simple handler each time, reports 1-2
million hits per second, depending on the architecture.  A jprobe or
return-probe hit typically takes 50-75% longer than a kprobe hit.
When you have a return probe set on a function, adding a kprobe at
the entry to that function adds essentially no overhead.

Here are sample overhead figures (in usec) for different architectures.
k = kprobe; j = jprobe; r = return probe; kr = kprobe + return probe
on same function; jr = jprobe + return probe on same function

i386: Intel Pentium M, 1495 MHz, 2957.31 bogomips
k = 0.57 usec; j = 1.00; r = 0.92; kr = 0.99; jr = 1.40

x86_64: AMD Opteron 246, 1994 MHz, 3971.48 bogomips
k = 0.49 usec; j = 0.76; r = 0.80; kr = 0.82; jr = 1.07

ppc64: POWER5 (gr), 1656 MHz (SMT disabled, 1 virtual CPU per physical CPU)
k = 0.77 usec; j = 1.31; r = 1.26; kr = 1.45; jr = 1.99

6.1 Optimized Probe Overhead

Typically, an optimized kprobe hit takes 0.07 to 0.1 microseconds to
process. Here are sample overhead figures (in usec) for x86 architectures.
k = unoptimized kprobe, b = boosted (single-step skipped), o = optimized kprobe,
r = unoptimized kretprobe, rb = boosted kretprobe, ro = optimized kretprobe.

i386: Intel(R) Xeon(R) E5410, 2.33GHz, 4656.90 bogomips
k = 0.80 usec; b = 0.33; o = 0.05; r = 1.10; rb = 0.61; ro = 0.33

x86-64: Intel(R) Xeon(R) E5410, 2.33GHz, 4656.90 bogomips
k = 0.99 usec; b = 0.43; o = 0.06; r = 1.24; rb = 0.68; ro = 0.30

7. TODO

a. SystemTap (http://sourceware.org/systemtap): Provides a simplified
programming interface for probe-based instrumentation.  Try it out.
b. Kernel return probes for sparc64.
c. Support for other architectures.
d. User-space probes.
e. Watchpoint probes (which fire on data references).

8. Kprobes Example

See samples/kprobes/kprobe_example.c

9. Jprobes Example

See samples/kprobes/jprobe_example.c

10. Kretprobes Example

See samples/kprobes/kretprobe_example.c

For additional information on Kprobes, refer to the following URLs:
http://www-106.ibm.com/developerworks/library/l-kprobes.html?ca=dgr-lnxw42Kprobe
http://www.redhat.com/magazine/005mar05/features/kprobes/
http://www-users.cs.umn.edu/~boutcher/kprobes/
http://www.linuxsymposium.org/2006/linuxsymposium_procv2.pdf (pages 101-115)


Appendix A: The kprobes debugfs interface

With recent kernels (> 2.6.20) the list of registered kprobes is visible
under the /sys/kernel/debug/kprobes/ directory (assuming debugfs is mounted at //sys/kernel/debug).

/sys/kernel/debug/kprobes/list: Lists all registered probes on the system

c015d71a  k  vfs_read+0x0
c011a316  j  do_fork+0x0
c03dedc5  r  tcp_v4_rcv+0x0

The first column provides the kernel address where the probe is inserted.
The second column identifies the type of probe (k - kprobe, r - kretprobe
and j - jprobe), while the third column specifies the symbol+offset of
the probe. If the probed function belongs to a module, the module name
is also specified. Following columns show probe status. If the probe is on
a virtual address that is no longer valid (module init sections, module
virtual addresses that correspond to modules that've been unloaded),
such probes are marked with [GONE]. If the probe is temporarily disabled,
such probes are marked with [DISABLED]. If the probe is optimized, it is
marked with [OPTIMIZED].

/sys/kernel/debug/kprobes/enabled: Turn kprobes ON/OFF forcibly.

Provides a knob to globally and forcibly turn registered kprobes ON or OFF.
By default, all kprobes are enabled. By echoing "0" to this file, all
registered probes will be disarmed, till such time a "1" is echoed to this
file. Note that this knob just disarms and arms all kprobes and doesn't
change each probe's disabling state. This means that disabled kprobes (marked
[DISABLED]) will be not enabled if you turn ON all kprobes by this knob.


Appendix B: The kprobes sysctl interface

/proc/sys/debug/kprobes-optimization: Turn kprobes optimization ON/OFF.

When CONFIG_OPTPROBES=y, this sysctl interface appears and it provides
a knob to globally and forcibly turn jump optimization (see section
1.4) ON or OFF. By default, jump optimization is allowed (ON).
If you echo "0" to this file or set "debug.kprobes_optimization" to
0 via sysctl, all optimized probes will be unoptimized, and any new
probes registered after that will not be optimized.  Note that this
knob *changes* the optimized state. This means that optimized probes
(marked [OPTIMIZED]) will be unoptimized ([OPTIMIZED] tag will be
removed). If the knob is turned on, they will be optimized again.

[108] kref.txt

kref可以为你自定义的结构体提供一个引用计数器，前面[106]中提到的kobject也可以实
现该功能，但是kobject比较复杂，如果只是提供一个简单的引用计数器的话，应该使用
kref而不是kobject。

krefs allow you to add reference counters to your objects.  If you
have objects that are used in multiple places and passed around, and
you don't have refcounts, your code is almost certainly broken.  If
you want refcounts, krefs are the way to go.

To use a kref, add one to your data structures like:

struct my_data
{
        .
        .
        struct kref refcount;
        .
        .
};

The kref can occur anywhere within the data structure.

You must initialize the kref after you allocate it.  To do this, call
kref_init as so:

     struct my_data *data;
    
     data = kmalloc(sizeof(*data), GFP_KERNEL);
     if (!data)
            return -ENOMEM;
     kref_init(&data->refcount);

This sets the refcount in the kref to 1.

Once you have an initialized kref, you must follow the following
rules:

1) If you make a non-temporary copy of a pointer, especially if
   it can be passed to another thread of execution, you must
   increment the refcount with kref_get() before passing it off:
       kref_get(&data->refcount);
   If you already have a valid pointer to a kref-ed structure (the
   refcount cannot go to zero) you may do this without a lock.

2) When you are done with a pointer, you must call kref_put():
       kref_put(&data->refcount, data_release);
   If this is the last reference to the pointer, the release
   routine will be called.  If the code never tries to get
   a valid pointer to a kref-ed structure without already
   holding a valid pointer, it is safe to do this without
   a lock.

3) If the code attempts to gain a reference to a kref-ed structure
   without already holding a valid pointer, it must serialize access
   where a kref_put() cannot occur during the kref_get(), and the
   structure must remain valid during the kref_get().

For example, if you allocate some data and then pass it to another
thread to process:

void data_release(struct kref *ref)
{
        struct my_data *data = container_of(ref, struct my_data, refcount);
        kfree(data);
}

void more_data_handling(void *cb_data)
{
        struct my_data *data = cb_data;
        .
        . do stuff with data here
        .
        kref_put(&data->refcount, data_release);
}

int my_data_handler(void)
{
        int rv = 0;
        struct my_data *data;
        struct task_struct *task;
        data = kmalloc(sizeof(*data), GFP_KERNEL);
        if (!data)
                return -ENOMEM;
        kref_init(&data->refcount);

        kref_get(&data->refcount);
        task = kthread_run(more_data_handling, data, "more_data_handling");
        if (task == ERR_PTR(-ENOMEM)) {
                rv = -ENOMEM;
                goto out;
        }
    
        .
        . do stuff with data here
        .
 out:
        kref_put(&data->refcount, data_release);
        return rv;
}

This way, it doesn't matter what order the two threads handle the
data, the kref_put() handles knowing when the data is not referenced
any more and releasing it.  The kref_get() does not require a lock,
since we already have a valid pointer that we own a refcount for.  The
put needs no lock because nothing tries to get the data without
already holding a pointer.

Note that the "before" in rule 1 is very important.  You should never
do something like:

        task = kthread_run(more_data_handling, data, "more_data_handling");
        if (task == ERR_PTR(-ENOMEM)) {
                rv = -ENOMEM;
                goto out;
        } else
                /* BAD BAD BAD - get is after the handoff */
                kref_get(&data->refcount);

Don't assume you know what you are doing and use the above construct.
First of all, you may not know what you are doing.  Second, you may
know what you are doing (there are some situations where locking is
involved where the above may be legal) but someone else who doesn't
know what they are doing may change the code or copy the code.  It's
bad style.  Don't do it.

There are some situations where you can optimize the gets and puts.
For instance, if you are done with an object and enqueuing it for
something else or passing it off to something else, there is no reason
to do a get then a put:

        /* Silly extra get and put */
        kref_get(&obj->ref);
        enqueue(obj);
        kref_put(&obj->ref, obj_cleanup);

Just do the enqueue.  A comment about this is always welcome:

        enqueue(obj);
        /* We are done with obj, so we pass our refcount off
           to the queue.  DON'T TOUCH obj AFTER HERE! */

The last rule (rule 3) is the nastiest one to handle.  Say, for
instance, you have a list of items that are each kref-ed, and you wish
to get the first one.  You can't just pull the first item off the list
and kref_get() it.  That violates rule 3 because you are not already
holding a valid pointer.  You must add a mutex (or some other lock).
For instance:

static DEFINE_MUTEX(mutex);
static LIST_HEAD(q);
struct my_data
{
        struct kref      refcount;
        struct list_head link;
};

static struct my_data *get_entry()
{
        struct my_data *entry = NULL;
        mutex_lock(&mutex);
        if (!list_empty(&q)) {
                entry = container_of(q.next, struct my_data, link);
                kref_get(&entry->refcount);
        }
        mutex_unlock(&mutex);
        return entry;
}

static void release_entry(struct kref *ref)
{
        struct my_data *entry = container_of(ref, struct my_data, refcount);

        list_del(&entry->link);
        kfree(entry);
}

static void put_entry(struct my_data *entry)
{
        mutex_lock(&mutex);
        kref_put(&entry->refcount, release_entry);
        mutex_unlock(&mutex);
}

The kref_put() return value is useful if you do not want to hold the
lock during the whole release operation.  Say you didn't want to call
kfree() with the lock held in the example above (since it is kind of
pointless to do so).  You could use kref_put() as follows:

static void release_entry(struct kref *ref)
{
        /* All work is done after the return from kref_put(). */
}

static void put_entry(struct my_data *entry)
{
        mutex_lock(&mutex);
        if (kref_put(&entry->refcount, release_entry)) {
                list_del(&entry->link);
                mutex_unlock(&mutex);
                kfree(entry);
        } else
                mutex_unlock(&mutex);
}

This is really more useful if you have to call other routines as part
of the free operations that could take a long time or might claim the
same lock.  Note that doing everything in the release routine is still
preferred as it is a little neater.


Corey Minyard <minyard@acm.org>

A lot of this was lifted from Greg Kroah-Hartman's 2004 OLS paper and
presentation on krefs, which can be found at:
  http://www.kroah.com/linux/talks/ols_2004_kref_paper/Reprint-Kroah-Hartman-OLS2004.pdf
and:
  http://www.kroah.com/linux/talks/ols_2004_kref_talk/

[109] ldm.txt

LDM - Logical Disk Manager (Dynamic Disks)
------------------------------------------

Originally Written by FlatCap - Richard Russon <ldm@flatcap.org>.
Last Updated by Anton Altaparmakov on 30 March 2007 for Windows Vista.

Overview
--------

Windows 2000, XP, and Vista use a new partitioning scheme.  It is a complete
replacement for the MSDOS style partitions.  It stores its information in a
1MiB journalled database at the end of the physical disk.  The size of
partitions is limited only by disk space.  The maximum number of partitions is
nearly 2000.

Any partitions created under the LDM are called "Dynamic Disks".  There are no
longer any primary or extended partitions.  Normal MSDOS style partitions are
now known as Basic Disks.

If you wish to use Spanned, Striped, Mirrored or RAID 5 Volumes, you must use
Dynamic Disks.  The journalling allows Windows to make changes to these
partitions and filesystems without the need to reboot.

Once the LDM driver has divided up the disk, you can use the MD driver to
assemble any multi-partition volumes, e.g.  Stripes, RAID5.

To prevent legacy applications from repartitioning the disk, the LDM creates a
dummy MSDOS partition containing one disk-sized partition.  This is what is
supported with the Linux LDM driver.

A newer approach that has been implemented with Vista is to put LDM on top of a
GPT label disk.  This is not supported by the Linux LDM driver yet.


Example
-------

Below we have a 50MiB disk, divided into seven partitions.
N.B.  The missing 1MiB at the end of the disk is where the LDM database is
      stored.

  Device | Offset Bytes  Sectors  MiB | Size   Bytes  Sectors  MiB
  -------+----------------------------+---------------------------
  hda    |            0        0    0 |     52428800   102400   50
  hda1   |     51380224   100352   49 |      1048576     2048    1
  hda2   |        16384       32    0 |      6979584    13632    6
  hda3   |      6995968    13664    6 |     10485760    20480   10
  hda4   |     17481728    34144   16 |      4194304     8192    4
  hda5   |     21676032    42336   20 |      5242880    10240    5
  hda6   |     26918912    52576   25 |     10485760    20480   10
  hda7   |     37404672    73056   35 |     13959168    27264   13

The LDM Database may not store the partitions in the order that they appear on
disk, but the driver will sort them.

When Linux boots, you will see something like:

  hda: 102400 sectors w/32KiB Cache, CHS=50/64/32
  hda: [LDM] hda1 hda2 hda3 hda4 hda5 hda6 hda7


Compiling LDM Support
---------------------

To enable LDM, choose the following two options: 

  "Advanced partition selection" CONFIG_PARTITION_ADVANCED
  "Windows Logical Disk Manager (Dynamic Disk) support" CONFIG_LDM_PARTITION

If you believe the driver isn't working as it should, you can enable the extra
debugging code.  This will produce a LOT of output.  The option is:

  "Windows LDM extra logging" CONFIG_LDM_DEBUG

N.B. The partition code cannot be compiled as a module.

As with all the partition code, if the driver doesn't see signs of its type of
partition, it will pass control to another driver, so there is no harm in
enabling it.

If you have Dynamic Disks but don't enable the driver, then all you will see
is a dummy MSDOS partition filling the whole disk.  You won't be able to mount
any of the volumes on the disk.


Booting
-------

If you enable LDM support, then lilo is capable of booting from any of the
discovered partitions.  However, grub does not understand the LDM partitioning
and cannot boot from a Dynamic Disk.


More Documentation
------------------

There is an Overview of the LDM together with complete Technical Documentation.
It is available for download.

  http://www.linux-ntfs.org/

If you have any LDM questions that aren't answered in the documentation, email
me.

Cheers,
    FlatCap - Richard Russon
    ldm@flatcap.org

[110] local_ops.txt 

前面了解了x86上non-irq自旋锁的实现，理解起来没有问题！
但是现在问的是，多核cpu如何实现同步？？？可能要cpu提供支持或者内存控制器进行支
持。
有人提问过，可以参考下。
http://stackoverflow.com/questions/8188649/
    in-multi-core-multi-processor-architecture-what-part-of-the-system-synchronize
http://stackoverflow.com/questions/20858260/
    how-can-synchronize-data-between-differernt-cores-on-xeon-linux-how-to-use-memo

