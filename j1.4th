(
   eForth 1.04 for j1 Simulator by Edward A., July 2014
   Much of the code is derived from the following sources:
      j1 Cross-compiler by James Bowman August 2010
     8086 eForth 1.0 by Bill Muench and C. H. Ting, 1990
)

only forth definitions hex

wordlist constant meta.1 \ 转移编译词汇 
wordlist constant target.1 \ 目标词汇(自定义forth系统的词汇)
wordlist constant assembler.1	\ 汇编词汇 组成目标词汇

: (order) ( w wid*n n -- wid*n w n ) 
\ w表示一个词表  wid*n表示wid1、wid2···widn  n表示n个词表 ；该词的功能为从当前搜索词表中找出该词并丢弃wid*[n-1] w n，若无该词不进行任何操作wid*n w n
   dup if
    1- swap >r recurse over r@ xor if
     1+ r> -rot exit then r> drop then ;
: -order ( wid -- ) get-order (order) nip set-order ; \ 把词表从搜索词表的序列中删除 ，get-order返回结果widn~wid1 n（wid1为栈顶元素，n为词表wid个数）
: +order ( wid -- ) dup >r -order get-order r> swap 1+ set-order ; \ 把词表添加搜索词表的序列中

: ]asm ( -- ) assembler.1 +order ; immediate \把汇编词表加入到搜索队列中

get-current meta.1 set-current

: [a] ( "name" -- ) \ 如果后面跟随的词在汇编(assembler.1)列表中，则把该词的执行地址（代码指针域地址）编译到使用本词的定义中（即本定义词的参数域中）
  parse-word assembler.1 search-wordlist 0=
   abort" [a]?" compile, ; immediate
: a: ( "name" -- ) \把一个词汇加入到汇编词列表中
  get-current >r  assembler.1 set-current
  : r> set-current ;

target.1 +order meta.1 +order

a: asm[ ( -- ) assembler.1 -order ; immediate \ asm[ 功能：把汇编词表从搜索表中删除

create tflash 1000 cells here over erase allot \ 创建一个数组tflash，1000个单元大小，并且清空单元内的所有废数据，将here指针向后推进1000个单元

variable tdp 	\ tflash的指针

: there ( -- n ) tdp @ ;  \ 变量tdp的值
: tc! ( n addr -- ) tflash + c! ; \ 把n的低8位存到数组tflash的addr位置  字节 为单位
: tc@ ( addr -- ) tflash + c@ ; \ 取数组tflash的addr位置的值 字节 为单位
: t! ( n addr -- ) over ff and over tc! swap 8 rshift swap 1+ tc! ; \ 把n存到数组tflash的addr位置  字 为单位
: t@ ( tdp -- ) dup tc@ swap 1+ tc@ 8 lshift or ; \ 取数组tflash的addr位置的值 字 为单位
: talign ( -- ) there 1 and tdp +! ; \ 若变量tdp中存的是地址 则判断地址是否是按字对齐的（最低位为0是对齐） 若不对齐则对齐（地址+1）
: tc, ( n -- ) there tc! 1 tdp +! ; \ 把变量中的值低8位存到tflash数组的tdp位置后tdp指针自增1
: t, ( n -- ) there t! 2 tdp +! ; \ 把变量中的值存到tflash数组的tdp位置后tdp指针自增2
: $literal [char] " word count dup tc, 0 ?do 
	count tc, loop drop talign ; \ 读取一个词存入到tflash中  tflash的内容为【5，‘a’,'b','x','s','e',·····】
: tallot tdp +! ; \ 加减法更改指针位置 
: org tdp ! ; \ 更改指针位置
\ [char] " 如果我想的不错的话是把“ " ”的ascii码放到栈顶，然后word从输入中获取一个词以“ " ”结尾，返回带有词长度的地址，count把这个带有词长度的地址转换成词的第一个字符的地址和词长度，此时堆栈应为 addr len，dup和tc,后,堆栈为addr len。tflash为【len[8:0],······】其中len[8:0]为len的低8位。进入循环后 执行count和tc，后堆栈为addr+1。tflash为【len[8:0], len[8:0]-1,······】。难道tflash就存长度不存字符
a: t    0000 ;
a: n    0100 ;
a: t+n  0200 ;
a: t&n  0300 ;
a: t|n  0400 ;
a: t^n  0500 ;
a: ~t   0600 ;
a: n==t 0700 ;
a: n<t  0800 ;
a: n>>t 0900 ;
a: t-1  0a00 ;
a: rt   0b00 ;
a: [t]  0c00 ;
a: n<<t 0d00 ;
a: dsp  0e00 ;
a: nu<t 0f00 ;

a: t->n 0080 or ;
a: t->r 0040 or ;
a: n->[t] 0020 or ;
a: d-1  0003 or ;
a: d+1  0001 or ;
a: r-1  000c or ;
a: r-2  0008 or ;
a: r+1  0004 or ;

a: alu  6000 or t, ;

a: return [a] t 1000 or [a] r-1 [a] alu ; \ （ -- ）将指令700c送至tflash[tdp] 指令700c：逻辑运算 返回栈顶地址送至pc 返回堆栈指针-1 ，其中1000为返回栈顶地址送至pc
a: branch 2/ 0000 or t, ; \ （ n -- ） jump
a: ?branch 2/ 2000 or t, ; \ 条件跳转
a: call 2/ 4000 or t, ;

a: literal \ ( n -- ) 若n>8000h 则在tflash[tdp]处存放值8000h的取反值（即取非值）和6600h（非 运算指令）；若 n!=8000h 则在tflash[tdp]处存放值8000h|n（按位或运算） 的值即转换为文字
   dup 8000 and if
    ffff xor recurse
     [a] ~t [a] alu
   else
    8000 or t,
   then ;

variable tlast \ tflash中最后一个词的指针
variable tuser

0001 constant =ver
0004 constant =ext
0040 constant =comp \ 与某词长度or运算可使该词为只编译词不搜索，即词长度的次高位置为1
0080 constant =imed \ 与某词长度or运算可使该词为立即词，即词长度的最高位置为1
7f1f constant =mask
0002 constant =cell
0010 constant =base
0008 constant =bksp
000a constant =lf	\ 换行符的ascii码
000d constant =cr	\ 回车符的ascii码

4000 constant =em
0000 constant =cold

 8 constant =vocs
80 constant =us

=em 100 - constant =tib \ 3f00
=tib =us - constant =up \ 3e80

=cold =us + constant =pick \ 0080
=pick 100 + constant =code \ 0180

: thead ( "name" -- ) \ 以空格为结尾 存放字符串 一般为词头名称 第一个单元存放长度,,
  talign
   tlast @ t, there tlast !
	parse-word dup tc, 0 ?do count tc, loop drop talign ; 
: twords ( -- )  \ 打印tflash中的词 每个词的之间有空格  若一个词的长度为0 则停止打印   ｛len1， “5555”， len2， “12312”， len3， “12jlkj”， ······｝
   cr tlast @
   begin
      dup tflash + count 1f and type space =cell - t@
   ?dup 0= until ;
: [t] ( "name" -- ) \ 如果后面跟随的词在目标(target.1)列表中，则把该词的参数域的内容放在堆栈上
  parse-word target.1 search-wordlist 0=
    abort" [t]?" >body @ ; immediate
: [last] ( -- ) tlast @ ; immediate \ 最后一个词的指针
: ( [char] ) parse 2drop ; immediate \ 括号定义 忽略括号内部的内容
: literal [a] literal ;
: lookback ( -- n ) there =cell - t@ ; \ 取前一个单元的值
: call? ( -- 1or0 ) lookback e000 and 4000 = ; \ 如果前一单元的指令为跳转指令则栈顶为1 反之为0
: call>goto ( -- ) there =cell - dup t@ 1fff and swap t! ; \ 将tdp-2处的跳转指令中的地址取出并重新存入当前指令的位置
: safe? ( -- 1or0 ) lookback e000 and 6000 = lookback 004c and 0= and ; \ 判断tflash[tdp-2]中的指令是否是alu并且参数栈顶数据不穿传到返回栈顶，是返回1，反之0  指令004c 参数栈顶数据传到返回栈顶
: alu>return there =cell - dup t@ 1000 or [a] r-1 swap t! ;	\ 在指令中添加返回位即R->PC,以及返回堆栈指针-1指令
: t: \ 创建跟在t：之后的词，并将tdp指针存到创建词的参数域，运行该词的时候会跳转到参数域的tdp指针处。创建t；之前的词不会编译到词参数域中，而是存储到tflash的tdp处。
  >in @ thead >in !
    get-current >r target.1 set-current create
	 r> set-current 947947 talign there , does> @ [a] call ; \ t: noop noop t;
: exit \ 若是跳转指令call 则将地址取出并重新存入当前指令的位置，否则判断是否是alu并且参数栈顶不传数据到返回栈顶，是则在该指令中添加返回位即R->PC否则直接写返回指令到tdp-2位置
  	call? if
	
  		call>goto
  	else safe? if
			alu>return 
		else
	 		[a] return
   		then
  	then ;
: t; \ t：的结束词，它会使该定义词返回到原来调用的下一条语句
  947947 <> if
   abort" unstructured" then true if
	exit else [a] return then ;
: u: \ 创建用户变量 参数域存为tflash的地址 ，并将地址转换为文字指令 且加上退出指令
  >in @ thead >in !
   get-current >r target.1 set-current create
    r> set-current talign tuser @ dup ,
	 [a] literal exit =cell tuser +! does> @ [a] literal ;
: [u] \ 取后跟随的词的参数域的内容 减去地址=up再加2
  parse-word target.1 search-wordlist 0=
    abort" [t]?" >body @ =up - =cell + ; immediate
: immediate tlast @ tflash + dup c@ =imed or swap c! ;
: compile-only tlast @ tflash + dup c@ =comp or swap c! ;

      0 tlast !
    =up tuser !  \ 3e80

: hex# ( u -- addr len )  0 <# base @ >r hex =lf hold # # # # r> base ! #> ; \ 将无符号单字长整数转换为4有效位的16进制整数字符串 
: save-hex ( <name> -- ) 
  parse-word w/o create-file throw
  there 0 do i t@  over >r hex# r> write-file throw 2 +loop
   close-file throw ; \ 将代码编译保存为16进制文件
: save-target ( <name> -- ) \ 将代码编译保存为2进制文件
  parse-word w/o create-file throw >r
   tflash there r@ write-file throw r> close-file ;

: begin  there ; \ tdp指针的值
: until  [a] ?branch ; \ 2/ 2000 or t,

: if     there 0 [a] ?branch ;
: skip   there 0 [a] branch ;
: then   begin 2/ over t@ or swap t! ; \ tdp tdp1/2 tdp@ or 
: else   skip swap then ;
: while  if swap ;
: repeat [a] branch then ;
: again  [a] branch ;
: aft    drop skip begin swap ;

: noop ]asm t alu asm[ ;
: + ]asm t+n d-1 alu asm[ ;
: xor ]asm t^n d-1 alu asm[ ;
: and ]asm t&n d-1 alu asm[ ;
: or ]asm t|n d-1 alu asm[ ;
: invert ]asm ~t alu asm[ ;
: = ]asm n==t d-1 alu asm[ ;
: < ]asm n<t d-1 alu asm[ ;
: u< ]asm nu<t d-1 alu asm[ ;
: swap ]asm n t->n alu asm[ ;
: dup ]asm t t->n d+1 alu asm[ ;
: drop ]asm n d-1 alu asm[ ;
: over ]asm n t->n d+1 alu asm[ ;
: nip ]asm t d-1 alu asm[ ;
: >r ]asm n t->r r+1 d-1 alu asm[ ;
: r> ]asm rt t->n r-1 d+1 alu asm[ ;
: r@ ]asm rt t->n d+1 alu asm[ ;
: @ ]asm [t] alu asm[ ;
: ! ]asm t n->[t] d-1 alu
    n d-1 alu asm[ ;
: dsp ]asm dsp t->n d+1 alu asm[ ;
: lshift ]asm n<<t d-1 alu asm[ ;
: rshift ]asm n>>t d-1 alu asm[ ;
: 1- ]asm t-1 alu asm[ ;
: 2r> ]asm rt t->n r-1 d+1 alu
    rt t->n r-1 d+1 alu
    n t->n alu asm[ ;
: 2>r ]asm n t->n alu
    n t->r r+1 d-1 alu
    n t->r r+1 d-1 alu asm[ ;
: 2r@ ]asm rt t->n r-1 d+1 alu
    rt t->n r-1 d+1 alu
    n t->n d+1 alu
    n t->n d+1 alu
    n t->r r+1 d-1 alu
    n t->r r+1 d-1 alu
    n t->n alu asm[ ;
: unloop
    ]asm t r-1 alu
    t r-1 alu asm[ ;

: dup@ ]asm [t] t->n d+1 alu asm[ ;
: dup>r ]asm t t->r r+1 alu asm[ ;
: 2dupxor ]asm t^n t->n d+1 alu asm[ ;
: 2dup= ]asm n==t t->n d+1 alu asm[ ;
: !nip ]asm t n->[t] d-1 alu asm[ ;
: 2dup! ]asm t n->[t] alu asm[ ;

: up1 ]asm t d+1 alu asm[ ;
: down1 ]asm t d-1 alu asm[ ;
: copy ]asm n alu asm[ ;

a: down e for down1 next copy exit  ;
a: up e for up1 next noop exit ;

: for >r begin ;
: next r@ while r> 1- >r repeat r> drop ;

=pick org

    ]asm down up asm[
	
there constant =pickbody

	copy ]asm return asm[
	9c ]asm call asm[ bc ]asm branch asm[
	9a ]asm call asm[ ba ]asm branch asm[
	98 ]asm call asm[ b8 ]asm branch asm[
	96 ]asm call asm[ b6 ]asm branch asm[
	94 ]asm call asm[ b4 ]asm branch asm[
	92 ]asm call asm[ b2 ]asm branch asm[
	90 ]asm call asm[ b0 ]asm branch asm[
	8e ]asm call asm[ ae ]asm branch asm[
	8c ]asm call asm[ ac ]asm branch asm[
	8a ]asm call asm[ aa ]asm branch asm[
	88 ]asm call asm[ a8 ]asm branch asm[
	86 ]asm call asm[ a6 ]asm branch asm[
	84 ]asm call asm[ a4 ]asm branch asm[
	82 ]asm call asm[ a2 ]asm branch asm[
	80 ]asm call asm[ a0 ]asm branch asm[
	]asm return asm[

=cold org

0 t,

there constant =uzero
   =base t, ( base )
   0 t,     ( temp )
   0 t,     ( >in )
   0 t,     ( #tib )
   =tib t,  ( tib )
   0 t,     ( 'eval )
   0 t,     ( 'abort )
   0 t,     ( hld )

            ( context )

   0 t, 0 t, 0 t, 0 t, 0 t, 0 t, 0 t, 0 t, 0 t,

            ( forth-wordlist )

   0 t,     ( na, of last definition, linked )
   0 t,     ( wid|0, next or last wordlist in chain )
   0 t,     ( na, wordlist name pointer )

            ( current )

   0 t,     ( wid, new definitions )
   0 t,     ( wid, head of chain )

   0 t,     ( dp )
   0 t,     ( last )
   0 t,     ( '?key )
   0 t,     ( 'emit )
   0 t,     ( 'boot )
   0 t,     ( '\ )
   0 t,     ( '?name )
   0 t,     ( '$,n )
   0 t,     ( 'overt )
   0 t,     ( '; )
   0 t,     ( 'create )
there constant =ulast
=ulast =uzero - constant =udiff

=code org

t: noop noop t;
t: + + t;
t: xor xor t;
t: and and t;
t: or or t;
t: invert invert t;
t: = = t;
t: < < t;
t: u< u< t;
t: swap swap t;
t: u> swap u< t;
t: dup dup t;
t: drop drop t;
t: over over t;
t: nip nip t;
t: lshift lshift t;
t: rshift rshift t;
t: 1- 1- t;
t: >r r> swap >r >r t; compile-only
t: r> r> r> swap >r t; compile-only
t: r@ r> r> dup >r swap >r t; compile-only
t: @ ( a -- w ) @ t;
t: ! ( w a -- ) ! t;

t: <> = invert t;
t: 0< 0 literal < t;
t: 0= 0 literal = t;
t: > swap < t;
t: 0> 0 literal swap < t;
t: >= < invert t;
t: tuck swap over t;
t: -rot swap >r swap r> t;
t: 2/ 1 literal rshift t;
t: 2* 1 literal lshift t;
t: 1+ 1 literal + t;
t: sp@ dsp ff literal and t;
t: execute ( ca -- ) >r t;
t: bye ( -- ) f002 literal ! t;
t: c@ ( b -- c )
  dup @ swap 1 literal and if
   8 literal rshift else ff literal and then exit t;
t: c! ( c b -- )
  swap ff literal and dup 8 literal lshift or swap
   tuck dup @ swap 1 literal and 0 literal = ff literal xor
   >r over xor r> and xor swap ! t;
t: um+ ( w w -- w cy )
  over over + >r
   r@ 0 literal >= >r
    over over and
	 0< r> or >r
   or 0< r> and invert 1+
  r> swap t;
t: dovar ( -- a ) r> t; compile-only
t: up dovar =up t, t;
t: douser ( -- a ) up @ r> @ + t; compile-only

u: base
u: temp
u: >in
u: #tib
u: tib
u: 'eval
u: 'abort
u: hld
u: context
	=vocs =cell * tuser +!
u: forth-wordlist
    =cell tuser +!
	=cell tuser +!
u: current
	=cell tuser +!
u: dp
u: last
u: '?key
u: 'emit
u: 'boot
u: '\
u: 'name?
u: '$,n
u: 'overt
u: ';
u: 'create

t: ?dup ( w -- w w | 0 ) dup if dup then exit t;
t: rot ( w1 w2 w3 -- w2 w3 w1 ) >r swap r> swap t;
t: 2drop ( w w -- ) drop drop t;
t: 2dup ( w1 w2 -- w1 w2 w1 w2 ) over over t;
t: negate ( n -- -n ) invert 1+ t;
t: dnegate ( d -- -d )
   invert >r invert 1 literal um+ r> + t;
t: - ( n1 n2 -- n1-n2 ) negate + t;
t: abs ( n -- n ) dup 0< if negate then exit t;
t: max ( n n -- n ) 2dup > if drop exit then nip t;
t: min ( n n -- n ) 2dup < if drop exit then nip t;
t: within ( u ul uh -- t ) over - >r - r> u< t;
t: um/mod ( udl udh u -- ur uq )
   2dup u< if
    negate f literal
     for >r dup um+ >r >r dup um+ r> + dup
     r> r@ swap >r um+ r> or if
      >r drop 1+ r>
     else
      drop
     then r>
     next drop swap exit
   then drop 2drop -1 literal dup t;
t: m/mod ( d n -- r q )
   dup 0< dup >r if
    negate >r dnegate r>
   then >r dup 0< if
    r@ +
   then r> um/mod r> if
    swap negate swap then exit t;
t: /mod ( n n -- r q ) over 0< swap m/mod t;
t: mod ( n n -- r ) /mod drop t;
t: / ( n n -- q ) /mod nip t;
t: um* ( u u -- ud )
   0 literal swap f literal
    for dup um+ >r >r dup um+ r> + r> if
    >r over um+ r> + then
    next rot drop t;
t: * ( n n -- n ) um* drop t;
t: m* ( n n -- d )
   2dup xor 0< >r abs swap abs um* r> if
    dnegate then exit t;
t: */mod ( n1 n2 n3 -- r q ) >r m* r> m/mod t;
t: */ ( n1 n2 n3 -- q ) */mod nip t;
t: cell+ ( a -- a ) =cell literal + t;
t: cell- ( a -- a ) =cell literal - t;
t: cells ( n -- n ) 1 literal lshift t;
t: bl ( -- 32 ) 20 literal t;
t: >char ( c -- c )
   7f literal and dup 7f literal bl within if
    drop 5f literal then exit t;
t: +! ( n a -- ) tuck @ + swap ! t;
t: 2! ( d a -- ) swap over ! cell+ ! t;
t: 2@ ( a -- d ) dup cell+ @ swap @ t;
t: count ( b -- b +n ) dup 1+ swap c@ t;
t: here ( -- a ) dp @ t;
t: aligned ( b -- a )
   dup 0 literal =cell literal um/mod drop dup if
    =cell literal swap - then + t;
t: align ( -- ) here aligned dp ! t;
t: pad ( -- a ) here 50 literal + aligned t;
t: @execute ( a -- ) @ ?dup if execute then exit t;
t: fill ( b u c -- )
   swap for swap aft 2dup c! 1+ then next 2drop t;
t: erase 0 literal fill t;
t: digit ( u -- c ) 9 literal over < 7 literal and + 30 literal + t;
t: extract ( n base -- n c ) 0 literal swap um/mod swap digit t;
t: <# ( -- ) pad hld ! t;
t: hold ( c -- ) hld @ 1- dup hld ! c! t;
t: # ( u -- u ) base @ extract hold t;
t: #s ( u -- 0 )  begin # dup while repeat t;
t: sign ( n -- ) 0< if 2d literal hold then exit t;
t: #> ( w -- b u ) drop hld @ pad over - t;
t: str ( n -- b u ) dup >r abs <# #s r> sign #> t;
t: hex ( -- ) 10 literal base ! t;
t: decimal ( -- ) a literal base ! t;
t: digit? ( c base -- u t )
   >r 30 literal - 9 literal  over < if
    dup 20 literal > if
	 20 literal  -
	then
	7 literal - dup a literal  < or
   then dup r> u< t;
t: number? ( a -- n t | a f )
   base @ >r 0 literal over count
   over c@ 24 literal = if
    hex swap 1+ swap 1- then
   over c@ 2d literal = >r
   swap r@ - swap r@ + ?dup if
    1-
     for dup >r c@ base @ digit?
       while swap base @ * + r> 1+
     next r@ nip if
	  negate then swap
     else r> r> 2drop 2drop 0 literal
      then dup
   then r> 2drop r> base ! t;
t: ?rx ( -- c t | f ) f001 literal @ 1 literal and 0= invert t;
t: tx! ( c -- )
   begin
    f001 literal @ 2 literal and 0=
   until f000 literal ! t;
t: ?key ( -- c ) '?key @execute t;
t: emit ( c -- ) 'emit @execute t;
t: key ( -- c )
    begin
     ?key
	until f000 literal @ t;
t: nuf? ( -- t ) ?key dup if drop key =cr literal = then exit t;
t: space ( -- ) bl emit t;
t: spaces ( +n -- ) 0 literal max  for aft space then next t;
t: type ( b u -- ) for aft count emit then next drop t;
t: cr ( -- ) =cr literal emit =lf literal emit t;
t: do$ ( -- a ) r> r@ r> count + aligned >r swap >r t; compile-only
t: $"| ( -- a ) do$ noop t; compile-only
t: .$ ( a -- ) count type t;
t: ."| ( -- ) do$ .$ t; compile-only
t: .r ( n +n -- ) >r str r> over - spaces type t;
t: u.r ( u +n -- ) >r <# #s #> r> over - spaces type t;
t: u. ( u -- ) <# #s #> space type t;
t: . ( w -- ) base @ a literal xor if u. exit then str space type t;
t: cmove ( b1 b2 u -- ) for aft >r dup c@ r@ c! 1+ r> 1+ then next 2drop t;
t: pack$ ( b u a -- a ) dup >r 2dup ! 1+ swap cmove r> t;
t: ? ( a -- ) @ . t;
t: (parse) ( b u c -- b u delta ; <string> )
  temp ! over >r dup if
    1- temp @ bl = if
      for
	  count temp @ swap - 0< invert r@ 0> and
	   while next r> drop 0 literal dup exit
	 then 1- r>
    then over swap
      for
	  count temp @ swap - temp @ bl = if
	   0< then
	    while next dup >r else r> drop dup >r 1-
     then over - r> r> - exit
   then over r> - t;
t: parse ( c -- b u ; <string> )
   >r
   tib @ >in @ +
   #tib @ >in @ - r>
   (parse)
   >in +! t;
t: .( ( -- ) 29 literal parse type t; immediate
t: ( ( -- ) 29 literal parse 2drop t; immediate
t: <\> ( -- ) #tib @ >in ! t; immediate
t: \ ( -- ) '\ @execute t; immediate
t: word ( c -- a ; <string> ) parse here cell+ pack$ t;
t: token ( -- a ; <string> ) bl word t;
t: name> ( na -- ca ) count 1f literal and + aligned t;
t: same? ( a a u -- a a f \ -0+ )
   1-
    for aft over r@ + c@
     over r@ + c@ - ?dup
   if r> drop exit then then
    next 0 literal t;
t: find ( a va -- ca na | a f )
   swap
   dup c@ temp !
   dup @ >r
   cell+ swap
    begin @ dup
   if dup @ =mask literal and r@ xor
     if cell+ -1 literal else cell+ temp @ same? then
    else r> drop swap cell- swap exit
   then
    while 2 literal cells -
    repeat r> drop nip cell- dup name> swap t;
t: <name?> ( a -- ca na | a f )
   context dup 2@ xor if cell- then >r
    begin
	 r> cell+ dup >r @ ?dup
    while
	 find ?dup
    until r> drop exit then r> drop 0 literal t;
t: name? ( a -- ca na | a f ) 'name? @execute t;
t: ^h ( bot eot cur -- bot eot cur )
   >r over r@ < dup if
    =bksp literal dup emit space
	emit then r> + t;
t: tap ( bot eot cur c -- bot eot cur )
   dup emit over c! 1+ t;
t: ktap ( bot eot cur c -- bot eot cur )
   dup =cr literal xor if
    =bksp literal xor if
     bl tap exit
    then ^h exit
   then drop nip dup t;
t: accept ( b u -- b u )
   over + over
    begin
    2dup xor
    while
      key dup bl - 7f literal u< if tap else ktap then
    repeat drop over - t;
t: query ( -- ) tib @ 50 literal accept #tib ! drop 0 literal >in ! t;
t: abort2 do$ drop t;
t: abort1 space .$ 3f literal emit cr 'abort @execute abort2 t;
t: <?abort"> if do$ abort1 exit then abort2 t; compile-only
t: forget ( -- )
   token name? ?dup if
    cell- dup dp !
     @ dup context ! last !
     drop exit
   then abort1 t;
t: $interpret ( a -- )
   name? ?dup if
    @ =comp literal and
     <?abort"> $literal compile-only" execute exit
   else number? if
     exit then abort1 then t;
t: [ ( -- ) [t] $interpret literal 'eval ! t; immediate
t: .ok ( -- )
   [t] $interpret literal 'eval @ = if
    ."| $literal  ok"
   then cr t;
t: eval ( -- )
    begin
     token dup c@
    while
	 'eval @execute
    repeat drop .ok t;
t: $eval ( a u -- )
   >in @ >r #tib @ >r tib @ >r
   [t] >in literal 0 literal swap !
    #tib ! tib ! eval r> tib ! r> #tib ! r> >in ! t; compile-only
t: preset ( -- ) =tib literal #tib cell+ ! t;
t: quit ( -- )
   [ begin
	 query eval
   again t;
t: abort drop preset .ok quit t;
t: ' ( -- ca ) token name? if exit then abort1 t;
t: allot ( n -- ) aligned dp +! t;
t: , ( w -- ) here dup cell+ dp ! ! t;
t: call, ( ca -- ) 1 literal rshift 4000 literal or , t; compile-only
t: ?branch ( ca -- ) 1 literal rshift 2000 literal or , t; compile-only
t: branch ( ca -- ) 1 literal rshift 0000 literal or , t; compile-only
t: [compile] ( -- ; <string> ) ' call, t; immediate
t: compile ( -- ) r> dup @ , cell+ >r t; compile-only
t: recurse last @ name> call, t; immediate
t: pick dup 2* 2* =pickbody literal + >r t;
t: literal ( w -- )
   dup 8000 literal and if
    ffff literal xor [t] literal ]asm call asm[ compile invert
   else
    8000 literal or ,
   then exit t; immediate
t: ['] ' [t] literal ]asm call asm[ t; immediate
t: $," ( -- ) 22 literal parse here pack$ count + aligned dp ! t;
t: for ( -- a ) compile [t] >r ]asm call asm[ here t; compile-only immediate
t: begin ( -- a ) here t; compile-only immediate
t: (next) ( n -- ) r> r> ?dup if 1- >r @ >r exit then cell+ >r t; compile-only
t: next ( -- ) compile (next) , t; compile-only immediate
t: (do) ( limit index -- index ) r> dup >r swap rot >r >r cell+ >r t; compile-only
t: do ( limit index -- ) compile (do) 0 literal , here t; compile-only immediate
t: (leave) r> drop r> drop r> drop t; compile-only
t: leave compile (leave) noop t; compile-only immediate
t: (loop)
   r> r> 1+ r> 2dup <> if
    >r >r @ >r exit
   then >r 1- >r cell+ >r t; compile-only
t: (unloop) r> r> drop r> drop r> drop >r t; compile-only
t: unloop compile (unloop) noop t; compile-only immediate
t: (?do)
   2dup <> if
     r> dup >r swap rot >r >r cell+ >r exit
   then 2drop exit t; compile-only
t: ?do ( limit index -- ) compile (?do) 0 literal , here t; compile-only immediate
t: loop ( -- ) compile (loop) dup , compile (unloop) cell- here 1 literal rshift swap ! t; compile-only immediate
t: (+loop)
   r> swap r> r> 2dup - >r
   2 literal pick r@ + r@ xor 0< 0=
   3 literal pick r> xor 0< 0= or if
    >r + >r @ >r exit
   then >r >r drop cell+ >r t; compile-only
t: +loop ( n -- ) compile (+loop) dup , compile (unloop) cell- here 1 literal rshift swap ! t; compile-only immediate
t: (i) ( -- index ) r> r> tuck >r >r t; compile-only
t: i ( -- index ) compile (i) noop t; compile-only immediate
t: until ( a -- ) ?branch t; compile-only immediate
t: again ( a -- ) branch t; compile-only immediate
t: if ( -- a ) here 0 literal ?branch t; compile-only immediate
t: then ( a -- ) here 1 literal rshift over @ or swap ! t; compile-only immediate
t: repeat ( a a -- ) branch [t] then ]asm call asm[ t; compile-only immediate
t: skip here 0 literal branch t; compile-only immediate
t: aft ( a -- a a ) drop [t] skip ]asm call asm[ [t] begin ]asm call asm[ swap t; compile-only immediate
t: else ( a -- a ) [t] skip ]asm call asm[ swap [t] then ]asm call asm[ t; compile-only immediate
t: while ( a -- a a ) [t] if ]asm call asm[ swap t; compile-only immediate
t: (case) r> swap >r >r	t; compile-only
t: case compile (case) 30 literal t; compile-only immediate
t: (of) r> r@ swap >r = t; compile-only
t: of compile (of) [t] if ]asm call asm[ t; compile-only immediate
t: endof [t] else ]asm call asm[ 31 literal t; compile-only immediate
t: (endcase) r> r> drop >r t;
t: endcase
   begin
    dup 31 literal =
   while
    drop			
    [t] then ]asm call asm[
   repeat
   30 literal <> <?abort"> $literal bad case construct."
   compile (endcase) noop t; compile-only immediate
t: $" ( -- ; <string> ) compile $"| $," t; compile-only immediate
t: ." ( -- ; <string> ) compile ."| $," t; compile-only immediate
t: >body ( ca -- pa ) cell+ t;
t: (to) ( n -- ) r> dup cell+ >r @ ! t; compile-only
t: to ( n -- ) compile (to) ' >body , t; compile-only immediate
t: (+to) ( n -- ) r> dup cell+ >r @ +! t; compile-only
t: +to ( n -- ) compile (+to) ' >body , t; compile-only immediate
t: get-current ( -- wid ) current @ t;
t: set-current ( wid -- ) current ! t;
t: definitions ( -- ) context @ set-current t;
t: ?unique ( a -- a )
   dup get-current find if ."| $literal  redef " over .$ then drop t;
t: <$,n> ( na -- )
   dup c@ if
    ?unique
	dup count + aligned
	dp !
    dup last !
    cell-
    get-current @
    swap ! exit
   then drop $"| $literal name" abort1 t;
t: $,n ( na -- ) '$,n @execute t;
t: $compile ( a -- )
   name? ?dup if
    @ =imed literal and if
	 execute exit
	 else call, exit
	then
   then
   number? if
     [t] literal ]asm call asm[ exit then abort1 t;
t: abort" compile <?abort"> $," t; immediate
t: <overt> ( -- ) last @ get-current ! t;
t: overt ( -- ) 'overt @execute t;
t: exit r> drop t;
t: <;> ( -- )
   compile [t] exit ]asm call asm[
   [ overt 0 literal here ! t; compile-only immediate
t: ; ( -- ) '; @execute t; compile-only immediate
t: ] ( -- ) [t] $compile literal 'eval ! t;
t: : ( -- ; <string> ) token $,n ]  t;
t: immediate ( -- ) =imed literal last @ @ or last @ ! t;
t: user ( u -- ; <string> ) token $,n overt compile douser , t;
t: <create> ( -- ; <string> ) token $,n overt [t] dovar ]asm literal asm[ call, t;
t: create ( -- ; <string> ) 'create @execute t;
t: variable ( -- ; <string> ) create 0 literal , t;
t: (does>) ( -- )
   r> 1 literal rshift here 1 literal rshift
   last @ name> dup cell+ ]asm 8000 literal asm[ or , ! , t; compile-only
t: compile-only ( -- ) =comp literal last @ @ or last @ ! t;
t: does> ( -- ) compile (does>) noop t; immediate
t: char ( <char> -- char ) ( -- c ) bl word 1+ c@ t;
t: [char] char [t] literal ]asm call asm[ t; immediate
t: constant create , (does>) @ t;
t: defer create 0 literal , 
   (does>) 
    @ ?dup 0 literal =
   <?abort"> $literal uninitialized" execute t;
t: is ' >body ! t; immediate
t: .id ( na -- )
   ?dup if
   count 1f literal and type exit then
   cr ."| $literal {noname}" t;
t: wordlist ( -- wid ) align here 0 literal , dup current cell+ dup @ , ! 0 literal , t;
t: order@ ( a -- u*wid u ) dup @ dup if >r cell+ order@ r> swap 1+ exit then nip t;
t: get-order ( -- u*wid u ) context order@ t;
t: >wid ( wid -- ) cell+ t;
t: .wid ( wid -- )
   space dup >wid cell+ @ ?dup if .id drop exit then 0 literal u.r t;
t: !wid ( wid -- ) >wid cell+ last @ swap ! t;
t: vocs ( -- ) ( list all wordlists )
   cr ."| $literal vocs:" current cell+
   begin
    @ ?dup
   while
    dup .wid >wid
   repeat t;
t: order ( -- ) ( list search order )
   cr ."| $literal search:" get-order
   begin
    ?dup
   while
    swap .wid 1-
   repeat
   cr ."| $literal define:" get-current .wid t;
t: set-order ( u*wid n -- ) ( 16.6.1.2197 )
   dup -1 literal = if
   drop forth-wordlist 1 literal then
   =vocs literal over u< <?abort"> $literal over size of #vocs"
   context swap
   begin
    dup
   while
    >r swap over ! cell+ r>
    1-
   repeat swap ! t;
t: only ( -- ) -1 literal set-order t;
t: also ( -- ) get-order over swap 1+ set-order t;
t: previous ( -- ) get-order swap drop 1- set-order t;
t: >voc ( wid 'name' -- )
   create dup , !wid
   (does>)
	 @ >r get-order swap drop r> swap set-order t;
t: widof ( "vocabulary" -- wid ) ' >body @ t;
t: vocabulary ( 'name' -- ) wordlist >voc t;
t: _type ( b u -- )  for aft count >char emit then next drop t;
t: dm+ ( a u -- a )
   over 4 literal u.r space
   for aft count 3 literal u.r then next t;
t: dump ( a u -- )
   base @ >r hex 10 literal /
   for cr 10 literal 2dup dm+ -rot
   2 literal spaces _type
   next drop r> base ! t;
t: .s ( ... -- ... ) cr sp@ 1- f literal and for r@ pick . next ."| $literal <tos" t;
t: (>name) ( ca va -- na | f )
   begin
    @ ?dup
   while
    2dup name> xor
     while cell-
   repeat nip exit
   then drop 0 literal t;
t: >name ( ca -- na | f )
   >r get-order
   begin
	  ?dup
   while
	  swap
	  r@ swap
	  (>name)
	  ?dup if
		>r
		1- for aft drop then next
		r> r> drop
		exit
	  then
	  1-
   repeat
   r> drop 0 literal t;
t: see ( -- ; <string> )
   ' cr
   begin
    dup @ ?dup 700c literal xor
   while
    3fff literal and 1 literal lshift
	>name ?dup if
     space .id
	else
	  dup @ 7fff literal and u.
	then
	cell+
   repeat 2drop t;
t: (words) ( -- )
   cr
   begin
    @ ?dup
   while
    dup .id space cell-
   repeat t;
t: words
   get-order
   begin
	  ?dup
   while
	  swap
	  cr cr ."| $literal :" dup .wid cr
	  (words)
	  1-
   repeat t;
t: ver ( -- n ) =ver literal 100 literal * =ext literal + t;
t: hi ( -- )
   cr ."| $literal eforth j1 v"
	base @ hex
	ver <# # # 2e literal hold # #>
	type base ! cr t;
t: cold ( -- )
   =uzero literal =up literal =udiff literal cmove
   preset forth-wordlist dup context ! dup current 2! overt
   4000 literal cell+ dup cell- @ $eval
   'boot @execute
   quit
   cold t;

target.1 -order set-current

there 			[u] dp t!
[last] 			[u] last t!
[t] ?rx			[u] '?key t!
[t] tx!			[u] 'emit t!
[t] <\>			[u] '\ t!
[t] $interpret	[u] 'eval  t!
[t] abort		[u] 'abort t!
[t] hi			[u] 'boot t!
[t] <name?>		[u] 'name? t!
[t] <overt>		[u] 'overt t!
[t] <$,n>		[u] '$,n t!
[t] <;>			[u] '; t!
[t] <create>	[u] 'create t!
[t] cold 		2/ =cold t!

save-target j1.bin
save-hex j1.hex

meta.1 -order

bye
