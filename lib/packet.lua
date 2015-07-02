--packet encoding/decoding

local VERSION = "20150618"
local TAG = "SHELOB"
local _M = {}

local function _encode(obj, stream)
	--print("Encoding "..tostring(obj))
	local typ = type(obj)
	if typ == "boolean" then
		if obj==true then
			stream:write("t")
		else
			stream:write("f")
		end
	elseif typ == "number" then
		stream:write("N")
		stream:write(tostring(obj))
		stream:write("\n")
	elseif typ == "string" then
		stream:write("S")
		stream:write(tostring(#obj))
		stream:write("\n")
		if #obj > 0 then
			stream:write(obj)
		end
	elseif typ == "table" then
		local keys = {}
		for k, v in pairs (obj) do
			table.insert(keys,k)
		end
		stream:write("T")
		stream:write(tostring(#keys))
		stream:write("\n")
		for i, key in ipairs(keys) do
			_encode(key,stream)
			_encode(obj[key], stream)
		end
	else
		_encode("*ERROR* Cannot encode "..typ.." *ERROR*", stream)
	end
end

_M.encode = function(object, stream)
	stream:write(TAG)
	stream:write(VERSION)
	_encode(object, stream)
	return true
end

local read_next_line = function(stream)
	if stream.setsockopt then --It's a Tarantool socket
		local txt = stream:read("\n")
		local line = assert(txt:match("(.*)\n$"))
		return line
	end
	return assert(stream:read("*l"))
end

local function _decode(st)
	local function __decode(stream)
		local typ = stream:read(1)
		--print("Type "..typ)
		if typ == "t" then
			return true
		elseif typ == "f" then
			return false
		elseif typ == "N" then
			local num = read_next_line(stream)
			return (assert(tonumber(num), "This is not a number"))
		elseif typ == "S" then
			local num = read_next_line(stream)
			num = assert(tonumber(num), "This is not a number")
			if str == 0 then
				return ""
			end
			local str = stream:read(num)
			return (str)
		elseif typ == "T" then
			local num = read_next_line(stream)
			num = assert(tonumber(num), "This is not a number: "..tostring(num))
			assert(num >= 0)
			--	print("table of "..num.." items")
			local tbl = {}
			for i = 1, num do
				local k,v = _decode(stream), _decode(stream)
				tbl[k] = v
			end
			return tbl
		else
			error("Unknown type: "..typ)
		end
		error("WTF")
	end
	local obj = __decode(st)
	--print("Decoded: "..tostring(obj))
	return(obj)
end

_M.decode = function(stream)
	local tag = assert(stream:read(6), "Cannot get opening id tag (connection aborted?)")
	assert(tag == TAG, "Wrong id tag: "..tostring(tag))
	assert(stream:read(8) == VERSION, "Wrong packet version")
	local result = _decode(stream)
	assert(result ~= nil)
	return result
end

local function test()
	_M.encode({array={100,200,300}, string="text\ntext2", funkce=function(x) return x+x end, booleans={pravda=true, lez=false}}, io.output())
	print("\n\n")
	_M.encode({ping=1}, io.output())
end

if arg[1] == "test" then
	test()
end

return _M
