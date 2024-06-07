local M = {}

function M.get_rankid(appname, tag)
	return string.format("%s@%s", appname, tag)
end
function M.split_rankid(rankid)
	local reps  = "@"
	local r = {}
	if rankid == nil then return nil end
	string.gsub(rankid, "[^"..reps.."]+", function(w) table.insert(r, w) end)
	return r
end

return M
