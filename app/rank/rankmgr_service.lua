return function()
	local skynet = require "skynet"
	local service = require "skynet.service"
	local rank_service = require "app.rank.rank_service"
	local log = require "log"
	local db = require "app.db"
	local util_table = require "util.table"
	local rankidlib = require "app.rank.rankid"
	local errcode = require "app.errcode"
	local cjson = require "cjson"
	local CMD = {}

	local function load_rank_service(t, rankid)
		log.info("load_rank_service rankid:", rankid)
		t[rankid] = service.new(rankid, rank_service, rankid)
		return t[rankid]
	end

	local ranks = setmetatable ({} , {
		__index = load_rank_service,
	})

	function CMD.get_rank_service(appname, tag)
		local rankid = rankidlib.get_rankid(appname, tag)
		return ranks[rankid]
	end

	function CMD.get_setting(appname)
		local query = {appname = appname,setting_name="query_limit"}
		local dbtbl = db.get_setting_dbtbl()
		local ret = dbtbl:findOne(query,{_id = false})
		-- log.debug(ret,"rankmgr_service",cjson.encode(ret))
		if ret then
			return ret.data
		else
			return {}
		end
	end

	function CMD.set_setting(appname,config)

		log.info("set_setting", config)
		if (type(config) ~= "string") then
			config = cjson.encode(config)
		end
		-- 写入数据库
		local dbtbl = db.get_setting_dbtbl()
		local query = {setting_name = "query_limit",appname=appname}
		local update = {data = config}
		local ok, err = dbtbl:safe_update(query, {['$set'] = update},true)
		if not ok  then
			log.error("set_setting save failed. ", ", config:", util_table.tostring(config), ", err:", err)
			return errcode.SAVE_DB_FAIL
		end

		-- 通知所有 rank_service 清空缓存
		for _, addr in pairs(ranks) do
			skynet.send(addr, "lua", "clear_setting_config_cache")
		end
		return errcode.OK
	end

	function CMD.set_config(appname, config)
		log.info("set_config", config)
		-- 写入数据库
		local dbtbl = db.get_config_dbtbl()
		local updates = {}
		for _, cfg in pairs(config) do
			local tag = cfg.tag
			local rankid = rankidlib.get_rankid(appname, tag)
			updates[#updates + 1] = {
				query = { rankid = rankid },
				update = {
					["$set"] = {
						cfg = cfg,
					},
				},
				upsert = true,
				multi = false,
			}
		end
		local ok, err, ret = dbtbl:safe_batch_update(updates)
		if (not ok) or (not ret) or (ret.n ~= #updates) then
			log.error("set_config save failed. appname:", appname, ", config:", util_table.tostring(config), ", err:", err)
			return errcode.SAVE_DB_FAIL
		end

		-- 通知所有 rank_service 清空缓存
		for _, addr in pairs(ranks) do
			skynet.send(addr, "lua", "clear_config_cache")
		end
		return errcode.OK
	end

	skynet.dispatch("lua", function(_, source, cmd, ...)
		local f = CMD[cmd]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			log.error(string.format("Unknown cmd:%s, source:%s", cmd, source))
			skynet.ret(skynet.pack(errcode.RANK_SERVICE_CALL_FAIL))
		end
	end)
end
