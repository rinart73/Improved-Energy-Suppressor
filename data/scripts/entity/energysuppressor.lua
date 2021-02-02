include("faction")
include("stringutility")

local iES_initialize -- extended server functions
local iES_initUI, iES_onSync -- extended client functions
local iES_sendMailCheckBox -- client UI
local iES_Config -- server


if onClient() then -- CLIENT


function EnergySuppressor.interactionPossible(playerIndex, option) -- overridden
    return checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
end

iES_initUI = EnergySuppressor.initUI
function EnergySuppressor.initUI(...)
    if iES_initUI then iES_initUI(...) end

    local res = getResolution()
    local size = vec2(500, 50)

    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    window.caption = "Settings"%_t
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "Settings"%_t)

    iES_sendMailCheckBox = window:createCheckBox(Rect(10, 10, window.width - 10, 30), "Send a mail when suppressor will burn out or will be destroyed"%_t, "iES_onSendMailChecked")
    iES_sendMailCheckBox.captionLeft = false
    iES_sendMailCheckBox.fontSize = 13
    iES_sendMailCheckBox:setCheckedNoCallback(EnergySuppressor.data.sendmail)
end

iES_onSync = EnergySuppressor.onSync
function EnergySuppressor.onSync(...)
    iES_onSync(...)

    if iES_sendMailCheckBox then
        iES_sendMailCheckBox:setCheckedNoCallback(EnergySuppressor.data.sendmail)
    end
end

function EnergySuppressor.iES_onSendMailChecked(checkbox, value)
    invokeServerFunction("iES_onSendMailChecked", value)
end


else -- SERVER


Azimuth = include("azimuthlib-basic")

iES_initialize = EnergySuppressor.initialize
function EnergySuppressor.initialize(...)
    iES_initialize(...)
    
    local configOptions = {
      _version = {"1.2", comment = "Config version. Don't touch."},
      CreateWreckage = {true, comment = "If false, burned out energy suppressors will disappear instead of turning into a wreckage."},
      Duration = {600, round = -1, min = 0, comment = "How long (in MINUTES) do energy suppressor work."}
    }
    local isModified
    iES_Config, isModified = Azimuth.loadConfig("ImprovedEnergySuppressor", configOptions)
    if isModified then
        Azimuth.saveConfig("ImprovedEnergySuppressor", iES_Config, configOptions)
    end
    EnergySuppressor.data.time = iES_Config.Duration * 60

    Entity():registerCallback("onDestroyed", "iES_onDestroyed")
end

function EnergySuppressor.updateServer(timeStep) -- overridden
    EnergySuppressor.data.time = EnergySuppressor.data.time - timeStep

    if EnergySuppressor.data.time <= 0 then
        EnergySuppressor.iES_notify([[%1%Your energy signature suppressor in sector %2%(%3%:%4%) has burnt out!]]%_T, [[%1%Your alliance energy signature suppressor in sector %2%(%3%:%4%) has burnt out!]]%_T)
        -- Create Wreckage
        local entity = Entity()
        entity:unregisterCallback("onDestroyed", "iES_onDestroyed")
        local position = entity.position
        local plan = entity:getMovePlan()
        -- remove energy suppressor
        Sector():deleteEntity(entity)
        -- create a wreckage in its place
        if iES_Config.CreateWreckage then
            Sector():createWreckage(plan, position)
        end
    end
end

function EnergySuppressor.iES_notify(playerMsg, allianceMsg)
    local x, y = Sector():getCoordinates()
    -- send message
    local faction = getParentFaction()
    if faction.isAlliance then
        faction:sendChatMessage("Energy Signature Suppressor"%_T, ChatMessageType.Warning, allianceMsg, '', '\\s', x, y)
    else
        faction:sendChatMessage("Energy Signature Suppressor"%_T, ChatMessageType.Warning, playerMsg, '', '\\s', x, y)
    end
    -- send mail
    if EnergySuppressor.data.sendmail then
        local mail = Mail()
        mail.header = "Energy Signature Suppressor"%_T
        mail.sender = "Energy Signature Suppressor"%_T
        local dateTime = string.format("[%s]\n", os.date("%d.%m %H:%M:%S"))
        if faction.isPlayer then
            mail.text = Format(playerMsg, dateTime, '', x, y)
            Player(faction.index):addMail(mail)
        elseif faction.isAlliance then -- send message to every Alliance member that can manage ships
            mail.text = Format(allianceMsg, dateTime, '', x, y)
            local alliance = Alliance(faction.index)
            for index, _ in pairs({alliance:getMembers()}) do
                if alliance:hasPrivilege(index, AlliancePrivilege.ManageShips) then
                    Player(index):addMail(mail)
                end
            end
        end
    end
end

function EnergySuppressor.iES_onSendMailChecked(value)
    if not checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips) then return end

    EnergySuppressor.data.sendmail = value
    EnergySuppressor.sync()
end
callable(EnergySuppressor, "iES_onSendMailChecked")

function EnergySuppressor.iES_onDestroyed()
    EnergySuppressor.iES_notify([[%1%Your energy signature suppressor in sector %2%(%3%:%4%) was destroyed!]]%_T, [[%1%Your alliance energy signature suppressor in sector %2%(%3%:%4%) was destroyed!]]%_T)
end


end