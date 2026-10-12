unit mc_combochart;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Graphics, Math,
  BGRABitmap, BGRABitmapTypes, BGRAPath,
  mc_types, mc_utils, mc_dataset, mc_basechart;

type
  TMCComboChart = class(TMCBaseChart)
  private
    FBarPadding: Integer;
    FCategoryPadding: Integer;
    FMaxBarThickness: Integer;
    FPointRadius: Integer;

    type
      TBarRegion = record Rect: TRectF; DatasetIndex, CategoryIndex: Integer; Value: Double; end;
      TPointRegion = record Center: TPointF; DatasetIndex, CategoryIndex: Integer; Value: Double; end;

    var
      FBarRegions: array of TBarRegion;
      FPointRegions: array of TPointRegion;

    procedure SetMaxBarThickness(AValue: Integer);
    procedure SetPointRadius(AValue: Integer);
    procedure DrawRoundedBar(ARect: TRectF; ARadius: TMCBorderRadius; AFillColor, ABorderColor: TBGRAPixel; ABorderWidth: Integer);
  protected
    procedure DrawChart; override;
    procedure DrawGridAndAxes; override;
    function CheckHover(X, Y: Integer; out ALine1, ALine2: string): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
  property Align;
  property BorderSpacing;
    property BarPadding: Integer read FBarPadding write FBarPadding default 2;
    property CategoryPadding: Integer read FCategoryPadding write FCategoryPadding default 15;
    property MaxBarThickness: Integer read FMaxBarThickness write SetMaxBarThickness default 40;
    property PointRadius: Integer read FPointRadius write SetPointRadius default 5;
  end;

implementation

constructor TMCComboChart.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBarPadding := 2;
  FCategoryPadding := 15;
  FMaxBarThickness := 40;
  FPointRadius := 5;
  SetLength(FBarRegions, 0);
  SetLength(FPointRegions, 0);
end;

procedure TMCComboChart.SetMaxBarThickness(AValue: Integer); begin if FMaxBarThickness = AValue then Exit; FMaxBarThickness := AValue; Invalidate; end;
procedure TMCComboChart.SetPointRadius(AValue: Integer); begin if FPointRadius = AValue then Exit; FPointRadius := AValue; Invalidate; end;

function TMCComboChart.CheckHover(X, Y: Integer; out ALine1, ALine2: string): Boolean;
var
  i: Integer; Dist: Double; Dataset: TMCChartDataset;
begin
  Result := False; ALine1 := ''; ALine2 := '';

  { Prioritas 1: Cek Titik Line Chart (karena berada di layer paling atas) }
  for i := High(FPointRegions) downto 0 do
  begin
    Dist := Hypot(X - FPointRegions[i].Center.X, Y - FPointRegions[i].Center.Y);
    if Dist <= (FPointRadius + 5) then
    begin
      Dataset := TMCChartDataset(FDatasets.Items[FPointRegions[i].DatasetIndex]);
      if (FPointRegions[i].CategoryIndex >= 0) and (FPointRegions[i].CategoryIndex < Labels.Count) then
        ALine1 := Labels[FPointRegions[i].CategoryIndex] else ALine1 := 'Kategori ' + IntToStr(FPointRegions[i].CategoryIndex + 1);
      ALine2 := Dataset.LabelName + ': ' + FormatFloat('0.##', FPointRegions[i].Value);
      Exit(True);
    end;
  end;

  { Prioritas 2: Cek Batang Chart (Bar) di bawahnya }
  for i := High(FBarRegions) downto 0 do
  begin
    if (X >= FBarRegions[i].Rect.Left) and (X <= FBarRegions[i].Rect.Right) and
       (Y >= Min(FBarRegions[i].Rect.Top, FBarRegions[i].Rect.Bottom)) and
       (Y <= Max(FBarRegions[i].Rect.Top, FBarRegions[i].Rect.Bottom)) then
    begin
      Dataset := TMCChartDataset(FDatasets.Items[FBarRegions[i].DatasetIndex]);
      if (FBarRegions[i].CategoryIndex >= 0) and (FBarRegions[i].CategoryIndex < Labels.Count) then
        ALine1 := Labels[FBarRegions[i].CategoryIndex] else ALine1 := 'Kategori ' + IntToStr(FBarRegions[i].CategoryIndex + 1);
      ALine2 := Dataset.LabelName + ': ' + FormatFloat('0.##', FBarRegions[i].Value);
      Exit(True);
    end;
  end;
end;

procedure TMCComboChart.DrawRoundedBar(ARect: TRectF; ARadius: TMCBorderRadius; AFillColor, ABorderColor: TBGRAPixel; ABorderWidth: Integer);
var Path: TBGRAPath; MaxRad: Double;
begin
  MaxRad := Min(ARect.Right - ARect.Left, Abs(ARect.Bottom - ARect.Top)) / 2;
  ARadius.TopLeft := Min(ARadius.TopLeft, Trunc(MaxRad)); ARadius.TopRight := Min(ARadius.TopRight, Trunc(MaxRad));
  ARadius.BottomRight := Min(ARadius.BottomRight, Trunc(MaxRad)); ARadius.BottomLeft := Min(ARadius.BottomLeft, Trunc(MaxRad));
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

procedure TMCComboChart.DrawGridAndAxes;
var ChartArea: TRect; GridBGRA: TBGRAPixel; NumTicks, i: Integer; YPos, XPos, CatWidth: Double; ValMin, ValMax, StepValue, CurrentValue: Double; LabelStr: string;
begin
  ChartArea := GetChartRect; GridBGRA := ColorToBGRAAlpha(GridColor, GridAlpha);
  FBuffer.FontName := Font.Name; FBuffer.FontHeight := Abs(Font.Height);
  if FBuffer.FontHeight = 0 then FBuffer.FontHeight := Font.Size; if FBuffer.FontHeight = 0 then FBuffer.FontHeight := 12;
  FBuffer.FontStyle := Font.Style; FBuffer.FontAntialias := True;
  FBuffer.DrawLineAntialias(ChartArea.Left, ChartArea.Top, ChartArea.Left, ChartArea.Bottom, BGRA(150, 150, 150, 255), 1);
  FBuffer.DrawLineAntialias(ChartArea.Left, ChartArea.Bottom, ChartArea.Right, ChartArea.Bottom, BGRA(150, 150, 150, 255), 1);
  if Labels.Count = 0 then Exit;
  CalculateMinMax(ValMin, ValMax); NumTicks := 5; StepValue := (ValMax - ValMin) / NumTicks;

  for i := 0 to NumTicks do
  begin
    CurrentValue := ValMin + (i * StepValue); YPos := MapValue(CurrentValue, ValMin, ValMax, ChartArea.Bottom, ChartArea.Top);
    if (ShowGrid) and (i > 0) then FBuffer.DrawLineAntialias(ChartArea.Left, YPos, ChartArea.Right, YPos, GridBGRA, 1);
    LabelStr := FormatAxisLabel(CurrentValue);
    FBuffer.TextOut(ChartArea.Left - 8, YPos - (FBuffer.FontHeight div 2), LabelStr, ColorToBGRAAlpha(Font.Color, 255), taRightJustify);
  end;

  CatWidth := (ChartArea.Right - ChartArea.Left) / Labels.Count;
  for i := 0 to Labels.Count - 1 do
  begin
    XPos := ChartArea.Left + (i * CatWidth) + (CatWidth / 2);
    LabelStr := Labels[i];
    FBuffer.TextOut(Trunc(XPos), ChartArea.Bottom + 10, LabelStr, ColorToBGRAAlpha(Font.Color, 255), taCenter);
  end;
end;

procedure TMCComboChart.DrawChart;
var
  ChartArea: TRect; i, j, RegionBarIdx, RegionPointIdx, BarDatasetCount, CurrentBarIndex: Integer;
  CatWidth, SingleBarWidth, TotalBarWidth, ActualTotalBarWidth, CategoryOffset: Double;
  ZeroY, BaseX, XPos, YPos, PrevX, PrevY: Double; ValMin, ValMax, Val: Double;
  BarRect: TRectF; Dataset: TMCChartDataset; ValStr: string;
begin
  if (Labels.Count = 0) or (Datasets.Count = 0) then Exit;

  ChartArea := GetChartRect; CalculateMinMax(ValMin, ValMax);
  if (ValMin < 0) and (ValMax > 0) then ZeroY := MapValue(0, ValMin, ValMax, ChartArea.Bottom, ChartArea.Top)
  else if ValMax <= 0 then ZeroY := ChartArea.Top else ZeroY := ChartArea.Bottom;

  if (ValMin < 0) and (ValMax > 0) then FBuffer.DrawLineAntialias(ChartArea.Left, ZeroY, ChartArea.Right, ZeroY, BGRA(150, 150, 150, 255), 1.5);

  CatWidth := (ChartArea.Right - ChartArea.Left) / Labels.Count;

  { Hitung berapa banyak Dataset yang bertipe Bar untuk menentukan lebar batang }
  BarDatasetCount := 0;
  for j := 0 to Datasets.Count - 1 do
    if TMCChartDataset(Datasets.Items[j]).SeriesType = stBar then Inc(BarDatasetCount);

  SingleBarWidth := 0; CategoryOffset := 0;
  if BarDatasetCount > 0 then
  begin
    TotalBarWidth := CatWidth - (FCategoryPadding * 2);
    SingleBarWidth := (TotalBarWidth - (FBarPadding * (BarDatasetCount - 1))) / BarDatasetCount;
    if (FMaxBarThickness > 0) and (SingleBarWidth > FMaxBarThickness) then SingleBarWidth := FMaxBarThickness;
    if SingleBarWidth <= 0 then SingleBarWidth := 1;
    ActualTotalBarWidth := (SingleBarWidth * BarDatasetCount) + (FBarPadding * (BarDatasetCount - 1));
    CategoryOffset := (CatWidth - ActualTotalBarWidth) / 2;
  end;

  SetLength(FBarRegions, Labels.Count * BarDatasetCount);
  SetLength(FPointRegions, Labels.Count * (Datasets.Count - BarDatasetCount));
  RegionBarIdx := 0; RegionPointIdx := 0;

  { TAHAP 1: Render Bar Chart (Layer Bawah) }
  CurrentBarIndex := 0;
  for j := 0 to Datasets.Count - 1 do
  begin
    Dataset := TMCChartDataset(Datasets.Items[j]);
    if Dataset.SeriesType = stBar then
    begin
      for i := 0 to Min(Labels.Count - 1, Dataset.Count - 1) do
      begin
        Val := Dataset.Values[i]; BaseX := ChartArea.Left + (i * CatWidth) + CategoryOffset;
        BarRect.Left := BaseX + (CurrentBarIndex * (SingleBarWidth + FBarPadding));
        BarRect.Right := BarRect.Left + SingleBarWidth;

        if Val >= 0 then begin BarRect.Top := MapValue(Val, ValMin, ValMax, ChartArea.Bottom, ChartArea.Top); BarRect.Bottom := ZeroY; end
        else begin BarRect.Top := ZeroY; BarRect.Bottom := MapValue(Val, ValMin, ValMax, ChartArea.Bottom, ChartArea.Top); end;
        if Abs(BarRect.Bottom - BarRect.Top) < 1 then BarRect.Top := BarRect.Bottom - 1;

        DrawRoundedBar(BarRect, Dataset.GetRadiusRecord, Dataset.GetBGRAFill, Dataset.GetBGRABorder, Dataset.BorderWidth);
        FBarRegions[RegionBarIdx].Rect := BarRect; FBarRegions[RegionBarIdx].DatasetIndex := j; FBarRegions[RegionBarIdx].CategoryIndex := i; FBarRegions[RegionBarIdx].Value := Val; Inc(RegionBarIdx);

        if ShowDataLabels then
        begin
          FBuffer.FontName := DataLabelFont.Name; FBuffer.FontHeight := Abs(DataLabelFont.Height);
          if FBuffer.FontHeight = 0 then FBuffer.FontHeight := DataLabelFont.Size; FBuffer.FontStyle := DataLabelFont.Style;
          ValStr := FormatFloat('0.##', Val);
          if Val >= 0 then FBuffer.TextOut(Trunc(BarRect.Left + (SingleBarWidth / 2)), Trunc(BarRect.Top - 5), ValStr, ColorToBGRAAlpha(DataLabelFont.Color, 255), taCenter)
          else FBuffer.TextOut(Trunc(BarRect.Left + (SingleBarWidth / 2)), Trunc(BarRect.Bottom + 5 + FBuffer.FontHeight), ValStr, ColorToBGRAAlpha(DataLabelFont.Color, 255), taCenter);
        end;
      end;
      Inc(CurrentBarIndex);
    end;
  end;

  { TAHAP 2: Render Line Chart (Layer Atas) }
  for j := 0 to Datasets.Count - 1 do
  begin
    Dataset := TMCChartDataset(Datasets.Items[j]);
    if Dataset.SeriesType = stLine then
    begin
      PrevX := -1; PrevY := -1;
      for i := 0 to Min(Labels.Count - 1, Dataset.Count - 1) do
      begin
        Val := Dataset.Values[i]; XPos := ChartArea.Left + (i * CatWidth) + (CatWidth / 2);
        YPos := MapValue(Val, ValMin, ValMax, ChartArea.Bottom, ChartArea.Top);
        if i > 0 then FBuffer.DrawLineAntialias(PrevX, PrevY, XPos, YPos, Dataset.GetBGRABorder, Dataset.BorderWidth);
        PrevX := XPos; PrevY := YPos;
      end;

      for i := 0 to Min(Labels.Count - 1, Dataset.Count - 1) do
      begin
        Val := Dataset.Values[i]; XPos := ChartArea.Left + (i * CatWidth) + (CatWidth / 2);
        YPos := MapValue(Val, ValMin, ValMax, ChartArea.Bottom, ChartArea.Top);
        FBuffer.FillEllipseAntialias(XPos, YPos, FPointRadius, FPointRadius, Dataset.GetBGRAFill);
        if Dataset.BorderWidth > 0 then FBuffer.EllipseAntialias(XPos, YPos, FPointRadius, FPointRadius, Dataset.GetBGRABorder, Dataset.BorderWidth);

        FPointRegions[RegionPointIdx].Center.X := XPos; FPointRegions[RegionPointIdx].Center.Y := YPos;
        FPointRegions[RegionPointIdx].DatasetIndex := j; FPointRegions[RegionPointIdx].CategoryIndex := i; FPointRegions[RegionPointIdx].Value := Val; Inc(RegionPointIdx);

        if ShowDataLabels then
        begin
          FBuffer.FontName := DataLabelFont.Name; FBuffer.FontHeight := Abs(DataLabelFont.Height);
          if FBuffer.FontHeight = 0 then FBuffer.FontHeight := DataLabelFont.Size; FBuffer.FontStyle := DataLabelFont.Style;
          ValStr := FormatFloat('0.##', Val);
          FBuffer.TextOut(Trunc(XPos), Trunc(YPos - FPointRadius - FBuffer.FontHeight - 5), ValStr, ColorToBGRAAlpha(DataLabelFont.Color, 255), taCenter);
        end;
      end;
    end;
  end;
  SetLength(FBarRegions, RegionBarIdx); SetLength(FPointRegions, RegionPointIdx);
end;

end.
