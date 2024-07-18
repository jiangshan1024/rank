return function()
	local skynet = require "skynet"
	local service = require "skynet.service"
	local rank_service = require "app.rank.rank_service"
	local log = require "log"
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
		return skynet.call(".mongo_mgr","lua","get_rank_setting",appname)
	end

	function CMD.set_setting(appname,config)

		return skynet.call(".mongo_mgr","lua","set_rank_setting",appname,config)
	end

	function CMD.set_config(appname, config)
		return skynet.call(".mongo_mgr","lua","set_rank_config",appname,config)
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
