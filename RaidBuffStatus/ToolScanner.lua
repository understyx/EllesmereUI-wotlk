-- RBS mini Tooltip scanner
RBS_svnrev["ToolScanner.lua"] = select(3,string.find("$Revision: 388 $", ".* (.*) .*"))

local RBSToolScanner = CreateFrame('GameTooltip', 'RBSToolScanner', WorldFrame, 'GameTooltipTemplate')
RBSToolScanner:SetOwner(WorldFrame, "ANCHOR_NONE")

function RBSToolScanner:Find(text)
	local lines = self:NumLines()
	for l = 2, lines do  -- don't care about name of item; instead interested in text about it
		local left = getglobal('RBSToolScannerTextLeft' .. l):GetText()
		if left then
			if string.find(left, text) then
				return true
			end
		else
			return false
		end
	end
	return false
end
