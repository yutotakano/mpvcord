local options = require 'mp.options'
local msg = require 'mp.msg'
local gameSDK = require 'lua-discordGameSDK'

local app

-- set [options]
local o = {
	rpc_wrapper = "lua-discordGameSDK",
	periodic_timer = 10,
	-- Recommendation value, to set `periodic_timer`:
	-- value >= 1 second, if use lua-discordRPC,
	-- value <= 15 second, because discord-rpc updates every 15 seconds.
	playlist_info = "yes",
	-- Valid value to set `playlist_info`: (yes|no)
	loop_info = "yes",
	-- Valid value to set `loop_info`: (yes|no)
	cover_art = "yes",
	-- Valid value to set `cover_art`: (yes|no)
	mpv_version = "yes",
	-- Valid value to set `mpv_version`: (yes|no)
	active = "no",
	-- Set Discord RPC active automatically when mpv started.
	-- Valid value to `set_active`: (yes|no)
	key_toggle = "D",
	-- Key for toggle active/inactive the Discord RPC.
	-- Valid value to set `key_toggle`: same as valid value for mpv key binding.
	-- You also can set it in input.conf by adding this next line (without double quote).
	-- "D script-binding mpv_discordRPC/active-toggle"
}
options.read_options(o) -- added identifier

-- set `script_info`
local script_info = {
	name = mp.get_script_name(),
	description = "Discord Rich Presence integration for mpv.",
	upstream = "https://github.com/yutotakano/mpv-discord",
	forked_from = "https://github.com/cniw/mpv-discordRPC",
	version = "2.0.0",
}

-- set `mpv_version`
local mpv_version = mp.get_property("mpv-version"):sub(5)

-- set `startTime`
local startTime = os.time(os.date("*t"))

-- local client = baseclient.connect()
local function main()
	-- Default values
	local presence = {
		-- pid = 9999,
		-- state = "Second line",
		-- details = "Third line",
		-- start = startTime,
		-- end_time = startTime + 60,
		-- large_image = "",
		-- large_text = "",
		-- small_image = "",
		-- small_text = "",
		-- party_id = "",
		-- party_size = 0,
		-- party_max = 0
		-- join = "",
		-- spectate = "",
		-- match = "",
		-- buttons = {},
		-- instance = false
	}

	-- Set images
	local idle = mp.get_property_bool("idle-active")
	local coreIdle = mp.get_property_bool("core-idle")
	local pausedFC = mp.get_property_bool("paused-for-cache")
	local pause = mp.get_property_bool("pause")
	local play = coreIdle and false or true
	if idle then
		presence["state"] = "(Idle)"
		presence["small_image"] = "player_stop"
		presence["small_text"] = "Idle"
	elseif pausedFC then
		presence["state"] = ""
		presence["small_image"] = "player_pause"
		presence["small_text"] = "Buffering"
	elseif pause then
		presence["state"] = "(Paused)"
		presence["small_image"] = "player_pause"
		presence["small_text"] = "Paused"
	elseif play then
		presence["state"] = "(Playing at " .. mp.get_property_native("speed") .. "x)"
		presence["small_image"] = "player_play"
		presence["small_text"] = "Playing"
	end

	
	if not idle then
		-- set `playlist_info`
		local playlist = ""
		if o.playlist_info == "yes" then
			playlist = (" - Playlist: [%s/%s]"):format(mp.get_property("playlist-pos-1"), mp.get_property("playlist-count"))
		end
		-- set `loop_info`
		local loop = ""
		if o.loop_info == "yes" then
			local loopFile = mp.get_property_bool("loop-file") == false and "" or "file"
			local loopPlaylist = mp.get_property_bool("loop-playlist") == false and "" or "playlist"
			if loopFile ~= "" then
				if loopPlaylist ~= "" then
					loop = ("%s, %s"):format(loopFile, loopPlaylist)
				else
					loop = loopFile
				end
			elseif loopPlaylist ~= "" then
				loop = loopPlaylist
			else
				loop = "disabled"
			end
			loop = (" - Loop: %s"):format(loop)
		end
		-- state = state .. mp.get_property("options/term-status-msg")
		presence["small_text"] = ("%s%s%s"):format(presence["small_text"], playlist, loop)
	end

	-- Set information as the file name, or if it exists, artist/album names
	local url = mp.get_property("path")
	local stream = mp.get_property("stream-path")
	local mediaTitle = mp.get_property("media-title")
	local metadataTitle = mp.get_property_native("metadata/by-key/Title")
	local metadataArtist = mp.get_property_native("metadata/by-key/Artist")
	local metadataAlbum = mp.get_property_native("metadata/by-key/Album")
	
	presence["details"] = mediaTitle
	if metadataTitle ~= nil then
		presence["details"] = metadataTitle
	end
	if metadataArtist ~= nil then
		presence["details"] = ("%s\nby %s"):format(presence["details"], metadataArtist)
	end
	if metadataAlbum ~= nil then
		presence["details"] = ("%s\non %s"):format(presence["details"], metadataAlbum)
	end
	if presence["details"] == nil then
		presence["details"] = "No file"
	end

	if url ~= nil then
		-- checking protocol: http, https
		if string.match(url, "^https?://.*") ~= nil then
			presence["large_image"] = "internet"
			presence["large_text"] = "Streaming"
		end

		if string.match(mediaTitle, "Informatics") ~= nil then
			presence["large_image"] = "informatics_logo"
			presence["large_text"] = "UoE Informatics"

		elseif string.match(url, "r1%-01%.m3u8") ~= nil then
			presence["large_image"] = "radio"
			presence["large_text"] = "Radio"
			presence["details"] = "Listening to NHK R1"
			state = "" -- hide (Playing 1x) because it is unnecessary

		elseif string.match(url, "www.youtube.com/watch%?v=([a-zA-Z0-9-_]+)&?.*$") ~= nil or string.match(url, "youtu.be/([a-zA-Z0-9-_]+)&?.*$") ~= nil then
			presence["large_image"] = "youtube"
			presence["large_text"] = "YouTube"
		end
	end


	-- set time
	local timeNow = os.time(os.date("*t"))
	local timeRemaining = os.time(os.date("*t", mp.get_property("playtime-remaining")))
	local timeUp = timeNow + timeRemaining
	
	-- default
	presence["start"] = nil
	presence["end"] = timeUp

	if url ~= nil and stream == nil then
		presence["state"] = "(Loading)"
		presence["start"] = math.floor(startTime)
		presence["end"] = nil
	end

	if url ~= nil and string.match(url, "%.m3u8") ~= nil then
		presence["start"] = math.floor(startTime)
		presence["end"] = nil
	end

	if idle then
		presence["start"] = math.floor(startTime)
		presence["end"] = nil
	end

	-- set game activity
	if o.active == "yes" then
		presence.details = presence.details:len() > 127 and presence.details:sub(1, 127) or presence.details
		referencesTable = gameSDK.updatePresence(referencesTable, presence)
	else
		referencesTable = gameSDK.clearPresence(referencesTable)
	end
end

-- print script info
msg.info(string.format(script_info.description))
-- msg.info(string.format("Upstream: %s", script_info.upstream))
-- msg.info(string.format("Version: %s", script_info.version))

-- print option values
msg.verbose(string.format("periodic_timer : %s", o.periodic_timer))
msg.verbose(string.format("playlist_info  : %s", o.playlist_info))
msg.verbose(string.format("loop_info      : %s", o.loop_info))
msg.verbose(string.format("cover_art      : %s", o.cover_art))
msg.verbose(string.format("mpv_version    : %s", o.mpv_version))
msg.verbose(string.format("active         : %s", o.active))
msg.verbose(string.format("key_toggle     : %s", o.key_toggle))

-- toggling active or inactive
mp.add_key_binding(o.key_toggle, "active-toggle", function()
		o.active = o.active == "yes" and "no" or "yes"
		local status = o.active == "yes" and "active" or "inactive"
		mp.osd_message(("[%s] Status: %s"):format(script_info.name, status))
		msg.info(string.format("Status: %s", status))
	end,
	{repeatable=false})

local clientId = 798647747678568488LL
referencesTable = gameSDK.initialize(clientId)

-- run `main` function
mp.add_periodic_timer(o.periodic_timer, main)
