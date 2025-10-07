-- DoiteEdit.lua
-- Secondary frame for editing Aura conditions / edit UI
-- Attached to DoiteAuras main frame (DoiteAurasFrame)

if DoiteConditionsFrame then
    DoiteConditionsFrame:Hide()
    DoiteConditionsFrame = nil
end

local condFrame = nil
local currentKey = nil

-- Ensure DB entry exists for a key
local function EnsureDBEntry(key)
    if not DoiteAurasDB.spells[key] then
        DoiteAurasDB.spells[key] = {
            order = 999,
            type = "Ability",
            displayName = key,
            growth = "Horizontal Right",
            numAuras = 5,
            offsetX = 0,
            offsetY = 0,
            iconSize = 40
        }
    end
    local d = DoiteAurasDB.spells[key]
    if not d.growth then d.growth = "Horizontal Right" end
    if not d.numAuras then d.numAuras = 5 end
    if not d.offsetX then d.offsetX = 0 end
    if not d.offsetY then d.offsetY = 0 end
    if not d.iconSize then d.iconSize = 40 end
    return d
end

-- Build a map group -> leaderKey
local function BuildGroupLeaders()
    local leaders = {}
    for k, v in pairs(DoiteAurasDB.spells) do
        if v.group and v.isLeader then
            leaders[v.group] = k
        end
    end
    return leaders
end

-- Safe refresh hooks for main addon (if functions exist there)
local function SafeRefresh()
    if DoiteAuras_RefreshList then DoiteAuras_RefreshList() end
    if DoiteAuras_RefreshIcons then DoiteAuras_RefreshIcons() end
end

-- Internal: initialize group dropdown contents for current data
local function InitGroupDropdown(dd, data)
    -- Use UIDropDownMenu_Initialize with the expected signature
    UIDropDownMenu_Initialize(dd, function(frame, level, menuList)
        local info
        local choices = { "No" }
        for i = 1, 10 do table.insert(choices, "Group " .. tostring(i)) end

        for _, choice in ipairs(choices) do
            info = {}
            info.text = choice
            info.value = choice
            info.func = function()
                local picked = (this and this.value) or choice
                if not currentKey then return end
                local d = EnsureDBEntry(currentKey)

                if picked == "No" then
                    d.group = nil
                    d.isLeader = false
                else
                    local leaders = BuildGroupLeaders()
                    d.group = picked
                    if not leaders[picked] then
                        d.isLeader = true
                    else
                        if leaders[picked] ~= currentKey then
                            d.isLeader = false
                        end
                    end
                end

                UIDropDownMenu_SetSelectedValue(dd, picked)
                -- set visible text: (text, dropdown)
                UIDropDownMenu_SetText(picked, dd)
                CloseDropDownMenus()
                UpdateCondFrameForKey(currentKey)
                SafeRefresh()
            end

            if data and ((not data.group and choice == "No") or (data.group == choice)) then
                info.checked = true
            else
                info.checked = false
            end

            UIDropDownMenu_AddButton(info)
        end
    end)
end

-- Internal: initialize growth direction dropdown (leader-only control)
local function InitGrowthDropdown(dd, data)
    UIDropDownMenu_Initialize(dd, function(frame, level, menuList)
        local info
        local directions = { "Horizontal Right", "Horizontal Left", "Vertical Down", "Vertical Up" }
        for _, dir in ipairs(directions) do
            info = {}
            info.text = dir
            info.value = dir
            info.func = function()
                local picked = (this and this.value) or dir
                if not currentKey then return end
                local d = EnsureDBEntry(currentKey)
                d.growth = picked
                UIDropDownMenu_SetSelectedValue(dd, picked)
                UIDropDownMenu_SetText(picked, dd)
                CloseDropDownMenus()
                SafeRefresh()
            end
            info.checked = (data and data.growth == dir)
            UIDropDownMenu_AddButton(info)
        end
    end)
end

-- Internal: initialize numAuras dropdown (leader-only control)
local function InitNumAurasDropdown(dd, data)
    UIDropDownMenu_Initialize(dd, function(frame, level, menuList)
        local info
        for i = 1, 10 do
            info = {}
            info.text = tostring(i)
            info.value = i
            info.func = function()
                local picked = (this and this.value) or i
                if not currentKey then return end
                local d = EnsureDBEntry(currentKey)
                d.numAuras = picked
                UIDropDownMenu_SetSelectedValue(dd, picked)
                UIDropDownMenu_SetText(tostring(picked), dd)
                CloseDropDownMenus()
                SafeRefresh()
            end
            info.checked = (data and data.numAuras == i)
            UIDropDownMenu_AddButton(info)
        end
        -- Unlimited option
        info = {}
        info.text = "Unlimited"
        info.value = "Unlimited"
        info.func = function()
            if not currentKey then return end
            local d = EnsureDBEntry(currentKey)
            d.numAuras = "Unlimited"
            UIDropDownMenu_SetSelectedValue(dd, "Unlimited")
            UIDropDownMenu_SetText("Unlimited", dd)
            CloseDropDownMenus()
            SafeRefresh()
        end
        info.checked = (data and data.numAuras == "Unlimited")
        UIDropDownMenu_AddButton(info)
    end)
end

-- Update frame controls to reflect db for `key`
function UpdateCondFrameForKey(key)
    if not condFrame or not key then return end
    currentKey = key
    local data = EnsureDBEntry(key)

    -- Header: colored by type
    local typeColor = "|cffffffff"
    if data.type == "Ability" then typeColor = "|cff4da6ff"
    elseif data.type == "Buff" then typeColor = "|cff22ff22"
    elseif data.type == "Debuff" then typeColor = "|cffff4d4d" end
    condFrame.header:SetText("Edit: " .. (data.displayName or key) .. " " .. typeColor .. "(" .. (data.type or "") .. ")|r")

    -- Initialize group dropdown contents (pass current data to get 'checked' right)
    if condFrame.groupDD then
        InitGroupDropdown(condFrame.groupDD, data)
        local sel = data.group or "No"
        UIDropDownMenu_SetSelectedValue(condFrame.groupDD, sel)
        UIDropDownMenu_SetText(sel, condFrame.groupDD)
    end

    -- Leader checkbox logic & leader-only controls
    if condFrame.leaderCB then
        if not data.group then
            condFrame.leaderCB:Hide()
            if condFrame.growthDD then condFrame.growthDD:Hide() end
            if condFrame.numAurasLabel then condFrame.numAurasLabel:Hide() end
            if condFrame.numAurasDD then condFrame.numAurasDD:Hide() end
        else
            condFrame.leaderCB:Show()
            local leaders = BuildGroupLeaders()
            local leaderKey = leaders[data.group]
            if not leaderKey then
                data.isLeader = true
                condFrame.leaderCB:SetChecked(true)
                condFrame.leaderCB:Disable()
                if condFrame.growthDD then
                    condFrame.growthDD:Show()
                    InitGrowthDropdown(condFrame.growthDD, data)
                    UIDropDownMenu_SetSelectedValue(condFrame.growthDD, data.growth or "Horizontal Right")
                    UIDropDownMenu_SetText(data.growth or "Horizontal Right", condFrame.growthDD)
                end
                if condFrame.numAurasLabel and condFrame.numAurasDD then
                    condFrame.numAurasLabel:Show()
                    condFrame.numAurasDD:Show()
                    InitNumAurasDropdown(condFrame.numAurasDD, data)
                    UIDropDownMenu_SetSelectedValue(condFrame.numAurasDD, data.numAuras or 5)
                    UIDropDownMenu_SetText(tostring(data.numAuras or 5), condFrame.numAurasDD)
                end
            else
                if leaderKey == key then
                    condFrame.leaderCB:SetChecked(true)
                    condFrame.leaderCB:Disable()
                    if condFrame.growthDD then
                        condFrame.growthDD:Show()
                        InitGrowthDropdown(condFrame.growthDD, data)
                        UIDropDownMenu_SetSelectedValue(condFrame.growthDD, data.growth or "Horizontal Right")
                        UIDropDownMenu_SetText(data.growth or "Horizontal Right", condFrame.growthDD)
                    end
                    if condFrame.numAurasLabel and condFrame.numAurasDD then
                        condFrame.numAurasLabel:Show()
                        condFrame.numAurasDD:Show()
                        InitNumAurasDropdown(condFrame.numAurasDD, data)
                        UIDropDownMenu_SetSelectedValue(condFrame.numAurasDD, data.numAuras or 5)
                        UIDropDownMenu_SetText(tostring(data.numAuras or 5), condFrame.numAurasDD)
                    end
                else
                    condFrame.leaderCB:SetChecked(false)
                    condFrame.leaderCB:Enable()
                    if condFrame.growthDD then condFrame.growthDD:Hide() end
                    if condFrame.numAurasLabel then condFrame.numAurasLabel:Hide() end
                    if condFrame.numAurasDD then condFrame.numAurasDD:Hide() end
                end
            end
        end
    end

    -- Show/hide Position & Size section (only when no group OR leader)
    if (not data.group) or data.isLeader then
        if condFrame.groupTitle3 then condFrame.groupTitle3:Show() end
        if condFrame.sep3 then condFrame.sep3:Show() end
        if condFrame.sliderX then condFrame.sliderX:Show() end
        if condFrame.sliderY then condFrame.sliderY:Show() end
        if condFrame.sliderSize then condFrame.sliderSize:Show() end
        if condFrame.sliderXBox then condFrame.sliderXBox:Show() end
        if condFrame.sliderYBox then condFrame.sliderYBox:Show() end
        if condFrame.sliderSizeBox then condFrame.sliderSizeBox:Show() end

        -- update slider positions/values (guarded)
        if condFrame.sliderX then condFrame.sliderX:SetValue(data.offsetX or 0) end
        if condFrame.sliderY then condFrame.sliderY:SetValue(data.offsetY or 0) end
        if condFrame.sliderSize then condFrame.sliderSize:SetValue(data.iconSize or 40) end

        -- update numeric editboxes if present
        if condFrame.sliderXBox then condFrame.sliderXBox:SetText(tostring(math.floor((data.offsetX or 0) + 0.5))) end
        if condFrame.sliderYBox then condFrame.sliderYBox:SetText(tostring(math.floor((data.offsetY or 0) + 0.5))) end
        if condFrame.sliderSizeBox then condFrame.sliderSizeBox:SetText(tostring(math.floor((data.iconSize or 40) + 0.5))) end
    else
        if condFrame.groupTitle3 then condFrame.groupTitle3:Hide() end
        if condFrame.sep3 then condFrame.sep3:Hide() end
        if condFrame.sliderX then condFrame.sliderX:Hide() end
        if condFrame.sliderY then condFrame.sliderY:Hide() end
        if condFrame.sliderSize then condFrame.sliderSize:Hide() end
        if condFrame.sliderXBox then condFrame.sliderXBox:Hide() end
        if condFrame.sliderYBox then condFrame.sliderYBox:Hide() end
        if condFrame.sliderSizeBox then condFrame.sliderSizeBox:Hide() end
    end
end

-- Public show/hide entry point
function DoiteConditions_Show(key)
    -- toggle: if same key and shown -> hide
    if condFrame and condFrame:IsShown() and currentKey == key then
        condFrame:Hide()
        currentKey = nil
        return
    end

    -- create the frame if needed
    if not condFrame then
        condFrame = CreateFrame("Frame", "DoiteConditionsFrame", UIParent)
        condFrame:SetWidth(355)
        condFrame:SetHeight(360)
        if DoiteAurasFrame and DoiteAurasFrame:GetName() then
            condFrame:SetPoint("TOPLEFT", DoiteAurasFrame, "TOPRIGHT", 5, 0)
        else
            condFrame:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
        end

        condFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 16, edgeSize = 32,
            insets = { left=11, right=12, top=12, bottom=11 }
        })
        condFrame:SetBackdropColor(0,0,0,1)
        condFrame:SetBackdropBorderColor(1,1,1,1)
        condFrame:SetFrameStrata("FULLSCREEN_DIALOG")

        condFrame.header = condFrame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        condFrame.header:SetPoint("TOP", condFrame, "TOP", 0, -15)
        condFrame.header:SetText("Edit:")

        condFrame.groupTitle = condFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        condFrame.groupTitle:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -40)
        condFrame.groupTitle:SetText("|cff33ff99GROUP & LEADER|r")

        local sep = condFrame:CreateTexture(nil, "ARTWORK")
        sep:SetHeight(1)
        sep:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 16, -55)
        sep:SetPoint("TOPRIGHT", condFrame, "TOPRIGHT", -16, -55)
        sep:SetTexture(1,1,1)
        if sep.SetVertexColor then sep:SetVertexColor(1,1,1,0.25) end

        condFrame.groupLabel = condFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        condFrame.groupLabel:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -68)
        condFrame.groupLabel:SetText("Group this Aura?")

        condFrame.groupDD = CreateFrame("Frame", "DoiteConditions_GroupDD", condFrame, "UIDropDownMenuTemplate")
        condFrame.groupDD:SetPoint("LEFT", condFrame.groupLabel, "RIGHT", -10, -2)
        if UIDropDownMenu_SetWidth then
            pcall(UIDropDownMenu_SetWidth, 75, condFrame.groupDD)
        end

        condFrame.leaderCB = CreateFrame("CheckButton", nil, condFrame, "UICheckButtonTemplate")
        condFrame.leaderCB:SetWidth(20); condFrame.leaderCB:SetHeight(20)
        condFrame.leaderCB:SetPoint("Left", condFrame.groupDD, "Right", -10, 0)
        condFrame.leaderCB.text = condFrame.leaderCB:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        condFrame.leaderCB.text:SetPoint("LEFT", condFrame.leaderCB, "RIGHT", 2, 0)
        condFrame.leaderCB.text:SetText("Aura group leader")
        condFrame.leaderCB:Hide()

        condFrame.growthDD = CreateFrame("Frame", "DoiteConditions_GrowthDD", condFrame, "UIDropDownMenuTemplate")
        condFrame.growthDD:SetPoint("BOTTOMLEFT", condFrame.groupLabel, "BOTTOMLEFT", -18, -43)
        if UIDropDownMenu_SetWidth then
            pcall(UIDropDownMenu_SetWidth, 110, condFrame.growthDD)
        end
        condFrame.growthDD:Hide()

        -- NEW: Number of Auras label + dropdown
        condFrame.numAurasLabel = condFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        condFrame.numAurasLabel:SetPoint("LEFT", condFrame.growthDD, "RIGHT", -5, 2)
        condFrame.numAurasLabel:SetText("Number of Auras")
        condFrame.numAurasLabel:Hide()

        condFrame.numAurasDD = CreateFrame("Frame", "DoiteConditions_NumAurasDD", condFrame, "UIDropDownMenuTemplate")
        condFrame.numAurasDD:SetPoint("LEFT", condFrame.numAurasLabel, "RIGHT", -10, -2)
        if UIDropDownMenu_SetWidth then
            pcall(UIDropDownMenu_SetWidth, 75, condFrame.numAurasDD)
        end
        condFrame.numAurasDD:Hide()

        -- leaderCB click behavior
        condFrame.leaderCB:SetScript("OnClick", function(self)
            local cb = self or (condFrame and condFrame.leaderCB)
            if not currentKey then
                if cb then cb:SetChecked(false) end
                return
            end
            local data = DoiteAurasDB.spells[currentKey]
            if not data or not data.group then
                if cb then
                    cb:SetChecked(false)
                    cb:Hide()
                end
                return
            end

            if cb and cb:GetChecked() then
                local leaders = BuildGroupLeaders()
                local prev = leaders[data.group]
                if prev and prev ~= currentKey and DoiteAurasDB.spells[prev] then
                    DoiteAurasDB.spells[prev].isLeader = false
                end
                data.isLeader = true
                cb:SetChecked(true)
                cb:Disable()

                if condFrame.growthDD then
                    condFrame.growthDD:Show()
                    InitGrowthDropdown(condFrame.growthDD, data)
                    UIDropDownMenu_SetSelectedValue(condFrame.growthDD, data.growth or "Horizontal Right")
                    UIDropDownMenu_SetText(data.growth or "Horizontal Right", condFrame.growthDD)
                end
                if condFrame.numAurasLabel and condFrame.numAurasDD then
                    condFrame.numAurasLabel:Show()
                    condFrame.numAurasDD:Show()
                    InitNumAurasDropdown(condFrame.numAurasDD, data)
                    UIDropDownMenu_SetSelectedValue(condFrame.numAurasDD, data.numAuras or 5)
                    UIDropDownMenu_SetText(tostring(data.numAuras or 5), condFrame.numAurasDD)
                end
            end

            SafeRefresh()
            UpdateCondFrameForKey(currentKey)
        end)

        condFrame.groupTitle2 = condFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        condFrame.groupTitle2:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -125)
        condFrame.groupTitle2:SetText("|cff33ff99CONDITIONS & RULES|r")

        local sep2 = condFrame:CreateTexture(nil, "ARTWORK")
        sep2:SetHeight(1)
        sep2:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 16, -140)
        sep2:SetPoint("TOPRIGHT", condFrame, "TOPRIGHT", -16, -140)
        sep2:SetTexture(1,1,1)
        if sep2.SetVertexColor then sep2:SetVertexColor(1,1,1,0.25) end

        condFrame.groupTitle3 = condFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        condFrame.groupTitle3:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 20, -270)
        condFrame.groupTitle3:SetText("|cff33ff99POSITION & SIZE|r")

        condFrame.sep3 = condFrame:CreateTexture(nil, "ARTWORK")
        condFrame.sep3:SetHeight(1)
        condFrame.sep3:SetPoint("TOPLEFT", condFrame, "TOPLEFT", 16, -285)
        condFrame.sep3:SetPoint("TOPRIGHT", condFrame, "TOPRIGHT", -16, -285)
        condFrame.sep3:SetTexture(1,1,1)
        if condFrame.sep3.SetVertexColor then condFrame.sep3:SetVertexColor(1,1,1,0.25) end

        -- Sliders helper (makes a slider + small EditBox beneath it)
        local function MakeSlider(name, text, x, y, width, minVal, maxVal, step)
            local s = CreateFrame("Slider", name, condFrame, "OptionsSliderTemplate")
            s:SetWidth(width)
            s:SetHeight(16)
            s:SetMinMaxValues(minVal, maxVal)
            s:SetValueStep(step)
            s:SetPoint("TOPLEFT", condFrame, "TOPLEFT", x, y)

            local txt = _G[s:GetName() .. 'Text']
            local low = _G[s:GetName() .. 'Low']
            local high = _G[s:GetName() .. 'High']
            if txt then txt:SetText(text); txt:SetFontObject("GameFontNormalSmall") end
            if low then low:SetText(tostring(minVal)); low:SetFontObject("GameFontNormalSmall") end
            if high then high:SetText(tostring(maxVal)); high:SetFontObject("GameFontNormalSmall") end

            -- tiny EditBox below slider
            local eb = CreateFrame("EditBox", name .. "_EditBox", condFrame, "InputBoxTemplate")
            eb:SetWidth(30); eb:SetHeight(18)
            eb:SetPoint("TOP", s, "BOTTOM", 3, -2)
            eb:SetAutoFocus(false)
            eb:SetText("0")
			eb:SetJustifyH("CENTER")
            eb:SetFontObject("GameFontNormalSmall")
            eb.slider = s
            eb._updating = false

            -- slider -> editbox (robust, avoids recursion)
            s:SetScript("OnValueChanged", function(self, value)
                local frame = self or s
                local v = tonumber(value)
                if not v and frame and frame.GetValue then
                    v = frame:GetValue()
                end
                if not v then return end
                v = math.floor(v + 0.5)
                if eb and eb.SetText and not eb._updating then
                    eb._updating = true
                    eb:SetText(tostring(v))
                    eb._updating = false
                end
                if frame and frame.updateFunc then frame.updateFunc(v) end
            end)

            -- editbox commit helper (clamp + set slider)
            local function CommitEditBox(box)
                if not box or not box.slider then return end
                local sref = box.slider
                local txt = box:GetText()
                local val = tonumber(txt)
                if not val then
                    -- revert to slider's current rounded value
                    local cur = math.floor((sref:GetValue() or 0) + 0.5)
                    box:SetText(tostring(cur))
                else
                    if val < minVal then val = minVal end
                    if val > maxVal then val = maxVal end
                    -- set value on slider; OnValueChanged will handle DB update via updateFunc
                    box._updating = true
                    sref:SetValue(val)
                    box._updating = false
                end
            end

            -- editbox -> slider while typing (userInput true) and on finalize (enter/lost focus)
            eb:SetScript("OnTextChanged", function(self, userInput)
                if not userInput then return end          -- ignore programmatic changes
                if self._updating then return end         -- avoid recursion
                local txt = self:GetText()
                local num = tonumber(txt)
                if num then
                    if num < minVal then num = minVal end
                    if num > maxVal then num = maxVal end
                    self._updating = true
                    self.slider:SetValue(num)            -- will trigger slider OnValueChanged -> updateFunc
                    self._updating = false
                end
            end)

            eb:SetScript("OnEnterPressed", function(self)
                CommitEditBox(self)
                if self and self.ClearFocus then self:ClearFocus() end
            end)

            eb:SetScript("OnEditFocusLost", function(self)
                CommitEditBox(self)
            end)

            return s, eb
        end

        -- calculate slider widths as 1/3 of available area (leave left margin + spacing)
        local totalAvailable = condFrame:GetWidth() - 60 -- left/right padding
        local sliderWidth = math.floor((totalAvailable - 20) / 3) -- 10px gaps between sliders
        if sliderWidth < 100 then sliderWidth = 100 end -- sensible minimum

        local baseX = 20
        local baseY = -305 -- row y for sliders (tweak as needed)
        local gap = 8

        condFrame.sliderX, condFrame.sliderXBox = MakeSlider("DoiteConditions_SliderX", "Horizontal Position", baseX, baseY, sliderWidth, -500, 500, 1)
        condFrame.sliderY, condFrame.sliderYBox = MakeSlider("DoiteConditions_SliderY", "Vertical Position", baseX + sliderWidth + gap, baseY, sliderWidth, -500, 500, 1)
        condFrame.sliderSize, condFrame.sliderSizeBox = MakeSlider("DoiteConditions_SliderSize", "Icon Size", baseX + 2*(sliderWidth + gap), baseY, sliderWidth, 10, 100, 1)

        -- update functions that the slider will call when changed
        condFrame.sliderX.updateFunc = function(value)
            if not currentKey then return end
            local d = EnsureDBEntry(currentKey)
            d.offsetX = value
            SafeRefresh()
        end
        condFrame.sliderY.updateFunc = function(value)
            if not currentKey then return end
            local d = EnsureDBEntry(currentKey)
            d.offsetY = value
            SafeRefresh()
        end
        condFrame.sliderSize.updateFunc = function(value)
            if not currentKey then return end
            local d = EnsureDBEntry(currentKey)
            d.iconSize = value
            SafeRefresh()
        end

        -- Initially hidden position section
        if condFrame.groupTitle3 then condFrame.groupTitle3:Hide() end
        if condFrame.sep3 then condFrame.sep3:Hide() end
        if condFrame.sliderX then condFrame.sliderX:Hide() end
        if condFrame.sliderY then condFrame.sliderY:Hide() end
        if condFrame.sliderSize then condFrame.sliderSize:Hide() end
        if condFrame.sliderXBox then condFrame.sliderXBox:Hide() end
        if condFrame.sliderYBox then condFrame.sliderYBox:Hide() end
        if condFrame.sliderSizeBox then condFrame.sliderSizeBox:Hide() end

        -- When the main DoiteAuras frame hides, hide the cond frame too
        if DoiteAurasFrame then
            local oldHide = DoiteAurasFrame:GetScript("OnHide")
            DoiteAurasFrame:SetScript("OnHide", function(self)
                if condFrame then condFrame:Hide() end
                if oldHide then oldHide(self) end
            end)
        end
    end

    condFrame:Show()
    UpdateCondFrameForKey(key)
end
