local e=type(package)=="table"and type(package.preload)=="table"and package.preload or{}local t=require if type(t)~=
"function"then local a={}local o={}t=function(i)local n=o[i]if n~=nil then if n==a then error(
"loop or previous error loading module '"..i.."'",2)end return n end o[i]=a local s=e[i]if s then n=s(i)else error(
"cannot load '"..i.."'",2)end if n==nil then n=true end o[i]=n return n end end e["objects"]=function(...)local a=t
"deflate".inflate_zlib local o=t"metis.crypto.sha1"local i,n,s,h=bit32.band,bit32.bor,bit32.lshift,bit32.rshift local r,
d,l=string.byte,string.format,string.sub local u={[0]="none","commit","tree","blob","tag",nil,"ofs_delta","ref_delta",
"any","max"}local function c(j)return u[j.ty]or"?"end local m=("luagit-%08x"):format(math.random(0,2^24))local function 
f()os.queueEvent(m)os.pullEvent(m)end local w=("%02x"):rep(20)local function y(j)local x=d(w,r(j,-20,-1))local z=o(j:sub(
1,-21))if x~=z then error(("checksum mismatch: expected %s, got %s"):format(x,z))end j=j:sub(1,-20)local _=1 local 
function E(A)if A<=0 then error("len < 0",2)end if _>#j then error("end of stream")end local O=_ _=_+A local I=l(j,O,_-1
)if#I~=A then error("expected "..A.." bytes, got"..#I)end return I end local function T()if _>#j then error(
"end of stream")end local A=_ _=_+1 return r(j,A)end return{offset=function()return _-1 end,read8=T,read16=function()
return(T()*(2^8))+T()end,read32=function()return(T()*(2^24))+(T()*(2^16))+(T()*(2^8))+T()end,read=E,close=function()if _
~=#j then error(("%d of %d bytes remaining"):format(#j-_+1,#j))end end}end local function p(j,x)local z,_={},1 a{input=j
.read8,output=function(T)z[_],_=string.char(T),_+1 end}local E=table.concat(z)if#E~=x then error((
"expected %d decompressed bytes, got %d"):format(x,#E))end return E end local function v(j,x)local z=1 local function _(
)local N=r(x,z)z=z+1 local S=i(N,0x7f)local H=7 while i(N,0x80)~=0 do N,z=r(x,z),z+1 S,H=S+s(i(N,0x7f),H),H+7 end return 
S end local E=_()local T=_()if E~=#j then error(("expected original of size %d, got size %d"):format(E,#j))end local A,O
={},1 while z<=#x do local N=r(x,z)z=z+1 if i(N,0x80)~=0 then local S,H=0,0 if i(N,0x01)~=0 then S,z=n(S,r(x,z)),z+1 end 
if i(N,0x02)~=0 then S,z=n(S,s(r(x,z),8)),z+1 end if i(N,0x04)~=0 then S,z=n(S,s(r(x,z),16)),z+1 end if i(N,0x08)~=0 
then S,z=n(S,s(r(x,z),24)),z+1 end if i(N,0x10)~=0 then H,z=n(H,r(x,z)),z+1 end if i(N,0x20)~=0 then H,z=n(H,s(r(x,z),8)
),z+1 end if i(N,0x40)~=0 then H,z=n(H,s(r(x,z),16)),z+1 end if H==0 then H=0x10000 end A[O],O=l(j,S+1,S+H),O+1 elseif N
>0 then A[O],O=l(x,z,z+N-1),O+1 z=z+N else error(("unknown opcode '%02x'"):format(N))end end local I=table.concat(A)if T
~=#I then error(("expected patched of size %d, got size %d"):format(T,#I))end return I end local function b(j,x)local z=
j.read8()local _=i(h(z,4),7)local E=i(z,15)local T=4 while i(z,0x80)~=0 do z=j.read8()E=E+s(i(z,0x7f),T)T=T+7 end local 
A if _>=1 and _<=4 then A=p(j,E)elseif _==6 then A=p(j,E)error("ofs_delta not yet implemented")elseif _==7 then local I=
w:format(j.read(20):byte(1,20))local N=p(j,E)local S=x[I]if not S then error(("cannot find object %d to apply diff"):
format(I))return end _=S.ty A=v(S.data,N)else error(("unknown object of type '%d'"):format(_))end local O=("%s %d\0"):
format(u[_],#A)..A local o=o(O)x[o]={ty=_,data=A,sha=o}end local function g(j,x)local z=j.read(4)if z~="PACK"then error(
"expected PACK, got "..z,0)end local _=j.read32()local E=j.read32()local T={}for A=1,E do if x then x(A,E)end f()b(j,T)
end return T end local function k(j,x,z,_)if not z then z=""end if not _ then _={}end local E=1 while E<=#x do local T,A
,O,I=x:find("^(%x+) ([^%z]+)%z",E)if not A then break end I=z..I local o=x:sub(A+1,A+20):gsub(".",function(S)return(
"%02x"):format(string.byte(S))end)local N=j[o]if not N then error(("cannot find %s %s (%s)"):format(O,I,o))end if N.ty==
3 then _[I]=N.data elseif N.ty==2 then k(j,N.data,I.."/",_)else error("unknown type for "..I.." ("..o.."): "..c(N))end E
=A+21 end return _ end local function q(j,o)local x=j[o]if not x then error("cannot find commit "..o)end if x.ty~=1 then 
error("Expected commit, got "..u[x.ty])end local z=x.data:match("tree (%x+)\n")if not z then error(
"Cannot find tree from commit")end local _=j[z]if not _ then error("cannot find tree "..z)end if _.ty~=2 then error(
"Expected tree, got ".._[_.ty])end return k(j,_.data)end return{reader=y,unpack=g,build_tree=k,build_commit=q,type=c}end 
e["network"]=function(...)local function a(d)return("%04x%s\n"):format(5+#d,d)end local function o(d,...)return a(d:
format(...))end local i="0000"local function n(d)local l=d.read(4)if l==nil or l==""then return nil end local u=tonumber(
l,16)if u==nil then error(("read_pkt_line: cannot convert %q to a number"):format(l))elseif u==0 then return false,l 
else return d.read(u-4),l end end local function s(d,l,u)if type(l)=="table"then l=table.concat(l)end local c,m=http.
request(d,l,{['User-Agent']='CCGit/1.0',['Content-Type']=u},true)if c then while true do local f,w,y,p=os.pullEvent()if 
f=="http_success"and w==d then return true,y elseif f=="http_failure"and w==d then printError("Cannot fetch "..d..": "..
y)return false,p end end else printError("Cannot fetch "..d..": "..m)return false,nil end end local function h(...)
local d,l,u=s(...)if not d then if u then print(u.getStatusCode())print(textutils.serialize(u.getResponseHeaders()))
print(u.readAll())end error("Cannot fetch",0)end return l end local function r(d)local l={}while true do local u=n(d)if 
u==nil then break end l[#l+1]=u end d.close()return l end return{read_pkt_line=n,force_fetch=h,receive=r,pkt_linef=o,
flush_line=i}end e["deflate"]=function(...)local a,o,i,n,s,h,r,d,l=assert,error,ipairs,pairs,tostring,type,setmetatable,
io,math local u,c,m=table.sort,l.max,string.char local f,w,y=bit32.band,bit32.lshift,bit32.rshift local function p(L)
local U={}U.outbs=L U.len=0 U.window={}U.window_pos=1 return U end local function v(L,U)local C=L.window_pos L.outbs(U)L
.len=L.len+1 L.window[C]=U L.window_pos=C%32768+1 end local function b(L)return a(L,'unexpected end of file')end local 
function g(L)return r({},{__index=function(U,C)local M=L(C)U[C]=M return M end})end local k=g(function(L)return 2^L end)
local function q(L)local U=0 local C=0 local M={type="bitstream"}function M:nbits_left_in_byte()return C end function M:
read(F)F=F or 1 while C<F do local Y=L()if not Y then return end U=U+w(Y,C)C=C+8 end local W if F==0 then W=0 elseif F==
32 then W=U U=0 else W=f(U,y(0xffffffff,32-F))U=y(U,F)end C=C-F return W end return M end local function j(L)if h(L)==
"table"and L.type=="bitstream"then return L elseif d.type(L)=='file'then return q(function()local U=L:read(1)if U then 
return U:byte()end end)elseif h(L)=="function"then return q(L)else o'unrecognized type'end end local function x(L)local 
U if d.type(L)=='file'then U=function(C)L:write(m(C))end elseif h(L)=='function'then U=L else o('unrecognized type: '..s(
L))end return U end local function z(L,U)local C={}if U then for B,G in n(L)do if G~=0 then C[#C+1]={val=B,nbits=G}end 
end else for B=1,#L-2,2 do local G,K,Q=L[B],L[B+1],L[B+2]if K~=0 then for J=G,Q-1 do C[#C+1]={val=J,nbits=K}end end end 
end u(C,function(B,G)return B.nbits==G.nbits and B.val<G.val or B.nbits<G.nbits end)local M=1 local F=0 for B,G in i(C)
do if G.nbits~=F then M=M*k[G.nbits-F]F=G.nbits end G.code=M M=M+1 end local W=l.huge local Y={}for B,G in i(C)do W=l.
min(W,G.nbits)Y[G.code]=G.val end local P=function(B,F)local G=0 for K=1,F do G=w(G,1)+f(B,1)B=y(B,1)end return G end 
local V=g(function(B)return k[W]+P(B,W)end)function C:read(B)local M=1 local F=0 while 1 do if F==0 then M=V[b(B:read(W)
)]F=F+W else local K=b(B:read())F=F+1 M=M*2+K end local G=Y[M]if G then return G end end end return C end local 
function _(L)local U=L:read(4)local C=L:read(4)local M=L:read(5)local F=L:read(1)local W=L:read(2)local Y=C*16+U local P
=M+F*32+W*64 if U~=8 then o("unrecognized zlib compression method: "..U)end if C>7 then o(
"invalid zlib window size: cinfo="..C)end local V=2^(C+8)if(Y*256+P)%31~=0 then o("invalid zlib header (bad fcheck sum)"
)end if F==1 then o("FIX:TODO - FDICT not currently implemented")local B=L:read(32)end return V end local function E(L)
local U=L:read(5)local C=L:read(5)local M=b(L:read(4))local F=M+4 local W={}local Y={16,17,18,0,8,7,9,6,10,5,11,4,12,3,
13,2,14,1,15}for J=1,F do local X=L:read(3)local Z=Y[J]W[Z]=X end local P=z(W,true)local function V(J)local X={}local Z 
local ee=0 while ee<J do local ea=P:read(L)local eo if ea<=15 then eo=1 Z=ea elseif ea==16 then eo=3+b(L:read(2))elseif 
ea==17 then eo=3+b(L:read(3))Z=0 elseif ea==18 then eo=11+b(L:read(7))Z=0 else o'ASSERT'end for ei=1,eo do X[ee]=Z ee=ee
+1 end end local et=z(X,true)return et end local B=U+257 local G=C+1 local K=V(B)local Q=V(G)return K,Q end local T 
local A local O local I local function N(L,U,C,M)local F=C:read(L)if F<256 then v(U,F)elseif F==256 then return true 
else if not T then local X={[257]=3}local Z=1 for ee=258,285,4 do for et=ee,ee+3 do X[et]=X[et-1]+Z end if ee~=258 then 
Z=Z*2 end end X[285]=258 T=X end if not A then local X={}for Z=257,285 do local ee=c(Z-261,0)X[Z]=y(ee,2)end X[285]=0 A=
X end local W=T[F]local Y=A[F]local P=L:read(Y)local V=W+P if not O then local X={[0]=1}local Z=1 for ee=1,29,2 do for 
et=ee,ee+1 do X[et]=X[et-1]+Z end if ee~=1 then Z=Z*2 end end O=X end if not I then local X={}for Z=0,29 do local ee=c(Z
-2,0)X[Z]=y(ee,1)end I=X end local B=M:read(L)local G=O[B]local K=I[B]local Q=L:read(K)local J=G+Q for X=1,V do local Z=(
U.window_pos-1-J)%32768+1 v(U,a(U.window[Z],'invalid distance'))end end return false end local function S(L,U)local C=L:
read(1)local M=L:read(2)local F=0 local W=1 local Y=2 local P=3 if M==F then L:read(L:nbits_left_in_byte())local V=L:
read(16)local B=b(L:read(16))for G=1,V do local K=b(L:read(8))v(U,K)end elseif M==W or M==Y then local V,B if M==Y then 
V,B=E(L)else V=z{0,8,144,9,256,7,280,8,288,nil}B=z{0,5,32,nil}end repeat local G=N(L,U,V,B)until G else o(
'unrecognized compression type '..M)end return C~=0 end local function H(L)local U=j(L.input)local C=x(L.output)local M=
p(C)repeat local F=S(U,M)until F end local function R(L,U)local C=U%65536 local M=(U-C)/65536 C=(C+L)%65521 M=(M+C)%
65521 return M*65536+C end local function D(L)local U=j(L.input)local C=x(L.output)local M=L.disable_crc if M==nil then 
M=false end local F=_(U)local W=1 H{input=U,output=M and C or function(K)W=R(K,W)C(K)end,len=L.len}U:read(U:
nbits_left_in_byte())local Y=U:read(8)local P=U:read(8)local V=U:read(8)local B=U:read(8)local G=((Y*256+P)*256+V)*256+B 
if not M then if W~=G then o('invalid compressed data--crc error')end end end return{inflate=H,inflate_zlib=D}end e[
"clone"]=function(...)do local d={["metis.argparse"]="src/metis/argparse.lua",["metis.crypto.sha1"]=
"src/metis/crypto/sha1.lua",["metis.timer"]="src/metis/timer.lua"}package.loaders[#package.loaders+1]=function(l)local u
=d[l]if not u then return nil,"not a metis module"end local c="/.cache/metis/ae11085f261e5b506654162c80d21954c0d54e5e/"
..u if not fs.exists(c)then local w="https://raw.githubusercontent.com/SquidDev-CC/metis/ae11085f261e5b506654162c80d21954c0d54e5e/"
..u local y,p=http.get(w)if not y then return nil,"Cannot download "..w..": "..p end local v=fs.open(c,"w")v.write(y.
readAll())v.close()y.close()end local m,f=loadfile(c,nil,_ENV)if m then return m,c else return nil,f end end end local a
=t"network"local o=t"objects"local i,n=...if not i or i=="-h"or i=="--help"then error("clone.lua URL [name]",0)end if i:
sub(-1)=="/"then i=i:sub(1,-2)end n=n or fs.getName(i):gsub("%.git$","")local s=shell.resolve(n)if fs.exists(s)then 
error(("%q already exists"):format(n),0)end local function h(d)local l=""for u in d:gmatch("[^\n]+")do l=u end term.
setCursorPos(1,select(2,term.getCursorPos()))term.clearLine()term.write(l)end local r do h("Cloning from "..i)local d=a.
force_fetch(i.."/info/refs?service=git-upload-pack")local l=a.receive(d)local u=("%x"):rep(40)local c={}local m={}for f=
1,#l do local w=l[f]if w~=false and w:sub(1,1)~="#"then local y,n=w:match("("..u..") ([^%z\n]+)")if y and n then m[n]=y 
local p=w:match("%z([^\n]+)\n")if p then for v in(p.." "):gmatch("%S+")do local b=v:find("=")if b then c[v:sub(1,b-1)]=v
:sub(b+1)else c[v]=true end end end else printError("Unexpected line: "..w)end end end r=m['HEAD']or m[
'refs/heads/master']or error("Cannot find master",0)if not c['shallow']then error(
"Server does not support shallow fetching",0)end if not c['side-band-64k']then error("Server does not support side band"
,0)end end do local d=a.force_fetch(i.."/git-upload-pack",{a.pkt_linef("want %s side-band-64k shallow",r),a.pkt_linef(
"deepen 1"),a.flush_line,a.pkt_linef("done")},"application/x-git-upload-pack-request")local l,r={},nil while true do 
local m=a.read_pkt_line(d)if m==nil then break end if m==false or m=="NAK\n"then elseif m:byte(1)==1 then table.insert(l
,m:sub(2))elseif m:byte(1)==2 or m:byte(1)==3 then h(m:sub(2):gsub("\r","\n"))elseif m:find("^shallow ")then r=m:sub(#(
"shallow ")+1)else printError("Unknown line: "..tostring(m))end end d.close()local u=o.reader(table.concat(l))local c=o.
unpack(u,function(m,f)h(("Extracting %d/%d (%.2f%%)"):format(m,f,m/f*100))end)u.close()if not r then error(
"Cannot find HEAD commit",0)end for m,f in pairs(o.build_commit(c,r))do local w=fs.open(fs.combine(s,fs.combine(m,"")),
"wb")w.write(f)w.close()end end h(("Cloned to %q"):format(n))print()end return e["clone"](...)