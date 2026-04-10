unit DemoMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TFormMain = class(TForm)
    pnlTitulo: TPanel;
    gbDados: TGroupBox;
    lblNome: TLabel;
    lblValor: TLabel;
    edNome: TEdit;
    edValor: TEdit;
    btnCalcular: TButton;
    btnLimpar: TButton;
    btnSair: TButton;
    lblResultado: TLabel;
    procedure btnCalcularClick(Sender: TObject);
    procedure btnLimparClick(Sender: TObject);
    procedure btnSairClick(Sender: TObject);
  public
    Contador: Integer;
  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

procedure TFormMain.btnCalcularClick(Sender: TObject);
var
  V: Double;
begin
  Inc(Contador);
  V := StrToFloatDef(edValor.Text, 0);
  lblResultado.Caption :=
    Format('%s: %.2f (clicks=%d)', [edNome.Text, V * 2, Contador]);
end;

procedure TFormMain.btnLimparClick(Sender: TObject);
begin
  edNome.Clear;
  edValor.Clear;
  lblResultado.Caption := '';
end;

procedure TFormMain.btnSairClick(Sender: TObject);
begin
  Close;
end;

end.
