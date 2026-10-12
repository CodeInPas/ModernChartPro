unit mc_stackedbarchart;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Graphics, Math,
  BGRABitmap, BGRABitmapTypes, BGRAPath,
  mc_types, mc_utils, mc_dataset, mc_basechart;

type
  TMCStackedBarChart = class(TMCBaseChart)
  private
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
    procedure CalculateMinMax(out AMin, AMax: Double); override;
    procedure DrawChart; override;

    function CheckHover(X, Y: Integer; out ALine1, ALine2: string): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Align;
    property BorderSpacing;
    property CategoryPadding: Integer read FCategoryPadding write FCategoryPadding default 15;
    property MaxBarThickness: Integer read FMaxBarThickness write SetMaxBarThickness default 60;
  end;

implementation

constructor TMCStackedBarChart.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCategoryPadding := 15;
  FMaxBarThickness := 60;
  SetLength(FBarRegions, 0);
end;

procedure TMCStackedBarChart.SetMaxBarThickness(AValue: Integer);
begin
  if FMaxBarThickness = AValue then Exit;
  FMaxBarThickness := AValue;
  Invalidate;
end;

function TMCStackedBarChart.CheckHover(X, Y: Integer; out ALine1, ALine2: string): Boolean;
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

{ Mengganti algoritma pencarian Min/Max dengan total penjumlahan bertumpuk (Stacked) }
procedure TMCStackedBarChart.CalculateMinMax(out AMin, AMax: Double);
var
  i, j: Integer;
  PosSum, NegSum, Val: Double;
  Dataset: TMCChartDataset;
begin
  if UseForcedYScale then
  begin
    AMin := ForceYMin; AMax := ForceYMax;
    Exit;
  end;

  AMin := 0; AMax := 0;
  if FDatasets.Count = 0 then Exit;

  for i := 0 to Labels.Count - 1 do
  begin
    PosSum := 0;
    NegSum := 0;

    for j := 0 to FDatasets.Count - 1 do
    begin
      Dataset := TMCChartDataset(FDatasets.Items[j]);
      if i < Dataset.Count then
      begin
        Val := Dataset.Values[i];
        if Val >= 0 then
          PosSum := PosSum + Val
        else
          NegSum := NegSum + Val;
      end;
    end;

    if PosSum > AMax then AMax := PosSum;
    if NegSum < AMin then AMin := NegSum;
  end;

  if AMax > 0 then AMax := AMax * 1.1;
  if AMin < 0 then AMin := AMin * 1.1;
end;

procedure TMCStackedBarChart.DrawRoundedBar(ARect: TRectF; ARadius: TMCBorderRadius;
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

procedure TMCStackedBarChart.DrawChart;
var
  ChartArea: TRect;
  i, j: Integer;
  DatasetCount, LabelCount, RegionIdx: Integer;
  CatWidth, SingleBarWidth: Double;
  CategoryOffset: Double;
  ZeroY, BaseX: Double;
  ValMin, ValMax, Val: Double;
  PosSum, NegSum, TopVal, BottomVal: Double;
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

  if (ValMin < 0) and (ValMax > 0) then ZeroY := MapValue(0, ValMin, ValMax, ChartArea.Bottom, ChartArea.Top)
  else if ValMax <= 0 then ZeroY := ChartArea.Top
  else ZeroY := ChartArea.Bottom;

  if (ValMin < 0) and (ValMax > 0) then
    FBuffer.DrawLineAntialias(ChartArea.Left, ZeroY, ChartArea.Right, ZeroY, BGRA(150, 150, 150, 255), 1.5);

  CatWidth := (ChartArea.Right - ChartArea.Left) / LabelCount;
  SingleBarWidth := CatWidth - (FCategoryPadding * 2);

  if (FMaxBarThickness > 0) and (SingleBarWidth > FMaxBarThickness) then
    SingleBarWidth := FMaxBarThickness;

  if SingleBarWidth <= 0 then SingleBarWidth := 1;

  CategoryOffset := (CatWidth - SingleBarWidth) / 2;

  SetLength(FBarRegions, LabelCount * DatasetCount);
  RegionIdx := 0;

  for i := 0 to LabelCount - 1 do
  begin
    BaseX := ChartArea.Left + (i * CatWidth) + CategoryOffset;

    { Variabel akumulator untuk menumpuk nilai }
    PosSum := 0;
    NegSum := 0;

    for j := 0 to DatasetCount - 1 do
    begin
      Dataset := TMCChartDataset(Datasets.Items[j]);
      if i < Dataset.Count then
      begin
        Val := Dataset.Values[i];

        BarRect.Left := BaseX;
        BarRect.Right := BaseX + SingleBarWidth;

        if Val >= 0 then
        begin
          BottomVal := PosSum;
          TopVal := PosSum + Val;
          PosSum := TopVal;

          BarRect.Bottom := MapValue(BottomVal, ValMin, ValMax, ChartArea.Bottom, ChartArea.Top);
          BarRect.Top := MapValue(TopVal, ValMin, ValMax, ChartArea.Bottom, ChartArea.Top);
        end
        else
        begin
          TopVal := NegSum;
          BottomVal := NegSum + Val;
          NegSum := BottomVal;

          BarRect.Top := MapValue(TopVal, ValMin, ValMax, ChartArea.Bottom, ChartArea.Top);
          BarRect.Bottom := MapValue(BottomVal, ValMin, ValMax, ChartArea.Bottom, ChartArea.Top);
        end;

        if Abs(BarRect.Bottom - BarRect.Top) < 1 then BarRect.Top := BarRect.Bottom - 1;

        DrawRoundedBar(BarRect, Dataset.GetRadiusRecord, Dataset.GetBGRAFill, Dataset.GetBGRABorder, Dataset.BorderWidth);

        FBarRegions[RegionIdx].Rect := BarRect;
        FBarRegions[RegionIdx].DatasetIndex := j;
        FBarRegions[RegionIdx].CategoryIndex := i;
        FBarRegions[RegionIdx].Value := Val;
        Inc(RegionIdx);

        if ShowDataLabels then
        begin
          FBuffer.FontName := DataLabelFont.Name;
          FBuffer.FontHeight := Abs(DataLabelFont.Height);
          if FBuffer.FontHeight = 0 then FBuffer.FontHeight := DataLabelFont.Size;
          FBuffer.FontStyle := DataLabelFont.Style;

          ValStr := FormatFloat('0.##', Val);
          DataLabelX := Trunc(BarRect.Left + (SingleBarWidth / 2));
          DataLabelY := Trunc(BarRect.Top + (Abs(BarRect.Bottom - BarRect.Top) / 2) - (FBuffer.FontHeight / 2));

          FBuffer.TextOut(DataLabelX, DataLabelY, ValStr, ColorToBGRAAlpha(DataLabelFont.Color, 255), taCenter);
        end;
      end;
    end;
  end;

  SetLength(FBarRegions, RegionIdx);
end;

end.
