local activeGroups = {}
local activePlayers = {}
-- functiot

local function GiveNewPlace(group, place)
    activeGroups[place][group].progress.trash = {}
    local new = {}
    local dump = math.random(#dumpsters)
    local s = dumpsters[dump]
    for k,v in pairs(dumpsters) do
        if #(s.Pos - v.Pos) < 10 then
            table.insert(new, k)
            table.insert(activeGroups[place][group].progress.trash, 0)
        end
    end
    for k,v in pairs(activeGroups[place][group].players) do
        TriggerClientEvent('t_garbage:Client:JobNewPlace', v.s, group, place, new, dump)
    end
end

local function StartWorking(group, place, vehicle, Own)
    activeGroups[place][group].active = true
    activeGroups[place][group].vehicle = {id = vehicle, rent = Own}
    for k,v in pairs(activeGroups[place][group].players) do
        TriggerClientEvent('t_garbage:Client:JobStart', v.s, group, place, vehicle)
    end
    GiveNewPlace(group, place)
end

local function PlaceCleaned(group, place, id)
    for k,v in pairs(activeGroups[place][group].players) do
        TriggerClientEvent('t_garbage:Client:CleanedBin', v.s, id)
    end
end

local function RewardGroup(place, group)
    local places = activeGroups[place][group].progress.places
    for k,v in pairs(activeGroups[place][group].players) do
        exports.ox_inventory:AddItem(v.s, 'money', places*100)
    end
end

local function DeleteGroup(place, group, source)
    local vehicle = activeGroups[place][group].vehicle
    if vehicle and vehicle.rent then
        TriggerClientEvent('t_garbage:Client:DeleteVehicle', source, vehicle.id)
    end
    for k,v in pairs(activeGroups[place][group].players) do
        activePlayers[v.id] = nil
        TriggerClientEvent('t_garbage:Client:Notify', v.s, "Ryhmäsi poistettiin.")
        TriggerClientEvent('t_garbage:Client:LeaveGroup', v.s)
    end
    if activeGroups[place][group].progress.places > 0 then
        RewardGroup(place, group)
    end
    activeGroups[place][group] = nil
end

local function IsLeader(source, place)
    for k,v in pairs(activeGroups[place]) do
        if v.leader == GetPlayerIdentifierByType(source, 'license') then
            return true, k
        end
    end
    return false
end

local function IsCloseEnough(source, table)
    local C = GetEntityCoords(GetPlayerPed(source))
    for k,v in pairs(table) do
        if #(dumpsters[v].Pos - C) < 5 then
            return true
        end
    end
    return false
end

local function IsGroupReadyForNew(group, place) 
    local p = 0
    local prog = activeGroups[place][group].progress.trash
    for k,v in pairs(prog) do
        if v >= 2 then
            p = p+1
        end
    end
    return p == #prog
end

-- Eventit

RegisterNetEvent('t_garbage:Server:Progress', function(group, place, trashplace, id)
    local src = source
    if activeGroups[place] and activeGroups[place][group] then
        if IsCloseEnough(src, trashplace) then
            local progress = activeGroups[place][group].progress.trash[id]+1
            activeGroups[place][group].progress.trash[id] = progress
            if progress >= 2 then
                PlaceCleaned(group, place, id)
            end
            if IsGroupReadyForNew(group, place) then
                activeGroups[place][group].progress.places = activeGroups[place][group].progress.places+1
                GiveNewPlace(group, place)
            end
        end
    end
end)


RegisterNetEvent('t_garbage:Server:CreateGroup', function(place)
    local src = source
    local license = GetPlayerIdentifierByType(src, 'license')
    local PlaceCoords = C.Peds[place].coords
    if #(GetEntityCoords(GetPlayerPed(src)) - vec3(PlaceCoords.x, PlaceCoords.y, PlaceCoords.z)) < 10 then
        if not activeGroups[place] then
            activeGroups[place] = {}
        end
        local groupId = #activeGroups[place]+1
        activePlayers[license] = {id = groupId, place = place}
        activeGroups[place][groupId] = {leader = license, active = false, players = {{id = license, s = src}}, progress = {places = 0, trash = {}}}
    end
end)

RegisterNetEvent('t_garbage:Server:Invite', function(target)
    local src = source
    local license = GetPlayerIdentifierByType(src, 'license')
    local player = activePlayers[license]
    local players = activeGroups[player.place][player.id].players
    local Tlicense = GetPlayerIdentifierByType(target, 'license')
    if #players >= 4 then
        TriggerClientEvent('t_garbage:Client:Notify', src, "Ryhmä Täynnä!")
        TriggerClientEvent('t_garbage:Client:StopInvite', src)
        return 
    end
    if activePlayers[Tlicense] then
        TriggerClientEvent('t_garbage:Client:Notify', src, "Henkilö työskentelee jo ryhmässä!")
        TriggerClientEvent('t_garbage:Client:StopInvite', src)
        return 
    end
    local accept = lib.callback.await('t_garbage:Client:Invite', target)
    if not accept then
        TriggerClientEvent('t_garbage:Client:Notify', src, "Kutsu hylättiin.")
        return
    end
    for k,v in pairs(players) do
        TriggerClientEvent('t_garbage:Client:Notify', v.s, "Uusi jäsen liittyi ryhmään")
    end
    activePlayers[Tlicense] = {id = player.id, place = player.place}
    TriggerClientEvent('t_garbage:Client:JoinGroup', target)
    table.insert(activeGroups[player.place][player.id].players, {id = Tlicense, s = target})
end)

RegisterNetEvent('t_garbage:Server:LeaveGroup', function()
    local src = source
    local license = GetPlayerIdentifierByType(src, 'license')
    local table = activePlayers[license]
    if not table then 
        return
    end
    if IsLeader(src, table.place) then
        DeleteGroup(table.place, table.id, src)
    else
        for k,v in pairs(activeGroups[table.place][table.id].players) do
            TriggerClientEvent('t_garbage:Client:Notify', v.s, "Yksi jäsen lähti ryhmästä")
            if v.id == license then
                activeGroups[table.place][table.id].players[k] = nil
            end
        end
        activePlayers[license] = nil
        TriggerClientEvent('t_garbage:Client:LeaveGroup', src)
    end
end)



RegisterNetEvent('t_garbage:Server:JobStart', function(place, vehicle, own)
    local src = source
    local IsLeader,_ = IsLeader(src, place)
    if IsLeader then
        StartWorking(_, place, vehicle, own)
    end
end)


RegisterNetEvent('t_garbage:Server:OpenDoor', function(netId, door)
    local object = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(object) then
        return
    end
    local owner = NetworkGetEntityOwner(object)
    TriggerClientEvent('t_garbage:Client:OpenDoor', owner, netId, door)
end)


RegisterNetEvent('t_garbage:Server:Connect', function()
    local src = source
    local license = GetPlayerIdentifierByType(src, 'license')
    if activePlayers[license] then
        local group = activeGroups[activePlayers[license].place][activePlayers[license].id]
        if group then
            local IsLeader = group.leader == license
            for k,v in pairs(group.players) do
                if v.id == license then
                    activeGroups[activePlayers[license].place][activePlayers[license].id].players[k].s = src
                end
            end
            TriggerClientEvent('t_garbage:Client:Reconnect', src, group, IsLeader)
        else
            activePlayers[license] = nil
        end
    end
end)
 
-- Callbackit

lib.callback.register('t_garbage:Server:Money', function(source)
    local count = exports.ox_inventory:GetItemCount(source, 'money') >= 100
    if count then
        exports.ox_inventory:RemoveItem(source, 'money', 100)
    end
    return count
end)