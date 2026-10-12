{ =========================================================================
  FILE BARU: src/charts/mc_scatterchart.pas
  Komponen: TMCScatterChart
  Deskripsi: Scatter chart untuk memvisualisasikan korelasi data X dan Y.
  ========================================================================= }
unit mc_scatterchart;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Graphics, Math,
  BGRABitmap, BGRABitmapTypes, BGRAPath,
  mc_types, mc_utils, mc_dataset, mc_basechart;

type
  TMCScatterChart = class(TMCBaseChart)
  private
    FXMin, FXMax: Double;
    FPointRadius: Integer;

    type
      TScatterRegion = record
        Center: TPointF;
        DatasetIndex: Integer;
        ValueX, ValueY: Double;
      end;

    var
      FScatterRegions: array of TScatterRegion;

    procedure CalculateXMinMax;
    procedure SetPointRadius(AValue: Integer);
  protected
    procedure CalculateMinMax(out AMin, AMax: Double); override;
    procedure DrawChart; override;
    procedure DrawGridAndAxes; override;
    function CheckHover(X, Y: Integer; out ALine1, ALine2: string): Boolean; override;

    { Override untuk mengatur padding secara dinamis }
    function GetChartRect: TRect; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
   property Align;
   property BorderSpacing;
    property PointRadius: Integer read FPointRadius write SetPointRadius default 6;
  end;

implementation

constructor TMCScatterChart.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FPointRadius := 6;
  SetLength(FScatterRegions, 0);
end;

procedure TMCScatterChart.SetPointRadius(AValue: Integer);
begin
  if FPointRadius = AValue then Exit;
  FPointRadius := AValue;
  Invalidate;
end;

{ Menambahkan margin agar titik terluar dan label sumbu X tidak terpotong }
function TMCScatterChart.GetChartRect: TRect;
begin
  Result := inherited GetChartRect;
  Result.Top := Result.Top + 15;
  Result.Right := Result.Right - 30;
end;

{ Menghitung Min Max khusus untuk Sumbu X (Karena X berupa Numerik) }
procedure TMCScatterChart.CalculateXMinMax;
var
  i, k: Integer;
  Dataset: TMCChartDataset;
  ValX: Double;
begin
  FXMin := 0; FXMax := 0;
  if FDatasets.Count = 0 then Exit;

  for i := 0 to FDatasets.Count - 1 do
  begin
    Dataset := TMCChartDataset(FDatasets.Items[i]);
    { Loop setiap 2 nilai: [X, Y] }
    for k := 0 to (Dataset.Count div 2) - 1 do
    begin
      ValX := Dataset.Values[k * 2];
      if (i = 0) and (k = 0) then
      begin
        FXMin := ValX; FXMax := ValX;
      end
      else
      begin
        if ValX > FXMax then FXMax := ValX;
        if ValX < FXMin then FXMin := ValX;
      end;
    end;
  end;

  if FXMax > 0 then FXMax := FXMax * 1.1;
  if FXMin < 0 then FXMin := FXMin * 1.1;
  if FXMax = FXMin then FXMax := FXMin + 10;
end;

{ Meng-override pencarian MinMax Y agar hanya mengecek nilai indeks ke-2 (Y) dari pasangan [X, Y] }
procedure TMCScatterChart.CalculateMinMax(out AMin, AMax: Double);
var
  i, k: Integer;
  Dataset: TMCChartDataset;
  ValY: Double;
begin
  if UseForcedYScale then
  begin
    AMin := ForceYMin; AMax := ForceYMax;
    Exit;
  end;

  AMin := 0; AMax := 0;
  if FDatasets.Count = 0 then Exit;

  for i := 0 to FDatasets.Count - 1 do
  begin
    Dataset := TMCChartDataset(FDatasets.Items[i]);
    for k := 0 to (Dataset.Count div 2) - 1 do
    begin
      ValY := Dataset.Values[(k * 2) + 1];
      if (i = 0) and (k = 0) then
      begin
        AMin := ValY; AMax := ValY;
      end
      else
      begin
        if ValY > AMax then AMax := ValY;
        if ValY < AMin then AMin := ValY;
      end;
    end;
  end;

  if AMax > 0 then AMax := AMax * 1.1;
  if AMin < 0 then AMin := AMin * 1.1;
  if AMax = AMin then AMax := AMin + 10;
end;

function TMCScatterChart.CheckHover(X, Y: Integer; out ALine1, ALine2: string): Boolean;
var
  i: Integer;
  Region: TScatterRegion;
  Dataset: TMCChartDataset;
  Dist: Double;
begin
  Result := False;
  ALine1 := ''; ALine2 := '';

  if Length(FScatterRegions) = 0 then Exit;

  for i := High(FScatterRegions) downto 0 do
  begin
    Region := FScatterRegions[i];
    Dist := Hypot(X - Region.Center.X, Y - Region.Center.Y);

    if Dist <= (FPointRadius + 4) then
    begin
      Dataset := TMCChartDataset(FDatasets.Items[Region.DatasetIndex]);
      ALine1 := Dataset.LabelName;
      ALine2 := Format('X: %s, Y: %s', [
        FormatFloat('0.##', Region.ValueX),
        FormatFloat('0.##', Region.ValueY)]);
      Result := True;
      Break;
    end;
  end;
end;

procedure TMCScatterChart.DrawGridAndAxes;
var
  ChartArea: TRect;
  GridBGRA: TBGRAPixel;
  NumTicks, i: Integer;
  YPos, XPos: Double;
  ValMin, ValMax, StepValue, CurrentValue: Double;
  LabelStr: string;
begin
  ChartArea := GetChartRect;
  GridBGRA := ColorToBGRAAlpha(GridColor, GridAlpha);

  FBuffer.FontName := Font.Name;
  FBuffer.FontHeight := Abs(Font.Height);
  if FBuffer.FontHeight = 0 then FBuffer.FontHeight := Font.Size;
  if FBuffer.FontHeight = 0 then FBuffer.FontHeight := 12;
  FBuffer.FontStyle := Font.Style;
  FBuffer.FontAntialias := True;

  FBuffer.DrawLineAntialias(ChartArea.Left, ChartArea.Top, ChartArea.Left, ChartArea.Bottom, BGRA(150, 150, 150, 255), 1);
  FBuffer.DrawLineAntialias(ChartArea.Left, ChartArea.Bottom, ChartArea.Right, ChartArea.Bottom, BGRA(150, 150, 150, 255), 1);

  CalculateMinMax(ValMin, ValMax);
  CalculateXMinMax;

  NumTicks := 6;

  { Render Grid Horizontal (Sumbu Y Numerik) }
  StepValue := (ValMax - ValMin) / NumTicks;
  if StepValue > 0 then
  begin
    for i := 0 to NumTicks do
    begin
      CurrentValue := ValMin + (i * StepValue);
      YPos := MapValue(CurrentValue, ValMin, ValMax, ChartArea.Bottom, ChartArea.Top);

      if (ShowGrid) and (i > 0) then
        FBuffer.DrawLineAntialias(ChartArea.Left, YPos, ChartArea.Right, YPos, GridBGRA, 1);

      LabelStr := FormatAxisLabel(CurrentValue);
      FBuffer.TextOut(ChartArea.Left - 8, YPos - (FBuffer.FontHeight div 2), LabelStr, ColorToBGRAAlpha(Font.Color, 255), taRightJustify);
    end;
  end;

  { Render Grid Vertikal (Sumbu X Numerik) }
  StepValue := (FXMax - FXMin) / NumTicks;
  if StepValue > 0 then
  begin
    for i := 0 to NumTicks do
    begin
      CurrentValue := FXMin + (i * StepValue);
      XPos := MapValue(CurrentValue, FXMin, FXMax, ChartArea.Left, ChartArea.Right);

      if (ShowGrid) and (i > 0) then
        FBuffer.DrawLineAntialias(XPos, ChartArea.Top, XPos, ChartArea.Bottom, GridBGRA, 1);

      LabelStr := FormatAxisLabel(CurrentValue);
      FBuffer.TextOut(Trunc(XPos), ChartArea.Bottom + 10, LabelStr, ColorToBGRAAlpha(Font.Color, 255), taCenter);
    end;
  end;
end;

procedure TMCScatterChart.DrawChart;
var
  ChartArea: TRect;
  i, k: Integer;
  RegionIdx: Integer;
  XPos, YPos: Double;
  ValMin, ValMax: Double;
  Dataset: TMCChartDataset;
  ValX, ValY: Double;
begin
  if Datasets.Count = 0 then Exit;

  ChartArea := GetChartRect;
  CalculateMinMax(ValMin, ValMax);
  CalculateXMinMax;

  { Hitung total memori poin yang dibutuhkan }
  RegionIdx := 0;
  for i := 0 to Datasets.Count - 1 do
    Inc(RegionIdx, TMCChartDataset(Datasets.Items[i]).Count div 2);

  SetLength(FScatterRegions, RegionIdx);
  RegionIdx := 0;

  { Gambar Titik/Poin dari Dataset }
  for i := 0 to Datasets.Count - 1 do
  begin
    Dataset := TMCChartDataset(Datasets.Items[i]);

    { Step per 2 index: [X, Y] }
    for k := 0 to (Dataset.Count div 2) - 1 do
    begin
      ValX := Dataset.Values[k * 2];
      ValY := Dataset.Values[k * 2 + 1];

      XPos := MapValue(ValX, FXMin, FXMax, ChartArea.Left, ChartArea.Right);
      YPos := MapValue(ValY, ValMin, ValMax, ChartArea.Bottom, ChartArea.Top);

      { Gambar Titik Lingkaran }
      FBuffer.FillEllipseAntialias(XPos, YPos, FPointRadius, FPointRadius, Dataset.GetBGRAFill);

      if Dataset.BorderWidth > 0 then
        FBuffer.EllipseAntialias(XPos, YPos, FPointRadius, FPointRadius, Dataset.GetBGRABorder, Dataset.BorderWidth);

      { Simpan data ke memori untuk tooltip kursor }
      FScatterRegions[RegionIdx].Center.X := XPos;
      FScatterRegions[RegionIdx].Center.Y := YPos;
      FScatterRegions[RegionIdx].DatasetIndex := i;
      FScatterRegions[RegionIdx].ValueX := ValX;
      FScatterRegions[RegionIdx].ValueY := ValY;
      Inc(RegionIdx);
    end;
  end;
end;

end.
