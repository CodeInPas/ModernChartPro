unit mc_barchart;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Graphics, Math,
  BGRABitmap, BGRABitmapTypes, BGRAPath,
  mc_types, mc_utils, mc_dataset, mc_basechart;

type
  TMCBarChart = class(TMCBaseChart)
  private
    FBarPadding: Integer;
    FCategoryPadding: Integer;
    FMaxBarThickness: Integer;

    { Struktur untuk menampung data posisi batang agar deteksi hover (Tooltip) lebih efisien }
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

    { Implementasi CheckHover untuk mendeteksi mouse masuk ke area batang grafik }
    function CheckHover(X, Y: Integer; out ALine1, ALine2: string): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Align;
    property BorderSpacing;
    property BarPadding: Integer read FBarPadding write FBarPadding default 2;
    property CategoryPadding: Integer read FCategoryPadding write FCategoryPadding default 15;
    property MaxBarThickness: Integer read FMaxBarThickness write SetMaxBarThickness default 40;
  end;

implementation

{ TMCBarChart }

constructor TMCBarChart.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBarPadding := 2;
  FCategoryPadding := 15;
  FMaxBarThickness := 40;
  SetLength(FBarRegions, 0);
end;

procedure TMCBarChart.SetMaxBarThickness(AValue: Integer);
begin
  if FMaxBarThickness = AValue then Exit;
  FMaxBarThickness := AValue;
  Invalidate;
end;

function TMCBarChart.CheckHover(X, Y: Integer; out ALine1, ALine2: string): Boolean;
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
    { Cek apakah koordinat Mouse (X,Y) berada di dalam area batang (TRectF) }
    if (X >= Region.Rect.Left) and (X <= Region.Rect.Right) and
       (Y >= Min(Region.Rect.Top, Region.Rect.Bottom)) and
       (Y <= Max(Region.Rect.Top, Region.Rect.Bottom)) then
    begin
      Dataset := TMCChartDataset(FDatasets.Items[Region.DatasetIndex]);

      { Format teks untuk baris 1 (Nama Sumbu X) dan baris 2 (Nama Dataset: Nilai) }
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

procedure TMCBarChart.DrawRoundedBar(ARect: TRectF; ARadius: TMCBorderRadius;
  AFillColor, ABorderColor: TBGRAPixel; ABorderWidth: Integer);
var
  Path: TBGRAPath;
  MaxRad: Double;
begin
  MaxRad := Min(ARect.Right - ARect.Left, Abs(ARect.Bottom - ARect.Top)) / 2;
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

procedure TMCBarChart.DrawGridAndAxes;
var
  ChartArea: TRect;
  i: Integer;
  CatWidth, XPos: Double;
  LabelStr: string;
begin
  inherited DrawGridAndAxes;
  if Labels.Count = 0 then Exit;

  ChartArea := GetChartRect;
  CatWidth := (ChartArea.Right - ChartArea.Left) / Labels.Count;

  FBuffer.FontName := Font.Name;
  FBuffer.FontHeight := Abs(Font.Height);
  if FBuffer.FontHeight = 0 then FBuffer.FontHeight := Font.Size;
  if FBuffer.FontHeight = 0 then FBuffer.FontHeight := 12;
  FBuffer.FontStyle := Font.Style;
  FBuffer.FontAntialias := True;

  for i := 0 to Labels.Count - 1 do
  begin
    XPos := ChartArea.Left + (i * CatWidth) + (CatWidth / 2);
    LabelStr := Labels[i];
    FBuffer.TextOut(Trunc(XPos), ChartArea.Bottom + 10, LabelStr, ColorToBGRAAlpha(Font.Color, 255), taCenter);
  end;
end;

procedure TMCBarChart.DrawChart;
var
  ChartArea: TRect;
  i, j: Integer;
  DatasetCount, LabelCount, RegionIdx: Integer;
  CatWidth, TotalBarWidth, SingleBarWidth: Double;
  ActualTotalBarWidth, CategoryOffset: Double;
  ZeroY, MappedY, BaseX: Double;
  ValMin, ValMax, Val: Double;
  BarRect: TRectF;
  Dataset: TMCChartDataset;
  ValStr: string;
  DataLabelY: Integer;
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
  TotalBarWidth := CatWidth - (FCategoryPadding * 2);
  SingleBarWidth := (TotalBarWidth - (FBarPadding * (DatasetCount - 1))) / DatasetCount;

  if (FMaxBarThickness > 0) and (SingleBarWidth > FMaxBarThickness) then
    SingleBarWidth := FMaxBarThickness;

  if SingleBarWidth <= 0 then SingleBarWidth := 1;

  ActualTotalBarWidth := (SingleBarWidth * DatasetCount) + (FBarPadding * (DatasetCount - 1));
  CategoryOffset := (CatWidth - ActualTotalBarWidth) / 2;

  { Reset array penampung deteksi hover }
  SetLength(FBarRegions, LabelCount * DatasetCount);
  RegionIdx := 0;

  for i := 0 to LabelCount - 1 do
  begin
    BaseX := ChartArea.Left + (i * CatWidth) + CategoryOffset;

    for j := 0 to DatasetCount - 1 do
    begin
      Dataset := TMCChartDataset(Datasets.Items[j]);
      if i < Dataset.Count then
      begin
        Val := Dataset.Values[i];
        MappedY := MapValue(Val, ValMin, ValMax, ChartArea.Bottom, ChartArea.Top);

        BarRect.Left := BaseX + (j * (SingleBarWidth + FBarPadding));
        BarRect.Right := BarRect.Left + SingleBarWidth;

        if Val >= 0 then
        begin
          BarRect.Top := MappedY;
          BarRect.Bottom := ZeroY;
        end
        else
        begin
          BarRect.Top := ZeroY;
          BarRect.Bottom := MappedY;
        end;

        if Abs(BarRect.Bottom - BarRect.Top) < 1 then BarRect.Top := BarRect.Bottom - 1;

        { 1. Gambar Batang Grafik }
        DrawRoundedBar(BarRect, Dataset.GetRadiusRecord, Dataset.GetBGRAFill, Dataset.GetBGRABorder, Dataset.BorderWidth);

        { 2. Simpan koordinat ke memori untuk interaktivitas Mouse Hover (Tooltip) }
        FBarRegions[RegionIdx].Rect := BarRect;
        FBarRegions[RegionIdx].DatasetIndex := j;
        FBarRegions[RegionIdx].CategoryIndex := i;
        FBarRegions[RegionIdx].Value := Val;
        Inc(RegionIdx);

        { 3. Fitur Data Labels: Menuliskan angka tepat di ujung batang }
        if ShowDataLabels then
        begin
          FBuffer.FontName := DataLabelFont.Name;
          FBuffer.FontHeight := Abs(DataLabelFont.Height);
          if FBuffer.FontHeight = 0 then FBuffer.FontHeight := DataLabelFont.Size;
          FBuffer.FontStyle := DataLabelFont.Style;

          ValStr := FormatFloat('0.##', Val);

          if Val >= 0 then
            DataLabelY := Trunc(BarRect.Top - 5) // Angka di atas batang
          else
            DataLabelY := Trunc(BarRect.Bottom + 5 + FBuffer.FontHeight); // Angka di bawah batang

          FBuffer.TextOut(Trunc(BarRect.Left + (SingleBarWidth / 2)), DataLabelY, ValStr, ColorToBGRAAlpha(DataLabelFont.Color, 255), taCenter);
        end;
      end;
    end;
  end;

  SetLength(FBarRegions, RegionIdx); // Pangkas array jika ada data kosong
end;

end.
