object frmGamepadVCL: TfrmGamepadVCL
  Left = 0
  Top = 0
  Caption = 'Virtual Gamepad VCL'
  ClientHeight = 800
  ClientWidth = 1100
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Menu = MainMenu1
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  TextHeight = 15
  object pnlPad: TPanel
    Left = 0
    Top = 0
    Width = 1100
    Height = 44
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblPadName: TLabel
      AlignWithMargins = True
      Left = 8
      Top = 0
      Width = 1092
      Height = 44
      Margins.Left = 8
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 0
      Align = alClient
      AutoSize = False
      Caption = 'No controller'
      Layout = tlCenter
    end
  end
  object tmPoll: TTimer
    Enabled = False
    Interval = 16
    OnTimer = tmPollTimer
    Left = 760
    Top = 160
  end
  object tmStart: TTimer
    Interval = 100
    OnTimer = tmStartTimer
    Left = 760
    Top = 216
  end
  object MainMenu1: TMainMenu
    Left = 840
    Top = 272
    object mnuFile: TMenuItem
      Caption = '&File'
      object mnuLayout: TMenuItem
        Caption = 'View Controller Settings...'
        OnClick = mnuLayoutClick
      end
      object mnuRemoteLog: TMenuItem
        Caption = 'Send log to receiver...'
        OnClick = mnuRemoteLogClick
      end
      object mnuSep1: TMenuItem
        Caption = '-'
      end
      object mnuExit: TMenuItem
        Caption = 'E&xit'
        OnClick = mnuExitClick
      end
    end
    object mnuView: TMenuItem
      Caption = '&View'
      object mnuMotion: TMenuItem
        Caption = 'Follow pad motion: off'
        OnClick = mnuMotionClick
      end
      object mnuRecenter: TMenuItem
        Caption = 'Recenter motion'
        OnClick = mnuRecenterClick
      end
      object mnuShowBack: TMenuItem
        Caption = 'Show back'
        OnClick = mnuShowBackClick
      end
      object mnuResetView: TMenuItem
        Caption = 'Reset view'
        OnClick = mnuResetViewClick
      end
    end
  end
  object SteamAPI1: TSteamAPI
    AppID = 4108310
    OnInitialized = SteamInitialized
    OnInitFailed = SteamInitFailed
    OnShutdown = SteamShutdown
    OnSteamShutdown = SteamClientExit
    OnLog = SteamLog
    Left = 840
    Top = 160
  end
  object SteamInput1: TSteamInput
    SteamAPI = SteamAPI1
    OnSteamInputConfigurationLoaded = InputConfigurationLoaded
    Left = 840
    Top = 216
  end
end
