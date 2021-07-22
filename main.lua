local options = require 'mp.options'
local msg = require 'mp.msg'
local gameSDK = require 'lua-discordGameSDK'

local app

--[=====[
  Main Options.
  Configure these as you wish. These will be overwritten if any
  config file exists at script-opts/mpvcord.conf, and even those
  are overwritten if any command-line arguments are passed, e.g.
  --script-opts=mpvcord-activate=yes

  periodic_timer: How often the script communicates with Game SDK.
                  Recommended 1 <= x <= 15.
  playlist_info:  Whether to display the playlist information.
                  (yes | no)
  loop_info:      Whether to display your loop status.
                  (yes | no)
  mpv_version:    Whether to show the mpv version.
                  (yes | no)
  active:         Whether to activate script on launch.
                  (yes | no)
  key_toggle:     Key to toggle script. Can also be set in input.conf.
--]=====]

local o = {
  periodic_timer = 2,
  playlist_info = "yes",
  loop_info = "yes",
  mpv_version = "yes",
  active = "no",
  key_toggle = "D"
}

client_id = 798647747678568488LL



--[=====[
  Setup.
  Reads option files, sets keybinding, and initialises Discord.
--]=====]

options.read_options(o)

local script_info = {
  name = mp.get_script_name(),
  description = "Discord Rich Presence integration for mpv.",
  upstream = "https://github.com/yutotakano/mpv-discord",
  forked_from = "https://github.com/cniw/mpv-discordRPC",
  version = "2.0.0",
}

msg.info(script_info.description)

msg.verbose("Running on options:")
msg.verbose(string.format("periodic_timer : %s", o.periodic_timer))
msg.verbose(string.format("playlist_info  : %s", o.playlist_info))
msg.verbose(string.format("loop_info      : %s", o.loop_info))
msg.verbose(string.format("mpv_version    : %s", o.mpv_version))
msg.verbose(string.format("active         : %s", o.active))
msg.verbose(string.format("key_toggle     : %s", o.key_toggle))
msg.verbose(string.format("client_id      : %s", client_id))

local mpv_version = mp.get_property("mpv-version"):sub(5)

local startTime = os.time(os.date("*t"))

-- Keybinding
mp.add_key_binding(o.key_toggle, "active-toggle", function ()
  o.active = o.active == "yes" and "no" or "yes"
  local status = o.active == "yes" and "active" or "inactive"
  mp.osd_message(("[%s] Status: %s"):format(script_info.name, status))
  msg.verbose(string.format("Status: %s", status))
end, {
  repeatable = false
})

-- Initialise Discord Game SDK and keep its instance
discord_instance = gameSDK.initialize(client_id)



--[=====[
  Main loop.
  Called every `o.periodic_timer`. Parses various mpv values, formats
  them nicely, and sends it off to the game SDK.
--]=====]

local function main()

  -- Return early if discord game sdk doesn't need to run
  if o.active == "no" then
    msg.verbose("Calling Game SDK...")
    discord_instance = gameSDK.clearPresence(discord_instance)
    return
  end

  -- Default values for presence.
  local presence = {
    state = "", -- Second line
    details = "", -- Third line
    start_time = startTime, -- Epoch
    end_time = startTime + 60,
    large_image = "", -- Image key
    large_text = "",
    small_image = "", -- Image key
    small_text = "",
    party_id = "",
    party_size = 0,
    party_max = 0,
    match_secret = "", -- Not exactly sure how to use them >.<
    join_secret = "",
    spectate_secret = ""
  }

  -- Set values according to player state
  local idle = mp.get_property_bool("idle-active")
  local coreIdle = mp.get_property_bool("core-idle")
  local pausedFC = mp.get_property_bool("paused-for-cache")
  local pause = mp.get_property_bool("pause")
  local play = coreIdle and false or true

  local timeNow = os.time(os.date("*t"))
  local timeRemaining = os.time(os.date("*t", mp.get_property("playtime-remaining")))
  local timeUp = timeNow + timeRemaining

  presence["start_time"] = nil
  presence["end_time"] = timeUp

  if idle then
    presence["state"] = "(Idle)"
    presence["small_image"] = "player_stop"
    presence["small_text"] = "Idle"
    presence["start_time"] = math.floor(startTime)
    presence["end_time"] = nil
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


  --[=====[
    Conditionals.
    Here is where the customisability will shine! Set various presence values
    using the metadata available. See https://mpv.io/manual/master#property-list
    for properties you can use by mp.get_property()

    By default:
      - The media title is set as the detail, plus any artist/album if it exists
      - If the path matches any specific URL scheme, it sets the image and text
        accordingly. Most of it is for my personal use.
  --]=====]

  local file_path = mp.get_property("path") -- URL, or file path
  local media_title = mp.get_property("media-title")
  local chapter_title = mp.get_property("chapter-metadata/by-key/Title")
  local metadata_title = mp.get_property_native("metadata/by-key/Title")
  local metadata_artist = mp.get_property_native("metadata/by-key/Artist")
  local metadata_album = mp.get_property_native("metadata/by-key/Album")

  presence["details"] = media_title
  if metadata_title ~= nil then
    presence["details"] = metadata_title
  end
  if chapter_title ~= nil then
    presence["details"] = chapter_title
  end

  if file_path ~= nil then
    -- checking protocol: http, https
    if string.match(file_path, "^https?://.*") ~= nil then
      presence["large_image"] = "internet"
      presence["large_text"] = "Streaming"
    end

    if string.match(media_title, "Informatics") ~= nil then
      presence["large_image"] = "informatics_logo"
      presence["large_text"] = "UoE Informatics"

    elseif string.match(media_title, "Star Wars") ~= nil then
      presence["large_image"] = "starwars"
      presence["large_text"] = "Star Wars"

    elseif string.match(file_path, "r1%-01%.m3u8") ~= nil then
      presence["large_image"] = "radio"
      presence["large_text"] = "Listening to NHK R1"
      if media_title ~= "r1%-01%.m3u8" then
        lines = {}
        for s in media_title:gmatch("[^\r\n]+") do
          table.insert(lines, s)
        end
        presence["details"] = lines[1] and lines[1] or ""
        presence["state"] = lines[2] and lines[2] or ""
      end
      presence["start_time"] = math.floor(startTime)
      presence["end_time"] = nil

    elseif string.match(file_path, "www.youtube.com/watch%?v=([a-zA-Z0-9-_]+)&?.*$") ~= nil
        or string.match(file_path, "youtu.be/([a-zA-Z0-9-_]+)&?.*$") ~= nil then
      presence["large_image"] = "youtube"
      presence["large_text"] = "YouTube"

    elseif string.match(file_path, "urn:bbc:pips:service:bbc_one") ~= nil then
      presence["large_image"] = "bbc_one"
      presence["large_text"] = "BBC One"
      if media_title == "main.m3u8" then
        presence["details"] = "Watching BBC One"
        presence["state"] = "(likely for the Olympics)"
      else
        lines = {}
        for s in media_title:gmatch("[^\r\n]+") do
          table.insert(lines, s)
        end
        presence["details"] = lines[1] and lines[1] or ""
        presence["state"] = lines[2] and lines[2] or ""
      end
      presence["start_time"] = math.floor(startTime)
      presence["end_time"] = nil

    end

    if metadata_artist ~= nil then
      presence["state"] = ("by %s"):format(metadata_artist)
    end

    if metadata_album ~= nil then
      presence["details"] = ("%s //\n(%s)"):format(presence["details"], metadata_album)
    end

    if chapter_title ~= nil
      and (string.match(file_path, "www.youtube.com/watch%?v=([a-zA-Z0-9-_]+)&?.*$") ~= nil
        or string.match(file_path, "youtu.be/([a-zA-Z0-9-_]+)&?.*$") ~= nil) then
        -- Youtube, and with chapters.
        presence["large_text"] = media_title

    end
  end

  if presence["details"] == nil then
    presence["details"] = "No file"
  end

  -- set game activity
  presence["details"] = presence["details"]:len() > 127 and presence["details"]:sub(1, 127) or presence["details"]
  presence["state"] = presence["state"]:len() > 127 and presence["state"]:sub(1, 127) or presence["state"]
  msg.verbose("Calling Game SDK...")
  discord_instance = gameSDK.updatePresence(discord_instance, presence)
end


-- Call main() once, and keep it calling periodically.
main()
mp.add_periodic_timer(o.periodic_timer, main)
