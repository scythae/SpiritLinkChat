object frMain: TfrMain
  Left = 0
  Top = 0
  Caption = 'frMain'
  ClientHeight = 389
  ClientWidth = 656
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object splChat: TSplitter
    Left = 185
    Top = 0
    Width = 4
    Height = 389
    AutoSnap = False
    Color = clBtnShadow
    ParentColor = False
  end
  object pNavigation: TPanel
    Left = 0
    Top = 0
    Width = 185
    Height = 389
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 0
    object btnHost: TButton
      Left = 0
      Top = 0
      Width = 185
      Height = 25
      Align = alTop
      Caption = 'Host'
      TabOrder = 0
      OnClick = btnHostClick
    end
    object btnJoin: TButton
      Left = 0
      Top = 25
      Width = 185
      Height = 25
      Align = alTop
      Caption = 'Join'
      TabOrder = 1
      OnClick = btnJoinClick
    end
    object lbConnections: TListBox
      Left = 0
      Top = 50
      Width = 185
      Height = 339
      Align = alClient
      ItemHeight = 13
      TabOrder = 2
    end
  end
  object pChat: TPanel
    Left = 189
    Top = 0
    Width = 467
    Height = 389
    Align = alClient
    BevelOuter = bvNone
    Caption = 'p'
    TabOrder = 1
    object splMyMessage: TSplitter
      Left = 0
      Top = 261
      Width = 467
      Height = 4
      Cursor = crVSplit
      Align = alBottom
      AutoSnap = False
      Color = clBtnShadow
      ParentColor = False
      ExplicitTop = 262
      ExplicitWidth = 468
    end
    object mChat: TMemo
      Left = 0
      Top = 0
      Width = 467
      Height = 261
      Align = alClient
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 0
      ExplicitLeft = 2
      ExplicitTop = -2
    end
    object pMyMessage: TPanel
      Left = 0
      Top = 265
      Width = 467
      Height = 124
      Align = alBottom
      BevelOuter = bvNone
      TabOrder = 1
      object mMyMessage: TMemo
        Left = 72
        Top = 0
        Width = 395
        Height = 124
        Align = alClient
        TabOrder = 0
      end
      object pMyMessageButtons: TPanel
        Left = 0
        Top = 0
        Width = 72
        Height = 124
        Align = alLeft
        BevelOuter = bvNone
        TabOrder = 1
        object btnSend: TButton
          Left = 0
          Top = 99
          Width = 72
          Height = 25
          Align = alBottom
          Caption = 'btnSend'
          TabOrder = 0
          OnClick = btnSendClick
        end
      end
    end
  end
end
