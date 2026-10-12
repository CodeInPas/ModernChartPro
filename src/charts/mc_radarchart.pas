{ =========================================================================
  FILE BARU: src/charts/mc_radarchart.pas
  Komponen: TMCRadarChart
  Deskripsi: Radar / Spider chart untuk membandingkan multi-variabel.
  ========================================================================= }
unit mc_radarchart;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Graphics, Math,
  BGRABitmap, BGRABitmapTypes, BGRAPath,
  mc_types, mc_utils, mc_dataset, mc_basechart;

type
  TMCRadarChart = class(TMCBaseChart)
  private
    FCX, FCY: Double;
    FRadius: Double;
    FPointRadius: Integer;

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
    function GetChartRect: TRect; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Align;
    property BorderSpacing;
    property PointRadius: Integer read FPointRadius write SetPointRadius default 4;
  end;

implementation

constructor TMCRadarChart.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FPointRadius := 4;
  SetLength(FPointRegions, 0);
end;

procedure TMCRadarChart.SetPointRadius(AValue: Integer);
begin
  if FPointRadius = AValue then Exit;
  FPointRadius := AValue;
  Invalidate;
end;

{ Menyesuaikan padding agar Radar Chart memiliki ruang untuk Label Kategori di sekelilingnya }
function TMCRadarChart.GetChartRect: TRect;
var
  MinDim: Integer;
begin
  Result := inherited GetChartRect;

  { Radar chart idealnya berbentuk persegi/lingkaran sempurna }
  MinDim := Min(Result.Right - Result.Left, Result.Bottom - Result.Top);

  FCX := Result.Left + (Result.Right - Result.Left) / 2;
  FCY := Result.Top + (Result.Bottom - Result.Top) / 2;

  { Sisakan sekitar 40 pixel margin untuk teks label kategori di ujung jaring }
  FRadius := (MinDim / 2) - 40;
  if FRadius < 0 then FRadius := 10;
end;

function TMCRadarChart.CheckHover(X, Y: Integer; out ALine1, ALine2: string): Boolean;
var
  i: Integer;
  Region: TPointRegion;
  Dataset: TMCChartDataset;
  Dist: Double;
begin
  Result := False;
  ALine1 := ''; ALine2 := '';

  if Length(FPointRegions) = 0 then Exit;

  for i := High(FPointRegions) downto 0 do
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

procedure TMCRadarChart.DrawGridAndAxes;
var
  GridBGRA: TBGRAPixel;
  NumTicks, i, j: Integer;
  Angle, Rad, R, ValMin, ValMax, CurrentValue: Double;
  Pts: array of TPointF;
  LabelStr: string;
  TextAlign: TAlignment; { PERBAIKAN: Mengubah nama variabel dari Align menjadi TextAlign }
  TextX, TextY: Double;
begin
  if Labels.Count < 3 then Exit; { Radar chart butuh minimal 3 sumbu (segitiga) }

  GetChartRect; { Panggil untuk menghitung FCX, FCY, FRadius }
  GridBGRA := ColorToBGRAAlpha(GridColor, GridAlpha);

  FBuffer.FontName := Font.Name;
  FBuffer.FontHeight := Abs(Font.Height);
  if FBuffer.FontHeight = 0 then FBuffer.FontHeight := Font.Size;
  if FBuffer.FontHeight = 0 then FBuffer.FontHeight := 12;
  FBuffer.FontStyle := Font.Style;
  FBuffer.FontAntialias := True;

  CalculateMinMax(ValMin, ValMax);
  NumTicks := 5;
  SetLength(Pts, Labels.Count);

  { 1. Gambar Jaring/Web (Grid Kosentris) }
  if ShowGrid then
  begin
    for i := 1 to NumTicks do
    begin
      R := (i / NumTicks) * FRadius;
      for j := 0 to Labels.Count - 1 do
      begin
        Angle := -90 + (j * 360 / Labels.Count);
        Rad := DegToRad(Angle);
        Pts[j] := PointF(FCX + R * Cos(Rad), FCY + R * Sin(Rad));
      end;
      FBuffer.DrawPolygonAntialias(Pts, GridBGRA, 1);

      { Gambar Label Angka Skala (di sumbu paling atas / j=0) }
      CurrentValue := ValMin + (i / NumTicks) * (ValMax - ValMin);
      LabelStr := FormatAxisLabel(CurrentValue);
      FBuffer.TextOut(Trunc(FCX + 5), Trunc(FCY - R - (FBuffer.FontHeight / 2)), LabelStr, ColorToBGRAAlpha(Font.Color, 200), taLeftJustify);
    end;
  end;

  { 2. Gambar Garis Radial (Dari pusat ke ujung) & Label Kategori }
  for j := 0 to Labels.Count - 1 do
  begin
    Angle := -90 + (j * 360 / Labels.Count);
    Rad := DegToRad(Angle);

    if ShowGrid then
      FBuffer.DrawLineAntialias(FCX, FCY, FCX + FRadius * Cos(Rad), FCY + FRadius * Sin(Rad), GridBGRA, 1);

    { Posisi Label Kategori (sedikit lebih jauh dari FRadius) }
    TextX := FCX + (FRadius + 15) * Cos(Rad);
    TextY := FCY + (FRadius + 15) * Sin(Rad);

    { Penyesuaian perataan teks berdasarkan sudut letaknya }
    if (Angle = -90) or (Angle = 90) or (Angle = 270) then
      TextAlign := taCenter
    else if (Angle > -90) and (Angle < 90) then
      TextAlign := taLeftJustify
    else
      TextAlign := taRightJustify;

    LabelStr := Labels[j];
    FBuffer.TextOut(Trunc(TextX), Trunc(TextY - (FBuffer.FontHeight / 2)), LabelStr, ColorToBGRAAlpha(Font.Color, 255), TextAlign);
  end;
end;

procedure TMCRadarChart.DrawChart;
var
  i, j, RegionIdx: Integer;
  ValMin, ValMax, Val, R, Angle, Rad: Double;
  Dataset: TMCChartDataset;
  Pts: array of TPointF;
  ValStr: string;
begin
  if (Labels.Count < 3) or (Datasets.Count = 0) then Exit;

  CalculateMinMax(ValMin, ValMax);
  SetLength(FPointRegions, Labels.Count * Datasets.Count);
  SetLength(Pts, Labels.Count);
  RegionIdx := 0;

  { Loop setiap Dataset }
  for i := 0 to Datasets.Count - 1 do
  begin
    Dataset := TMCChartDataset(Datasets.Items[i]);

    { 1. Hitung titik kordinat (X,Y) untuk setiap label pada dataset }
    for j := 0 to Labels.Count - 1 do
    begin
      if j < Dataset.Count then Val := Dataset.Values[j] else Val := 0;

      R := MapValue(Val, ValMin, ValMax, 0, FRadius);
      Angle := -90 + (j * 360 / Labels.Count);
      Rad := DegToRad(Angle);

      Pts[j] := PointF(FCX + R * Cos(Rad), FCY + R * Sin(Rad));

      { Simpan data titik ke memori untuk tooltip hover }
      FPointRegions[RegionIdx].Center := Pts[j];
      FPointRegions[RegionIdx].DatasetIndex := i;
      FPointRegions[RegionIdx].CategoryIndex := j;
      FPointRegions[RegionIdx].Value := Val;
      Inc(RegionIdx);
    end;

    { 2. Gambar area Polygon untuk Dataset tersebut (Area Isi dan Garis Border) }
    FBuffer.FillPolyAntialias(Pts, Dataset.GetBGRAFill);
    if Dataset.BorderWidth > 0 then
      FBuffer.DrawPolygonAntialias(Pts, Dataset.GetBGRABorder, Dataset.BorderWidth);

    { 3. Gambar titik-titik (Dots/Points) di sudut polygon }
    for j := 0 to Labels.Count - 1 do
    begin
      FBuffer.FillEllipseAntialias(Pts[j].X, Pts[j].Y, FPointRadius, FPointRadius, Dataset.GetBGRAFill);
      if Dataset.BorderWidth > 0 then
        FBuffer.EllipseAntialias(Pts[j].X, Pts[j].Y, FPointRadius, FPointRadius, Dataset.GetBGRABorder, Dataset.BorderWidth);

      { Fitur Data Labels jika diaktifkan }
      if ShowDataLabels then
      begin
        FBuffer.FontName := DataLabelFont.Name;
        FBuffer.FontHeight := Abs(DataLabelFont.Height);
        if FBuffer.FontHeight = 0 then FBuffer.FontHeight := DataLabelFont.Size;
        FBuffer.FontStyle := DataLabelFont.Style;

        if j < Dataset.Count then Val := Dataset.Values[j] else Val := 0;
        ValStr := FormatFloat('0.##', Val);

        FBuffer.TextOut(Trunc(Pts[j].X), Trunc(Pts[j].Y - FPointRadius - FBuffer.FontHeight - 5), ValStr, ColorToBGRAAlpha(DataLabelFont.Color, 255), taCenter);
      end;
    end;
  end;

  SetLength(FPointRegions, RegionIdx);
end;

end.
