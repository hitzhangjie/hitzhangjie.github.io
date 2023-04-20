---
layout: post
title: 别用float作为map的key
description: "使用float作为map的key，非常容易留坑"
date: 2019-05-23 00:16:36 +0800
tags: ["go", "map", "float"]
toc: true
---

遇到个好玩的问题，使用float类型作为go map的key，示例代码如下：
![use-float64-as-map-key](assets/gomap/1558586114_21.png)

其实就是浮点数精度的问题，随手翻了下go map的源码，备忘下。这里要涉及到几个问题：

- golang如何针对key计算hash的，阅读源码后发现就是有个key *_type，h.key.alg.hash(key)来计算得到hash，问题就出在这里的hash计算过程，可以阅读下alg.go，里面针对不同的key类型定义了计算hash的方法：

  ```go
  var algarray = [alg_max]typeAlg{
  	alg_NOEQ:     {nil, nil},
  	alg_MEM0:     {memhash0, memequal0},
  	alg_MEM8:     {memhash8, memequal8},
  	alg_MEM16:    {memhash16, memequal16},
  	alg_MEM32:    {memhash32, memequal32},
  	alg_MEM64:    {memhash64, memequal64},
  	alg_MEM128:   {memhash128, memequal128},
  	alg_STRING:   {strhash, strequal},
  	alg_INTER:    {interhash, interequal},
  	alg_NILINTER: {nilinterhash, nilinterequal},
  	alg_FLOAT32:  {f32hash, f32equal},
  	alg_FLOAT64:  {f64hash, f64equal},
  	alg_CPLX64:   {c64hash, c64equal},
  	alg_CPLX128:  {c128hash, c128equal},
  }
  ```

  float64就是要使用`f64hash`这个方法来计算hash值。

- golang里面利用计算得到的hash值的后5位作为hmap的bucket index，先定位到bucket，然后再根据hash的前8位作为与bucket内部<k,v> entries的hash进行比较找到对应的entry。

  

下面我们看下f64hash的实现：

```go
func f64hash(p unsafe.Pointer, h uintptr) uintptr {
	f := *(*float64)(p)
	switch {
	case f == 0:
		return c1 * (c0 ^ h) // +0, -0
	case f != f:
		return c1 * (c0 ^ h ^ uintptr(fastrand())) // any kind of NaN
	default:
		return memhash(p, h, 8)
	}
}
```

f==0或者f!=f是两种极端情况，不考虑直接看f64hash里面调用方法memhash(p, h, 8)，memhash实现，省略无关代码：

```go
func memhash(p unsafe.Pointer, seed, s uintptr) uintptr {
	if (GOARCH == "amd64" || GOARCH == "arm64") &&
		GOOS != "nacl" && useAeshash {
		return aeshash(p, seed, s)
	}
	h := uint64(seed + s*hashkey[0])
tail:
	switch {
	case s == 0:
	case s < 4:
		...
	case s <= 8:
		h ^= uint64(readUnaligned32(p))
		h ^= uint64(readUnaligned32(add(p, s-4))) << 32
		h = rotl_31(h*m1) * m2
	case s <= 16:
		...
  case s <= 32:
		...
	default:
		...
	}

	h ^= h >> 29
	h *= m3
	h ^= h >> 32
	return uintptr(h)
}
```

现在可以看到它其实是把浮点数的内存表示（IEEE 754 double encoding format) 当做一个普通的数字来计算的，先读4字节计算，再读剩下的4字节计算，再做其他计算。

两个浮点数最终hash值相同，其实就是浮点数精度导致的，写代码的时候，看上去我们定义了两个完全不同的浮点数，但是内存中按照IEEE 754 double的规范进行内存表示的时候，很可能就是一样的。

![IEEE 754 Double Format](assets/gomap/1558586071_3.png)

上面是IEEE 754 double的格式，1位符号位，11位阶码，52位尾数，像NaN、Inf的定义也都跟这些不同的组成部分有关。这里只关心尾数部分就好了，只有52位，当超过52 bits可以表示的精度之后，代码里面定义的数值就被截断了。

示例代码中，看似数值上有一两位末尾数字不同的浮点数，内存表示是相同的，hash值也相同，就会出现map赋值时值被覆盖的问题。

浮点数的更多细节如符号位、阶码（bias）、尾数，以及NaN、Inf的定义等，可以参考wikipedia了解更多细节。