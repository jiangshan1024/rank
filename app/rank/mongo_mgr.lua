return function()
	local skynet = require "skynet"
	local log = require "log"
	local const = require "app.const"
    local mongo = require "skynet.db.mongo"
	local sysconfig = require "config"
	local cjson = require "cjson"
    local errcode = require "app.errcode"
    local util_table = require "util.table"
    local rankidlib = require "app.rank.rankid"

	local CMD = {}

    local idx = 0

    local mongodb_index = {} --索引缓存

    local mongo_clients = {}

    local config_mongo = nil


    local  config_cache = {}--配置缓存
    local  setting_cache = {}--设置缓存
	function CMD.init()
        log.debug("==============start init ===================")
        local app_mongodb_conf = sysconfig.get_tbl("app_mongodb_conf")
        for i=1,5 do
	        local db_conn = mongo.client(app_mongodb_conf)
            assert(db_conn)
            table.insert(mongo_clients,db_conn)
        end
        config_mongo = mongo.client(app_mongodb_conf)
        config_mongo[const.DB_NAME][const.DB_TBL_CONF_NAME]:createIndex({{ rankid = 1 }, unique = true})
        config_mongo[const.DB_NAME][const.DB_TBL_SETTING_NAME]:createIndex({{ appname = 1 }, unique = true})
    end

    --原项目自带配置
    function CMD.load_config(rankid)
        -- 从数据库加载配置
        local db = config_mongo[const.DB_NAME][const.DB_TBL_CONF_NAME]
        local data = db:findOne({ rankid = rankid }, { _id = 0, cfg = 1, })
        log.debug("load_config data:", data)
        if data then
            return {
                capacity = data.cfg.capacity,
                order = data.cfg.order,
            }
        end
        return {
            capacity = const.DEFAULT_CAPACITY,
            order = const.DESCENDING,--修改为默认从大到小
        }
    end
    function CMD.get_rank_config(rankid)
        if not config_cache[rankid] then
            config_cache[rankid] = CMD.load_config(rankid)
        end
        return config_cache[rankid]
    end
    function CMD.set_rank_config(appname,config)--type(_config) = table
        log.info("set_rank_config", config)
		-- 写入数据库
		local dbtbl = config_mongo[const.DB_NAME][const.DB_TBL_CONF_NAME]
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
        config_cache = nil
		return errcode.OK
    end


    --凝光需求配置
    function CMD.load_setting(appname)
        -- 从数据库加载配置
        local db = config_mongo[const.DB_NAME][const.DB_TBL_SETTING_NAME]
        local ret = db:findOne({ appname = appname }, { _id = 0, data = 1, })
		log.debug("load_setting data:", ret)
		if ret and ret.data then
			return cjson.decode(ret.data)
		end
        return {}
    end
    function CMD.get_rank_setting(appname)
        if not setting_cache[appname] then
            setting_cache[appname] = CMD.load_setting(appname)
        end
        return setting_cache[appname]
    end
    function CMD.set_rank_setting(appname,_config)
        log.info("set_setting", _config)
		if (type(_config) ~= "string") then
			_config = cjson.encode(_config)
		end
		log.info("setting:",cjson.encode(_config))
		-- 写入数据库
        local dbtbl = config_mongo[const.DB_NAME][const.DB_TBL_SETTING_NAME]
		local query = {setting_name = "query_limit",appname=appname}
		local update = {data = _config}
		local ok, err = dbtbl:safe_update(query, {['$set'] = update},true)
		if not ok  then
			log.error("set_setting save failed. ", ", config:", _config, ", err:", err)
			return errcode.SAVE_DB_FAIL
		end
        setting_cache[appname] = nil
        return errcode.ok
    end

    -------------------------------------

    function CMD.select(db_name,tbname)
        idx = idx + 1
        if idx > #mongo_clients then
            idx = 1
        end
        return mongo_clients[idx][db_name][tbname]
    end

    function CMD.check_index(db_name,tbname)
        if mongodb_index[db_name .. tbname] then
            return
        end
        local db = CMD.select(db_name,tbname)
        db[db_name][tbname]:createIndex({{ uid = 1 }, unique = true})
        mongodb_index[db_name .. tbname] = true
        log.debug("创建索引",db_name,tbname)
    end

	function CMD.update(db_name,tbname,uid, score, info)
        CMD.check_index(db_name,tbname)
        local db = CMD.select(db_name,tbname)
        -- 更新数据库数据
        local data = {
            ["$set"] = {
                score = score,
                info = info,
            }
        }
        local ok, err, ret = db:safe_update({uid = uid}, data, true, false)
        if (not ok) or (not ret) or (ret.n ~= 1) then
            log.error("save rank failed. uid:", uid, ", score:",
                score, ", info:", cjson.encode(info), ", err:", err)
        end
	end

	function CMD.delete(db_name,tbname,uid)
        CMD.check_index(db_name,tbname)
        local db = CMD.select(db_name,tbname)
        local ok, err, ret = db:safe_delete({uid= uid}, true)
        if (not ok) or (not ret) or (ret.n ~= 1) then
            log.error("delete from rank failed. uid:", uid, ", err:", err)
        end
	end

    function CMD.load_rank(db_name,tbname)
        CMD.check_index(db_name,tbname)
        local db = CMD.select(db_name,tbname)
        local ret = db:find({}, { _id = 0 })
        local rank_data = {}
        while ret:hasNext() do
            local data = ret:next()
            table.insert(rank_data,{data.uid, data.score, data.info})
        end
        return rank_data
	end

	skynet.dispatch("lua", function(_, source, cmd, ...)
		local f = CMD[cmd]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			log.error(string.format("Unknown cmd:%s, source:%s", cmd, source))
		end
	end)
end
