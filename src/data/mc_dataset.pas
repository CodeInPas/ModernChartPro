unit mc_dataset;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Controls, fgl, BGRABitmapTypes, mc_types, mc_utils; { <-- PERBAIKAN: Menambahkan unit Controls agar TControl dikenali }

type
  TMCValueList = specialize TFPGList<Double>;

  { Tipe untuk menentukan wujud Dataset (Bar atau Line) pada Combo Chart }
  TMCSeriesType = (stBar, stLine);

  { TMCChartDataset sekarang adalah TCollectionItem agar tampil di Object Inspector }
  TMCChartDataset = class(TCollectionItem)
  private
    FLabelName: string;
    FValues: TMCValueList;
    FDataValues: string; { Properti string (comma separated) untuk mempermudah input di IDE }

    FSeriesType: TMCSeriesType; { Properti baru untuk Combo Chart }

    { Properti visual standar untuk IDE }
    FBackgroundColor: TColor;
    FBackgroundAlpha: Byte;
    FBorderColor: TColor;
    FBorderAlpha: Byte;
    FBorderWidth: Integer;
    FBorderRadius: Integer;

    procedure SetSeriesType(AValue: TMCSeriesType);
    procedure SetDataValues(AValue: string);
    procedure SetLabelName(AValue: string);
    procedure SetBackgroundColor(AValue: TColor);
    procedure SetBackgroundAlpha(AValue: Byte);
    procedure SetBorderColor(AValue: TColor);
    procedure SetBorderAlpha(AValue: Byte);
    procedure SetBorderWidth(AValue: Integer);
    procedure SetBorderRadius(AValue: Integer);
  public
    constructor Create(ACollection: TCollection); override;
    destructor Destroy; override;

    procedure Add(AValue: Double); inline;
    procedure Clear; inline;

    function GetCount: Integer; inline;
    function GetValue(AIndex: Integer): Double; inline;

    { Helper untuk mengkonversi properti IDE kembali ke BGRAPixel saat render }
    function GetBGRAFill: TBGRAPixel;
    function GetBGRABorder: TBGRAPixel;
    function GetRadiusRecord: TMCBorderRadius;

    property Count: Integer read GetCount;
    property Values[AIndex: Integer]: Double read GetValue; default;
  published
    property LabelName: string read FLabelName write SetLabelName;
    { Input data praktis dari IDE, contoh: "10, -20, 50, 40" }
    property DataValues: string read FDataValues write SetDataValues;
    property SeriesType: TMCSeriesType read FSeriesType write SetSeriesType default stBar;

    property BackgroundColor: TColor read FBackgroundColor write SetBackgroundColor default $00FFAA55;
    property BackgroundAlpha: Byte read FBackgroundAlpha write SetBackgroundAlpha default 200;
    property BorderColor: TColor read FBorderColor write SetBorderColor default $00FF5500;
    property BorderAlpha: Byte read FBorderAlpha write SetBorderAlpha default 255;
    property BorderWidth: Integer read FBorderWidth write SetBorderWidth default 1;
    property BorderRadius: Integer read FBorderRadius write SetBorderRadius default 0;
  end;

  { TMCDatasetList bertindak sebagai TCollection untuk mengelola banyak dataset }
  TMCDatasetList = class(TCollection)
  private
    FChart: TControl; // Referensi ke komponen induk (Chart) untuk memicu repaint
    function GetDataset(Index: Integer): TMCChartDataset;
    procedure SetDataset(Index: Integer; Value: TMCChartDataset);
  protected
    { Update dipanggil otomatis ketika ada perubahan pada item dataset di Object Inspector }
    procedure Update(Item: TCollectionItem); override;
  public
    constructor Create(AChart: TControl);
    property Items[Index: Integer]: TMCChartDataset read GetDataset write SetDataset; default;
  end;

implementation

{ TMCChartDataset }

constructor TMCChartDataset.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FValues := TMCValueList.Create;
  FLabelName := 'Dataset ' + IntToStr(ID + 1);
  FDataValues := '';
  FSeriesType := stBar; // Default adalah Bar
  FBackgroundColor := $00FFAA55; // Biru Muda standar
  FBackgroundAlpha := 200;
  FBorderColor := $00FF5500;
  FBorderAlpha := 255;
  FBorderWidth := 1;
  FBorderRadius := 0;
end;

destructor TMCChartDataset.Destroy;
begin
  FValues.Free;
  inherited Destroy;
end;

procedure TMCChartDataset.SetSeriesType(AValue: TMCSeriesType);
begin
  if FSeriesType = AValue then Exit;
  FSeriesType := AValue;
  Changed(False);
end;

procedure TMCChartDataset.SetDataValues(AValue: string);
var
  SL: TStringList;
  i: Integer;
begin
  if FDataValues = AValue then Exit;
  FDataValues := AValue;

  FValues.Clear;
  SL := TStringList.Create;
  try
    SL.CommaText := AValue;
    for i := 0 to SL.Count - 1 do
      FValues.Add(StrToFloatDef(Trim(SL[i]), 0));
  finally
    SL.Free;
  end;
  Changed(False); // Memicu repaint chart
end;

procedure TMCChartDataset.SetLabelName(AValue: string);
begin
  if FLabelName = AValue then Exit;
  FLabelName := AValue;
  Changed(False);
end;

procedure TMCChartDataset.SetBackgroundColor(AValue: TColor);
begin
  if FBackgroundColor = AValue then Exit;
  FBackgroundColor := AValue;
  Changed(False);
end;

procedure TMCChartDataset.SetBackgroundAlpha(AValue: Byte);
begin
  if FBackgroundAlpha = AValue then Exit;
  FBackgroundAlpha := AValue;
  Changed(False);
end;

procedure TMCChartDataset.SetBorderColor(AValue: TColor);
begin
  if FBorderColor = AValue then Exit;
  FBorderColor := AValue;
  Changed(False);
end;

procedure TMCChartDataset.SetBorderAlpha(AValue: Byte);
begin
  if FBorderAlpha = AValue then Exit;
  FBorderAlpha := AValue;
  Changed(False);
end;

procedure TMCChartDataset.SetBorderWidth(AValue: Integer);
begin
  if FBorderWidth = AValue then Exit;
  FBorderWidth := AValue;
  Changed(False);
end;

procedure TMCChartDataset.SetBorderRadius(AValue: Integer);
begin
  if FBorderRadius = AValue then Exit;
  FBorderRadius := AValue;
  Changed(False);
end;

procedure TMCChartDataset.Add(AValue: Double); inline;
begin
  FValues.Add(AValue);
  { Update FDataValues string secara diam-diam tanpa memicu event }
  if FDataValues = '' then FDataValues := FloatToStr(AValue)
  else FDataValues := FDataValues + ',' + FloatToStr(AValue);
end;

procedure TMCChartDataset.Clear; inline;
begin
  FValues.Clear;
  FDataValues := '';
end;

function TMCChartDataset.GetCount: Integer; inline;
begin
  Result := FValues.Count;
end;

function TMCChartDataset.GetValue(AIndex: Integer): Double; inline;
begin
  Result := FValues[AIndex];
end;

function TMCChartDataset.GetBGRAFill: TBGRAPixel;
begin
  Result := ColorToBGRAAlpha(FBackgroundColor, FBackgroundAlpha);
end;

function TMCChartDataset.GetBGRABorder: TBGRAPixel;
begin
  Result := ColorToBGRAAlpha(FBorderColor, FBorderAlpha);
end;

function TMCChartDataset.GetRadiusRecord: TMCBorderRadius;
begin
  Result := MCBorderRadiusAll(FBorderRadius);
end;

{ TMCDatasetList }

constructor TMCDatasetList.Create(AChart: TControl);
begin
  inherited Create(TMCChartDataset);
  FChart := AChart;
end;

function TMCDatasetList.GetDataset(Index: Integer): TMCChartDataset;
begin
  Result := TMCChartDataset(inherited Items[Index]);
end;

procedure TMCDatasetList.SetDataset(Index: Integer; Value: TMCChartDataset);
begin
  inherited Items[Index] := Value;
end;

procedure TMCDatasetList.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Assigned(FChart) then FChart.Invalidate; // Meminta Chart untuk merender ulang
end;

end.
