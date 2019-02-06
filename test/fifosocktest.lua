OVL={}
OVL.fifo = function() return dofile("./fifo/fifo.lua") end
package.loaded["fifosock"] = dofile("./net/fifosock.lua")

verbose = false

vprint = verbose and print or function() end
outs = {}

fakesock = {
  cb = nil,
  on = function(this, _, cb) vprint("CBSET") this.cb = cb end,
  send = function(this, s) vprint("SEND", verbose and s) table.insert(outs, s) end,
}
function sent() vprint("CB") fakesock.cb() end

fsend = require "fifosock" (fakesock)
function fcheck(x)
  vprint ("CHECK", verbose and x)
  assert (#outs > 0)
  assert (x == outs[1])
  table.remove(outs, 1)
end
function fsendc(x) fsend(x) fcheck(x) end
function fchecke() vprint("CHECKE") assert (#outs == 0) end

fsendc("abracadabra none")
sent() ; fchecke()

fsendc("abracadabra three")
fsend("short")
fsend("string")
fsend("build")
sent() ; fcheck("shortstringbuild")
sent() ; fchecke()

-- Hit default FSMALLLIM while building up
fsendc("abracadabra lots small")
for i = 1, 34 do fsend("a") end
sent() ; fcheck(string.rep("a", 32))
sent() ; fcheck("aa")
sent() ; fchecke()

-- Hit string length while building up
fsendc("abracadabra overlong")
for i = 1, 10 do fsend(string.rep("a",32)) end
sent() ; fcheck(string.rep("a", 256))
sent() ; fcheck(string.rep("a", 64))
sent() ; fchecke()

-- Hit neither before sending a big string
fsendc("abracadabra mid long")
for i = 1, 6 do fsend(string.rep("a",32)) end
fsend(string.rep("b", 256))
for i = 1, 6 do fsend(string.rep("c",32)) end
sent() ; fcheck(string.rep("a", 192))
sent() ; fcheck(string.rep("b", 256))
sent() ; fcheck(string.rep("c", 192))
sent() ; fchecke()

-- send a huge string
fsend(string.rep("a",256) .. string.rep("b", 256) .. string.rep("c", 260))
fcheck(string.rep("a",256))
sent() ; fcheck(string.rep("b",256))
sent() ; fcheck(string.rep("c",260))
sent() ; fchecke()

-- test a lazy generator
local ix = 0
local function gen() vprint("GEN", ix); ix = ix + 1; return ("a" .. ix), ix < 3 and gen end
fsend(gen)
fsend("b")
fcheck("a1")
sent() ; fcheck("a2")
sent() ; fcheck("a3")
sent() ; fcheck("b")
sent() ; fchecke()

-- test a completeion-like callback that does send text
local ix = 0
local function gen() vprint("GEN"); ix = 1; return "efgh", nil end
fsend("abcd"); fsend(gen); fsend("ijkl")
assert (ix == 0)
         fcheck("abcd"); assert (ix == 0)
sent() ; fcheck("efgh"); assert (ix == 1); ix = 0
sent() ; fcheck("ijkl"); assert (ix == 0)
sent() ; fchecke()

-- and one that doesn't
local ix = 0
local function gen() vprint("GEN"); ix = 1; return nil, nil end
fsend("abcd"); fsend(gen); fsend("ijkl")
assert (ix == 0)
         fcheck("abcd"); assert (ix == 0)
sent() ; fcheck("ijkl"); assert (ix == 1); ix = 0
sent() ; fchecke()     ; assert (ix == 0)

print("All tests OK")