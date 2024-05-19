---
layout: post
title: C++核心知识点总结
description: ""
date: 2014-09-07 08:00:00 +0800
categories: ["过去的学习笔记"]
tags: ["unix","linux","programming","c","cpp"]
toc: true
reward: true
---

迁移自 hitzhangjie/Study 项目下的内容，本文主要总结的是C++编程里的一些知识要点。

```
=============================================================================
Sun Sep  7 16:50:05 CST 2014
=============================================================================

为了开启c++11的某些特性，需要在g++编译时添加参数：-std=c++0x。

c++语言里面，除了char类型被明确规定为占1个字节之外，其他的数据类型都没有指定其
具体的尺寸，这样做的原因是，在不同的编译器实现中，编译器会根据运行平台的特点，
自动为各个类型指定所占用的字节数，以使得编译后的程序能够尽可能适应运行平台。这
样做的好处是，使得编写的c++程序，不仅能够适应现在的机器结构，也能适应将来的机
器结构，实在是高明！

c++11标准中变量的初始化方式有3种，这3中初始化方式是等价的：
type varname = varvalue;
type varname (varvalue);
type varname {varvalue};

auto varname = varvalue;
变量auto会根据初始化时初值varvalue的类新，自动指定varname的类型；

decltype(varname)可以获取变量varname的类型，例如可以这样使用：
newvar；
这样变量newvar与新变量oldvar是相同的类型，decltype主要是用于模板中根据模板参数
的类型创建其他相同变量。

c++中有专门的字符串类string，需要包含头文件string。

cout输出时追加endl的作用不仅仅是输出换行符，考虑一下缓冲机制就明白了，在终端中
，缓冲一般是采用行缓冲，因此在cout中追加endl不仅输出了换行符，还进行了行缓冲，
从而确保信息被输出到cout上。
如果在通过cout输出某些信息时不在末尾追加endl，如果输出信息中没有换行符做结尾，
那么信息就不会输出到终端上，因为终端采用行缓冲，不碰到换行符或者待输出信息没有
超过缓冲区的长度，信息不会被输出到终端上。

std::cout，std是一个命名空间，c++标准库中的所有东西都包含在std这个命名空间中，
cout指定了设备是输出设备，c++中常用的cin\cout\cerr就等效于c中的
stdin\stdout\stderr。

常量类型
整型常量，常用的包括十进制、八进制、十六进制，分别如123,0234,0xffff；整型常量
可以在末尾追加合适的字符表示该常量应该用什么类型进行存储：
u/U表示unsigned；
l/L表示long；
ll/LL表示long long；

浮点常量，常用的包括float、double、long double，浮点常量的形式包括3.1415、
3.14e23，其中e表示10的多少次方，浮点常量默认是用一个double类型进行存储，也可以
在浮点常量的末尾追加字符表示使用什么类型进行存储，例如：
f/F表示float类型；
l/L表示long double类型；
什么都不加，即采用默认的double类型；
在c++ shell中的测试结果显示，double表示8字节，long double表示16字节，这个跟编
译器有关。

字符常量、字符串常量'x',"xxxxx"，注意一些特殊的转义字符，例如：
\n    newline
\r    carriage return
\t    tab
\v    vertical tab
\b    backspace
\f    form feed (page feed)
\a    alert (beep)
\'    single quote (')
\"    double quote (")
\?    question mark (?)
\\    backslash (\)
转义字符的输出还可以通过\后加八进制数字或者十六进制数字的形式进行，八进制数字
直接加在\后面，十六进制数字需要在\后面加个x，然后再加上对应的十六进制数字，如
下： 
\77
\xff
常量字符也可以在后面追加字母表示类型，例如：
u表示char16_t，
U表示char32_t，
L表示wchar_t，
什么都不加表示char。
此外常量字符串前面还可以追加前缀，例如：
u8,u8"hello world"，u8表示后面的字符串采用utf8编码，解码的时候怎么指定编码？；
R,R"hello'''\xxx"，R表示后面的字符串是原始字符串，没看懂什么意思；

其他常量类型：true、false、nullptr。

通过const指定常量，通过预处理指令#define、#undef定义、取消定义常量。

cin\cout\cerr\clog，其中clog是日志流，其他3个跟c中的类似。

<sstream>中的stringstream允许将一个string对象当作一个流，然后从这样的流中读取
、插入指定类型的数据，这就类似于c语言里面的sscanf、sprintf。

string a = "1111";
int b;
stringstream(a)>>b;

cin类似于scanf，cout、cerr、clog类似于printf(stdin/stderr, "xxx", xxx)。

=============================================================================
Mon Sep  8 01:48:59 CST 2014
=============================================================================

内联函数只是告诉编译器建议采用内联的形式，但是只是建议，具体是不是内敛要看编译
器的具体实现。

函数原型声明中只需要包含函数名称以及参数类型即可，不必指明参数名称以及具体的函
数实现。

通过模板参数来定义类和函数，可以适用于多种类型，增强适应性。模板参数的声明形式
为：
    template <class T1, class T2, ..., class T3>
{
        return (T3)xxx;
    }
上面只是举了一个简单的例子，注意模板参数中的class可以用typename代替。

命名空间的使用实例。
1）定义一个命名空间：
    namespace my 
    {
        int a,b;
    }
2）使用一个命名空间：方式1是通过{using namespace my; cout<<a<<b;}，方式2是通过
cout<<my::a<<my::b；

3）命名空间可以创建别名，例如namespace aliasname  == oldname;

数组c++提供了一个library array, array<int,3> a {1,2,3}。

char * str = "helloworld";
str[0] = 'A';
因为helloworld是存放在常量存储区中的，str只是指向了这个常量存储区中的地址，其
中的内容是不允许被修改的，因此str[0]被赋值的时候，会报段错误；

char str[20] = "helloworld";
str[0] = 'A';
因为helloworld是存放在str[20]中的，str这个数组是在栈中被创建的，因此是可以被修
改的，后面的str[0]被赋值是合法操作；

c风格的字符串与c++中string字符串类是可以相互转换的，例如将c风格的转换成string：
char * str = "helloworld";
string s = str;

将string字符串对象转换成c风格字符串：
string s = "helloworld";
const char * str = s.c_str();

=============================================================================
Tue Sep  9 00:37:56 CST 2014
=============================================================================

关于const修饰的是指针还是值的问题，请参见如下形式：
          int x;
          int *       p1 = &x;  // non-const pointer to non-const int
    const int *       p2 = &x;  // non-const pointer to const int
          int * const p3 = &x;  // const pointer to non-const int
    const int * const p4 = &x;  // const pointer to const int 
可见const仅仅紧跟在其后的类型进行修饰。

void类型表示没有类型或者没有指定类型，void*类型就可以指向任何数据类型，但是在
对数据进行类型转换时，必须明确地知道数据的类型，然后进行强制类型转换。

type (*funcPtr)(type,type,type...)，定义了一个函数指针funcPtr，例如：
{
    return a+b;
}

{
= add;
    int result = myadd(1,2);
}
        
pointer = new type
pointer = new type [number]

delete pointer
delete [] pointer

c++中通过new来申请内存的时候，内存如果申请失败该如何处理呢？c++语言提供了几种
处理方式，如果内存申请失败，会抛出bad_alloc异常，如果这个异常没有被捕获，则程
序会被强制终止；如果该异常通过try-catch捕获，则不会终止程序，而是从catch开始执
行；通过在new语句中加入（nothrow）来阻止抛出异常，而将new返回的结果设为nullptr
，这样程序也会继续向后执行。
关于异常、nothrow两种方式对内存分配失败的处理，nothrow效率要低一些，因为这种机
制对内存分配进行显示地检查，不管成功还是失败，而异常机制则只是在申请内存失败的
时候才会触发，因此捕获异常这种机制的效率要更高些，但是nothrow相对来说要简洁些
。

需要特别强调的是，c++虽然支持c中的malloc、calloc、realloc、free方法，但是
malloc等申请得到的内存块与new返回的内存块并不兼容，因此不应混用，例如malloc出
来的内存块必须用free释放，而不能用delete释放。

c++中定义类型可以通过struct、typedef、using，其中struct允许嵌套，typedef举例：
typedef char C;
typedef unsigned int WORD;
typedef char * pChar;
typedef char field [50];        // field == char[50]

using new_type_name = existing_type;举例：
using C = char;
using WORD = unsigned int;
using pChar = char *;
using field = char [50];

struct\union

enum\enum class\enum struct

c++中类访问修饰符：
private：可以被当前类、friend类访问；
protected：可以被当前类、friend类、派生类访问；
public：可以被当前类、friend类、派生类、非派生类访问；

定义类的时候，可以把类的成员函数的实现在类体中定义，也可以在类体外面定义，两种
方式的区别是，在类体内部定义的成员函数会被自动当成inline函数,而在类体外定义的
则不被当作inline函数，这对编译器对代码进行优化时有影响。

关于如何调用构造函数：
new func(x,y,z);    // 传统函数式
new func = x;        // 如果构造函数只包含一个参数
new func {x,y,z};    // c++11中引入的统一式

对成员进行初始化可以在构造函数中进行，也可以在成员初始化器中进行。两者有所区别
，在对基本数据类型进行初始化的时候，通过构造函数和成员初始化器这两种方式并没有
多大区别，但是当类定义中有一个类对象作为成员时，假如不在成员初始化器中对其进行
初始化，就会调用它的默认构造函数完成初始化，因此成员对象如果需要特别的初始化操
作一般要放在成员初始化器中进行。

c++中也可以用struct定义类似类的结构，其中也可以定义各种成员函数，但是struct中
所有的成员默认都是public。
至于union的话，自己搜索下吧。

=============================================================================
Wed Sep 10 17:49:15 CST 2014
=============================================================================

传参数、返回返回值，实际上都是创建了值的一份拷贝，不管是不是传引用、指针，即便
是引用、指针，也是引用、指针值的一份拷贝，
一般返回值都是放在eax寄存器里，但是有的时候eax寄存器装不下了，就得往其他地方放，
对于大结构体、对象的返回值我确实没有研究过，不过我想返回的时候可能是在栈上创建
了一个临时变量，然后将变量的值搬到另一个接收返回值的变量中。如果没有变量接收返
回值呢，这样想的话，一定有某个中间的临时位置用于存储这个返回值。需要研究下。

经过测试，不管是什么类型，只要返回值足够eax寄存器装下，那么就会将返回值存在eax
寄存器中，如果返回值超出了eax寄存器的位宽呢？
编译器是这么做的，假定有如下代码：
struct num {
    long long a;
    long long b;
};
typedef num NUM;

{
    NUM res;
    res.a = a.a+b.a;
    res.b = a.b +b.b;
    return res;
}

{
    NUM a,b;
    a.a=100; a.b=100;
    b.a=200; b.b=300;
    
    NUM c = add(a,b);
}
看这段简单的代码，首先编译器知道了返回值要往c这个地方存储，并且也知道了NUM类型
的返回值超过了寄存器的位宽，不可能保存在eax寄存器中。

这个时候，编译器会在栈中为c分配好空间，然后将变量c的内存单元地址存储到rdi这个
基地变址寄存器中，然后开始调用add。

add进入函数体后，将调用者传递过来的rdi寄存器的值，存储到当前函数所在栈帧中的某
个位置，然后开始根据调用者传递过来的参数进行运算，并将运算结果存储到当前栈帧中
的NUM res中。当return语句被执行时，从存储了rdi寄存器值的那个内存区域取回其中的
值，这个值就是返回值所要存储到的位置，然后根据该值及一系列的mov指令将运算结果
写入目标返回位置。此时执行完成时，对应的c=add(a,b)这条语句的赋值也就完成了。

如果只是调用add(a,b)则在add调用开始之前，也需要调用者通过rdi寄存器通知add将结
果存储到哪个位置，此时这个存储位置是调用者在其所在栈上创建的一个位置。

ok! 现在把函数返回值的存储问题解决了！

上面的问题解决了之后，又学到了新的知识，哈哈，幸亏我想不通了就会google！

之前我学习linux编程基本上是在笔记本thinkpad x61t上进行的，当时我在做反汇编的时
候发现所有的寄存器类型不外乎al,ah,ax,eax（现在明白了因为当时的cpu是L7500，应该
是32位运算能力），当时我了解ax包括了ah、al，但是我不清楚eax跟它们的区别，由于
看汇编计算字节偏移量时我只考虑了变量在内存中的开始位置，没有考虑结束位置，因此
当时寄存器位宽这个问题，没有影响到我做实验，但是今天发现了汇编代码中出现了rax
寄存器，而且发现每次移动struct结构体中的成员时，偏移量是8字节，我才想起这个问
题，会不会是cpu寄存器位宽、数据总线宽度的问题，google了下，寄存器AT&T汇编中代
码及其对应的位宽如下：

|63..32|31..16|15-8|7-0|
              |AH. |AL.|
              |AX......|
       |EAX............|
|RAX...................|

看完这些就明白其中的原因了！

=============================================================================
Thu Sep 11 17:13:53 CST 2014
=============================================================================

c++中定义的类本质上是在c++中定义了一种新的数据类型。

c++中规定了一些允许重载的运算符，汇总如下：
+    -    *    /    =    <    >    +=   -=   *=   /=   <<   >>
<<=  >>=  ==   !=   <=   >=   ++   --   %    &    ^    !    |
  ,    ->*  ->   new 
delete    new[]     delete[]

运算符重载的格式为：
type operator sign (params);
例如:
{
    ....
    return (Obj)objx;
}
当重载完成之后，可以隐式地调用+这个函数，也可以显示的调用+这个函数，其形式分别
为：
c = a+b;
c = a.operator+(b);
上述两种方法是等效的。

注意二元运算符重载的时候，默认第一操作数（左侧的操作数）为当前运算符函数的调用
者，例如a.operator+(b)中+的第一操作数即为a。
二元运算符在重载的时候参数列表中只允许有一个参数，此时如果想用两个参数，可以使
之成为友元函数；另外如果二元运算符两侧的操作数类型不一样，需要特别注意，调用的
时候应该注意调用顺序。

不同的运算符重载的时候的格式，汇总如下：
Expression    Operator                                        Member function            Non-member function
           operator@(A)
       operator@(A,int)
           operator@(A,B)
           -
   -
           -
       -

c++类模板，形式大致如下：
template <class T>
class Obj {
    T ...
    T ...
    T func(T t1, T t2, ...);
}
指定类模板参数时除了可以使用class T，也可以使用typename T来代替。

如果已经有了个类被声明为类模板，在此基础上我们可以实现自己的一个模板特例，例如：
template <class T> class mycontainer { ... };
template <> class mycontainer <char> { ... };
我们定义了一个模板类mycontainer，如果有需要，在此基础上，我们可以实现一个模板
特例，即template <> class mycontainer <char> {...};

c++类中特殊的成员函数，有6个，整理成5条，我们将移动构造、赋值函数放在5）中进行
描述，好的，下面以类Ex为例:

1）默认构造函数 Ex::Ex()
如果没有显示地为类定义一个构造函数，那么c++编译器会默认为其创建一个不带任何参
数的构造函数，这个构造函数就称为默认构造函数；
当显示地为该类指定了一个构造函数时，那么c++编译器便不再为该类隐式地创建默认构
造函数； 

2）析构函数 Ex::~Ex()
在析构函数里面执行一些与构造函数功能相反的任务，例如在构造函数中申请了内存，在
类对象声明周期结束的时候，析构函数被自动调用，析构函数里面可以实现资源的回收及
释放等清理工作； 

3）拷贝构造函数 Ex::Ex(const Ex&)/Ex::operator= (const Ex&)
注意原型中参数Ex&表示的是某个对象的引用！参数类型需要与当前对象类型一致！
假如有如下代码:
Ex d;
Ex e(d);
如果没有显示地创建一个拷贝构造函数，那么c++编译器会提供一个默认的拷贝构造函数
，这个默认的拷贝构造函数的实现只是简单的拷贝对象d中的成员的值到e中，而且拷贝是
浅拷贝，所谓浅拷贝指的是，没有考虑指针指向的内存区域，例如d中有一个指针ptr指向
一段内存区域，执行完默认的拷贝构造函数（浅拷贝）之后，d、e中的ptr的值是相同的
，假如ptr指向的内存是动态分配的，并且d这个对象生命周期结束的时候释放了这段内存
，那么e中ptr这个指针就变成了无效指针，它指向了一段无效的内存区域，继续访问这段
内存区域的话将引起难以预料的后果。

如果涉及到动态内存分配，并且对象里面包含了这样的指针的话，应该考虑提供自己定义
的拷贝构造函数，实现深拷贝，从而避免上述情况。实现方法也很简单，比如在自定义的
拷贝构造函数内部，首先申请一段新的内存区域，然后再将这段内存区域的地址赋值给成
员ptr，这样就实现了深拷贝，不会出现之前提到的浅拷贝引发的内存访问问题。

4）拷贝赋值函数 Ex& Ex::operator= (const Ex&)
参数类型需要与当前对象类型一致！
c++中对象的拷贝动作不仅仅是在构造的时候才会发生，当对象已经构造完成，在之后的
有效声明周期过程中，也可以通过拷贝赋值函数完成拷贝对象的动作，注意c++11中引入
的调用构造函数的3中方式： 
T t;
T t(...);
T{...};
上述3中方式都是调用构造函数的方式，但是拷贝构造函数只有如下两种原型形式：
T t1;
T t2 = t1;    调用拷贝构造函数
T t3(t1);    调用拷贝构造函数
t2 = t1;    调用拷贝赋值函数
需要注意上述几种形式的发生时间以及原型的区别。

|| 移动赋值函数 Ex& Ex::operator= (Ex&&)
注意，移动构造函数、移动赋值函数中，其参数类型与当前对象类型一致！

移动的意思主要是针对动态分配的内存区域，将参数对象中指向动态分配的内存的指针赋
值给目的对象，并将原对象中的指针设置为nullptr。在考虑尽量节省资源的需求下，可
以考虑使用。
那么c++为什么要提供这种移动构造函数呢？算是另一种形式的垃圾回收吧！？！
在c++的世界里，所有的动态分配的内存都需要程序员自行管理，不像java里面那样有gc
可以自动帮你把没有被引用的内存区域进行释放完成内存回收，举例来看，在java中假如
有这样一段代码：
ArrayList a = new ArrayList();
a = new ArrayList();
上述代码中，在执行第二行代码a = new ArrayList()时，a指向了新的内存区域，但是第
一次申请的内存此时没有变量引用它，因此它的引用计数为0，当gc进行垃圾回收时会回
收这样的内存，因此不需要程序员自己管理垃圾的释放、内存的回收，减轻了程序员的压
力。但是gc也占用资源，而且回收不及时，对系统性能影响也比较大。
我们来看看c++中是如何对内存进行更有效的管理的，通常程序员在堆上申请了内存之后
，例如new了之后，必须通过delete显示地加以释放该内存区域，否则该内存不会被回收
，程序员不得不认真考虑内存的占用问题，一定程度上，受此影响，程序员也对资源、性
能、垃圾回收的概念比较清晰、谨慎。
此外，需要注意的是，有的时候，在c++中，某些在堆上创建的匿名对象我们是无法去显
示的释放的，例如有一段代码：
new Ex();
上面这行代码创建了一个对象，但是没有变量指向这个对象，我们是无法显示地通过
delete释放其所占用的堆内存的，在c++中应该尽力避免这样的情况，但是有的时候无法
避免这种情况。

上面说了这么多，还没有说到移动构造函数、移动赋值函数诞生的原因，这两个特殊的函
数参数都必须是匿名对象，我们看个例子。
class Ex {
    string * ptr;
{
        ptr = new string(param);
    }
{
        this.ptr = t.ptr;
        t.ptr = nullptr;
    }
{
        this.ptr = t.ptr;
        t.ptr = nullptr;
    }
}
Ex a(Ex("xxx"));
代码中首先首先创建了一个对象Ex("xxx")不过它是匿名对象，虽然创建的这个匿名对象
是一个局部变量 在参数列表中创建的），但是这个变量内部包含了一个指向堆内存的指
针，并且这段内存没有被在析构时释 ，这样这段内存会被泄漏，现在我通过移动构造函
数，将这段ptr指向的差点泄漏的内存为新变量Ex a所使用，即通过移动构造函数将匿名
对象中的ptr的值移动到对象a中，这样不仅没有造成内存泄漏，还巧妙的进行了对象a的
初始化操作。参见Ex::Ex(Ex&& t)定义。
移动构造函数与之类似，只不过是在对象构建之后继续操作，例如调用如下代码：
Ex a("hello");
a = Ex("hello world");
第二行就是执行的移动赋值函数，参见Ex::operator=函数定义。

但是经过测试，我发现移动赋值函数成功执行了，但是移动构造函数没有执行,可能是编
译器的原因。因为“移动”的支持是c++11中才引入的。

这里顺便讲一下运算符&和&&的区别：
&：引用运算符，比如这样使用： int a = 100; int &b = a;我们定义了一个a的引用b，
或者说b是a的引用。因为&b = a，a是a=100这条语句的左值，所以说&运算符称为左值引
用或者简称为引用。
&&: 右值引用运算符，比如这样使用:
	class Ex {...};
	Ex a;				// default constructor
	Ex &b = a;			// 创建了一个a对象的引用b
	Ex &&c = a;			// invalid, 因为a是一个左值，第一条语句相当于Ex a = Ex();
	Ex && p = Ex();		// valid， &&引用的是右值，右边的Ex()没有被任何左值变量所记录
说明了什么呢？&&做右值引用的时候，赋值运算符右边创建按的临时对象，不能被任何变
量所引用，也就是说匿名对象，而移动构造函数、移动赋值函数，也正是为了解决匿名对
象的清理才引入的。
	

简单总结一下：

c++中类的6种特殊的默认成员函数：
成员函数名称                成员函数原型
Default constructor            C::C();
Destructor                    C::~C();
Copy constructor            C::C (const C&);
Copy assignment                C& operator= (const C&);
Move constructor            C::C (C&&);
Move assignment                C& operator= (C&&);

上面提到的这6个成员函数都是由c++隐式定义的，下面说一下这些隐式定义会执行哪些操
作：

隐式成员函数名称        条件                                                                    操作
Default constructor        if no other constructors                                                does nothing
Destructor                if no destructor                                                        does nothing
Copy constructor        if no move constructor and no move assignment                            copies all members
Copy assignment            if no move constructor and no move assignment                            copies all members
Move constructor        if no destructor, no copy constructor and no copy nor move assignment    moves all members
Move assignment            if no destructor, no copy constructor and no copy nor move assignment    moves all members

这6个隐式的成员函数，默认都是被开启的，我们可以选择开启或者禁用其中的某个或者
全部，显示开启或关闭的方法，很简单，只要按照如下格式在类声明中注明就可以了：
function_declaration = default;
function_declaration = delete;
举个例子:
class C {
    // 表明该原型将使用c++提供的默认构造函数
= default;
    // 表明该原型（拷贝构造函数）被禁用，即不使用拷贝构造函数（默认的拷贝构造
    // 函数也一并被禁用了）
= delete;    
}

=============================================================================
Sat Sep 13 00:13:16 CST 2014
=============================================================================
c++中，在类A中通过friend修饰的函数或者类不是A的成员，他可以直接访问A的private
修饰的数据。

类继承：
class A : public B {
};
A继承自B，B前面有访问修饰符，继承时的访问修饰符规定：
B中的成员的访问修饰符级别如果比继承时的访问修饰符更加严格，那么A继承B之后，对A
来讲，B中的成员的访问级别保持不变；
如果B中的成员的访问级别比继承时的访问级别要更加宽松或者相等，那么A继承B之后，
对A来讲，B中对应的成员的访问级别由继承时的访问修饰符来修饰。
继承时的访问修饰符的目的，其实还是为了对成员的访问进行限制，继承时的访问修饰符
不会使被继承成员的访问更加宽松，而是使其访问级别变得更加严格或者保持不变。例如
，如果继承时的修饰符是private，那么对A来讲，B中所有成员的访问修饰符将被限定为
private，从A中将无法访问B中的任何成员。

Access                                public        protected    private
members of the same class            yes            yes            yes
members of derived class            yes            yes            no
not members                            yes            no            no

类继承的时候，派生类会继承基类的成员，但是不包括下面这些成员：
its constructors and its destructor
its assignment operator members (operator=)
its friends
its private members

多重继承，class A : public B, protected C, ... {};

声明引用MyClass &obj2 = obj; 这样声明了一个引用obj2，它引用了obj这个对象，
MyClass *ptr = &obj;则是创建了一个指向对象obj的指针，注意引用、指针声明方式的
区别。

c++中多态实现方式，简单地说是：指针+虚函数+类继承。
首先，要实现多态，必须有个基类，然后定义几个派生类。然后需要创建几个基类指针，
让基类指针指向派生类对象。然后通过基类指针去调用期望的成员函数，实现多态。这里
要想让其表现出多态的特征，必须在基类中用virtual定义虚函数（虚函数可以由派生类
重新定义），然后派生类重新定义虚函数。这样通过指向派生类对象的基类指针去调用这
些虚函数时，就会根据指针指向的对象类型，自动调用目标对象中的这些成员函数。这样
就实现了多态。
注意，基类指针，可以访问到的成员函数，与其指向的对象类型无关，只与基类自身有关
，基类中定义了什么，它就可以访问到什么，基类中如果没有定义，就算是派生类中定义
了，它也是访问不到的，就相当于已经将派生类对象进行了强制类型转换，向上转换成了
基类而将自己添加的部分丢弃了一样。
虚函数可以有函数定义，没有函数定义的函数就变成了纯虚函数，其语法是type
= 0;即将函数定义部分用“=0;"替换。
包含纯虚函数的类就是抽象类（在java中，抽象类要通过abstract关键字指明），抽象类
不能用来实例化对象，只适合用来做基类，然后创建它的派生类对象。但是抽象类也不是
完全没有用的，作为基类是一个不错的选择，另外，它也可以用于创建指向派生类对象的
基类指针，然后使用c++中多态的一切特征。
类型转换：
1）基本数据类型的类型转换：
基本类型的隐式类型转换，例如从short a=2000; int b=a;这里就b=a就发生了short向
int的饮食类型转换。对于c++中的基本数据类型，从精度较低的转换为精度较高的类型时
，由于不会发生数据丢失，所以一般会自动地进行类型转换，不需要编码中显示指明，因
此称之为隐式类型转换。
但是当基本数据类型从精度较高的转换为精度较低的类型时，由于有可能发生数据丢失，
一般情况下，编译器会报warning而不是错误，一般在编码时需要显示指明类型转换，我
们称之为强制类型转换。
2）类的类型转换：
类之间也可以发生类型转换，但是试想一下，类有不是简单的数据类型，它还包括成员函
数，怎么能实现类型的转换呢？更不用说也是类型转换了！对，那么它一定是通过某种诡
辩术实现了这一类型转换，总结一下，类之间的饮食类型转换，主要通过3个成员函数进
行：
[single-argument constructor]：允许用一个特定的类型来初始化另一个类型，例如有
两个类A、B，B中定义一个构造函数来完成利用对象A a对B对象的初始化：
class B {
{...};
};
A a; B b(a);
注意这里的构造函数只是一个普通的构造函数，我们之前提到的拷贝构造函数、拷贝赋值
函数、移动构造函数、移动赋值函数这几个特殊的成员函数，其参数类型与当前类类型都
是一致的。
[assignment operator]：通过这个赋值运算符，完成类型的转换。这里需要重载运算符=
，例如还是两个类A、B，B希望能够实现在赋值时将对象A隐式转换成对象B，可以这样实
现：

class B {
{....}
};
A a; B b; b=a;
注意这里重载了赋值运算符，
[type-cast operator]：通过类型转换运算符，完成类型的转换。这里需要重载运算符()
，例如还是两个类A、B，B希望能够被强制类型转换成类A对象，这可以这样实现：
class B {
{return A()}
};
A a; B b;
a = b;
a=b;这行代码表示B类对象b需要被隐式转换成A类对象，因此会调用b.A()方法转换成A类
对象。

关于运算符重载，请仔细查看c++中运算符重载规则，有的运算符重载时有返回值，有的
则没有返回值，需要注意。另外，运算符重载的时候，应保持其实现与其语义相一致。

c++中在函数调用的时候，会检查传递给函数的参数类型，如果类型不匹配，例如传递的
实参的类型为A，并且期望的参数类型B中提供了一个合适的隐式类型转换函数，能够将A
转换成B，那么就会发生隐式类型转换。如果我们不希望这种隐式类型转换的发生，可以
在B中的对应类型转换函数之前加上关键字explicit，这样就会阻止饮食类型转换的发生
。例如：
class A{};
class B{
{..}
};
{...}
{
  A a;
  fn(a);
}
其中fn(a)这一行会报错，因为在B的类定义中已经通过explicit关键字禁用了从A向B的隐
式类型转换。

这种情况下，可以通过强制类型转换来解决，fn((b)a);其执行过程是，编译器检查到fn
形参类型为B，但是实参类型为A，于是希望能够进行隐式类型转换，于是去检查B的定义
中有没有合适的隐式类型转换函数，结果找到了B(A& a);这个合适的函数，但是它被
explicit修饰，禁用了自动隐式类型转换，于是开始检查传递形参到fn时是否指明了强制
类型转换，检查到传递的形参是(B)a，即指明了要从A向B进行强制类型转换，满足了
explicit的要求，然后类型转换开始，将a转换为B类对象后作为实参传递给fn，fn执行。

另外，多提一句，在c++中，对象的初始化的3中形式其实调用的是相同的构造函数。例如
：
A a;
B b=a;     // 形式1
B b(a);     // 形式2
B b{a};     // 形式3
这3种形式都是调用的构造函数B(A &)。

类的显示类型转换，也是通过强制类型转换运算符实现()。c++中类型转换考虑的比较周
全，首先提供了两个比较通用的强制类型转换形式：
expression;    // c-style notation
new_type (expression);    // functional notation
此外还提供了4中类型转换运算符，在说明这4中类型转换运算符之前，先说明下其原因。
由于通过强制类型转换，尤其是指针类型的转换，我们通过强制类型转换，可以将一个指
针指向任何类对象，当我们通过这样的指针调用某些成员函数的时候，就会出现runtime
错误，虽然在编译时没有任何问题，但是在运行时会出错。为了安全起见，c++提供了4中
类型转换运算符用于对类对象的强制类型转换进行控制。
它们分别是：
dynamic_cast <new_type> (expression);
reinterpret_cast <new_type> (expression);
static_cast <new_type> (expression);
const_cast <new_type> (expression);
每一种类型转换都有自己独特的特征。

dynamic_cast <new_type> (expression)：
dynamic_cast可以实现upcast和downcast，dynamic_cast仅应被用于指类对象的指针或者
引用的类型转换（包括void*），它的目的是确保转换后的指针或者引用可以指向一个有
效的、完整的对象。如果转换成功，返回对应的指针或引用；如果转换指针失败，返回
null，null就是0，内存0地址，如果转换引用失败，则抛出bad_cast异常，表示转换引用
失败。
看下面这个简单的例子：
{} };
class Derived: public Base { int a; };
{
  try {
     Base * pba = new Derived;
     Base * pbb = new Base;
     Derived * pd;

     pd = dynamic_cast<Derived*>(pba);
cout << "Null pointer on first type-cast.\n";
     pd = dynamic_cast<Derived*>(pbb);
cout << "Null pointer on second type-cast.\n";

{cout << "Exception: " << e.what();}
  return 0;
}
上面的代码中，第一次类型转换是成功的，因为pba指向了一个完整的派生类对象，虽然
pba是一个基类指针，通过dynamic_cast可以被downcast成派生类指针；第二次类型转换
是失败的，因为pbb指向的是一个基类对象，这个基类对象不是一个有效的、完整的派生
类对象，所以将该基类指针downcast成派生类指针会失败。
dynamic_cast需要RTTI（Runtime Type Information）的支持，需要编译器在编译的时候
打开相应的feature在编译后的代码中假如相应的信息，以便在运行时追踪dynamic类型信
息，以便完成这样的动态类型转换。

static_cast <new_type> (expression):
static_cast可以实现upcast和downcast，应该说static_cast是dynamic_cast的经济实用
版，为什么这么说呢？首先，它会在编译时完成指针和引用的upcast和downcast ，这个
与dynamic_cast相同，但是它不会像dynamic_cast那样，在运行时检查转换后的指针或引
用是否指向了一个有效的、完整的对象，运行时安全可能无法保证，类型转换后的安全由
程序员自己决定，因此，static_cast较之于dynamic_cast，损失了运行时安全检查，但
是也正是由于此，也减少了因为类型安全检查所引起的开销。

reinterpret_cast <new_type> (expression):
dynamic_cast、static_cast基本上都是在基类和派生类指针、引用之间进行转换，与它
们相比，reinterpret_cast可以实现任何指针类型向任何指针类型的转换，它的做法就是
将指针的值拷贝过去。基于这样的实现，它甚至可以将整型转换为指针类型，只要指针变
量的内存单元可以容纳这个整型值，这也是其提供的唯一的安全性检查。

const_cast <new_type> (expression):

const_cast主要是用于对指针set、remove const标志，即设置const标志或者移除const
标志，根据当前类型与目标类型是否有const标志自动进行设置。

在讲下面的例子之前，有几个基本常识需要了解，在c、c++中字符串常量都是存放在常量
存储区中的，是不允许修改的，例如char *str="helloworld",这里的helloworld就是存
储在常量存储区中的，虽然char *str前面没有const修饰，也不能通过str[i]去改变
helloworld中某个字符的值。如果是这样赋值，char str[] = "helloworld",则
helloworld不是存储在常量存储区中的，而是存储在栈上的，str这个数组在栈上创建，
hellowrold就存储在对应的内存单元中。

其实为什么会有这些差别，说白了都是编译器实现的原因。应该了解下编译器对内存分配
的管理，例如将内存分成堆区、栈区、程序文本区，刚才我习惯性说的常量存储区也就是
程序文本区，反汇编的时候就是.text段，总之是不允许修改的。

好了看下面一个简单的例子，理解下const_cast的使用：
void print (char * str)
{
  cout << str << '\n';
  str[0] = 'A';
  cout << str << '\n';
}
{
  char str[] = "hello world";
  const char * c = str;
);
  return 0;
}

这里主要看函数print，它的参数类型是char *而不是const char *，而参数c是const
char *类型，我们在调用print时，使用了const_cast对c进行类型转换，转换的类型与c
相同，只不过是需要const_cast根据需要为我们选择是设置const标志还是移除const标志
，这里const_cast为我们移除了const标志，使我们在print中可以改变字符串中的值。

通过typeid获取对象的类型信息，看一个简单的例子：
{
  int * a,b;
  a=0; b=0;
!= typeid(b))
  {
    cout << "a and b are of different types:\n";
<< '\n';
<< '\n';
  }
  return 0;
}
输出：
a is: int *
b is: int
typeid可以通过参数的类型构建出一个对象，这个对象的name方法可以获取到这个类型的
描述性字符串，这些类型信息在头文件<typeinfo>中定义。

下面在看一个typeid获取类对象类型信息的简单例子：
class Base { virtual void f(){} };
class Derived : public Base {};
{
  try {
    Base* a = new Base;
    Base* b = new Derived;
<< '\n';
<< '\n';
<< '\n';
<< '\n';
<< '\n'; }
   return 0;
}
输出：
a is: class Base *
b is: class Base *
*a is: class Base
*b is: class Derived

注意typeid这两个应用实例，应用起来就没有问题了。
另外需要注意，如果typeid(*ptr)中ptr为null的话，会抛出bad_typeid异常。

c++中异常处理：

try-catch，try中包含可能抛出异常的代码，抛出的异常可以是基本数据类型，也可以是
类对象，例如:
throw 20;
throw new B();

捕获基本数据类型时需要注意，catch(int e)或者catch(int &e),其中必须精确指明异常
类型为int，如果将其指明为short或者long则不会被捕获，如果需要一个能够捕获所有异
常类型的处理句柄，可以使用catch(...)来作为默认异常捕获句柄。

捕获类对象异常类型时，与捕获基本数据类型的异常稍微有所区别，例如假如有两个类A
、B，并且B是A的派生类，如果我们throw new B()，如果希望捕获类B，要么直接在catch
中捕获B类型异常对象，通过catch(B e)或者catch(B &e)进行直接捕获，要么通过
catch(...)捕获。
此外，还可以利用类的继承关系，来通过基类A来捕获派生类B，但是需要注意的是，基类
A必须是c++中标准异常类std::exception的派生类才可以，如果满足了这个条件，catch
的时候就可以通过catch(A &e)或者catch(A e)来捕获派生类B的对象。
一般，异常类，应该继承自std::exception，这样我们可以通过类的继承链关系来对抛出
的异常进行捕获，并且这样的话，也可以通过std::exception来统一对抛出的异常类对象
进行捕获。

与c++做个对比，java中捕获异常的时候，如果希望达到通过基类捕获派生类对象的目的
，例如通过A捕获B，那么要求类A必须是java.lang.Throwable的派生类，在java中通过基
类异常对象Exception捕获所有的异常对象。
此外，java中要catch的对象必须是java.lang.Throwable的派生类，也就是普通的基本数
据类型、非其派生类对象是不能够被当作异常抛出的。

在try-catch的过程中，可能会出现层层嵌套的情况，这个时候，如果希望将所有的异常
在外层进行统一处理，内层仅用来捕获异常的话，那么内层捕获异常之后可以选择将异常
重新抛出 ，即通过不带任何参数的语句throw就可以将异常重新抛出。

捕获异常的时候，为了提高效率，尽量传引用，而不是传值，这样可以一定程度上提高效
率。

try {
    try {
        throw xxx;
    }
{
        throw;
    }
}
{
    ...
}

捕获异常之后，为了能够将捕获到的对象的异常信息显示出来，可以重写std::exception
中的成员函数what()。

c++标准库中抛出的所有异常类都继承自std:exception这个类，这些异常类包括:
bad_alloc            thrown by new on allocation failure
bad_cast            thrown by dynamic_cast when it fails in a dynamic cast
bad_exception        thrown by certain dynamic exception specifiers
bad_typeid            thrown by typeid
bad_function_call    thrown by empty function objects
bad_weak_ptr        thrown by shared_ptr when passed a bad weak_ptr

=============================================================================
Sat Sep 13 12:05:00 CST 2014
=============================================================================

c++中的预处理指令，下面只介绍这些预处理指令中的一些常用的方法，具体地高级应用
暂不涉及。

宏定义#define,#undef:
预处理指令创建的宏在#undef之前一直有效，与语句块无关。宏定义在编译之前由预处理
器读取并进行相应的处理，宏定义的话，预处理器不会检查其数据类型，而仅仅是进行简
单的文本替换。
#define NUM 100
a>b?a:b
#x
x ## y
宏定义中的#表示将参数x两侧加上双引号,##表示将两个参数x，y连接在一起，连接的时
候只是将x、y的值连接，##前后的空格不用于连接。

条件包含指令：
#ifdef,#ifndef,#if,#endif,#else,#elif
条件包含指令在内核代码中大量出现，可以用于条件编译。

行控制：
#line linenumber "filename"，我们在编译源代码的时候，如果编译出错的时候，会报
出在那个源文件的哪一行出现了错误，我们可以通过#line指令控制显示的文件的名称，
即filename部分，另外，错误出现的行号可以被设置成基于某个初始行号的，例如我们设
置linenumber为100，显示的出错行号，就是在100+实际的出错行号。

错误指令：
#error something， 预处理器遇到这个宏，就表示遇到了错误，后续的编译过程就不会
被执行了。

源文件包含或者头文件包含：
#include，注意有两种形式#include <header>会在标准库中寻找对应的头文件实现，
#include "header"会首先在当前目录中寻找其实现，如果找不到再到标准库中寻找其实
现。有些时候允许我们设置include这个参数，让编译器自动到对应的目录中按照顺序检
索头文件，如果这么做的话，那么不管是不是c++标准库的实现还是用户自己的实现还是
其他第三方提供的库，使用#include "hedaer"或者#include <header>都是可以的。

pragma指令:
#pragam,该指令用于向编译器传递多种多样的控制选项，通常这些选项是与使用的平台和
编译器相关的，需要我们自己查看使用的平台、编译器手册以便确定可以传递的参数。

预定义宏：
__LINE__：当前代码行的行编号；
__FILE__：当前代码行所在源文件的名称；
__DATE__：当前系统日期；
__TIME__：当前系统时间；
__cplusplus：当前编译器支持的c++版本；

还有其他的一些编译器里面可选实现的宏定义选项，这里就布列出了。


c++里面的输入输出，这些没有什么特别之处，用到的时候，可以查看相关手册。

=============================================================================

/* vim: set ft=text: */
```
