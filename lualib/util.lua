local M = {}
local log = require "log"
local md5 = require "md5"


function M.string_split(str, sep)
	local arr = {}
	local i = 1
	for s in string.gmatch(str, "([^" .. sep .. "]+)") do
		arr[i] = s
		i = i + 1
	end
	return arr
end

local keys = {
	debug_xianwan = "PibYJZUbwvALLUIvuzbs", --预发布key
	zs_xianwan = "Jd7RRBqU42g4uT6Qj9UU", --正式服对接的key
}

local local_op_key = "erMBdglnujCsOtpltIcC"

function M.check_key(op,sign,appname,tag,arg1,arg2)
	sign = sign or ""
	appname = appname or ""
	tag = tag or ""
	arg1 = arg1 or ""
	arg2 = arg2 or ""
	log.info("check_key",op,sign,appname,tag,arg1,arg2)
	if local_op_key == sign then
		return true
	end

	if op == "query" or op == "ranklist" then
		if not keys[appname] then
			log.info("三方查询appname错误")
			return
		end
		local mysign = md5.sumhexa(string.format("%s%s%s%s%s",appname,arg1,arg2,keys[appname]))
		if sign ~= mysign then
			log.info("三方查询签名错误",sign,mysign)
			return 
		end
		return true
	end
	log.error("请求异常")
	return false
end

return M
