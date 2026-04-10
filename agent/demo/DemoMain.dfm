object FormMain: TFormMain
  Left = 200
  Top = 120
  Caption = 'NexusTest Demo VCL'
  ClientHeight = 320
  ClientWidth = 480
  Color = clWhite
  Font.Charset = ANSI_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Arial'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 15
  object pnlTitulo: TPanel
    Left = 0
    Top = 0
    Width = 480
    Height = 35
    Align = alTop
    BevelOuter = bvNone
    Caption = 'NexusTest Demo VCL'
    Color = 16766894
    Font.Charset = ANSI_CHARSET
    Font.Color = clNavy
    Font.Height = -21
    Font.Name = 'Arial'
    Font.Style = []
    ParentBackground = False
    ParentFont = False
    TabOrder = 0
  end
  object gbDados: TGroupBox
    Left = 16
    Top = 50
    Width = 450
    Height = 130
    Caption = ' Dados de entrada '
    Font.Charset = ANSI_CHARSET
    Font.Color = clNavy
    Font.Height = -15
    Font.Name = 'Arial'
    Font.Style = []
    ParentFont = False
    TabOrder = 1
    object lblNome: TLabel
      Left = 16
      Top = 28
      Width = 50
      Height = 18
      Caption = 'Nome:'
    end
    object lblValor: TLabel
      Left = 16
      Top = 64
      Width = 50
      Height = 18
      Caption = 'Valor:'
    end
    object edNome: TEdit
      Left = 80
      Top = 24
      Width = 350
      Height = 26
      Font.Charset = ANSI_CHARSET
      Font.Color = clBlack
      Font.Height = -15
      Font.Name = 'Arial'
      Font.Style = []
      ParentFont = False
      TabOrder = 0
    end
    object edValor: TEdit
      Left = 80
      Top = 60
      Width = 150
      Height = 26
      Font.Charset = ANSI_CHARSET
      Font.Color = clBlack
      Font.Height = -15
      Font.Name = 'Arial'
      Font.Style = []
      ParentFont = False
      TabOrder = 1
      Text = '0'
    end
    object lblResultado: TLabel
      Left = 16
      Top = 98
      Width = 420
      Height = 20
      AutoSize = False
      Caption = ''
      Font.Charset = ANSI_CHARSET
      Font.Color = clNavy
      Font.Height = -17
      Font.Name = 'Arial'
      Font.Style = [fsBold]
      ParentFont = False
    end
  end
  object btnCalcular: TButton
    Left = 16
    Top = 200
    Width = 130
    Height = 40
    Caption = '&Calcular'
    Font.Charset = ANSI_CHARSET
    Font.Color = clNavy
    Font.Height = -17
    Font.Name = 'Arial'
    Font.Style = [fsBold]
    ParentFont = False
    TabOrder = 2
    OnClick = btnCalcularClick
  end
  object btnLimpar: TButton
    Left = 160
    Top = 200
    Width = 130
    Height = 40
    Caption = '&Limpar'
    Font.Charset = ANSI_CHARSET
    Font.Color = clNavy
    Font.Height = -17
    Font.Name = 'Arial'
    Font.Style = []
    ParentFont = False
    TabOrder = 3
    OnClick = btnLimparClick
  end
  object btnSair: TButton
    Left = 336
    Top = 200
    Width = 130
    Height = 40
    Caption = '&Sair'
    Font.Charset = ANSI_CHARSET
    Font.Color = clRed
    Font.Height = -17
    Font.Name = 'Arial'
    Font.Style = []
    ParentFont = False
    TabOrder = 4
    OnClick = btnSairClick
  end
end
