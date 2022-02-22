CustomPropInfo = CustomPropInfo or {}
CustomPropInfo.Entries = CustomPropInfo.Entries or {}
CustomPropInfo.EntryLookup = CustomPropInfo.EntryLookup or {}
CustomPropInfo.Colors = CustomPropInfo.Colors or {}
CustomPropInfo.ClientConVars = CustomPropInfo.ClientConVars or {}
CustomPropInfo.ClientConVarsEntries = CustomPropInfo.ClientConVarsEntries or {}
CustomPropInfo.RequestCache = CustomPropInfo.RequestCache or {}
CustomPropInfo.Commands = CustomPropInfo.Commands or {}
CustomPropInfo.CPPIBuddies = CustomPropInfo.CPPIBuddies or {}

local infoEntries = CustomPropInfo.Entries
local infoEntryLookup = CustomPropInfo.EntryLookup
local infoColors = CustomPropInfo.Colors
local infoRequestCache = CustomPropInfo.RequestCache
local infoCommands = CustomPropInfo.Commands
local infoBuddies = CustomPropInfo.CPPIBuddies
local clConVarsEntries = CustomPropInfo.ClientConVarsEntries

local CVAR_BASE = "custom_propinfo_"
local DEFAULT_TEXT = "???"
local DEFAULT_TEXT_GAP = DEFAULT_TEXT .. " "
local DEFAULT_COLOR = Color( 255, 255, 255, 255 )
local BASIC_REQUEST_COOLDOWN = 0.5

infoColors.Background = Color( 100, 100, 100 )
infoColors.Text = Color( 255, 255, 255 )
infoColors.EntryText = Color( 255, 255, 140 )
infoColors.Red = Color( 255, 0, 0 )
infoColors.Green = Color( 0, 255, 0 )
infoColors.Blue = Color( 0, 0, 255 )
infoColors.Yellow = Color( 255, 255, 0 )
infoColors.Orange = Color( 255, 150, 0 )
infoColors.TechnicalBlue = Color( 0, 130, 255 )
infoColors.SoftRed = Color( 255, 140, 140 )
infoColors.SoftGreen = Color( 140, 255, 140 )
infoColors.SoftBlue = Color( 100, 180, 255 )
infoColors.SoftYellow = Color( 255, 255, 140 )
infoColors.SoftOrange = Color( 255, 190, 100 )
infoColors.PaleRed = Color( 255, 200, 187 )
infoColors.PvP = Color( 255, 80, 80 )
infoColors.Build = Color( 80, 80, 255 )

-- The Background color and any color with a name starting with "Solid" will not have their alpha modified by the custom_propinfo_text_alpha convar
infoColors.SolidRed = Color( 255, 0, 0 )
infoColors.SolidGreen = Color( 0, 255, 0 )
infoColors.SolidBlue = Color( 0, 0, 255 )


local function generateEntryConvar( name, alphaName, entry, blockToggle, default )
    local cvName = CVAR_BASE .. "entrytoggle_" .. string.lower( alphaName )
    local cvHelp = "Enables the " .. alphaName .. " CPI entry." .. ( blockToggle and " This entry cannot be toggled." or "" )
    local convar = CreateClientConVar( cvName, default and 1 or 0, true, false, cvHelp, 0, 1 )

    clConVarsEntries[name] = convar

    if not blockToggle then
        entry.Enabled = convar:GetBool()
    else
        entry.Enabled = default
    end

    cvars.AddChangeCallback( cvName, function( _, old, new )
        local state = ( tonumber( new ) or 0 ) ~= 0

        if blockToggle and default ~= state then
            LocalPlayer():ConCommand( cvName .. ( default and " 1" or " 0" ) )

            return
        end

        entry.Enabled = state
    end )

    local togglesPanel = CustomPropInfo.TogglesPanel

    if togglesPanel and togglesPanel:Valid() then
        togglesPanel:Remove()

        timer.simple( 0.1, function()
            local basePanel = CustomPropInfo.SettingsPanel

            togglesPanel = CustomPropInfo.CreateCollapsibleSliders( basePanel, "Entry Toggles", CustomPropInfo.GenerateCollapsibleEntryData() )
            basePanel:AddItem( togglesPanel )

            CustomPropInfo.TogglesPanel = togglesPanel
        end )
    end

    return convar
end

-- Core Functions:

--[[
    Adds a new info type to the prop info list, allowing other addons/servers/clients to expand the list with custom data.

    inputs:
        name: Name of info entry to add to the list.
        func: A function( ent ) which either returns nil to not display the entry, or returns { LIST_OF_STRINGS, LIST_OF_COLORS, OPTIONAL_EXTRA_INFO }, or returns a table with the format below
        settings: {
            CallNames = TABLE, -- A list of strings which will be used to call the function via chat command for printing out to chat, taking the standard return format. Only the first in the list will be displayed in the help command.
            OptionText = STRING, -- A short string to attach to the toggle checkbox in the option menu for this entry, like a mini-description.
            NoShow = BOOL, -- Never show on the HUD display, used for adding special CPI commands. This will also hide it from the entry toggle list.
            DefaultEnable = BOOL, -- Should this entry be on by default?
            BlockToggle = BOOL, -- Prevent the user from enabling/disabling this entry.
            CanCallWithoutEnt = BOOL, -- Can the entry function be called without a valid entity? Only applies to when called via chat command.
        }


    The func will afterwards be wrapped to actually return nil OR {
        Count = LIST_LENGTH,
        Strings = LIST_OF_STRINGS,
        Colors = LIST_OF_COLORS,
        ExtraInfo = OPTIONAL_EXTRA_INFO, -- Any type of data (preferably a string-indexed table for modularity) to pass along useful info for recursive calls in CustomPropInfo.AlterInfoEntry()
    }
    It gets wrapped for readability elsewhere, and to make CustomPropInfo.AlterInfoEntry() more reliable.

    If your func only returns one string (or other non-nil, non-table value), it will get auto-converted to the table format and use the default text color, to make adding basic entries simpler.
    You do not need to check for IsValid( ent ), as prop info is only acquired on valid entities. This also means that it will never acquire info on the world.
--]]
function CustomPropInfo.RegisterInfoEntry( name, func, settings )
    if type( name ) ~= "string" then
        ErrorNoHaltWithStack( "PropInfo entry names must be a string." )

        return false
    end

    if type( func ) ~= "function" then
        ErrorNoHaltWithStack( "PropInfo entries need a function of the form\n   function( ent )  return  nil OR { LIST_OF_STRINGS, LIST_OF_COLORS }  end" )

        return false
    end

    local entryCount = infoEntries[0] or 0

    for i = 1, entryCount do
        if infoEntries[i].Name == name then
            ErrorNoHaltWithStack( "There is already a PropInfo entry registered with the name " .. name )

            return false
        end
    end

    local alphaName

    alphaName = string.gsub( name, "[%s]+", "_" )
    alphaName = string.match( alphaName, "[%a_]+" ) or "UNKNOWN"

    entryCount = entryCount + 1
    infoEntries[0] = entryCount
    infoEntryLookup[name] = entryCount
    settings = settings or {}

    local entry = {
        Name = name,
        FuncOriginal = func,
        Func = function( ent )
            local result = func( ent )

            if result == nil then return end

            if type( result ) == "table" then
                local strings = result.Strings or result[1] or { DEFAULT_TEXT }
                local colors = result.Colors or result[2] or { DEFAULT_COLOR }

                return {
                    Count = #strings,
                    Strings = strings,
                    Colors = colors,
                    ExtraInfo = result.ExtraInfo or result[3],
                }
            end

            return {
                Count = 1,
                Strings = { tostring( result ) },
                Colors = { infoColors.Text or DEFAULT_COLOR },
                ExtraInfo = result.ExtraInfo or result[3],
            }
        end,
        Settings = settings,
        AlphaName = alphaName, -- Only contains letters and underscores
    }

    local callNames = settings.CallNames or {}

    for _, callName in pairs( callNames ) do
        infoCommands[callName] = entryCount
    end

    infoEntries[entryCount] = entry

    if not settings.NoShow then
        generateEntryConvar( name, alphaName, entry, settings.BlockToggle, settings.DefaultEnable )
    end

    return true
end


--[[
    Wraps a pre-existing info entry to append, remove, or otherwise modify its output.
        e.g. Append a build/pvp status marker to a player's/ent owner's name for servers with a build/pvp system.
    Behaves similarly to CustomPropInfo.RegisterInfoEntry(), except the arguments to func are function( ent, oldResult ),
        where oldResult is in the wrapped format described above. If the original result is nil, it'll be replaced with a formatted table with Count = 0.

    This is capable of wrapping for several layers. If you want to forcefully cut out some pre-existing wraps, CustomPropInfo.Entries[INDEX].FuncOriginal gives the base-level function.
        The index of an entry can be obtained with CustomPropInfo.EntryLookup[entryName]
        If one of the older functions in the chain returns a result containing ExtraInfo, you can access it with oldResult.ExtraInfo, useful for reducing recalculations, such as for getting an entity owner
--]]
function CustomPropInfo.AlterInfoEntry( name, func )
    if type( name ) ~= "string" then
        ErrorNoHaltWithStack( "PropInfo entry names must be a string." )

        return false
    end

    local ind = infoEntryLookup[name]

    if not ind then
        ErrorNoHaltWithStack( "Could not find a PropInfo entry with the name " .. name )

        return false
    end

    if type( func ) ~= "function" then
        ErrorNoHaltWithStack( "PropInfo entries need a function of the form\n   function( ent )  return  nil OR { LIST_OF_STRINGS, LIST_OF_COLORS }  end" )

        return false
    end

    local entry = infoEntries[ind]
    local prevFunc = entry.Func

    entry.Func = function( ent )
        local oldResult = prevFunc( ent ) or {
            Count = 0,
            Strings = {},
            Colors = {},
        }

        local result = func( ent, oldResult )

        if result == nil then return end

        if type( result ) == "table" then
            local strings = result.Strings or result[1] or { DEFAULT_TEXT }
            local colors = result.Colors or result[2] or { DEFAULT_COLOR }

            return {
                Count = #strings,
                Strings = strings,
                Colors = colors,
                ExtraInfo = result.ExtraInfo or result[3],
            }
        end

        return {
            Count = 1,
            Strings = { tostring( result ) },
            Colors = { infoColors.Text or DEFAULT_COLOR },
        }
    end

    return true
end


--[[
    Sends a request to the server to acquire some info that isn't readily available to the client realm.

    For each entry, there could be multiple different special requests made,
        such as conditionally needing different kinds of info, or when multiple layers that want server info are created with CustomPropInfo.AlterInfoEntry().
        So, each request should be given a uniqueID string to identify it between other requests in the same info entry.
    On the server's end, use CustomPropInfo.RegisterRequestResponse() to create a response to the specific info request.

    Will return whatever the most recently-received data was, which gets stored into a cache, or nil if nothing is currently cached.
    Will return false if the server doesn't have this addon installed or if the request is invalid (with the second argument being the corresponding message, in case you want to display it to the user).
        However, such a scenario can only occur with a hacked client or on servers with sv_allowcslua 1, as otherwise the client will never be able to use this addon on dedicated servers.

    clCooldown applies an optional cooldown on the client's end, in case it's data that doesn't update often or is more intensive to request, reducing the amount of net messages.
        Of course, this doesn't stop hacked clients from spamming the net message endlessly, so the server's end still has its own cooldown system, this just reduces
        excess net messages for good-faith clients.
--]]
function CustomPropInfo.RequestServerInfo( ent, entryName, uniqueID, clCooldown )
    if not CustomPropInfo.ServerExists then return false, "(Server doesn't have CustomPropInfo)" end

    if type( entryName ) ~= "string" then
        ErrorNoHaltWithStack( "PropInfo requests to the server need an entry name string." )

        return false, "(Invalid server info request)"
    end

    if type( uniqueID ) ~= "string" then
        ErrorNoHaltWithStack( "PropInfo requests to the server need a uniqueID string to identify different kinds of requests for the same info entry." )

        return false, "(Invalid server info request)"
    end

    local cacheGroup = infoRequestCache[entryName]

    if not cacheGroup then
        cacheGroup = {}
        infoRequestCache[entryName] = cacheGroup
    end

    local cache = cacheGroup[uniqueID]

    if not cache then
        cache = {}
        cacheGroup[uniqueID] = cache
    end

    local coolTime = cache.CoolTime
    local curTime = SysTime()

    if not coolTime or curTime > coolTime then
        net.Start( "CustomPropInfo_RequestInfo" )
        net.WriteEntity( IsValid( ent ) and ent or NULL )
        net.WriteString( entryName )
        net.WriteString( uniqueID )
        net.SendToServer()

        if type( clCooldown ) == "number" and clCooldown > 0 then
            cache.CoolTime = curTime + clCooldown
        elseif coolTime then
            cache.CoolTime = nil -- No need to repeatedly make comparison checks later if there's no more cooldown
        end
    end

    return cache.Data
end


-- Global Helpers:

--[[
    Does owner trust ply via CPPI?
        false <- no
        1 <- yes
        2 <- yes, by technicality (owner == ply, or ply is superadmin)
--]]
function CustomPropInfo.PlayerTrusts( owner, ply )
    if not IsValid( ply ) or not ply:IsPlayer() then return false end
    if owner == ply or ply:IsSuperAdmin() then return 2 end
    if not IsValid( owner ) then return false end

    local friends = owner.CPPIGetFriends and owner:CPPIGetFriends()

    if type( friends ) ~= "table" then
        friends = infoBuddies[owner]
    end

    if not friends then return false end

    for _, friend in pairs( friends ) do
        if ply == friend then return 1 end
    end

    return false
end


-- Returns blue if owner trusts by technicality, red/green for (not) trusting, choosing soft shades if owner == LocalPlayer()
function CustomPropInfo.GetTrustColor( owner, trustState )
    if owner == LocalPlayer() then
        if not trustState then return infoColors.SoftRed end
        if trustState == 1 then return infoColors.SoftGreen end
        if trustState == 2 then return infoColors.SoftBlue end
    end

    if not trustState then return infoColors.Red end
    if trustState == 1 then return infoColors.Green end
    if trustState == 2 then return infoColors.TechnicalBlue end

    return DEFAULT_COLOR
end


--[[
    Uses CustomPropInfo.AlterInfoEntry() to append data to the end of the current entry result.

    func:
        preferred return format: nil OR { Count = LIST_LENGTH, Strings = LIST_OF_STRINGS, Colors = LIST_OF_COLORS }
        other accepted return formats:
            { LIST_OF_STRINGS, LIST_OF_COLORS }
            { LIST_OF_STRINGS }, { LIST_OF_COLORS }
            STRING, COLOR
            STRING
--]]
function CustomPropInfo.AppendInfoEntry( name, func )
    func = type( func ) == "function" and func or function() end

    CustomPropInfo.AlterInfoEntry( name, function( ent, oldResult )
        local result, result2 = func( ent, oldResult )
        local rType = type( result )

        if result == nil then return oldResult end

        if type( result ) == "table" then
            local appendStrings = result.Strings or result[1]
            local appendColors = result.Colors or result[2] or result2
            local count = result.Count or #appendStrings

            appendColors = type( appendColors ) == "table" and appendColors or ( type( appendColors ) == "Color" and { appendColors } ) or {}

            local oldCount = oldResult.Count
            local strings = oldResult.Strings
            local colors = oldResult.Colors

            for i = 1, count do
                local ind = oldCount + i

                strings[ind] = tostring( appendStrings[i] )
                colors[ind] = appendColors[i] or infoColors.Text or DEFAULT_COLOR
            end

            -- The final string count will get auto-updated by AlterInfoEntry()

            return oldResult
        end

        local oldCount = oldResult.Count + 1

        oldResult.Strings[oldCount] = tostring( result )
        oldResult.Colors[oldCount] = type( result2 ) == "Color" and result2 or infoColors.Text or DEFAULT_COLOR

        return oldResult
    end )
end


--------------------------------------------------------------------------------
-- Helpers/Misc Functionality:


local registerEntry = CustomPropInfo.RegisterInfoEntry
local alterEntry = CustomPropInfo.AlterInfoEntry
local playerTrusts = CustomPropInfo.PlayerTrusts
local getTrustColor = CustomPropInfo.GetTrustColor
local appendInfoEntry = CustomPropInfo.AppendInfoEntry

local mathRound = math.Round
local mathClamp = math.Clamp

local roundAmount = GetConVar( CVAR_BASE .. "round" ):GetInt() or 3
local displayTextAlpha = GetConVar( CVAR_BASE .. "text_alpha" ):GetFloat() or 255

local function makeTransparent( color )
    return Color( color.r, color.g, color.b, displayTextAlpha or 255 )
end

local function getOBBSize( ent )
    return ent:OBBMaxs() - ent:OBBMins()
end

local function getTeamColor( ply )
    return team.GetColor( ply:Team() ) or infoColors.Yellow
end

local function getTeamColorTransparent( ply )
    return makeTransparent( getTeamColor( ply ) )
end

local function convertFloatColor( color )
    return Color(
        mathClamp( color.r * 255, 0, 255 ), -- Clamp values to not give away the out-of-range colors some people use for wepcolor to have extra unique physgun appearances, as custom ones can be quite special to people
        mathClamp( color.g * 255, 0, 255 ),
        mathClamp( color.b * 255, 0, 255 ),
        255
    )
end


cvars.AddChangeCallback( CVAR_BASE .. "round", function( _, old, new )
    new = tonumber( new ) or 3
    roundAmount = math.Clamp( math.floor( new ), 0, 10 )

    if roundAmount ~= new then
        LocalPlayer():ConCommand( CVAR_BASE .. "round " .. roundAmount )
    end
end )

cvars.AddChangeCallback( CVAR_BASE .. "text_alpha", function( _, old, new )
    displayTextAlpha = mathClamp( tonumber( new ) or 255, 0, 255 )
    DEFAULT_COLOR.a = displayTextAlpha
end )


net.Receive( "CustomPropInfo_RequestResponse", function()
    local entryName = net.ReadString()
    local uniqueID = net.ReadString()
    local result = net.ReadTable()

    local cacheGroup = infoRequestCache[entryName]

    if not cacheGroup then
        cacheGroup = {}
        infoRequestCache[entryName] = cacheGroup
    end

    local cache = cacheGroup[uniqueID]

    if not cache then
        cache = {}
        cacheGroup[uniqueID] = cache
    end

    cache.Data = result
end )



--------------------------------------------------------------------------------
-- Default Entries:



registerEntry( "Entity: ", function( ent ) -- Primary entity info, cannot be turned off in config
    if ent:IsPlayer() then
        return {
            Strings = { tostring( ent ), },
            Colors = { getTeamColorTransparent( ent ) },
            ExtraInfo = { Player = ent },
        }
    end

    return {
        Strings = { tostring( ent ) },
        Colors = { infoColors.Orange },
    }
end,
{
    CallNames = {},
    OptionText = "Primary entity info",
    NoShow = false,
    DefaultEnable = true,
    BlockToggle = true,
} )


registerEntry( "Owner: ", function( ent )
    if ent:IsPlayer() then return end

    local owner = ent.CPPIGetOwner and ent:CPPIGetOwner() or ent:GetOwner()
    local ownerIsAPlayer = IsValid( owner ) and owner:IsPlayer()

    return {
        Strings = { ownerIsAPlayer and tostring( owner ) or "None" },
        Colors = { ownerIsAPlayer and getTeamColorTransparent( owner ) or infoColors.PaleRed },
        ExtraInfo = { Player = owner },
    }
end,
{
    CallNames = { "owner" },
    NoShow = false,
    DefaultEnable = true,
    BlockToggle = false,
} )


registerEntry( "CPPI: ", function( ent ) -- Extra prop-protection info, if CPPI exists
    if not CPPI then return end

    local ply

    if ent:IsPlayer() then
        ply = ent
    else
        ply = ent.CPPIGetOwner and ent:CPPIGetOwner() or ent:GetOwner()

        if not IsValid( ply ) then return end
    end

    local locPly = LocalPlayer()

    if locPly == ply then
        return {
            Strings = { "You trust yourself" },
            Colors = { getTrustColor( locPly, 2 ) },
        }
    end

    local theyTrust = playerTrusts( ply, locPly )
    local youTrust = playerTrusts( locPly, ply )
    local theirColor = getTrustColor( ply, theyTrust )
    local yourColor = getTrustColor( locPly, youTrust )
    local textColor = infoColors.Text or DEFAULT_COLOR

    return {
        Strings = {
            theyTrust and "They trust you" or "They don't trust you", ", ",
            youTrust and "you trust them" or "you don't trust them",
        },
        Colors = {
            theirColor, textColor,
            yourColor,
        },
    }
end,
{
    CallNames = {},
    OptionText = function() return CPPI and "Prop protection info" or "Requires a prop protection addon" end,
    NoShow = false,
    DefaultEnable = true,
    BlockToggle = false,
} )


registerEntry( "Model: ", function( ent )
    return tostring( ent:GetModel() )
end,
{
    CallNames = { "model", "mod" },
    NoShow = false,
    DefaultEnable = true,
    BlockToggle = false,
} )


registerEntry( "Material: ", function( ent )
    local mat = ent:GetMaterial() or ""

    return mat ~= "" and mat or ent:GetMaterials()[1]
end,
{
    CallNames = { "material", "mat" },
    NoShow = false,
    DefaultEnable = true,
    BlockToggle = false,
} )


registerEntry( "Size: ", function( ent )
    local size = getOBBSize( ent )
    local textColor = infoColors.Text or DEFAULT_COLOR

    return {
        Strings = {
            tostring( mathRound( size[1], roundAmount ) ), ", ",
            tostring( mathRound( size[2], roundAmount ) ), ", ",
            tostring( mathRound( size[3], roundAmount ) ),
        },
        Colors = {
            infoColors.SoftRed, textColor,
            infoColors.SoftGreen, textColor,
            infoColors.SoftBlue,
        },
    }
end,
{
    CallNames = { "size" },
    NoShow = false,
    DefaultEnable = true,
    BlockToggle = false,
} )


registerEntry( "Position: ", function( ent )
    local pos = ent:GetPos()
    local textColor = infoColors.Text or DEFAULT_COLOR

    return {
        Strings = {
            tostring( mathRound( pos[1], roundAmount ) ), ", ",
            tostring( mathRound( pos[2], roundAmount ) ), ", ",
            tostring( mathRound( pos[3], roundAmount ) ),
        },
        Colors = {
            infoColors.SoftRed, textColor,
            infoColors.SoftGreen, textColor,
            infoColors.SoftBlue,
        },
    }
end,
{
    CallNames = { "position", "pos" },
    NoShow = false,
    DefaultEnable = true,
    BlockToggle = false,
} )


registerEntry( "Angles: ", function( ent )
    local ang = ent:GetAngles()
    local textColor = infoColors.Text or DEFAULT_COLOR

    return {
        Strings = {
            tostring( mathRound( ang[1], roundAmount ) ), ", ",
            tostring( mathRound( ang[2], roundAmount ) ), ", ",
            tostring( mathRound( ang[3], roundAmount ) ),
        },
        Colors = { -- Colors are GBR instead of RGB in order to match which vector axis that angle rotates around
            infoColors.SoftGreen, textColor,
            infoColors.SoftBlue, textColor,
            infoColors.SoftRed,
        },
    }
end,
{
    CallNames = { "angles", "angle", "ang" },
    NoShow = false,
    DefaultEnable = true,
    BlockToggle = false,
} )


registerEntry( "Color: ", function( ent )
    local color = ent:GetColor()
    local displayColor = Color( color.r, color.g, color.b, displayTextAlpha )

    return {
        Strings = {
            tostring( mathRound( color.r, roundAmount ) ) .. ", " ..
            tostring( mathRound( color.g, roundAmount ) ) .. ", " ..
            tostring( mathRound( color.b, roundAmount ) ) .. ", " ..
            tostring( mathRound( color.a, roundAmount ) ),
        },
        Colors = {
            displayColor
        },
    }
end,
{
    CallNames = { "color" },
    NoShow = false,
    DefaultEnable = true,
    BlockToggle = false,
} )


registerEntry( "Player Color: ", function( ent )
    if not ent:IsPlayer() then return end

    local color = convertFloatColor( ent:GetPlayerColor() )
    local displayColor = Color( color.r, color.g, color.b, displayTextAlpha )

    return {
        Strings = {
            tostring( mathRound( color.r, roundAmount ) ) .. ", " ..
            tostring( mathRound( color.g, roundAmount ) ) .. ", " ..
            tostring( mathRound( color.b, roundAmount ) ),
        },
        Colors = {
            displayColor
        },
    }
end,
{
    CallNames = {},
    OptionText = "Only on players",
    NoShow = false,
    DefaultEnable = true,
    BlockToggle = false,
} )


registerEntry( "Weapon Color: ", function( ent )
    if not ent:IsPlayer() then return end

    local color = convertFloatColor( ent:GetWeaponColor() )
    local displayColor = Color( color.r, color.g, color.b, displayTextAlpha )

    return {
        Strings = {
            tostring( mathRound( color.r, roundAmount ) ) .. ", " ..
            tostring( mathRound( color.g, roundAmount ) ) .. ", " ..
            tostring( mathRound( color.b, roundAmount ) ),
        },
        Colors = {
            displayColor
        },
    }
end,
{
    CallNames = {},
    OptionText = "Only on players",
    NoShow = false,
    DefaultEnable = true,
    BlockToggle = false,
} )


registerEntry( "Weapon: ", function( ent )
    if not ent:IsPlayer() then return end

    local wep = ent:GetActiveWeapon()

    if not IsValid( ent ) then
        return {
            Strings = { "None" },
            Colors = { infoColors.PaleRed },
        }
    end

    return {
        Strings = { tostring( wep ) },
        Colors = { infoColors.SoftBlue },
    }
end,
{
    CallNames = { "weapon", "wep" },
    OptionText = "Only on players",
    NoShow = false,
    DefaultEnable = true,
    BlockToggle = false,
} )



registerEntry( "Mass: ", function( ent ) -- Uses a server request
    local data, failReason = CustomPropInfo.RequestServerInfo( ent, "Mass: ", "CPI_BaseRequest", BASIC_REQUEST_COOLDOWN )

    if data then
        local invalid = data.Invalid

        if invalid then
            return {
                Strings = { tostring( invalid ) },
                Colors = { infoColors.PaleRed },
            }
        end

        return tostring( mathRound( data.Mass or 0, roundAmount ) )
    end

    return {
        Strings = { DEFAULT_TEXT .. ( failReason and ( " " .. failReason ) or "" ) },
        Colors = { infoColors.PaleRed },
    }
end,
{
    CallNames = { "mass" },
    OptionText = function() return not CustomPropInfo.ServerExists and "Server doesn't have CPI" or nil end,
    NoShow = false,
    DefaultEnable = true,
    BlockToggle = false,
} )



registerEntry( "Frozen: ", function( ent ) -- Uses a server request
    if ent:IsPlayer() then
        local frozen = ent:IsFrozen()

        return {
            Strings = { frozen and "true" or "false" },
            Colors = { frozen and infoColors.Green or infoColors.Red },
        }
    end

    local data, failReason = CustomPropInfo.RequestServerInfo( ent, "Frozen: ", "CPI_BaseRequest", BASIC_REQUEST_COOLDOWN )

    if data then
        local invalid = data.Invalid

        if invalid then
            return {
                Strings = { tostring( invalid ) },
                Colors = { infoColors.PaleRed },
            }
        end

        local frozen = data.Frozen

        return {
            Strings = { frozen and "true" or "false" },
            Colors = { frozen and infoColors.Green or infoColors.Red },
        }
    end

    return {
        Strings = { DEFAULT_TEXT .. ( failReason and ( " " .. failReason ) or "" ) },
        Colors = { infoColors.PaleRed },
    }
end,
{
    CallNames = {},
    OptionText = function() return not CustomPropInfo.ServerExists and "Server doesn't have CPI" or nil end,
    NoShow = false,
    DefaultEnable = true,
    BlockToggle = false,
} )


registerEntry( "Collisions: ", function( ent )
    local collided = ent:GetCollisionGroup() ~= COLLISION_GROUP_WORLD

    return {
        Strings = { collided and "true" or "false" },
        Colors = { collided and infoColors.Green or infoColors.Red },
    }
end,
{
    CallNames = {},
    NoShow = false,
    DefaultEnable = true,
    BlockToggle = false,
} )


registerEntry( "Driver: ", function( ent )
    if not ent:IsVehicle() then return end

    local driver = ent:GetDriver()

    if IsValid( driver ) and driver:IsPlayer() then
        return {
            Strings = { tostring( driver ) },
            Colors = { getTeamColorTransparent( driver ) },
            ExtraInfo = { Player = driver },
        }
    end

    return {
        Strings = { "None" },
        Colors = { infoColors.PaleRed },
    }
end,
{
    CallNames = {},
    OptionText = "Only on vehicles",
    NoShow = false,
    DefaultEnable = true,
    BlockToggle = false,
} )



--------------------------------------------------------------------------------
-- Default NoShow Commands:

registerEntry( "--Help", function( ent )
    local entryCount = infoEntries[0] or 0
    local count = 0
    local strings = {}
    local colors = {}

    for i = 1, entryCount do
        local entry = infoEntries[i] or {}
        local callNames = ( entry.Settings or {} ).CallNames or {}
        local primaryCallName = callNames[1]

        if primaryCallName then
            count = count + 1
            strings[count] = primaryCallName
            colors[count] = infoColors.Yellow or Color( 255, 255, 0 )

            count = count + 1
            strings[count] = ", "
            colors[count] = color_white
        end
    end

    strings[count - 2] = ", and "

    strings[count] = nil
    colors[count] = nil

    return {
        Strings = strings,
        Colors = colors,
    }
end,
{
    CallNames = { "help" },
    NoShow = true,
    CanCallWithoutEnt = true,
} )


registerEntry( "--Type", function( ent )
    return ent:GetClass()
end,
{
    CallNames = { "type", "class" },
    NoShow = true,
} )


registerEntry( "--Directions", function( ent )
    local newState = GetConVar( CVAR_BASE .. "directions" ):GetInt() == 0

    LocalPlayer():ConCommand( CVAR_BASE .. "directions " .. ( newState and "1" or "0" ) )

    return {
        Strings = {
            "Directional arrows are now ",
            newState and "enabled" or "disabled",
            "."
        },
        Colors = {
            infoColors.Text,
            newState and infoColors.Green or infoColors.Red,
            infoColors.Text,
        }
    }
end,
{
    CallNames = { "directions", "dirs", "dir", "d" },
    NoShow = true,
    CanCallWithoutEnt = true,
} )

registerEntry( "--DirectionsMode", function( ent )
    local newState = GetConVar( CVAR_BASE .. "directions_mode" ):GetInt() == 0

    LocalPlayer():ConCommand( CVAR_BASE .. "directions_mode " .. ( newState and "1" or "0" ) )

    return {
        Strings = {
            "Directional mode has been set to ",
            newState and "local coords" or "direction vectors",
            "."
        },
        Colors = {
            infoColors.Text,
            newState and infoColors.Green or infoColors.SoftGreen,
            infoColors.Text,
        }
    }
end,
{
    CallNames = { "dirmode", "dirm", "dm" },
    NoShow = true,
    CanCallWithoutEnt = true,
} )



--------------------------------------------------------------------------------
-- Default Conditionals:

if CFCPvp then
    local function appendPvpStatus( ent, oldResult )
        local ply = ( oldResult.ExtraInfo or {} ).Player

        if not IsValid( ply ) or not ply:IsPlayer() then return end

        local inBuild = ply:isInBuild()

        return {
            Strings = {
                ", ", inBuild and "Build" or "PvP"
            },
            Colors = {
                infoColors.Text, inBuild and infoColors.Build or infoColors.PvP
            },
        }
    end

    appendInfoEntry( "Entity: ", appendPvpStatus )
    appendInfoEntry( "Owner: ", appendPvpStatus )
    appendInfoEntry( "Driver: ", appendPvpStatus )
end
