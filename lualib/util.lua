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
	zs_juhaoliang = "Lh3DABi6HLN8EttN99B7", --巨好量
	zs_dandanzhuan = "U2jBiHAGmuTidbLB64rR", --蛋蛋赚
	zs_doudouqu = "3LK68JHf,gvjFg294752Dl", --逗逗趣
	zs_doudouzhuan = "23U2H2aDYUNmkKiENf3e", --豆豆赚
	zs_duoliang = "Jh63aShdfKhfe48Hfe", --多量
	zs_juxiang = "HBdSHalVJhDgGKsFkd93784(^9^@(9-F", --聚享玩
	zs_mtzd = "mKUGtg^%$@cgfSU&^Gmr", --每天赚点
	zs_pceggs = "umTe8EEfD2uYtQ34iTN2", --pc蛋蛋
	zs_xiaozhuo = "aoiuwperwq-1-23807JKLiphHT3234", --小啄
	zs_zhuanke = "yAjrN8AEjKBDDdFEeuE2", --赚客
	zs_zhuanke91 = "po*&8975872546(*&^98232Dl", --赚客91
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
		local mysign = md5.sumhexa(string.format("%s%s%s%s",appname,arg1,arg2,keys[appname]))
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
