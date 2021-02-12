local ffi = require "ffi"
local discordGameSDKlib = ffi.load("discord-rpc")

ffi.cdef[[
typedef int64_t DiscordTimestamp;
typedef int64_t DiscordSnowflake;
typedef DiscordSnowflake DiscordUserId;

enum EDiscordActivityType {
    DiscordActivityType_Playing,
    DiscordActivityType_Streaming,
    DiscordActivityType_Listening,
    DiscordActivityType_Watching,
};

enum EDiscordStatus {
    DiscordStatus_Offline = 0,
    DiscordStatus_Online = 1,
    DiscordStatus_Idle = 2,
    DiscordStatus_DoNotDisturb = 3,
};

typedef struct DiscordUser {
    DiscordUserId id;
    char* username; /* max 256 bytes */
    char* discriminator; /* max 8 bytes */
    char* avatar; /* max 128 bytes */
    bool bot;
};

typedef struct DiscordActivityTimestamps {
    DiscordTimestamp start;
    DiscordTimestamp end;
} DiscordActivityTimestamps;

typedef struct DiscordActivityAssets {
    const char* large_image; /* max 128 bytes */
    const char* large_text; /* max 128 bytes */
    const char* small_image; /* max 128 bytes */
    const char* small_text; /* max 128 bytes */
} DiscordActivityAssets;

typedef struct DiscordPartySize {
    int32_t current_size;
    int32_t max_size;
} DiscordPartySize;

typedef struct DiscordActivityParty {
    const char* id; /* max 128 bytes */
    struct DiscordPartySize size;
} DiscordActivityParty;

typedef struct DiscordActivitySecrets {
    const char* match; /* max 128 bytes */
    const char* join; /* max 128 bytes */
    const char* spectate; /* max 128 bytes */
} DiscordActivitySecrets;

typedef struct DiscordActivity {
    enum EDiscordActivityType type;
    int64_t application_id;
    const char* name; /* max 128 bytes */
    const char* state; /* max 128 bytes */
    const char* details; /* max 128 bytes */
    struct DiscordActivityTimestamps timestamps;
    struct DiscordActivityAssets assets;
    struct DiscordActivityParty party;
    struct DiscordActivitySecrets secrets;
    bool instance;
} DiscordActivity;

typedef struct DiscordPresence {
    enum EDiscordStatus status;
    struct DiscordActivity activity;
} DiscordPresence;

typedef struct IDiscordActivityManager* (*get_activity_manager)(struct IDiscordCore* core);
]]

-- typedef void (*readyPtr)(const DiscordUser* request);
-- typedef void (*disconnectedPtr)(int errorCode, const char* message);
-- typedef void (*erroredPtr)(int errorCode, const char* message);
-- typedef void (*joinGamePtr)(const char* joinSecret);
-- typedef void (*spectateGamePtr)(const char* spectateSecret);
-- typedef void (*joinRequestPtr)(const DiscordUser* request);

-- typedef struct DiscordEventHandlers {
--     readyPtr ready;
--     disconnectedPtr disconnected;
--     erroredPtr errored;
--     joinGamePtr joinGame;
--     spectateGamePtr spectateGame;
--     joinRequestPtr joinRequest;
-- } DiscordEventHandlers;

-- void Discord_Initialize(const char* applicationId,
--                         DiscordEventHandlers* handlers,
--                         int autoRegister,
--                         const char* optionalSteamId);

-- void Discord_Shutdown(void);

-- void Discord_RunCallbacks(void);

-- void Discord_UpdatePresence(const DiscordRichPresence* presence);

-- void Discord_ClearPresence(void);

-- void Discord_Respond(const char* userid, int reply);

-- void Discord_UpdateHandlers(DiscordEventHandlers* handlers);
-- ]]

local discordGameSDK = {} -- module table

-- proxy to detect garbage collection of the module
discordGameSDK.gcDummy = newproxy(true)

local function unpackDiscordUser(request)
    return ffi.string(request.userId), ffi.string(request.username),
        ffi.string(request.discriminator), ffi.string(request.avatar)
end

-- callback proxies
-- note: callbacks are not JIT compiled (= SLOW), try to avoid doing performance critical tasks in them
-- luajit.org/ext_ffi_semantics.html
local ready_proxy = ffi.cast("readyPtr", function(request)
    if discordGameSDK.ready then
        discordGameSDK.ready(unpackDiscordUser(request))
    end
end)

local disconnected_proxy = ffi.cast("disconnectedPtr", function(errorCode, message)
    if discordGameSDK.disconnected then
        discordGameSDK.disconnected(errorCode, ffi.string(message))
    end
end)

local errored_proxy = ffi.cast("erroredPtr", function(errorCode, message)
    if discordGameSDK.errored then
        discordGameSDK.errored(errorCode, ffi.string(message))
    end
end)

local joinGame_proxy = ffi.cast("joinGamePtr", function(joinSecret)
    if discordGameSDK.joinGame then
        discordGameSDK.joinGame(ffi.string(joinSecret))
    end
end)

local spectateGame_proxy = ffi.cast("spectateGamePtr", function(spectateSecret)
    if discordGameSDK.spectateGame then
        discordGameSDK.spectateGame(ffi.string(spectateSecret))
    end
end)
    
local joinRequest_proxy = ffi.cast("joinRequestPtr", function(request)
    if discordGameSDK.joinRequest then
        discordGameSDK.joinRequest(unpackDiscordUser(request))
    end
end)

-- helpers
function checkArg(arg, argType, argName, func, maybeNil)
    assert(type(arg) == argType or (maybeNil and arg == nil),
        string.format("Argument \"%s\" to function \"%s\" has to be of type \"%s\"",
            argName, func, argType))
end

function checkStrArg(arg, maxLen, argName, func, maybeNil)
    if maxLen then
        assert(type(arg) == "string" and arg:len() <= maxLen or (maybeNil and arg == nil),
            string.format("Argument \"%s\" of function \"%s\" has to be of type string with maximum length %d",
                argName, func, maxLen))
    else
        checkArg(arg, "string", argName, func, true)
    end
end

function checkIntArg(arg, maxBits, argName, func, maybeNil)
    maxBits = math.min(maxBits or 32, 52) -- lua number (double) can only store integers < 2^53
    local maxVal = 2^(maxBits-1) -- assuming signed integers, which, for now, are the only ones in use
    assert(type(arg) == "number" and math.floor(arg) == arg
        and arg < maxVal and arg >= -maxVal
        or (maybeNil and arg == nil),
        string.format("Argument \"%s\" of function \"%s\" has to be a whole number <= %d",
            argName, func, maxVal))
end

-- function wrappers
function discordGameSDK.initialize(applicationId, autoRegister, optionalSteamId)
    local func = "discordGameSDK.Initialize"
    checkStrArg(applicationId, nil, "applicationId", func)
    checkArg(autoRegister, "boolean", "autoRegister", func)
    if optionalSteamId ~= nil then
        checkStrArg(optionalSteamId, nil, "optionalSteamId", func)
    end

    local eventHandlers = ffi.new("struct DiscordEventHandlers")
    eventHandlers.ready = ready_proxy
    eventHandlers.disconnected = disconnected_proxy
    eventHandlers.errored = errored_proxy
    eventHandlers.joinGame = joinGame_proxy
    eventHandlers.spectateGame = spectateGame_proxy
    eventHandlers.joinRequest = joinRequest_proxy

    discordGameSDKlib.Discord_Initialize(applicationId, eventHandlers,
        autoRegister and 1 or 0, optionalSteamId)
end

function discordGameSDK.shutdown()
    discordGameSDKlib.Discord_Shutdown()
end

function discordGameSDK.runCallbacks()
    discordGameSDKlib.Discord_RunCallbacks()
end
-- http://luajit.org/ext_ffi_semantics.html#callback :
-- It is not allowed, to let an FFI call into a C function (runCallbacks)
-- get JIT-compiled, which in turn calls a callback, calling into Lua again (e.g. discordGameSDK.ready).
-- Usually this attempt is caught by the interpreter first and the C function
-- is blacklisted for compilation.
-- solution:
-- "Then you'll need to manually turn off JIT-compilation with jit.off() for
-- the surrounding Lua function that invokes such a message polling function."
jit.off(discordGameSDK.runCallbacks)

function discordGameSDK.updatePresence(presence)
    local func = "discordGameSDK.updatePresence"
    checkArg(presence, "table", "presence", func)

    -- -1 for string length because of 0-termination
    checkStrArg(presence.state, 127, "presence.state", func, true)
    checkStrArg(presence.details, 127, "presence.details", func, true)

    checkIntArg(presence.startTimestamp, 64, "presence.startTimestamp", func, true)
    checkIntArg(presence.endTimestamp, 64, "presence.endTimestamp", func, true)

    checkStrArg(presence.largeImageKey, 31, "presence.largeImageKey", func, true)
    checkStrArg(presence.largeImageText, 127, "presence.largeImageText", func, true)
    checkStrArg(presence.smallImageKey, 31, "presence.smallImageKey", func, true)
    checkStrArg(presence.smallImageText, 127, "presence.smallImageText", func, true)
    checkStrArg(presence.partyId, 127, "presence.partyId", func, true)

    checkIntArg(presence.partySize, 32, "presence.partySize", func, true)
    checkIntArg(presence.partyMax, 32, "presence.partyMax", func, true)

    checkStrArg(presence.matchSecret, 127, "presence.matchSecret", func, true)
    checkStrArg(presence.joinSecret, 127, "presence.joinSecret", func, true)
    checkStrArg(presence.spectateSecret, 127, "presence.spectateSecret", func, true)

    checkIntArg(presence.instance, 8, "presence.instance", func, true)

    local cpresence = ffi.new("struct DiscordRichPresence")
    cpresence.state = presence.state
    cpresence.details = presence.details
    cpresence.startTimestamp = presence.startTimestamp or 0
    cpresence.endTimestamp = presence.endTimestamp or 0
    cpresence.largeImageKey = presence.largeImageKey
    cpresence.largeImageText = presence.largeImageText
    cpresence.smallImageKey = presence.smallImageKey
    cpresence.smallImageText = presence.smallImageText
    cpresence.partyId = presence.partyId
    cpresence.partySize = presence.partySize or 0
    cpresence.partyMax = presence.partyMax or 0
    cpresence.matchSecret = presence.matchSecret
    cpresence.joinSecret = presence.joinSecret
    cpresence.spectateSecret = presence.spectateSecret
    cpresence.instance = presence.instance or 0

    discordGameSDKlib.Discord_UpdatePresence(cpresence)
end

function discordGameSDK.clearPresence()
    discordGameSDKlib.Discord_ClearPresence()
end

local replyMap = {
    no = 0,
    yes = 1,
    ignore = 2
}

-- maybe let reply take ints too (0, 1, 2) and add constants to the module
function discordGameSDK.respond(userId, reply)
    checkStrArg(userId, nil, "userId", "discordGameSDK.respond")
    assert(replyMap[reply], "Argument 'reply' to discordGameSDK.respond has to be one of \"yes\", \"no\" or \"ignore\"")
    discordGameSDKlib.Discord_Respond(userId, replyMap[reply])
end

-- garbage collection callback
getmetatable(discordGameSDK.gcDummy).__gc = function()
    discordGameSDK.shutdown()
    ready_proxy:free()
    disconnected_proxy:free()
    errored_proxy:free()
    joinGame_proxy:free()
    spectateGame_proxy:free()
    joinRequest_proxy:free()
end

return discordGameSDK
