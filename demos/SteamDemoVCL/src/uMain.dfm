object frmSteamDemo: TfrmSteamDemo
  Left = 0
  Top = 0
  Caption = 'Steamworks VCL Demo - AppID 2275430 (SDK 1.65)'
  ClientHeight = 601
  ClientWidth = 944
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  TextHeight = 15
  object pnlButtons: TPanel
    Left = 0
    Top = 0
    Width = 944
    Height = 48
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    ExplicitWidth = 938
    object btnStart: TButton
      Left = 8
      Top = 10
      Width = 110
      Height = 28
      Caption = 'Start Steam'
      TabOrder = 0
      OnClick = btnStartClick
    end
    object btnInfo: TButton
      Left = 126
      Top = 10
      Width = 110
      Height = 28
      Caption = 'Show info'
      TabOrder = 1
      OnClick = btnInfoClick
    end
    object btnStop: TButton
      Left = 244
      Top = 10
      Width = 110
      Height = 28
      Caption = 'Stop Steam'
      TabOrder = 2
      OnClick = btnStopClick
    end
    object btnCopy: TButton
      Left = 362
      Top = 10
      Width = 110
      Height = 28
      Caption = 'Copy log'
      TabOrder = 3
      OnClick = btnCopyClick
    end
  end
  object pgcMain: TPageControl
    Left = 0
    Top = 48
    Width = 944
    Height = 553
    ActivePage = tsOutput
    Align = alClient
    TabOrder = 1
    ExplicitWidth = 938
    ExplicitHeight = 536
    object tsOutput: TTabSheet
      Caption = 'Output'
      object memLog: TMemo
        Left = 0
        Top = 0
        Width = 936
        Height = 523
        Align = alClient
        ReadOnly = True
        ScrollBars = ssBoth
        TabOrder = 0
        WordWrap = False
        ExplicitWidth = 930
        ExplicitHeight = 506
      end
    end
    object tsPersonal: TTabSheet
      Caption = 'Personal'
      object lblFriends: TLabel
        Left = 0
        Top = 200
        Width = 936
        Height = 15
        Align = alTop
        Caption = ' Friends'
        ExplicitWidth = 41
      end
      object pnlPersonalTop: TPanel
        Left = 0
        Top = 0
        Width = 936
        Height = 200
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        object imgAvatar: TImage
          Left = 0
          Top = 0
          Width = 200
          Height = 200
          Align = alLeft
          Center = True
        end
        object lvInfo: TListView
          Left = 200
          Top = 0
          Width = 736
          Height = 200
          Align = alClient
          Columns = <
            item
              Caption = 'Item'
              Width = 160
            end
            item
              Caption = 'Value'
              Width = 400
            end>
          ReadOnly = True
          RowSelect = True
          TabOrder = 0
          ViewStyle = vsReport
        end
      end
      object lvFriends: TListView
        Left = 0
        Top = 215
        Width = 936
        Height = 308
        Align = alClient
        Columns = <
          item
            Caption = 'Name'
            Width = 260
          end
          item
            Caption = 'Status'
            Width = 140
          end
          item
            Caption = 'Level'
            Width = 60
          end
          item
            Caption = 'SteamID'
            Width = 160
          end>
        ReadOnly = True
        RowSelect = True
        SmallImages = ilFriends
        TabOrder = 1
        ViewStyle = vsReport
      end
    end
    object tsAchievements: TTabSheet
      Caption = 'Achievements'
      object lvAchievements: TListView
        Left = 0
        Top = 0
        Width = 936
        Height = 523
        Align = alClient
        Columns = <
          item
            Caption = 'Achievement'
            Width = 220
          end
          item
            Caption = 'Description'
            Width = 400
          end
          item
            Caption = 'State'
            Width = 200
          end>
        ReadOnly = True
        RowSelect = True
        SmallImages = ilAchievements
        TabOrder = 0
        ViewStyle = vsReport
      end
    end
  end
  object ilFriends: TImageList
    ColorDepth = cd32Bit
    Height = 64
    Width = 64
    Left = 760
    Top = 8
  end
  object ilAchievements: TImageList
    ColorDepth = cd32Bit
    Height = 64
    Width = 64
    Left = 840
    Top = 8
  end
  object SteamAPI1: TSteamAPI
    AppID = 2275430
    UpdateMode = sumThread
    OnInitialized = SteamInitialized
    OnInitFailed = SteamInitFailed
    OnShutdown = SteamShutdown
    OnSteamShutdown = SteamClientExit
    OnLog = SteamLog
    OnWarning = SteamWarning
    OnCallback = SteamCallback
    Left = 520
    Top = 8
  end
  object SteamFriends1: TSteamFriends
    SteamAPI = SteamAPI1
    OnPersonaStateChange = FriendPersonaChanged
    OnAvatarImageLoaded = FriendAvatarLoaded
    Left = 600
    Top = 8
  end
  object SteamUserStats1: TSteamUserStats
    SteamAPI = SteamAPI1
    OnUserStatsReceived = StatsReceived
    OnUserAchievementIconFetched = AchievementIconFetched
    Left = 680
    Top = 8
  end
end
