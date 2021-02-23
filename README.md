# mpvcord

A rewrite/fork of [cniw/mpv-discordRPC](https://github.com/cniw/mpv-discordRPC) that uses the Discord Game SDK instead of the deprecated discord-RPC.

The script comes with some predefined conditionals, but it is up to users to customise how they want their activity to look depending on various media. You will need to [create a Discord developer client ID](https://discord.com/developers/) if you want to use your own images.

## Examples

These are some ideas of how to customise the script:

| | |
| ----------- | ----------- |
| Mostly default, with custom large image | ![Image](https://i.imgur.com/51PwuGe.png) |
| Custom large image, custom 2nd line, custom 3rd line, custom time | ![Image](https://i.imgur.com/KW7e9YP.png) |
| Potential for even more customisation using other scripts and APIs.<br>(Showing current radio programme with [mpv-radio-title-script](https://github.com/olivierlemoal/mpv-radio-title-script/)) | ![Image](https://i.imgur.com/y72ZUUP.png) |

## Installation

It is assumed that the user of this script has basic Lua knowledge (just the syntax is fine), and knows their way around their file system.

1. Download the Game SDK from [the official page](https://discord.com/developers/docs/game-sdk/sdk-starter-guide). This unfortunately cannot be included in this repository due to legal constraints.
2. In the `lib/` folder in the ZIP, go into your distribution `x86` or `x86_64`, and copy all library files inside it (or just the necessary ones if you're sure). Paste them into mpv's installation directory. This is *not* your user configuration directory, but where the mpv binary lies (e.g. `C:/Program Files/mpv/discord_game_sdk.dll`).
3. Download or clone this repository and place both main.lua and the SDK lua files into `scripts/mpvcord` of your mpv configuration directory. E.g. `%appdata%/mpv/scripts/mpvcord/main.lua`.
4. Skim through main.lua and customise any of the code as you want. The SDK lua file needs no configuration.
5. Optionally, create a `script-opts/mpvcord.conf` file in the mpv configuration directory to control options from a separate file. An example has been included in this repo.

It can take around 10-15 seconds since mpv starts for Discord to show the status on the client.

## Uninstallation

1. Delete the relevant directory inside your `scripts` folder, and any SDK library files in your mpv installation folder.
