{ =========================================================================
  FILE BARU: src/charts/mc_piechart.pas
  Komponen: TMCPieChart
  Deskripsi: Pie chart untuk visualisasi proporsi dengan sudut 360 derajat.
  ========================================================================= }
unit mc_piechart;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Graphics, Math,
  BGRABitmap, BGRABitmapTypes, BGRAPath,
  mc_types, mc_utils, mc_dataset, mc_basechart;

type
  TMCPieChart = class(TMCBaseChart)
  private
    FCX, FCY: Double;
    FRadius: Double;

    type
      TPieRegion = record
        StartAngle: Double;
        EndAngle: Double;
        DatasetIndex: Integer;
        Value: Double;
      end;

    var
      FPieRegions: array of TPieRegion;

    { PERBAIKAN: Mengubah nama parameter BorderWidth menjadi ABorderWidth agar tidak bentrok dengan properti bawaan TCustomControl }
    procedure DrawPieSlice(CX, CY, Radius, StartAngle, SweepAngle: Double; FillColor, BorderColor: TBGRAPixel; ABorderWidth: Integer);
  protected
    procedure DrawChart; override;

    { Grid dan Garis Sumbu ditiadakan untuk Pie Chart }
    procedure DrawGridAndAxes; override;

    function CheckHover(X, Y: Integer; out ALine1, ALine2: string): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Align;
    property BorderSpacing;
  end;

implementation

constructor TMCPieChart.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  SetLength(FPieRegions, 0);
end;

{ Pie Chart tidak membutuhkan Garis Grid dan Sumbu }
procedure TMCPieChart.DrawGridAndAxes;
begin
  // Dikosongkan secara sengaja
end;

{ Menggambar poligon melengkung untuk membentuk potongan pie }
procedure TMCPieChart.DrawPieSlice(CX, CY, Radius, StartAngle, SweepAngle: Double; FillColor, BorderColor: TBGRAPixel; ABorderWidth: Integer);
var
  pts: array of TPointF;
  i, steps: Integer;
  rad: Double;
begin
  if SweepAngle <= 0 then Exit;

  { Jika satu dataset mendominasi 100% penuh (360 derajat) }
  if SweepAngle >= 359.9 then
  begin
    FBuffer.FillEllipseAntialias(CX, CY, Radius, Radius, FillColor);
    if ABorderWidth > 0 then
      FBuffer.EllipseAntialias(CX, CY, Radius, Radius, BorderColor, ABorderWidth);
    Exit;
  end;

  { Menghitung titik polygon pinggiran kurva secara manual agar sangat mulus }
  steps := Max(15, Trunc(SweepAngle * Radius / 15));
  SetLength(pts, steps + 2);

  pts[0] := PointF(CX, CY); // Titik pusat

  for i := 0 to steps do
  begin
    rad := DegToRad(StartAngle + (i / steps) * SweepAngle);
    pts[i + 1] := PointF(CX + cos(rad) * Radius, CY + sin(rad) * Radius);
  end;

  FBuffer.FillPolyAntialias(pts, FillColor);
  if ABorderWidth > 0 then
    FBuffer.DrawPolygonAntialias(pts, BorderColor, ABorderWidth);
end;

{ Logika Hover: Menggunakan jarak dari pusat dan sudut kemiringan kursor }
function TMCPieChart.CheckHover(X, Y: Integer; out ALine1, ALine2: string): Boolean;
var
  Dist, MouseAngle, RadAngle: Double;
  i: Integer;
  Region: TPieRegion;
  Dataset: TMCChartDataset;
  Hit: Boolean;
begin
  Result := False;
  ALine1 := ''; ALine2 := '';

  if Length(FPieRegions) = 0 then Exit;

  { Cek apakah kursor berada di dalam radius lingkaran }
  Dist := Hypot(X - FCX, Y - FCY);
  if Dist > FRadius then Exit;

  { Hitung sudut kursor dari titik tengah }
  RadAngle := ArcTan2(Y - FCY, X - FCX);
  MouseAngle := RadToDeg(RadAngle);

  { Normalisasi sudut ke 0..360 }
  while MouseAngle < 0 do MouseAngle := MouseAngle + 360;
  while MouseAngle >= 360 do MouseAngle := MouseAngle - 360;

  for i := 0 to High(FPieRegions) do
  begin
    Region := FPieRegions[i];

    if Region.StartAngle < Region.EndAngle then
      Hit := (MouseAngle >= Region.StartAngle) and (MouseAngle <= Region.EndAngle)
    else
      Hit := (MouseAngle >= Region.StartAngle) or (MouseAngle <= Region.EndAngle);

    if Hit then
    begin
      Dataset := TMCChartDataset(FDatasets.Items[Region.DatasetIndex]);
      ALine1 := Dataset.LabelName;
      ALine2 := FormatFloat('0.##', Region.Value);
      Result := True;
      Break;
    end;
  end;
end;

procedure TMCPieChart.DrawChart;
var
  ChartArea: TRect;
  i, RegionIdx: Integer;
  Total, Val, SweepAngle, CurrentAngle, MidAngle, MidRad: Double;
  LabelX, LabelY: Double;
  Dataset: TMCChartDataset;
  ValStr: string;
begin
  if Datasets.Count = 0 then Exit;

  ChartArea := GetChartRect;

  FCX := ChartArea.Left + (ChartArea.Right - ChartArea.Left) / 2;
  FCY := ChartArea.Top + (ChartArea.Bottom - ChartArea.Top) / 2;
  FRadius := Min(ChartArea.Right - ChartArea.Left, ChartArea.Bottom - ChartArea.Top) / 2;
  FRadius := FRadius - 10; { Beri margin 10px agar tidak menabrak batas }

  if FRadius <= 0 then Exit;

  { 1. Hitung Total Nilai Keseluruhan }
  Total := 0;
  for i := 0 to Datasets.Count - 1 do
  begin
    Dataset := TMCChartDataset(Datasets.Items[i]);
    if Dataset.Count > 0 then
      Total := Total + Max(0, Dataset.Values[0]); { Pie Chart mengabaikan nilai negatif }
  end;

  if Total <= 0 then Exit;

  SetLength(FPieRegions, Datasets.Count);
  RegionIdx := 0;
  CurrentAngle := -90; { Dimulai dari jam 12 atas }

  { 2. Render Potongan Pie per Dataset }
  for i := 0 to Datasets.Count - 1 do
  begin
    Dataset := TMCChartDataset(Datasets.Items[i]);
    if Dataset.Count > 0 then
    begin
      Val := Max(0, Dataset.Values[0]);
      if Val > 0 then
      begin
        SweepAngle := (Val / Total) * 360;

        { Memanggil DrawPieSlice dengan ABorderWidth }
        DrawPieSlice(FCX, FCY, FRadius, CurrentAngle, SweepAngle, Dataset.GetBGRAFill, Dataset.GetBGRABorder, Dataset.BorderWidth);

        { Simpan sudut ke memori untuk tooltip (Dinormalisasi 0..360) }
        if SweepAngle >= 359.9 then
        begin
          FPieRegions[RegionIdx].StartAngle := 0;
          FPieRegions[RegionIdx].EndAngle := 359.99;
        end
        else
        begin
          FPieRegions[RegionIdx].StartAngle := CurrentAngle;
          while FPieRegions[RegionIdx].StartAngle < 0 do FPieRegions[RegionIdx].StartAngle := FPieRegions[RegionIdx].StartAngle + 360;
          while FPieRegions[RegionIdx].StartAngle >= 360 do FPieRegions[RegionIdx].StartAngle := FPieRegions[RegionIdx].StartAngle - 360;

          FPieRegions[RegionIdx].EndAngle := CurrentAngle + SweepAngle;
          while FPieRegions[RegionIdx].EndAngle < 0 do FPieRegions[RegionIdx].EndAngle := FPieRegions[RegionIdx].EndAngle + 360;
          while FPieRegions[RegionIdx].EndAngle >= 360 do FPieRegions[RegionIdx].EndAngle := FPieRegions[RegionIdx].EndAngle - 360;
        end;

        FPieRegions[RegionIdx].DatasetIndex := i;
        FPieRegions[RegionIdx].Value := Val;
        Inc(RegionIdx);

        { 3. Render Data Labels di tengah-tengah potongan Pie }
        if ShowDataLabels then
        begin
          FBuffer.FontName := DataLabelFont.Name;
          FBuffer.FontHeight := Abs(DataLabelFont.Height);
          if FBuffer.FontHeight = 0 then FBuffer.FontHeight := DataLabelFont.Size;
          FBuffer.FontStyle := DataLabelFont.Style;

          ValStr := FormatFloat('0.##', Val);
          MidAngle := CurrentAngle + (SweepAngle / 2);
          MidRad := DegToRad(MidAngle);

          { Posisikan teks di 65% jarak dari tengah menuju tepi luar }
          LabelX := FCX + cos(MidRad) * (FRadius * 0.65);
          LabelY := FCY + sin(MidRad) * (FRadius * 0.65);

          FBuffer.TextOut(Trunc(LabelX), Trunc(LabelY - (FBuffer.FontHeight / 2)), ValStr, ColorToBGRAAlpha(DataLabelFont.Color, 255), taCenter);
        end;

        CurrentAngle := CurrentAngle + SweepAngle;
      end;
    end;
  end;

  SetLength(FPieRegions, RegionIdx);
end;

end.
