local skynet = require "skynet"
local service = require "skynet.service"
local rankmgr_service = require "app.rank.rankmgr_service"
local log = require "log"

local mongodb_pool = {}

local addr = nil

local function load_service(t, key)
	if key == "addr" then
		addr = addr or service.new("rankmgr", rankmgr_service)
		return addr
		-- if #mongodb_pool < 2 then
		-- 	for i=1,2 do
		-- 		table.insert(mongodb_pool,service.new("rankmgr" .. i, rankmgr_service))
		-- 		-- print("创建第",i,"条mongo通道",skynet.self())
				-- log.debug("创建第" .. i .. "条mongo通道",skynet.self())
		-- 	end
		-- end
		-- local rdx = math.random(1,#mongodb_pool)
		-- return mongodb_pool[rdx]
		-- return t.address
	else
		return nil
	end
end

local rankmng = setmetatable ({} , {
	__index = load_service,
})

return rankmng
