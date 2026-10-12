unit mc_linechart;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Graphics, Math,
  BGRABitmap, BGRABitmapTypes, BGRAPath,
  mc_types, mc_utils, mc_dataset, mc_basechart;

type
  TMCLineChart = class(TMCBaseChart)
  private
    FPointRadius: Integer;

    { Struktur untuk deteksi interaksi kursor di atas titik grafik }
    type
      TPointRegion = record
        Center: TPointF;
        DatasetIndex: Integer;
        CategoryIndex: Integer;
        Value: Double;
      end;

    var
      FPointRegions: array of TPointRegion;

    procedure SetPointRadius(AValue: Integer);
  protected
    procedure DrawChart; override;
    procedure DrawGridAndAxes; override;
    function CheckHover(X, Y: Integer; out ALine1, ALine2: string): Boolean; override;

    { Meng-override GetChartRect untuk mengatur padding kanan secara dinamis }
    function GetChartRect: TRect; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Align;
    property BorderSpacing;
    { Properti khusus Line Chart }
    property PointRadius: Integer read FPointRadius write SetPointRadius default 5;
  end;

implementation

constructor TMCLineChart.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FPointRadius := 5;
  SetLength(FPointRegions, 0);
end;

procedure TMCLineChart.SetPointRadius(AValue: Integer);
begin
  if FPointRadius = AValue then Exit;
  FPointRadius := AValue;
  Invalidate;
end;

{ Modifikasi area gambar agar memiliki margin kanan tambahan untuk label terakhir }
function TMCLineChart.GetChartRect: TRect;
begin
  Result := inherited GetChartRect;
  { Memberikan padding kanan ekstra 30px agar label tidak terpotong }
  Result.Right := Result.Right - 30;
end;

{ Deteksi Hover: Menggunakan jarak dari kursor ke titik koordinat (Radius + Toleransi 5px) }
function TMCLineChart.CheckHover(X, Y: Integer; out ALine1, ALine2: string): Boolean;
var
  i: Integer;
  Region: TPointRegion;
  Dataset: TMCChartDataset;
  Dist: Double;
begin
  Result := False;
  ALine1 := ''; ALine2 := '';

  if Length(FPointRegions) = 0 then Exit;

  for i := 0 to High(FPointRegions) do
  begin
    Region := FPointRegions[i];
    Dist := Hypot(X - Region.Center.X, Y - Region.Center.Y);

    if Dist <= (FPointRadius + 5) then
    begin
      Dataset := TMCChartDataset(FDatasets.Items[Region.DatasetIndex]);
      if (Region.CategoryIndex >= 0) and (Region.CategoryIndex < Labels.Count) then
        ALine1 := Labels[Region.CategoryIndex]
      else
        ALine1 := 'Kategori ' + IntToStr(Region.CategoryIndex + 1);

      ALine2 := Dataset.LabelName + ': ' + FormatFloat('0.##', Region.Value);
      Result := True;
      Break;
    end;
  end;
end;

{ Meng-override DrawGridAndAxes untuk menambahkan Grid Vertikal ala Line Chart Chart.js }
procedure TMCLineChart.DrawGridAndAxes;
var
  ChartArea: TRect;
  GridBGRA: TBGRAPixel;
  NumTicks, i: Integer;
  YPos, XPos, SpacingX: Double;
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
  NumTicks := 5;
  StepValue := (ValMax - ValMin) / NumTicks;

  { Render Grid Horizontal (Sumbu Y) }
  for i := 0 to NumTicks do
  begin
    CurrentValue := ValMin + (i * StepValue);
    YPos := MapValue(CurrentValue, ValMin, ValMax, ChartArea.Bottom, ChartArea.Top);

    if (ShowGrid) and (i > 0) then
      FBuffer.DrawLineAntialias(ChartArea.Left, YPos, ChartArea.Right, YPos, GridBGRA, 1);

    LabelStr := FormatAxisLabel(CurrentValue);
    FBuffer.TextOut(ChartArea.Left - 8, YPos - (FBuffer.FontHeight div 2), LabelStr, ColorToBGRAAlpha(Font.Color, 255), taRightJustify);
  end;

  { Render Grid Vertikal & Label Sumbu X }
  if Labels.Count > 0 then
  begin
    SpacingX := (ChartArea.Right - ChartArea.Left) / Max(1, Labels.Count - 1);
    for i := 0 to Labels.Count - 1 do
    begin
      XPos := ChartArea.Left + (i * SpacingX);

      if (ShowGrid) and (i > 0) and (i < Labels.Count - 1) then
        FBuffer.DrawLineAntialias(XPos, ChartArea.Top, XPos, ChartArea.Bottom, GridBGRA, 1);

      LabelStr := Labels[i];
      FBuffer.TextOut(Trunc(XPos), ChartArea.Bottom + 10, LabelStr, ColorToBGRAAlpha(Font.Color, 255), taCenter);
    end;
  end;
end;

procedure TMCLineChart.DrawChart;
var
  ChartArea: TRect;
  i, j: Integer;
  RegionIdx: Integer;
  SpacingX, XPos, YPos: Double;
  PrevX, PrevY, ZeroY: Double;
  ValMin, ValMax, Val: Double;
  Dataset: TMCChartDataset;
  ValStr: string;
begin
  if (Labels.Count = 0) or (Datasets.Count = 0) then Exit;

  ChartArea := GetChartRect;
  CalculateMinMax(ValMin, ValMax);

  if (ValMin < 0) and (ValMax > 0) then
  begin
    ZeroY := MapValue(0, ValMin, ValMax, ChartArea.Bottom, ChartArea.Top);
    FBuffer.DrawLineAntialias(ChartArea.Left, ZeroY, ChartArea.Right, ZeroY, BGRA(150, 150, 150, 255), 1.5);
  end;

  SpacingX := (ChartArea.Right - ChartArea.Left) / Max(1, Labels.Count - 1);

  SetLength(FPointRegions, Labels.Count * Datasets.Count);
  RegionIdx := 0;

  { Loop setiap Dataset }
  for j := 0 to Datasets.Count - 1 do
  begin
    Dataset := TMCChartDataset(Datasets.Items[j]);

    { Tahap 1: Gambar Garis Penghubung }
    PrevX := -1; PrevY := -1;
    for i := 0 to Min(Labels.Count - 1, Dataset.Count - 1) do
    begin
      Val := Dataset.Values[i];
      XPos := ChartArea.Left + (i * SpacingX);
      YPos := MapValue(Val, ValMin, ValMax, ChartArea.Bottom, ChartArea.Top);

      if i > 0 then
        FBuffer.DrawLineAntialias(PrevX, PrevY, XPos, YPos, Dataset.GetBGRABorder, Dataset.BorderWidth);

      PrevX := XPos;
      PrevY := YPos;
    end;

    { Tahap 2: Gambar Titik (Dot) di atas garis dan Daftarkan ke Hover }
    for i := 0 to Min(Labels.Count - 1, Dataset.Count - 1) do
    begin
      Val := Dataset.Values[i];
      XPos := ChartArea.Left + (i * SpacingX);
      YPos := MapValue(Val, ValMin, ValMax, ChartArea.Bottom, ChartArea.Top);

      { Gambar titik berupa lingkaran (Fill + Border) }
      FBuffer.FillEllipseAntialias(XPos, YPos, FPointRadius, FPointRadius, Dataset.GetBGRAFill);

      { PERBAIKAN: Menggunakan EllipseAntialias yang benar }
      if Dataset.BorderWidth > 0 then
        FBuffer.EllipseAntialias(XPos, YPos, FPointRadius, FPointRadius, Dataset.GetBGRABorder, Dataset.BorderWidth);

      { Simpan data ke memori untuk tooltip }
      FPointRegions[RegionIdx].Center.X := XPos;
      FPointRegions[RegionIdx].Center.Y := YPos;
      FPointRegions[RegionIdx].DatasetIndex := j;
      FPointRegions[RegionIdx].CategoryIndex := i;
      FPointRegions[RegionIdx].Value := Val;
      Inc(RegionIdx);

      { Tahap 3: Fitur Data Labels }
      if ShowDataLabels then
      begin
        FBuffer.FontName := DataLabelFont.Name;
        FBuffer.FontHeight := Abs(DataLabelFont.Height);
        if FBuffer.FontHeight = 0 then FBuffer.FontHeight := DataLabelFont.Size;
        FBuffer.FontStyle := DataLabelFont.Style;

        ValStr := FormatFloat('0.##', Val);

        { Tampilkan nilai tepat di atas titik }
        FBuffer.TextOut(Trunc(XPos), Trunc(YPos - FPointRadius - FBuffer.FontHeight - 5), ValStr, ColorToBGRAAlpha(DataLabelFont.Color, 255), taCenter);
      end;
    end;
  end;

  SetLength(FPointRegions, RegionIdx);
end;

end.
