local function SafeRegisterEvent(frame, event)
  if not frame or not event then
    return false
  end
  if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(event) then
    return false
  end
  local ok = pcall(frame.RegisterEvent, frame, event)
  return ok
end

BiSPulseSafeRegisterEvent = SafeRegisterEvent

-- Custom addon art (TGA, no file extension in the path)
BiSPulse.ICON = "Interface\\AddOns\\BiSPulse\\Media\\BiSPulseIcon"
BiSPulse.MINIMAP_ICON = "Interface\\AddOns\\BiSPulse\\Media\\BiSPulseMinimap"
