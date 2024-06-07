local wlua = require "wlua"
local rank_proxy = require "app.rank.rank_proxy"
local errcode = require "app.errcode"
local util = require "util"
local log = require "log"
local cjson = require "cjson"

local app = wlua:default()

app:get("/", function (c)
	log.info(package.cpath)
	c:send("Hello wlua rank!")
end)

app:get("/ping", function (c)
	c:send("pong")
end)

app:post("/setsetting", function (c)
	local config = c.req.body.config
	local appname = c.req.body.appname
	local key = c.req.body.key
	if not util.check_key("setsetting",key) then
		c:send_json({
			code = errcode.PERMISSION_DENIED
		})
		return
	end

	local proxy = rank_proxy.get(appname)
	if proxy == nil then
		c:send_json({
			code = errcode.RANK_INIT_FAIL
		})
		return
	end
	local code = proxy:set_setting(config)
	c:send_json({
		code = code
	})
end)

app:post("/setappconfig", function (c)
	local appname = c.req.body.appname
	local config = c.req.body.config
	local key = c.req.body.key
	if not util.check_key("setconfig",key) then
		c:send_json({
			code = errcode.PERMISSION_DENIED
		})
		return
	end

	local proxy = rank_proxy.get(appname)
	if proxy == nil then
		c:send_json({
			code = errcode.RANK_INIT_FAIL
		})
		return
	end
	local code = proxy:set_config(config)
	c:send_json({
		code = code
	})
end)

app:post("/update", function (c)
	local appname = c.req.body.appname
	local tags = c.req.body.tags
	local uid = c.req.body.uid
	local score = c.req.body.score
	local info = c.req.body.info
	local addscore = c.req.body.addscore
	local key = c.req.body.key
	if not util.check_key("update",key,appname,cjson.encode(tags),uid,score,addscore) then
		c:send_json({
			code = errcode.PERMISSION_DENIED
		})
		return
	end

	local proxy = rank_proxy.get(appname)
	if proxy == nil then
		c:send_json({
			code = errcode.RANK_INIT_FAIL
		})
		return
	end
	local code = nil
	print(addscore,tonumber(addscore))
	if addscore and tonumber(addscore) and tonumber(addscore)~=0 then
		code = proxy:change(tags, uid, addscore, info)
		print("update---change")
	else
		code = proxy:update(tags, uid, score, info)
		print("update---recover")
	end
	c:send_json({
		code = code
	})
end)

app:post("/delete", function (c)
	local appname = c.req.body.appname
	local tags = c.req.body.tags
	local uid = c.req.body.uid
	local key = c.req.body.key
	if not util.check_key("delete",key) then
		c:send_json({
			code = errcode.PERMISSION_DENIED
		})
		return
	end

	local proxy = rank_proxy.get(appname)
	if proxy == nil then
		c:send_json({
			code = errcode.RANK_INIT_FAIL
		})
		return
	end

	local code = proxy:delete(tags, uid)
	c:send_json({
		code = code
	})
end)

app:get("/query", function (c)
	local appname = c.req.query.appname
	local tag = c.req.query.tag
	local uid = c.req.query.uid
	local today = c.req.query.today
	local sign = c.req.query.sign
	if not util.check_key("query",sign,appname,tag,uid) then
		c:send_json({
			code = errcode.PERMISSION_DENIED
		})
		return
	end
	local proxy = rank_proxy.get(appname)
	if proxy == nil then
		c:send_json({
			code = errcode.RANK_INIT_FAIL
		})
		return
	end

	local code, element, rank = proxy:query(today,uid)
	c:send_json({
		code = code,
		element = element,
		rank = rank,
	})
end)

app:get("/infos", function (c)
	local appname = c.req.query.appname
	local tag = c.req.query.tag
	local today = c.req.query.today
	local uids = util.string_split(c.req.query.uids, ",")

	log.debug("infos appname:", appname, ", uids:", uids)

	local key = c.req.query.key
	if not util.check_key("infos",key) then
		c:send_json({
			code = errcode.PERMISSION_DENIED
		})
		return
	end

	local proxy = rank_proxy.get(appname)
	if proxy == nil then
		c:send_json({
			code = errcode.RANK_INIT_FAIL
		})
		return
	end

	local code, elements = proxy:infos(today,uids)
	c:send_json({
		code = code,
		elements = elements,
	})
end)

app:get("/ranklist", function (c)
	local appname = c.req.query.appname
	local today = c.req.query.today
	local tag = c.req.query.tag
	local start = tonumber(c.req.query.start)
	local count = tonumber(c.req.query.count)
	local sign = c.req.query.sign
	if not util.check_key("ranklist",sign,appname,tag,start,count) then
		c:send_json({
			code = errcode.PERMISSION_DENIED
		})
		return
	end
	local proxy = rank_proxy.get(appname)
	if proxy == nil then
		c:send_json({
			code = errcode.RANK_INIT_FAIL
		})
		return
	end

	local code, elements = proxy:ranklist(today,start, count)
	c:send_json({
		code = code,
		elements = elements,
	})
end)

app:run()

