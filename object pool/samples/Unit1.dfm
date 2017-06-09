object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 387
  ClientWidth = 845
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 120
  TextHeight = 16
  object mmo1: TMemo
    Left = 8
    Top = 226
    Width = 817
    Height = 153
    Lines.Strings = (
      'mmo1')
    TabOrder = 0
    WordWrap = False
  end
  object Button1: TButton
    Left = 24
    Top = 16
    Width = 129
    Height = 25
    Caption = 'Test'#20027#32447#31243#24212#29992
    TabOrder = 1
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 184
    Top = 16
    Width = 137
    Height = 25
    Caption = #22810#32447#31243#24212#29992
    TabOrder = 2
    OnClick = Button2Click
  end
  object Panel1: TPanel
    Left = 8
    Top = 72
    Width = 817
    Height = 148
    TabOrder = 3
    object lbl_wait: TLabel
      Left = 16
      Top = 8
      Width = 44
      Height = 16
      Caption = 'lbl_wait'
    end
    object lbl_mntsize: TLabel
      Left = 16
      Top = 30
      Width = 44
      Height = 16
      Caption = 'lbl_wait'
    end
    object lbl_poolsize: TLabel
      Left = 16
      Top = 52
      Width = 44
      Height = 16
      Caption = 'lbl_wait'
    end
    object lbl_used: TLabel
      Left = 16
      Top = 74
      Width = 44
      Height = 16
      Caption = 'lbl_wait'
    end
  end
  object Button3: TButton
    Left = 368
    Top = 16
    Width = 75
    Height = 25
    Caption = #20572#27490#25152#26377
    TabOrder = 4
    OnClick = Button3Click
  end
  object tmr1: TTimer
    Interval = 300
    OnTimer = tmr1Timer
    Left = 88
    Top = 88
  end
  object Timer1: TTimer
    Enabled = False
    Interval = 500
    Left = 176
    Top = 88
  end
end
