-- Enemy identity service (Coder B, 2026-10-14). Framework service: maps native enemy rows to the boss or miniboss that
-- owns them, by the actor's data asset name (BP_Boss.Boss, BP_MiniBoss.DA_MiniBoss) and actor class name.
-- * A row is identified by its slot (the actor's MyIndex, once initialized: MaxHP > 0) and by its enemy class
--   (the asset's EnemyClass), so a row is known even while its actor is still initializing.
-- * Liveness: the live actors are found again on every refresh; no UObject handle is kept. Only names and numbers are
--   cached, per actor lifetime (keyed by its full name), so the asset and class names are read once per actor.
-- * Read-only: nothing in the game is written.
local Identity={};Identity.__index=Identity
Identity.SOURCES={{class='BP_Boss_C',asset='Boss'},{class='BP_MiniBoss_C',asset='DA_MiniBoss'}}
Identity.GAME='/Game/Maps/Game.'
Identity.INTERVAL=0.25
function Identity.new(G,options)
    options=options or {}
    return setmetatable({G=G,now=options.now or os.clock,interval=options.interval or Identity.INTERVAL,
        cache={},list={},bySlot={},byType={},last=nil},Identity)
end
local function text(object)
    local name=object:GetFName():ToString()
    return type(name)=='string' and name~='' and name or nil
end
-- The cached part of one actor: its names and class (read once), or nil when it cannot be read yet.
local function describe(actor,assetField)
    local names={}
    local className=text(actor:GetClass())
    if className then names[className]=true end
    local enemyType
    local asset=actor[assetField]
    if asset~=nil and asset:IsValid() then
        local assetName=text(asset)
        if assetName then names[assetName]=true end
        local class=asset.EnemyClass
        if type(class)=='number' and class==math.floor(class) then enemyType=class end
    end
    if next(names)==nil then return nil end
    return {names=names,enemyType=enemyType}
end
local function slotOf(actor)
    local index,maxHp=actor.MyIndex,actor.MaxHP
    if type(index)=='number' and index==math.floor(index) and index>=0 and type(maxHp)=='number' and maxHp>0 then return index end
end
-- Rebuilds the map from the live actors, at most once per interval unless forced. Returns true when it rebuilt.
function Identity:refresh(force)
    local now=self.now()
    if not force and self.last and now-self.last<self.interval then return false end
    self.last=now
    local cache,list,bySlot,byType,seen={}, {}, {}, {}, {}
    for _,source in ipairs(Identity.SOURCES) do
        local ok,actors=pcall(self.G.FindAllOf,source.class)
        if ok and type(actors)=='table' then
            for _,actor in ipairs(actors) do
                pcall(function()
                    if not actor:IsValid() then return end
                    local key=actor:GetFullName()
                    if type(key)~='string' or not key:find(Identity.GAME,1,true) or seen[key] then return end
                    local info=self.cache[key] or describe(actor,source.asset)
                    if not info then return end
                    seen[key]=true;cache[key]=info
                    local entry={key=key,slot=slotOf(actor),enemyType=info.enemyType,names=info.names}
                    list[#list+1]=entry
                    if entry.slot then bySlot[entry.slot]=entry end
                    if entry.enemyType then
                        local set=byType[entry.enemyType] or {}
                        for name in pairs(info.names) do set[name]=true end
                        byType[entry.enemyType]=set
                    end
                end)
            end
        end
    end
    self.cache,self.list,self.bySlot,self.byType=cache,list,bySlot,byType
    return true
end
-- The names (a set) of the boss or miniboss owning this row, or nil. Either argument may be nil when unknown.
-- A slot whose recorded class differs from the given one was reused by another enemy and does not match.
function Identity:namesFor(slot,enemyType)
    local entry=slot~=nil and self.bySlot[slot] or nil
    if entry and (enemyType==nil or entry.enemyType==nil or entry.enemyType==enemyType) then return entry.names end
    if enemyType~=nil then return self.byType[enemyType] end
end
function Identity:entries() return self.list end
function Identity:count() return #self.list end
return Identity
