BiSPulseData = BiSPulseData or {}
BiSPulseData.specs = BiSPulseData.specs or {}

-- Rank weights used for scoring / alert thresholds.
BiSPulseData.RANK = {
  BIS = "bis",
  STRONG = "strong",
  ALT = "alt",
  OK = "ok",
}

BiSPulseData.RANK_SCORE = {
  bis = 100,
  strong = 82,
  alt = 68,
  ok = 52,
}

BiSPulseData.RANK_ORDER = {
  bis = 4,
  strong = 3,
  alt = 2,
  ok = 1,
}

--- Register a specialization BiS pack.
-- @param classFile string e.g. "DEMONHUNTER"
-- @param specIndex number GetSpecialization() index (1-based)
-- @param pack table
function BiSPulseData:Register(classFile, specIndex, pack)
  self.specs[classFile] = self.specs[classFile] or {}
  self.specs[classFile][specIndex] = pack
end

function BiSPulseData:GetPack(classFile, specIndex)
  local byClass = self.specs[classFile]
  return byClass and byClass[specIndex] or nil
end
BiSPulseData.GetPack = BiSPulseData.GetPack

function BiSPulseData:LookupItem(pack, itemID)
  if not pack or not itemID then
    return nil
  end
  return pack.items[itemID]
end
