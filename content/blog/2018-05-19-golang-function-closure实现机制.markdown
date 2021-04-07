---
layout: post
title:  "golang function-closure 实现机制"
color: green
width:  6
height:  1
date:   2018-05-19 19:55:15 +0800
tags: ["go", "golang", "closure"]
toc: true
---

golang里面函数时first-class citizen，可以作为值进行参数传递，不管是普通函数“func abc()”，还是成员方法“func (x X) xxx()”，还是一个闭包“func () { return func(){....}}”……看上去很方便，不禁要问，golang里面funciton和closure是如何实现的呢？扒拉了下源码，这里简单总结下。

# 1 golang中函数内部表示是什么样子的？

看下golang cmd/compile/internal/types/type.go中对Func类型的定义：
```golang
// Func contains Type fields specific to func types.
type Func struct {
   Receiver *Type  // function receiver，接受者类型，每个函数定义都包括该字段，可以为nil或non-nil
   Results  *Type   // function results，返回值类型
   Params   *Type // function params，参数列表类型
   Nname *Node   // function name，函数名
   // Argwid is the total width of the function receiver, params, and results.
   // It gets calculated via a temporary TFUNCARGS type.
   // Note that TFUNC's Width is Widthptr.
   Argwid int64
   Outnamed bool // 是否是可导出的？
}
```
通过这个Func定义来看，其可以覆盖golang里面所有的函数类型声明了，不管是普通函数，还是成员方法等等。

# 2 golang中闭包是怎么实现的？

前端时间组内分享闭包使用的时候，觉得这玩意虽然轻巧但是太容易出错了，究其原因是因为不了解闭包的实现原理。那么闭包是如何实现的呢，抽时间扒拉了一下golang中实现闭包的代码，看完后瞬间觉得闭包很简单。

来简单总结一下，**闭包就是函数+环境**，问题是**这里的环境是如何与函数进行绑定的呢**？

>remark: 一开始看了上面的Func类型定义之后，我以为是golang创建了一个虚拟的类型（里面各个字段值为闭包捕获的变量值）然后将该虚拟类型作为receiver-type来实现的呢，可是仔细一想这种思路站不住脚，因为闭包是golang里面的first-class citizen，闭包实现应该非常轻量才对，如果像我最初这种想法那实在是太复杂了，想想要创建多少虚拟类型及其对象吧。

看了下源代码，总结一下golang中的实现思路，考虑到闭包对象是否能重复使用，分为两个场景进行处理：

**1) 假如闭包定义后立即被调用**
因为只会被使用一次，所以应该力图避免闭包对象的内存分配操作，那怎么优化一下呢，以下面的示例代码为例。
```golang
func(a int) {
    println(byval)
    byref++
}(42)
```
上面的闭包将被转换为简单函数调用的形式：
```golang
func(byval int, &byref *int, a int) {
    println(byval)
    (*&byref)++
}(byval, &byref, 42)
```
注意看函数原型的变化，原来闭包里面捕获的变量都被转换成了通过函数参数来供值：
- 因为println操作不涉及对byval变量的修改操作，所以是按值捕获；
- 而byref++涉及到对捕获变量的修改，所以是按引用捕获，对于按引用捕获的变量会进行特殊处理，golang编译器会在编译时将按引用捕获的变量名byref转换成“&byref”，同时将其类型转换成pointer类型，捕获变量对应的写操作也会转换为通过pointer来操作。

**2） 假如闭包定以后并不是立即调用**
闭包定义后不是立即使用，而是后续调用，这种情况下同一个闭包可能调用多次，这种情况下就需要创建闭包对象，如何实现呢？
- 如果变量是按值捕获，并且该变量占用存储空间小于2*sizeof(int)，那么就通过在函数体内创建局部变量的形式来shadow捕获的变量，相比于通过引用捕获，这么做的好处应该是考虑到减少引用数量、减少逃逸分析相关的计算。
- 如果变量是按引用捕获，或者按值捕获但是捕获的变量占用存储空间较大（拷贝到本地做局部变量代价太大），这种情况下就将捕获的变量var转换成pointer类型的“&var”，并在函数prologue阶段将其初始化为捕获变量的值。

这部分的代码详见：cmd/compile/gc/closure.go中的方法transformclosure(...)。
闭包就是函数体+环境，环境就是像这样绑定的。

# 3 总结
本文简要描述了golang中对函数的内部定义，以及闭包的大致实现思路，加深了理解。

# 附：golang闭包处理关键代码
```golang
func transformclosure(xfunc *Node) {
	lno := lineno
	lineno = xfunc.Pos
	func_ := xfunc.Func.Closure

	if func_.Func.Top&Ecall != 0 {
		// If the closure is directly called, we transform it to a plain function call
		// with variables passed as args. This avoids allocation of a closure object.
		// Here we do only a part of the transformation. Walk of OCALLFUNC(OCLOSURE)
		// will complete the transformation later.
		// For illustration, the following closure:
		//	func(a int) {
		//		println(byval)
		//		byref++
		//	}(42)
		// becomes:
		//	func(byval int, &byref *int, a int) {
		//		println(byval)
		//		(*&byref)++
		//	}(byval, &byref, 42)

		// f is ONAME of the actual function.
		f := xfunc.Func.Nname

		// We are going to insert captured variables before input args.
		var params []*types.Field
		var decls []*Node
		for _, v := range func_.Func.Cvars.Slice() {
			if v.Op == OXXX {
				continue
			}
			fld := types.NewField()
			fld.Funarg = types.FunargParams
			if v.Name.Byval() {
				// If v is captured by value, we merely downgrade it to PPARAM.
				v.SetClass(PPARAM)
				fld.Nname = asTypesNode(v)
			} else {
				// If v of type T is captured by reference,
				// we introduce function param &v *T
				// and v remains PAUTOHEAP with &v heapaddr
				// (accesses will implicitly deref &v).
				addr := newname(lookup("&" + v.Sym.Name))
				addr.Type = types.NewPtr(v.Type)
				addr.SetClass(PPARAM)
				v.Name.Param.Heapaddr = addr
				fld.Nname = asTypesNode(addr)
			}

			fld.Type = asNode(fld.Nname).Type
			fld.Sym = asNode(fld.Nname).Sym

			params = append(params, fld)
			decls = append(decls, asNode(fld.Nname))
		}

		if len(params) > 0 {
			// Prepend params and decls.
			f.Type.Params().SetFields(append(params, f.Type.Params().FieldSlice()...))
			xfunc.Func.Dcl = append(decls, xfunc.Func.Dcl...)
		}

		dowidth(f.Type)
		xfunc.Type = f.Type // update type of ODCLFUNC
	} else {
		// The closure is not called, so it is going to stay as closure.
		var body []*Node
		offset := int64(Widthptr)
		for _, v := range func_.Func.Cvars.Slice() {
			if v.Op == OXXX {
				continue
			}

			// cv refers to the field inside of closure OSTRUCTLIT.
			cv := nod(OCLOSUREVAR, nil, nil)

			cv.Type = v.Type
			if !v.Name.Byval() {
				cv.Type = types.NewPtr(v.Type)
			}
			offset = Rnd(offset, int64(cv.Type.Align))
			cv.Xoffset = offset
			offset += cv.Type.Width

			if v.Name.Byval() && v.Type.Width <= int64(2*Widthptr) {
				// If it is a small variable captured by value, downgrade it to PAUTO.
				v.SetClass(PAUTO)
				xfunc.Func.Dcl = append(xfunc.Func.Dcl, v)
				body = append(body, nod(OAS, v, cv))
			} else {
				// Declare variable holding addresses taken from closure
				// and initialize in entry prologue.
				addr := newname(lookup("&" + v.Sym.Name))
				addr.Type = types.NewPtr(v.Type)
				addr.SetClass(PAUTO)
				addr.Name.SetUsed(true)
				addr.Name.Curfn = xfunc
				xfunc.Func.Dcl = append(xfunc.Func.Dcl, addr)
				v.Name.Param.Heapaddr = addr
				if v.Name.Byval() {
					cv = nod(OADDR, cv, nil)
				}
				body = append(body, nod(OAS, addr, cv))
			}
		}

		if len(body) > 0 {
			typecheckslice(body, Etop)
			walkstmtlist(body)
			xfunc.Func.Enter.Set(body)
			xfunc.Func.SetNeedctxt(true)
		}
	}

	lineno = lno
}
```

