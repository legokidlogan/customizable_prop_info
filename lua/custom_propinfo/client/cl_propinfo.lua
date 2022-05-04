CustomPropInfo = CustomPropInfo or {}
CustomPropInfo.Entries = CustomPropInfo.Entries or {}
CustomPropInfo.Colors = CustomPropInfo.Colors or {}
CustomPropInfo.DisplayData = CustomPropInfo.DisplayData or {}
CustomPropInfo.Commands = CustomPropInfo.Commands or {}
CustomPropInfo.ClientConVars = CustomPropInfo.ClientConVars or {}
CustomPropInfo.ClientConVarsEntries = CustomPropInfo.ClientConVarsEntries or {}
CustomPropInfo.CPPIBuddies = CustomPropInfo.CPPIBuddies or {}
CustomPropInfo.ServerExists = false


local infoEntries = CustomPropInfo.Entries
local infoColors = CustomPropInfo.Colors
local infoDisplayData = CustomPropInfo.DisplayData
local infoCommands = CustomPropInfo.Commands
local infoBuddies = CustomPropInfo.CPPIBuddies
local clConVars = CustomPropInfo.ClientConVars
local convarFlags = { FCVAR_ARCHIVE, FCVAR_REPLICATED }

local COMMAND_PREFIX_MAX_LENGTH = 20
local CVAR_BASE = "custom_propinfo_"
local FONT_NAME = "CustomPropInfo_DisplayFont"
local DEFAULT_TEXT = "???"
local DEFAULT_TEXT_GAP = DEFAULT_TEXT .. " "
local DEFAULT_COLOR = Color( 255, 255, 255, 255 )
local DEFAULT_FUNC = function()
    return {
        Count = 1,
        Strings = { DEFAULT_TEXT },
        Colors = { DEFAULT_COLOR },
    }
end

local function createClientConVarCPI( name, default, save, userinfo, text, min, max )
    name = CVAR_BASE .. name

    local convar = CreateClientConVar( name, default, save, userinfo, text, min, max )
    clConVars[name] = convar

    return convar
end

local function checkServerPresence()
    CustomPropInfo.ServerExists = util.NetworkStringToID( "CustomPropInfo_RequestInfo" ) ~= 0
end

checkServerPresence()

local REQUEST_COOLDOWN = CreateConVar( CVAR_BASE .. "request_cooldown_default", 0.3, convarFlags, "Sets the default serverside cooldown for CPI info requests.", 0, 5 ) -- Replicated for visibility
local WELCOME_ENABLED = CreateConVar( CVAR_BASE .. "welcome_message_enabled", 1, convarFlags, "Whether or not new users will receive a welcome message on their first-ever join.", 0, 1 )
local ENABLED_DEFAULT = CreateConVar( CVAR_BASE .. "enabled_default", 1, convarFlags, "Whether or not new users who've never used this addon before should have CPI enabled by default.", 0, 1 )

local CPI_FIRST_USE = CreateClientConVar( CVAR_BASE .. "first_use", 1, true, false, "Whether or not to print welcome text. Disables itself automatically.", 0, 1 )

local CPI_ENABLED = createClientConVarCPI( "enabled", 1, true, false, "Enables CustomPropInfo.", 0, 1 )
local CPI_DIR_ENABLED = createClientConVarCPI( "directions", 0, true, false, "Enables directional arrows for entities. Red for forward, green for right, blue for up.", 0, 1 )
local CPI_DIR_MODE = createClientConVarCPI( "directions_mode", 0, true, false, "Changes display mode for the green line of directional arrows. 0 = 'right' direction, 1 = y-axis direction for local coordinates.", 0, 1 )
local CPI_TOOL_ONLY = createClientConVarCPI( "tool_only", 1, true, false, "Makes CPI only display while you are actively holding the physgun or toolgun.", 0, 1 )
local CPI_HIDE_SEAT = createClientConVarCPI( "hide_seat", 1, true, false, "Hide CPI while sitting in a seat.", 0, 1 )
local CPI_ROUND = createClientConVarCPI( "round", 3, true, false, "How many decimal points to round numbers to.", 0, 10 )
local CPI_INTERVAL = createClientConVarCPI( "update_interval", 0.5, true, false, "The time, in seconds, between each update for CPI.", 0.05, 3 )
local CPI_OUTLINE = createClientConVarCPI( "outline", 0, true, false, "Enables an outline for text readability.", 0, 1 )
local CPI_DIR_LENGTH = createClientConVarCPI( "directions_length", 10, true, false, "The length of CPI directional arrows.", 0, 100 )
local CPI_DIR_LENGTH_END = createClientConVarCPI( "directions_length_end", 3, true, false, "The back-facing length of CPI directional arrows.", 0, 50 )
local CPI_BACKGROUND_VALUE = createClientConVarCPI( "background_value", 40, true, false, "The brightness of the CPI display background.", 0, 255 )
local CPI_BACKGROUND_ALPHA = createClientConVarCPI( "background_alpha", 80, true, false, "The opacity of the CPI display background.", 0, 255 )
local CPI_TEXT_ALPHA = createClientConVarCPI( "text_alpha", 255, true, false, "The opacity of the CPI display text.", 0, 255 )
local CPI_POS_X = createClientConVarCPI( "pos_x", 0, true, false, "X position of the leftmost corner of the CPI display, as a fraction of the screen. 0 is the left, 1 is the right.", 0, 1 )
local CPI_POS_Y = createClientConVarCPI( "pos_y", 0.51, true, false, "Y position of the leftmost corner of the CPI display, as a fraction of the screen. 0 is the top, 1 is the bottom.", 0, 1 )
local CPI_FONT_SIZE = createClientConVarCPI( "font_size", 21, true, false, "Font size for the CPI display, in pixels. Determines overall display size.", 8, 50 )
local CPI_MIN_WIDTH = createClientConVarCPI( "min_width", 20, true, false, "Minimum width of the CPI display background, scaled by the font size.", 0, 200 )
local CPI_PREFIX = createClientConVarCPI( "command_prefix", "/pi", true, false, "The command prefix used for CPI chat commands. Cannot include whitespace characters. Max character length is " .. COMMAND_PREFIX_MAX_LENGTH .. "." )
local CPI_FLAG_FROZEN = createClientConVarCPI( "flag_frozen", 0, true, false, "Makes frozen status into a flag, only showing when an object is frozen.", 0, 1 )
local CPI_FLAG_COLLISIONS = createClientConVarCPI( "flag_collisions", 0, true, false, "Makes collision status into a flag, only showing when an object has collisions disabled.", 0, 1 )

local cpiEntity = false
local cpiEnabled = CPI_ENABLED:GetBool()
local cpiDirEnabled = CPI_DIR_ENABLED:GetBool()
local cpiDirMode = CPI_DIR_MODE:GetBool()
local cpiToolOnly = CPI_TOOL_ONLY:GetBool()
local cpiHideSeat = CPI_HIDE_SEAT:GetBool()
local cpiInterval = CPI_INTERVAL:GetFloat()
local displayOutline = CPI_OUTLINE:GetBool()
local cpiDirLength = CPI_DIR_LENGTH:GetFloat()
local cpiDirLengthEnd = CPI_DIR_LENGTH_END:GetFloat()
local displayBackgroundValue
local displayBackgroundAlpha
local displayTextAlpha
local displayPosX = CPI_POS_X:GetFloat() * ScrW()
local displayPosY = CPI_POS_Y:GetFloat() * ScrH()
local displayFontSize = CPI_FONT_SIZE:GetInt()
local displayMinWidth = displayFontSize * CPI_MIN_WIDTH:GetInt()
local commandPrefix = string.sub( string.match( CPI_PREFIX:GetString(), "^[%S]+" ) or "/pi", 1, COMMAND_PREFIX_MAX_LENGTH )

local FONT_DATA = {
    font = "Roboto Mono",
    extended = false,
    size = CPI_FONT_SIZE:GetInt(),
    weight = 400,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = false,
    additive = false,
    outline = false,
}

do
    -- I would generalize this so players can set their own font, but CreateFont looks for font names, not font file names
    --   and GMod doesn't have any tools for finding valid fonts, meaning I'd have to file.Read a ton of stuff which is absurd
    if not file.Exists( "resource/fonts/RobotoMono.ttf", "MOD" ) then
        local files = file.Find( "resource/fonts/*", "THIRDPARTY" )
        local robotoExists = false

        for _, v in ipairs( files ) do
            if v == "RobotoMono.ttf" then
                robotoExists = true

                break
            end
        end

        if not robotoExists then
            FONT_DATA.font = "Verdana" -- Sadly the only default monospace font is Courier New, which doesn't look good for CPI
        end
    end

    surface.CreateFont( FONT_NAME, FONT_DATA )
end


local mathClamp = math.Clamp
local mathMax = math.max

local stringSub = string.sub

function CustomPropInfo.MakeOpaque( color )
    return Color( color.r, color.g, color.b, 255 )
end

function CustomPropInfo.MakeTransparent( color )
    return Color( color.r, color.g, color.b, displayTextAlpha or 255 )
end

function CustomPropInfo.SetBackgroundValue( value )
    value = value or displayBackgroundValue
    displayBackgroundValue = value

    local color = infoColors.Background

    if not color then
        color = Color( value, value, value, displayBackgroundAlpha )
        infoColors.Background = color

        return
    end

    infoColors.Background.r = value
    infoColors.Background.g = value
    infoColors.Background.b = value
end

function CustomPropInfo.SetBackgroundAlpha( alpha )
    alpha = alpha or displayBackgroundAlpha
    displayBackgroundAlpha = alpha

    local color = infoColors.Background

    if not color then
        local value = displayBackgroundValue or 100

        color = Color( value, value, value, alpha )
        infoColors.Background = color

        return
    end

    infoColors.Background.a = alpha
end

function CustomPropInfo.SetTextAlpha( alpha )
    alpha = alpha or displayTextAlpha
    displayTextAlpha = alpha

    DEFAULT_COLOR.a = alpha

    for name, color in pairs( infoColors ) do
        if name ~= "Background" and stringSub( name, 5 ) ~= "Solid" then
            color.a = alpha
        end
    end
end

local makeOpaque = CustomPropInfo.MakeOpaque
local setBackgroundValue = CustomPropInfo.SetBackgroundValue
local setBackgroundAlpha = CustomPropInfo.SetBackgroundAlpha
local setTextAlpha = CustomPropInfo.SetTextAlpha


cvars.AddChangeCallback( CVAR_BASE .. "enabled", function( _, old, new )
    cpiEnabled = ( tonumber( new ) or 0 ) ~= 0

    if not cpiEnabled then
        CustomPropInfo.GetPropInfo( NULL )
    end
end )

cvars.AddChangeCallback( CVAR_BASE .. "directions", function( _, old, new )
    cpiDirEnabled = ( tonumber( new ) or 0 ) ~= 0
end )

cvars.AddChangeCallback( CVAR_BASE .. "directions_mode", function( _, old, new )
    cpiDirMode = ( tonumber( new ) or 0 ) ~= 0
end )

cvars.AddChangeCallback( CVAR_BASE .. "tool_only", function( _, old, new )
    cpiToolOnly = ( tonumber( new ) or 0 ) ~= 0
end )

cvars.AddChangeCallback( CVAR_BASE .. "hide_seat", function( _, old, new )
    cpiHideSeat = ( tonumber( new ) or 0 ) ~= 0
end )

cvars.AddChangeCallback( CVAR_BASE .. "directions_length", function( _, old, new )
    cpiDirLength = tonumber( new ) or 0
end )

cvars.AddChangeCallback( CVAR_BASE .. "directions_length_end", function( _, old, new )
    cpiDirLengthEnd = tonumber( new ) or 0
end )

cvars.AddChangeCallback( CVAR_BASE .. "outline", function( _, old, new )
    displayOutline = ( tonumber( new ) or 0 ) ~= 0

    FONT_DATA.outline = displayOutline
    surface.CreateFont( FONT_NAME, FONT_DATA )
end )

cvars.AddChangeCallback( CVAR_BASE .. "background_value", function( _, old, new )
    setBackgroundValue( mathClamp( tonumber( new ) or 50, 0, 255 ) )
end )

cvars.AddChangeCallback( CVAR_BASE .. "background_alpha", function( _, old, new )
    setBackgroundAlpha( mathClamp( tonumber( new ) or 50, 0, 255 ) )
end )

cvars.AddChangeCallback( CVAR_BASE .. "text_alpha", function( _, old, new )
    setTextAlpha( mathClamp( tonumber( new ) or 255, 0, 255 ) )
end )

cvars.AddChangeCallback( CVAR_BASE .. "pos_x", function( _, old, new )
    displayPosX = mathClamp( tonumber( new ) or 0, 0, 1 ) * ScrW()
end )

cvars.AddChangeCallback( CVAR_BASE .. "pos_y", function( _, old, new )
    displayPosY = mathClamp( tonumber( new ) or 0.51, 0, 1 ) * ScrH()
end )

cvars.AddChangeCallback( CVAR_BASE .. "font_size", function( _, old, new )
    local oldVal = math.floor( tonumber( old ) or 20 )
    local newVal = math.floor( tonumber( new ) )

    if not newVal then
        LocalPlayer():ConCommand( CVAR_BASE .. "font_size " .. oldVal )

        return
    end

    displayFontSize = newVal
    displayMinWidth = displayFontSize * CPI_MIN_WIDTH:GetInt()
    FONT_DATA.size = newVal
    surface.CreateFont( FONT_NAME, FONT_DATA )
end )

cvars.AddChangeCallback( CVAR_BASE .. "min_width", function( _, old, new )
    local oldVal = math.floor( tonumber( old ) or 25 )
    local newVal = math.floor( tonumber( new ) )

    if not newVal then
        LocalPlayer():ConCommand( CVAR_BASE .. "min_width " .. oldVal )

        return
    end

    displayMinWidth = displayFontSize * newVal
end )

cvars.AddChangeCallback( CVAR_BASE .. "command_prefix", function( _, old, new )
    local noSpaces = string.sub( string.match( new, "^[%S]+" ) or "", 1, COMMAND_PREFIX_MAX_LENGTH )

    if noSpaces == "" then
        LocalPlayer():ConCommand( CVAR_BASE .. "command_prefix /pi" )

        return
    end

    if noSpaces ~= new then
        LocalPlayer():ConCommand( CVAR_BASE .. "command_prefix " .. noSpaces )

        return
    end

    commandPrefix = noSpaces

    if CustomPropInfo.ServerExists then
        net.Start( "CustomPropInfo_SetCommandPrefix" )
        net.WriteString( commandPrefix )
        net.SendToServer()
    end
end )



--------------------------------------------------------------------------------
-- Functionality:

local displayWidth = false
local displayHeight = false

hook.Add( "HUDPaint", "CustomPropInfo_DisplayInfo", function()
    if not cpiEnabled then return end

    ---- Use surface lib isntead of render lib, also https://wiki.facepunch.com/gmod/surface.DrawText works real nice here

    local count = ( infoDisplayData or {} ).Count or 0

    if count == 0 then return end

    ---- set some surface properties, such as text font

    local x = displayPosX
    local y = displayPosY
    local bgWidth = displayWidth or 0
    local bgHeight = displayHeight or 0

    surface.SetFont( FONT_NAME )

    if not displayWidth then
        for i = 1, count do
            local data = infoDisplayData[i] or {}
            local dataCount = data.Count or 0
            local strings = data.Strings or {}
            local combined = ""

            for i2 = 0, dataCount do
                combined = combined .. strings[i2] or DEFAULT_TEXT_GAP
            end

            local size = surface.GetTextSize( combined )

            if size > bgWidth then
                bgWidth = size
            end
        end

        bgHeight = displayFontSize * count

        displayLongestLine = bgWidth
        displayHeight = bgHeight
    end

    bgWidth = mathMax( bgWidth, displayMinWidth )

    surface.SetDrawColor( infoColors.Background:Unpack() )
    surface.DrawRect( x, y, bgWidth, bgHeight )

    for i = 1, count do
        local data = infoDisplayData[i] or {}
        local dataCount = data.Count or 0
        local strings = data.Strings or {}
        local colors = data.Colors or {}

        surface.SetTextPos( x, y )

        for i2 = 0, dataCount do
            surface.SetTextColor( ( colors[i2] or DEFAULT_COLOR ):Unpack() )
            surface.DrawText( strings[i2] or DEFAULT_TEXT_GAP )
        end

        y = y + displayFontSize
    end
end )

local renderDrawLine = render.DrawLine

hook.Add( "PostDrawOpaqueRenderables", "CustomPropInfo_DirectionalArrows", function( depth, skybox2, skybox3 )
    if skybox2 or skybox3 then return end
    if not cpiDirEnabled then return end
    if not IsValid( cpiEntity ) then return end

    local pos = ( cpiEntity:GetPos() + EyePos() ) / 2
    local forward = cpiEntity:GetForward()
    local right = cpiEntity:GetRight()
    local up = cpiEntity:GetUp()

    if cpiDirMode then
        right = -right
    end

    local forwardPos = pos + forward * cpiDirLength
    local rightPos = pos + right * cpiDirLength
    local upPos = pos + up * cpiDirLength

    local red = infoColors.SolidRed
    local green = infoColors.SolidGreen
    local blue = infoColors.SolidBlue

    renderDrawLine( pos, forwardPos, red, true )
    renderDrawLine( forwardPos, forwardPos + ( right - forward ) * cpiDirLengthEnd, red, true )
    renderDrawLine( forwardPos, forwardPos + ( - right - forward ) * cpiDirLengthEnd, red, true )

    renderDrawLine( pos, rightPos, green, true )
    renderDrawLine( rightPos, rightPos + ( forward - right ) * cpiDirLengthEnd, green, true )
    renderDrawLine( rightPos, rightPos + ( - forward - right ) * cpiDirLengthEnd, green, true )

    renderDrawLine( pos, upPos, blue, true )
    renderDrawLine( upPos, upPos + ( right - up ) * cpiDirLengthEnd, blue, true )
    renderDrawLine( upPos, upPos + ( - right - up ) * cpiDirLengthEnd, blue, true )
end )


function CustomPropInfo.GetPropInfo( ent )
    local count = 0

    if not infoDisplayData then
        infoDisplayData = {}
        CustomPropInfo.DisplayData = infoDisplayData
    end

    if not IsValid( ent ) then
        for i = 1, ( infoEntries[0] or 0 ) do
            infoDisplayData[i] = nil
        end

        infoDisplayData.Count = 0
        cpiEntity = false

        return
    end

    displayWidth = false
    displayHeight = false
    cpiEntity = ent

    for i = 1, ( infoEntries[0] or 0 ) do
        local entry = infoEntries[i] or {}

        -- Wipe old entries directly instead of using table.Empty or overriding the global infoDisplayData table
        infoDisplayData[i] = nil

        if entry.Enabled and not entry.Settings.NoShow then
            local result = entry.Func or entry.FuncOriginal or DEFAULT_FUNC
            result = result( ent ) or {}

            local resultCount = result.Count or 0

            if resultCount > 0 then
                count = count + 1

                local strings = result.Strings or {}
                local colors = result.Colors or {}

                -- Insert entry name at the beginning without having to shift over any other indeces
                strings[0] = entry.Name or ( DEFAULT_TEXT .. ": " )
                colors[0] = infoColors.EntryText or DEFAULT_COLOR

                infoDisplayData[count] = {
                    Count = resultCount,
                    Strings = strings,
                    Colors = colors,
                }
            end
        end
    end

    infoDisplayData.Count = count
end

net.Receive( "CustomPropInfo_RunCommand", function()
    local args = string.Explode( " ", net.ReadString() )
    local callName = args[2] or ""
    local entryInd = infoCommands[callName]

    if not entryInd then
        if callName == "" then
            chat.AddText(
                color_white, "[PropInfo] ",
                makeOpaque( infoColors.Red ), "You must specify a command! ",
                color_white, "You can find a basic list of commands with ",
                makeOpaque( infoColors.Yellow ), commandPrefix .. " help"
            )
        else
            chat.AddText(
                color_white, "[PropInfo] ",
                makeOpaque( infoColors.Yellow ), callName .. " ",
                makeOpaque( infoColors.Red ), "is not a registered command! ",
                color_white, "You can find a basic list of commands with ",
                makeOpaque( infoColors.Yellow ), commandPrefix .. " help"
            )
        end

        return
    end

    local ent = ( LocalPlayer():GetEyeTrace() or {} ).Entity
    local entry = infoEntries[entryInd]

    ent = IsValid( ent ) and ent or nil

    if not ent and not entry.Settings.CanCallWithoutEnt then
        chat.AddText(
            color_white, "[PropInfo] ",
            makeOpaque( infoColors.EntryText ), entry.AlphaName .. ": ",
            makeOpaque( infoColors.Red ), "This command requires you to look at an entity while running it."
        )

        return
    end

    local result = entry.Func( ent ) or {}
    local count = result.Count or 0

    if count < 1 then
        chat.AddText(
            color_white, "[PropInfo] ",
            makeOpaque( infoColors.EntryText ), entry.AlphaName .. ": ",
            makeOpaque( infoColors.PaleRed ), "(no result)"
        )

        return
    end

    local resultFlat = {}
    local strings = result.Strings or {}
    local colors = result.Colors or {}

    for i = 1, count do
        resultFlat[i * 2 - 1] = makeOpaque( colors[i] or color_white )
        resultFlat[i * 2] = strings[i] or " "
    end

    chat.AddText(
        color_white, "[PropInfo] ",
        makeOpaque( infoColors.EntryText ), entry.AlphaName .. ": ",
        unpack( resultFlat )
    )
end )

net.Receive( "CustomPropInfo_InformClientsOfBuddies", function()
    infoBuddies[net.ReadEntity()] = net.ReadTable()
end )

net.Receive( "CustomPropInfo_InformClientsOfBuddiesGroup", function()
    local buddyGroups = net.ReadTable()

    for ply, buddies in pairs( buddyGroups ) do
        infoBuddies[ply] = buddies
    end
end )

local getPropInfo = CustomPropInfo.GetPropInfo

function CustomPropInfo.StartInfoTimer()
    timer.Create( "CustomPropInfo_EntityCheck", cpiInterval, 0, function()
        if not cpiEnabled then return end

        if cpiToolOnly then
            local wep = LocalPlayer():GetActiveWeapon()
            local class = IsValid( wep ) and wep:GetClass() or ""

            if class ~= "weapon_physgun" and class ~= "gmod_tool" then
                getPropInfo( NULL )

                return
            end
        end

        if cpiHideSeat and LocalPlayer():InVehicle() then
            getPropInfo( NULL )

            return
        end

        local ent = ( LocalPlayer():GetEyeTrace() or {} ).Entity

        getPropInfo( ent )
    end )
end

hook.Add( "InitPostEntity", "CustomPropInfo_Init", function()
    checkServerPresence()
    setBackgroundValue( CPI_BACKGROUND_VALUE:GetFloat() )
    setBackgroundAlpha( CPI_BACKGROUND_ALPHA:GetFloat() )
    setTextAlpha( CPI_TEXT_ALPHA:GetFloat() )

    timer.Simple( 10, function()
        checkServerPresence() -- Just in case
        CustomPropInfo.StartInfoTimer()

        if CustomPropInfo.ServerExists then
            net.Start( "CustomPropInfo_SetCommandPrefix" )
            net.WriteString( commandPrefix )
            net.SendToServer()
        end
    end )
end )

cvars.AddChangeCallback( CVAR_BASE .. "update_interval", function( _, old, new )
    local oldVal = tonumber( old ) or 0.5
    local newVal = mathClamp( tonumber( new ) or 0.5, 0.05, 3 )

    if tonumber( new ) ~= newVal then
        LocalPlayer():ConCommand( CVAR_BASE .. "update_interval " .. oldVal )

        return
    end

    if oldVal == newVal then return end

    cpiInterval = newVal

    CustomPropInfo.StartInfoTimer()
end )

if not CPI_FIRST_USE:GetBool() then return end

hook.Add( "InitPostEntity", "CustomPropInfo_NoteFirstUse", function()
    LocalPlayer():ConCommand( CVAR_BASE .. "enabled " .. ENABLED_DEFAULT:GetString() )
    LocalPlayer():ConCommand( CVAR_BASE .. "first_use 0" )

    timer.Simple( 10, function() -- Just in case
        LocalPlayer():ConCommand( CVAR_BASE .. "enabled " .. ENABLED_DEFAULT:GetString() )
    end )
end )

local function doIntroMessage()
    if not WELCOME_ENABLED:GetBool() then
        hook.Remove( "StartChat", "CustomPropInfo_IntroMessage" )
        hook.Remove( "KeyPress", "CustomPropInfo_IntroMessage" )

        return
    end

    local menuKey = input.LookupBinding( "+menu" )

    if not menuKey or menuKey == "no value" then
        menuKey = "q"
    end

    chat.AddText(
        color_white, "[PropInfo] ",
        makeOpaque( infoColors.TechnicalBlue ), "Welcome! ",
        color_white, "This server has ",
        makeOpaque( infoColors.Yellow ), "CustomPropInfo ",
        color_white, "installed. Check your ",
        makeOpaque( infoColors.SoftYellow ), "options tab ",
        color_white, "in the upper right of the ",
        makeOpaque( infoColors.SoftYellow ), "spawnmenu (",
        makeOpaque( infoColors.Yellow ), menuKey,
        makeOpaque( infoColors.SoftYellow ), ") ",
        color_white, "to toggle it and other features. This is a one-time message and will not appear again."
    )

    hook.Remove( "StartChat", "CustomPropInfo_IntroMessage" )
    hook.Remove( "KeyPress", "CustomPropInfo_IntroMessage" )
end

hook.Add( "StartChat", "CustomPropInfo_IntroMessage", doIntroMessage )

hook.Add( "KeyPress", "CustomPropInfo_IntroMessage", function( ply, key )
    if key ~= IN_FORWARD then return end

    doIntroMessage()
end )
