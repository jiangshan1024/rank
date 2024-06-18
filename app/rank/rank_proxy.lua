local log = require "log"
local skynet = require "skynet"
local errcode = require "app.errcode"
local const = require "app.const"
local rankmgr = require "app.rank.rankmgr"
local cjson = require "cjson"
local setting_rank_mgr_addr =  nil
local M = {}
local mt = { __index = M }

local proxys_cache = {}

local function timeout_call(...)
	local reqs = skynet.request({ ... })
	local ret
	for req, resp in reqs:select(const.DEFAULT_TIMEOUT) do
		if resp then
			ret = resp
		else
			log.error("timeout_call error:", req, " , args:", ...)
		end
	end
	if reqs.timeout then
		return errcode.RANK_SERVICE_TIMEOUT
	end
	if ret then
		return table.unpack(ret, 1, ret.n)
	end
	return errcode.RANK_SERVICE_CALL_FAIL
end

function M.get(appname)
	if appname == nil then
		return
	end

	if proxys_cache[appname] then
		return proxys_cache[appname]
	end

	local instance = {
		appname = appname,
		tag2service = {}
	}
	log.debug("new proxy:", appname)
	local proxy = setmetatable(instance, mt)
	proxys_cache[appname] = proxy
	return proxy
end

function M:set_config(config)
	setting_rank_mgr_addr = setting_rank_mgr_addr or rankmgr.addr
	return timeout_call(setting_rank_mgr_addr, "lua", "set_config", self.appname, config)
end

function M:set_setting(config)
	setting_rank_mgr_addr = setting_rank_mgr_addr or rankmgr.addr
	return timeout_call(setting_rank_mgr_addr, "lua", "set_setting", self.appname,config)
end

function M:cache_services(tags)
	local req_args = {}
	for _, tag in pairs(tags) do
		if not self.tag2service[tag] then
			req_args[#req_args + 1] = { rankmgr.addr, "lua", "get_rank_service", self.appname, tag }
		end
	end

	local succ = true
	if #req_args == 0 then
		return succ
	end

	log.debug("cache_services req_args:", req_args)

	local reqs = skynet.request()
	for _, req in pairs(req_args) do
		reqs:add(req)
	end
	for req, resp in reqs:select(const.DEFAULT_TIMEOUT) do
		if resp then
			local tag = req[5]
			self.tag2service[tag] = resp[1]
		else
			log.error("unknow error:", req)
			succ = false
		end
	end
	if reqs.timeout then
		return false
	end
	return succ
end

function M:update(tags, uid, score, info)
	if not self:cache_services(tags) then
		return errcode.RANK_SERVICE_CACHE_FAIL
	end
	for _, tag in pairs(tags) do
		local service = self.tag2service[tag]
		skynet.send(service, "lua", "update", uid, score, info)
	end
	return errcode.OK
end
function M:change(tags, uid, addscore, info)
	if not self:cache_services(tags) then
		return errcode.RANK_SERVICE_CACHE_FAIL
	end
	for _, tag in pairs(tags) do
		local service = self.tag2service[tag]
		skynet.send(service, "lua", "change", uid, addscore, info)
	end
	return errcode.OK
end

function M:delete(tags, uid)
	if not self:cache_services(tags) then
		return errcode.RANK_SERVICE_CACHE_FAIL
	end
	for _, tag in pairs(tags) do
		local service = self.tag2service[tag]
		skynet.send(service, "lua", "delete", uid)
	end
	return errcode.OK
end

function M:query(date,uid)
	--tag要从配置里面获取，如果没配就是不允许请求
	-- if not self:cache_services({tag}) then
	-- 	return errcode.RANK_SERVICE_CACHE_FAIL
	-- end
	setting_rank_mgr_addr = setting_rank_mgr_addr or rankmgr.addr
	local setting =  timeout_call(setting_rank_mgr_addr, "lua", "get_setting", self.appname)
	if type(setting) == "string" then
		local ok,_setting = pcall(cjson.decode,setting)
		if not ok then
			return errcode.NO_CONFIG
		end
		setting = _setting
	end
	-- local tg,server = next(self.tag2service)
	-- log.info(tg,server,self.tag2service[tg])
	-- local setting = skynet.call(server,"lua","get_setting")
	local tag = setting.tag
	if not tag or tag == "nil" then
		return errcode.NO_CONFIG
	end
	date = string.gsub(date, "-", "")
	tag = tag .. "_" .. date
	-- if date then
	-- 	tag = tag  .. "_".. os.date("%Y%m%d")
	-- else
	-- 	tag = tag .. "_" .. os.date("%Y%m%d",os.time() - 86400)
	-- end
	if not self:cache_services({tag}) then
		return errcode.RANK_SERVICE_CACHE_FAIL
	end
	log.info("query",tag,uid)
	local service = self.tag2service[tag]
	return timeout_call(service, "lua", "query", uid)
end

function M:infos(date,uids)
	--tag要从配置里面获取，如果没配就是不允许请求
	setting_rank_mgr_addr = setting_rank_mgr_addr or rankmgr.addr
	local setting =  timeout_call(setting_rank_mgr_addr, "lua", "get_setting", self.appname)
	if type(setting) == "string" then
		local ok,_setting = pcall(cjson.decode,setting)
		if not ok then
			return errcode.NO_CONFIG
		end
		setting = _setting
	end

	local tag = setting.tag
	if not tag or tag == "nil" then
		return errcode.NO_CONFIG
	end
	date = string.gsub(date, "-", "")
	tag = tag .. "_" .. date
	-- if date then
	-- 	tag = tag .. "_".. os.date("%Y%m%d")
	-- else
	-- 	tag = tag .. "_".. os.date("%Y%m%d",os.time() - 86400)
	-- end

	if not self:cache_services({tag}) then
		return errcode.RANK_SERVICE_CACHE_FAIL
	end

	local service = self.tag2service[tag]
	return timeout_call(service, "lua", "infos", uids)
end

function M:ranklist(date,start, count)
	--tag要从配置里面获取，如果没配就是不允许请求

	setting_rank_mgr_addr = setting_rank_mgr_addr or rankmgr.addr
	local setting =  timeout_call(setting_rank_mgr_addr, "lua", "get_setting", self.appname)
	if type(setting) == "string" then
		local ok,_setting = pcall(cjson.decode,setting)
		if not ok then
			return errcode.NO_CONFIG
		end
		setting = _setting
	end
	local tag = setting.tag
	if not tag or tag == "nil" then
		return errcode.NO_CONFIG
	end
	date = string.gsub(date, "-", "")
	tag = tag .. "_" .. date
	-- if today then
	-- 	tag = tag .. "_".. os.date("%Y%m%d")
	-- else
	-- 	tag = tag .. "_".. os.date("%Y%m%d",os.time() - 86400)
	-- end
	if not self:cache_services({tag}) then
		return errcode.RANK_SERVICE_CACHE_FAIL
	end

	local service = self.tag2service[tag]
	return timeout_call(service, "lua", "ranklist", start, count)
end

return M
