-- Demonstration only: changes this settings panel, never gameplay or achievements.
local ctx=...
local Ini=require('mm_ini')
local text,err=ctx.readConfig()
assert(text,err)
local settings=Ini.read(text).Settings or {}
local enabled=settings.PreviewEnabled=='true'
local number=tonumber(settings.Number) or 3
if number~=number or number<0 or number>10 or number%1~=0 then number=3 end
local function save(key,value,commit)
    local current,why=ctx.readConfig()
    if not current then return nil,why end
    local ok,problem=ctx.writeConfig(Ini.set(current,'Settings',key,tostring(value)))
    if not ok then return nil,problem end
    commit(value); ctx.invalidate(); return true
end
ctx.registerSettings({
    build=function(ui,panel)
        ui.boolean(panel,'Preview enabled',enabled,function(value)
            if type(value)~='boolean' then return nil,'Expected boolean' end
            return save('PreviewEnabled',value,function(v) enabled=v end)
        end)
        ui.number(panel,'Example number',number,0,10,1,function(value)
            if type(value)~='number' or value~=value or value%1~=0 or value<0 or value>10 then
                return nil,'Expected integer 0-10'
            end
            return save('Number',value,function(v) number=v end)
        end)
    end,
    buildInfo=function(ui,panel)
        ui.label(panel,'Example only: settings change this panel, not gameplay.')
    end,
    restartRequired=function() return false end,
})
