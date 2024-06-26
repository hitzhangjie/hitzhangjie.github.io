---
layout: post  
title: Linux常见IO模型
description: "高性能服务器开发，离不开对网络IO的深刻认识。本文结合Linux平台，详细总结了阻塞IO、非阻塞IO、IO多路复用、实时信号驱动、异步IO的原理、使用、适用场景，加深了对网络IO的认识。"
date: 2017-05-02 21:42:13 +0800
tags: ["io","io-multiplex","rtsig","aio"]
toc: true
reward: true
---

目前Linux下可用的IO模型有5种，分别为阻塞IO、非阻塞IO、IO多路复用、信号驱动IO、异步IO，其中较为成熟且高效、稳定的是IO多路复用模型，因此当前众多网络服务程序几乎都是采用这种IO操作策略。

当一个应用程序读写（以读为例）某端口数据时，选择不同IO模型的应用程序，其执行流程也将不同。下面将对选择这5种不同IO模型时的程序的执行情形进行分析，以便了解使用IO复用模型的运行情况和性能优势。

一个完整经典的应用程序的数据读取操作可以看做两步：
- 等待数据准备好；
- 将数据从内核复制到应用程序进程；

## 1. 阻塞IO模型

最流行的IO模型是阻塞IO（Blocking IO）模型，几乎所有刚开始学习IO操作的人员都是使用这个模型，虽然它存在一定的性能缺陷，但是它的确很简单。

如下图所示，是利用该模型读取IO端口数据的典型流程。在有些情况下，当系统调用发现用户请求的IO操作不能立刻完成时（比如对IO写操作，缓冲区没有空闲空间或者空闲空间少于待写的数据量；而对于读操作，缓冲区中没有数据可读或者可读数据少于用户请求的数据量），则当前的进程会进入睡眠，也就是进程被IO读写阻塞。但是当数据可以写出或者有数据可供读入时（其他进程或线程从缓冲区中读走了数据后或者向缓冲区写入了数据），系统将会产生中断，唤醒在缓冲区上等待相应事件的进程继续执行。

![Blocking-IO-Model]

>备注：  
有必要在这里进一步解释一下“阻塞IO”的含义。通过阻塞IO系统调用进行IO操作时，以read为例，在内核将数据拷贝到用户程序完成之前，Linux内核会对当前read请求操作的缓冲区（内存中的特殊区域）进行加锁，并且会将调用read的进程的状态设置为
**“uninterruptible wait”状态（不可中断等待状态）**，处于该状态的进程将无法参与进程调度。能够参与进程调度的进程的状态必须是处于running状态的进程或者有信号到达的处于interruptible wait状态（可中断等待状态）的进程。当read操作完成时，内核会将对应的缓冲块解锁，然后发出中断请求，内核中的中断服务程序会将阻塞在该缓冲块上的进程的状态修改为running状态以使其重新具备参与进程调度的能力。

## 2. 非阻塞IO模型

在有些时候并不希望进程在IO操作未完成时睡眠，而是希望系统调用能够立刻返回一个错误，以报告这一情况，然后进程可以根据需要在适当的时候再重新执行这个IO操作。这就是所谓的非阻塞IO模型。

如下图所示，应用程序前几次read系统调用时都没有数据可供返回，此时内核立即返回一个EAGAIN错误代码，程序并不睡眠而是继续调用read，当第四次调用read时数据准备好了，于是执行数据从内核到用户空间的复制操作并成功返回，应用程序接着处理数据。**这种对一个非阻塞IO端口反复调用read进行数据读取的动作称为轮询**，即应用程序持续轮询内核数据是否准备好。这里的持续轮询操作将导致耗费大量的CPU时间，因此该模型并不推荐使用。

![NonBlocking-IO-Model]

## 3. IO多路复用模型

前面介绍了**非阻塞IO模型的问题在于，尽管应用程序可以在当前IO操作不能完成的时候迫使系统调用立刻返回而不至于睡眠，但是却无法知道什么时候再次请求IO操作可以顺利完成，只能周期性地做很多无谓的轮询**，每隔一段时间就要重新请求一次系统调用，这种轮询策略极大浪费了CPU时间。

**IO多路复用模型就是在此之上的改进，它的好处在于使得应用程序可以同时对多个IO端口进行监控以判断其上的操作是否可以顺利（无阻塞地）完成，达到时间复用的目的**。进程阻塞在类似于select、poll或epoll这样的系统调用上，而不是阻塞在真正的IO系统调用上，意思也就是说在这些select、poll或者epoll函数内部会代替我们做非阻塞地轮询，那么它的轮询策略是怎样地呢？稍后会进行介绍。

select、poll或epoll使得进程可以在多个IO端口上等待IO事件（可读、可写、网络连接请求等）的发生，当有事件发生时再根据发生事件的类型进行适当的IO处理。不过进程在等待IO事件发生时仍然在代码执行序上处于“阻塞”状态，应用程序“阻塞”在这里照样还是无法做其他的工作（尽管可以指定轮询时等待时间的长短）。如果希望进程在没有IO事件要处理时还能做其他的工作，可以考虑分派任务给其他线程、进程，当然也可以在当前线程做，但是不宜过久以免影响处理IO事件。

下图是IO多路复用模型的示例。

![IO-Multiplexing]

IO多路复用模型主要有3种实现形式，select、poll、epoll。

### 3.1. select

```c
#include <sys/select.h>

//返回值：readfds、writefds、exceptfds中事件就绪的fd的数量
int select(int nfds,                                    // 最大文件描述符fd+1
           fd_set *restrict readfds,                    // 等待读取的fds
           fd_set *restrict writefds,                   // 等待写入的fds
           fd_set *restrict exceptfds,                  // 异常fds
           struct timeval *restrict timeout);           // 超时时间
           
//返回值：readfds、writefds、exceptfds中事件就绪的fd的数量
int pselect(int nfds,                                   // 最大文件描述符fd+1
            fd_set *restrict readfds,                   // 等待读取的fds
            fd_set *restrict writefds,                  // 等待写入的fds
            fd_set *restrict exceptfds,                 // 异常fds
            const struct timespec *restrict timeout,    // 超时时间
            const sigset_t *restrict sigmask);          // 信号掩码
```

>备注：  
IO事件就绪的意思是，执行对应的IO操作时可以无阻塞地完成。例如读事件就绪，表明一定有数据到达，或者已经读取到了数据的结束位置EOF。

```c
#define __FD_SETSIZE 1024
typedef struct { 
    /* XPG4.2 requires this member name.  Otherwise avoid the name from the global namespace.  */
    #ifdef __USE_XOPEN
        __fd_mask fds_bits[__FD_SETSIZE / __NFDBITS];
        # define __FDS_BITS(set) ((set)->fds_bits)
    #else
        __fd_mask __fds_bits[__FD_SETSIZE / __NFDBITS];
        # define __FDS_BITS(set) ((set)->__fds_bits)
    #endif
} fd_set;            
```

select和pselect基本是相同的，它们主要有3点细微的差别：
- select使用的超时时间struct timeval是微秒级的，而pselect使用的struct timespec可以精确到纳秒级；
- select会更新timeout的值，将其修改为剩余轮询时间，而pselect不会对timeout做修改；
- select无法指定轮询时的信号掩码，而pselect允许指定信号掩码，如果pselect第6个参数不为NULL，则用其先替换当前的信号掩码，然后执行与select相同的操作，返回时再还原之前的信号掩码；

fd_set只是一个普通的用于记录待监视的fd的位图，由于__FD_SETSIZE硬编码为1024，所以select最多只能监视1024个fd。

对fd_set的操作主要通过如下几个函数。

```c
#include <sys/select.h>

void FD_CLR(int fd, fd_set *fdset);                 // 从fdset中删除fd
void FD_ISSET(int fd, fd_set *fdset);               // 测试fd是否已添加到fdset中
void FD_SET(int fd, fd_set *fdset);                 // 向fdset中添加fd
void FD_ZERO(fd_set *fdset);                        // 清空fdset
```

下面对timeout相关的数据结构进行一下说明：
- 如果timeout中的两个字段均为0，则表示select立即返回；
- 如果timeout中的任意一个字段不为0，则表示select轮询时经过指定的时间后会返回；
- 如果timeout为NULL，则表示select会阻塞到有事件就绪才返回；

```c
struct timeval {
    long tv_sec;
    long tv_usec;
};

struct timespec {
    long tv_sec;
    long tv_nsec;
};

```

**在循环使用select函数时有三个地方值得注意**:
- 第一，虽然在普遍情况下，参数timeout在select函数返回时不会被修改，但是有的Linux版本却会将这个值修改成函数返回时剩余的等待秒数，因此从可移植性上考虑，在每次重新调用select函数前都得再次对参数timeout初始化。
- 第二，select函数中间的三个参数（即感兴趣的描述符集）在select函数返回时，其保存有指示哪些描述符已经进入就绪状态（此时其对应bit被设置为1，其他未就绪描述符对应bit设置为0），从而程序可以使用宏FD_ISSET来测试描述符集中的就绪描述符。因此，在每次重新调用select函数前都得再次把所有描述符集中关注的fd对应的bit设置为1。
- 第三，应注意到利用select函数监控的最大描述符收到系统FD_SETSIZE宏的限制，最多能够监视1024个描述符，在高并发情景中，select是难以胜任的。

下面是select的编程模板，可在此基础上进行改进。

```c
// 可读、可写、异常3种文件描述符集的声明和初始化
fd_set readfds, writefds, exceptfds;

FD_ZERO(&readfds);
FD_ZERO(&writefds);
FD_ZERO(&exceptfds);

int max_fd;

// socket配置和监听
int sock = socket(...);
bind(sock, ...);
listen(sock, ...);

// 对socket描述符上关心的事件进行注册，select不要求fd非阻塞
FD_SET(sock, &readfds);
max_fd = sock;

while(1) {

    int i;
    fd_set r, w, e;

    // 为了重复使用readfds、writefds、exceptionfds，将他们复制到临时变量内
    memcpy(&r, &readfds, sizeof(fd_set));
    memcpy(&w, &writefds, sizeof(fd_set));
    memcpy(&e, &exceptfds, sizeof(fd_set));

    // 利用临时变量调用select阻塞等待，等待时间为永远等待直到事件发生
    select(max_fd+1, &r, &w, &e, NULL);

    // 测试是否有客户端发起连接请求，如果有则接受并把新建的描述符加入监控
    if(FD_ISSET(sock, &r)) {
        new_sock = accept(sock, ...);

        FD_SET(new_sock, &readfds);
        FD_SET(new_sock, &writefds);

        max_fd = MAX(max_fd, new_sock);
    }

    // 对其他描述符上发生的事件进行适当处理
    // 描述符依次递增，各系统的最大值可能有所不同，一般可以通过ulimit -n进行设置
    for(i=sock+1; i<max_fd+1; ++i) {
        if(FD_ISSET(i, &r)) {
            doReadAction(i);
        }
        if(FD_ISSET(i, &w)) {
            doWriteAction(i);
        }
    }
}

```

>备注：
上述只是一个非常简单的select使用示例，在实际使用过程中需要考虑一些其他的因素，例如对端的tcp连接socket关闭时应该怎样处理，关闭又可以细分为关闭读和写两种情况。

**代码示例**：   
**点击这里查看基于select实现的tcp server，[[click to see select-based-tcp-server]](https://github.com/hitzhangjie/Linux-IO-Model/tree/master/io-select)**。

### 3.2. poll

```c
#include <poll.h>

int poll(struct pollfd *fds,                        // 待监视的fd构成的struct pollfd数组
         nfds_t nfds,                               // 数组fds[]中元素数量
         int timeout);                              // 轮询时等待的最大超时时间

struct pollfd {
    int fd;                                         // 待监视的fd
    short events;                                   // 请求监视的事件
    short revents;                                  // 实际收到的事件
};

```

pollfd中可指定的event类型包括：
- POLLIN，普通数据读取；
- POLLPRI，紧急数据读取；
- POLLOUT，普通数据可写；
- POLLRDHUP，面向流的socket，对端socket关闭连接或者关闭了写半连接；
- POLLERR，错误；
- POLLHUP，挂起；
- POLLNVAL，无效请求，fd没有打开；

当如果通过宏_XOPEN_SOURCE进行条件编译时，还可指定如下event类型：
- POLLRDNORM，与POLLIN等效；
- POLLRDBAND，优先级带数据可读，在Linux上通常是无用的；
- POLLWRNORM，与POLLOUT等效；
- POLLWRBAND，优先级数据可写；

poll系统调用的第三个参数timeout指定了轮询时的等待事件，当timeout<0时永远等待直到监视的fds上有事件发生，当timeout=0时立即返回，单timeout>0时等待到指定的超时时间后返回。poll不要求监视的fd为非阻塞。

**poll与select相比具有如下优势**：  
- poll系统调用中通过第二个参数nfds来限定要监视的描述符的数量，与select相比，poll去掉了硬编码的FD_SETSIZE宏的监控fd数量上限；
- 另外poll通过pollfd中的revents来接收fd上到达的事件，events不会被修改，每次调用poll时不用像select一样每次都需要重新设置r、w、e文件描述符集，方便使用也减少数据向内核拷贝的开销。

```c
// 新建并初始化文件描述符集
struct pollfd fds[MAX_NUM_FDS];
int max_fd;

// socket配置和监听
sock = socket(...);
bind(sock, ...);
listen(sock, ...);

// 对socket描述符上关心的事件进行注册
fds[0].fd = sock;
fds[0].events = POLLIN;
max_fd = 1;

while(1) {

    int i;

    // 调用poll阻塞等待，等待时间为永远等待直到事件发生
    poll（fds, max_fd, -1);

    // 测试是否有客户端发起连接请求，如果有则接受并把新建的描述符加入监控
    if(fds[0].revents & POLLIN) {
        new_sock = accept(sock, ...);

        fds[max_fd].fd = new_sock;
        fds[max_fd].events = POLLIN | POLLOUT;

        ++ max_fd;
    }
    
    // 对其他描述符发生的事件进行适当处理
    for(i=1; i<max_fd+1; ++i) {
        if(fds[i].revents & POLLIN) {
            doReadAction(i);
        }
        if(fds[i].revents & POLLOUT) {
            doWriteAction(i);
        }
    }
}
```

>备注：  
上面的代码也是只给出了一个最简单的编程示例，对于对端tcp连接关闭的情况也需要予以考虑，避免服用端占用大量的fd。  
从上面基于select/poll多路复用IO模型可以看出，在大量的并发连接中，如果空闲连接（即无事件发生的连接）较多，select/poll的性能会因为并发数的线性上升而成线型速度下降，实际上性能可能比线型下降更差。当连接数很大时，系统开销会异常大。  
另外select、poll每次返回时都需要从内核向用户空间复制大量的数据，数据复制的开销也会很大，select主要是从内核向用户空间复制readfds、writefds、exceptfds开销大，poll主要是从内核复制pollfd[]开销大。  
使用select/poll实现的多路复用IO模型是最稳定也是使用最为广泛的事件驱动IO模型，但是其固有的一些缺点（如性能低下、伸缩性不强）使得各种更为先进的替代方案出现在各种平台下。

**代码示例**：   
**点击这里查看基于poll实现的tcp server，[[click to see poll-based-tcp-server]](https://github.com/hitzhangjie/Linux-IO-Model/tree/master/io-poll)**。

### 3.3. epoll

epoll作为poll的变体在Linux内核2.5中被引入，相比于select实现的多路复用IO模型，epoll的最大好处在于它不会随着监控描述符数目的增长而使效率急剧下降。在内核中的select实现是采用轮询处理的，轮询的描述符数目越多，自然耗时越多，而且在很多情况下，select最多能同时监听的描述符数目为1024个。

epoll提供了三种系统调用，如下所示。

```c
#include <sys/poll.h>

// 创建一个epfd，最多监视${size}个文件描述符
int epoll_create(int size);

int epoll_ctl(int epfd,                             // epfd
             int op,                                // 操作类型（注册、取消注册）
             int fd,                                // 待监视的fd
             struct epoll_event *event);            // 待监视的fd上的io事件

int epoll_wait(int epfd,                            // epfd
               struct epoll_event *events,          // 最终返回的就绪事件
               int maxevents,                       // 期望的就绪事件数量
               int timeout);                        // 超时时间

int epoll_wait(int epfd,                            // epfd
               struct epoll_event *events,          // 接收返回的就绪事件
               int maxevents,                       // 期望的就绪事件数量
               int timeout,                         // 超时时间
               const sigset_t *sigmask);            // 信号掩码

typedef union epoll_data {
    void *ptr;
    int fd;
    __uint32_t u32;
    __uint64_t u64;
} epoll_data_t;

struct epoll_event {
    __uint32_t events;                              // epoll events
    epoll_data_t data;                              // user data variable
};

```

epoll中可以关注的事件主要有：
- EPOLLIN，数据可读事件；
- EPOLLOUT，数据可写事件；
- EPOLLRDHUP，流socket对端关闭连接或者关闭了写半连接；
- EPOLLPRI，紧急数据读取事件；
- EPOLLERR，错误事件；
- EPOLLHUP，挂起事件，epoll总是会等待该事件，不需要显示设置；
- EPOLLET，设置epoll以边缘触发模式工作（不指定该选项则使用级别触发Level Trigger模式）；
- EPOLLONESHOT，设置epoll针对某个fd上的事件只通知一次，一旦epoll通知了某个事件，该fd上后续到达的事件将不会再发送通知，除非重新通过epoll_ctl EPOLL_CTL_MOD更新其关注的事件。

epoll事件的两种模型：

- LT，Level Triggered，译为水平触发或者级别触发，我更偏向于使用级别触发。级别触发是默认的工作方式，同时支持阻塞和非阻塞socket。在这种模式下，当描述符从未就绪变为就绪时，内核通过epoll告诉进程该描述符有事件发生，之后如果进程一直不对这个就绪状态做出任何操作，则内核会继续通知，直到事件处理完成。以LT方式调用的epoll接口就相当于一个速度比较快的poll模型。
- ET，Edge Triggered，译为边缘触发。边缘触发方式是高速工作方式，只支持非阻塞socket。在这种工作方式下，当描述符从未就绪变为就绪时，内核通过epoll告诉进程该描述符有事件发生，之后就算进程一直不对这个就绪状态做出任何操作，内核也不会再发送更多地通知，也就是说内核仅在该描述符事件到达的那个突变边缘对进程做出一次通知。  
根据ET方式的特性，epoll工作在此模式时必须使用非阻塞文件描述符，以避免由于一个文件描述符的阻塞读、阻塞写操作把处理多个文件描述符的任务“饿死”。  
调用ET模式epoll接口的推荐步骤如下：  
1）基于非阻塞文件描述符；  
2）只有当read或write返回EAGAIN（对于面向包/令牌的文件，比如数据报套接口、规范模式的终端）时，或是read/write读到/写出的数据长度小于请求的数据长度（对于面向流的文件，比如pipe、fifo、流套接口）时才需要挂起等待下一个事件。  
总的来说，在大并发的系统中，边缘触发模式比级别触发模式更具有优势，但是对于程序员的要求也更高。如果对于这两种模式想要了解得更加深入，那么建议读者阅读epoll相关的源代码。

下面是epoll多路复用IO模型的一个编程模板，可以在此基础上进行改进。

```c
// 创建并初始化文件描述符集
struct epoll_event ev;
struct epoll_event events[MAX_EVENTS];

// 创建epoll句柄epfd
int epfd = epoll_create(MAX_EVENTS);

// 监听socket配置
sock = socket(...);
bind(sock, ...);
listen(sock, ...);

// 对socket描述符上关心的事件进行注册
ev.events = EPOLLIN;
ev.data.fd = sock;
epoll_ctl(epfd, EPOLL_CTL_ADD, sock, &ev);

while(1) {

    int i;

    // 调用epoll_wait阻塞等待，等待事件未永远等待直到发生事件
    int n = epoll_wait(epfd, events, MAX_EVENTS, -1);
    for(i=0; i<n; ++i) {
        // 测试是否有客户端发起连接请求，如果有则接受并把新建的描述符加入监控
        if(events[i].data.fd == sock) {
            if(events[i].events & EPOLLIN) {
                new_sock = accept(sock, ...);

                ev.events = EPOLLIN | EPOLLOUT;
                ev.data.fd = new_sock;

                epoll_ctl(epfd, EPOLL_CTL_ADD, new_sock, &ev);
            }
        }
        else {
            // 对于其他描述符上发生的事件进行适当处理
            if(events[i].events & EPOLLIN) {
                doReadAction(i);
            }
            if(events[i].events & EPOLLOUT) {
                doWriteAction(i);
            }
        }
    }
}

```

>备注：
注意上面的代码也是仅仅给出了一个编程示例，实际应用过程中也需要考虑对端tcp连接关闭时对server端套接字的处理，比如通过epoll_ctl(epfd, EPOLL_CTL_DEL, fd, NULL)取消对fd上事件的轮询，并close(fd)_。服务端如果不注意对分配的套接字fd进行回收，很有可能达到系统允许的fd上限，那时候就会出现服务瘫痪，应注意避免这种情况的发生。

**备注**：  
**需要注意级别触发、边缘触发编码方式上的差别，这里首先要铭记一点，级别触发只在事件状态发生改变时通知一次，而边缘触发只要事件处于就绪状态那么就会在处理之前一直发送统治**。  
**使用边缘触发方式进行编程比使用级别触发编程要稍微复杂一些，需要时刻谨记上述差异，这里说两个直观的情景便于大家理解**。  
- **当通过epfd监听来自多个客户端的入连接请求时，可能一次会有大量客户端的入连接请求到达，一次epoll_wait，如果工作在边缘触发模式，就只会通知一次epfd可读事件就绪，因此在对epfd上的EPOLLIN进行事件处理时，需要通过一个while循环不停地调用accept来完成所有入连接请求的处理，而不是像上述编程示例（上例为LT触发模式）中一样一次EPOLLIN只调用一次accept，则级别触发模式下上述方式是可行的，但是边缘触发模式下会造成严重的bug**。  
- **当通过sock_conn对连接socket上到达的数据进行读取时，对于每一个socket_conn上的数据都要通过一个while循环不停读取知道再次read返回EAGAIN确保所有数据已读取完，因为这个时候不读取，以后就不会收到epoll_wait的再次通知，如果想读取基本上就退化为一个poll了，需要自己轮询或者测试是否可读，影响性能**。  
- **对于sock_conn上数据写操作的处理，与sock_conn上数据读的处理是相似的**。

**与select、poll相比，epoll具有如下优点**：
- epoll每次只返回有事件发生的文件描述符信息，这样调用者不用遍历整个文件描述符队列；
- 使用epoll使得系统不用从内核向用户空间复制数据，因为它是利用mmap使内核和用户空间贡献一块内存；
- 另外epoll可以设置不同的事件触发方式，包括边缘触发和级别触发两种，为用户使用epoll提供了灵活性。

**代码示例**：   
**点击这里查看基于epoll实现的tcp server，[[click to see epoll-based-tcp-server]](https://github.com/hitzhangjie/Linux-IO-Model/tree/master/io-epoll)**。注意，这里的代码实现中包括了两个tcp server实现，一个是基于边缘触发模式(ET)，一个是基于级别触发模式(LT)。

## 4. 实时信号驱动IO模型

实时信号驱动(rtsig)IO模型使得应用程序不需要阻塞在某一个或多个IO端口上，它先利用系统调用sigaction来安装某个端口的事件信号处理函数，该系统调用sigaction执行成功后立即返回，进程继续往下工作而不被阻塞，当某个IO端口上可进行数据操作时，内核就为该进程产生一个SIGIO信号，进程收到该信号后相应地在信号处理函数里进行IO操作，因此，这种机制使得程序能够在一个更合适的时间点被通知到，被通知去执行IO事件处理，之所以说是通知的时间点更好，是因为此时进行IO需要的数据已就绪，IO处理可以保证无阻塞地完成。

![RtSig-IO-Model]

实时信号驱动IO完全不是在select/poll基础上的修改，而是对传统信号驱动IO的完善，因此它是完全不同于前面介绍的几种解决方案的事件驱动IO机制。

要使用实时信号驱动IO模型相对于处理普通的信号要稍微复杂一点，除了要为SIGIO信号建立信号处理函数（在该处理函数内当然要包含对实际IO操作的系统调用）以外，还需要额外的步骤，如对IO端口做一些设置以便启用信号驱动IO功能。首先要设置描述符的所有者，这可以通过fcntl的F_SETOWN操作来完成，**fcntl(fd, F_SETOWN, (int)pid)**，接着要启用描述符的信号驱动IO模式，这个步骤一般是通过fcntl的F_SETFL来设置O_ASYNC标识来完成的，**fcntl(fd, F_SETFL, O_ASYNC\|O_NONBLOCK\|O_RDWR)**。另外，如果有必要还可以重新设置描述符可读写时要发送的信号值，这可以通过fcntl的F_SETSIG指定，**fcntl(fd, F_SETSIG, ev->signum)**。

>备注：  
要使用F_SETSIG常量值必须在其源文件开头包含宏定义“#define __USE_GNU”或者“#define _GNU_SOURCE”，当然也可以通过GCC -D来指定宏。不过推荐使用宏_GNU_SOURCE而不是__USE_GNU宏。原因是，双划线开头的宏一般是由系统中的头文件对其进行定义、扩展，而不是在普通应用程序中。

可以看到所谓的实时信号驱动IO模型就是利用了O_ASYNC来使得当描述符可读、写时发送通知信号（采用非常规可排队的POSIX实时信号）从而使得进程可以异步执行。

该模型有一些缺点：
- O_ASYNC仅能工作于socket描述符上，而不能工作于管道（pipe）或中断（tty）上；
- O_ASYNC为边缘触发方式，因此事件处理函数必须完整的完成某个事件处理动作（比如读取数据则必须读取完），否则不能保证进程可靠的再次接收到信号通知；

>备注：  
RTSIG的实现与进程怎样分派信号密切相关，对每一个发生的事件就递交一个信号通知将是十分浪费的，因此一般考虑使用sigtimedwait()函数来阻塞等待进程关心的信号，并且结合利用poll()函数实现对描述符事件的水平触发效果。

据某些开发人员测试，在一定条件下的实时信号驱动IO模型表现性能比其他基于poll的IO模型都要好，但是这种方案似乎并不可靠，很多开发人员给出的建议就是不要使用这种方式。

下面给出了一个利用RTSIG IO的编程范例。

```c
// 屏蔽不关心的信号
sigset_t all;
sigfillset(&all);
sigdelset(&all, SIGINT);
sigprocmask(SIG_SETMASK, &all, NULL);

// 新建并初始化关心的信号
sigset_t sigset;
siginfo_t siginfo;

// sigwaitinfo调用时会阻塞，除非收到wait的信号集中的某个信号
sigemptyset(&sigset);
sigaddset(&sigset, SIGRTMIN + 1);

// socket配置和监听
sock = socket(...);
bind(sock, ...);
listen(sock, ...);

// 重新设置描述符可读写时要发送的信号值
fcntl(sock, F_SETSIG, SIGRTMIN + 1);

// 对socket描述符设置所有者
fcntl(sock, F_SETOWN, getpid());

// 启用描述符的信号驱动IO模式
int flags = fcntl(sock, F_GETFL);
fcntl(sock, F_SETFL, flags|O_ASYNC|O_NONBLOCK);

while(1) {
    struct timespec ts;
    ts.tv_sec = 1;
    ts.tv_nsec = 0;

    // 调用sigtimedwait阻塞等待，等待事件1s & sigwaitinfo会一直阻塞
    // - 通过这种方式可以达到一种类似级别触发的效果，不再是边缘触发；
    // - 边缘触发效果，应该通过同一个sighandler进行处理，但是处理起来比较麻烦：
    //   - 假如不同的连接socket使用相同的信号，那么sighandler里无法区分事件就绪的fd；
    //   - 假如不同的连接socket使用不同的信号，实时信号数量有限SIGRTMIN~SIGRTMAX大约才32个！
    //sigtimedwait(&sigset, &siginfo, &ts);
    sigwaitinfo(&sigset, &siginfo);

    // 测试是否有客户端发起连接请求
    if(siginfo.si_fd == sock) {
        new_sock = accept(sock, ...);
        fcntl(new_sock, F_SETSIG, SIGRTMIN + 1);
        fcntl(new_sock, F_SETOWN, getpid() + 1);
        fcntl(new_sock, F_SETFL, O_ASYNC|O_NONBLOCK|O_RDWR);
    }
    // 对其他描述符上发生的读写事件进行处理
    else {
        doReadAction(i);
        doWriteAction(i);
    }
}
```

上面的代码看起来似乎挺简单，很多人看了之后可能还很想尝试并在实践中应用，这里要注意的是，rtsig driven io并没有那么简单、有效！且听我细细道来！

### 4.1 rtsig在udp中应用

rtsig driven io在udp server中较为简单，因为udp中只有两种情况会为fd raise一个rtsig：
1. fd上有数据到达；
2. fd上io操作有错误；

我的repo里面有一个基于rtsig实现的udp server，实现起来很简单，不需要做什么特殊处理逻辑就可以轻松实现，虽然说rtsig不怎么被看好吧，但是至少有个服务ntp还是使用的rtsig & udp来实现的，可是tcp就不同了，好像还没有一个tcp server是基于rtsig实现的，很多人都反对在tcp中应用rtsig，因为太啰嗦而且很“没用”，每个io事件都raise一个信号也是个累赘，要判断的可能的io状态太多。

**代码示例**：   
**点击查看基于rtsig实现的udp server示例：[[click to see rtsig-udp-server]](https://github.com/hitzhangjie/Linux-IO-Model/tree/master/rtsig-udp)**。

### 4.2 rtsig在tcp中应用

rtsig drive io在tcp server中实现就复杂多了，因为对于一个fd有7种可能的情景会为其raise一个rtsig：
1. fd上完成了一个建立连接的请求；
2. fd上发起了一个断开连接的请求；
3. fd上完成了一个断开连接的请求；
4. fd上有数据到达；
5. fd上有数据写出；
6. fd上半连接关闭；
7. fd上有错误发生；

这么多的情景需要作很多额外的判断才能加以区分，所以很多开发人员建议在tcp中只将rtsig应用在监听套接字sock_listen上，对于连接套接字还是基于select、poll、epoll来操作，其实即便这样也是费力不讨好，因为rtsig也存在可能丢失的问题！而且它是边缘触发，对程序员要求也比较高。建议还是用epoll吧！

这里的tcp server中采用的是通过sigtimedwait/sigwaitinfo & siginfo_t.si_fd来区分收到rtsig的连接套接字、监听套接字的，然后再针对性地进行io处理！在我们的另一个基于rtsig的tcpserver实现中，我们通过同一个sighandler收到SIGIO信号时建立tcp连接并随即选择一个连接进行处理，虽然我们实现了，不过也不是一个特别clean的方法，不建议使用rtsig driven io，还是用IO多路复用来的清爽！

**代码示例**：   
**点击查看基于rtsig实现的tcp server示例**：
- **示例1，基于sigtimedwait/sigwaitinfo & siginfo_t.si_fd来区分连接fd，[[click to see rtsig-tcp-server-1]](https://github.com/hitzhangjie/Linux-IO-Model/tree/master/rtsig-tcp)**；
- **示例2，基于sighandler以及一点小技巧实现的对多个连接fd进行处理，[[click to see rtsig-tcp-server-2]](https://github.com/hitzhangjie/Linux-IO-Model/tree/master/rtsig-tcp2)**；

## 5. 异步IO模型

异步IO也是属于POSIX规范的一部分，类似实时信号驱动IO的异步通知机制，这也使得异步IO模型常常与后者相混淆。与后者的区别在于，启用异步IO意味着告知内核启动某个IO操作，并让内核在整个操作（包括将数据从内核复制到用户空间的缓冲区）完成时通知我们。也就是说，**实时信号驱动IO是由内核通知我们何时可以启动一个IO操作，而在异步IO模型中，是由内核通知我们IO操作何时完成，即实际的IO操作是异步的**。

![Async-IO-Model]

### 5.1. AIO API说明
下面的内容摘自Linux man手册，其对POSIX下的AIO接口、实现做了一个基础的介绍。在此基础上，我们将把AIO应用于后台服务中。

POSIX AIO接口允许应用程序发起一个或者多个IO操作，这些IO操作是异步执行的，即相比于当前发起IO操作的线程来说这些实际的IO操作是在“后台”运行的。IO操作完成时，可以选择多种方式来通知应用程序完成这一事件，例如：
- 传递一个信号给应用程序通知其IO操作完成；
- 在应用程序中额外实例化一个线程来对IO完成操作进行后处理；
- 也可能根本不会通知应用程序；

前面第4节讲过的rtsig driven io也可以算是异步的，从其当时使用的选项O_ASYNC就可以看出来，也可以称其为AIO（Asynchronous IO），但是呢，这里本节所提到的AIO主要指的是POSIX规范里面定义的AIO API。

#### 5.1.1. POSIX AIO API

**POSIX AIO接口包括如下几个函数**：
- aio_read(3)：入队一个read请求，它是read的异步操作版本；
- aio_write(3)：入队一个write请求，它是write的异步操作版本；
- aio_fsync(3)：入队一个sync请求（针对某个fd上的IO操作），它是fsync和fdatasync的异步版本；
- aio_error(3)：获取一个已入队的IO请求的错误状态信息；
- aio_return(3)：获取一个已完成的IO请求的返回状态信息；
- aio_suspend(3)：挂起IO请求的发起者，直到指定的一个或多个IO事件完成；
- aio_cancel(3)：尝试取消已经发起的某个特定fd上的未完成的IO请求；
- lio_listio(3)：使用这一个函数可以一次性入队多个IO请求；

#### 5.1.2. Linux AIO SysCall
**通过上面几个函数后面的“(3)”可以知道，上述几个函数都是普通的libc库函数，而不是系统调用，实际上上述这些纯用户态的库函数是基于5个系统调用来实现的，它们是**：
- io_setup(2) - **int io_setup(unsigned nr_events, aio_context_t \*ctx_idp)**  
该函数在内核中为进程创建一个AIO Context，AIO Context是多个数据结构的集合，用于支持内核的AIO操作。每一个进程可以拥有多个AIO Context，每一个AIO Context都有一个唯一的标识符，AIO Context类型aio_context_t变量作为io_setup的第二个参数，内核会设置其对应的值，实际上这个aio_context_t类型仅仅是一个unsigned long类型(typedef unsigned long aio_context_t），io_setup的第一个参数表示aio_context_t变量要支持的同时发起的IO请求的数量。
- io_destroy(2) - **int io_destroy(aio_context_t ctx_id)**  
该函数用于销毁AIO Context变量，销毁之前有两个操作，首先取消基于该aio_context_t发起的未完成的AIO请求，然后对于无法取消的AIO请求就阻塞当前进程等待其执行完成，最后销毁AIO Context。
- io_submit(2) - **int io_submit(aio_context_t ctx_id, long nr, struct iocb \*\*iocbpp)**  
该函数将向aio_context_t ctx_id上提交nr个IO请求，每个IO请求是由一个aio control block来指示的，第三个参数struct iocb **iocbpp是一个aio控制块的指针数组。
- io_getevents(2) - **int io_getevents(aio_context_t ctx_id, long min_nr, long nr, struct io_event \*events, struct timespec \*timeout)**  
等待aio_context_t ctx_id关联的aio请求已完成队列中返回最少min_nr个事件，最多nr个事件，如果指定了timeout则最多等待该指定的时间，如果timeout为NULL则至少等待min_nr个事件返回。
- io_cancel(2) - **int io_cancel(aio_context_t ctx_id, struct iocb \*iocb, struct io_event \*result)**  
该函数取消之前提交到aio_context_t ctx_id的一个AIO请求，这个请求由struct iocb *iocb标识，如果这个AIO请求成功取消了，对应的事件将被拷贝到第三个参数struct io_event *result指向的内存中，而不是将其放在已完成队列中。

>备注：  
上述几个内核中的函数io_setup、io_destroy、io_submit、io_getevents、io_cancel，libc中并没有提供对应的wrapper函数供我们调用，如果要使用这些函数的话，可以通过syscall(2)来调用，以调用io_setup为例：syscall(__NR_io_setup, hr, ctxp)，这也是一种发起系统调用的常见方式。  
但是呢，libaio库里面提供了对应的wrapper函数，但是其参数类型与这里有点差异，而且返回值的含义也存在一些差异，不是很建议使用。

### 5.2. AIO操作示例

#### 5.2.1. Kernel AIO SysCall

下面是一个基于内核AIO系统调用的一个示例，程序打开一个本地文件，并将一段缓冲区中的数据写入到文件中。

```c
#define _GNU_SOURCE         /* syscall() is not POSIX */

#include <stdio.h>          /* for perror() */
#include <unistd.h>         /* for syscall() */
#include <sys/syscall.h>    /* for __NR_* definitions */
#include <linux/aio_abi.h>  /* for AIO types and constants */
#include <fcntl.h>          /* O_RDWR */
#include <string.h>         /* memset() */
#include <inttypes.h>       /* uint64_t */

inline int io_setup(unsigned nr, aio_context_t * ctxp)
{
    return syscall(__NR_io_setup, nr, ctxp);
}

inline int io_destroy(aio_context_t ctx)
{
    return syscall(__NR_io_destroy, ctx);
}

inline int io_submit(aio_context_t ctx, long nr, struct iocb **iocbpp)
{
    return syscall(__NR_io_submit, ctx, nr, iocbpp);
}

inline int io_getevents(aio_context_t ctx, 
                        long min_nr, long max_nr, 
                        struct io_event *events, 
                        struct timespec *timeout)
{
    return syscall(__NR_io_getevents, ctx, min_nr, max_nr, events, timeout);
}

int main()
{
    int fd = open("./testfile", O_RDWR|O_CREAT, S_IRUSR|S_IWUSR);
    if (fd < 0) {
        perror("open error");
        return -1;
    }

    // init aio context
    aio_context_t ctx = 0;

    int ret = io_setup(128, &ctx);
    if (ret < 0) {
        perror("io_setup error");
        return -1;
    }

    // setup I/O control block
    struct iocb cb;
    memset(&cb, 0, sizeof(cb));
    cb.aio_fildes = fd;
    cb.aio_lio_opcode = IOCB_CMD_PWRITE;

    // command-specific options
    char data[4096] = "i love you, dad!\n";
    cb.aio_buf = (uint64_t) data;
    cb.aio_offset = 0;
    cb.aio_nbytes = strlen(data);

    struct iocb *cbs[1];
    cbs[0] = &cb;

    ret = io_submit(ctx, 1, cbs);
    if (ret != 1) {
        if (ret < 0)
            perror("io_submit error");
        else
            fprintf(stderr, "could not sumbit IOs");

        return -1;
    }

    // get the reply 
    struct io_event events[1];
    ret = io_getevents(ctx, 1, 1, events, NULL);
    printf("%d io ops completed\n", ret);

    ret = io_destroy(ctx);
    if (ret < 0) {
        perror("io_destroy error");
        return -1;
    }

    return 0;
}
```

**代码示例**：   
**点击这里查看基于aio的fileio示例1，[[click to see aio-based-fileio]](https://github.com/hitzhangjie/Linux-IO-Model/tree/master/aio-file/aio-file.c)**。

#### 5.2.2. POSIX AIO API

POSIX AIO API实现基于上述5个AIO系统调用，下面看一下基于POSIX AIO API的示例。程序读取命令行参数中指定的文件，并读取文件中的内容，程序还会在异步IO过程中检查IO操作的错误信息、状态信息。

在5.1.1节中列出了POSIX AIO API对应的函数，其中有一个非常重要的参数类型“AIO请求控制块”类型，即struct aiocb，下面是该结构体的定义：

```c
// 异步io请求控制块
struct aiocb {
    int aio_fildes;                         // io操作对应的文件描述符
    off_t aio_offset;                       // 文件读写操作位置的偏移量
    volatile void *aio_buf;                 // 异步io操作对应的数据缓冲区
    size_t aio_nbytes;                      // aio_buf的容量
    int aio_reqprio;                        // aio操作的优先级（一般继承自发起aio操作的线程）
    struct sigevent aio_sigevent;           // aio操作完成时如何通知应用程序
    int aio_lio_opcode;                     // aio操作命令
};
```

其中aio_sigevent定义如下：
```c
// Data passed with notification
union sigval {          
    int sival_int;                          // Integer value
    void *sival_ptr;                        // Pointer value
};

struct sigevent {
    int sigev_notify;                       // Notification method
                                            // - SIGEV_NONE，不作处理
                                            // - SIGEV_SIGNAL，发送信号
                                            // - SIGEV_THREAD，实例化一个线程

    int sigev_signo;                        // Notification signal
    union sigval sigev_value;               // Data passed with notification

    // Function used for thread notification (SIGEV_THREAD)
    void (*sigev_notify_function) (union sigval);

    // Attributes for notification thread (SIGEV_THREAD)
    void *sigev_notify_attributes;

    // ID of thread to signal (SIGEV_THREAD_ID)
    pid_t sigev_notify_thread_id;
};
```

下面是示例程序的源代码：

```c
#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <errno.h>
#include <aio.h>
#include <signal.h>

// Size of buffers for read operations
#define BUF_SIZE 20     

#define errExit(msg) do { perror(msg); exit(EXIT_FAILURE); } while (0)
#define errMsg(msg)  do { perror(msg); } while (0)

/* Application-defined structure for tracking I/O requests */
struct ioRequest {
    int           reqNum;
    int           status;
    struct aiocb *aiocbp;
};

// On delivery of SIGQUIT, we attempt to cancel all outstanding I/O requests
static volatile sig_atomic_t gotSIGQUIT = 0;

// Handler for SIGQUIT 
static void quitHandler(int sig) { gotSIGQUIT = 1; }

// Signal used to notify I/O completion
#define IO_SIGNAL SIGUSR1   

// Handler for I/O completion signal
static void aioSigHandler(int sig, siginfo_t *si, void *ucontext)
{
    if (si->si_code == SI_ASYNCIO) {
        write(STDOUT_FILENO, "I/O completion signal received\n", 31);
       
        // The corresponding ioRequest structure would be available as: 
        //     struct ioRequest *ioReq = si->si_value.sival_ptr;
        //
        // and the file descriptor would then be available via:
        //     int fd = ioReq->aiocbp->aio_fildes;
    }
}

int main(int argc, char *argv[])
{
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <pathname> <pathname>...\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    int numReqs = argc - 1; // Total number of queued I/O requests, i.e, num of files listed on cmdline

    /* Allocate our arrays */
    struct ioRequest *ioList = calloc(numReqs, sizeof(struct ioRequest));
    if (ioList == NULL) errExit("calloc");

    struct aiocb *aiocbList = calloc(numReqs, sizeof(struct aiocb));
    if (aiocbList == NULL) errExit("calloc");

    // Establish handlers for SIGQUIT and the I/O completion signal
    // - SIGQUIT
    struct sigaction sa;
    sa.sa_flags = SA_RESTART;
    sigemptyset(&sa.sa_mask);
    sa.sa_handler = quitHandler;
    if (sigaction(SIGQUIT, &sa, NULL) == -1) errExit("sigaction");
    // - IO_SIGNAL, actually it's SIGUSR1
    sa.sa_flags = SA_RESTART | SA_SIGINFO;
    sa.sa_sigaction = aioSigHandler;
    if (sigaction(IO_SIGNAL, &sa, NULL) == -1) errExit("sigaction");

    // Open each file specified on the command line, and queue a read request
    // on the resulting file descriptor 
    int j;
    for (j = 0; j < numReqs; j++) {
        ioList[j].reqNum = j;
        ioList[j].status = EINPROGRESS;
        ioList[j].aiocbp = &aiocbList[j];
    
        ioList[j].aiocbp->aio_fildes = open(argv[j + 1], O_RDONLY);
        if (ioList[j].aiocbp->aio_fildes == -1) errExit("open");
        printf("opened %s on descriptor %d\n", argv[j + 1], ioList[j].aiocbp->aio_fildes);
    
        ioList[j].aiocbp->aio_buf = malloc(BUF_SIZE);
        if (ioList[j].aiocbp->aio_buf == NULL) errExit("malloc");
    
        ioList[j].aiocbp->aio_nbytes = BUF_SIZE;
        ioList[j].aiocbp->aio_reqprio = 0;
        ioList[j].aiocbp->aio_offset = 0;
        ioList[j].aiocbp->aio_sigevent.sigev_notify = SIGEV_SIGNAL;
        ioList[j].aiocbp->aio_sigevent.sigev_signo = IO_SIGNAL;
        ioList[j].aiocbp->aio_sigevent.sigev_value.sival_ptr = &ioList[j];
    
        int s = aio_read(ioList[j].aiocbp);
        if (s == -1) errExit("aio_read");
    }

    // Number of requests still in progress
    int openReqs = numReqs;

    // Loop, monitoring status of I/O requests
    while (openReqs > 0) {
        sleep(3);       /* Delay between each monitoring step */

        if (gotSIGQUIT) {
            // On receipt of SIGQUIT, attempt to cancel each of the
            // outstanding I/O requests, and display status returned from the
            // cancellation requests
            printf("got SIGQUIT; canceling I/O requests: \n");

            for (j = 0; j < numReqs; j++) {
                if (ioList[j].status == EINPROGRESS) {
                    printf("Request %d on descriptor %d:", j, ioList[j].aiocbp->aio_fildes);
                    int s = aio_cancel(ioList[j].aiocbp->aio_fildes, ioList[j].aiocbp);
                    if (s == AIO_CANCELED)
                        printf("I/O canceled\n");
                    else if (s == AIO_NOTCANCELED)
                        printf("I/O not canceled\n");
                    else if (s == AIO_ALLDONE)
                        printf("I/O all done\n");
                    else
                        errMsg("aio_cancel");
                }
            }
            gotSIGQUIT = 0;
        }

        // Check the status of each I/O request that is still in progress
        printf("aio_error():\n");
        for (j = 0; j < numReqs; j++) {
            if (ioList[j].status == EINPROGRESS) {
                printf("for request %d (descriptor %d): ", j, ioList[j].aiocbp->aio_fildes);
                ioList[j].status = aio_error(ioList[j].aiocbp);
     
                switch (ioList[j].status) {
                    case 0:
                        printf("I/O succeeded\n");
                        break;
                    case EINPROGRESS:
                        printf("In progress\n");
                        break;
                    case ECANCELED:
                        printf("Canceled\n");
                        break;
                    default:
                        errMsg("aio_error");
                        break;
                }
     
                if (ioList[j].status != EINPROGRESS) openReqs--;
            }
        }
    }

    printf("All I/O requests completed\n");

    // Check status return of all I/O requests
    printf("aio_return():\n");
    for (j = 0; j < numReqs; j++) {
        ssize_t s = aio_return(ioList[j].aiocbp);
        printf("for request %d (descriptor %d): %zd\n", j, ioList[j].aiocbp->aio_fildes, s);
    }

    exit(EXIT_SUCCESS);
}
```

**代码示例**：   
**点击这里查看基于aio的fileio示例2，[[click to see aio-based-fileio2]](https://github.com/hitzhangjie/Linux-IO-Model/tree/master/aio-file/aio-file2.c)**。

下面是程序的执行效果：
```
// run:
./a.out f1 f2

// result:
I/O completion signal received
I/O completion signal received
opened f1 on descriptor 3
opened f2 on descriptor 4
aio_error():
    for request 0 (descriptor 3): I/O succeeded
    for request 1 (descriptor 4): I/O succeeded
All I/O requests completed
aio_return():
    for request 0 (descriptor 3): 20
    for request 1 (descriptor 4): 20
```

### 5.3 AIO在服务端开发中的应用

Linux下的AIO，Kernel AIO是真正的异步IO，但是glibc中的AIO是在用户态中实现的，利用多开的线程来模拟异步通知，但是这个线程里面的io操作并不是真正的异步。AIO更多的被应用于file io，而不是socket io，stack overflow上曾有人提到，AIO应用到socket上并不会返回明显的错误，只是socket上的io操作仍然是按照默认的“阻塞同步”工作方式执行，并不是异步, 这一点在github上的一篇文章中也被重点提到。

>[**摘自github linux-aio**](https://github.com/littledan/linux-aio)  
Blocking during io_submit on ext4, on buffered operations, network access, pipes, etc. Some operations are not well-represented by the AIO interface. **With completely unsupported operations like buffered reads, operations on a socket or pipes** ...  


Asynchronous IO模型（AIO）比事件驱动的IO模型要晚，而且事件驱动的IO模型已经非常成熟、稳定，因此如果要基于socket开发高性能server，应该首先事件驱动的IO模型，如Linux下的epoll，Mac OS X下的kqueue，Solaris下的/dev/poll。

那么既然事件驱动的IO模型已经这么成熟了，那么为什么还要设计AIO呢？设计它的目的是什么呢？这里我在stack overflow上找到了两个最具有信服力的回答，整理在此以供大家参考。

[**摘自stack overflow, 点击查看原文：**](https://stackoverflow.com/questions/87892/what-is-the-status-of-posix-asynchronous-i-o-aio/88607#88607)

原文出处：[answer-1](https://stackoverflow.com/a/88607)，译文：
>网络IO并不是AIO优先考虑的对象，现在几乎所有人编写网络服务器都是基于POSIX事件驱动模型，事件驱动模型已经非常成熟、稳定了。磁盘写一般会被缓冲、磁盘读一般会预取，还有什么不够完美的呢？要说有，那就只有Disk Direct IO这种不带缓冲形式的操作了，这是AIO最适用的地方，而Disk Direct IO仅仅被用于事务数据库或是那些趋向于自己编写线程或者进程来管理disk io的情景。所以，POSIX AIO其实没有什么多大的用途，不要用！

原文出处：[answer-2](https://stackoverflow.com/a/5307557)，译文：
>现在借助于kqueue、epoll、/dev/poll等已经可以实现非常高效的socket io操作。异步的文件IO草走是一个出现比较晚的东西（Windows的overlapped io和Solaris早期的POSIX AIO除外）。如果想实现高效的socket io操作，最好是基于上述的事件驱动机制来实现。  
AIO的主要目的是为了解决异步的磁盘IO问题，以Mac OS X为例，它提供的AIO就只能作用在普通文件上而不能作用在socket上，因为已经有kqueue可以很好地完成这个工作，没必要重复造轮子。  
磁盘写操作通常都会被kernel进行缓冲（将写的数据存在缓冲块中），然后在后面适当的事件将缓冲的写操作全部flush到磁盘（通常由一个额外的进程来完成，linux 0.11中是由pid=2的update进程来负责同步缓冲块数据到磁盘）。后面适当的时刻可以由内核进行选择以获得最优的效率、最少的代价，例如当磁盘的读写头经过某一个磁盘写请求对应的磁盘块时，内核可能就会将这个块对应的缓冲块的数据同步回磁盘。  
但是，对于读操作，如果我们向让内核对多个磁盘读请求根据请求优先级进行排序，AIO是唯一可供选择的方式。下面是为什么让内核来作这个工作比在用户态程序中做这个工作更有优势的原因：  
- 内核可以看到所有的磁盘io请求（不止是当前某个程序的磁盘io请求）并且能够排序；
- 内核知道磁盘读写头的位置，并能根据当前读写头的位置挑选距离当前位置最近的磁盘io请求进行处理，尽量少的移动读写头；
- 内核能够利用native command queuing技术来进一步优化磁盘的读操作；
- 可以借助于lio_listio通过一个系统调用发起多个磁盘read操作，比readv方便，特别是如果我们的磁盘read操作不是逻辑上连续的时候还可以节省一点系统的负载；
- 借助于AIO程序实现可能更见简单些，因为不需要创建额外的一个线程阻塞在read、write系统调用上，完成后还要再通知其他发起io的线程io操作完成；
另外，POSIX AIO设计的接口有点尴尬，举几个例子：
- 唯一高效的、支持的比较好的事件回调机制就是通过信号，但是这在库里面应用起来不方便，因为这意味着要使用进程的全局信号名字空间。如果操作系统不支持实时信号，还意味着不得不便利所有的请求来判断到底哪一个请求完成了（Mac OS X是这样的，Linux下不是）。此外，在多线程环境中捕获信号也是一项比较有挑战性的工作，还不能直接在信号处理汉书里面对事件作出响应，不得不重新raise一个信号并将它写到管道里面或者使用signalfd（on Linux）然后再由其他线程或进程进行处理，如果在信号处理函数里面响应信号可能耗时较长导致后续信号丢失；
- lio_suspend跟select存在相同的问题，都具有最大数量限制，伸缩性差！
- lio_listio，因为实现的原因也存在提交io操作数量的限制，为了兼容性试图获取这个限制的操作是没有什么意义的，只能通过调用sysconf(_SC_AIO_LISTIO_MAX)来获取，这个系统调用可能会失败，这种情况下可以使用AIO_LISTIO_MAX宏来代替。  
对于Posix AIO的真实应用情况，可以看一下lighttpd，这里面有采用基于AIO来实现server的部分实现，可以参考以下。  
现在大多数POSIX平台都支持POSIX AIO了，例如Linux、BSD、Solaris、AIX等。Windwos通过它的overlapped file io来支持aio。我的理解是只有Solaris、Windows、Linux是真正的支持异步，异步文件io会落到磁盘驱动上，其他的操作系统都是在通过某种机制来模拟异步io，如借助额外的内核线程，这里Linux是个例外，它的glibc中的POSIX AIO实现是借助的一个用户态线程来辅助模拟aio的行为，但是Linux Kernel提供的AIO是真正的异步实现，所有的操作直接落到驱动，只要驱动支持异步那就是真正的异步！  
我相信在不同的操作系统里面，POSIX AIO实现往往只支持普通文件fd类型而不支持socket fd，这种情况是很常见的，也是很正常的！

### 5.4 关于AIO的结论

如果是想基于socket io实现高性能server，还是采用基于事件驱动IO模型吧！别再想信号驱动的IO和AIO了！

感兴趣的读者可以进一步了解AIO的相关使用和实现细节。

## 6 本文总结

以上对阻塞IO、非阻塞IO、IO多路复用、实时信号驱动IO、异步IO这5种模型的执行流程、使用方式做了最基本的介绍。如果时间充足，后面会参考Linux内核中的相应实现进一步介绍以上IO模型的实现细节。

## 附录A. 错误码定义

这里只列出了常见的错误码，Linux中定义的错误码可以通过**man errno**进行查看。

|错误码Macro|错误码说明|
|:--------|:--------|
|EAGAIN   | Resource temporarily unavailable|

## 附录B. 插图信息

[Blocking-IO-Model]:data:image/png;base64,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v7/nWZlMjYAQgMBUAgiNqaTaDUfn0a7vZluuCv3HP/1lt//VbybHffzDt7tPf/lzhMZkYgSEAATmEEBozKHVZliERpt+i7IaoRGFjUgQgEBGAgiNjHArSRqhUYkj1jADobEGZfKAAATmEEBozKHVZliERpt+i7IaoRGFjUgQgEBGAgiNjHArSRqhUYkj1jADobEGZfKAAATmEEBozKHVZliERpt+i7IaoRGFjUgQgEBGAgiNjHArSRqhUYkj1jADobEGZfKAAATmEEBozKHVZliERpt+i7IaoRGFjUgQgEBGAgiNjHArSRqhUYkj1jADobEGZfKAAATmEEBozKHVZliERpt+i7IaoRGFjUgQgEBGAgiNjHArSRqhUYkj1jADobEGZfKAAATmEEBozKHVZliERpt+i7IaoRGFjUgQgEBGAgiNjHArSRqhUYkj1jADobEGZfKAAATmEEBozKHVZliERpt+i7IaoRGFjUgQgEBGAgiNjHArSRqhUYkj1jADobEGZfKAAATmEEBozKHVZliERpt+i7IaoRGFjUgQgEBGAgiNjHArSRqhUYkj1jADobEGZfKAAATmEEBozKHVZliERpt+i7IaoRGFjUgQgEBGAgiNjHArSRqhUYkj1jADobEGZfKAAATmEEBozKHVZliERpt+i7IaoRGFjUgQgEBGAgiNjHArSRqhUYkj1jADobEGZfKAAATmEEBozKHVZliERpt+i7IaoRGFjUgQgEBGAgiNjHArSRqhUcARz8/P78/Pz7Nzvrm52d3c3ET7DKExGzkRIACBzAQQGpkBV5B8dKdVge3NmqCK9e//8Z+7z/7pnyeX4af//q/dv/3rv+zu7++jfYbQmIybgBCAwEoEEBorgS6YTXSnVdDm5rNWxfrzX/+2+/Vvfze5LL//5uvdLz75GUJjMjECQgACLRBAaLTgpWU2IjSW8YuKjdCIwkYkCEBggwQQGht0aqdICI0CPkZoFIBOlhCAQJUEEBpVuiWpUQiNpDinJYbQmMaJUBCAwPYJIDS272OERgEfIzQKQCdLCECgSgIIjSrdktQohEZSnNMSQ2hM40QoCEBg+wQQGtv3MUKjgI8RGutAf319fb+7u9s9PT25DK+vr3ePj4/6N+q5f3l5eb+8vNxdXV1FxU9d6pubG53HciG7VK6Hh4dZdln81HaNpbdWvk9PT++3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RkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpiiSKlUAAAAgNJREFUhCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+XFwCKvpihCQAAQhEEqD9iQTXUDSERkPOymUqFT0XWdKFAATGCND+jBFq/3uERvs+pAQQgAAEmiWA0GjWdZMNR2hMRkVACEAAAhBITQChkZpofen9D1k9S6xytMXjAAAAAElFTkSuQmCC
[NonBlocking-IO-Model]:data:image/png;base64,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
[IO-Multiplexing]:data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAh0AAAFUCAYAAACA347eAAAgAElEQVR4Xu2dPYiszXWt+yTmYsPV3FRKRuDYNHyREIYBY6NEYuTc0IkctxIHjiZyoEQTS8mAc2uQEmFjOGCEoo87OPUFzQ3k1CPDNcbJXJ5yrf6q33n/u96/6jUwnDPd9bNr7fpZtWvXrk87/8yGwNvb2/vj4+OO35ubm93d3d3u9vZ2tvq3WtHr6+vu8+fPu7e3t93xeAy/Nzc3n7baHsttBIyAEbhWBDxxz6T55+fn98PhEIjGw8PDbr/fG/uB2H/+/Pkd7F5eXnZPT0+7+/t7YzgQQyc3AkbACCyJgCftGdB/enp6Z3fuhTIP2CJwWIwOh4P7cB5YXcoVIgCRh8RjRfRPMwJYpvf7PZtGzzcXdhQDeCGAXdm1QHI8YOtGF1r9v395eXnHamQi1x8zpzQCIOBj3uH9wEe8wzFrymHSkQ/LDyUxuPHZ8MI4DcgidEwI9vGYBmOXWhYCPua9TJ8+4r0MP3KbdFyOYWMJDw8PwXT5/PxsnCfC+f7+/h2z58PDgzGeCGMXWwYCPubNp0cf8Y7H0hP1eOw6c97c3Lw/Pz/7HLATqfEJdMzy9vbmvjweRucsHAEf8+ZXsI94x2HqiXocbp25MMNxW+X19dUYd6J1WYLb29t3jrDs5HUZjs5dJgI+5p1Orz7iHY6tF8ThmPXK8fj4GI5Wnp6ejHEvxMYnOhwO4YjleDwa6/EwOmehCPiYd1rF+oh3GL6epIfh1Ts1A53EOX0N6NxcE729vb1Ib5gFsQw8Pj5+4pwXOcdePYXpK17G3d3d++fPny+SrTfAScIpsB4jh/MYgTUi4GPeabXiI95h+M6+QAwTb7upcy+ELO4ExuKaKGThEmTkgQ1BeH19DaTjAiJD/iAP5S5xxJEb60uwdV4jsCYEfMw7jzZ8xNsf54sWr/7VXF/K3AuhrBz39/dE5DzpjUmFwD7EAeE4J0Y8Dd8jgyKgEtxGkVBT0sH/SQtZ4OxXET+56hvDtZ99TloCnWHdwEqC3wp5sOhQnyw7kBk+5zorMih0uepDXn7Tesb2ktxYj5XD+YzA2hBY6pg3taYKEz5jHmBemTpm0aUW3KF69BFvf8RMOvpjNShlzoWQBVxk43g8Bv8FHYdQD4OYwazFnbRx8Q+kg+9Y/EUCICf8H0tHKifHI5AAiATHLzEgzqf0cz6jPMqANKSkY7fbBauHHNckE/JFYhTqo2y+i34Y4d9LfF9yYj1IyU5sBFaOwFJjI93YAJGOIOaKIjx3u+eub+XdrlU8k46JtJezE1JWJAPhOISFXr4TVScxvodoxFszwZlVuwrYuB6Zq5IOvQuT3raJlgxZNEJfgVDEIx7dFjkdr4h0kA9CkhIJzI/xs0Bm9F11chqjjpxYj6nfeYzAWhFYamyk47qJcJBGGxLmH22kmD8UATTOU1hWw0ZJjz7Kj6zJojp3u+eub639rY9cJh19UBqRJmcnZMHmeIRffli8GZT4YTTUIyKQEoJw3BKPUj5YOnQMU+cIij8JkwMERj9J/JEPpKNOJqwlmkAoQ8cwJh0jOpezGIGeCOSch3pWqTkqjHfmDW1SUmf1lIiwoYpHticLLSQEooEVlO/5vyysstzqPRRtmFLr7Nztnru+IbpYW1qTjok0kqsTasFnAKcLPv/HoZR6YP9yLtXRRgyWFb5TiHCOZhjAMYLn2fEKg5rBm/qLUDfp9cYJ/1KWCER0Gv1AOjhHhhSlDq8QJ4gKvyYdE3U6F2sEKgjkmoeGAisH1jj/BMKQXmmX1VVEpGqhTectLKjaZMVN08lfrM2ims4zQ+Ufmn4pnIfKuYb0Jh0TaSFXJ8SBNLL+k65SYiGfDjllRodNLfghL0cZmgRkJanz6YAYaHIgPUQEkhDJSCAcEArSUI5IRzJBBALCBAKxkTWEPOx4OLqp4mJLx0Qd0MUagehMPufiK9DjTTa9OxWsFemjl/F6fZ2OmOfOLLTVv1OraboZS+oOdc3Z7lzz/TV0WpOOibScw2tci3ddiG/ICKSAHQDHHvzyfwiCbp0wWOUtrlsinIWmC306WORdnt4qIT0WEsrkhzohGTqDRQ7IRdyJkCT0KawkMoPKvIpvyRSkw57jE3ViF7t5BHLMQ2NAqG4m+FubFTYvdZsp5rt4db8X6dCcl1pUVcbcJMBzUP9eYtLRH6tBKee6H98xuKqDd1AbtpLYd+S3oinLOTcCc81D1XbVWTDZvLBhwfKKsygbGTYs8k2L1+h7Wzp0VCyLqqyz8Wh3VkuH56D+Pdukoz9Wg1MSCTA1KQ4uoEeGaycdmmj84FuPzuIkV4nAHPNQH9JBmv1+Hywe+HLoaBgiklpD+x6vcLybWlRTa+6clg7PQcOGlUnHMLwGpa5eZx2UuWfiNLhXNQv15wzD3lOkWZP53YNZ4XZlG0Rgjnlog7BkE9lz0DAoTTqG4TUotV93HATX4MR+4XEwZM5whQh4HppO6Z6DhmNr0jEcs0E51CmnPmYZJFQBiXXPn7v5ChRUQLPcBCMwCQKeh/LD6jloHKYmHeNwG5QLpynOMb1ADoKtMbEm0LlCKueR2qUYgWUR8DyUD3/PQeOxNOkYj92gnOqkCsy1xGusgwReYWJ5xHNVzgRuhQqySKtHwPPQZSryHHQZfuQ26bgcw94lcLbK7jzG0Qge23hc+6cdAb3DoHcX9GKtcTMCRmA4Ap6HhmPmOWg4Zk05TDryYTmoJBgzO3YW0jX9KJIfhGgtP3pjwdahtWjEcpSCwNrmoTXOP+jac1C+Hm/SkQ/LIkqa8357EYC5EUbACGRDwPNPNihXW5BJx2pVs4xgHvTL4O5ajYARCK9Ph5ewS48vdM26Num4Zu3XtN2D3h3CCBiBpRDw/LMU8vPVa9IxH9abqMmDfhNqspBGoEgEPP8UqdazRpl0lK/jQS30oB8ElxMbASOQEQHPPxnBXGlRJh0rVcxSYnnQL4W86zUCRsDzT/l9wKSjfB0PaqEH/SC4nNgIGIGMCHj+yQjmSosy6VipYpYSy4N+KeRdrxEwAp5/yu8DJh3l63hQCz3oB8HlxEbACGREwPNPRjBXWpRJx0oVs5RYHvRLIe96jYAR8PxTfh8w6Shfx4Na6EE/CC4nNgJGICMCnn8ygrnSokw6VqqYpcTyoF8KeddrBIyA55/y+4BJR/k6HtRCD/pBcDmxETACGRHw/JMRzJUWZdKxUsUsJZYH/VLIu14jYAQ8/5TfB0w6ytfxoBZ60A+Cy4mNgBHIiIDnn4xgrrQok46VKmYpsTzol0Le9RoBI+D5p/w+YNJRvo4HtdCDfhBcTmwEjEBGBDz/ZARzpUWZdKxUMUuJ5UG/FPKu1wgYAc8/5fcBk47ydTyohR70g+ByYiNgBDIi4PknI5grLcqkY6WKWUosD/qlkHe9RsAIeP4pvw+YdJSv40Et9KAfBJcTGwEjkBEBzz8ZwVxpUSYdK1XMUmJ50C+FvOs1AkbA80/5fcCko3wd17bw8+fP758/f/7wnT67u7urzcfnd3d37jdX2m/cbCMwJQImHVOiu46yvXisQw+zS8Hg/tnPf7nbf/Gt3nW/fPnr3fe/953dw8OD+01v1JzQCBiBvgiYdPRFarvpvHhsV3cXSc7g/s1vf7c7/OCHvct5+umPd9/8xtdMOnoj5oRGwAgMQcCkYwha20xr0rFNvV0stUnHxRC6ACNgBDIjYNKRGdAVFmfSsUKlzCGSScccKLsOI2AEhiBg0jEErW2mNenYpt4ultqk42IIXYARMAKZETDpyAzoCosz6VihUuYQyaRjDpRdhxEwAkMQMOkYgtY205p0bFNvF0tt0nExhC7ACBiBzAiYdGQGdIXFmXSsUClziGTSMQfKrsMIGIEhCJh0DEFrm2lNOrapt4ulNum4GEIXYASMQGYETDoyA7rC4kw6VqiUOUQy6ZgDZddhBIzAEARMOoagtc20Jh3b1NvFUpt0XAyhCzACRiAzAiYdmQFdYXEmHStUyhwiXRvpeH19fT8ej7vn5+cA736/3z09PfHvqDHw8vLyfnNzs7u9vR2VP7eO7+7ueEvnE3LRrsfHx0FyKX9uubrKm6ve5+fn9/v7+0GYpLJfmr+KQ1VPXeWP1WsX/mv73qRjbRrJL8/oQZhflOsssenhtTY0cjy6dm2kg8Xt/v5+dzweQ59/enoKJOT19XV3c3MzeBxQ3sPDw5oev3vf7Xaf6E/IBQEZOKJC/oF5ciSfvN4LMAntuzR/HUhvb2/v9D1Ib5/y+6TJoYylyzDpWFoD09e/xCQzfas2VAOD7Bf/8I+7L779x72k/vJX/7T77p/+ycXvn1wb6djtdh8WN4gHBO7t7S2QD+2EsYrw2u7hcAiWAxZx0pCWx+5YAA6Hg/4O1g4+e3x8DOn4jrwoFJzJx3eR7IT/U77Kq1M8O18sFpQHOZJs6ee3t7ehrEiaspEO6gAPCBqLo+SlPrCgvWD08vISLEeSMRI4yRTSypLUhE+dXsCDeslPHWk72+QBU6xPEZNT/YfDIeiT8tALsvN/5EUH4AuGj4+PQVeSGRwoDz2k+VN91fUP9SvhRH49kggO5KdN6mNV+SiTNkg+9bkof5CH/Mg91lLXa7JZIJFJxwKgz1xlMaTjeDyGSTD9wYTOQB2zk23SA/WwqNQNdiYLJhLtplVGdTJLy2aQ/et//NfuL//qr3up/ic/+pvd13//90w6eqH1VSIsE/wlspAei7AIsdi8vr6G8YCO46T+6fb2NlhE6Ev8yy/fpaRDhISFQosBVpW40IT+wi/f00eVV+WJoEhaFibys7hIZh0L6fN0cX16ekLuLKRDFiD6MX38/v4+4IasyK7Fmv+LTMVjJohRaJtkpAwwZVwobR0+dRYW9CWcwYEFGOsNn1Mf8lC+Fmfkaao/XdRJgy6lg7RsSEa0Ep30RLmqS6Ql7Xp1/UNEiXkAPKmLz4Qnf9MGWaSq8oncqc8hc7RuitCGvkGZLy8vxczhIunx36LaNXC6Kjp5MYqV+ZyBmiz2YRc2wtTcqPQ2szoTNJNBleSwO2OieX5+/oC3Scc84wsdaPGIZu0w6cuCsN/vw4LD3ywkLPIsEjc3N2HXycRPXxJZSfsBiwaLgshDhcQEq4GsIXHxPllB6ibYanmQEBYifuLu93REFHfhWUgHZQkj2l4lY5EAhbaKPGjRk/VHxC1qNRChLnyqpKOuXlkPUnJYlYcxVld/ejRBOZCVSNSCmOibz9ARhDPOGcGK03X8Udc/0vpoe7Sihc0I6d/e3s6OVNrkAwvyi3zWtW+eETRPLbZ0zIPzkrUURToazthPZvUmsyoKaDJbp2ZeJjyZWe/u7s6wY+Jg0k4ns1SxTD5xd3WWz6Rj/u5PP4jOlmFhQZdYo7SrhWBocmeR0u4+Wi/CQpSSjugMWdeQExngy+q5fNME20RsRZziDjcs/NFM30k6Ut+haEGojv1gQRCxgTiThz5f/Ynj7LRTr2tbSjr64qN6mvwX6j4XhvGoqrrB+GD9IT3yV3/icVc4TpKFRc64bf4UTf0DciFyC2mlvzH++ZfNR1pm+v+mPtEgw+T+MHOPTpOOuRGfv76iSQcLSTS/hsmkyayamrOrZuvUzEtZLFKaoKqkgkWpyUMeUkPeKikx6Zi+0+uMvIo9u9po5g67epmz2elqweFzdsA6u48E9Yx0YOGKxwqn8aR8qc9CX9JRLU+7XR236Cy/Ul7r8Uof0iEfDRZLsKLN8WjgQ7uqbWlbFPvio55QV6/8K1JLkSwd6E1HqRWr5gdMmBNoX3q7J9EVnwdCSho5GbeRjqb+wSYDmRjz/EJkdEyCRayJdNTJB7HRkUtd+6YfQfPVYNIxH9ZL1VQU6YAMpD86R2Zn2mZW1e5O1gvSRqtFOEtNTZqYYvmuaungcybtJv8RkZ6KeTQ4GtqnY/ruLzO4jkDQR7zNcnbEAuGQfkVE5N/AgsD/2alCRuXgSX8RIYWgoFPSxQXitBvtSzrS8iBF0YconOFHx8dAkpCf79N6LrjlcJKToybaQx+XzwJHAzr2EPlJb8m0kY6++KS9IK1XmwJZDqIvTFi4wQBc+K7m1s6JdIisSKeycKVly3EzkpJQrqwSVbIT54xALOr6BySJPOgO3x4wpW9pjqiSjib51JdoW1P7ph8989Vg0jEf1kvVVBTp0PEKOyUmI53JAm6bWVU73KrZum6gt/h09DF1fkhj0jFP11efYJHmVw6d6Y5XTpScuUuq5LOw4MebA+E4hoUims0D0dDtlZTsjrF0qL+mt2HkMBmPfk47Z/p4JLJZHEl1VCLnx3iLJSyscuBMb1No591l/u+DT9oT0Jf8S3R7BSti0+dt9YvwR6LwSYQg+toEZ1Q5aqZ+PvITE+lT/lTOpv4R0wTrJnJjVaM++XWl8rbJp74EYTHpmGeucC3TIlAk6Ygm8JMnuq7DNZlVMYWSp2q2ZjKqmpfTXWBFNSYd0/bVLKWzaEWH0A+BveTX0eSXk0UAF2IEjEAjArZ0lN85iiUdqI6z5HjWezqzrzOrJlcYP5itIRl8n15/q/PpIF08u63FVObw6hU3WzqWH2SpY2m87ljMuFgeXUtgBPojYNLRH6utpixmcq079pAnuhaSOrOqTLZNZuvUnKtAUjrvTpWO+TQ6qtZiihkWOarhqU061jF0FMSr6quzDukshRG4DgRMOsrXczGkY2lVsVvGItIUEwRSJH+AVFZHJF1ac67fCBiBuRFIb1OldesyQN1VbaXL8QzE3O11fV8hYNKRsTfgG1IXmrjpyiZVNw2+NrFyDLorDIOeUdMuyghcLwK6CXhJGHbmn5/9/Je7/RffGgTky5e/3n3/e9+5OCLzoEqdOCsCJh0Z4eQ4B6ZejdXBsQ5EIWc49kvFNum4FEHnNwLXiwBXmtMrzPH6du/1ZMz8A9pPP/3x7pvf+JpJx4a7Xu9OsuE2WvQaBMYMegb8//2X/x2uF/rHCBiB60VAgeRSBLjaHB/M07+N68uY+ceko4z+ZtJRhh4Ht2KMeRPT5v/6n//DpGMw2s5gBMpCwKSjLH3O2RqTjjnRXlFdYx25cviTrAgGi2IEjMAIBHy8MgI0ZwkImHS4I5wh4Ctr7hBGwAi0IZDLkfQ3v/3d7vCDHw4C2z4dg+BaZWKTjlWqZTmhTDqWw941G4FrQcA+Hdei6Y/tNOm4Xt3Xttykwx3CCBiBqREw6Zga4fWWb9KxXt0sIplJxyKwu1IjcFUImHRclbrPGmvScb26t6XDujcCRmARBEw6FoF9FZWadKxCDesRwpaO9ejCkhiBUhEw6ShVs93tMunoxuiqUph0XJW63VgjsAgCWyUdvKHV9L6WgOR2D/8/HA6feALj5uZmd3t7+yn9vA10IlhXo1ovoSRk572w6iOldZ8/Pj6+ExwOuQnHQIh8YrnwQ7RaHkkFA/426VhCmyuu06RjxcqxaEagEAS2SjpYULteoubxT9TEIpu+fp5+3qFG8i++NtPWh4eHD4+Y1n1O3Jbn5+cdofF5+BSyAgHhaRD+Tzl67X3xhhUyhopphklHMap0Q4zAahHYKulA7oeHh08QCN7ZworBLp5/WVj3+33Y6Qt4FmACKvIdCzI/kBYWYy3EfIZlgEUaawh5+I56SEf51IUlgc9lMUiVSz7KJ12UI8hVl08PkJI+lZvysLJAEqKc/N1JOsCCNr6+vn6CfJC/SszAjfqenp4+mXSsdlguI5hJxzK4u1YjcE0IbJV07Ha7YIWAWHBsAEHgXxZaFngWXs2hLMQp6dBiDpnAAgKJ4HsWYx1HUEZKOu7v7wOB0fciLzWPhwaygiz7/T6kr8sXLTAnYkJ9yIXcahN/v729hTIoq3qcVLV0cLSCFQPZRD6qfRliQllvb28mHdc00Pu01aSjD0pOYwSMwCUIlEA6ImFIN+6BkKRzaHq8kn4eLRohL9YMFmssE9FCEMpJLQiJ5SSkxV+kgv87RAEy0pYPUpK+hE5ayA/1HQ6Hs7KRMZKps7qqpANiBBaymrT4vIR22dJxycgpMK9JR4FKdZOMwMoQKIF01Pg79CYdHGNAMuRsGY82zkhH9B/5oDkdvVRJh/xAuvKBPcRDRy/x2OfM/4SyB/h0BMIja0cd6YBYQUpMOlY2ENcgjknHGrRgGYxA2QhcM+nAKsBRQ/R9CNaJ1CKiIxx8L0j78vJyMg5Ey0SdseDkfNqWD+sFZCexqtDRQl5ZLHRzRsSo7Xilmubm5iYctVT9TqgX/5Dn52dbOsoe2sNbZ9IxHDPnMAJGYBgC10Q65CSquZUjDn5ZnCEc+ESQBsuDjld0VIJjJt8dj8fTsUmdo6aIg7TQlI86qYfFH+sDZUdfk08QCKwokAOsEhzj8G8b6Tgej+F4BvmomzZG59PQNj6DBFEWn9M+H68MGyvFpzbpqFcxA0fOWWkKdizVe+zsGNJ76UovT/TouBUGtO6wVx3D0ANlV+/rp3ECqgNe9bTFEsBkGj3cz8Y+eepazoSDLEwaqUc6dWOWZfJK28fOjM+67uo3xQBIYxlQR9wVfpinqvLKKU8y1ukLPJlUwbqpfrWlS37SadJmMmWRUPnSWZ38fEbeap8pfmKpNPBaSIcIhcZ8XJg/0Q+YI/hhDqD/0Nfx1WD+0PVTOXTqpgxzEI6oNf3l7Jqt+n81H31Wfh3MP7reKusEeknlijdiGn06dFWWWzuSKd7wCaQF+fmlTI0Lk45rG+0d7TXpqAdIi5AGpFIxcNMBp91CdAw7G1/7/T7sCkRIMJWKyFQXb/LHXcIHhzGd3UZyEXZMqQzVXU/aIpzFonf7h3KZoKo/LOIQAepIF0rMqLSFyVR103YmS3n1t93VbzovbnLCq5tkU3l1A0B11ukL3JkAIVJN9VMP7eiKNUA69Elb0SFERt7/2tFVTOZM8AHHuBBsfu69ZK7YMOnwitEDAciN/FWq12c33/F7tN9JBiBwyUQyoJrNJW1bpNLGyMoRzaen8dXkCU5eFqdo0gzp2R1Fs6aurX3wkFe+eKXt7Ny3jXSwM4kOZI1kpqocyFHaHhEr7dBERti9abffdVc/B+moBlBid4dMuv5XF9govfLY8D3n0Z2xBtIz6hQvsIkOdWfn9KURjksHsEnHpQhuN79Jx3Z1N4nkJh3Nlo6mRUo50sVZC7CutlWvo7Upj0UvOXsNAXWS9CczqnbS0SnsdK7aRDrSRbnOctAWBVEysaPXsY7iEMjRjZ0/stRcJQzVpXf1pyAdsj4ozkBVX5A5BTtqqr/uumGqX8UagFxGi07jHCr9IE9JFo4cE49JRw4Ut1mGScc29TaZ1CYdzaRDRx5pivT6GthF34Lg9MXiKyesqqmd7xUsiPJIi8c3iyGfi2iwkFfM8R9IBwuhLB7Ra7w2jDKLLscQDf4EH3w6aK/kh2jwN+eyqbVE/5fjGaSjg5ydgivVpRtyvFJHkoRztAR9UGY8/mk8Xulh0QryV/VZ12tIozNtvpfj4GSDd0MFm3RsSFmZRTXpyAzo1osz6Rhv6WABZvGN99EVofD0BoO82LXrF+mIJCM4amIR0f15LVTReqCx+oF0kK9yda2WdLAIpjJUWtr63gPlK1qijjAiWQpHKpCtGHSokXSkd/WntHTI76ZKaqgzXkFsjCnQRjpS+avXC9tIB7goJkPqu7P1ueIS+ddMOjg6Q2cxIqfXyEsUXZPXgGYGdOvFmXSMIx1a9Fno9MOumh8sCwoVXDkqCd9r16zFW/kiOdGC1Uo6VI4cG6tWgHTBbOijraRDURMVtlnWEr3VAOmQJaTPXf26WALIld7I6bAmfJC3z/FNaglpssj0kb9Jn+kRW1V+/tYNha3PE5fKv2bSQdvYQGAVVEhxxlVN6PFLYbjK/CYdV6n25kabdIwjHXU7XxZqFmPeG+D/msB0p52a0hsPmN/rjj84YkluidRaOmQ9iW8f8OfZ2BY5aNlpd75sqeOCSmAhJuPQTvl29Lmrj4DkY0ep2y/CCNLFZ0NIh0gMiwNXCussFsIajNuiJ/aRX7rVbRnaI2ImGeqO1BSvoHLb6OpmoUtJx9SA0T9S8h+JSCDWjOP4r9fPEYowaCNAKzmLSUcz6ajz6ZA1Qg6G1dypw6HuzrPosUjr1Ul23Dic1t15j5aS4FgarSSNpENp4zXcs7HdclVWIjfF6TjF52B3j6yQqLSdepQqJTRdd/XJr6upYKHbOhAakTJdCU7rSnxozuRVnA7FMKgLBZ3G0WgKFS2y1kd+OebqSA0dYcmQFaiONOnmTynXZsfOhSYdY5Hbfj6Tju3rMGsLTDqywllbGCZ4PStd8o637a5+CoyeAocUrMmE3Vd+yAcOoxCfumfHp+9R26vhUtLRECArGxA+XskG5YeCTDqmw3aTJZt0bFJtFtoIbAqBNZMOO5JO25VMOqbFd3Olm3RsTmUW2AhsDoE1k47NgbkxgU06NqawqcU16ZgaYZdvBIyAScf19gGTjuvVfW3LTTrcIYyAEZgaAZOOqRFeb/kmHevVzWSS6aXRugr0iFbdTY3qS6N9BMTJTmG6FRK8Tz6nMQJGoFwETDrK1W1Xy0w6uhAq8HsG/M9+/svd/otv9W7dy5e/3n3/e99pelb5rBy8/rnjriiM8Xqo+1pvtJ3QCJSNgElH2fpta50XgivU/ZgB//TTH++++Y2v1ZIOrBlYSPSoleJPCFqCJXEd0j9GwAgYARBgvvi3f//PQRsf8g3Z/BjpdSJg0rFOvUwqlUnHpPC6cCNgBEYi0Ha8qyLHHPOOFMfZJkBg9aSDO9OEGlZnrMMgfQ1zAoyKKzI36agC5OOV4rqMG2QEZkHAjuyzwLxoJaslHSxc8TXL8GqlH9zJ10+mJh2ppHYkzac3l2QESkfApKN0DVcehVpTc3nkCj8AnBHXFBp5TRiNlWVO0jFWRuczAkbg+hAw6Shf56u0dNS98liiKtqurra199IzTc2BMykAACAASURBVJOOEnuT22QEto+AScf2ddjVgtWRDj0ZzZXLu7u71cnXBeiQ7xlgv/j7v9t98e0/6p3ty1/98+67f/bnva6uNhVq0tEbbic0AkZgRgRMOmYEe6GqVreo4zga4zusTrbcOmKA/ev/+z+7v/yrv+hd9E9+9Le7r//BH5p09EbMCY2AEdgKAiYdW9HUeDlXt7Afj8f3m5ubixbV8XDMm9OkY168XZsRMALrRsCkY936ySHd6kjH3d3dO7dVSj9aQXkmHTm6sMswAkagFARMOkrRZHM7TDoW1LFJx4Lgu2ojYARWh4BJx+pUkl0gk47skPYv0KSjP1ZOaQSMQPkImHSUr2OTjgV1bNKxIPiu2ggYgdUhYNKxOpVkF8ikIzuk/Qs06eiPlVMaASNQPgImHeXr2KRjQR2bdCwIvqs2AkZgdQiYdKxOJdkFMunIDmn/Ak06+mPllEbACJSPgElH+To26VhQxyYdC4Lvqo2AEVgdAiYdq1NJdoFMOrJD2r9Ak47+WDmlETAC5SNg0lG+js9IB4G5Pn/+3NXqSYmKg4O1w58rDPrPfv7L3f6Lb3Xp+vT9y5e/3n3/e9+5ikixvUFxQiNgBLIiYNKRFc5VFlZLIJ6fn0NUUB5du729/cQjbMfjkSfmeWrepCOTKpeydLS9bivSyUu21Z9LX7fNBJuLMQJGoFAETDoKVWzSrFoCgbUBknF/f1/9/n2325l0ZOoXS5GONvE96DMp18UYASMwGAHPP4Mh21yGWgJxOBze9/v97ng8nr5nd3w4HHavr68mHZnUbNKRCUgXYwSMQBEImHQUocbWRtQSiJeXl3dM6ff39xyv7N7e3sJRC0/O11g/sqJkn452OHP4dNjSkbXLujAjYAQyIWDSkQnIFRfTaLXAjwOi8fr6Gnw5IgGZ1MoBTiYdJh0rHi8WzQgYgQkRMOmYENyVFN2LdDw8PHzieGWO5+ZNOkw6VjI2LIYRMAIzI2DSMTPgC1RXSzpeX1+DTwfWjaenp2Dt4LgFnw4IyJRymnSYdEzZv1y2ETAC60XApGO9usklWR9H0nBjRUTk7e3NpCMT+nYkzQSkizECRqAIBEw6ilBjayMar8wSpyMep6TXZH1lNmOfMOnICKaLMgJGYPMImHRsXoWdDaglHSj+5eWFGyt8H4jG4+NjcCz9/PmzLR2dsPZLYNLRDyenMgJG4DoQMOkoX8+1BIKbK/hvQDzw58C/Q9dm9/u9SUemfmHSkQlIF2MEjEARCJh0FKHG4ccryoEfh67MQjYgIzc3NyYdmfqFSUcmIF2METACRSBg0lGEGoeTDo5SuK2SWjUckTR/ZzDpyI+pSzQCRmC7CJh0bFd3fSVvfPCN4xUe/yIiKe+wcNRCRNKpY3X4ymy76hyRtG/XdjojYAS2hoBJx9Y0NlzexqOSp6en8OgbP/w7dXwOiW7SYdIxvBs7hxEwAiUgYNJRghbb29DqnyHigcVjagdSk45+nc2Wjn44OZURMALbQ8CkY3s6GyrxGenAygDB6PixI2kXQj2/t09HT6CczAgYgatAwKSjfDX3IhDcWgGKqW+uUIePV3y8Uv6wcwuNgBGoQ8Cko/x+0Ring3dXcCY9HA6fnp+fQ9wO3mHx0/b5OoUtHfmwdElGwAhsHwGTju3rsKsFjW+vkPHp6en0va/MdkE5/HuTjuGYOYcRMALlImDSUa5u1bI+b6+kKFzN2ysKjEbjicg6xdGSSUf5A8wtNAJGoD8CJh39sdpqylrScTweQyTS+PZKaNs1vL2C7wqxSDhGurm5Cb/8KCorV4c5bsqlbJOOXEi6HCNgBEpAwKSjBC22t6HVp4PFluBgvLtS+tsrXA/mQTt8WfitWjawfEBGuN0DMclxhdiko/wB5hYaASPQHwGTjv5YbTVl6669+vbKHI1c6vYKPit9oq1iDYmP4F1s8TDpmKNHuQ4jYAS2goBJx1Y0NV7OxoUT5bOz19ECu392+FP4NqTiL0U6xkM4PqdJx3jsnNMIGIHyEDDpKE+n1RbVkg6OGiAYHDfc3t6G12UVEj290TIFPCYd7ag6IukUvc5lGgEjsAYETDrWoIVpZWi8vQLJSGNyxGftkebiY4W2Jpl0mHRM2+VduhEwAmtFwKRjrZrJJ1ctgbi/v3+PwcFO3+PfwdXRt7e3IklHJFW92jYkbZuqfLySryO7JCNgBLaPgEnH9nXY1YLaRRanSvlw6PbKw8NDuNUx9WuzS1k6uCbMFVkir3KkVAccuHDsRJockVlNOrq6p783AkbgmhAw6Shf2407exbYqiNpzhgVTdAuRTqQhzZDrrgefHd3dxang6uyfMb3TaRkaHcx6RiKmNMbASNQMgImHSVr97/b1us4YU4YliQdaidHSZAMbu7ww7FSJCFZ8TLpmLNnuS4jYATWjoBJx9o1dLl8Z4soRwwvLy+tpX7+/DnrwlutbA2k43JY+5Vg0tEPJ6cyAkbgOhAw6Shfz2cE4uXl5Z2jhbafPgG0LoHNpKMdPV+ZvaR3Oa8RMAJrRsCkY83aySNbo9WCGxrE6UiDg+XyZeggNcGvYmpykwe+y0qxpeMy/JzbCBiBshAw6ShLn3WtqSUdWDzwYeC2im6vQEC4uZHj1sYWSQd+HrlJl0lH+QPMLTQCRqA/AiYd/bHaaspa0nE4HEJMjuPxePqemx1cFX19fS3ap6Ou008VGM2kY6vDxnIbASMwBQImHVOguq4ye0ckjWK/T33jZSmfjufn5xCbpOmH756fn7MSLpOOdQ0GS2MEjMCyCJh0LIv/HLXXLqIswPhVVN9eIXjW4+Nj1oW32sj9fh8CcC3l08G7M8g0R0wSk445urjrMAJGYCsImHRsRVPj5TwjEFgZiE/R8TMp6djtdpNbU7oaSMfHpwXiAwkhSBpEaL/fZ227SUeXJvy9ETAC14SASUf52s66iF4KFxYWHpqb2m+kTU46PRYeWXlIy2eQsdwxSkw6Lu0xzm8EjEBJCJh0lKTN+rasinTgwMptmanfd2lTa4tPSXYLjElH+QPMLTQCRqA/AiYd/bHaasrVkA5d0yUiau6rqUOUU0d8prq5Y9IxRDNOawSMQOkImHSUruGVvL3ClVTFBVnSyoG662KU4NPBb+4YJSYd5Q8wt9AIGIH+CJh09MdqqykbLR0Ew9KDZ2njprhVgnWBunL7TIxVylzRWE06xmrI+YyAESgRAZOOErV63qbGK7PEpcD6UP3JSQxY3GPAMQgHT8mv4rgnJR1YXjhemYJsmXSUP8DcQiNgBPojYNLRH6utpmwMDgbpSCOS5m6g/CSIfMrRxVoIBxYeZKL9yIUFBvIFOcp99GPSkbtXuTwjYAS2jIBJx5a110/2WtJxf38frq5OsbtnUVfgMf6dktj0g+A8VSUEfLixIiLy9vaW1RJj0jFGQ85jBIxAqQiYdJSq2a/a1fjgG4SAgFi5bpJg2ZBDZrQaZCs7p5oqV2bTa7K+MpsTaJdlBIyAEaggYNJRfpeoJR0oHtLR8NNrt49fRAyoFQJt8QPZ4DcXkZlCPbSda7vxnZVANB4fH0PAsJz+LMhuS8cUGnSZRsAIbBUBk46taq6/3L0IRP/ivkqpkOr4Q0BgpjiqGSNXVx45t0I88OfAv+Pt7S0QJ4dB70LP3xsBI2AExiNg0jEeu63kbCQdKF+OlDz0hmMlxy19HT5ZvEkf3yzZFPFAeboyTNtzkw11Dls6tjJMLKcRMAJzIGDSMQfKy9ZRSzp45AyyUH1lFlGfnp4GWUdS8jGUuMwJDW2ui0uSyuDbK3NqxHUZASNwbQiYdJSv8cYrs9xeSSNwQh7Y9ePjMAYWHVvg5zFFdM8xMqV5TDr+Gw0P+kt7kvMbASMwFgHPP2OR206+xiuzWCUOh8Pp+1zXRnlJVg6lj4+PowjMHPDqeAVflEi4ssvq45U5NOk6jIAR2AoCJh1b0dR4OWsXUq636iiEV19xpMQZlM9yHDHwvgnEIwYGy76Yj4djR1tD2zlq0a8CmPntlUuQdV4jYASMQDsCJh3l95DGBV9xNVh45UiaWj4uhUaPvK2NeNDpaXP0XQlXZv3K7KXadn4jYASMQDcCJh3dGG09xaJWhjW9LitFOjjYA0Qri0Vr64PD8hsBIzAvAiYd8+K9RG1npON4PIZjD2JU4OxZ95M7QJaekuemzBpieRAGnSOleIxkS8cSvdJ1GgEjcJUImHSUr/Yz0gEBkA9H0/XRKYgBET+5ovv6+rqo5QV140BKQDN+IV7c4lH4dvt0lD8g3EIjYASWQ8CkYzns56q5MU4HAlR9OG5vb/F3mIQYUDbEI/fCPgbI9Gl7+bNMEbrdt1fGaMd5jIARKBUBk45SNftVu84IBNdZo8UhpMDqoR9usPA7FekgTgZHLPHNk1UgD/ngqAln176RWIcIbtIxBC2nNQJGoHQETDpK13BNoC/dWomWjjMEplp8dawRSc4klpQuVeqqbHwr5pN8TZCJoybIWM7bO8hj0tGlFX9vBIzANSFg0lG+tgct8Pg7THHMIJg5YpniYbU+ary/vw/+LApYxt8crXB1VoHR4vXhQZi11W3S0UczTmMEjMC1IGDSUb6maxdQdvkKkJVCwCL89vaWbdGtwlu5rjo3+u8cH3GMopDv8WgltHcK2Uw65lax6zMCRmDNCJh0rFk7eWRrDIPOUQrXZzluwI+Dq6SQjilDl0+xsA+AKVyPJb1CtacEawrZTDoGaMdJjYARKB4Bk47iVVz/eFtdgCx2//E6bZGWjv1+H5xouRIMwcLqIadW+XfktvKYdJQ/wNxCI2AE+iNg0tEfq62mrCUQLLpYOo7H46eWCJ3Z2zyFNaGvkAp1DrHiWIXXcPf7/SdiiPDujB1J+yLpdEbACBiBcQiYdIzDbUu5Gn06FByLBRjnTgUNyx2RNAVrSdKBHHVXZLnKCwGDgORWrC0duRF1eUbACGwZAZOOLWuvn+yNCykLMEXgWMnCy3EDPh5TxKuQqEuTjn6Q5Utl0pEPS5dkBIzA9hEw6di+Drta0Eg6UH4MBx5IB6HAOWKYYsdv0vEXXXo6ff+TH/3t7ut/8IeTPcjmQd9bFU5oBIxAZgQ8/2QGdIXF1ZIOFB+jg3KsEtLwGX4OJR+vzK0fWzrmRtz1GQEjsGYETDrWrJ08stWSjpZjjtO10jzVn5fi45VuVG3p6MbIKYyAEdgmAiYd29TbEKkbb68kz7uH8nS7Y6q3V6jDpKNbdSYd3Rg5hREwAttEwKRjm3obInXr7RWikurWylTPu6fCmnR0q86koxsjpzACRmCbCJh0bFNvQ6Ruvb2CX0d8b4Qn50/+HUMqGJLWpKMbLZOOboycwggYgW0isGbScTwew6vj6Q/hFIjjlPNWJ/VwU3TKSxtL9o7ssScuaYxJRzd6Jh3dGDmFETAC20RgzaSD9YnNN0RDP9zoJJxEzgsWpa+DZ6RDjeWWCuyt4WcyolI62FU8fXtlmxOjpTYCRmAaBNZOOlgXeSqj0vrTBQteJCcNJwSEnDgejycrCG964aYASYkvmp8eGCUPVhTyaP2t1kPoCsrV95AfSA9/Rx/M02kEdfEdP8hwf38fXksnbXzi40wG0uG3KRKFpeVwOJxurkK2kJG8Ko88dfXweRsOkxGIMV3SpKMbNVs6ujFyCiNgBLaJwNZIB89ksFBzwYKAmulDqRCMSBI+saCzcPNZfDg1/Pv09BSeGoE0sNBTFm4NkIM6ckMaWVtY/EUqICwiOxAD5KAufsjD98hCXpGhOvmoH7koKxINOEKQnfooh38pi5+6esjfhAN5zkiHmFRbd314eJiMqJh0dE8UJh3dGDmFETAC20Rg7aQDMpD+sIAraCbrJ99DJJTm9vY2fBZ3/ycioYCbLPx6yT3NEz//YFGBUOA/giWhmo830/iMBR+SgFyycBBvS8QnfbhU8kULzsm6USk/WFgUs0vrNOSirp42HCjDpGPBsenjlQXBd9VGwAisDoG1kw4dr/DyOAsuVgk5fCJ7nVtCfDz0ZCnAWoBlQ0ci5El9QvrEyYJAQDCqP5SFYQBnVFk6RAxkDamrK+arWld0bHQWnyuVr64eyE4TDlhvWq0WsB3dXpnDk9aWju45wJaOboycwggYgW0isBXSAbr4M0TCEKwPHLWwXj4+Pp7WVdZQdvdYIcjD0QRrKaQheb2cY4tTnv1+H45s2nxHID3x2ORDXdGqEuqVjPE2jIjPWV2QE2SJRzfhO+TGYhKtIo2kQ+1L65FVpw4HvqslHZxNwY6iSSU4j/CDcFOSD5OO7onCpKMbI6cwAkZgmwhsiXSA8P39fVicsS5oocb6AWHQcQbrKAt69KUI6VhfOZ7A6gDJ4Pvj8RjeOeP/TT4d6ZrN0Qgkhnw6DpGfhhxMIUPIqGMXvR6PkygkifQQHuqVPwlyyV8kHhXVko5IsIKsaT3yOanDgXSNEUkjyTh9j4DRwcU+HZnGs49XMgHpYoyAESgCga2RDjboHJPEI5NgWZCjpW6o4Feh4xht5HU0gwMq35EnEo2wye+ydKDsNJ+IgnwuOfbQ7RVIDOQBEhRv05zqSh9xBfv09kp0Kg2OpCnZqR6vVOuRFagOh0ZLR58zpSl6uC0d3aja0tGNkVMYASOwTQTWTDq2iehXUutIJ2dMkTGY1FotsGrAup6fn0/fy9t2SoFNOrpVaNLRjZFTGAEjsE0ETDqm09uqSQcEQ2c60ZkkmI/4P2YcftLgIblgMunoRtKkoxsjpzACRmCbCJh0TKc3BQdT0K/pamovudbSoVsrbVnjlZ+s/h0mHd3dwKSjGyOnMAJGYJsImHRsU29DpPaDb0PQypzWjqSZAa0pTs5TeqgpiQrYSpix9kWL3ihijUMZDmSXthAi3nWkiUMZFkgF77m0zqH5qR8veK7I9cEtTV+tq0/+OvkokyNhPPmHyt8nfZvMyn9pu+ir8abDJG3o086l05h0LK2B6euv7dwMHq7WpE/bc3NFEc6mEsuWjm5kbenoxkgpFJZY0f34W28cdC3kGSa/M4/v/lJ/SNlZztLjBlxZLLlO3we3trPlPvnrsORaYAwxPcmC3ec8PEe7pm7HBf1wlqxj9Z8Kx/oVb3+cImzOIrwr6YVA7QDVvd5018CAwo+DKz69Sh6RaOnJc4TIF2WxpeMi+DozNy0CMXLgKQhO3QNN6eTHotr0sJImOD3wxJU13bVXdMBOQZMEaXnxYSW+DbLWPRiFBUcxAKhPAYHqHpaqylFXHu2IbzScXZenDn5E2vh/9SEpzoqruNWll170uFX6PHhf3NO2UB7tVfjpIQ9jpXjrzQnFIhI+1IWsChmQktcUh77tIo8c83XVUYGgJPuUz00M6Y9zpx1LOtCJNsaK+DnlWjU3LiXVV0sgWPzTl+SSBnfuui4Bx6SjGz1bOroxUgrdocdip4eOCE6Tft/0MFE6+UHCtbikDyvxmUIZU45Igh5vGko6JG8kD+kC3/hgVHToDouiyFPTw1LVhbound5g0ISdvsGQPkwFMdEDUPxfoZxT3NrSy5JKGenDU31wT3VIm4j2GHUs3YYNUtfDWFX9xXczwsYqfaBLL2uiYyxkl7ZLQZkUKhpZFUhJ1rlSF0xwrb5fUumX4c+6EN98JnKm4zTGI+XpATKVVX2Cvv+sMSzltZLDYSidp64lHWmIVlg/A0FBRdLQppdUXJfXpKMbUZOObozSFExOClXM4qEnmunXbQ8TpS80Nj2sRD3pA09ywI4T42CCXpUnhhimmhBxMFpTwphNr7Cn46YtXYpLWzoiJMZXJsMbDuSTv4Y835kT9NgV39eRjmjxCfJW01etpnp4qg/uVe978rL4JGTkvc/DWPQF9CffmxRvPZ6lulK8L2kXi5TaKh+cqt7BHxKylI/OsBE2LDWk8mc//+Vu/8W3BmV8+fLXu+9/7zsh8icZTToGwbeqxLWko+nhmlTyobu4Pq026ehGyaSjG6OmFDKlM6ErhG/Tw0TajcXd1Yci03wNu51a0pG+5Jzu3OLCHRb4SnmhHBF/Ftf0wSjtvPUQVVu6tBFt6diJUwfHFSyQetSK4waOmeSUS3l810Q6+qSXTBr7fXCvwbuK9envroexmOuok18sVHHHHKwZwjSSS5HXEHWyC4emdkXZg57Tn3jUFObjkudB8P7Nb3+3O/zgh4MG8tNPf7z75je+Vh0bpzJ8vDIIzkUTT+afMaZVJQ+2Ojzs0zGml/TPwwIfTeNn/VwPKrF4Nj3QJDM/u+Gmh5XqHnhKdsGDSUe1PCbSGBen8cGoKuloeliq6jjblk7HPBAKWST0roSe4saqoPFaRzr0wFRT+ng0c9ILOiGtSEwb7jU9oJF0tD2MpfcmKiGnQ1kcqaUPYIloxPenwpEQRKGKQ1e7IB03Nzd6SPNkBaJNstSUPA9ORTrSPmFH0v5z5BIpe5EOJqF4Jc6OpBm1ZNKREcyaonQLKz4tfXIc5WwesgEh4f91DxPpPQGZw+seVmJnnOZPds3UdTLx921l+mgTRzQQg3jccHq0SY87pQ9GpT5YqRN49WGpVI6udHyvh6qoU29H6BgDgqT3IupIh/xomtI3PTyV+nQ0PWhVfX2z5jjijIQ0lSN/ACIvy/IjvPVqJn0D4hcJhm7wBWuPXhZNcejTLhG+9M0KPRoGljXHRX270OrTzUE6Vg/ClQvYSjrkFa4dT9y99CIqY3AtmeHb0jGmR1yeR9F1mdT5YbFgstdZfdMDTeni1/awUppfPg74i7Bo6xhnyNl8Wh6LWVyYWh+MEgHQLjx9ITp9WKq6G2xLpxs48YGqMObTR6TIC2ljTpAzLdaUFLe29E0PT/XFPW0L9USH4JMjafpAVZP+9Jp2fCUztCW+uhn8KZBFxEBY0cZL21UhOKFePa4lopg+dX75KFhPCSYd69HFUpJ8IBCpVUNX2hTnYGohTTq6EbZPRzdGdSkg0HweQ/lPRpzHSedclyDAQh2fA9+8XlmU4+2nzbelaaM1hU/HJf3HeedF4Kxj0+HZnenqX3peWTVpTiGmSUc3qiYd3Rg5xfUhwJEF85ZibGwRgcTyUiThQCe2dGyxZ+aV+axz6xyT3aDuvc9JBOasKy+M40qzT8c43JzLCFQRYMFOr79uESGOgaI1zqSjosCu2ytb1Pe1ylzbueX9m3j3zxJO1qSjuxva0tGNkVMYASOwTgRs6VinXuaUqpVRp3efEYpz06keVKJ8k45u1W+FdPjaWrcuncIIXBsCJh3XpvGP7e1txtMiovcNpoDOpKMb1Rykoy0UcRqcqSpNNZhVnYnb7x9069ApjMC1ImDSca2a/6rdvUnHHFCZdHSjnIN0jAlFXA1DjKRrCUXcjZpTGAEjsAYE2NT827//58Vh0NfQFsswDgGTjnG4Zcm1lCPpmN1GnSOXSUeWbuBCjIARiAhcYmk1iNtAwKRjQT1tnXT4eGXBzuOqjUCBCIx92r5AKIptkknHgqotjXSkUNqRdMGO5aqNwEYRMOnYqOIGiG3SMQCs3ElLJh25sXJ5RsAIlI+ASUf5OjbpWFDHDLBf/P3f7b749h/1luLLX/3z7rt/9ueNTzz3KSiXT0efupzGCBgBI9AXAZOOvkhtN92qSAcPKfGiIy97bhfS/pK3XV1tK6Xr6mqXBCYdXQj5eyNgBJZAwKRjCdTnrXNVizsvW/LaYqkvLM6r2ubaTDrWognLYQSMQIqASUf5/WFVpIMIqLywSICpOR6YK1+99S006bhWzbvdRmDdCJh0rFs/OaRbFemgQXrplvvavHKbo5Eu4xwBkw73CCNgBNaIgEnHGrWSV6ZVLur7/f6dl245ajHxyKtwEbvf/PZ3u8MPfti7cL/y2BsqJzQCRmAkAiYdI4HbULZVkg6OWe7v73evr69YPnb83+QjX6+ypSMfli7JCBiBfAiYdOTDcq0lrZJ0CCwcS5+ennYKjVsHIjc5Pn/+vOp2rE35Jh1r04jlMQJGQFbY+K/n9EK7hBVbqGLbmmXScYVKd5ONwAYQsKVjA0q6UESTjgsB3GJ2k44tas0yG4HyETDpKF/HJh3l6/hDC006rlDpbrIR2AACJh0bUNKFIpp0XAjgFrObdGxRa5bZCJSPgElH+To26Shfx1dr6Xh9fX0/Ho8h2Bw/XMPGMXm/34/q97ycS5j+29vbUflzd7W7u7t3nKiRi3Y9Pj4Okkv5c8vVVd5c9T4/P3MLbhAmqeyX5q/iUNVTV/lj9dqF/5q/N+lYs3byyDZ6QOap3qUsgcC1WDpY3LhufTweQz/nNhQkhKvYY65gUx5XuFcULfd9t9t94g0f5BpxiyvkX6APTl7vBZgEOC7NX4cpoQDoe5DePuX3SbOA7iat0qRjUnhXUfgSE84qGn7NQlwL6djtdh8WN4gH16zf3t4C+dBOGKsIV7MPh0OwHLCIk4a0PEDIAnA4HPR3sHbwGQHsSMd35KVfgS/5+C6SnfB/yld5df2PnS8WC8qDHEm29HOeCUiC5mUjHdQBHhA0FkfJS31gQXvB6OXlJViOJGMkcJIppJUlqQmfOr2AB/WSnzrSdrbJEyMXf6j/cDgEfVIeekF2/o+86AB8IZ6Pj49BV5IZHLBm6aq+8qf6qusf6lfCifx6uBIcyE+b1Meq8lEmmEs+9blYf5CH/Mg91lK3hTnPpGMLWrpMRpOOy/DbZO5rIR1YJlCQyEJ6LMIixGLz+voaxgAvHMdJ/dPt7W2wiHAcw7/88l1KOkRIWCi0GGBViQtNICj8xgcMT3lVngiKOhALE/lZXCSzjoX0OYthJBykQ+4spEMWIBZEFrT7+/uAG7JCALRY83+RqXjMFAL30U7JSBlgyiKqtHX41FlY0JdwBgcWYKw3fE59yEP5WpyRp6n+dFEnDbqU/tKyIRnRShTaShr+VV11pKOuf4goQdrAU+UIT/6OL2iHNlXlE7lTirzsQwAAFc5JREFUn0Pm+Jq0CG3oG9RT8oOYJh2bXFIGCW3SMQiuMhJfC+lgh6zFI5q1FeE29HvC7ceIt4FosMizSNzc3IRdJxM/5EJkJT1eYdFgURB5qJCYYDWQNSQu3icrSLSGnI29anmQEBYifuLu93REFHfhWUgHZQkj2l4lY5EAhbaKPGjRk/VHxC2OjkCEuvCpko66emU9SMlhVR4W87r606MJyoGsRKIWxETffIaOIJzomb/VB9qONur6R5qetkcrWrAckf7t7e3sSKVNPrAgv8hnXfvKmIk+tsKko1TNftUuk47ydfyhhddCOtKGM5FHZ8vTK8aY1rWrjWH3Twu7dvfRehHISEo6ojNkXe85kQG+rC5eTZNqk7+IiFPc4YaFP5rpO0kHdSuab7QgVMd7sCCI2HDcQB4W+epP9GUJpE2+Iw0LcyAdffFJLT11fil1dQjDeFRV9WX5YP0hPWVXf+JxVzhOkoVFzrhtpAMSU9c/IBcit5BW+hukiH+fn58bSUdTn2jDt9Rpy6SjVM2adJSv2ZYWXgPp0Bl5ursFEna10cwddvUyZ7PT1YLD5+yAdXZPPhaNlBhwBBGPFU4LufKlPgt9SUe1PO12ddyis/xKea3HK31Ih3w0WCzBijbHo4EP7aq2pW1R7IuPumldvfKvSC1FsnSgN35riMoHTCCXtC+93ZPois8DISWNnIzbSEdT/8DCgUxYS/iFyOiYBItYWmb6/zr5IDY6cqk4CE/uhLvk5GjSsST689RtS8c8OK+qlmsgHQAuM7iOQPSQYOqkyRELhINFh1spIiLyb2BBiGb3QDqUl0WB3WxcXD6BKeniAnFaGPqSjrQ8SBELPwuY/Cgw0yNbfPzwrJ4Lbjmc5AQH2gMG8llQnVgURH76Wjr64pMOjLRe+bjIchB9YcLCDQbgogch6xZl0omsSKfoivalZctxM5KSUK6sElWyEy1CgVjU9Q9IEnnQHb496luUKSuS8GuTT32JtE2kalUTSkZhTDoygrnSokw6VqqYKcW6FtLB7lmLNAu5HAXTHa+cKDlzF+bJZ8GZL94cCDcdWFSi2TwQDd1ekdNkvFkwmHRQd1qenFDlGxB9RMLOmcUznvNncSSlbvlnaDGXn4ccONPbFH2OV6rtacIn7efoS/Xq9go3eJo+b7O0QDAhB5EofBIhEI6RYJ1uI+mmkK5Zi/QpfypnU/+IaYJvEOVhVaM+SIwwFolok09YQYZNOqacCV32EgiYdCyB+sJ1XgvpSE330SH0Q2Av+XVUj2EWVpGrNwJXiYAtHeWr3aSjfB1/aOG1kY46FaeOpfG6o8fCFY4FN3ldCJh0rEsfU0jjiXYKVFdepknHfytIQbxWFGF05T3H4hmBaREw6ZgW3zWUbtKxBi3MLINJx8yAuzojYAR6IWDS0QumTScy6di0+sYJb9IxDjfnMgJGYFoETDqmxXcNpZt0rEELM8tg0jEz4K7OCBiBXgiYdPSCadOJTDo2rb5xwpt0jMPNuYyAEZgWAZOOafFdQ+kmHWvQwswymHTMDLirMwIFIqA3bXK+fGvSUWBHqTTJpKN8HX9ooUnHFSrdTTYCEyBAFNk0amwMxjd6XTHpmEBJKytydOdYWTs2KU76NkbfBsTnri/S2yWko6+cTmcEjED5COjtnrSlRJNlniIibPy393xl0lF+n+ndGcqHYv4WMsB+8Q//uPvi23/cq/Ivf/VPu+/+6Z+Edx16ZWhIZNJxCXrOawSMgBAYSjq6Nlp6FbnupeMcGy5rbnkELlq8lhd/2xKw+P/rf/zX7i//6q97NeQnP/qb3dd///cWJR2XEp5eDXUiI2AENoHA0OMV5ryf/fyXu/0X3xrUvpcvf737/ve+c/HcN6hSJ54EAZOOSWDtV6hJRz+cnMoIGIH1ITDGkXSMlZWWP/30x7tvfuNrJh3r6waDJTLpGAxZvgwmHfmwdElGwAisHwGTjvXraGoJTTqmRrilfJOOBcF31UbACMyOgEnH7JCvrkKTjgVVYtKxIPgLVH13d/eeVouX/+FwwMO/cxy+vLy839zc7G5vbzvTLtC02apswwFz/9PT045rm8fj8apxmk0hAysy6RgIWIHJPTAXVKpJx4LgL1P1u7zzqZ74BgRWigtl61iEsDw8PPQiKMs0bZ5aO3B4f35+Dlc1r52czaON4bWYdAzHrLQcJh0LatSkY0Hwl6kaS8fZmGPnzs789fU1fP78/Bx2629vbyycu8fHxx3XEqNFBEe6sKDWpbu5uTkrm+uJlEN+yA5lsCBTBj/8u9/vQx7SUhfpSXc4HD4hG8To/v7+VO7j4+M73/NDespFTsn1+vp6Ila0Q/VBrkSyVB5pycfnXIckDW1AlijTqfwmHKRGxhJl8Yt8yEW5/BvbebG8y3SZsmo16ShLn2NaY9IxBrVMeUw6MgG5nWI+kA5E3+/3J6IBAWGx5iiFhZZ/IwkIC7MW6bp0T09PZ+OZ/kVZ5KEc8vBLeSzIlA/ZYZHnc9VHeqWjThEiSIL+vr+/D8QAogCpkVz8Px5vBHmpi7ojoQh/k4bPICQiU8gZScInyR3Da4e8SlslX02kQ0dXyKK8kgMiEtseZOkjry0neQaZSUceHLdciknHgtoz6VgQ/GWqriUdOjJgoYy7/jAu5aPw+fPnT+mxAot/U7q0WfQv0omMUAYLeGK5CPIcDodAJrBukD8lFxCiSEI+HY/HE9FIyQh5VIYWexEVZMB68vj4GMpWO2SFSIkSMR8gBCIg+g5ShAxVHGpUmOIb6sVykrZHeYbK28fvZpkuta1aTTq2pa8ppDXpmALVnmWadPQEqpxkjZYOdt7syGU5YAfOAs5vdbF9e3sL5IE01XRV0sHfCuhW4w8R5GnwkwjfcZxCHRAASAE+EyzmdREjo89JsHogc6w7EJWqDDr2qKqWz+X3ojxjSYeOstL8qWUkkqBe8pp05BmEJh15cNxyKSYdC2rPpGNB8Jep+gPpYBcO2Xh7ewsWB8TSq51Ni21bujGkg6MSji1SXwvJBMGB+EA24rFM8PWIxySn+YN2cARRXeCrb2mI4EBk4hHPhzKqeS4lHXXygiFtlM9JF0ky6cgzYEw68uC45VJMOhbUnknHguAvU/UZ6dBiiE8Bu3oW/+hQGY4E4oudJ0uHjkba0o0hHRzjYGmBWMjvgXJ0vEF9EASIhq6iYvVAHv7W8QXHItGq0WnpgMiw4FMnC7r8SuRrklpHqqSjckSUNvnseCV12k3lVV0iPn0sMyYdeQaMSUceHLdciknHgtoz6VgQ/GWqro3ToWOE5CZLOFaBdLAo4x/BMYeu17JYxxsvH9KNIR06Bklvr0Sn0pNviZxP5VCJrMjDUYiICu3oa+lgEecGjm616KYO1pY2S0eKg3xQkjY3ko5U3rSuIfIu02XKqtWkoyx9jmnN5kkHzm3sWNIfmUyrVwjHAKQ81BOvHH7AjAmNybcakIgJsu1pZ5OOSzTivEbACGwNAZOOrWksv7ybJx2cEetanODRjk3ntDlgawtKhPk5XnM8w5PzcIjK8/NzLc4mHTk04zKMgBHYCgImHVvR1HRyFkE6GiI1nkytTUGIgLUpyBKEgXKxomCtkLd99WwX8yyEoxojQSrDYa0p1LVJx3Qd2yUbASOwPgRMOtank7klKpJ0cKyhwEeQh6YgRHIoqwZjgkBg2VDMATnZQTyqpANSEYMu1WIJqeFcvo6UmHTM3d1dnxEwAksiYNKxJPrrqLsI0pG+ZwGsWCZi3INPeObHgEOntioIEWnrgixBQqrBj8gTPz/DjM9jhMVaLEV6FCwpVbtJxzoGgaUwAkZgHgRMOubBec21FEE6dLwi7//46NMpOJHemkgVARFpCsakNxxSn5AWn47agE8VpdemMelY89D4KBuWsSWuTi5V77a0Y2m3gIBJxxa0NK2MRZEOoOI4I967DyGQOWppCkLUFGQJK0k1+BHhoPm8ZtEx6Zi2j66p9D66nkLepert3Rb8prj+2uQ03bsgJywaAZOOotXbq3HFkQ5azW2SeG02BC5qCkKkx6MU4CgNxgTJUDAkjmj0cmWVdJAOy0rTg1AK8vTy8vIBa1s6evXRNSVqXPw5RktCkp/pmj5A6HC96EqDsF7ER8/O0mKti2HG088b61V6+njdK7N1dejtlgH141BdJ9dJN3WhxlVPnWx9lCpMh8ipPHUWqbbymmRVHuStltmU59J298Fmq2lMOraquXxyF0k6FLo5LgKNQYjagjGlwYTw74iPVn2YeIjfER1Va7GEsCCHHrxKVWfSka8jz1RSWPzpXzH+SnAQxrqmZ+PjU/BB3yzE7P7pO/xggdNLrvytJ+vTx9DIr4ffkmPCWtJB34uEN32HhX4YnJspS++kyJEZ656eo0/rV5tSHGPgr+BU3SBXmjwEPos3vcLjcHraPvb/04NyylRHVJAdjLVZYGylmMY6auXBv4rvFawsDR7WVB5jkHaqfcgaj16DP5heuOV7ytXmoYqj8lCe3tEhDzqvCWI2U3ddXzUmHevTydwSbZ50zA1YtT4ms2gFqcWSCZvJt84SYtKxtPYG16/dfvAH0kJ+c3MTFi4sGXIc1sNoWvyxQkTfDC1w4Q0TytHDapSh4wmOBZO/mywdp5dUSU9ZcTceFj4seKk8et5eZILv+Kyufr3HotdgG+SqtXSIzMvBmr8jcT8bI22kg7Gh12n1wB14V3CBxJ3hVHfDLBK+2vKoh/EpWdPysGJG4hTk1hGrcEzzKEw8+u5q9+BeV1AGk46ClDmyKSYdI4FLs7Hr0SNd6edMtkz+TTE8TDoygD9vEXqcLYQmp2oWTkgnv8kOPuz4+U3f9WhbZHVFGyuHfqIDdLBcpO+I6HtZIFjoKtFyT2REC278N5AQ7ebjs/eBdDQ5SnfIVUs6qmHMSVRXfhseImjxOnoI+w5xG4OT9IQ+quWl5CbpSie8kUNvtEBAIJPVV3ATfQUClL7AG2P41PmCzdtzV1KbScdKFLGgGCYdGcBnImey0SudKhKzOxNQUzh2k44M4M9bhF5XDWQCfdeRjrjIBskuIR0iCk2kg37HIqjfeOvqA0kRCdARULSIhGOcSJYGkY5ErslIBwVD2rXQY/XQMQtyp+SsCycJWVcem4Ka9gTSgWVDuqQ+ZCH9ENJBfjBu8vmat/suX5tJx/I6WFoCk44FNWDSsSD446oOi1F6fEAx8sEQuUSv7KhZKPuSDnwgMNvr8TeO7Vjgor/HB0tH5ftwaysuiIF0pMcMWAewxLFj15GFFnUd71Trly8S6VrkqiUdFVmoM7SNulMCLp8X+UnQpkgmwjFKclx0OtrQS7h9cZKATeWBU/w9Wa7AKh5PnXw4dEwF8ZB/l67Uy1lcPjvpVXusoOnjeeO6XTm5TDrK0eXYlph0jEUuQz6TjgwgzlvEafFPzfJy6NRLrPFl2LDI9yUdcnSErGhXTXlxca09XmEnnj4Rnzw9f4qmq105C6Ei8Mq5VXKmjpu6wSULg8pvkOuEvvw24nXzYCWAaGDpoyzyV52p5fCtskUAkEfOuamsIk16ZbcvTgjZVF4kdkFOlRcdeE+WINohssF3+M1U2yddpZ+n2M/bTddbm0nHenUzl2QmHXMhXVOPSceC4I+oGn1ph82Cqd2wnET1zDsLEJ9BJPhMtxeqfyNCtUwtbtEnJA1w92GsIkNdeiwd8teIRyinvBAPyclizyIaF/3g76Hy0iOBlnrOUMQ6Em9shPr0d9qWKuxgggz8UCeYCuNUVmFKuiZ5Uizr1FtXno6eZK1K241s4MFP4hB88s9oap8+r2I/ossVl8WkoziVDm6QScdgyPJlMOnIh6VLOkNg9cHE1qKvOqfXtchWohwmHSVqdVibTDqG4ZU1tUlHVjhd2FcImHT07A0mHT2BypTMpCMTkBsuxqRjQeWZdCwIvqs2AkZgdgRMOmaHfHUVmnQsqBKTjgXBd9VGwAjMjoBJx+yQr65Ck44FVWLSsSD4rtoIGIHZETDpmB3y1VVo0rGgSq6BdCgqKzcY/AbFgp3NVRuBFSBg0rECJSwsgknHggoolXQoUibXH/XyqsKGLwi3qzYCRmBhBEw6FlbACqo36VhQCQzAX/zDP+6++PYf95Liy1/90+67f/onpzgGvTLVJKLen/38l7v9F9/qXcTLl7/eff9736mtG2sGsR/SNz3SgolxECNf9q7PCY2AESgPAeaJf/v3/xw094BC2/xTHkplt8ikY0H9KljREBHaAi31LaetXkVRTB+tUrlNdZt09EXe6YyAEWhDYMz8Y0S3hYBJx7b0Nbm0OeIW+HhlcjW5AiNQJAI55p8igSmoUSYdBSkzR1NyD3o7kubQisswAteBQO755zpQ21YrTTq2pa/JpfWgnxxiV2AEjEADAp5/yu8aJh3l63hQCz3oB8HlxEbACGREwPNPRjBXWpRJx0oVs5RYHvRLIe96jYAR8PxTfh8w6Shfx4Na6EE/CC4nNgJGICMCnn8ygrnSokw6VqqYpcTyoF8KeddrBIyA55/y+4BJR/k6HtRCD/pBcDmxETACGRHw/JMRzJUWZdKxUsUsJZYH/VLIu14jYAQ8/5TfB0w6ytfxoBZ60A+Cy4mNgBHIiIDnn4xgrrQok46VKmYpsTzol0Le9RoBI+D5p/w+YNJRvo4HtdCDfhBcTmwEjEBGBDz/ZARzpUWZdKxUMUuJ5UG/FPKu1wgYAc8/5fcBk47ydTyohR70g+ByYiNgBDIi4PknI5grLcqkY6WKWUosD/qlkHe9RsAIeP4pvw+YdJSv40Et9KAfBJcTGwEjkBEBzz8ZwVxpUSYdK1XMUmJ50C+FvOs1AkbA80/5fcCko3wdD2qhB/0guJzYCBiBjAh4/skI5kqLMulYqWKWEsuDfinkXa8RMAKef8rvAyYd5et4UAs96AfB5cRGwAhkRMDzT0YwV1qUScdKFbOUWB70SyHveo2AEfD8U34fMOkoX8eDWuhBPwguJzYCRiAjAp5/MoK50qJMOlaqmKXE8qBfCnnXawSMgOef8vuASUf5Oh7UQg/6QXA5sREwAhkR8PyTEcyVFmXSsVLFLCWWB/1SyLteI2AEPP+U3wdMOsrX8aAWetAPgsuJjYARyIiA55+MYK60KJOOlSpmKbE86JdC3vUaASPg+af8PmDSUb6OB7XQg34QXE5sBIxARgQ8/2QEc6VFmXSsVDFLieVBvxTyrtcIGAHPP+X3AZOO8nU8qIUe9IPgcmIjYAQyIuD5JyOYKy3KpGOlillKLA/6pZB3vUbACHj+Kb8PmHSUr+NBLfSgHwSXExsBI5ARAc8/GcFcaVEmHStVzFJiedAvhbzrNQJGwPNP+X3ApKN8HQ9qoQf9ILic2AgYgYwIeP7JCOZKizLpWKliLJYRMAJG4NoQMOkoX+MmHeXr2C00AkbACGwCAZOOTajpIiH/P7wDtiNe1P0hAAAAAElFTkSuQmCC
[RtSig-IO-Model]:data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAgQAAAEcCAYAAAC4b6z9AAAgAElEQVR4XuzdBZhsxbU+/EICBDshweEfLMHdJbi7a4DgrsEhF/cQ3DW4BYK7u7sGCxocAtwLgZB8z6++1LlN35k5M6d7z3T3rHqeeWame+/atVftXetd71q11gj//ve//52ihQRCAiGBkEBIICQwqCUwQgCCQT3/cfMhgZBASCAkEBLIEghAEA9CSCAkEBIICYQEQgIBCOIZCAmEBEICIYGQQEggGIJ4BkICIYGQQEggJBASCJdBPAMhgZBASCAkEBIICUQMQTwDIYGQQEggJBASCAlkCURQYTwIIYGQQEggJBASCAkEIIhnICQQEggJhARCAiGBYAjiGQgJhARCAiGBkEBIIFwG8QyEBEICIYGQQEggJBAxBPEM9EkCV199dXrqqafSvvvum2S8vvvuu9NYY42V5pxzzj71Uw5+//3304MPPphWWGGF9KMf/Wi4+oiTQgLtLoEvv/wyXXLJJWmEEUZI66+/fhpttNEqu6VnnnkmXXHFFWmllVZKc8wxR2XXiY7bUwIRVNie8zYgo95kk03SOeeck7755pv0/fffp7nnnjtNP/306bLLLuv1eC6//PL04x//OIOAG2+8Ma288srp7bffThNMMEGv+4gDQwKdJAGAYPLJJ0+ffvppevXVV9NUU01V2e1de+21GQz85je/SX/84x8ru0503J4SCEDQnvPW51F/9tln6Yknnkg//elP02yzzZb+9a9/pY8//jj985//TB988EH68MMP0zzzzJN+8pOfpE8++SQzAF9//XV66aWX0uyzz55+9rOfpXPPPTdttNFG+XPWzLHHHpvGGWectMUWW+Tx/O1vf0sskF/+8pdpyimnzP1iFKaYYoo09dRT52OcB0hgF9566610/PHHp4MPPjhfV3v00UfzmLAOWIMvvvgi/f3vf0///d//nX9PMskkadJJJ+3z/ccJIYFWlsDSSy+dbrnlloQ1827+9a9/TTPPPHMaY4wx8rv5/PPP5/fWe+Kd8D77zvvmXfnqq6/yO+K8WWaZJY0//vj5dvWFhfPeTzfddBl8//znP0+bbbZZOuOMM1pZJDG2AZBAAIIBEHp/X/If//hHtuJZ5/fee2866aST0iqrrJKWWWaZvECwSG6//fa84Fx00UVpjz32yNbKrLPO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L7+cqx+qdqiNMsoouVriN998k//3Xam26H+1GfQ5zTTTpBFHHLGps6vaoxKzyjFXkdJZyujuFD6lqNjUzjvv3NR76mtnzz77bK7Ap5Jef7WVV145z+tTTz2V9thjj3TkkUcO81nrr7HFdUICnSSBAAQdMJvPP/98rkdAgWusecWLlFJVo2CNNdbICuyyyy7L3yu1+vHHH6fZZ589K83NN988qXB4wAEHpA8//DDNOOOMuazxr371q8wQnHzyyVlpK1WsZLL22GOP5WNUQ1QmecMNN0yfffZZBh+uW18QSdGka665Jt1///15rJTKjjvumN54442077775hKtE044Ya75rm47oHHJJZeke++9N48dOPj5z3+eNt5441zr/c9//nP69ttv02qrrZZ22223fO+Yjquuuipb8co5+67IpC/T7FquD3zUNjK96KKL8vXGGmusoV85HphR6rkAGbLBKOhHaej6Bohp5Rx/77fffmmzzTbLcjAfBdA4lhyefvrptNNOO/2fvrAH5RquWXtebf+1JwJValnMNNNMmXnwvzkBrgA/94cZ8pz4TjXMwiKtuOKKeQ401rrnibw11ycLCtzfQKhyuwCm/rpqpeS1crwa0GHcniPt97//fZ5Xz86VV16Zn5Fhgc++zHcc23oSsNbcdtttuUS652CBBRZovUF24IgCELTxpLIoKVKW0/vvv5+teVb3a6+9lh5++OGslClXVCvlRmFaaAEDP8stt1xWbo6hRBdccMF0wQUXZKULJMw///xZYRx66KH5c22HHXbIizNFwNoHNlyP8uViACrmnXfetNdee/1AaWIQgIJVV101W/2PPvpoVoDG4/wDDzwwrbvuupmtmGSSSTLIuPHGG7OCpLBOOOGEbJViKCiYXXbZJY9Bv8b44IMPpuOPPz6Px3Gnn356mnnmmTPo6C1TQIEZC1BDqRnvQgstlOvGf/HFF+nWW2/NSpFcCuChDFnuFJR7AagoLBT3Aw88kBUh5T799NPn2vX+p9gteOYEiDJvFj79brXVVpkhAcTMm6Y8NQBGNrVlqo1VX84FmhzvHswzt4Z7oPQXXXTRoayL/jwb7777bn5uuIlGG220DPR+97vfpe222y5tuummaYYZZsiVLl2XcqfM0fTmZtZZZ82A7L333svPgDEAMWuttVY688wz8z0CQjfddFP6r//6r3z+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NwAQKMITLSQQEggJDFYJRFBhtTMfgKBa+Tbce2EIxBAEIGhYnNFBSCAk0MYSiBiCaicvAEG18m2498IQyKEfLoOGxRkdhARCAm0sgWAIqp28AATVyrfh3qUpFlQYDEHDoowOQgIhgTaXQDAE1U5gAIJq5dtw7xFU2LAIo4OQQEigQyRQguQoaLsAACAASURBVAol3Iqibs2f1AAEzZdpU3vEEJRdBhFD0FTRRmchgZBAm0kgdhlUO2EBCKqVb8O9B0PQsAijg5BASKBDJBCAoNqJDEBQrXwb7r0wBBFU2LAoo4OQQEigzSUQgKDaCQxAUK18G+49AEHDIowOQgIhgQ6RQACCaicyAEG18m2498hD0LAIo4OQQEigQyQQ2w6rncgABNXKt+Hey7bDSF3csCijg5BASKDNJRDVDqudwAAE1cq34d4jD0HDIowOQgIhgQ6RQOQhqHYiAxBUK9+Gew+XQcMijA5CAiGBDpFAAIJqJzIAQbXybbj3YAgaFmF0EBIICXSIBMJlUO1EBiCoVr4N9x6AoGERRgchgZBAh0ggggqrncgABNXKt+Hew2XQsAijg5BASKBDJBAug2onMgBBtfJtuPdS7dAug0hd3LA4o4OQQEigjSUQDEG1kxeAoFr5Ntx7pC5uWITRQUggJNAhEiiAYJ111oniRhXMaQCCLoT6yiuvpNFGGy2XHK5tH3zwQRp11FHTT37yk/TJJ5+k9957L80wwwxpxBFHHHrYq6++mv+ffPLJ8+/PPvssOW/aaacdesxf/vKX9K9//WvoZ3/961/T3//+9zTNNNPk69a2cBlU8NRHlyGBkEBbSiCqHVY7bQEI/iNfIOCAAw7ItPy5556b7rnnnnTQQQelDTfcMG255Zbppz/9aXrppZfSPPPMk3bcccd01VVXpZFGGinddtttaYcddkgzzTRTuummm9Kdd96Znn322Xwupf/FF1+k119/Pf3zn/9Mq666av5+vvnmS2eddVZaaKGF8tVHHnnk9Pnnn6dnnnkm7bfffl0CgkhMVO2LEL2HBEICrS+BiCGodo4CEPxHvn/729/SxBNPnE477bRs3b/44otpp512Si+//HLadNNN04cffpgOOeSQJOr//vvvTxtssEG26DfbbLPEwt9kk03yd4sttlh6880303fffZdOOumktMcee2SmYa655kpHHnlk2n333TOImGKKKTJImHPOOdMuu+ySQYV+Zpttth/MeNQyqPYFiN5DAiGB9pFAAIJq5yoAQY18RxhhhPTQQw9lFkDz/3333Zct/4cffjjdcsst6eabb07LLLNM+ve//52POeWUU9I222yTRh999HT00UdnNkHbd999M0uw4oorZoChjyuuuCJtv/326emnn07jjz9+Zhn+9Kc/5WOBkb333jttu+22XTIEQEUEFVb7MkTvIYGQQGtLoACCddddN2IIKpiqAAR1gODee+9Nv/rVrzJ9v8UWW6Q77rgjHXPMMVmJX3bZZRkYzDvvvOnRRx/N1v2xxx6bTjjhhPT9999nxX/XXXflHi+99NIk8GWvvfbKLAL3ArfARBNNlFmHnXfeOU055ZQZRGAUrr/++nT22Wen999/P1wGFTzo0WVIICTQ/hKIXQbVzmEAgjpAMNlkk6VFFlkkLbroomn22WdP4447bvrFL36RBPcBAbPMMksGCKz9VVZZJU044YRp5plnTl999VWm/bVf//rXGUyw/G+99dY099xzp+222y4DggsvvDCDgjHGGCP3BQj4u/RRzxBEYqJqX4DoPSQQEmgfCQQgqHauAhDUAQLW/tRTT52tf4GEX375ZbruuuvyjgFxAKx6ShqD8M0336Q55pgjjT322LkXwYNiDwQACjIEIjALjqP8uRWeeOKJvENBYOHPfvazZFeCYEWAgNvgRz/60Q9mPKodVvsCRO8hgZBA+0ggYgiqnasABHWA4KmnnsrKu6smbkBcQWn1//d2quw+qN2q2FM/kYegt1KN40ICIYFOl0AwBNXOcACC/8j3tddey6yAbX9bb711zjfQCq1kKuTKsAUyWkggJBASGKwSKHkI1ltvvbxdu51a2YYuj02rtgAE/5kZroFvv/02/eMf/8jUfau0su0wUhe3yozEOEICIYGBkgCGQEyXOK1mAAJbvR944IEcN9bTuv/pp5+mlVZaKceW2T02vE3gudi08847L4055pjD201l5wUgqEy0zek4GILmyDF6CQmEBNpfAgCBXV7LLbfcD9y3w3tndpFJEidfzPTTT593f0k8B3SUJuZr/fXXz3llbBdvRJHLV/PCCy+kG264Iceo1TcAZbfddkvnn3/+/8laO7z32JfzAhD0RVoDcGwUNxoAocclQwIhgZaUAMVta7ct4NyopdnNJSX8rLPO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nVUngS+++CK99tpraeKJJ+5y3v72t7+lDz/8MP3yl79Mo48+egIE/QT4q25Oouf2kkDsMqh2vgIQVCvfpvf+l7/8Ja222mrp+eefz8GGEDPlEa31JfD222+n6aefPk0zzTTp7rvvTmOMMcYPBu2zRRZZJO2xxx7p8MMPT3/605/SZ599ljbffPOm3pxA1ZFGGikDjQI2vvnmm6HXGGGEEdKoo4469P/vvvsu/+0c3/nx2ffff5//9rv2GfzXv/6Vvv3229yH76OFBJolgdhl0CxJdt1PAIJq5Ru9hwSyBChQShez89Zbb6XLL788/fSnP82fKXH9s5/9LB8388wzp8UXXzwdc8wxebspxuCAAw7Iv3/0ox+lccYZJ2EaKFznjzzyyOmrr75KlPDYY4+d+8AqUPquOeaYYw5Vyj5/7rnn0lNPPZX7ochXWmml3Nef//zn9N5776V//vOf6Re/+EVaYokl0lhjjZVeffXV9Mgjj+S/v/zyy6QM94ILLphuueWW9OKLL6ZPP/00jT/++Ek5Wvfw8ccfp4cffjj3helwP8YZLSTQDAkEQ9AMKXbfRwCCauUbvQ9yCVDCf//737Orh2I95ZRT0uyzz56uuOKKJMcExfrQQw+lzTbbLM0222xp6qmnzgwQ5ufmm29OP/7xjzOrsNxyy2Xl+vvf/z798Y9/zH0deeSRabzxxkuXXHJJ+uCDD3KeCkAAE/HKK6/kH8GotqxqFPhBBx2UNthggwwg/vCHP6SrrroqK/snnngi3X777en1119Pu+++e5piiinS448/nk4++eQ055xz5riVtddeO4/loosuyvd0/vnn5++Bl6WXXjqNMsooaa211srxLgsssEC67rrr0kcffZR3x4TbY5C/CE26/Shu1CRBdtNNAIJq5dv03j/55JP00ksv5QDDGWaYIVtrrMRorSkBMQNAwEwzzZQV61JLLZVmmWWWdMghh6Qdd9wx7bTTTplaxwI88MAD+TtW+2677ZYmmmiiNO2002aLfvXVV09//etfs+K+/vrr0zvvvDMUIGy99dbpxhtvTI899lhW/jfccENaZpllMjOgX5a6hpXglth2223TT37ykwxIXKPQ/c5/+umn06abbpq/Ax7EqBij9uijj2bgsfDCC2cQgQk49NBD07nnnpv7u//++/M1jj322KGTsf3226dNNtkkg51o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gQceSDPNNNNQWb3++utpjjnmSKussko+96ijjkrSxU4zzTRpgw02+EFAW1sIuEMHucUWW6TDDjssA73B0AogsMOCaytacyUQgKC58mx6b7HtsOkibckO55133vTYY4+l448/Pi90qGAWuuI1c801V7YC99hjj2ydH3rooemmm27KQOCLL75IRx99dD7voosuSpdcckk64YQTEkUhyOyOO+7Ix1H4mAYuAecCFxog4dpcAKzN0t5///204IILpnnmmSf/5j7QXEeq3GghgYGQQNQyqFbqAQiqlW/DvUfq4oZF2BYdoOQp+oceeiih8ccaa6zss+dGoMBXWmmldN9992UGgbV+3XXXpYMPPjgf/84772QfMlYBA7Djjjvm/ylzjIHPn3jiiQwQxhhjjHTKKacMdT9hCCaffPJ07rnn/sAl9eKLL6aVV145bbrppvma559/fppqqqlybIG++a2jhQT6WwIBCKqVeACCauXbcO8RQ9CwCNuiA1Y+V8Bdd92VAQHl7W90PjoYU/Sb3/wmxwJcffXV6bzzzssxBU899VRW9ocffnhmEJy7yy67JHntl1lmmazoN9544xyNTqHbquY6PtP0u/nmm6cbbrghPf/882niiSfOcQyYBj/iFfbbb7907bXX5vgFQYYy5B177LH5vNp4hLYQdAzy/0iAS8mPyom1WxlbUVSx7bDaWQlAUK18G+498hA0LMK26IDSveyyy7IlPuecc6b1118/jTPOOGm55ZbLte7lqOf7v/zyy9M111yTS95uu+222Yofe+yxM5vATUCZ8ymLLeDz5z7Ye++9M7gQE0Dh77TTTj+w8F977bW0wgor5GvOP//8aeSRR07PPfdcmm666fIOg/XWWy8zA1iMRRddNIluBxAwDYLZYpdBWzxi3Q7Ss8Ty3m233bosmlRO9GyNOuqoA3qzEVRYrfgDEFQr34Z7jxiChkXYFh3w8fPjTz/99Fn5y0svol8MAZaAdc+Ku/7669Nss82WF+7HH388bxGce+65M3MgKNF5yuMKJhQk6HsBghS9/er33ntvVvhdlcnlhrAjYcIJJ8xjGHPMMbO7oIzNOAQYahdffHHOQbDwwgvn/qL9UALmodWt7doRe+7ErCihXD9uQAAj5fnCUg1ki6DCaqUfgKBa+TbcewCChkXYUAe28N18883pwQcfzJYxf3u0kECt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
[Async-IO-Model]:data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAeEAAAFUCAYAAAATTYTIAAAgAElEQVR4Xu2dv5IyR9anaW+tFWvLQXdAhCx5bY41wdwBjnx0B30HwpfDHYgYa0y8sSYWfw2xhuwPfdZ6vfFL5UFJUQWnkgSyqp+OeOPthvxXz8nKX52Tf+ptUuHP8Xj8XK/XE/2bTqeT9/f3yWw2q7CldTXpcDhMdrvd5Hg8TlarVfg3nU7f6molrYEABCAAASNQ3QC93W4/l8tlEN6Pj4/JfD6vro21d5/dbvcpdvv9frLZbCaLxQKGtRuN9kEAAl+SQFWD82az+ZT3hnCU6Yv2QKOIwnK5rMrWZa6QUiBQloAeYPXwqmgSP90EFKGcz+dylhhX7uwo1QA0wVA4Fe/3Tqsm2ff7/aeiCjzYlGNKSeMiwPRXf3sy9dWfWVeOKkRYN4HmfBGKcoZNS7IHHN04zBE/hjGlDpMA01/32Y2pr/v4KXcVIvzx8RFCQNvttor23I+1vhIWi8WnwkcfHx8wrs88tOgFBJj+Kgedqa98llUMyNPp9HO73TK/kG/Hmzn1xLpYLDTXVYXNbzaYBBB4IAGmv8rDZeorj+nLB2SJg1ZDHw6Hl7clD+Fwcs1ms0+F/FlMMRyb0dLyBJj+Ks/USmTqqz/blwvfer0OoejNZvPytvTHN6wcy+UyhKRXqxWsh2U6WluQANNfBWG2FMXUVz++Lx+MdUOoySXnKtUJtC1nNpvddX0Kr8hzXK/Xb5o/Ujtzt/roCdH2676/v3/udru72tbPzH+mfgTrnHaQBwKvJMD012PpW1iaqS8f56cLQbNZpYVBYqeDKrQtR+Lpw9Ceylb+STAPh0MQ4TuEXflDe1TuK0LCpVnfw5a8EHgFAaa/nkOdqS8/57tEyl9Nd8rSwmBesBYh7ff70/Xp5tMGfO1DVvg7nsgVvlcb7IQubUK3k7pSEdbvSivx1JySnUilrVXxeM2zz5VWB4/I+5UXrXlv5ZHHr/rM85e463NtH1Ib7KhJq0/t1b+0nlzupVnntoN8EHgVgVdNf6VRNbt2fab7XePHo89GuDeS19deTH35iY1KhCVoJr6r1SrMf1r4WAKkzq5Ob2KntFEMgwjrO4mhiaLEWr/LE04FTOFkiaKEVeHquHH9Lf1cn6k8lSERTUV4MpkEr9gWiFib1L74oBDqU9n6Ls7jhv/vmTtHhP03BinHSeBV90D6QC+yFrJ91ml2z77uZ9c35N46KhGW4aM4hvCxhM/mXpuLMfS9hDeuyg6Lw+xpVE9x9tKIpgjbudbpau7o6ZrHG5hKYGNI3FYjn8LRJsLKJ4FOhVVhnPhZEHf7rnkT53Q6bowcauQZE4FX3QPp/dslwEpjD+IaZ8yB0DhhJ1TF8UgRtuAg2MtabL1JV2Tt2df97PqG3EdHJcISMIWT9S/OvQYh0zxuR6cwYUwF8rSAyULUqSecftY0vOajdRNJ0O0n2f98IcJtbZI3bTdaDJWf5pHtgSC3w3Fj5JIj31gIvOoeMBHW+GAP5+kiz1SY5UjEqaxTpE6iLOFVNEzf63eLtFkEz85zNkchjdI9+7qfXd+Q++doRNgEUEKVCqB+1wItdQo9NdpiLQsFxxV84Ts70lGhbHX0eMLUWThanV+dPJ1vVt1Kb2c063+VZYIaF2FdiLDmp/SQkC4g04OEhFv/EOEh31q0vUYCrxIHWxAWxxl71ehp/LXomwlzM1KXjk+KpJlzIcY2zpi33BVZS8eTR9vmVZwffV2PKH80IqwFWfFp8XRNqdDanLAtcooLoEwAQ151XrtZlM7mh5tzwhLK+L7ekF7CLNGM4hwEWAKrNCrHRDi5kYIg60aT0Ju3rDx6Ulaou9mJCUc/ovtT5lcj8CpxiDsi7Hz84M2mL6uJ2xbbzKHx7CxS1/w7jZ6lTogVZos7EeE6e/vLRbjEakUTs7Z9aRJniaQEVWFi/dPvEkxb1axObasUbRWy5lhS4UtvXlvVmK5aVnp50CpTP/GIyFCPnm7VDoltfIJVksBeXrSFkyxMpbnpR4gwKxbrvAlp1fMIlBhvclrbfIjW3/aQrof2NidC41rcEukSYRvb0sialfHshw/GGn8vebkIP2vf3o1O2OzkfoIDSsnevQEZi6Y+hMCzxptm49siWXpoV3RMETgtvtIDvB7UbQ1L9GDdnrBNoVlkzaJ0ccrrbHrrIXCTQhlr/IRfLsJqqk6wefR7hL+6CPMCB/9NQcpxE3jGeOMRYaWZz+fBI1a0zKbMJMxpVMwbjta0VxpZS6N6z/SEGWv63T9ViHBz+1C/S/ClTg/baOZQ/SWPzfS16LmpOM/1ubyprV4Czxhv6r36x7eMsaYf4ypEmLea9DNa39S82aQvMdKPmQDjzeOsy1jTn20VIqxm837P/sbz5OAdnx5KpPlqBBhvylucsSaPaTUirOZrcYLmR7TJ3E6AybsscqUPNs86Gg/qEBgSAcabctayhxrGmv5MqxLhVDjsoIxXvG2oP8a6cthKzPieZh5o6jIPramIgIkH402eURhr8riluaoTYTVOczZ6oor7eMNKQa304+c6ATsxx86TtTcywQ0CEOgmwHjTv3cw1vRn1pWjShFOG6snLXl0EpaafrSlSj96QKjlx86OJXpQi0Vox9AI1Dbe1DjOyKaMNeV6dvUiXO5Sy5b0zH13ZVtOaRCAwFAIMM4MxVL57USEM9lxc2SCIxsEIOAmwDjjRjXYhIhwpum4OTLBkQ0CEHATYJxxoxpsQkQ403TcHJngyAYBCLgJMM64UQ02ISKcaTpujkxwZIMABNwEGGfcqAabEBHONB03RyY4skEAAm4CjDNuVINNiAhnmo6bIxMc2SAAATcBxhk3qsEmRIQzTcfNkQmObBCAgJsA44wb1WATIsKZpuPmyARHNghAwE2AccaNarAJEeFM03FzZIIjGwQg4CbAOONGNdiEiHCm6bg5MsGRDQIQcBNgnHGjGmxCRDjTdNwcmeDIBgEIuAkwzrhRDTYhIpxpOm6OTHBkgwAE3AQYZ9yoBpsQEc40HTdHJjiyQQACbgKMM25Ug02ICGeajpsjExzZIAABNwHGGTeqwSZEhDNNx82RCY5sEICAmwDjjBvVYBMiwpmm4+bIBEc2CEDATYBxxo1qsAkR4UzTcXNkgiMbBCDgJsA440Y12ISIcKbpuDkywZENAhBwE2CccaMabEJEONN03ByZ4MgGAQi4CTDOuFENNiEinGk6bo5McGSDAATcBBhn3KgGmxARzjQdN0cmOLJBAAJuAowzblSDTYgI3zDdbrf73O12F6nss/f399YS9Pn7+zt8B3tr0HAIvJ4AIvx6Gzy6BYjEDcK6CX79578m8+9/cNti/59/T/7x979NPj4+4OumRkIIQKBJABEef59AJBwi/Nvvf0yWP/7k7g2bX36efPftN4iwmxgJIQCBNgKI8Pj7BSKMCI+/l3OFEBgoAUR4oIbr0WxEGBHu0V1ICgEIPJMAIvxM2q+pCxFGhF/T86gVAhC4SQARvolo8AkQYUR48J2YC4DAWAkgwmO17F/XhQgjwuPv5VwhBAZKABEeqOF6NBsRRoR7dBeSQgACzySACD+T9mvqQoQR4df0PGqFAARuEkCEbyIafAJEGBEefCfmAiAwVgKI8Fgty5yw27K6CTisw42LhBCAQEECiHBBmJUWhSeMJ1xp16RZEIAAIjz+PoAII8Lj7+VcIQQGSgARHqjhejQbEUaEe3QXkkIAAs8kgAg/k/Zr6kKEEeHX9DxqhQAEbhJAhG8iGnwCRBgRHnwn5gIgMFYCiPBYLfvXdSHCiPD4ezlXCIGBEkCEB2q4Hs1GhBHhHt2FpBCAwDMJIMLPpP2auhBhRPg1PY9aIQCBmwQQ4ZuIBp8AEUaEB9+JuQAIjJUAIjxWyzrnhDebzaeSLpfLqsT6/f39c7fbtbZJbZ7NZuEKD4fD3W3nxKzx3wRcIQRqJYAI12qZcu26Kq6HwyGI8Gw2q0qEJ5OJ2nXRpuPx+LlcLifb7TZ8t1gsPjebzWQ6nWa3HxEu19koCQIQ6EcAEe7Ha4ipgzjt9/vP9XodPMfpdDr5+PiYzOfzt91uF0T4/f39TQKnNLvdTqIc0twSZ+U/Ho+TKIT6P5SpcvS5BNO8bJWvMvf7feC4Wq0kohfti58ryYWwqsOqbVamvGJd08fHByI8xN5JmyHwxQkgwuPvAEFcTVTn83kQWYnm4XB4SzuAQsASaImg0iSi3Slwyq90Ki961BL0kFd1mqBKJFV+FNDwMKDvJMiqMxH9IP5RqC/qnc1mnzFP+E7XpmvSteSaEk84lxz5IACBewkgwvcSrD9/EGGJqnmdCkHHOdWTCMtjlXimYrZcLj/12bX5YnUgebzr9TqIYDOP6rJy5bWmXrGJtQQ5PhiEMtL2pXj1+WKxkECfCe58Pv/cbrc3vfYuUyHC9XdiWgiBsRJAhMdq2b+uKwiWDC2hs1CzhE/hXusAEkR5oOliKE/naKaJC6raqL5tt9vgNVs4WokknmpTbGMqrhdzwgpzN9uofKpTnyuknmNORDiHGnkgAIESBDzjbIl6KON1BN7kgUr89C8RqiBy1gHkYcobTr1MebUK9a5Wq6vh6FRAtVBK5ZjXbZ6t/ldZCltL8LWQysRToqyHAvOm5bkrRN2cE0aEX9eJqBkCEHgMAUT4MVxrKvVtvV4HL1griiVwmouNc7hnc8Kab9V3El0JXgz9Xg3zNjuQCb6Fh80D1wOAlScBVpts7lmhcQlzFOg3ib+1LwXZNf/bnCfuCx9PuC8x0kMAAqUIIMKlSNZbThBeCaCEWB6mPFWJnDxQW1ClhVNaQZ0KYxTOqyHetg5ki7U0V2zzvlqJvVqtgkeuH7UnXT2tULXqtgVbMd1F3c3536554j7mQIT70CItBCBQkgAiXJJmnWVlzZPWeSkTPTScbUlqblnKaTcinEONPBCAQAkCiHAJinWXcZcIy9M0b7l5mel+3Wci0Fyywt3mUXedrOVtEyLsJUU6CECgNAFEuDTR+sobnQgrbJ5iVqj7HuxfTYT1YKXQvz3I2IK5XI6yR9zrfZcd7rFhmteOPFW79ABpC/685V87MtVbRk66Z9WrqZ904WTftt6bv1lf0063ys+1a9/rfFZ6RPhZpF9XTxUD4+su/3bNX02ENdhrTt5WvSvEb/PxOcd/3rtF7LaFeqcIK/+7VtM7Sms9MtWR794kD6/3Dibh2u7N3wZIa1a0FsRO8Gvbhpjme0Qb7jXcPfkR4XvoDSMvInzDTl9NhNvO5ZYQaxGdFstpQEwPdtGCPh2yIg9EA6QtuNNiPg2IdtCLHXPadWypONtCPZkkeqlhwWDcp97aV+UZKa3qTY86TT/X1IgW88WHiGIirDriYsHOY10VWdAiR0UWrI12PGxs0+mYWBOytmNdr52XbqfIpdfZdcys2mOLMJv1a+eBvlN5sqnS6ne1VzYQX9u9oL8tOiIOinbIDmn+9NZq6x/Wr3T8rU1t2RGzdmSursn6WLN96XG71kdMhG2BqZ3MlxvJefUwjgi/2gKPrx8RRoTPCMhz1Qcmnun54OkJZ0qjFe1xkHuzLWxx73gYsO0YUjvsJV0R3zy2VCITzxIPginhsjbErXEXp7PZVjlblxBf3hGuR968nVluYqOzy03M7vCYgohbhEACoQFee+Ajk9B2Ey/9bg8XdgSr7bu3NqoMnUYnUek61rVLhNPjXuNxs+FQna5jZtWervpTkVMa2dJskJYt0Y0e6clOKtd2T5iIpx2rrX8oj/WfeGJeKM94qm47y17X1GxfetyuHYErfvEkv7OdHs2T9B4/tJapAREuw7HmUhBhRPiMgO0Vj8IQBmINqub9ahuY/a2BVR6eBs3pdBq2mNn2MhPvNBx97dhSiYw8LuWTQMazw08nuqmRzRdxNMtTvvQ1lnb4jAb46KUVEWGVZYKja28+nMSHmCCo9rBhImDRgcZ55kHYb/FpHlDTVq95l13HzCbns1+cQJc+mKic9LhYXZPsHU/VC1sK9VAVzxi4GS5u6x9pfbr2GGUJUyFKfzwez6YNrrVPLOJJf0F82/jWPBB3tQ0RHqLV+rUZEUaEOwlYiFDiKrGVqOkgFfN6JLg22GnQNu9Pn9ubuFIRvnZsaerpNb3UroGoa77ZHiTUTvO2YljzpgirbjsqtWOFv53YZm8dC0Ih0Wv+xONSz4587fDAgwh7+Vg9Xd582+fXjqBtiw4ovdrf/InTA6cXv0jwbHHbtehCV/+Q2MY53xAB0QOOhZJ1gFBaZvp7V5+4xrff0FhHakS4Djs8shWIMCJ8ImBzbDFse/pcXk8MCwavz0LO6cs54os1TnPDyqxBNBXKrmNLo9d8WnjkFeFmeeYNWXha3mrLgp6rc8IeEbY5XomHWIlb81hX49G8lmsi4eVjhmmr1+Zn00iCeeaym0U2Glv3LpjoYSs9LlZl2DXpd31vIeo4x311sVtX/7Djb/WQF0/SC9EUezlMlwi3tU9CbyHqtut75ED6qLIR4UeRradcRBgRPiNgYcP0jVZxtfRZSNreEy3v2ITZ5kfTo1AlwrZgquvY0jhg9hbhtDw77U0iY/OwCmvaqWn6Pq3n3jlhQVNo3s5cT491tTBxcuLc6eUn10TYyyc1WNtxsuZZth0zG9+vffYyltQTNvE2m1oExObfld8WakWRDrzNa22Kv4m3vSZVD0Vp/7DT8PQQo+kGMVXfsleSNkW4q312BK6895YV1A9fWf6oIR0RfhTZespFhBHhMwLyriS6Ei39swVS6X5aW5SkOTvLnHx2OutbHq6dAx7DjOE8clv9mx5bmhOOVt1peTE0aiu4w//yjHQ9EpMYOi+2Otrmd+0lIzZPbO/dthXiqSjcCpd6+KQG6zpOtuvza/Xb+etROMObzWx7mq28toVP6ToB29Ym/hJby5+2s6t/xDRhbYHWHSjqIrtJ1PVd2t5r7bO+JAFHhOsRGFpymwAijAi3EtAgrgFNg2+6QtpCkfFscfrP7XuMFBDIJoAnnI1uMBkZRBFhd2dNF2rFBU/0Hzc9EkKgPwFEuD+zoeVgEEWEe/VZO1Qjefd0r/wkhgAE/AQQYT+roaZEhBHhofZd2g2B0RNAhEdv4gkijAiPv5dzhRB4AQE78ERVx61TvcdbRPgFhntylb07xZPb9/LqvuDZ0S9nTgMgMBYC2kKWbhmLOw/c4y4iPJae0H0d7s4wfhTtV5grwv/3//zvsFWHHwhA4OsSsINdUgLyiuMLMOz/znEYER5/30GEHeHoX//5r8n8+x/cvWH/n39P/tf//B+IsJsYCSEwTgKI8DjtWvKqEOEbNNNjDNOkdr5wl7cbDzWAb8neSlkQGBgBbzg6d5wRDsaagXWKRnMRiUz7ESbKBEc2CHwRArYwy84wv3bZGk/6RtxUnqJu//j73y7eMPZFEI/iMhHhTDMiwpngyAYBCFwQyFl7okI2v/w8+e7bbxDhAfcpRDjTeIhwJjiyQQACiDB94EQAEc7sDIhwJjiyQQACiDB9ABG+tw8gwvcSJD8EIGAECEd/3b6AJ5xpe0Q4ExzZIAABPGH6AJ7wvX0AEb6XIPkhAAE8YfoAnnBmH0CEM8GRDQIQwBOmD+AJ39sHEOF7CZIfAhAYuif8/v7+udvtrjpz2i+t61wul2/7/f5zOp3qhRZv6efXesJ2u/1cLBYvdxjV9s1mM1mv12dtaft8vV5/6nhStVsHsWivuE5P04/OD1+v14GB/n75hQ31NkSEh2o52g2B+ggMdWGWBObWu8UPh0MQYYmORPvj40OnfL2ln9+wiPK/XKt0rWp786Gj7XOdlLbdbid6ecdyuZxIvCXIx+MxCLnKkSiLycsvrL7bwdciRNjHiVQQgMBtAkMVYbX74+MjCKqO8pWXKy9P/0to5vN58ASNgARJx2zqOwmUfiTIEicTJn0mz1GiJW9ZefSd6lE6la+64ushTx5lSln5VL7SxXaEdrXlkyer75Q+bbfKkxcu0Yzt1N83RVgsdI2Hw+FNYqz8zQcVcVN9m80GEb59e7SnQIRzyZEPAhBoEhiqCE8mk+ClSmgVZpVg6n8JjwRPQmRjpYQpFWETN4mrPGSJqr6XOFn4VmWkIrxYLIKg2/cm5tPptOlQBvFWW+bzeUjfli966CehVn1ql9pt16S/j8djKENl3fKEFYqWlxs9/lBW094SapV1PB4R4dzhABHOJUc+CEBgjCIcBTQVnCDQ6ViZhqPTz6PHG/LK25VgyzuNHmQoJ/UwE886pNV8c4Ppp4RT4nwtn0RawmtzzkqrhwHVt1wuz8pWG+PDxVldzXC0HhTEwrzqK3Pm4boIR2eOB4hwJjiyQQACFwTG4Am3zJe6RVhhX4muLV6KoeAzEY7zz23s2s7OPs0j38on9hJiC1XHMPnZ/LUq7TEnHB4AzBtuE2E9aEikEeE7BgNE+A54ZIUABM4IfGURlteo0GycOw3ea+oxW8hbc7dKu9/vT85j9FzbnMmTCF/LJ+9W4p943bJLyGserXnJ9qBwLRzdTDOdTkNo2lZCm9FVr+aXt9stnnDuWIAI55IjHwQgMMZwtNcTtkVXNoYqJKx/EisJsOZUlUaeqYWjLbSshU76brVancLMbQufTEiNc1c+1al6JIbyTlV2nKt+k6DqmiSW8loV9tb/10R4tVqFcLbap7p1jXExV7g2faaHApWlz3V9hKMzxwNEOBMc2SAAgS8bjjaBjYufAgctzJJ4yRvVjwRZoiuvV3O98khtu48tkLKV2BJN5W/pUmfbmiR8JuwSUssn4bV5YX1u24nMe9U4n7YrrrjunBO2rUlaFW5tiivIg4ir/fqnMs3DRoQzBwREOBMc2SAAgTGJMNZ0EJDY23x3c7sSIuwA2JYEEc4ERzYIQAARpg+cCCDCmZ0BEc4ERzYIQAARpg8gwvf2AUT4XoLkhwAE0nnD337/Y7L88adeUDa//Dz57ttvuuZFe5VF4tcQwBPO5I4IZ4IjGwQgMChPWNtptBAqnhiFZhTuvwDNBIoIZ4IjGwQg0CrCv/7zX5P59z/0orP/z78n//j73x7uCWvVr1YG2xGQWlHcclRkr7aT+E8CiLCjJ+ikFD0Jpj/2t5add/3ou1tvGHFUTxIIQGDkBNrGGF2yd5xpjk+lcWllr7YJpT/aD6sxTsIc/0dPMsADzQFNXm/fp9RnPaE6mk8SCEBgoAS8ETdL96jLRIQfRRZP2EU250g5Fky40JIIAhC4QsArwo+GSDj6cYTxhB1sEWEHJJJAAALFCdQgwizMKm7WswIRYQdfRNgBiSQQgEBxAjWIcPGLokBEuG8fQIT7EiM9BCBQggAiXIJi3WXgCTvsgwg7IJEEAhAoTgARLo60ugIRYYdJEGEHJJJAAALFCSDCxZFWVyAi7DAJIuyARBIIQKA4AUS4ONLqCkSEHSZBhB2QSAIBCBQngAgXR1pdgYiwwySIsAMSSSAAgeIEEOHiSKsrEBF2mAQRdkAiCQQgUJwAIlwcaXUFIsIOkyDCDkgkgQAEihNAhIsjra5ARNhhEkTYAYkkEIBAcQKIcHGk1RWICDtMggg7IJEEAhAoTgARLo60ugIRYYdJEGEHJJJAAALFCSDCxZFWVyAi7DAJIuyARBIIQKA4AUS4ONLqCkSEHSZBhB2QSAIBCBQngAgXR1pdgYiwwySIsAMSSSAAgeIEEOHiSKsrEBF2mAQRdkAiCQQgUJwAIlwcaXUFIsIOkyDCDkgkgQAEihNAhIsjra5ARNhhEkTYAYkkEIBAcQKIcHGk1RWICDtMggg7IJEEAhAoTgARLo60ugIRYYdJEGEHJJJAAALFCSDCxZFWVyAi7DAJIuyARBIIQKA4AUS4ONLqCkSEHSZBhB2QSAIBCBQngAgXR1pdgYiwwySIsAMSSSAAgeIEEOHiSKsrEBF2mAQRdkAiCQQgUJwAIlwcaXUFIsIOkyDCDkgkgQAEihNAhIsjra5ARNhhEkTYAYkkEIBAcQKIcHGk1RWICDtMggg7IJEEAhAoTgARLo60ugIRYYdJEGEHJJJAAALFCSDCxZFWVyAi7DAJIuyARBIIQKA4AUS4ONLqCkSEHSZBhB2QSAIBCBQngAgXR1pdgYiwwySIsAMSSSAAgeIEEOHiSKsrEBF2mAQRdkAiCQQgUJwAIlwcaXUFIsIOkyDCDkgkgQAEihNAhIsjra5ARNhhEkTYAYkkEIBAcQKIcHGk1RWICDtMggg7IJEEAhAoTgARLo60ugIRYYdJEGEHJJJAAALFCSDCxZFWVyAi7DAJIuyARBIIQKA4AUS4ONLqCkSEHSZBhB2QSAIBCBQngAgXR1pdgYiwwySIsAMSSSAAgeIEEOHiSKsrEBF2mAQRdkAiCQQgUJwAIlwcaXUFIsIOkyDCDkgkgQAEihNAhIsjra5ARNhhEkTYAYkkEIBAcQKIcHGk1RWICDtMggg7IJEEAhAoTgARLo60ugIRYYdJEGEHJJJAAALFCSDCxZFWVyAi7DAJIuyARBIIQKA4AUS4ONLqCkSEHSZBhB2QSAIBCBQngAgXR1pdgYiwwySIsAMSSSAAgeIEEOHiSKsrEBF2mAQRdkAiCQQgUJwAIlwcaXUFIsIOkyDCDkgkgQAEihNAhIsjra5ARNhhEkTYAYkkEIBAcQKIcHGk1RWICDtMggg7IJEEAhAoTgARLo60ugIRYYdJEGEHJJJAAALFCSDCxZFWVyAi7DAJIuyARBIIQKA4AUS4ONLqCkSEHSZBhB2QSAIBCBQngAgXR1pdgYiwwySIsAMSSSAAgeIEEOHiSKsrEBF2mAQRdkAiCQQgUJwAIlwcaXUFFhHh9Xr9uV6vJ4fDYTKdTifL5XLy8fGh30P5+/3+U5/PZrO3zWbzqc+Wy2WRup9BFBF+BmXqgAAEmgQQ4fH3ibuFcLVafe52u8lms5nM5/O3w+HwKQHe7/f6F8p/f38Pn72/v5lO0LUAACAASURBVL8NsVMhwuO/EbhCCNRIYIjjZY0ca27TXSIswZ3P5+YBn5Ul4ZVHPJvNgmf8/v4evGOJ9fF4DB6zxFv5zWs+Ho/Bo9bnyqfP5T2rHon6drsNeZVGnz8LLCL8LNLUAwEIpAQQ4fH3h7uETKHl6AVflKPvJJqr1epChCWuElIJsL6XQK/X67fFYhFC1fpMoqt0CnHr95jGwt13tbuvWRHhvsRIDwEIlCCACJegWHcZd4nZtQ6y2+1CCHq32701w9ES1s1mE+q2dPKQJbSHw+HUpuVy+anP5BVHYb6rvbmmQIRzyZEPAhC4hwAifA+9YeS9S9SudZDtdmuh5QsRFpqPj48zEY5zxhfU7HMT9FdgRYRfQZ06IQABRHj8feAuEdaq58Vicea9GjJ5sTHc7BJhhac1d2yLuVSO5oI195t61a8wCSL8CurUCQEIIMLj7wN3ibDwKNSscLGFl/WZ5oMVPo5bloII6+/FYnGxOjoV2NlsFtKtVquwGEuhaIWpo+ccQtuvMAki/Arq1AkBCCDC4+8Dd4uaVjTLg7WVzhJeiXJceBXK1z5iiasEVd+3haMlsPKslU5lafW0flfYGk94/B2RK4QABC4JIMLj7xV3i7Ahkudqh3Vov/CY0OEJj8maXAsEhkMAER6OrXJbOiqxzIVwKx8ifIsQ30MAAo8ggAg/gmpdZSLCDnsgwg5IJIEABIoTQISLI62uQETYYRJE2AGJJBCAQHECiHBxpNUViAg7TIIIOyCRBAIQKE4AES6OtLoCByXCWomtxV/PXviFCFfXb2kQBL4EAUR4/GYelAhrC5O2Oemc6WeaBhF+Jm3qggAEjAAiPP6+cCZm8jT1sgTt822+pSh9J7Cw6G+90UivJ0wxdZVxrWztA1YZzbK6PvfUZ1umdGqXvdc415yIcC458kEAAvcQQITvoTeMvKfzm3UwhkRVAiwhjsdIhhOu9DYk+9FBGvGoynCghvLoe4WI7aQsCV9ahs6R1oEe9tpD5Tdvdj6fBwG2Hzu2su3z9NAOtUt12N5ktUvt0KlczXaonfEFEVkeNCI8jM5MKyEwNgKI8Ngsenk9JxHWEZESNYmpvFz9fTwegwhL4OzISJ1+FQXvdBqW/T2dTsN3VoadBZ1+Lo9YYmzvBk7fjrRarU7HXXZ9bi9ysIeDeLrWm9qlMtXOZjtUn9I1PW2veRFhLynSQQACJQkgwiVp1lnWmSecvjzBXj8o8dKPvfUofS1hcklBfNvedCTvVWKsf6k3LZGX0MbQd/heHrLC4BLqts+bnnDaLvtObWi2o6PNbosgwm5UJIQABAoSQIQLwqy0qLPXCaYvSHikCIuFRFieqeZu5cEqXCxP3DzWts+j6AZvt9k5EeFKexjNggAEsgkgwtnoBpPxJMLJPO/JE9V8q+aGU49TIWPNsZpnrPne6HkGr9benKQ8mteNc7Fnn6tjqT7NJ0t49dYkpbeyLTTe9nkajm7zhCXoaTvMq9bnhKMH0y9pKAQg8GcEMqyZsfEWKOMjcCbCEi+Jo4RT4WEZvtkJ5KFqjlXpbMGT0mtBlERUYmdvVRIuea3p5xJppdH/EmGVpfQqS4Jvb1Bq+1zpb4mw1WcLyKwuRHh8nZcrgsDYCSDCY7fwZHIWjjaP1kLFUUQvtg/Ju5TwShQloOl2JoWFJYAS9OVyeVqNbJ9LbKPohu8k6vbO4LSsts/1mcpWuc3tS+l3KlceurxsXYvNE+MJj79Dc4UQGBMBRHhM1my/ls454SFfuoXBtUpbYh1D31nbk2Io6PO33/+YLH/8yY1l88vPk+++/YYwkpsYCSEAgSYBRHj8fWKUIqx9wvJ+FfKWR64wt8LlueZkdXQuOfJBAAL3EECE76E3jLzZwjSMyyvTSkS4DEdKgQAE+hFAhPvxGmJqRNhhNUTYAYkkEIBAcQKIcHGk1RWICDtMggg7IJEEAhAoTgARLo60ugIRYYdJEGEHJJJAAALFCSDCxZFWVyAi7DAJIuyARBIIQKA4AUS4ONLqCkSEHSZBhB2QSAIBCBQngAgXR1pdgYiwwySIsAMSSSAAgeIEEOHiSKsrEBF2mAQRdkAiCQQgUJwAIlwcaXUFIsIOkyDCDkgkgQAEihNAhIsjra5ARNhhEkTYAYkkEIBAcQKIcHGk1RWICDtMggg7IJEEAhAoTgARLo60ugIRYYdJEGEHJJJAAALFCSDCxZFWVyAi7DAJIuyARBIIQKA4AUS4ONLqCkSEHSZBhB2QSAIBCBQngAgXR1pdgYiwwySIsAMSSSAAgeIEEOHiSKsrEBF2mAQRdkAiCQQgUJwAIlwcaXUFIsIOkyDCDkgkgQAEihNAhIsjra5ARNhhEkTYAYkkEIBAcQKIcHGk1RWICDtMggg7IJEEAhAoTgARLo60ugIRYYdJEGEHJJJAAALFCSDCxZFWVyAi7DAJIuyARBIIQKA4AUS4ONLqCkSEHSZBhB2QSAIBCBQngAgXR1pdgYiwwySIsAMSSSAAgeIEEOHiSKsrEBF2mAQRdkAiCQQgUJwAIlwcaXUFIsIOkyDCDkgkgQAEihNAhIsjra5ARNhhEkTYAYkkEIBAcQKIcHGk1RWICDtMggg7IJEEAhAoTgARLo60ugIRYYdJEGEHJJJAAALFCSDCxZFWVyAi7DAJIuyARBIIQKA4AUS4ONLqCkSEHSZBhB2QSAIBCBQngAgXR1pdgYiwwySIsAMSSSAAgeIEEOHiSKsrEBF2mAQRdkAiCQQgUJwAIlwcaXUFIsIOkyDCDkgkgQAEihNAhIsjra5ARNhhEkTYAYkkEIBAcQK1i/Bqtfrc7/dn1z2fzycfHx+T6XRaTF9Uz3K5nMzn82JlFjdWZoGju6BMDlezIcKPoEqZEIDALQK1i/D7+/vnYrGQOJ4uZb1eT47H42S32xXTF9UjYX9/fy9W5i32z/p+dBf0CHCI8COoUiYEIHCLwBBEuEMcPyeTSdCXw+EQBPRwOEhEJ6vV6uQlb7fbz81mE0R7NptNJODyoI/HY8gjL1t5drtd8K6bIrzZbD5Vrn2vhwGVob9VnvLMZrPQDtWl7/SjNiwWize1TWlV/3a7PWuD0u12u5BH38sTXy6XoSzZRQ8fKl/fWXld9VzjgAjfugsi8N9+/2Oy/PEnR+o/k2x++Xny3bffyEgwdlMjIQQgkBIYogiv1+sgXIfDIYiphFECJjGV4EbRfJPAScj02XQ6NQHW32/yfCWiyqeyJJASyxZPOISpzRuXGJrISsBN/CWUaofq0o/y6Hu1RXnt4aCtffHBIJQVhVdjemi76lM5+l9l6aetHl1fFwcEwnHP4wk7IJEEAhAoTmAIIixxTH8kaBIuzd/KU9X3ElZLM5vNwmfROzwJq9JKBPVPZUjE0zzx86ZmfUpg5T3Lq23mWy6X4TMJoERT7TIPWB6yPQgcj8eL9kXP++T9NsoPHrh52RYul9i21XONAyLsuG0QYQckkkAAAsUJDEGELUy83++Ddyiv1RZQqf36vvkjEZYwmicpb1Ker4WQlSedU74yJ3wKe0tQJbjNH5WliKQWd5knbEJp3nJbXTFf0/u2+k71qr60fW31SPy7OCDCjtsGEXZAIgkEIFCcwJBEWBevedcooME7VWhaHuN6vT5pjTxKeZDyUpVHQizRlogqrwQrhotPeebzeQhxt4Wjbe5ZDwHNfFZX9LpDvdbGuNraHgTO6pJYqy0x1H2a29aDQ/SaO0XY6kzrMa+/jQMi7LhtEGEHJJJAAALFCQxNhAVgsViEeWB5nxIk/S7vWAJq4V8Js80Tr1arkE7eqcK58koluvpe3ymUq9+75oRNhFW3Qt0SdSsznYe2BVt6OFAbLUxtabToSg8NEuD9fh/qtflotcvmm2NovVWE4wNHaGtaj81Zt3FAhB23zVBEuLlnz+YnbEXfrUvVk5vmS26lG/v3XRz0pK0bUSGzdI7rETw0AKhcr+1KteFV9fZt/1fpq0MUYS3G0j0SQ8zB87SFS7YCWuOMha/j3GqYS5VIaS7Y7rUovGEF8i1PWH0ozWfCaYtjNT7a6miJuu5hPRTE1dom8qf5bJUn/unqaFu9rYVZqfg3w9HNeixK0Mbhyw+4npt/KCLc3LOnjmuLC9IwSNs1Wyio5N4+D9va0lzjIL56ao5PtQ+9d141+L6q3ox+cDYIZuQfRJYB2WMQPJuNrGHce+hAMkirtDR6SCLc3EtnWwTivrnwhBm3D4TQj9JrPkbzM7bXTt5XV7oUj+2x02cK4dhJOfa0l+6d69orqPCPnkrtdB3VG7cNhKfUrj16tgLT6rZQkz63J19de9ueQWt3ui2ii4NdrzzEZLVk+FgPOba9wp6q72lvyjYdfO06TPy7uDT3TMqeXXsZu+xxbdDXdzHMduo3aks8mOG0pzPlb3s9dW1pf0j7V2qza3tKU1uoz9iCmy47N2/luEjoNOaJl+q2ecLmHlLl72qPXXdq/0eMd4jwI6j+VSYi/Fi+xUofsgjHwe+0585WH0ow49aBEP5JRVgDd1e6FKrN72hw1WAWxdQ245/24knsVJ6lS0/UsS0EFnZNtxSY0FredI9e3DgfQkcKeyXzS6Eelad5Hxv80z2D+l1l2f5CDaRi0eSQhoKbIqz0qttWW6ZbE+zhpm9720TYmMW9h+Hh6BYXm38St7a9jNf2LHYN+jY/ZrxtH6iF66ydUWjDg1C611MPVrYS1vpDfPAxcbYFOq17SlM2NkdoIqx6LPRodlF9LccmtoYQxanv3k677mS17UMcGkS42DDeWpA9kD972idtzEM6zmOxPb/0oYuw3cgaBKN3dFrtpwFIcxvpE6E8i650TRGWkNl+PtUT525C+TZPYifatO0VNHHUQgjVq8HUTqCJwn5qa7IH8LRHz+Z0lF912rWaKKd7DU3g7RCA9Dub47kVjrZIQ/Namw8TXXsKu9rbPNTFyretHMbuVj22ZzLaqXUv4zV7mKg026OIhebrbP+nrQBVO2XD7XZ7YacoluFz2dYeHpr1qyx9dq1dth8z6X9BUK/tDW0ZWFtFOGdvp53ydGua597RChG+l2D9+RFhh42GLsJakBC9szcLKdqxbvGUlzMRNjFTmma6pgin+/maA4aJsG3MTwf2dCHDdDoNA7nSaaDXgK7vm4cAxLrDaTW2KKIpmtYGDfhdewZj+LN5tm0os48IR05nDxyNLRQXewq72tsmwvEQ/OAh2vdeLibCbYtHbNqh2fXN3ul1WRqJqB5s7Gi/GA4O/aklfbhuOyYwPeDfTj5qqyOGiy/uyGurYtvsdUW4iu3tbOvTjqGkdxJEuDeywWVAhB0mG7oIa9m+Bj8NhvJkGqsML8QnDT0monKxEOaWoJjQ2vFwqddgbdJ8tD0kJGHiEEpO9+jJTMmev5sibOFm85DT/B1Ce5cIN9trWzOaewpvMbPuaB6mPK50pamXyzURbrNH6tl2ibC1TX3Joir6PY1+pCtjLcSrhx6Fhq/1B/U5ldO1p7TlNg32atsbqmhBPAji4nSlrhWtffd2PkscS9Vjc/BpdMkx9JHkCQQQYQfkoYpwuqhEq54VUozeZgj9aiCN4cfTUn2J1rV0OZ6wzbnZHrn0bFmVZwOpBmA7Pi7do6dQZOLBuzxheY5dewajyHR6wnHu8uLeSL335uDo3VPYR4RNDM2jlA29XK6JcNMe6d5NW5zU9MztYAWFxW2xX4xanB2Yb9s9bL5dgm+HNphwN+s329rivra9lG3zuxZ6T+1s12LbY9L+qoiL6tD2mLjFydYCnK7Bu7ezi5NjOOmV5B4Rlp1sCsFOpGpMwfRqC4kfQwARdnAdkginIdzGYqEweMpDtBWuca9c8JBtsU4UxbCgpy1dOjd3S1BS0Ur3CqZnyxp+DaRx0/ypT9riFw22jTw3PWGJSNeewWuesAlM9JzP7o9rIhwF8+aewlvMUk849Uht+5kOIfBwuSbCim507d3sGvSbfUehcmuL+o9513bgvsQs3Zep/pS+iaarP3S1q3mbKiIQ95Se1hDY1ImdD9zMY4vr0kViNsfftodU+ftycgwnF0nUJzqmXsI9qJ+2qRX73KJV6u9Kb1M79kIBq7D5ysGctnry8NIaD6W/0iDCDl5DEWHHpZAEAkUJ3OOpFW3IgAsTw1//+a/J/Psfel3F/j//nvzj7387rRdAhHvhqyYxIuwwBSLsgESSL0kAEb7f7Dnji2q99bpUwtH32+YZJSDCDso5N8mtG8RRLUkgUD0BhVJjWJSxJNNaOeOLR4TT5rAwK9M4T8jGjeOAnHOTIMIOsCSBAATC3vbffv9jsvzxp140GGN64ao2MSLsME3OTcIN4gBLEghAABH+4n0AEXZ0AETYAWngSTR/ptWk9jJyu5yuz72Xe2/+a/VoC5q+bzlNytu8u9PFF6mHlffGr2S7Hsnv7osvVEDO+NI3HF2oqRTzAAKIsANqzk2CJ+wAW1ESzZlpD6kOFJGIaE+rTu6694D3tNzSl1vJoqiLQ05Ktute/qWZP6K8nPEFEX6EJV5TJiLs4J5zkyDCf4LtWrgjD8cOEGh6chIu7SnVoQ7pd115rpXlMO9FknTgb/7ebFMzs2ehktLEfdkX959de+P4y3BaWHwpwclbvyV2XWUZr2Yddi1d+Trs0inC8Vzx8DL3lJPVr8+6rlMnXmmvMSLc3YMZY3Lu7vryIMIOmyDCDkgtSebzeQiXJoP76WQuE1k7SlOH7dsh/0ovkbKzpHXCkQ5akHeqwTnNo8MUNNjr8/gKxODNpvWmRz3G8Gk44MEOlLATnJJzsG3Fb3hdnr0dSm2yNza1Hdzfdb1Wbnp9sX67znAKmImWia0duWlvuLLjK+OBGF3nNoeXJehgBitHdelgC4XadSiK8bW3TRmrtH32WfOwiKZd2l58ofvFDtIwe8UXUZzZ8dZ1Ko+9E1unhaVvkHrlW2/y7obuXDnjC55waSu8rjxE2ME+ZzN9cyO9o5pRJWm+LUgnEtl7hnX6j8RMomADq46rlKAqJGxv5EmPa9SRgzaQp+cFp5+nxymmc7sS8PjaxiBcMewcji+UKMXXGAbB1WDf9H672psa7Nr1WrnpcaDKq4eD+C7eIMJqlz2M2LnL9jrCeHrZ6U1TOgO5yxNu1tP4O1xvmxfc1j4JfhjwO+zSJcJKnx5Zacel6kElHk8Zxh79rROu7HS3NI89VIlfPO88/D8mARYDRHhUQ1/vi0GEHcjajpW7dZycio1v8vmSjO0gf3ttYHxH8dkZ1YY+PQ5SYVc7BjF5U81JIJvCZ+8VTj239CXx+jx93Z3qksDpx959K4/zWgg6fVNUrOfiZRbXrtfyp9epchqh1s43/Fj41h4W7LzvLhFu1tNo80Xb2+zQvC3a7KIHli4RjuKS9v2zo0btmMso7qfjGZtHHoqRbKyHFfWh9HWYjlt3EEkQ4UGY6WGN/JICUYLmrfm4EnUMvQwN3ApLmleUimocwMMlmmjY2cISURNKe+1eixAGEWuKcNfDj3lgGsjVJstnb+25V4RN7K9db44IW6hcPMTFHmquecKlRdhC/k275IiwheztWiwq0fVqQJs+kP2VNp4PPapxCxEe+kh3X/tH1ZnvQ9EvNyJ8nZcGT3k7OuQ/ep1hMZIG32S+MoRXJSwWeozeachjL5K3d9jGOcRTGFODsspLP5dd4kH1Z33bQq1qg7wphbElbPaS+ntF+Nr12gNE+l7n6CmG0HAqZk2v1OZFbQ5aofj4gNIZjm7WIxFVG+Icc6cn3MynML5FJdrsck2Ek+sKD0vKL9bpG6ps+kB2jK9DPL3ZSg9wsqPydIXz+92x9aZGhOu1zTNahghnUkaEr4Oz9+naoiYNpiYoMTRt4cXglSoMaQt6TKTjYqIwMEsgzIM1r6n5ucTYFgQ1X30X3xdrQhDeVxxDouEeSEU4XQCkBwRPOPra9Vr+NI3qtFf3XRNhpRMPiZctsIpvx+kUYatH+eJDR6hLc+AWPm6zXls+8UwWyIUHntQuXeFom8MVPws56+HBPHlrl12T5qjlJduDWpwfDw9ZKX95+ekDQebtW1U2RLgqczy9MYhwJnJE+DY4Depx/jIIrbYbmdjFgfVi3lzelwZ6Ddbx1Yant8TY3HwcyE991z7XAB5Fv7Vfy2ZpO+I8Y0irtkpsbNGPtUPp08/Ng217XVvb9TbLtRC9ytF1xIeTIKhpmao/hmwDM3utpIXT7UElht8vrldepnmYds3X2m7W7MrXZRdrd3qdtk1LdtS/tP6UUbqC2xaKWT22nqLJz94UZBGW272w/hSIcP02emQLEeFMuohwHrivsO+zi4xC4jYHLbGTOElsxiQoeb3ia+dChL+2/RHhTPsjwnngvrIIm/AqnKufuN837FfOo0muMRBAhMdgxfxr4ObPZIcIZ4IjGwQgcEYAEf7aHQIRzrQ/IpwJjmwQgAAiTB84EUCEMzsDIpwJjmwQgAAiTB9AhO/tA48QYa38tK0dYzua717e5IfAWAkQjh6rZX3XhSd8g1PbkZXKcuvYSu+RlVqso4U6El97q9DhcMAuvv5LKggMngAiPHgT3nUBDPY38JV+eYPtc5Tg2lnAaRPiaU93GZXMEIDAcAhoHPiv//5/k/n3P/Rq9Fd/SUwvWBUnRoQdIvzb739Mlj/+5Dbjtfd8IsJujCSEwJcnUCri9uVBVgwAEX6yCDerIxxd8d1B0yDwYgKPWHvy4kui+gYBRPjFIpxWz8Is7k8IQCAlgAiPvz8gwhWJ8Pi7G1cIAQj0IYAI96E1zLSIMCI8zJ5LqyHwBQggwuM3MiKMCI+/l3OFEBgoAUR4oIbr0WxEGBHu0V1ICgEIPJMAIvxM2q+pCxFGhF/T86gVAhC4SQARvolo8AkQYUR48J2YC4DAWAkgwmO17F/XhQgjwuPv5VwhBAZKABEeqOF6NPspIvz+/v652+1Oddl5zB8fH286rOLj42Oy2Wwmx+NxMpvNJqvVSv+e0rZbrHLOdb12Ytat+vgeAhCAgBFAhMffF54ldJ+TyeRU13K5/JzP50Fo5/N5+F1CPJvN3nRgxXK5nOgFCOv1+lnt67Q0Ijz+m4ArhECtBBDhWi1Trl3PErkzEZ7NZvKMwwsM5AGnXrIuTd6xPOL4VqFntbGVKiJcrrNREgQg0I8AItyP1xBTP0vgTiIsT1dvCtLr+uQRy+Nte3du6i2/Eiwi/Er61A2Br00AER6//Z8uwuv1+vNwOIRQs+aKFYZ+f3+/aEctnQ8RHv9NwBVCoFYCtYyDtfIZQ7ueLsISXi28WiwWV0V4tVp9TqdTzRU/q42Eo8fQo7kGCIyIACI8ImN2XMqzBC6EozXXK2G1RVryijXvu9lsLtqheePtdjuZz+fPaiMiPP7+zhVCYFAEEOFBmSursc8SuCDC2+32UwuxttttqNcWYK3X67N5Yc0HK2TdXLCVdYV3ZiIcfSdAskMAAtkEEOFsdIPJ+FQRbltsZVuSbI+wPGMt3JIwT6fTZ7Wv02CI8GD6Mg2FwOgIIMKjM+nFBb1c5KxFEmMTYu0XrgU9IlyLJWgHBL4eAUR4/DavRuxqRY0I12oZ2gWB8RNAhMdvY0T4ho0R4fHfBFwhBGolgAjXaply7UKEEeFyvYmSIACBogQQ4aI4qywMEUaEq+yYNAoCEJjonATtLHn5eQnY4nEEBinC2tqkLUzP2ENMOPpxnY+SIQCB6wQQ4fH3kEGKsFZSa7/xM96yhAiP/ybgCiFQKwFEuFbLlGtXqwjL04xvMAqvF0yrkwDq1Cv73LYWNc9/7irjWtl6z7DqapbV9Xnarq5yD4eDec1Z+44R4XKdjZIgAIF+BBDhfryGmPpMYCV2Otc5PTjDTrNSZ9Axkvaj1xDGtyFJ3EIeO2Zys9mEcvSeYIm5laETs/SuYH2ucHI8lCO0Qe8Vboh95+dqp178oBO11C7VofLUDrVL7dDZ1M126Ht50G0vjOgyHiI8xG5NmyEwDgKI8DjseO0qLkRYrxaUqGm+VV6u/j4ej0Hs4juAQx6d+xwF7+Lv6XQavrMyJLz7/f4t/Vyeq8RYgikBl2grjcrWyxv0t4S16/NUhFWG6tMJW2pX/PusPl2L6lM6RHj8HZsrhMAYCCDCY7Di9Wto9YRNDGNo2LzOUJK91ajjNYRBfE0g06rlvUqM9S/1piXyEtrZbBb+6Xt5yAp329nSzc+bnnDaLvtObWi249qrE/GEx9/ZuUIIDI0AIjw0i/Vv74UIdwmXxLW0CEeRD56p5m7lwSpcLE/cPNa2z2M7TuFoRLi/4ckBAQjUTwARrt9G97bwQoSTed6TJ6qwsOZ1U7Frvu9X871RwINHG+doT/O6cS727HN1MNWncLSEd7VancLRmr+10Hjb52k4uk2EJehpO8yr1ueEo+/tNuSHAASeQQARfgbl19bRKsISL4mjhFPhYYWgm51BHqrmWJXOFjwpvRZESaAldsprHrQWUaWfS6SVRv9LhFWW0qssCX6c4239XOlvibDVZwvIrC5E+LUdjtohAAE/AUTYz2qoKVvD0ebRyhM1r7Ftm5C8SwmvRFECmm5nUnoJYJzPPdVjn0tso+iG7yTqKks/aVltn+szlb1cLt+a7Uq/U1ny0OVl61psnhhPeKjdlXZD4GsRQITHb++bc8JDRqBtTxJ2rdKWWMfQd68DStiiNOQeQNshMGwCiPCw7edp/ahFWPuE5f0q5C2PXGFuhcs9YCwNItyHFmkhAIGSBBDhkjTrLKuXINV5CY9tFSL8WL6UDgEIdBNAhMffOxDhGzZGhMd/E3CFEKiVACJcq2XKtQsRRoTL9SZKggAEihJAhIvirLIwRBgRrrJj0igIQID3CX+FPoAII8JfoZ9zjRAYJAE84UGarVejEWFEuFeHITEEIPA8Aojw81i/qiZEGBF+Vd+jXghAwDH+KIm9OAdgrbhAaQAAAX9JREFU4yOACDtugt9+/2Oy/PEnt/U3v/w8+e7bb7hx3MRICAEItBHAEx5/v0CEEeHx93KuEAIDJYAID9RwPZqNCCPCPboLSSEAgWcSQISfSfs1dSHCDhH+9Z//msy//8Ftof1//j35x9//RjjaTYyEEIAA4eiv2QcQ4Rt2t7c+NZPZKxr1dqa2n/QNVF+za3HVEIDAvQTwhO8lWH9+RDjTRtwcmeDIBgEIuAkwzrhRDTYhIpxpOm6OTHBkgwAE3AQYZ9yoBpsQEc40HTdHJjiyQQACbgKMM25Ug02ICGeajpsjExzZIAABNwHGGTeqwSZEhDNNx82RCY5sEICAmwDjjBvVYBMiwpmm4+bIBEc2CEDATYBxxo1qsAkR4UzTcXNkgiMbBCDgJsA440Y12ISIcKbpuDkywZENAhBwE2CccaMabEJEONN03ByZ4MgGAQi4CTDOuFENNiEiPFjT0XAIQGDsBBDhsVt4MkGEx29jrhACEBgoAUR4oIbr0ez/DwAuXZWLyS0hAAAAAElFTkSuQmCC

