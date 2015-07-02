local _M = {}

local MY_DIR = RUMCAJS.app_dir.."fffilm_chat/"
local HISTORY_FILENAME = "/var/tmp/fuxoft_rumcajs_ffchat_history.txt"
local USERS_FILENAME = "/var/tmp/fuxoft_rumcajs_ffchat_users.txt"
local SERIALIZE = dofile("/home/fuxoft/work/web/private/lib/serialize.lua")
local TASKER = require("tasker")


local function format_time(time)
	time = time or os.time()
	local struct = os.date("*t", time)
	for i,key in ipairs{"hour","min","sec"} do
		struct["xx"..key] = string.format("%02d", struct[key])
	end
	struct.hhmm = struct.xxhour..":"..struct.xxmin
	struct.hhmmss = struct.hhmm..":"..struct.xxsec
	return struct
end

local BOT_KEY = assert(dofile("/home/fuxoft/.private.lua").telegram.fffilmchatbot)
local function telegram_poll()
	local maybe_offset = ""
	local offset = _M.last_update_id
	if offset then
		offset = tonumber(offset) + 1
		maybe_offset = "&offset="..offset
	end
	local txt, err = TASKER.http_request(string.format("https://api.telegram.org/bot%s/getUpdates?timeout=10%s", BOT_KEY,maybe_offset))
	--sock:send(string.format("GET /bot%s/getUpdates?timeout=10%s HTTP/1.0\r\n\r\n", BOT_KEY,maybe_offset))
	return txt, err
end

local function telegram_post(args)
	assert(args.method, "No method specified")
	local data = assert(args.data, "No data supplied")
	local enctbl = {}
	for k,v in pairs (data) do
		v = tostring(v)
		local enc = v:gsub("[^a-zA-Z0-9]",function(char)
			return (string.format("%%%02x",char:byte()))
		end)
		table.insert(enctbl, k.."="..enc)
	end
	local encoded = table.concat(enctbl,"&")
	local txt, stat = TASKER.http_request(string.format("https://api.telegram.org/bot%s/%s", BOT_KEY, args.method), encoded)
	if not stat == 200 then
		LOG.warn("Post status is not 200. Got: "..tostring(txt).."/"..tostring(stat))
	else
		local ok = txt:match('"ok":true')
		if not ok then
			LOG.warn("-------------Post didn't get json OK but: "..txt.."\n--------The post was: "..encoded)
		end
	end
	return txt
end

local function actually_send_messages()
	local msgs = assert(_M.messages_to_send)
	_M.messages_to_send = {}
	LOG.debug("Actually sending "..#msgs.." messages.")
	TASKER.add_pthread(function()
		for i, msgitem in ipairs (msgs) do
			telegram_post(msgitem)
		end
		LOG.debug("Sent messages.")
	end)
end

local function send_message(args)
	if not _M.messages_to_send then
		_M.messages_to_send = {}
	end
	assert(args.receiver)
	assert(args.text)
	local data = {chat_id = args.receiver, text = args.text}
	table.insert(_M.messages_to_send, {data=data, method = "sendMessage"})
end
--[[
{"ok":true,"result":[

{"update_id":315634024,
"message":{"message_id":6,"from":{"id":70045183,"first_name":"Frantisek","last_name":"Fuka","username":"fuxoft"},"chat":{"id":70045183,"first_name":"Frantisek","last_name":"Fuka","username":"fuxoft"},"date":1435415264,"text":"Ahoj"}},

{"update_id":315634025,
"message":{"message_id":7,"from":{"id":70045183,"first_name":"Frantisek","last_name":"Fuka","username":"fuxoft"},"chat":{"id":70045183,"first_name":"Frantisek","last_name":"Fuka","username":"fuxoft"},"date":1435415430,"text":"Ooo"}},

{"update_id":315634026,
"message":{"message_id":8,"from":{"id":70045183,"first_name":"Frantisek","last_name":"Fuka","username":"fuxoft"},"chat":{"id":70045183,"first_name":"Frantisek","last_name":"Fuka","username":"fuxoft"},"date":1435415762,"document":{"file_name":"2015-05-14 Nova 3.x.novabackup","mime_type":"application\/octet-stream","thumb":{},"file_id":"BQADBAADCgAD_80sBM8fVn5FAAHSvAI","file_size":1062651}}}]}

user:
.name
.noecho (boolean)
.ts

]]

local function update_history(msgtext)
	local history_prefix = "/home/fuxoft/work/web/fuxoft.cz/fffilm/ffchat/_nosync/log_telegram_"
	assert(type(msgtext)=="string")
	assert(#msgtext > 1)
	local time = os.time()
	local history = _M.history
	local item = {text = msgtext, ts = time}
	table.insert(history, item)
	while #history > 100 do
		table.remove(history,1)
	end
	SERIALIZE.save(history, HISTORY_FILENAME)

	local tstruct = format_time(time)
	local fname = history_prefix..tstruct.year.."_"..string.format("%02d",tstruct.month).."_"..string.format("%02d",tstruct.day)..".html"
	local fd = assert(io.open(fname, "a+"))
	fd:write("<div>")
	fd:write(tstruct.hhmm)
	fd:write(" ")
	local escaped = msgtext:gsub("&","&amp;")
	escaped = escaped:gsub("<","&lt;")
	fd:write(escaped)
	fd:write("</div>\n")
	fd:close()
	return item
end

local function random_name()
	local souhlaska = function()
		local all = {"b","c","d","f","g","h","j","k","l","m","n","p","r","s","t","v","w","x","b","c","d","f","g","h","j","k","l","m","n","p","r","s","t","v","w","x","č","ř","š","ž"}
		return all[math.random(#all)]
	end
	local samohlaska = function()
		local all = {"a","e","i","o","u","y","a","e","i","o","u","y","a","e","i","o","u","y","á","é","í","ó","ů","ý"}
		return all[math.random(#all)]
	end
	local ltrs = {}
	if math.random()>0.5 then
		table.insert(ltrs,souhlaska())
	end
	if math.random()>0.8 then
		table.insert(ltrs,samohlaska())
		table.insert(ltrs,souhlaska())
		if math.random()<0.1 then
			table.insert(ltrs,souhlaska())
		end
	end
	table.insert(ltrs,samohlaska())
	table.insert(ltrs,souhlaska())
	if math.random()<0.1 then
		table.insert(ltrs,souhlaska())
	end
	table.insert(ltrs,samohlaska())
	table.insert(ltrs, "nym")
	ltrs[1] = ({["č"] = "Č", ["ř"] = "Ř", ["š"] = "Š", ["ž"] = "Ž", ["á"] = "Á", ["é"] = "É", ["í"] = "Í", ["ó"] = "Ó", ["ů"] = "Ú", ["ý"] = "Ý"})[ltrs[1]] or ltrs[1]:upper()
	return(table.concat(ltrs))
	--res.name = names[math.random(#names)].."-"..string.format("%02d", math.random(99))
end

local function user_command(user, text0)
	local send_text = function(txt)
		send_message{receiver = assert(user.id), text = txt}
	end
	local text = text0:match("^(/%S+)") or "/"
	if text == "/" or text == "/start" then
		send_text("> Příkazy jsou následující:\n/hist = Vypíše posledních 20 příspěvků\n/nick xy = Změní tvou přezdívku na xy (nebo dá náhodnou, pokud vynecháš 'xy')\n/bye = Přestane ti posílat všechny zprávy z chatu\n/echo = Přestane ti posílat zpět tebou napsané veřejné zprávy.\n> Nyní máš přezdívku "..user.name..".")
	elseif text == "/hist" then
		send_text("> Posledních 20 příspěvků:")
		local history = _M.history
		local f = math.max(#history - 19, 1)
		for i = f, #history do
			send_text(format_time(assert(history[i].ts)).hhmm.." "..history[i].text)
		end
		send_text("> Starší příspěvky jsou archivovány zde: http://fuxoft.cz/fffilm/ffchat/_nosync/")
	elseif text == "/nick" then
		local desired = text0:match("^/nick%s+(.*)$")
		if not desired then
			desired = random_name()
		elseif desired == "*" then
			local registered = SERIALIZE.load(MY_DIR.."registered_users.txt")
			--print("User "..user.id.." is registered?")
			if registered[user.id] then
				desired = "*" .. assert(registered[user.id].name)
			else
				send_text("> Hahahaha.")
				return
			end
		else
			if desired:match("[^a-zA-Z]") then
				send_text("> Přezdívka musí obsahovat pouze písmena bez diakritiky")
				return
			end
			if not (#desired <= 20 and #desired >=3) then
				send_text("> Přezdívka musí mít 3 až 20 znaků")
				return
			end
		end
		user.name = desired
		send_text("> Přezdívka změněna. Nyní jsi "..desired)
	elseif text == "/bye" then
		_M.users[assert(user.id)]=false
		send_text("> OK. Další zprávy z chatu ti NEBUDOU POSÍLÁNY dokud mi nepošleš zprávu (libovolnou)!")
	elseif text == "/echo" then
		if user.noecho then
			send_text("> Tebou odeslané veřejné zprávy nyní BUDEŠ dostávat pro kontrolu zpět. Pokud je nebudeš chtít dostávat, použij znovu příkaz /echo.")
		else
			send_text("> Tebou odeslané veřejné zprávy nyní NEBUDEŠ dostávat pro kontrolu zpět. Pokud je opět budeš chtít dostávat, použij znovu příkaz /echo.")
		end
		user.noecho = not user.noecho
	elseif text == "/UnsupportedMessageVole" then
		send_text("> Tento typ zprávy není zatím podporován, sorry.")
	else
		send_text("> Neznámý příkaz "..text..". Seznam všech příkazů zobrazíš odesláním samotného lomítka.")
	end
end

local function handle_incoming_json(args)
	local json = assert(args.incoming_json)
	local jsontxt = assert(args.incoming_jsontxt)
	--print(jsontxt)
	if not json.ok then
		LOG.warn("Json not OK")
		return
	end
	local result = assert(json.result)
	if not next(result) then --No data
		return
	end
	for i, update in ipairs(result) do
		local msgtxt = update.message.text or "/UnsupportedMessageVole"
		local sender_id = assert(update.message.from.id)
		LOG.info("Got text message from "..sender_id..": "..msgtxt)
		local user = _M.users[sender_id]
		if not user then
			user = {name = random_name(), id = sender_id}
			_M.users[sender_id] = user
		end
		user.ts = os.time()
		SERIALIZE.save(_M.users,USERS_FILENAME)

		local banned = SERIALIZE.load(MY_DIR.."banned_users.txt")
		if banned[sender_id] then
			local text = "> "..(banned[sender_id].message or "Problem. Please contact admin.")
			send_message{receiver = sender_id, text = text}
			LOG.info("User "..sender_id.. " banned: "..text)
		else

			if msgtxt:match("^/") then
				user_command(user, msgtxt)
			else --Normal message
				local name = assert(user.name)
				local fulltext = name..": "..msgtxt
				local added = update_history(fulltext)
				local fulltext = format_time(added.ts).hhmm.." "..fulltext
				local excluded = {}
				if user.noecho then
					excluded[sender_id] = true
				end
				for rcvid, rcv in pairs(_M.users) do
					if rcv and not (rcv.quiet) and not excluded[rcvid] then
						send_message {receiver = rcvid, text = fulltext}
					end
				end
			end
		end
		--print("handled msg "..update.message.message_id)
		actually_send_messages()
		_M.last_update_id = assert(update.update_id)
	end
end

_M.start = function()
	_M.last_update_id = false
	_M.users = SERIALIZE.load(USERS_FILENAME) or {}
	_M.history = SERIALIZE.load(HISTORY_FILENAME) or {}
	local CJSON = require("cjson.safe") --lua-cjson
	LOG.debug("Starting telegram polling")

	while true do
		local txt,status = telegram_poll(stunnel)
		if status == 200 then
			local jsontxt = txt
			local stat,json = CJSON.decode(jsontxt)
			if not stat then
				LOG.warn("Cannot decode incoming json: "..jsontxt..", "..json)
			else
				handle_incoming_json{incoming_json=stat,incoming_jsontxt=jsontxt}
			end
		else
			LOG.warn("Telegram response is not 200 OK: "..tostring(txt).." / "..tostring(status))
		end
		SERIALIZE.save_all()
	end
end

return _M
