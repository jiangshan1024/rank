local skiplist = require "skiplist.c"
local util_table = require "util.table"
local log = require "log"
local skynet = require "skynet"

local mt = {}
mt.__index = mt

function mt:_add(uid, score, info)
	local element = self.tbl[uid]
	if element then
		if element.score == score then
			return
		end
		self.sl:delete(element.score, uid)
	end

	self.sl:insert(score, uid)
	self.tbl[uid] = {
		uid = uid,
		score = score,
		info = info,
	}
end
function mt:_change(uid, addscore, info)
	local element = self.tbl[uid]
	local old_score = 0
	local new_score = 0
	if element then
		old_score = element.score
		self.sl:delete(element.score, uid)
	end
	new_score = old_score + (addscore or 0)
	self.sl:insert(new_score, uid)
	self.tbl[uid] = {
		uid = uid,
		score = new_score,
		info = info,
	}
	return new_score
end

function mt:add(uid, score, info)
	self:_add(uid, score, info)
	self:_db_update(uid, score, info)
end
function mt:change(uid, addscore, info)
	local new_score = self:_change(uid, addscore, info)
	self:_db_update(uid, new_score, info)
end

function mt:_db_update(uid, score, info)
	skynet.send(".mongo_mgr","lua","update",self.dbname,self.tblname,uid, score, info)
end

function mt:rem(uid)
	local element  = self.tbl[uid]
	if element then
		self.sl:delete(element.score, uid)
		self.tbl[uid] = nil
		-- 从数据库中删除
		self:_db_delete(uid)
	end
end

function mt:_db_delete(uid)
	skynet.send(".mongo_mgr","lua","delete",self.dbname,self.tblname,uid)
end

function mt:limit(count)
	local total = self.sl:get_count()
	if total <= count then
		return 0
	end

	local from = count + 1
	local to = total

	return self:_do_delete(from, to)
end

function mt:_reverse_rank(r)
	return self.sl:get_count() - r + 1
end

function mt:rev_limit(count)
	local total = self.sl:get_count()
	if total <= count then
		return 0
	end

	local from = self:_reverse_rank(count + 1)
	local to   = self:_reverse_rank(total)

	return self:_do_delete(from, to)
end

function mt:_do_delete(from, to)
	local delete_ids = {}
	local delete_function = function(uid)
		self.tbl[uid] = nil
		delete_ids[uid] = true
	end

	local ret = self.sl:delete_by_rank(from, to, delete_function)
	for uid, _ in pairs(delete_ids) do
		-- 从数据库中删除
		self:_db_delete(uid)
	end
	return ret
end

function mt:rank(uid)
	local element = self.tbl[uid]
	if not element then
		return nil
	end
	return self.sl:get_rank(element.score, uid)
end

function mt:rev_rank(uid)
	local r = self:rank(uid)
	if r then
		return self:_reverse_rank(r)
	end
	return r
end

function mt:get_info(uid)
	return self.tbl[uid]
end

function mt:range(r1, r2)
	if r1 < 1 then
		r1 = 1
	end

	if r2 < 1 then
		r2 = 1
	end
	return self.sl:get_rank_range(r1, r2)
end

function mt:rev_range(r1, r2)
	r1 = self:_reverse_rank(r1)
	r2 = self:_reverse_rank(r2)
	return self:range(r1, r2)
end

function mt:dump()
	self.sl:dump()
end

function mt:_load_db()
	local r_data = skynet.call(".mongo_mgr","lua","load_rank",self.dbname,self.tblname)
	for _,v in ipairs(r_data) do
		self:_add(v[1], v[2], v[3])
	end
end

local M = {}


function M.new(db_conf, dbname, tblname)
	local obj = {}
	obj.sl = skiplist()
	obj.tbl = {}
	obj.dbname = dbname
	obj.tblname = tblname
	setmetatable(obj, mt)
	obj:_load_db()
	return obj
end

return M
