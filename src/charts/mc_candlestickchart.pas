{ =========================================================================
  FILE BARU: src/charts/mc_candlestickchart.pas
  Komponen: TMCCandlestickChart
  Deskripsi: Candlestick chart untuk data keuangan/saham (Open, High, Low, Close).
  ========================================================================= }
unit mc_candlestickchart;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Graphics, Math,
  BGRABitmap, BGRABitmapTypes, BGRAPath,
  mc_types, mc_utils, mc_dataset, mc_basechart;

type
  TMCCandlestickChart = class(TMCBaseChart)
  private
    FCategoryPadding: Integer;
    FMaxCandleWidth: Integer;

    { Warna khusus untuk tren naik (Bullish) dan turun (Bearish) }
    FBullishColor: TColor; { Close >= Open }
    FBearishColor: TColor; { Close < Open }

    type
      TCandleData = record
        OpenVal, HighVal, LowVal, CloseVal: Double;
      end;

      TCandleRegion = record
        Rect: TRectF;
        DatasetIndex: Integer;
        CategoryIndex: Integer;
        Data: TCandleData;
      end;

    var
      FCandleRegions: array of TCandleRegion;

    procedure SetBullishColor(AValue: TColor);
    procedure SetBearishColor(AValue: TColor);
    procedure SetMaxCandleWidth(AValue: Integer);
  protected
    procedure CalculateMinMax(out AMin, AMax: Double); override;
    procedure DrawChart; override;
    procedure DrawGridAndAxes; override;
    function CheckHover(X, Y: Integer; out ALine1, ALine2: string): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Align;
    property BorderSpacing;
    property CategoryPadding: Integer read FCategoryPadding write FCategoryPadding default 15;
    property MaxCandleWidth: Integer read FMaxCandleWidth write SetMaxCandleWidth default 30;
    property BullishColor: TColor read FBullishColor write SetBullishColor default $0000D7FF; { Cyan / Biru Cerah }
    property BearishColor: TColor read FBearishColor write SetBearishColor default $000080FF; { Oranye }
  end;

implementation

constructor TMCCandlestickChart.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCategoryPadding := 15;
  FMaxCandleWidth := 30;
  FBullishColor := $0000D7FF;
  FBearishColor := $000080FF;
  SetLength(FCandleRegions, 0);
end;

procedure TMCCandlestickChart.SetBullishColor(AValue: TColor);
begin
  if FBullishColor = AValue then Exit;
  FBullishColor := AValue;
  Invalidate;
end;

procedure TMCCandlestickChart.SetBearishColor(AValue: TColor);
begin
  if FBearishColor = AValue then Exit;
  FBearishColor := AValue;
  Invalidate;
end;

procedure TMCCandlestickChart.SetMaxCandleWidth(AValue: Integer);
begin
  if FMaxCandleWidth = AValue then Exit;
  FMaxCandleWidth := AValue;
  Invalidate;
end;

{ Kalkulasi Min dan Max berdasarkan titik High tertinggi dan Low terendah }
procedure TMCCandlestickChart.CalculateMinMax(out AMin, AMax: Double);
var
  i, k: Integer;
  Dataset: TMCChartDataset;
  HighVal, LowVal: Double;
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
    { Setiap candlestick membutuhkan 4 nilai: [Open, High, Low, Close] }
    for k := 0 to (Dataset.Count div 4) - 1 do
    begin
      HighVal := Dataset.Values[(k * 4) + 1];
      LowVal  := Dataset.Values[(k * 4) + 2];

      if (i = 0) and (k = 0) then
      begin
        AMin := LowVal; AMax := HighVal;
      end
      else
      begin
        if HighVal > AMax then AMax := HighVal;
        if LowVal < AMin then AMin := LowVal;
      end;
    end;
  end;

  if AMax > 0 then AMax := AMax * 1.1;
  if AMin < 0 then AMin := AMin * 1.1;
end;

function TMCCandlestickChart.CheckHover(X, Y: Integer; out ALine1, ALine2: string): Boolean;
var
  i: Integer;
  Region: TCandleRegion;
  Dataset: TMCChartDataset;
begin
  Result := False;
  ALine1 := ''; ALine2 := '';

  if Length(FCandleRegions) = 0 then Exit;

  for i := High(FCandleRegions) downto 0 do
  begin
    Region := FCandleRegions[i];
    { Deteksi area hover pada badan lilin (Candle Body) atau sumbunya }
    if (X >= Region.Rect.Left - 3) and (X <= Region.Rect.Right + 3) and
       (Y >= Min(Region.Rect.Top, Region.Rect.Bottom) - 10) and
       (Y <= Max(Region.Rect.Top, Region.Rect.Bottom) + 10) then
    begin
      Dataset := TMCChartDataset(FDatasets.Items[Region.DatasetIndex]);
      if (Region.CategoryIndex >= 0) and (Region.CategoryIndex < Labels.Count) then
        ALine1 := Labels[Region.CategoryIndex]
      else
        ALine1 := 'Periode ' + IntToStr(Region.CategoryIndex + 1);

      ALine2 := Format('O: %.2f, H: %.2f, L: %.2f, C: %.2f', [
        Region.Data.OpenVal, Region.Data.HighVal, Region.Data.LowVal, Region.Data.CloseVal]);
      Result := True;
      Break;
    end;
  end;
end;

procedure TMCCandlestickChart.DrawGridAndAxes;
var
  ChartArea: TRect;
  GridBGRA: TBGRAPixel;
  NumTicks, i: Integer;
  YPos, XPos, CatWidth: Double;
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

  for i := 0 to NumTicks do
  begin
    CurrentValue := ValMin + (i * StepValue);
    YPos := MapValue(CurrentValue, ValMin, ValMax, ChartArea.Bottom, ChartArea.Top);

    if (ShowGrid) and (i > 0) then
      FBuffer.DrawLineAntialias(ChartArea.Left, YPos, ChartArea.Right, YPos, GridBGRA, 1);

    LabelStr := FormatAxisLabel(CurrentValue);
    FBuffer.TextOut(ChartArea.Left - 8, YPos - (FBuffer.FontHeight div 2), LabelStr, ColorToBGRAAlpha(Font.Color, 255), taRightJustify);
  end;

  { Render Label Sumbu X (Kategori / Waktu) }
  if Labels.Count > 0 then
  begin
    CatWidth := (ChartArea.Right - ChartArea.Left) / Labels.Count;
    for i := 0 to Labels.Count - 1 do
    begin
      XPos := ChartArea.Left + (i * CatWidth) + (CatWidth / 2);
      LabelStr := Labels[i];
      FBuffer.TextOut(Trunc(XPos), ChartArea.Bottom + 10, LabelStr, ColorToBGRAAlpha(Font.Color, 255), taCenter);
    end;
  end;
end;

procedure TMCCandlestickChart.DrawChart;
var
  ChartArea: TRect;
  i, k, j, DatasetCount, LabelCount, RegionIdx: Integer;
  CatWidth, TotalCandleWidth, SingleCandleWidth: Double;
  ActualTotalWidth, CategoryOffset: Double;
  OpenY, CloseY, HighY, LowY, BaseX, CenterX: Double;
  ValMin, ValMax: Double;
  OpenVal, HighVal, LowVal, CloseVal: Double;
  CandleRect: TRectF;
  CandleColor, WickColor: TBGRAPixel;
  Dataset: TMCChartDataset;
  IsBullish: Boolean;
begin
  LabelCount := Labels.Count;
  DatasetCount := Datasets.Count;

  if (LabelCount = 0) or (DatasetCount = 0) then Exit;

  ChartArea := GetChartRect;
  CalculateMinMax(ValMin, ValMax);

  CatWidth := (ChartArea.Right - ChartArea.Left) / LabelCount;
  TotalCandleWidth := CatWidth - (FCategoryPadding * 2);
  SingleCandleWidth := (TotalCandleWidth - (2 * (DatasetCount - 1))) / DatasetCount;

  if (FMaxCandleWidth > 0) and (SingleCandleWidth > FMaxCandleWidth) then
    SingleCandleWidth := FMaxCandleWidth;

  if SingleCandleWidth <= 0 then SingleCandleWidth := 4;

  ActualTotalWidth := (SingleCandleWidth * DatasetCount) + (2 * (DatasetCount - 1));
  CategoryOffset := (CatWidth - ActualTotalWidth) / 2;

  SetLength(FCandleRegions, LabelCount * DatasetCount);
  RegionIdx := 0;

  for i := 0 to LabelCount - 1 do
  begin
    BaseX := ChartArea.Left + (i * CatWidth) + CategoryOffset;

    for j := 0 to DatasetCount - 1 do
    begin
      Dataset := TMCChartDataset(Datasets.Items[j]);

      { Pastikan dataset memiliki data untuk indeks k ini (format per 4 angka) }
      k := i;
      if (k * 4 + 3) < Dataset.Count then
      begin
        OpenVal  := Dataset.Values[k * 4];
        HighVal  := Dataset.Values[k * 4 + 1];
        LowVal   := Dataset.Values[k * 4 + 2];
        CloseVal := Dataset.Values[k * 4 + 3];

        IsBullish := (CloseVal >= OpenVal);
        if IsBullish then
        begin
          CandleColor := ColorToBGRAAlpha(FBullishColor, 220);
          WickColor   := ColorToBGRAAlpha(FBullishColor, 255);
        end
        else
        begin
          CandleColor := ColorToBGRAAlpha(FBearishColor, 220);
          WickColor   := ColorToBGRAAlpha(FBearishColor, 255);
        end;

        HighY  := MapValue(HighVal, ValMin, ValMax, ChartArea.Bottom, ChartArea.Top);
        LowY   := MapValue(LowVal, ValMin, ValMax, ChartArea.Bottom, ChartArea.Top);
        OpenY  := MapValue(OpenVal, ValMin, ValMax, ChartArea.Bottom, ChartArea.Top);
        CloseY := MapValue(CloseVal, ValMin, ValMax, ChartArea.Bottom, ChartArea.Top);

        CandleRect.Left := BaseX + (j * (SingleCandleWidth + 2));
        CandleRect.Right := CandleRect.Left + SingleCandleWidth;
        CandleRect.Top := Min(OpenY, CloseY);
        CandleRect.Bottom := Max(OpenY, CloseY);

        if Abs(CandleRect.Bottom - CandleRect.Top) < 2 then
          CandleRect.Bottom := CandleRect.Top + 2; { Minimal tinggi 2px untuk Doji }

        CenterX := CandleRect.Left + (SingleCandleWidth / 2);

        { 1. Gambar Garis Sumbu Atas & Bawah (Wick / Shadow) }
        FBuffer.DrawLineAntialias(CenterX, HighY, CenterX, CandleRect.Top, WickColor, 1.5);
        FBuffer.DrawLineAntialias(CenterX, CandleRect.Bottom, CenterX, LowY, WickColor, 1.5);

        { 2. Gambar Badan Lilin (Candle Body / Box) }

        { Trik BGRABitmap: Area lebih besar sebagai Border/WickColor }
        FBuffer.FillRect(Trunc(CandleRect.Left), Trunc(CandleRect.Top),
                           Trunc(CandleRect.Right), Trunc(CandleRect.Bottom),
                           WickColor, dmDrawWithTransparency);

        { Ditimpa dengan area lebih kecil (dikurangi 1px) sebagai Fill/CandleColor }
        FBuffer.FillRect(Trunc(CandleRect.Left) + 1, Trunc(CandleRect.Top) + 1,
                           Trunc(CandleRect.Right) - 1, Trunc(CandleRect.Bottom) - 1,
                           CandleColor, dmDrawWithTransparency);

        { 3. Simpan wilayah untuk Tooltip Hover }
        FCandleRegions[RegionIdx].Rect := CandleRect;
        FCandleRegions[RegionIdx].DatasetIndex := j;
        FCandleRegions[RegionIdx].CategoryIndex := i;
        FCandleRegions[RegionIdx].Data.OpenVal := OpenVal;
        FCandleRegions[RegionIdx].Data.HighVal := HighVal;
        FCandleRegions[RegionIdx].Data.LowVal := LowVal;
        FCandleRegions[RegionIdx].Data.CloseVal := CloseVal;
        Inc(RegionIdx);
      end;
    end;
  end;

  SetLength(FCandleRegions, RegionIdx);
end;

end.
