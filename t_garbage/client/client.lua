local Peds = {} 
local targets = {}
local blips = {}
local InJob, active, leader, Invite = false

--functiot

local function OpenDoor(vehicle, door)
    if GetVehicleDoorAngleRatio(vehicle, door) > 0.0 then
        SetVehicleDoorShut(vehicle, door, false)
    else
        SetVehicleDoorOpen(vehicle, door, false, false)
    end
end

local function CreateBlip(coords, sprite, scale, color, label, id)
    blips[id] = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blips[id], sprite)
    SetBlipScale(blips[id], scale)
    SetBlipColour(blips[id], color)
    SetBlipAsShortRange(blips[id], true)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blips[id])
end

local function notify(text, kind)
    lib.notify({
        title = text,
        type = kind or 'info'
    })
end

local function IsBlocked(coords)
    for k,v in pairs(GetGamePool("CVehicle")) do
        if #(GetEntityCoords(v) - vec(coords.x, coords.y, coords.z)) <= 5 then
            return true
        end
    end
    return false
end

local function CloseTruck(coords)
    for k,v in pairs(GetGamePool("CVehicle")) do
        if GetEntityModel(v) == GetHashKey("trash") and #(GetEntityCoords(v) - vec(coords.x, coords.y, coords.z)) <= 10 then
            return v
        end
    end
    return false
end

local function Start(place)
    local coords = C.Peds[place].truckCoords
    local OwnVehicle = lib.inputDialog('Vuokraa ajoneuvo', {{type = 'checkbox', label = 'Vuokraa ajoneuvo (100$)', checked = true}})
    if not OwnVehicle or OwnVehicle[1] then
        local EnoughMoney = lib.callback.await('t_garbage:Server:Money')
        if not EnoughMoney then
            notify("Rahat ei riitä", 'error')
            return
        end
        if IsBlocked(coords) then
            notify("Paikka täynnä tavaraa, rekalla ei ole tilaa", 'error')
            return
        end
        local hash = GetHashKey("trash")
        lib.requestModel(hash)
        local veh = CreateVehicle(hash, coords.x, coords.y, coords.z, coords.w, true, true)
        local netId = VehToNet(veh) 
        TriggerServerEvent('t_garbage:Server:JobStart', place, netId, OwnVehicle[1])
    else
        local truck = CloseTruck(coords)
        if not truck then 
            notify("Rekkaa ei ole lähistöllä")
            return
        end
        local netId = VehToNet(truck)
        TriggerServerEvent('t_garbage:Server:JobStart', place, netId, OwnVehicle[1])
    end
end

local function CreateGroup(place)
    TriggerServerEvent('t_garbage:Server:CreateGroup', place)
    InJob = true
    leader = true
end


local function PickUpTrash(group, place, dumpsters, id)
    if lib.progressCircle({
        duration = 4500,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
            },
        anim = {
            dict = 'mini@repair',
            clip = 'fixing_a_ped'
        },
    })
    then
        local bHash = GetHashKey("hei_prop_heist_binbag")
        lib.requestModel(bHash)
        bag = CreateObject(bHash, 0, 0, 0, true, true, true)
        AttachEntityToEntity(bag, PlayerPedId(), GetPedBoneIndex(PlayerPedId(), 57005), 0.12, 0.0, 0.00, 25.0, 270.0, 180.0, true, true, false, true, 1, true)
        TriggerServerEvent('t_garbage:Server:Progress', group, place, dumpsters, id)
    end
end


-- Threadit jne

CreateThread(function()
    Wait(1000)
    TriggerServerEvent('t_garbage:Server:Connect')
    for k,v in pairs(C.Peds) do
        CreateBlip(v.coords, 318, 1.0, 25, "Roska-asema", "blip_"..k)
        local hash = GetHashKey(v.model)
        lib.requestModel(bHash)
        Peds[k] = CreatePed(1, hash, v.coords.x, v.coords.y, v.coords.z, v.coords.w, false, true)
    	SetBlockingOfNonTemporaryEvents(Peds[k], true)
    	SetPedDiesWhenInjured(Peds[k], false)
    	SetPedCanPlayAmbientAnims(Peds[k], true)
    	SetPedCanRagdollFromPlayerImpact(Peds[k], false)
    	FreezeEntityPosition(Peds[k], true)
        SetEntityInvincible(Peds[k], true)
        exports.ox_target:addLocalEntity(Peds[k], {
            {
                label = 'Aloita roskatyö',
                name = 'garbageJob_'..k,
                icon = 'fa-solid fa-trash-can',
                distance = 1,
                canInteract = function()
                    return not lib.progressActive() and not InJob
                end,
                onSelect = function()
                    CreateGroup(k)
                end,
            },
            {
                label = 'Aloita keikka',
                name = 'garbageStart_'..k,
                icon = 'fa-solid fa-trash-can',
                distance = 1,
                canInteract = function()
                    return not lib.progressActive() and InJob and leader and not active
                end,
                onSelect = function()
                    Start(k)
                end,
            },
            {
                label = 'Kutsu ihmisiä ryhmään',
                name = 'garbageInvite_'..k,
                icon = 'fa-regular fa-user',
                distance = 1,
                canInteract = function()
                    return not lib.progressActive() and InJob and leader and not active
                end,
                onSelect = function()
                    Invite = true
                end,
            },
            {
                label = 'Lopeta roskatyö',
                name = 'garbageEnd_'..k,
                icon = 'fa-solid fa-trash-can',
                distance = 1,
                canInteract = function()
                    return not lib.progressActive() and InJob
                end,
                onSelect = function(data)
                    if lib.progressCircle({
                        duration = 1000,
                        position = 'bottom',
                        useWhileDead = false,
                        canCancel = false,
                        disable = {
                            car = true,
                        },
                    })
                    then
                        TriggerServerEvent('t_garbage:Server:LeaveGroup')
                    end
                end,
            },
        })
    end
    exports.ox_target:addGlobalPlayer({
        {
            icon = 'fa-regular fa-user',
            label = 'Kutsu Ryhmään',
            distance = 1.5,
            canInteract = function()
                return leader and not active and Invite
            end,
            onSelect = function(data)
                Invite = false
                TriggerServerEvent('t_garbage:Server:Invite', GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity)))
            end
        }
    })
end)

CreateThread(function()
    while true do
        if InJob then
            local car = GetVehiclePedIsUsing(PlayerPedId())
            if car and car ~= 0 then
                if GetEntityModel(car) == GetHashKey("trash") then
                    if GetVehicleDoorAngleRatio(car, 5) > 0.0 and (GetEntitySpeed(car) * 3.6) > 8 then
                        notify("Ajoneuvo tunnisti takaosan olevan auki liikkelle lähdössä", "error")
                        SetVehicleHandbrake(car, true)
	                    Wait(5000)
	                    SetVehicleHandbrake(car, false)
                    end
                end
            end
        end
        Wait(3000)
    end
end)


--Eventit

RegisterNetEvent('t_garbage:Client:CleanedBin', function(trashBin)
    if targets[trashBin] then
        exports.ox_target:removeZone(targets[trashBin])
        targets[trashBin] = nil
    end
    local blip = 'trash_'..trashBin
    RemoveBlip(blips[blip])
    blips[blip] = nil
end)

RegisterNetEvent('t_garbage:Client:JoinGroup', function(place, id)
    InJob = true
    leader = false
end)

RegisterNetEvent('t_garbage:Client:Reconnect', function(group, boss)
    InJob = true
    leader = boss
    active = group.active
    if active then
        local vehicle = NetToVeh(group.vehicle.id)
        targets['vehicle'] = exports.ox_target:addLocalEntity(vehicle, {
            {
                label = "Avaa/Sulje takaosa",
                name = "openTrunk_"..vehicle,
                distance = 1.85,
                offset = vec3(0.5, 0, 0.5),
                offsetSize = 2,
                onSelect = function()
                    TriggerServerEvent('t_garbage:Server:OpenDoor', VehToNet(vehicle), 5)
                end,
            },
            {
                label = "Laita roska",
                name = "putTrash_"..vehicle,
                distance = 1.25,
                offset = vec3(0.5, 0, 0.5),
                offsetSize = 2,
                canInteract = function()
                    return bag and DoesEntityExist(bag) and GetVehicleDoorAngleRatio(vehicle, 5) > 0.0  
                end,
                onSelect = function()
                    if lib.progressCircle({
                        duration = 1000,
                        position = 'bottom',
                        useWhileDead = false,
                        canCancel = true,
                        disable = {
                            move = true,
                            car = true,
                            combat = true,
                        },
                        anim = {
                            dict = 'anim@heists@narcotics@trash',
                            clip = 'throw_b'
                        },
                    }) then
                        DeleteObject(bag)
                    end
                end,
            },
        })
    end
end)

RegisterNetEvent('t_garbage:Client:StopInvite', function()
    Invite = false
end)



RegisterNetEvent('t_garbage:Client:LeaveGroup', function()
    InJob = false
    leader = false
    active = false
    if bag then
        DeleteObject(bag)
    end
    for k,v in pairs(targets) do
        exports.ox_target:removeZone(targets[k])
    end
    for _,table in pairs(blips) do
        if string.sub(_, 1, 4) ~= 'blip' then
            RemoveBlip(blips[_])
            blips[_] = nil
        end
    end
    targets = {}
    notify("Lähdit ryhmästä")
end)



RegisterNetEvent('t_garbage:Client:Notify', notify)


RegisterNetEvent('t_garbage:Client:JobNewPlace', function(group, place, Dumpsters, bin)
    for key,value in pairs(targets) do
        if key ~= 'vehicle' then
            exports.ox_target:removeZone(targets[key])
            targets[key] = nil
        end
    end
    for _,table in pairs(blips) do
        if string.sub(_, 1, 5) == 'trash' then
            RemoveBlip(blips[_])
            blips[_] = nil
        end
    end
    notify("Saitte uuden paikan!")
    SetNewWaypoint(dumpsters[bin].Pos)
    for k,v in pairs(Dumpsters) do
        CreateBlip(dumpsters[v].Pos, 128, 0.3, 52, "Roskakori", 'trash_'..k)
        targets[k] = exports.ox_target:addBoxZone({
            coords = dumpsters[v].Pos+0.7,
            size = vector3(1.8, 1.8, 1.5),
            rotation = 45,
            drawSprite = false,
            options = {
                {
                    label = 'Kerää roskia',
                    name = 'garbageCollect_'..k,
                    icon = 'fa-solid fa-trash-can',
                    distance = 1,
                    canInteract = function()
                        return not DoesEntityExist(bag)
                    end,
                    onSelect = function()
                        PickUpTrash(group, place, Dumpsters, k)
                    end,
                },
            }
        })
    end
end)

RegisterNetEvent('t_garbage:Client:OpenDoor', function(netId, door)
    local entity = NetToVeh(netId)
    OpenDoor(entity, door)
end)

RegisterNetEvent('t_garbage:Client:DeleteVehicle', function(car)
    DeleteVehicle(NetToVeh(car))
end)

RegisterNetEvent('t_garbage:Client:JobStart', function(group, place, car)
    notify("Keikka alkaa!")
    active = true
    local vehicle = NetToVeh(car)
    if not DoesEntityExist(vehicle) then
        Wait(1000)
        local coords = C.Peds[place].truckCoords
        vehicle = CloseTruck(coords)
    end 
    targets['vehicle'] = exports.ox_target:addLocalEntity(vehicle, {
        {
            label = "Avaa/Sulje takaosa",
            name = "openTrunk_"..vehicle,
            distance = 1.85,
            offset = vec3(0.5, 0, 0.5),
            offsetSize = 2,
            onSelect = function()
                TriggerServerEvent('t_garbage:Server:OpenDoor', VehToNet(vehicle), 5)
            end,
        },
        {
            label = "Laita roska",
            name = "putTrash_"..vehicle,
            distance = 1.25,
            offset = vec3(0.5, 0, 0.5),
            offsetSize = 2,
            canInteract = function()
                return bag and DoesEntityExist(bag) and GetVehicleDoorAngleRatio(vehicle, 5) > 0.0  
            end,
            onSelect = function()
                if lib.progressCircle({
                    duration = 1000,
                    position = 'bottom',
                    useWhileDead = false,
                    canCancel = true,
                    disable = {
                        move = true,
                        car = true,
                        combat = true,
                    },
                    anim = {
                        dict = 'anim@heists@narcotics@trash',
                        clip = 'throw_b'
                    },
                }) then
                    DeleteObject(bag)
                end
            end,
        },
    })
end)

-- Callbackit

lib.callback.register('t_garbage:Client:Invite', function()
    local accept = true
    local alert = lib.alertDialog({
        header = 'Sinut Kutsuttiin Tekemään Roskatyötä',
        content = 'Hyväksy kutsu ryhmään',
        cancel = true,
        
    })
    if alert == 'cancel' then
        accept = false
    end
    return accept
end)