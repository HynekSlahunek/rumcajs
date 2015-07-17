local _M = {}

local MY_DIR = RUMCAJS.app_dir.."fffilm_chat/"
local HISTORY_FILENAME = "/var/tmp/fuxoft_rumcajs_ffchat_history.txt"
local USERS_FILENAME = "/var/tmp/fuxoft_rumcajs_ffchat_users.txt"
local SERIALIZE = dofile("/home/fuxoft/work/web/private/lib/serialize.lua")
local CJSON = require("cjson.safe") --lua-cjson
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

local priv = dofile("/home/fuxoft/.private.lua")
local BOT_KEY = assert(priv.telegram.fffilmchatbot)
if priv.runwhere == "fuxoft" then
	BOT_KEY = assert(priv.telegram.anonchatbot)
end
local function telegram_poll()
	local maybe_offset = ""
	local offset = _M.last_update_id
	if offset then
		offset = tonumber(offset) + 1
		maybe_offset = "&offset="..offset
	end
	local timeout = 10
	if _M.please_restart then
		timeout = 1
	end
	local txt, err = TASKER.http_request(string.format("https://api.telegram.org/bot%s/getUpdates?timeout=%s%s", BOT_KEY,timeout,maybe_offset))
	--sock:send(string.format("GET /bot%s/getUpdates?timeout=10%s HTTP/1.0\r\n\r\n", BOT_KEY,maybe_offset))
	if _M.please_restart then --This must be here because "/restart" command must be acknowledged before quitting
		os.exit(tonumber(_M.please_restart))
	end
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
		local json = CJSON.decode(txt)
		local ok = json.ok
		if not ok then
			local errcode = json.error_code or "???"
			local desc = json.description or "?????"
			local receiver = data.chat_id or "???"
			LOG.warn("Receiver %s error %s: %s", receiver, errcode, desc)
			return false, errcode
		end
	end
	return txt
end

local function do_queued_tasks()
	local queue = assert(_M.queued_tasks)
	_M.queued_tasks = {}
	TASKER.add_pthread("ffchat_queued_tasks_launcher", function()
		local nsync,nasync = 0,0
		for i, task in ipairs (queue) do
			--LOG.debug("%s: %s", i, (task.id or "[sync]"))
			if task.sync_fun then
				assert(not task.id)
				task.sync_fun()
				nsync = nsync + 1
			else
				assert(task.async_fun)
				assert(task.id)
				TASKER.add_pthread(task.id, task.async_fun)
				nasync = nasync + 1
			end
		end
		LOG.debug("Launched %s queued tasks (%s async, %s sync).", nasync+nsync, nasync, nsync)
	end)
end

local function queue_sync_task(fun)
	table.insert(_M.queued_tasks, {sync_fun = fun})
	assert(type(fun) == "function", "Fun is not function.")
end

local function queue_async_task(id, fun)
	assert(type(id) == "string", "Id is not string.")
	assert(type(fun) == "function", "Fun is not function.")
	table.insert(_M.queued_tasks, {async_fun = fun, id = id})
end

local function send_text_message(text, receiver)
	assert(type(text)=="string", "Text is not string.")
	assert(type(receiver) == "number", "Receiver is not number.")
	local stat, code = telegram_post {method = "sendMessage", data = {chat_id = receiver, text = text}}
	if not stat then --Sending was NOT ok
		local user = _M.users[receiver]
		if user then
			local ostime = os.time()
			if not user.invalid_since then
				user.invalid_since = ostime
			else
				local invalid_days = (ostime - user.invalid_since) / (60*60*24)
				LOG.debug("User %s invalid for %s days", receiver, invalid_days)
				if invalid_days > 7.5 then
					LOG.info("User %s (%s) invalid for %s days, deleting.",receiver,user.name or "???",invalid_days)
					_M.users[receiver] = false
				end
			end
		end
	end
end

local function for_all_users_except(exclude, fun)
	assert(type(fun)=="function", "Fun is not a function")
	exclude = exclude or -1
	assert(type(exclude)=="number")
	local excluded = {}
	if (_M.users[exclude] or {}).noecho then
		excluded[exclude] = true
	end
	local num = 0
	for rcvid, rcv in pairs(_M.users) do
		if rcv and not (rcv.quiet) and not excluded[rcvid] then
			fun(rcv)
			num = num + 1
		end
	end
	return num --how many of them were done
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
	local reply_text = function(txt)
		queue_sync_task(function()
			send_text_message(txt, assert(user.id))
		end)
	end
	local text = text0:match("^(/%S+)") or "/"
	local history_num = 5
	local registered_users = SERIALIZE.load(MY_DIR.."registered_users.txt")
	local is_god = (registered_users[user.id] or {}).is_god
	if text == "/" or text == "/start" then
		reply_text("> Příkazy jsou následující:\n/hist = Vypíše posledních "..history_num.." příspěvků\n/nick xy = Změní tvou přezdívku na xy (nebo dá náhodnou, pokud vynecháš 'xy')\n/bye = Přestane ti posílat všechny zprávy z chatu\n/echo = Začne ti pro kontrolu posílat zpět tebou napsané veřejné zprávy.\n> Nyní máš přezdívku "..user.name..".")
	elseif text == "/hist" then
		reply_text("> Posledních "..history_num.." příspěvků:")
		local history = _M.history
		local f = math.max(#history - history_num + 1, 1)
		for i = f, #history do
			reply_text(format_time(assert(history[i].ts)).hhmm.." "..history[i].text)
		end
		reply_text("> Starší příspěvky jsou archivovány zde: http://fuxoft.cz/fffilm/ffchat/_nosync/")
	elseif text == "/nick" then
		local desired = text0:match("^/nick%s+(.*)$")
		if not desired then
			desired = "?"..random_name()
		elseif desired == "*" then
			if registered_users[user.id] then
				desired = "*" .. assert(registered_users[user.id].name)
			else
				reply_text("> Hahahaha.")
				return
			end
		else
			if desired:match("[^a-zA-Z]") then
				reply_text("> Přezdívka musí obsahovat pouze písmena bez diakritiky")
				return
			end
			if not (#desired <= 20 and #desired >=3) then
				reply_text("> Přezdívka musí mít 3 až 20 znaků")
				return
			end
		end
		user.name = desired
		reply_text("> Přezdívka změněna. Nyní jsi "..desired)
	elseif text == "/bye" then
		_M.users[assert(user.id)]=false
		reply_text("> OK. Další zprávy z chatu ti NEBUDOU POSÍLÁNY, dokud mi nepošleš zprávu (libovolnou)!")
	elseif text == "/echo" then
		if user.noecho then
			reply_text("> Tebou odeslané veřejné zprávy nyní BUDEŠ dostávat pro kontrolu zpět. Pokud je nebudeš chtít dostávat, použij znovu příkaz /echo.")
		else
			reply_text("> Tebou odeslané veřejné zprávy nyní NEBUDEŠ dostávat pro kontrolu zpět. Pokud je opět budeš chtít dostávat, použij znovu příkaz /echo.")
		end
		user.noecho = not user.noecho
	elseif text == "/ver" then
		local fd = io.popen("git --git-dir "..RUMCAJS.root_dir..".git log --oneline -10")
		local txt = fd:read("*a")
		fd:close()
		local latest = txt:match("^(%w+)") --This is SHORT version!
		local running = (arg[1] or "-versionUNKNOWN"):match("version(%w+)")
		if not running:match(latest) then
			txt = "!!!!!!!!! WARNING !!!!!!!!!!!!!!!!!!\nNot running latest version but "..running.."\n!!!!!!!!! WARNING !!!!!!!!!!!!!!!!!!\n\n"..txt
		end
		reply_text(txt)
	elseif is_god and text == "/restart" then
		LOG.info("God command = restart")
		_M.please_restart = 101
		reply_text("RESTARTING")
	elseif is_god and text == "/abort" then
		LOG.info("God command = abort")
		_M.please_restart = 100
		reply_text("ABORTING")
	else
		reply_text("> Neznámý příkaz "..text..". Seznam všech příkazů zobrazíš odesláním samotného lomítka.")
	end
end

local function handle_nontext_message(update, sender)
	local sender_id = assert(sender.id)
	local reply_text = function(txt)
		queue_sync_task(function()
			send_text_message(txt, sender_id)
		end)
	end
	if update.message.sticker then
		local sticker = assert(update.message.sticker)
		local file_id = assert(sticker.file_id)
		LOG.info("Got sticker %s from %s.", file_id, sender_id)
		for_all_users_except(sender_id, function(rcv)
			local rcvid = assert(rcv.id)
			queue_async_task("sticker_to_"..rcvid, function()
				telegram_post{method = "sendSticker", data ={chat_id = rcvid, sticker = file_id}}
				send_text_message("^^^ Sticker od "..sender.name.." ^^^", rcvid)
			end)
		end)
		update_history("<STICKER> od "..sender.name..": file_id "..file_id)
	elseif update.message.photo then
		local photo = assert(update.message.photo)
		table.sort(photo, function(a,b) return a.width > b.width end)
		--print(SERIALIZE.serialize(photo))
		local file_id = assert(photo[1].file_id)
		LOG.info("Got photo %s from %s.", file_id, sender_id)
		for_all_users_except(sender_id, function(rcv)
			local rcvid = assert(rcv.id)
			queue_async_task("sticker_to_"..rcvid, function()
				telegram_post{method = "sendPhoto", data ={chat_id = rcvid, photo = file_id, caption = "^^^ Fotka od "..sender.name.." ^^^"}}
				--send_text_message("^^^ Sticker od "..sender.name.." ^^^", rcvid)
			end)
		end)
		update_history("<PHOTO> od "..sender.name..": file_id "..file_id)
	else
		reply_text("> Tento druh souboru není (zatím) podporován.")
	end
end

local function handle_incoming_json(args)
	local json = assert(args.incoming_json)
	local jsontxt = assert(args.incoming_jsontxt)
	--print(jsontxt)
	if not json.ok then
		LOG.warn("Json doesn't have ok=true: %s", jsontxt)
		return
	end
	local result = assert(json.result)
	if not next(result) then --No data
		return
	end
	for i, update in ipairs(result) do
		local sender_id = assert(update.message.from.id)

		local user = _M.users[sender_id]
		if not user then
			user = {name = random_name(), id = sender_id, noecho = true}
			_M.users[sender_id] = user
		end
		user.ts = os.time()
		SERIALIZE.save(_M.users,USERS_FILENAME)

		local banned = SERIALIZE.load(MY_DIR.."banned_users.txt")
		if banned[sender_id] then
			local text = "> "..(banned[sender_id].message or "Problem. Please contact admin.")
			queue_async_task("ban_sender_"..sender_id,function()
				send_text_message(text, sender_id)
			end)
			LOG.info("Banned user "..sender_id.. " received: "..text)
		else --not banned
			local msgtxt = update.message.text
			if not msgtxt then
				handle_nontext_message(update, user)
			else --text message
				LOG.info("Text msg from %s (%s): %s",user.name, user.id, msgtxt)

				if msgtxt:match("^/") then
					user_command(user, msgtxt)
				else --Normal message
					local name = assert(user.name)
					local fulltext = name..": "..msgtxt
					local added = update_history(fulltext)
					local fulltext = format_time(added.ts).hhmm.." "..fulltext
					for_all_users_except(sender_id, function(rcv)
						local rcvid = assert(rcv.id)
						queue_async_task("text_to_"..rcvid, function()
							send_text_message(fulltext, rcvid)
						end)
					end)
				end
			end
		end
		--print("handled msg "..update.message.message_id)
		do_queued_tasks()
		_M.last_update_id = assert(update.update_id)
		--now handle next update in json
	end
end

_M.start = function()
	_M.last_update_id = false
	_M.users = SERIALIZE.load(USERS_FILENAME) or {}
	_M.history = SERIALIZE.load(HISTORY_FILENAME) or {}
	_M.queued_tasks = {}
	LOG.debug("Starting telegram polling")

	while true do
		local txt,status = telegram_poll()
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
