local M = {}
function M.read(path)
    local f,err,code = io.open(path, 'rb')
    if not f then
        if code~=2 and err~=nil then return nil,'Read failed: '..tostring(err) end
        -- A power loss between the two renames must not turn an existing registry into defaults.
        local backupError,backupCode
        f,backupError,backupCode = io.open(path .. '.modmenu-backup', 'rb')
        if not f and backupCode~=2 and backupError~=nil then return nil,'Backup read failed: '..tostring(backupError) end
        if f then print('[mod_menu] Using preserved configuration backup for ' .. path .. '; manual recovery required.\n') end
    end
    if not f then return nil,'missing' end
    local s,why = f:read('*a'); local closed,closeError=f:close()
    if s==nil or not closed then return nil,'Read failed: '..tostring(why or closeError) end
    return s
end
function M.absent(path)
    local text,err=M.read(path)
    return text==nil and (err==nil or err=='missing')
end
function M.replace(path, text, onlyMissing, expected)
    -- Same-directory replacement. Never truncate the previous live file.
    local temp, backup = path .. '.modmenu-new', path .. '.modmenu-backup'
    if not M.absent(temp) or not M.absent(backup) then return nil, 'Unfinished config transaction: ' .. path end
    local old,readError=M.read(path)
    if readError and readError~='missing' then return nil,readError end
    if onlyMissing and old~=nil then return true end
    if expected~=nil and old~=expected then return nil,'Settings changed during default merge' end
    local f, err = io.open(temp, 'wb'); if not f then return nil, err end
    local wrote, why = f:write(text); local closed = f:close()
    if not wrote or not closed or M.read(temp) ~= text then os.remove(temp); return nil, why or 'Config verification failed' end
    if old then
        local ok, e = os.rename(path, backup)
        if not ok then os.remove(temp); return nil, e end
    end
    local ok, e = os.rename(temp, path)
    if not ok then
        if old then os.rename(backup, path) end
        os.remove(temp); return nil, e
    end
    if old then os.remove(backup) end
    return true
end
function M.prepareSettings(path,defaults)
    local existing,err=M.read(path)
    if err and err~='missing' then return nil,err end
    if existing==nil then return M.replace(path,defaults or '[Settings]\n',true) end
    if not defaults then return true end
    local merged,why=require('mm_ini').mergeDefaults(existing,defaults)
    if not merged then return nil,why end
    if merged==existing then return true end
    local backup
    for i=1,100 do
        local candidate=path..'.before-defaults-'..os.time()..'-'..i..'.bak'
        if M.absent(candidate) then backup=candidate; break end
    end
    if not backup then return nil,'Cannot allocate settings backup' end
    local ok,problem=M.replace(backup,existing,true)
    if not ok then return nil,problem end
    if M.read(backup)~=existing then return nil,'Settings backup verification failed' end
    return M.replace(path,merged,false,existing)
end
function M.norm(path) return path:gsub('\\', '/'):gsub('/+$', '') end
function M.paths(source, directories)
    local dir = M.norm(source:gsub('^@', '')):match('^(.*)/[Ss][Cc][Rr][Ii][Pp][Tt][Ss]/main%.lua$')
    assert(dir, 'Cannot resolve mod_menu script path')
    if not dir:match('^%a:/') and not dir:match('^//') then
        local found
        local function walk(t)
            if type(t) ~= 'table' then return end
            local p = t.__absolute_path and M.norm(t.__absolute_path)
            if p and p:lower():match('/mods/mod_menu$') then
                assert(not found or found == p, 'Ambiguous mod_menu directories'); found = p
            end
            for k, v in pairs(t) do if type(v) == 'table' and k ~= '__files' then walk(v) end end
        end
        walk(directories); dir = assert(found, 'Absolute script location unavailable')
    end
    local root = dir:match('^(.*)/[Mm][Oo][Dd][Ss]/mod_menu$')
    assert(root and root:lower():match('/win64$'), 'Run only from a build-local Win64/Mods/mod_menu installation')
    return {mod=dir, root=root, mods=root .. '/Mods', configs=root .. '/Configs'}
end
function M.folders(tree, root)
    local found = {}
    local function walk(t)
        if type(t) ~= 'table' then return end
        if t.__absolute_path and M.norm(t.__absolute_path):lower() == root:lower() then
            for k, v in pairs(t) do
                if k ~= '__files' and type(v) == 'table' and v.__name then found[#found+1] = v.__name end
            end
            return
        end
        for k,v in pairs(t) do if k ~= '__files' and type(v) == 'table' then walk(v) end end
    end
    walk(tree); table.sort(found); return found
end
-- Reject cmd metacharacters before using Windows' mkdir/start builtins.
function M.shellPath(path)
    assert(not path:find('["%%!&|<>%^\r\n]'), 'Path cannot safely be passed to the Windows shell')
    return '"' .. path:gsub('/', '\\') .. '"'
end
function M.ensureConfigs(path)
    local ok = os.execute('if not exist ' .. M.shellPath(path) .. ' mkdir ' .. M.shellPath(path))
    return ok == true or ok == 0
end
return M
