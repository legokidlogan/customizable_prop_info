CustomPropInfo = CustomPropInfo or {}
CustomPropInfo.Entries = CustomPropInfo.Entries or {}
CustomPropInfo.EntryLookup = CustomPropInfo.EntryLookup or {}
CustomPropInfo.Colors = CustomPropInfo.Colors or {}
CustomPropInfo.ClientConVars = CustomPropInfo.ClientConVars or {}
CustomPropInfo.ClientConVarsEntries = CustomPropInfo.ClientConVarsEntries or {}

local clConVars = CustomPropInfo.ClientConVars
local clConVarsEntries = CustomPropInfo.ClientConVarsEntries

local CVAR_BASE = "custom_propinfo_"
local TEXT_COLOR = Color( 0, 0, 0, 255 )
local TEXT_COLOR_UNUSABLE = Color( 128, 128, 128, 255 )
local DIVIDER_COLOR = Color( 128, 128, 128, 255 )

local commandPrefix = GetConVar( CVAR_BASE .. "command_prefix" )
local infoPanelCmd


local function setInfoPanelCmdText()
    if not IsValid( infoPanelCmd ) then return end

    infoPanelCmd:SetText(
        "CPI has chat commands for extra info and copying text directly.\n" ..
        "You can set the command prefix for yourself if the default\n" ..
        "  conflicts with pre-existing commands.\n\n" ..
        "'" .. commandPrefix .. " help' will show all commands.\n" ..
        "Many commands have shorter aliases, such as\n" ..
        "  'dir' = 'directions' and 'mat' = 'material'"
    )
end


if commandPrefix then
    commandPrefix = commandPrefix:GetString()

    cvars.AddChangeCallback( CVAR_BASE .. "command_prefix", function( _, _, new )
        commandPrefix = new
        setInfoPanelCmdText()
    end )
else
    timer.Simple( 10, function()
        cvars.AddChangeCallback( CVAR_BASE .. "command_prefix", function( _, _, new )
            commandPrefix = new
            setInfoPanelCmdText()
        end )
    end )

    commandPrefix = "/pi"
end


local function updateUsabilityColor( panel, state )
    if not panel then return end

    local skin = panel:GetSkin() or SKIN or {}
    local newCol = state and ( skin.colTextEntryText or TEXT_COLOR ) or skin.colTextEntryTextPlaceholder or TEXT_COLOR_UNUSABLE

    panel:SetTextColor( newCol )
end

function CustomPropInfo.GenerateCollapsibleEntryData()
    local data = {}
    local count = 0

    for _, entry in ipairs( CustomPropInfo.Entries ) do
        local alphaName = entry.AlphaName
        local settings = entry.Settings or {}

        if not settings.NoShow then
            local extraText = settings.OptionText

            if type( extraText ) == "function" then
                extraText = extraText()
            end

            extraText = extraText and ( "  (" .. extraText .. ")" ) or ""

            count = count + 1

            data[count] = {
                Text = "Enable " .. alphaName .. extraText,
                Toggle = true,
                BlockToggle = ( entry.Settings or {} ).BlockToggle,
                ConVar = CVAR_BASE .. "entrytoggle_" .. string.lower( alphaName ),
            }
        end
    end

    return data
end

function CustomPropInfo.CreateCollapsibleSliders( panel, collapseText, settings )
    local collapse = vgui.Create( "DCollapsibleCategory", panel )
    local list = vgui.Create( "DPanelList", collapse )
    local bottomLine = vgui.Create( "DFrame", list )
    local skin = panel:GetSkin() or SKIN or {}
    local lineColor = skin.bg_color_bright or DIVIDER_COLOR
    local lineHeight = 1
    local lineMargin = 8

    collapse:SetLabel( collapseText )
    collapse:SetExpanded( false )

    list:SetSpacing( 5 )
    list:EnableHorizontal( false )
    list:EnableVerticalScrollbar( true )
    collapse:SetContents( list )

    for _, setting in ipairs( settings ) do
        local optionPanel

        if setting.Toggle then
            optionPanel = vgui.Create( "DCheckBoxLabel" )

            updateUsabilityColor( optionPanel, not setting.BlockToggle )
        else
            optionPanel = vgui.Create( "DNumSlider" )

            optionPanel:SetMin( setting.Min )
            optionPanel:SetMax( setting.Max )
            optionPanel:SetDecimals( setting.Decimals )
            optionPanel:GetChildren()[3]:SetTextColor( skin.colTextEntryText or TEXT_COLOR )
        end

        optionPanel:SetText( setting.Text )
        optionPanel:SetConVar( setting.ConVar )
        optionPanel:SizeToContents()

        list:AddItem( optionPanel )
    end

    local listW = list:GetSize()

    bottomLine:SetSize( listW, lineHeight )
    list:AddItem( bottomLine )
    bottomLine.Paint = function( _, w, h )
        draw.RoundedBox( 1, lineMargin / 2, 0, w - lineMargin, h, lineColor )
    end

    return collapse
end

local generateCollapsibleEntryData = CustomPropInfo.GenerateCollapsibleEntryData
local createCollapsibleSliders = CustomPropInfo.CreateCollapsibleSliders

hook.Add( "AddToolMenuCategories", "CustomPropInfo_AddToolMenuCategories", function()
    spawnmenu.AddToolCategory( "Options", "CustomTools", "#CustomTools" )
end )

hook.Add( "PopulateToolMenu", "CustomPropInfo_PopulateToolMenu", function()
    spawnmenu.AddToolMenuOption( "Options", "CustomTools", "custom_propinfo", "#Prop Info", "", "", function( panel )
        pcall( function() -- ControlPresets only exists in certain gamemodes
            local presetControl = vgui.Create( "ControlPresets", panel )
            local defaults = {}

            for cvName, cv in pairs( clConVars ) do
                presetControl:AddConVar( cvName )
                defaults[cvName] = cv:GetDefault()
            end

            defaults[CVAR_BASE .. "enabled"] = 1

            for _, cv in pairs( clConVarsEntries ) do
                local cvName = cv:GetName()

                presetControl:AddConVar( cvName )
                defaults[cvName] = cv:GetDefault()
            end

            presets.Add( "custom_propinfo", "Default", defaults )
            presetControl:SetPreset( "custom_propinfo" )

            panel:AddItem( presetControl )
        end )

        local serverExists = util.NetworkStringToID( "CustomPropInfo_RequestInfo" ) ~= 0

        panel:CheckBox( "Enable prop info", CVAR_BASE .. "enabled" )
        panel:CheckBox( "Enable directional arrows", CVAR_BASE .. "directions" )
        panel:CheckBox( "Set dir. mode (right vs y-axis)", CVAR_BASE .. "directions_mode" )
        panel:CheckBox( "Enable text outline for improved readability", CVAR_BASE .. "outline" )
        panel:CheckBox( "Only display if holding physgun or toolgun", CVAR_BASE .. "tool_only" )
        panel:CheckBox( "Hide if in a seat", CVAR_BASE .. "hide_seat" )

        local infoPanelDir = vgui.Create( "DLabel" )

        updateUsabilityColor( infoPanelDir, true )
        infoPanelDir:SetText(
            "Directional arrows display forward, right, and up directions.\n" ..
            "If dir. mode is on, green shows y-axis instead of right,\n" ..
            "  useful for local coordinates."
        )

        local _, infoY = infoPanelDir:GetTextSize()

        infoPanelDir:SetHeight( infoY + 5 )
        panel:AddItem( infoPanelDir )

        panel:NumSlider( "Dec. point rounding", CVAR_BASE .. "round", 0, 10, 0 )
        panel:NumSlider( "Time between updates", CVAR_BASE .. "update_interval", 0, 3, 2 )

        local prefixPanel = panel:TextEntry( "Command prefix", CVAR_BASE .. "command_prefix" )
        updateUsabilityColor( prefixPanel, serverExists )


        infoPanelCmd = vgui.Create( "DLabel" )

        updateUsabilityColor( infoPanelCmd, serverExists )
        setInfoPanelCmdText()

        _, infoY = infoPanelCmd:GetTextSize()

        infoPanelCmd:SetHeight( infoY + 5 )
        panel:AddItem( infoPanelCmd )


        panel:AddItem( createCollapsibleSliders( panel, "Display Settings", {
            {
                Text = "Dir. arrow length",
                Min = 0,
                Max = 100,
                Decimals = 0,
                ConVar = CVAR_BASE .. "directions_length",
            },
            {
                Text = "Dir. arrow end length",
                Min = 0,
                Max = 50,
                Decimals = 0,
                ConVar = CVAR_BASE .. "directions_length_end",
            },
            {
                Text = "Background value",
                Min = 0,
                Max = 255,
                Decimals = 0,
                ConVar = CVAR_BASE .. "background_value",
            },
            {
                Text = "Background alpha",
                Min = 0,
                Max = 255,
                Decimals = 0,
                ConVar = CVAR_BASE .. "background_alpha",
            },
            {
                Text = "Text alpha",
                Min = 0,
                Max = 255,
                Decimals = 0,
                ConVar = CVAR_BASE .. "text_alpha",
            },
            {
                Text = "X-pos",
                Min = 0,
                Max = 1,
                Decimals = 2,
                ConVar = CVAR_BASE .. "pos_x",
            },
            {
                Text = "Y-pos",
                Min = 0,
                Max = 1,
                Decimals = 2,
                ConVar = CVAR_BASE .. "pos_y",
            },
            {
                Text = "Font size",
                Min = 8,
                Max = 50,
                Decimals = 0,
                ConVar = CVAR_BASE .. "font_size",
            },
            {
                Text = "Min width",
                Min = 0,
                Max = 200,
                Decimals = 0,
                ConVar = CVAR_BASE .. "min_width",
            },
        } ) )


        panel:AddItem( createCollapsibleSliders( panel, "Additional Entry Settings", {
            {
                Text = "Frozen Flag: only show when frozen",
                Toggle = true,
                ConVar = CVAR_BASE .. "flag_frozen",
            },
            {
                Text = "Collisions Flag: only show when collisionless",
                Toggle = true,
                ConVar = CVAR_BASE .. "flag_collisions",
            }
        } ) )


        local togglesPanel = createCollapsibleSliders( panel, "Entry Toggles", generateCollapsibleEntryData() )

        CustomPropInfo.TogglesPanel = togglesPanel
        CustomPropInfo.SettingsPanel = panel

        panel:AddItem( togglesPanel )
    end )
end )
