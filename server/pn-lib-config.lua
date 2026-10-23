--- PN Base: expose les réglages essentiels de cette ressource à pn-lib (panel web + /configpn en jeu).
--- Sans effet si pn-lib n'est pas installé. Les valeurs sont lues à l'usage : les changements sont appliqués en direct.
local FIELDS = {
    { source = 'config.server', key = 'grapeAmountMin', path = 'grapeAmount.min', label = 'Raisins min. par récolte', description = 'Doit rester inférieur ou égal au maximum', valueType = 'number', min = 1, max = 100 },
    { source = 'config.server', key = 'grapeAmountMax', path = 'grapeAmount.max', label = 'Raisins max. par récolte', valueType = 'number', min = 1, max = 100 },
    { source = 'config.server', key = 'grapeJuiceAmountMin', path = 'grapeJuiceAmount.min', label = 'Jus de raisin min. produit', description = 'Doit rester inférieur ou égal au maximum', valueType = 'number', min = 1, max = 100 },
    { source = 'config.server', key = 'grapeJuiceAmountMax', path = 'grapeJuiceAmount.max', label = 'Jus de raisin max. produit', valueType = 'number', min = 1, max = 100 },
    { source = 'config.server', key = 'wineAmountMin', path = 'wineAmount.min', label = 'Vin min. produit', description = 'Doit rester inférieur ou égal au maximum', valueType = 'number', min = 1, max = 100 },
    { source = 'config.server', key = 'wineAmountMax', path = 'wineAmount.max', label = 'Vin max. produit', valueType = 'number', min = 1, max = 100 },
}

local function resolve(root, path)
    local holder, last = root, path
    for part in path:gmatch('([^%.]+)%.') do
        holder = holder[part]
        if type(holder) ~= 'table' then return nil end
    end
    return holder, path:match('([^%.]+)$') or last
end

CreateThread(function()
    if GetResourceState('pn-lib') == 'missing' then return end
    local waited = 0
    while GetResourceState('pn-lib') ~= 'started' do
        Wait(500)
        waited = waited + 500
        if waited >= 120000 then return end
    end

    local ns = GetCurrentResourceName()
    local ok, err = pcall(function()
        local schema, targets = {}, {}
        for i = 1, #FIELDS do
            local f = FIELDS[i]
            local root = f.global and _G[f.global] or require(f.source)
            local holder, last = resolve(root, f.path or f.key)
            if holder and holder[last] ~= nil then
                targets[f.key] = { holder = holder, last = last }
                schema[#schema + 1] = {
                    key = f.key, label = f.label, description = f.description,
                    valueType = f.valueType, min = f.min, max = f.max,
                    default = holder[last],
                }
            else
                print(('[%s] réglage pn-lib ignoré (introuvable): %s.%s'):format(ns, f.source, f.key))
            end
        end

        exports['pn-lib']:RegisterConfig(ns, schema)

        for i = 1, #schema do
            local key = schema[i].key
            local t = targets[key]
            local current = exports['pn-lib']:GetConfig(ns, key)
            if current ~= nil then t.holder[t.last] = current end
            exports['pn-lib']:OnConfigChange(ns, key, function(value)
                if value ~= nil then t.holder[t.last] = value end
            end)
        end
    end)
    if not ok then
        print(('[%s] configuration pn-lib indisponible: %s'):format(ns, tostring(err)))
    end
end)
