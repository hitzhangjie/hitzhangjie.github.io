//
//  main.m
//  LearnOC
//
//  Created by Zhang Jie on 1/31/17.
//  Copyright © 2017 Zhang Jie. All rights reserved.
//

// 导入Foundation框架中的某些类常用到#import来导入，但是为了避免导入太多的类，框架就提供了一个头文件Foundation.h，在这里面基本上把框架中所有
// 的类都给包含进去了，其中NSObject四所有类的基类！
// Foundation框架中的类大致可以分为如下几个类别：
// - 数据存储相关类，NSSet、NSArray、NSDictionary及其Mutable版本
// - 文本和字符串相关类
// - 日期和时间相关类
// - 异常处理相关类
// - 文件处理相关类
// - 协议处理相关类
#import <Foundation/Foundation.h>

// 1. basic structure of oc program
// 声明接口
// - oc中的继承只允许继承自一个基类，但是允许多级继承，这一点与java中一致，与cpp有差异（cpp支持继承自多个基类）
// - oc中能做到多个类实现同一个接口吗？简单学习一下之后感觉好像不行，至少不能像java中那样直接class classname implements interfacename，
//   可能还是需要先声明接口，比如多个接口都继承自要实现的那个接口，然后再分别针对派生接口进行实现，来达到一个接口、多种实现的解决方案！
// - 基类（接口）指针指向派生类对象，通过基类来调用方法，是否表现出多态取决于派生类实现的时候是否重写了这个方法！如果重写了，就会调用派生类方法！
// - 数据封装是OOP中非常重要的概念，数据封装又引入了另一个非常重要的概念：数据隐藏！
// - 数据抽象指的是类的设计只对用户暴露可以访问数据的接口，但是不直接将数据暴露给用户（也称为数据隐藏），当然了访问数据的实现细节也对用户隐藏！
@interface Test:NSObject
{
    // 接口里面定义的实例变量，只能在当前类的实现中访问
    // 联想一下cpp或者java是通过访问修饰符来控制成员变量的可见性的，oc里面通过@Property来对外暴露某些实例变量
    int num_1;
    //int num_2;
}
// 等效于在头文件和源代码文件中添加一个int num_2成员，同时增加getter、setter方法，这里不保证读写操作的原子性
@property(nonatomic, readwrite) int num_2;
- (void) add;
- (int) addnum:(int)num1 secNum:(int)num2;    // 必须指定形参的名字，joining argument “secNum”是可选的
                                              // 但是如果声明、定义里面添加了joining argument的话，调用的时候也必须加上！dislike this！
@end

// 实现
@implementation Test
// 旧版的xcode实现中需要显示指明下面的语句，现在新版的xcode不需要显示指明了
//@synthesize num_2;
- (id)init {
    self = [super init];
    num_1 = 100;
    self.num_2 = 200;
    return self;
}
- (void) add {
    NSLog(@"hello world xxx");
}
- (int)addnum:(int)num1 secNum:(int)num2 {
    return num1+num2;
}
@end

// 如果希望对现有的某个类增加某几个属性或者方法的话，可以使用oc中的category！
// 当通过category为Test增加了一个方法print之后：
// - 只要在使用了Test类的源文件中包括这个MyTest定义的头文件的话，那么就可以通过Test类来使用这个新增加的print方法[Test printXX]
// - 注意，这里不能通过Test类的实例对象test来访问方法printXX，也不能通过MyTest类来访问printXX方法，只能通过[Test printXX]
// - 像[test printXX]、[MyTest printXX]这种使用方式都是非法的！
// why? 因为扩展都是用符号+来增加的，+其实表示添加的是类方法，-才是实例方法，现在明白了吧！
@interface Test(MyTest)
+ (void)printXX;
@end

@implementation Test(MyTest)
+ (void)printXX {
    NSLog(@"XX XX XX");
}
@end

// oc中还要另一个类似于category的东西extension，extension也称为匿名category
// 只能对已经存在接口源码的类添加private成员变量或者private方法，任何已经实现过的接口类无法为其添加扩展，例如为已经实现过的Test接口实现添加扩展就是非法的
/*
@interface Test()
{
    int xxxx;
}
- (int) xxx;
@end
 */
// oc通过extension添加的变量或者方法都是private类型的，不能再任何其他类中被访问（子类也不行）
@interface XXTest:NSObject
- (void)setId:(int)newId;
@end

@interface XXTest()
{
    // in oc, literal 'id' is a keyword, which indicates a datatype!
    int _id;
}
- (int) getId;
@end

@implementation XXTest
- (int) getId {
    return _id;
}
- (void) setId:(int)newId {
    _id = newId;
}
@end

// @protocol，这个也挺重要的，可以参考这里的教程：https://www.tutorialspoint.com/objective_c/objective_c_protocols.htm
// - protocol中的方法分为required、optional，遵从这个协议的类必须实现required要求的方法，optional要求的方法不要求
// - protocol中只允许声明方法：
@protocol XXProtocol
@required
- (void)method1;
@optional
- (void)method2;
@end
// 通常一个协议处理类需要执行某些特殊的协议处理动作，处理之前或者之后需要调用某些协议特定的方法，但是协议处理类最好只对协议发送过程中的动作进行处理，
// 处理之前、之后的动作最好交由专门的类来处理，这个时候就比较适合用协议来约定之前、之后要执行的接口，事务处理类里面只是通过delegate来动态绑定实现
// 了该接口的类，当然这个类最好也继承自事务处理类
@interface XXX:NSObject
{
    id delegate;
}
- (void)setDelegate:(id)newDelegate;
- (void)startAction;
@end

@implementation XXX
- (void)setDelegate:(id)newDelegate {
    delegate = newDelegate;
}
- (void)startAction {
    NSLog(@"action running");
    NSLog(@"action done");
    // action执行完成之后需要执行method1方法，但是当前类XXX不负责对协议中的method1方法进行实现，需要由delegate动态绑定一个已经实现该协议中方法的类来完成处理
    [delegate method1];
}
@end

@interface MyProtoHandler:XXX <XXProtocol>
- (void) method1;
- (void) test;
@end

@implementation MyProtoHandler
- (void) method1 {
    NSLog(@"hahaha, i am in method1");
}
- (void) test {
    [super setDelegate:self];
    [super startAction];
}
@end

// oc中的内存管理方式有两种：
// - MRR(Manual Retain Release)，必须在代码中手动执行retain（增加引用计数）或者release（减少引用计数），当引用计数为0时会调用对应对象的dealloc方法释放内存
// - ARC(Automatic Reference Counting)，自动引用计数这个方法在现版本的xcode里面可以直接使用@autoreleasepool {...}，这里的ARC采用的方式本质上与MRR一致，
//   只不过是编译器在编译的时候会为我们插入一些retain或者release的代码而已。为了保证代码质量，建议使用ARC这种内存管理方式！

// POSING在OSX 10.5之后就被废弃了，所以只是做下简单了解就可以了
// - 好像描述的是程序中可以用一个类a来完全替代另一个类b，这里的替代意味着以前发送给类b的消息将全部由a来接收
// - 当然这里的POSING机制是对类a、类b是有限制条件的，如果能随意替代那不就完蛋了，所以还是有些约束条件的
// 考虑到后续的OSX 10.5之后的版本中已经彻底废除了这种机制，所以这里做简要了解之后直接跳过了！


// 2. base datatypes in oc
// - 整型、浮点型
// - 枚举类型
// - void类型
// - 派生类型：指针类型、数组类型、结构体类型、联合类型、函数类型
// oc中的基本数据类型与c中基本一致，需要注意的是oc中提供的众多扩展的对象类型，NSObject是所有类的基类

// 3. constant
// - #define通过宏定义常量
// - const修饰变量不可修改，编译时会检查数据类型

// 4. operators
// - 算术运算符
// - 关系运算符
// - 逻辑运算符
// - 位运算符
// - 赋值运算符
// - misc杂项：sizeof & * -> ?:

// 5. 循环控制，for、do-while、while，与c语言一致
// 6. 条件分支，ifelse、switch、三元运算符?:，与c语言一致

// 7. 方法（oc中习惯称类中的函数为方法method，这在cpp、java中也是一样的叫法)
// - 了解一下在接口中声明方法原型的方法：注意，joining argument可选（最好就不加）、形参名称必须指定、返回值类型、形参类型必须加()，形参前面加：
// - 类对象方法调用的时候要通过下面的形式：retVal = [对象名 方法名 :param1 :param2 ...]

// 8. Block,oc中在c语言基础上增加了Block的概念，它类似于cpp、java中的闭包或lambda表达式
// -  关于Block的使用方式，可以参见：https://www.tutorialspoint.com/objective_c/objective_c_blocks.htm

// 9. 数组，oc中数组与c中一致
// 10. 指针，oc中指针与c中一致

// 11. 字符串，oc中使用NSString表示string类型，与c有区别，创建的时候通过@"xxx"来创建一个NSString *，使用NSLog打印的时候使用占位符%@
// - NSString这个字符串类还是很好用的，提供的方法更java中的String差不多

// 12. oc中的结构体数据类型struct，其使用方式与c中一致！
// - 通过struct变量访问成员的时候通过点“.”运算符，通过struct指针访问成员的时候通过箭头“->”运算符
// - 通过struct来使用位字段的方式也与c中一致！

// 13. 预处理指令，与c中基本一致，oc中增加了一个#import预处理指令，目前看起来好像跟#include效果类似

// 14. 类型别名定义
// - typedef，编译器处理；#define，预处理器处理

// 15. 显示类型转换 & 隐式类型转换（类型提升)，与c中一致！

// 16. 日志处理NSLog方法
// - NSLog日志永远都会被打印出来，但是对于一个release版本的程序来说，打印大量的日志并不是一个好的处理方式
// - 一般我们是在开发、测试的过程中打开debug日志，在发行版中关闭debug日志，只打印重要日志信息，下面是一个不错的处理方式：
//     #if DEBUG == 0
//     #define DebugLog(...)
//     #elif DEBUG == 1
//     #define DebugLog(...) NSLog(__VA_ARGS__)
//     #endif
//   这样一来对于debug日志就通过DebugLog来打印，准备发布release版本的时候讲DEBUG宏设置为0就可以了

// 17. 错误处理
// - NSError这个类中封装了一个打印错误信息的一系列方法，一个NSError包括一个错误域、错误代码、用户信息
// 后面再看这里，现在暂时用不到！

// 18. 命令行参数处理，main(int argc, char **argv)，argc、argv与c语言中处理方式一致



int main(int argc, const char * argv[]) {
    // oc新版本中使用ARC（automatic reference count）来自动管理内存，下面这种方式是老版本的用法，不建议使用:
    //    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    //    ...
    //    [pool drain];
    // 如果非要用这个方法的话，可以在xcode中关闭arc
    // 使用arc的话直接使用@autoreleasepool {...}就可以了
   
    @autoreleasepool {
    
        // 1.test
        // 在堆上创建一个对象
        Test *test = [[Test alloc]init];
        // 调用对象的方法
        [test add];
        
        // 2.test
        NSLog(@"size of int is %d bytes", (int)sizeof(int));
    
        int a = 1, b = 2;
        int c = [test addnum :a secNum:b];
        [Test printXX];
        //[test printXX];
        //[MyTest printXX];
        printf("c == %d\n", c);
        
        // 11.test
        NSString *name = @"zhangjie";
        NSLog(@"your name is %@", name);
        NSLog(@"your name is %@", name.capitalizedString);
        NSLog(@"your name is %c", [name characterAtIndex:1]);
        NSLog(@"your name has prefix 'zh', yes or no? %d", [name hasPrefix:@"zh"]);
        NSString *name2 = @"zhangjie2";
        NSString *name3 = @"zhangjie";
        if([name isEqualToString:name2]) {
            NSLog(@"name==name2");
        }
        if([name isEqualToString:name3]) {
            NSLog(@"name==name3");
        }
        NSString *append = @"xxxx";
        NSLog(@"new string is %@", [name stringByAppendingString:append]);
        
        // protocol test
        MyProtoHandler * handler = [[MyProtoHandler alloc]init];
        [handler test];
        
        Test *test1 = [[Test alloc]init];
        // ARC禁止调用retainCount，关闭ARC要从xcode project->build settings中进行设置，一旦设置为arc为关闭的时候，即便代码中加了@autoreleasepool也没arc效果了
        /*
        NSLog(@"reference count = %lu", [test1 retainCount]);
        [test1 retain];
        NSLog(@"reference count = %lu", [test1 retainCount]);
        [test1 release];
        NSLog(@"reference count = %lu", [test1 retainCount]);
         */
    }
    
   
    return 0;
}
