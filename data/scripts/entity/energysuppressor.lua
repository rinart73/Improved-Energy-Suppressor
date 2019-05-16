include("faction")
include("stringutility")

if onClient() then -- CLIENT


local sendMailCheckBox

local old_initialize = EnergySuppressor.initialize
function EnergySuppressor.initialize()
    if old_initialize then old_initialize() end

    if checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips) then
        invokeServerFunction("setTranslatedMessage", "Energy Signature Suppressor"%_t,
          [[Your energy signature suppressor in sector \s(%s:%s) burnt out!]]%_t,
          [[Your alliance energy signature suppressor in sector \s(%s:%s) burnt out!]]%_t)
    end
end

function EnergySuppressor.interactionPossible(playerIndex, option)
    return checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips)
end

local old_initUI = EnergySuppressor.initUI
function EnergySuppressor.initUI()
    if old_initUI then old_initUI() end

    local res = getResolution()
    local size = vec2(450, 50)

    local menu = ScriptUI()
    local window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    window.caption = "Settings"%_t
    window.showCloseButton = 1
    window.moveable = 1
    menu:registerWindow(window, "Settings"%_t)

    sendMailCheckBox = window:createCheckBox(Rect(10, 10, window.width - 10, 30), "Send a mail when suppressor will burn out"%_t, "onSendMailChecked")
    sendMailCheckBox.captionLeft = false
    sendMailCheckBox.fontSize = 13
    sendMailCheckBox:setCheckedNoCallback(EnergySuppressor.data.sendmail)
end

local old_onSync = EnergySuppressor.onSync
function EnergySuppressor.onSync()
    if old_onSync then old_onSync() end
    if sendMailCheckBox then
        sendMailCheckBox:setCheckedNoCallback(EnergySuppressor.data.sendmail)
    end
end

function EnergySuppressor.onSendMailChecked(checkbox, value)
    invokeServerFunction("onSendMailChecked", nil, value)
end


else -- SERVER


local translatedText

function EnergySuppressor.updateServer(timeStep)
    EnergySuppressor.data.time = EnergySuppressor.data.time - timeStep

    if EnergySuppressor.data.time <= 0 then
        local x, y = Sector():getCoordinates()
        -- send message
        if not translatedText then
            translatedText = {
              header = "Energy Signature Suppressor"%_t,
              playerMsg = [[Your energy signature suppressor in sector \s(%s:%s) burnt out!]]%_t,
              allianceMsg = [[Your alliance energy signature suppressor in sector \s(%s:%s) burnt out!]]%_t
            }
        end
        local faction = getParentFaction()
        if faction.isAlliance then
            faction:sendChatMessage(translatedText.header, ChatMessageType.Warning, translatedText.allianceMsg, x, y)
        else
            faction:sendChatMessage(translatedText.header, ChatMessageType.Warning, translatedText.playerMsg, x, y)
        end
        -- send mail
        if EnergySuppressor.data.sendmail then
            local mail = Mail()
            mail.header = translatedText.header
            mail.sender = translatedText.header
            if faction.isPlayer then
                mail.text = string.format(string.gsub(translatedText.playerMsg, [[\s]], ''), x, y)
                Player(faction.index):addMail(mail)
            elseif faction.isAlliance then -- send message to every Alliance member that can manage ships
                mail.text = string.format(string.gsub(translatedText.allianceMsg, [[\s]], ''), x, y)
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
        Sector():deleteEntity(entity)
        -- create a wreckage in its place
        Sector():createWreckage(plan, position)
    end
end

local old_secure = EnergySuppressor.secure
function EnergySuppressor.secure()
    local data = old_secure()
    data.translatedText = translatedText
    return data
end

local old_restore = EnergySuppressor.restore
function EnergySuppressor.restore(data)
    translatedText = data.translatedText
    data.translatedText = nil -- no need to spam this to clients
    old_restore(data)
end

function EnergySuppressor.setTranslatedMessage(header, playerMsg, allianceMsg)
    if not checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips) or translatedText then return end

    translatedText = { header = header, playerMsg = playerMsg, allianceMsg = allianceMsg }
end
callable(EnergySuppressor, "setTranslatedMessage")

function EnergySuppressor.onSendMailChecked(checkbox, value)
    if not checkEntityInteractionPermissions(Entity(), AlliancePrivilege.ManageShips) then
        return
    end

    EnergySuppressor.data.sendmail = value
    EnergySuppressor.sync()
end
callable(EnergySuppressor, "onSendMailChecked")


end