include("faction")
include("stringutility")

local improvedEnergySuppressor_initialize, improvedEnergySuppressor_initUI, improvedEnergySuppressor_onSync, improvedEnergySuppressor_secure, improvedEnergySuppressor_restore -- extended functions
local improvedEnergySuppressor_sendMailCheckBox -- client UI
local improvedEnergySuppressor_translatedText -- server


if onClient() then -- CLIENT


improvedEnergySuppressor_initialize = EnergySuppressor.initialize
function EnergySuppressor.initialize(...)
    improvedEnergySuppressor_initialize(...)

    if checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips) then
        invokeServerFunction("improvedEnergySuppressor_setTranslatedMessage", "Energy Signature Suppressor"%_t,
          [[Your energy signature suppressor in sector \s(%s:%s) burnt out!]]%_t,
          [[Your alliance energy signature suppressor in sector \s(%s:%s) burnt out!]]%_t)
    end
end

function EnergySuppressor.interactionPossible(playerIndex, option) -- overridden
    return checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
end

improvedEnergySuppressor_initUI = EnergySuppressor.initUI
function EnergySuppressor.initUI()
    if improvedEnergySuppressor_initUI then improvedEnergySuppressor_initUI() end

    local res = getResolution()
    local size = vec2(450, 50)

    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    window.caption = "Settings"%_t
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "Settings"%_t)

    improvedEnergySuppressor_sendMailCheckBox = window:createCheckBox(Rect(10, 10, window.width - 10, 30), "Send a mail when suppressor will burn out"%_t, "improvedEnergySuppressor_onSendMailChecked")
    improvedEnergySuppressor_sendMailCheckBox.captionLeft = false
    improvedEnergySuppressor_sendMailCheckBox.fontSize = 13
    improvedEnergySuppressor_sendMailCheckBox:setCheckedNoCallback(EnergySuppressor.data.sendmail)
end

improvedEnergySuppressor_onSync = EnergySuppressor.onSync
function EnergySuppressor.onSync(...)
    improvedEnergySuppressor_onSync(...)

    if improvedEnergySuppressor_sendMailCheckBox then
        improvedEnergySuppressor_sendMailCheckBox:setCheckedNoCallback(EnergySuppressor.data.sendmail)
    end
end

function EnergySuppressor.improvedEnergySuppressor_onSendMailChecked(checkbox, value)
    invokeServerFunction("improvedEnergySuppressor_onSendMailChecked", nil, value)
end


else -- SERVER


function EnergySuppressor.updateServer(timeStep) -- overridden
    EnergySuppressor.data.time = EnergySuppressor.data.time - timeStep

    if EnergySuppressor.data.time <= 0 then
        local sector = Sector()
        local x, y = sector:getCoordinates()
        -- send message
        if not improvedEnergySuppressor_translatedText then
            improvedEnergySuppressor_translatedText = {
              header = "Energy Signature Suppressor"%_t,
              playerMsg = [[Your energy signature suppressor in sector \s(%s:%s) burnt out!]]%_t,
              allianceMsg = [[Your alliance energy signature suppressor in sector \s(%s:%s) burnt out!]]%_t
            }
        end
        local faction = getParentFaction()
        if faction.isAlliance then
            faction:sendChatMessage(improvedEnergySuppressor_translatedText.header, ChatMessageType.Warning, improvedEnergySuppressor_translatedText.allianceMsg, x, y)
        else
            faction:sendChatMessage(improvedEnergySuppressor_translatedText.header, ChatMessageType.Warning, improvedEnergySuppressor_translatedText.playerMsg, x, y)
        end
        -- send mail
        if EnergySuppressor.data.sendmail then
            local mail = Mail()
            mail.header = improvedEnergySuppressor_translatedText.header
            mail.sender = improvedEnergySuppressor_translatedText.header
            if faction.isPlayer then
                mail.text = string.format(string.gsub(improvedEnergySuppressor_translatedText.playerMsg, [[\s]], ''), x, y)
                Player(faction.index):addMail(mail)
            elseif faction.isAlliance then -- send message to every Alliance member that can manage ships
                mail.text = string.format(string.gsub(improvedEnergySuppressor_translatedText.allianceMsg, [[\s]], ''), x, y)
                local alliance = Alliance(faction.index)
                for index, _ in pairs({alliance:getMembers()}) do
                    if alliance:hasPrivilege(index, AlliancePrivilege.ManageShips) then
                        Player(index):addMail(mail)
                    end
                end
            end
        end
        -- Create Wreckage
        local entity = Entity()
        local position = entity.position
        local plan = entity:getMovePlan()
        -- remove energy suppressor
        sector:deleteEntity(entity)
        -- create a wreckage in its place
        sector:createWreckage(plan, position)
    end
end

improvedEnergySuppressor_secure = EnergySuppressor.secure
function EnergySuppressor.secure()
    local data = improvedEnergySuppressor_secure()

    data.translatedText = improvedEnergySuppressor_translatedText

    return data
end

improvedEnergySuppressor_restore = EnergySuppressor.restore
function EnergySuppressor.restore(data)
    improvedEnergySuppressor_translatedText = data.translatedText
    data.translatedText = nil -- no need to spam this to clients

    improvedEnergySuppressor_restore(data)
end

function EnergySuppressor.improvedEnergySuppressor_setTranslatedMessage(header, playerMsg, allianceMsg)
    if improvedEnergySuppressor_translatedText or not checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips) then return end

    improvedEnergySuppressor_translatedText = { header = header, playerMsg = playerMsg, allianceMsg = allianceMsg }
end
callable(EnergySuppressor, "improvedEnergySuppressor_setTranslatedMessage")

function EnergySuppressor.improvedEnergySuppressor_onSendMailChecked(checkbox, value)
    if not checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips) then
        return
    end

    EnergySuppressor.data.sendmail = value
    EnergySuppressor.sync()
end
callable(EnergySuppressor, "improvedEnergySuppressor_onSendMailChecked")


end