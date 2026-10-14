-- D57 (user, 2026-10-14): using mods disables achievements, and that belongs to Mod Menu. The native ModMenuGuard
-- (native/mm_guard, a UE4SS C++ mod inside Win64) denies every stats-changing SteamCorePro function (achievements,
-- stats, leaderboard score uploads) and registers into this Lua state:
--   MM_AchievementGuard() -> ready, reason, denied, found, late, unclassified, proven
--   MM_AchievementGuardBlocks() -> '<Class>:<Function>=<calls>;...' (blocked calls, the self-proof's own left out)
-- This module reads it. The native guard installs its denies at Unreal init and proves them on the game thread a
-- little later, so its first reasons may be pending (not_started, pending_surface, proof_pending): logged once as
-- 'MMGUARD PENDING <reason>' and re-read on every tick (and by the notice) until the status settles. Then one line:
-- 'MMGUARD READY denied=<n> found=<n>' or 'MMGUARD UNAVAILABLE <reason>'; and 'MMGUARD BLOCK <Class>:<Function>
-- calls=<n>' whenever a function's blocked-call count grows (tick).
-- When the guard cannot be confirmed, Mod Menu shows NOTICE on the main menu and play stays allowed (user, D57: warn
-- and allow; nothing is disabled). A status that is missing, raises, is malformed or contradicts itself is never ready.
local Guard={}
Guard.__index=Guard
-- Short enough for 584 px of logical width (the smallest supported window); styled by Menu_Options' hierarchy.
Guard.NOTICE='Achievement protection not confirmed - achievements may unlock'
local PENDING={not_started=true,pending_surface=true,proof_pending=true}

function Guard.new(env,log)
    return setmetatable({env=env or _G,log=log or function() end,counts={}},Guard)
end
local function integer(v) return math.type(v)=='integer' and v>=0 end
function Guard:_read()
    local fn=self.env.MM_AchievementGuard
    if type(fn)~='function' then return {ready=false,reason='guard_not_loaded'} end
    local ok,ready,reason,denied,found,late,unclassified,proven=pcall(fn)
    if not ok then return {ready=false,reason='status_error:'..tostring(ready):gsub('%s','_'):sub(1,120)} end
    if type(ready)~='boolean' or type(reason)~='string' or not integer(denied) or not integer(found)
        or type(late)~='boolean' then
        return {ready=false,reason='status_malformed'}
    end
    if ready and (reason~='ready' or late or proven~=true) then return {ready=false,reason='status_contradictory'} end
    return {ready=ready,reason=reason,denied=denied,found=found,late=late,unclassified=unclassified,proven=proven,
        pending=(not ready and PENDING[reason]) or nil}
end
-- Read until the status is final; log each transition once (PENDING, then READY or UNAVAILABLE).
function Guard:_settle()
    if self.status and not self.status.pending then return self.status end
    local status=self:_read()
    if status.pending then
        if not self.status then self.log('MMGUARD PENDING '..status.reason) end
    elseif status.ready then
        self.log(string.format('MMGUARD READY denied=%d found=%d',status.denied,status.found))
    else
        self.log('MMGUARD UNAVAILABLE '..status.reason)
    end
    self.status=status
    return status
end
function Guard:start() return self:_settle() end
function Guard:ready() return self:_settle().ready==true end
-- The main-menu notice: a status still pending when the menu is built counts as not confirmed (warn, allow).
function Guard:notice() if self:ready() then return nil end return Guard.NOTICE end
function Guard:allowsPlay() return true end   -- D57: warn and allow
-- Poll: settle a pending status, then the blocked-call counts (cheap; a few times a minute is enough), each growth once.
function Guard:tick()
    self:_settle()
    local fn=self.env.MM_AchievementGuardBlocks
    if type(fn)~='function' then return end
    local ok,text=pcall(fn)
    if not ok or type(text)~='string' then return end
    for name,n in text:gmatch('([%w_]+:[%w_]+)=(%d+);') do
        local calls=tonumber(n)
        if calls and calls>(self.counts[name] or 0) then
            self.counts[name]=calls
            self.log(string.format('MMGUARD BLOCK %s calls=%d',name,calls))
        end
    end
end
return Guard
