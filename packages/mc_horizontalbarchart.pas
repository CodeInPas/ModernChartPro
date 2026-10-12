unit mc_horizontalbarchart;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Graphics, Math,
  BGRABitmap, BGRABitmapTypes, BGRAPath,
  mc_types, mc_utils, mc_dataset, mc_basechart;

type
  TMCHorizontalBarChart = class(TMCBaseChart)
  private
    FBarPadding: Integer;
    FCategoryPadding: Integer;
    FMaxBarThickness: Integer;

    type
      TBarRegion = record
        Rect: TRectF;
        DatasetIndex: Integer;
        CategoryIndex: Integer;
        Value: Double;
      end;

    var
      FBarRegions: array of TBarRegion;

    procedure SetMaxBarThickness(AValue: Integer);
    procedure DrawRoundedBar(ARect: TRectF; ARadius: TMCBorderRadius;
      AFillColor, ABorderColor: TBGRAPixel; ABorderWidth: Integer);
  protected
    procedure DrawChart; override;
    procedure DrawGridAndAxes; override;

    function CheckHover(X, Y: Integer; out ALine1, ALine2: string): Boolean; override;
    function GetChartRect: TRect; override; { Di-override untuk memodifikasi padding kiri }
  public
    constructor Create(AOwner: TComponent); override;
  published
    property BarPadding: Integer read FBarPadding write FBarPadding default 2;
    property CategoryPadding: Integer read FCategoryPadding write FCategoryPadding default 15;
    property MaxBarThickness: Integer read FMaxBarThickness write SetMaxBarThickness default 40;
  end;

implementation

constructor TMCHorizontalBarChart.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBarPadding := 2;
  FCategoryPadding := 15;
  FMaxBarThickness := 40;
  SetLength(FBarRegions, 0);
end;

procedure TMCHorizontalBarChart.SetMaxBarThickness(AValue: Integer);
begin
  if FMaxBarThickness = AValue then Exit;
  FMaxBarThickness := AValue;
  Invalidate;
end;

function TMCHorizontalBarChart.GetChartRect: TRect;
begin
  Result := inherited GetChartRect;
  { Ruang kiri diperlebar agar label kategori (Jan, Feb, dst) muat tanpa terpotong }
  if Result.Left < 80 then Result.Left := 80;
end;

function TMCHorizontalBarChart.CheckHover(X, Y: Integer; out ALine1, ALine2: string): Boolean;
var
  i: Integer;
  Region: TBarRegion;
  Dataset: TMCChartDataset;
begin
  Result := False;
  ALine1 := ''; ALine2 := '';

  if Length(FBarRegions) = 0 then Exit;

  for i := 0 to High(FBarRegions) do
  begin
    Region := FBarRegions[i];
    if (X >= Region.Rect.Left) and (X <= Region.Rect.Right) and
       (Y >= Min(Region.Rect.Top, Region.Rect.Bottom)) and
       (Y <= Max(Region.Rect.Top, Region.Rect.Bottom)) then
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

procedure TMCHorizontalBarChart.DrawRoundedBar(ARect: TRectF; ARadius: TMCBorderRadius;
  AFillColor, ABorderColor: TBGRAPixel; ABorderWidth: Integer);
var
  Path: TBGRAPath;
  MaxRad: Double;
begin
  MaxRad := Min(Abs(ARect.Right - ARect.Left), Abs(ARect.Bottom - ARect.Top)) / 2;
  ARadius.TopLeft := Min(ARadius.TopLeft, Trunc(MaxRad));
  ARadius.TopRight := Min(ARadius.TopRight, Trunc(MaxRad));
  ARadius.BottomRight := Min(ARadius.BottomRight, Trunc(MaxRad));
  ARadius.BottomLeft := Min(ARadius.BottomLeft, Trunc(MaxRad));

  Path := TBGRAPath.Create;
  try
    Path.moveTo(ARect.Left + ARadius.TopLeft, ARect.Top);
    Path.lineTo(ARect.Right - ARadius.TopRight, ARect.Top);
    if ARadius.TopRight > 0 then Path.quadraticCurveTo(ARect.Right, ARect.Top, ARect.Right, ARect.Top + ARadius.TopRight);

    Path.lineTo(ARect.Right, ARect.Bottom - ARadius.BottomRight);
    if ARadius.BottomRight > 0 then Path.quadraticCurveTo(ARect.Right, ARect.Bottom, ARect.Right - ARadius.BottomRight, ARect.Bottom);

    Path.lineTo(ARect.Left + ARadius.BottomLeft, ARect.Bottom);
    if ARadius.BottomLeft > 0 then Path.quadraticCurveTo(ARect.Left, ARect.Bottom, ARect.Left, ARect.Bottom - ARadius.BottomLeft);

    Path.lineTo(ARect.Left, ARect.Top + ARadius.TopLeft);
    if ARadius.TopLeft > 0 then Path.quadraticCurveTo(ARect.Left, ARect.Top, ARect.Left + ARadius.TopLeft, ARect.Top);
    Path.closePath;

    FBuffer.FillPath(Path, AFillColor);
    if ABorderWidth > 0 then FBuffer.DrawPath(Path, ABorderColor, ABorderWidth);
  finally
    Path.Free;
  end;
end;

procedure TMCHorizontalBarChart.DrawGridAndAxes;
var
  ChartArea: TRect;
  GridBGRA: TBGRAPixel;
  NumTicks, i: Integer;
  XPos, YPos: Double;
  CatHeight: Double;
  ValMin, ValMax, StepValue, CurrentValue: Double;
  LabelStr: string;
begin
  ChartArea := GetChartRect;

  { Menggunakan Properti yang sudah diekspos oleh TMCBaseChart (GridColor, GridAlpha) }
  GridBGRA := ColorToBGRAAlpha(GridColor, GridAlpha);

  FBuffer.FontName := Font.Name;
  FBuffer.FontHeight := Abs(Font.Height);
  if FBuffer.FontHeight = 0 then FBuffer.FontHeight := Font.Size;
  if FBuffer.FontHeight = 0 then FBuffer.FontHeight := 12;
  FBuffer.FontStyle := Font.Style;
  FBuffer.FontAntialias := True;

  { Gambar Garis Batas Kiri (Sumbu Y) dan Bawah (Sumbu X) }
  FBuffer.DrawLineAntialias(ChartArea.Left, ChartArea.Top, ChartArea.Left, ChartArea.Bottom, BGRA(150, 150, 150, 255), 1);
  FBuffer.DrawLineAntialias(ChartArea.Left, ChartArea.Bottom, ChartArea.Right, ChartArea.Bottom, BGRA(150, 150, 150, 255), 1);

  { Render Label Kategori (Sumbu Y - disebelah Kiri) }
  if Labels.Count > 0 then
  begin
    CatHeight := (ChartArea.Bottom - ChartArea.Top) / Labels.Count;
    for i := 0 to Labels.Count - 1 do
    begin
      YPos := ChartArea.Top + (i * CatHeight) + (CatHeight / 2);
      LabelStr := Labels[i];
      FBuffer.TextOut(ChartArea.Left - 10, Trunc(YPos - (FBuffer.FontHeight div 2)), LabelStr, ColorToBGRAAlpha(Font.Color, 255), taRightJustify);
    end;
  end;

  CalculateMinMax(ValMin, ValMax);
  NumTicks := 5;
  StepValue := (ValMax - ValMin) / NumTicks;

  { Render Grid Vertikal dan Label Angka (Sumbu X - dibawah) }
  for i := 0 to NumTicks do
  begin
    CurrentValue := ValMin + (i * StepValue);
    XPos := MapValue(CurrentValue, ValMin, ValMax, ChartArea.Left, ChartArea.Right);

    { Menggunakan Properti ShowGrid }
    if (ShowGrid) and (i > 0) then
      FBuffer.DrawLineAntialias(XPos, ChartArea.Top, XPos, ChartArea.Bottom, GridBGRA, 1);

    LabelStr := FormatAxisLabel(CurrentValue);
    FBuffer.TextOut(Trunc(XPos), ChartArea.Bottom + 10, LabelStr, ColorToBGRAAlpha(Font.Color, 255), taCenter);
  end;
end;

procedure TMCHorizontalBarChart.DrawChart;
var
  ChartArea: TRect;
  i, j: Integer;
  DatasetCount, LabelCount, RegionIdx: Integer;
  CatHeight, TotalBarHeight, SingleBarHeight: Double;
  ActualTotalBarHeight, CategoryOffset: Double;
  ZeroX, MappedX, BaseY: Double;
  ValMin, ValMax, Val: Double;
  BarRect: TRectF;
  Dataset: TMCChartDataset;
  ValStr: string;
  DataLabelX, DataLabelY: Integer;
begin
  LabelCount := Labels.Count;
  DatasetCount := Datasets.Count;

  if (LabelCount = 0) or (DatasetCount = 0) then Exit;

  ChartArea := GetChartRect;
  CalculateMinMax(ValMin, ValMax);

  { Titik 0 berada di Sumbu X Vertikal }
  if (ValMin < 0) and (ValMax > 0) then ZeroX := MapValue(0, ValMin, ValMax, ChartArea.Left, ChartArea.Right)
  else if ValMax <= 0 then ZeroX := ChartArea.Right
  else ZeroX := ChartArea.Left;

  if (ValMin < 0) and (ValMax > 0) then
    FBuffer.DrawLineAntialias(ZeroX, ChartArea.Top, ZeroX, ChartArea.Bottom, BGRA(150, 150, 150, 255), 1.5);

  { Hitung Tinggi Batang (Bar Sizing Vertical) }
  CatHeight := (ChartArea.Bottom - ChartArea.Top) / LabelCount;
  TotalBarHeight := CatHeight - (FCategoryPadding * 2);
  SingleBarHeight := (TotalBarHeight - (FBarPadding * (DatasetCount - 1))) / DatasetCount;

  if (FMaxBarThickness > 0) and (SingleBarHeight > FMaxBarThickness) then
    SingleBarHeight := FMaxBarThickness;

  if SingleBarHeight <= 0 then SingleBarHeight := 1;

  ActualTotalBarHeight := (SingleBarHeight * DatasetCount) + (FBarPadding * (DatasetCount - 1));
  CategoryOffset := (CatHeight - ActualTotalBarHeight) / 2;

  SetLength(FBarRegions, LabelCount * DatasetCount);
  RegionIdx := 0;

  for i := 0 to LabelCount - 1 do
  begin
    BaseY := ChartArea.Top + (i * CatHeight) + CategoryOffset;

    for j := 0 to DatasetCount - 1 do
    begin
      Dataset := TMCChartDataset(Datasets.Items[j]);
      if i < Dataset.Count then
      begin
        Val := Dataset.Values[i];
        MappedX := MapValue(Val, ValMin, ValMax, ChartArea.Left, ChartArea.Right);

        BarRect.Top := BaseY + (j * (SingleBarHeight + FBarPadding));
        BarRect.Bottom := BarRect.Top + SingleBarHeight;

        { Arah Pertumbuhan Batang }
        if Val >= 0 then
        begin
          BarRect.Left := ZeroX;
          BarRect.Right := MappedX;
        end
        else
        begin
          BarRect.Left := MappedX;
          BarRect.Right := ZeroX;
        end;

        if Abs(BarRect.Right - BarRect.Left) < 1 then BarRect.Right := BarRect.Left + 1;

        DrawRoundedBar(BarRect, Dataset.GetRadiusRecord, Dataset.GetBGRAFill, Dataset.GetBGRABorder, Dataset.BorderWidth);

        FBarRegions[RegionIdx].Rect := BarRect;
        FBarRegions[RegionIdx].DatasetIndex := j;
        FBarRegions[RegionIdx].CategoryIndex := i;
        FBarRegions[RegionIdx].Value := Val;
        Inc(RegionIdx);

        { Data Labels (Di ujung kanan/kiri Batang) }
        if ShowDataLabels then
        begin
          FBuffer.FontName := DataLabelFont.Name;
          FBuffer.FontHeight := Abs(DataLabelFont.Height);
          if FBuffer.FontHeight = 0 then FBuffer.FontHeight := DataLabelFont.Size;
          FBuffer.FontStyle := DataLabelFont.Style;

          ValStr := FormatFloat('0.##', Val);
          DataLabelY := Trunc(BarRect.Top + (SingleBarHeight / 2) - (FBuffer.FontHeight / 2));

          if Val >= 0 then
          begin
            DataLabelX := Trunc(BarRect.Right + 5);
            FBuffer.TextOut(DataLabelX, DataLabelY, ValStr, ColorToBGRAAlpha(DataLabelFont.Color, 255), taLeftJustify);
          end
          else
          begin
            DataLabelX := Trunc(BarRect.Left - 5);
            FBuffer.TextOut(DataLabelX, DataLabelY, ValStr, ColorToBGRAAlpha(DataLabelFont.Color, 255), taRightJustify);
          end;
        end;
      end;
    end;
  end;

  SetLength(FBarRegions, RegionIdx);
end;

end.
