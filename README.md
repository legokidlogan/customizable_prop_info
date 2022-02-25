# customizable_prop_info
Prop Info for Garry's Mod

Highly customizable for both the client and the server. \
Custom info entries can be made and pre-existing ones can be modified. \
All clientside settings can be found in the spawnmenu options tab.


## Server Convars

| Convar | Description | Default |
| :---: | :---: | :---: |
| custom_propinfo_request_cooldown_default | Sets the default serverside cooldown for CPI info requests. | 0.3 |
| custom_propinfo_welcome_message_enabled | Whether or not new users will receive a welcome message on their first-ever join. | 1 |
| custom_propinfo_enabled_default | Whether or not new users who've never used this addon before should have CPI enabled by default. Set to 0 if new users are easily bothered by large HUD changes. | 1 |

## Client Convars

| Convar | Description | Default |
| :---: | :---: | :---: |
| custom_propinfo_enabled | Enables CustomPropInfo. | 1 |
| custom_propinfo_directions | Enables directional arrows for entities. Red for forward, green for right, blue for up. | 0 |
| custom_propinfo_directions_mode | Changes display mode for the green line of directional arrows. 0 = 'right' direction, 1 = y-axis direction for local coordinates. | 0 |
| custom_propinfo_tool_only | Makes CPI only display while you are actively holding the physgun or toolgun. | 1 |
| custom_propinfo_hide_seat | Hide CPI while sitting in a seat. | 1 |
| custom_propinfo_round | How many decimal points to round numbers to. | 3 |
| custom_propinfo_update_interval | The time, in seconds, between each update for CPI. | 0.5 |
| custom_propinfo_outline | Enables an outline for text readability. | 0 |
| custom_propinfo_directions_length | The length of CPI directional arrows. | 10 |
| custom_propinfo_directions_length_end | The back-facing length of CPI directional arrows. | 3 |
| custom_propinfo_background_value | The brightness of the CPI display background. | 40 |
| custom_propinfo_background_alpha | The opacity of the CPI display background. | 80 |
| custom_propinfo_text_alpha | The opacity of the CPI display text. | 255 |
| custom_propinfo_pos_x | X position of the leftmost corner of the CPI display, as a fraction of the screen. 0 is the left, 1 is the right. | 0 |
| custom_propinfo_pos_y | Y position of the leftmost corner of the CPI display, as a fraction of the screen. 0 is the top, 1 is the bottom. | 0.51 |
| custom_propinfo_font_size | Font size for the CPI display, in pixels. Determines overall display size. | 21 |
| custom_propinfo_min_width | Minimum width of the CPI display background, scaled by the font size. | 20 |
| custom_propinfo_command_prefix | The command prefix used for CPI chat commands. Cannot include whitespace characters. Max character length is 20. | /pi |


## Misc.

- Colors:
  - All CPI colors can be found in `CustomPropInfo.Colors`, make sure to use them if you add or edit info entries.
  - CPI modifies nearly all of its colors dynamically when the client changes their background/text alpha settings, be cautious when using its colors for something other than info entries/commands.
    - It modifies the alpha directly without making a new color, so you *could* store the colors locally if you want, to avoid extra table lookups. However, it is still recommended to access the colors via table lookup anyway, as a custom script or addon could potentially override it with a new color object entirely.
  - `CustomPropInfo.MakeOpaque( color )` and `CustomPropInfo.MakeTransparent( color )` return a copy of a color with its alpha set to 255 and `displayTextAlpha` respectively.
  - Colors with a name starting with `Solid` will never have their alpha modified by `displayTextAlpha`
  - If you want to change the color palette or expand it with additional colors for your server, simply modify/add to the `CustomPropInfo.Colors` table on the client.
    - You could even add a config menu for the client to tweak the colors themselves if desired. CPI doesn't do that itself because it would quickly become cumbersome and bloat up the option panel.
  - All base-addon colors can be found in `cl_entries.lua`


## Global Functions

Client:
- `CustomPropInfo.RegisterInfoEntry( name, func, settings )`
  - Adds a new info type to the prop info list.
  - `name` - Name of info entry to add to the list.
  - `func` - A `function( ent )` that returns `nil` to not display the entry, or returns `{ LIST_OF_STRINGS, LIST_OF_COLORS, OPTIONAL_EXTRA_INFO }`
    - The resulting table will be wrapped into a different format, listed further below.
  - `settings` - A table containing the following parameters:
    - `CallNames = TABLE` - A list of strings which will be used to call the function via chat command for printing out to chat, taking the standard return format.
      - Only the first in the list will be displayed in the help command.
    - `OptionText = STRING` - A short string to attach to the toggle checkbox in the option menu for this entry, like a mini-description.
    - `NoShow = BOOL` - Never show on the HUD display, used for adding special CPI commands. This will also hide it from the entry toggle list.
    - `DefaultEnable = BOOL` - Should this entry be on by default?
    - `BlockToggle = BOOL` - Prevent the user from enabling/disabling this entry.
    - `CanCallWithoutEnt = BOOL` - Can the entry function be called without a valid entity? Only applies to when called via chat command.
  - If `func` returns a table, it will be wrapped to match the following format:
    - `Count = LIST_LENGTH`
    - `Strings = LIST_OF_STRINGS`
    - `Colors = LIST_OF_COLORS`
    - `ExtraInfo = OPTIONAL_EXTRA_INFO` - Any type of data (preferably a string-indexed table for modularity) to pass along useful info for recursive calls in `CustomPropInfo.AlterInfoEntry()`
  - If `func` only returns one string (or other non-nil, non-table value), it will get auto-converted to the table format and use the default text color, to make adding basic entries simpler.
  - Unless `CanCallWithoutEnt` is true, you do not need to check for `IsValid( ent )`, as prop info is only acquired on valid entities. This also means that it will never acquire info on the world.
- `CustomPropInfo.AlterInfoEntry( name, func )`
  - Wraps a pre-existing info entry to append, remove, or otherwise modify its output.
  - Behaves similarly to `CustomPropInfo.RegisterInfoEntry()`, except the arguments to `func` are `function( ent, oldResult )`
    - `oldResult` is in the wrapped format described above. If the original result is `nil`, it'll be replaced with a formatted table with `Count = 0`.
  - This is capable of wrapping for several layers. If you want to forcefully cut out some pre-existing wraps, `CustomPropInfo.Entries[INDEX].FuncOriginal` gives the base-level function.
    - The index of an entry can be obtained with `CustomPropInfo.EntryLookup[entryName]`
    - If one of the older functions in the chain returns a result containing `ExtraInfo`, you can access it with `oldResult.ExtraInfo`
  - `ply` - Only required on server.
- `CustomPropInfo.AppendInfoEntry( name, func )`
  - Uses `CustomPropInfo.AlterInfoEntry()` to append data to the end of the current entry result.
  - Preferred return format for `func` is `nil` OR `{ Count = LIST_LENGTH, Strings = LIST_OF_STRINGS, Colors = LIST_OF_COLORS }`
  - Other accepted return formats:
    - `{ LIST_OF_STRINGS, LIST_OF_COLORS }`
    - `{ LIST_OF_STRINGS }, { LIST_OF_COLORS }`
    - `STRING, COLOR`
    - `STRING`
- `CustomPropInfo.RequestServerInfo( ent, entryName, uniqueID, clCooldown )`
  - Sends a request to the server to acquire some info that isn't readily available to the client realm.
  - For each entry, there could be multiple different special requests made, so each request should be given a `uniqueID` string to identify it between other requests.
  - On the server's end, use `CustomPropInfo.RegisterRequestResponse()` to create a response to the specific info request.
  - Will return whatever the most recently-received data was, which gets stored into a cache, or `nil` if nothing is currently cached.
  - Will return false if the server doesn't have this addon installed or if the request is invalid (with the second argument being the corresponding message fail message)
    - However, such a scenario can only occur with a hacked client or on servers with `sv_allowcslua 1`, as otherwise the client will never be able to use this addon on dedicated servers.
  - `clCooldown` - Applies an optional cooldown on the client's end, in case it's data that doesn't update often or is more intensive to request, reducing the amount of net messages.
    - Of course, this doesn't stop hacked clients from spamming the net message endlessly, so the server's end still has its own cooldown system.
- `CustomPropInfo.PlayerTrusts( owner, ply )`
  - Does `owner` trust `ply` via CPPI? (Whatever happens to be the server's prop protection system)
  - Returns:
    - `false` - No.
    - `1` - Yes.
    - `2` - Yes, by technicality. `owner == ply` or `ply` is a superadmin.
- `CustomPropInfo.GetTrustColor( owner, trustState )`
  - Returns blue if `owner` trusts by technicality, red/green for (not) trusting, choosing soft shades if `owner == LocalPlayer()`
  - `trustState` should be whatever gets returned by `CustomPropInfo.PlayerTrusts( owner, ply )`
- `CustomPropInfo.GetPropInfo( ent )`
  - Runs all enabled entry functions on `ent` and stores it for rendering.
  - If you remove/override the `CustomPropInfo_EntityCheck` timer, this will let you select a different entity to inspect in case the player's eye trace isn't sufficient.
  - Useful for remote cameras and trace filtering.

Server:
- `CustomPropInfo.RegisterRequestResponse( entryName, uniqueID, func, svCooldown )`
  - `entryName` - Name of info entry to respond to.
  - `uniqueID` - Unique string for a particular request the entry might make, as one entry could make multiple.
  - `func` - A `function( ent, ply, entryName, uniqueID )` to analyze the request, returns `{ ANYTHING }, OPTIONAL_NEW_COOLDOWN`
  - `svCooldown` - (optional) Cooldown to apply once request is analyzed, overriding `custom_propinfo_request_cooldown_default`
  - Unlike with clientside entry registering, this will **completely override** pre-existing functions that have the same `entryName` and `uniqueID`.
  - If the second return arg of func is a number `OPTIONAL_NEW_COOLDOWN`, then it will apply that cooldown instead of `svCooldown` or the global default cooldown.
