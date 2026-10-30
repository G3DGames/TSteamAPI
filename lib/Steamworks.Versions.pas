{ @abstract(Interface version strings (the *_INTERFACE_VERSION defines of the SDK).)

  These are FALLBACKS. At start-up @code(TSteamworks) scans the loaded
  redistributable and replaces the trailing number with the one that binary
  was built with (see @link(TSteamInterfaceVersions)). Only the family part
  (@code(SteamUtils), @code(STEAMAPPS_INTERFACE_VERSION), ...) has to be right
  for that lookup. The numbers match the SDK 1.65 Win64 redistributable as
  scanned on 2026-10-30 (28 families); re-check them when updating the SDK
  (the demos' "Show info" / SteamConsole list what the scan finds).

  @longCode(#
  Ptr := Steam.AcquireUserInterface(STEAMFRIENDS_INTERFACE_VERSION, 'SteamFriends');
  #) }
unit Steamworks.Versions;

{$I Steamworks.inc}

interface

const
  { SDK release this library targets. }
  STEAMWORKS_SDK_VERSION = '1.65';

  { Fallback version string of the STEAMCLIENT interface family. }
  STEAMCLIENT_INTERFACE_VERSION               = 'SteamClient023';
  { Fallback version string of the STEAMUSER interface family. }
  STEAMUSER_INTERFACE_VERSION                 = 'SteamUser023';
  { Fallback version string of the STEAMGAMESERVER interface family. }
  STEAMGAMESERVER_INTERFACE_VERSION           = 'SteamGameServer015';
  { Fallback version string of the STEAMFRIENDS interface family. }
  STEAMFRIENDS_INTERFACE_VERSION              = 'SteamFriends018';
  { Fallback version string of the STEAMUTILS interface family. }
  STEAMUTILS_INTERFACE_VERSION                = 'SteamUtils011';
  { Fallback version string of the STEAMMATCHMAKING interface family. }
  STEAMMATCHMAKING_INTERFACE_VERSION          = 'SteamMatchMaking009';
  { Fallback version string of the STEAMMATCHMAKINGSERVERS interface family. }
  STEAMMATCHMAKINGSERVERS_INTERFACE_VERSION   = 'SteamMatchMakingServers003';
  { Fallback version string of the STEAMGAMESEARCH interface family. Not found in the SDK 1.65 redistributable - the interface may have been removed. }
  STEAMGAMESEARCH_INTERFACE_VERSION           = 'SteamMatchGameSearch001';
  { Fallback version string of the STEAMPARTIES interface family. }
  STEAMPARTIES_INTERFACE_VERSION              = 'SteamParties002';
  { Fallback version string of the STEAMUSERSTATS interface family. }
  STEAMUSERSTATS_INTERFACE_VERSION            = 'STEAMUSERSTATS_INTERFACE_VERSION013';
  { Fallback version string of the STEAMGAMESERVERSTATS interface family. }
  STEAMGAMESERVERSTATS_INTERFACE_VERSION      = 'SteamGameServerStats001';
  { Fallback version string of the STEAMAPPS interface family. }
  STEAMAPPS_INTERFACE_VERSION                 = 'STEAMAPPS_INTERFACE_VERSION009';
  { Fallback version string of the STEAMNETWORKING interface family. }
  STEAMNETWORKING_INTERFACE_VERSION           = 'SteamNetworking006';
  { Fallback version string of the STEAMREMOTESTORAGE interface family. }
  STEAMREMOTESTORAGE_INTERFACE_VERSION        = 'STEAMREMOTESTORAGE_INTERFACE_VERSION016';
  { Fallback version string of the STEAMSCREENSHOTS interface family. }
  STEAMSCREENSHOTS_INTERFACE_VERSION          = 'STEAMSCREENSHOTS_INTERFACE_VERSION003';
  { Fallback version string of the STEAMMUSIC interface family. }
  STEAMMUSIC_INTERFACE_VERSION                = 'STEAMMUSIC_INTERFACE_VERSION001';
  { Fallback version string of the STEAMMUSICREMOTE interface family. Not found in the SDK 1.65 redistributable - the interface may have been removed. }
  STEAMMUSICREMOTE_INTERFACE_VERSION          = 'STEAMMUSICREMOTE_INTERFACE_VERSION001';
  { Fallback version string of the STEAMHTTP interface family. }
  STEAMHTTP_INTERFACE_VERSION                 = 'STEAMHTTP_INTERFACE_VERSION003';
  { Fallback version string of the STEAMINPUT interface family. }
  STEAMINPUT_INTERFACE_VERSION                = 'SteamInput007';
  { Fallback version string of the STEAMCONTROLLER interface family. }
  STEAMCONTROLLER_INTERFACE_VERSION           = 'SteamController008';
  { Fallback version string of the STEAMUGC interface family. }
  STEAMUGC_INTERFACE_VERSION                  = 'STEAMUGC_INTERFACE_VERSION021';
  { Fallback version string of the STEAMHTMLSURFACE interface family. }
  STEAMHTMLSURFACE_INTERFACE_VERSION          = 'STEAMHTMLSURFACE_INTERFACE_VERSION_005';
  { Fallback version string of the STEAMINVENTORY interface family. }
  STEAMINVENTORY_INTERFACE_VERSION            = 'STEAMINVENTORY_INTERFACE_V003';
  { Fallback version string of the STEAMVIDEO interface family. }
  STEAMVIDEO_INTERFACE_VERSION                = 'STEAMVIDEO_INTERFACE_V007';
  { Fallback version string of the STEAMPARENTALSETTINGS interface family. }
  STEAMPARENTALSETTINGS_INTERFACE_VERSION     = 'STEAMPARENTALSETTINGS_INTERFACE_VERSION001';
  { Fallback version string of the STEAMREMOTEPLAY interface family. }
  STEAMREMOTEPLAY_INTERFACE_VERSION           = 'STEAMREMOTEPLAY_INTERFACE_VERSION004';
  { Fallback version string of the STEAMTIMELINE interface family. }
  STEAMTIMELINE_INTERFACE_VERSION             = 'STEAMTIMELINE_INTERFACE_V004';
  { Fallback version string of the STEAMNETWORKINGSOCKETS interface family. }
  STEAMNETWORKINGSOCKETS_INTERFACE_VERSION    = 'SteamNetworkingSockets013';
  { Fallback version string of the STEAMNETWORKINGMESSAGES interface family. }
  STEAMNETWORKINGMESSAGES_INTERFACE_VERSION   = 'SteamNetworkingMessages002';
  { Fallback version string of the STEAMNETWORKINGUTILS interface family. }
  STEAMNETWORKINGUTILS_INTERFACE_VERSION      = 'SteamNetworkingUtils004';

implementation

end.
