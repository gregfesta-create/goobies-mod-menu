-- UE4SS entry: this is the only auto-started Lua mod in the managed-package design.
local source=debug.getinfo(1,'S').source
local scripts=assert(source:match('^@(.*)[/\\]main%.lua$'),'Cannot locate mod_menu Scripts')
package.path=scripts .. '/?.lua;' .. package.path
local function log(message) print('[mod_menu] ' .. tostring(message) .. '\n') end
local ok,err=pcall(function()
    local FS=require('mm_platform'); local Core=require('mm_core')
    local tree=IterateGameDirectories()
    local paths=FS.paths(source,tree)
    assert(FS.ensureConfigs(paths.configs),'Cannot create build-local Configs directory')
    local core=Core.new(FS,paths.configs .. '/ModList.ini',log,{
        legacyPath=paths.configs .. '/mods.ini',
        defaultText=FS.read(paths.mod .. '/Defaults/Configs/ModList.ini') or '[Mods]\nModMenu=true|Ver:'..Core.VERSION..'|Inst:?|Upd:?\n'})
    local own=assert(Core.manifest(assert(FS.read(paths.mod .. '/mod_menu.ini'),'Manager manifest missing')))
    assert(own.id=='ModMenu' and own.version==Core.VERSION,'Manager manifest does not match implementation')
    core:add(own)
    for _,folder in ipairs(FS.folders(tree,paths.mods)) do
        if folder:lower()~='mod_menu' and Core.identifier(folder) then
            local base=paths.mods .. '/' .. folder
            local text=FS.read(base .. '/mod_menu.ini')
            if text then
                local p,problem=Core.manifest(text)
                if p then
                    p.folder=base
                    p.managed=p.entry~=nil and FS.absent(base .. '/Scripts/main.lua') and FS.absent(base .. '/dlls/main.dll')
                    if not p.managed then p.reason='External UE4SS/native package: ModList.ini cannot prevent its loading.' end
                    local added,why=core:add(p); if not added then log(why) end
                else log(folder .. ': ' .. problem) end
            elseif FS.read(base .. '/Scripts/main.lua') or FS.read(base .. '/dlls/main.dll') then
                core:add({id=folder,name=folder,managed=false,unknown=true,
                    reason='No mod_menu manifest: version and enabled state are unknown. Managed-package conversion is required.'})
            end
        end
    end
    local saved,why=core:save()
    if not saved then
        log('Registry save failed; optional managed startup suppressed: ' .. tostring(why))
        core.warning=tostring(why)
        for _,p in ipairs(core.mods) do if not p.locked then p.startEnabled=false end end
    end
    local ui
    local menuStyles={}
    local function context(p)
        local config=paths.configs .. '/' .. p.id .. '.ini'
        -- Context is requested only for enabled packages during startup.
        local initial,defaultError=FS.read(p.folder..'/Defaults/Configs/'..p.id..'.ini')
        if defaultError and defaultError~='missing' then error(defaultError) end
        local prepared,problem=FS.prepareSettings(config,initial)
        assert(prepared,problem)
        return {id=p.id,packagePath=p.folder,configPath=config,readConfig=function() return FS.read(config) end,
            writeConfig=function(text) return FS.replace(config,text) end,
            query=function(id) return core:query(id) end,
            requestMenuBack=function() if ui then ui:requestBack() end end,
            registerMainMenuStyle=function(callback)
                assert(type(callback)=='function','Expected main menu style callback')
                menuStyles[p.id]=callback
            end,
            registerSettings=function(provider) core:provider(p.id,provider) end,
            invalidate=function() core.dirtyProviders[p.id]=true end,
            log=function(message) log(p.id .. ': ' .. tostring(message)) end}
    end
    -- Enabled packages run before UI initialization, so a UI failure does not prevent startup.
    -- Package/main.lua avoids UE4SS's Scripts/dlls discovery and duplicate execution.
    core:start(function(p,ctx)
        local environment=setmetatable({ModMenu=ctx},{__index=_G})
        environment._G=environment
        local chunk=assert(loadfile(p.folder .. '/' .. p.entry,'t',environment))
        return chunk(ctx)
    end,context)
    local UI=require('mm_ui'); local Restart=require('mm_restart')
    ui=UI.new(_G,core,paths,log,Restart.new(_G,paths,log))
    ui.menuStyles=menuStyles
    ui.status=core.warning
    ui:start()
    -- State-local inspection handle; not an inter-mod-Lua-state communication claim.
    ModMenuManager={registry=core,ui=ui,paths=paths}
    log('Initialized standalone manager ' .. Core.VERSION)
end)
if not ok then log('Initialization failed: ' .. tostring(err)) end
