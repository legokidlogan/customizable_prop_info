CustomPropInfo = CustomPropInfo or {}
CustomPropInfo.CommandPrefixes = CustomPropInfo.CommandPrefixes or {}
CustomPropInfo.RequestResponses = CustomPropInfo.RequestResponses or {}

local convarFlags = { FCVAR_ARCHIVE, FCVAR_REPLICATED }
local CVAR_BASE = "custom_propinfo_"
local HOOK_INFORM_BUDDIES = "CustomPropInfo_InformClientsOfBuddies"
local HOOK_INFORM_BUDDIES_GROUP = "CustomPropInfo_InformClientsOfBuddiesGroup"

local REQUEST_COOLDOWN = CreateConVar( CVAR_BASE .. "request_cooldown_default", 0.3, convarFlags, "Sets the default serverside cooldown for CPI info requests.", 0, 5 )
local WELCOME_ENABLED = CreateConVar( CVAR_BASE .. "welcome_message_enabled", 1, convarFlags, "Whether or not new users will receive a welcome message on their first-ever join.", 0, 1 )
local ENABLED_DEFAULT = CreateConVar( CVAR_BASE .. "enabled_default", 1, convarFlags, "Whether or not new users who've never used this addon before should have CPI enabled by default. Set to 0 if new users are easily bothered by large HUD changes.", 0, 1 )


local infoPrefixes = CustomPropInfo.CommandPrefixes
local requestResponses = CustomPropInfo.RequestResponses


util.AddNetworkString( "CustomPropInfo_RequestInfo" )
util.AddNetworkString( "CustomPropInfo_RequestResponse" )
util.AddNetworkString( "CustomPropInfo_SetCommandPrefix" )
util.AddNetworkString( "CustomPropInfo_RunCommand" )
util.AddNetworkString( HOOK_INFORM_BUDDIES )
util.AddNetworkString( HOOK_INFORM_BUDDIES_GROUP )



--[[
    inputs:
        entryName: Name of info entry to respond to.
        uniqueID: Unique string for a particular request the entry might make, as one entry could make multiple.
        func: A function( ent, ply, entryName, uniqueID ) to analyze the request, returns { ANYTHING }, OPTIONAL_NEW_COOLDOWN
        svCooldown: (optional) Cooldown to apply once request is analyzed, overriding custom_propinfo_request_cooldown_default

    Unlike with clientside entry registering, this will completely override pre-existing functions that have the same entryName and uniqueID.
    If the second return arg of func is a number OPTIONAL_NEW_COOLDOWN, then it will apply that cooldown instead of svCooldown or the global default cooldown.
--]]
function CustomPropInfo.RegisterRequestResponse( entryName, uniqueID, func, svCooldown )
    if type( entryName ) ~= "string" then
        ErrorNoHaltWithStack( "PropInfo entry names must be a string." )

        return false
    end

    if type( uniqueID ) ~= "string" then
        ErrorNoHaltWithStack( "PropInfo request responses need a uniqueID string to identify different kinds of requests for the same info entry." )

        return false
    end

    if type( func ) ~= "function" then
        ErrorNoHaltWithStack( "PropInfo request responses need a function of the form\n   function( ent, ply, entryName, uniqueID )  return  { ANYTHING }, OPTIONAL_NEW_COOLDOWN  end" )

        return false
    end

    local responses = requestResponses[entryName]

    if not responses then
        responses = {}
        requestResponses[entryName] = responses
    end

    responses[uniqueID] = {
        Func = func,
        Cooldown = svCooldown,
        CoolTimes = {},
    }

    return true
end

hook.Add( "CPPIFriendsChanged", HOOK_INFORM_BUDDIES, function( ply, buddies )
    if not IsValid( ply ) then return end

    net.Start( HOOK_INFORM_BUDDIES )
    net.WriteEntity( ply )
    net.WriteTable( type( buddies ) == "table" and buddies or {} )
    net.Broadcast()
end )

hook.Add( "PlayerInitialSpawn", HOOK_INFORM_BUDDIES, function( ply )
    if not CPPI then return end

    hook.Add( "SetupMove", HOOK_INFORM_BUDDIES, function( ply2, _, cmd )
        if ply ~= ply2 or cmd:IsForced() then return end

        hook.Remove( "SetupMove", HOOK_INFORM_BUDDIES )

        timer.Simple( 10, function()
            local plyBuddies = ply:CPPIGetFriends()
            local plys = player.GetHumans()
            local buddyGroups = {}

            plyBuddies = type( plyBuddies ) == "table" and plyBuddies or {}

            net.Start( HOOK_INFORM_BUDDIES )
            net.WriteEntity( ply )
            net.WriteTable( plyBuddies )
            net.Broadcast()

            for i = 1, #plys do
                local otherPly = plys[i]

                if otherPly ~= ply then
                    local buddies = otherPly:CPPIGetFriends()
                    buddies = type( buddies ) == "table" and buddies or {}

                    buddyGroups[otherPly] = buddies
                end
            end

            net.Start( HOOK_INFORM_BUDDIES_GROUP )
            net.WriteTable( buddyGroups )
            net.Send( ply )
        end )
    end )
end )

hook.Add( "PlayerSay", "CustomPropInfo_RunCommand", function( ply, msg )
    local prefix = infoPrefixes[ply] or "/pi"

    if not string.StartWith( msg, prefix ) then return end

    net.Start( "CustomPropInfo_RunCommand" )
    net.WriteString( msg )
    net.Send( ply )

    return ""
end )

net.Receive( "CustomPropInfo_SetCommandPrefix", function( _, ply )
    if not IsValid( ply ) then return end

    local prefix = net.ReadString()

    if not prefix or prefix == "" or string.match( prefix, "[%s]" ) then
        prefix = "/pi"
    end

    infoPrefixes[ply] = prefix
end )

net.Receive( "CustomPropInfo_RequestInfo", function( _, ply )
    if not IsValid( ply ) then return end

    local ent = net.ReadEntity()
    local entryName = net.ReadString()
    local uniqueID = net.ReadString()

    local response = ( requestResponses[entryName] or {} )[uniqueID]

    if not response then return end

    local coolTimes = response.CoolTimes
    local coolTime = coolTimes[ply]
    local curTime = SysTime()

    if coolTime and coolTime > curTime then return end

    local result, cooldown = response.Func( ent, ply, entryName, uniqueID )

    coolTimes[ply] = curTime + ( cooldown or response.Cooldown or REQUEST_COOLDOWN:GetFloat() or 0.3 )

    net.Start( "CustomPropInfo_RequestResponse", true )
    net.WriteString( entryName )
    net.WriteString( uniqueID )
    net.WriteTable( result or {} )
    net.Send( ply )
end )



--------------------------------------------------------------------------------
-- Default Request Responses:



local registerRequestResponse = CustomPropInfo.RegisterRequestResponse


registerRequestResponse( "Mass: ", "CPI_BaseRequest", function( ent )
    if not IsValid( ent ) then return end

    local physObj = ent:GetPhysicsObject()

    if not IsValid( physObj ) then
        return {
            Invalid = "(invalid physObj)"
        }
    end

    return {
        Mass = physObj:GetMass() or 0
    }
end )

registerRequestResponse( "Frozen: ", "CPI_BaseRequest", function( ent )
    if not IsValid( ent ) then return end

    local physObj = ent:GetPhysicsObject()

    if not IsValid( physObj ) then
        return {
            Invalid = "(invalid physObj)"
        }
    end

    return {
        Frozen = not physObj:IsMotionEnabled()
    }
end )
