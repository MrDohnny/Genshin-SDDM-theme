# Genshin title UI assets

Assets in this directory were exported from the installed game's Unity block:

`GenshinImpact_Data/StreamingAssets/AssetBundles/blocks/00/09101606.blk`

The complete converted export is kept at:

`/home/dione/GenshinExtractionV2/output/title_ui_complete`

Confirmed PC title-screen controls found in the block include `BtnQuit_PC`,
`BtnRepair`, `BtnSetting`, `BtnN0tice`, `BtnLogout`, `BtnSwitchServer`,
`BtnPressStart`, and `ClickTips`.

Runtime files copied here:

- `Login_Title.ttf`: title-screen font.
- `UI_IconSmall_AddAccount.png`: add/switch account.
- `UI_IconSmall_Login.png`: HoYoverse login mark.
- `UI_IconSmall_Login_Global.png`: global login mark.
- `UI_IconSmall_Notice.png`: notices.
- `UI_IconSmall_Quit.png`: quit/power.
- `UI_IconSmall_Repair.png`: file repair.
- `UI_IconSmall_Settings.png`: settings.
- `Ani_ClickTipsLoop.anim`: exact one-second vertical prompt loop.
- `Ani_LoginMainPage_WaitingState_*.anim`: title waiting-state transitions.

The Unity audio components reference Wwise events. The common UI bank
`AudioAssets/Minimum.pck` was unpacked into 30 original Wwise samples and
decoded losslessly to WAV at:

`/home/dione/GenshinExtractionV2/output/title_audio_minimum_wav`

Those samples still need to be matched to their Wwise event IDs before they are
used by the theme. An unrelated SDK sound must not be presented as the title
screen's original sound.
