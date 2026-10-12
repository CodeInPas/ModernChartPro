unit mc_basechart;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, Types, BGRABitmap, BGRABitmapTypes,
  mc_types, mc_utils, mc_dataset;

type
  TMCBaseChart = class(TCustomControl)
  private
    FLabels: TStringList;
    FShowGrid: Boolean;
    FShowLegend: Boolean;
    FGridColor: TColor;
    FGridAlpha: Byte;
    FChartPadding: TMCPadding;

    FTitle: string;
    FShowTitle: Boolean;
    FTitleFont: TFont;
    FTitleAlignment: TAlignment;

    FUseForcedYScale: Boolean;
    FForceYMin: Double;
    FForceYMax: Double;

    { Fitur 4 & 5: Data Labels dan Tooltips }
    FShowDataLabels: Boolean;
    FDataLabelFont: TFont;
    FShowTooltips: Boolean;
    FTooltipBackgroundColor: TColor;
    FTooltipFont: TFont;

    { Variabel Internal Hover }
    FMouseX, FMouseY: Integer;
    FIsHovering: Boolean;
    FHoverLine1, FHoverLine2: string;

    procedure SetShowGrid(AValue: Boolean);
    procedure SetShowLegend(AValue: Boolean);
    procedure SetGridColor(AValue: TColor);
    procedure SetGridAlpha(AValue: Byte);
    procedure SetLabels(AValue: TStringList);
    procedure LabelsChanged(Sender: TObject);
    procedure SetDatasets(AValue: TMCDatasetList);

    procedure SetTitle(AValue: string);
    procedure SetShowTitle(AValue: Boolean);
    procedure SetTitleFont(AValue: TFont);
    procedure SetTitleAlignment(AValue: TAlignment);

    procedure SetUseForcedYScale(AValue: Boolean);
    procedure SetForceYMin(AValue: Double);
    procedure SetForceYMax(AValue: Double);

    procedure SetShowDataLabels(AValue: Boolean);
    procedure SetDataLabelFont(AValue: TFont);
    procedure SetShowTooltips(AValue: Boolean);
    procedure SetTooltipBackgroundColor(AValue: TColor);
    procedure SetTooltipFont(AValue: TFont);
  protected
    FBuffer: TBGRABitmap;
    FDatasets: TMCDatasetList;

    procedure Paint; override;
    procedure Resize; override;

    { Interaksi Mouse untuk Tooltips }
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave; override;
    function CheckHover(X, Y: Integer; out ALine1, ALine2: string): Boolean; virtual;

    procedure CalculateMinMax(out AMin, AMax: Double); virtual;
    procedure DrawBackground; virtual;
    procedure DrawTitle; virtual;
    procedure DrawLegend; virtual;
    procedure DrawGridAndAxes; virtual;
    procedure DrawChart; virtual; abstract;
    procedure DrawTooltip; virtual; { Render popup }
    function GetChartRect: TRect; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure AddDataset(ADataset: TMCChartDataset); inline;
    procedure ClearData;
    procedure UpdateChart; inline;

    { Fitur 6: Ekspor Gambar }
    procedure SaveToImage(const FileName: string);
  published
    property Datasets: TMCDatasetList read FDatasets write SetDatasets;
    property Align; property Anchors; property Color default clWhite;
    property Font; property ParentColor; property ParentFont; property Visible;

    property Labels: TStringList read FLabels write SetLabels;
    property ShowGrid: Boolean read FShowGrid write SetShowGrid default True;
    property ShowLegend: Boolean read FShowLegend write SetShowLegend default True;
    property GridColor: TColor read FGridColor write SetGridColor default clSilver;
    property GridAlpha: Byte read FGridAlpha write SetGridAlpha default 100;

    property Title: string read FTitle write SetTitle;
    property ShowTitle: Boolean read FShowTitle write SetShowTitle default True;
    property TitleFont: TFont read FTitleFont write SetTitleFont;
    property TitleAlignment: TAlignment read FTitleAlignment write SetTitleAlignment default taCenter;

    property UseForcedYScale: Boolean read FUseForcedYScale write SetUseForcedYScale default False;
    property ForceYMin: Double read FForceYMin write SetForceYMin;
    property ForceYMax: Double read FForceYMax write SetForceYMax;

    { Published Fitur 4 & 5 }
    property ShowDataLabels: Boolean read FShowDataLabels write SetShowDataLabels default False;
    property DataLabelFont: TFont read FDataLabelFont write SetDataLabelFont;
    property ShowTooltips: Boolean read FShowTooltips write SetShowTooltips default True;
    property TooltipBackgroundColor: TColor read FTooltipBackgroundColor write SetTooltipBackgroundColor default $00404040;
    property TooltipFont: TFont read FTooltipFont write SetTooltipFont;
  end;

implementation

uses Math;

constructor TMCBaseChart.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque, csDoubleClicks];
  Width := 400; Height := 250; Color := clWhite;

  FBuffer := nil;
  FDatasets := TMCDatasetList.Create(Self);

  FLabels := TStringList.Create; FLabels.OnChange := @LabelsChanged;

  FShowGrid := True; FShowLegend := True;
  FGridColor := clSilver; FGridAlpha := 100;

  FTitle := 'Modern Chart Title'; FShowTitle := True;
  FTitleFont := TFont.Create; FTitleFont.Size := 14; FTitleFont.Style := [fsBold];
  FTitleFont.Color := $00333333; FTitleFont.OnChange := @LabelsChanged;
  FTitleAlignment := taCenter;

  FUseForcedYScale := False; FForceYMin := 0; FForceYMax := 100;
  FChartPadding := MCPadding(15, 20, 40, 50);

  FShowDataLabels := False;
  FDataLabelFont := TFont.Create; FDataLabelFont.Size := 9;
  FDataLabelFont.Color := clGray; FDataLabelFont.OnChange := @LabelsChanged;

  FShowTooltips := True;
  FTooltipBackgroundColor := $00404040; // Warna abu gelap
  FTooltipFont := TFont.Create; FTooltipFont.Size := 10;
  FTooltipFont.Color := clWhite; FTooltipFont.OnChange := @LabelsChanged;

  if (csDesigning in ComponentState) then
  begin
    FLabels.CommaText := 'Jan,Feb,Mar,Apr,May,Jun';
    with TMCChartDataset(FDatasets.Add) do
    begin
      LabelName := 'Demo Data'; DataValues := '45,-20,60,80,-30,50';
      BackgroundColor := $00FFB6C1; BorderRadius := 5;
    end;
  end;
end;

destructor TMCBaseChart.Destroy;
begin
  if Assigned(FBuffer) then FBuffer.Free;
  FDatasets.Free; FLabels.Free; FTitleFont.Free;
  FDataLabelFont.Free; FTooltipFont.Free;
  inherited Destroy;
end;

{ Setters standard }
procedure TMCBaseChart.SetDatasets(AValue: TMCDatasetList); begin FDatasets.Assign(AValue); end;
procedure TMCBaseChart.SetShowGrid(AValue: Boolean); begin if FShowGrid = AValue then Exit; FShowGrid := AValue; Invalidate; end;
procedure TMCBaseChart.SetShowLegend(AValue: Boolean); begin if FShowLegend = AValue then Exit; FShowLegend := AValue; Invalidate; end;
procedure TMCBaseChart.SetGridColor(AValue: TColor); begin if FGridColor = AValue then Exit; FGridColor := AValue; Invalidate; end;
procedure TMCBaseChart.SetGridAlpha(AValue: Byte); begin if FGridAlpha = AValue then Exit; FGridAlpha := AValue; Invalidate; end;
procedure TMCBaseChart.SetLabels(AValue: TStringList); begin FLabels.Assign(AValue); Invalidate; end;
procedure TMCBaseChart.LabelsChanged(Sender: TObject); begin Invalidate; end;
procedure TMCBaseChart.SetTitle(AValue: string); begin if FTitle = AValue then Exit; FTitle := AValue; Invalidate; end;
procedure TMCBaseChart.SetShowTitle(AValue: Boolean); begin if FShowTitle = AValue then Exit; FShowTitle := AValue; Invalidate; end;
procedure TMCBaseChart.SetTitleFont(AValue: TFont); begin FTitleFont.Assign(AValue); end;
procedure TMCBaseChart.SetTitleAlignment(AValue: TAlignment); begin if FTitleAlignment = AValue then Exit; FTitleAlignment := AValue; Invalidate; end;
procedure TMCBaseChart.SetUseForcedYScale(AValue: Boolean); begin if FUseForcedYScale = AValue then Exit; FUseForcedYScale := AValue; Invalidate; end;
procedure TMCBaseChart.SetForceYMin(AValue: Double); begin if FForceYMin = AValue then Exit; FForceYMin := AValue; Invalidate; end;
procedure TMCBaseChart.SetForceYMax(AValue: Double); begin if FForceYMax = AValue then Exit; FForceYMax := AValue; Invalidate; end;
procedure TMCBaseChart.SetShowDataLabels(AValue: Boolean); begin if FShowDataLabels = AValue then Exit; FShowDataLabels := AValue; Invalidate; end;
procedure TMCBaseChart.SetDataLabelFont(AValue: TFont); begin FDataLabelFont.Assign(AValue); end;
procedure TMCBaseChart.SetShowTooltips(AValue: Boolean); begin if FShowTooltips = AValue then Exit; FShowTooltips := AValue; Invalidate; end;
procedure TMCBaseChart.SetTooltipBackgroundColor(AValue: TColor); begin if FTooltipBackgroundColor = AValue then Exit; FTooltipBackgroundColor := AValue; Invalidate; end;
procedure TMCBaseChart.SetTooltipFont(AValue: TFont); begin FTooltipFont.Assign(AValue); end;

{ Ekspor Gambar }
procedure TMCBaseChart.SaveToImage(const FileName: string);
begin
  if Assigned(FBuffer) then FBuffer.SaveToFile(FileName);
end;

procedure TMCBaseChart.Resize;
begin
  inherited Resize;
  if Assigned(FBuffer) then FreeAndNil(FBuffer);
  if (Width > 0) and (Height > 0) then FBuffer := TBGRABitmap.Create(Width, Height);
  Invalidate;
end;

{ Logika Mouse Hover untuk Tooltip }
procedure TMCBaseChart.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Hit: Boolean;
  L1, L2: string;
begin
  inherited MouseMove(Shift, X, Y);
  if not FShowTooltips then Exit;

  FMouseX := X; FMouseY := Y;
  Hit := CheckHover(X, Y, L1, L2);

  if (Hit <> FIsHovering) or (L1 <> FHoverLine1) or (L2 <> FHoverLine2) then
  begin
    FIsHovering := Hit;
    FHoverLine1 := L1; FHoverLine2 := L2;
    Invalidate; { Render ulang hanya jika status/konten tooltip berubah }
  end
  else if Hit then Invalidate; { Update posisi kotak mengikuti mouse }
end;

procedure TMCBaseChart.MouseLeave;
begin
  inherited MouseLeave;
  if FIsHovering then
  begin
    FIsHovering := False;
    Invalidate; { Hilangkan tooltip saat kursor keluar }
  end;
end;

function TMCBaseChart.CheckHover(X, Y: Integer; out ALine1, ALine2: string): Boolean;
begin
  Result := False; // Di-override di barchart.pas
end;

function TMCBaseChart.GetChartRect: TRect;
var DynamicTop: Integer;
begin
  DynamicTop := FChartPadding.Top;
  if FShowTitle and (FTitle <> '') then DynamicTop := DynamicTop + Abs(FTitleFont.Height) + 15;
  if FShowLegend then DynamicTop := DynamicTop + 25;
  Result := Rect(FChartPadding.Left, DynamicTop, Width - FChartPadding.Right, Height - FChartPadding.Bottom);
end;

procedure TMCBaseChart.CalculateMinMax(out AMin, AMax: Double);
var i, j: Integer; Val: Double;
begin
  if FUseForcedYScale then
  begin AMin := FForceYMin; AMax := FForceYMax; Exit; end;

  AMin := 0; AMax := 0;
  if FDatasets.Count = 0 then Exit;

  for i := 0 to FDatasets.Count - 1 do
    for j := 0 to TMCChartDataset(FDatasets.Items[i]).Count - 1 do
    begin
      Val := TMCChartDataset(FDatasets.Items[i]).Values[j];
      if Val > AMax then AMax := Val;
      if Val < AMin then AMin := Val;
    end;

  if AMax > 0 then AMax := AMax * 1.1;
  if AMin < 0 then AMin := AMin * 1.1;
end;

procedure TMCBaseChart.DrawBackground; begin FBuffer.Fill(ColorToBGRA(ColorToRGB(Color))); end;

procedure TMCBaseChart.DrawTitle;
var X, Y, TextW: Integer;
begin
  if not FShowTitle or (FTitle = '') then Exit;
  FBuffer.FontName := FTitleFont.Name; FBuffer.FontHeight := Abs(FTitleFont.Height);
  if FBuffer.FontHeight = 0 then FBuffer.FontHeight := FTitleFont.Size;
  FBuffer.FontStyle := FTitleFont.Style;

  TextW := FBuffer.TextSize(FTitle).cx; Y := FChartPadding.Top;
  case FTitleAlignment of
    taLeftJustify: X := FChartPadding.Left;
    taRightJustify: X := Width - FChartPadding.Right - TextW;
    taCenter: X := (Width - TextW) div 2;
  else X := FChartPadding.Left;
  end;
  FBuffer.TextOut(X, Y, FTitle, ColorToBGRAAlpha(FTitleFont.Color, 255), taLeftJustify);
end;

procedure TMCBaseChart.DrawLegend;
var i: Integer; Dataset: TMCChartDataset; TotalWidth, CurrentX, YPos, BoxWidth, BoxHeight, ItemSpacing, TextSpace: Double; RectX1, RectY1, RectX2, RectY2: Integer;
begin
  if not FShowLegend or (FDatasets.Count = 0) then Exit;
  BoxWidth := 30; BoxHeight := 12; ItemSpacing := 20;
  YPos := FChartPadding.Top; if FShowTitle and (FTitle <> '') then YPos := YPos + Abs(FTitleFont.Height) + 15;

  FBuffer.FontName := Font.Name; FBuffer.FontHeight := Abs(Font.Height);
  if FBuffer.FontHeight = 0 then FBuffer.FontHeight := Font.Size; if FBuffer.FontHeight = 0 then FBuffer.FontHeight := 12;
  FBuffer.FontStyle := Font.Style; FBuffer.FontAntialias := True;

  TotalWidth := 0;
  for i := 0 to FDatasets.Count - 1 do
  begin
    Dataset := TMCChartDataset(FDatasets.Items[i]); TextSpace := FBuffer.TextSize(Dataset.LabelName).cx;
    TotalWidth := TotalWidth + BoxWidth + 5 + TextSpace;
    if i < FDatasets.Count - 1 then TotalWidth := TotalWidth + ItemSpacing;
  end;

  CurrentX := (Width - TotalWidth) / 2;

  for i := 0 to FDatasets.Count - 1 do
  begin
    Dataset := TMCChartDataset(FDatasets.Items[i]);
    RectX1 := Trunc(CurrentX); RectY1 := Trunc(YPos); RectX2 := Trunc(CurrentX + BoxWidth); RectY2 := Trunc(YPos + BoxHeight);
    if Dataset.BorderWidth > 0 then begin
      FBuffer.FillRect(RectX1, RectY1, RectX2, RectY2, Dataset.GetBGRABorder, dmDrawWithTransparency);
      FBuffer.FillRect(RectX1 + Dataset.BorderWidth, RectY1 + Dataset.BorderWidth, RectX2 - Dataset.BorderWidth, RectY2 - Dataset.BorderWidth, Dataset.GetBGRAFill, dmDrawWithTransparency);
    end else FBuffer.FillRect(RectX1, RectY1, RectX2, RectY2, Dataset.GetBGRAFill, dmDrawWithTransparency);

    CurrentX := CurrentX + BoxWidth + 5;
    FBuffer.TextOut(Trunc(CurrentX), Trunc(YPos - 1), Dataset.LabelName, ColorToBGRAAlpha(Font.Color, 255), taLeftJustify);
    TextSpace := FBuffer.TextSize(Dataset.LabelName).cx; CurrentX := CurrentX + TextSpace + ItemSpacing;
  end;
end;

procedure TMCBaseChart.DrawGridAndAxes;
var ChartArea: TRect; GridBGRA: TBGRAPixel; NumTicks, i: Integer; YPos, ValMin, ValMax, StepValue, CurrentValue: Double; LabelStr: string;
begin
  ChartArea := GetChartRect; GridBGRA := ColorToBGRAAlpha(FGridColor, FGridAlpha);
  FBuffer.FontName := Font.Name; FBuffer.FontHeight := Abs(Font.Height);
  if FBuffer.FontHeight = 0 then FBuffer.FontHeight := Font.Size; if FBuffer.FontHeight = 0 then FBuffer.FontHeight := 12;
  FBuffer.FontStyle := Font.Style; FBuffer.FontAntialias := True;

  FBuffer.DrawLineAntialias(ChartArea.Left, ChartArea.Top, ChartArea.Left, ChartArea.Bottom, BGRA(150, 150, 150, 255), 1);
  FBuffer.DrawLineAntialias(ChartArea.Left, ChartArea.Bottom, ChartArea.Right, ChartArea.Bottom, BGRA(150, 150, 150, 255), 1);

  if not FShowGrid then Exit;

  CalculateMinMax(ValMin, ValMax); NumTicks := 5; StepValue := (ValMax - ValMin) / NumTicks;

  for i := 0 to NumTicks do
  begin
    CurrentValue := ValMin + (i * StepValue); YPos := MapValue(CurrentValue, ValMin, ValMax, ChartArea.Bottom, ChartArea.Top);
    if i > 0 then FBuffer.DrawLineAntialias(ChartArea.Left, YPos, ChartArea.Right, YPos, GridBGRA, 1);
    LabelStr := FormatAxisLabel(CurrentValue);
    FBuffer.TextOut(ChartArea.Left - 8, YPos - (FBuffer.FontHeight div 2), LabelStr, ColorToBGRAAlpha(Font.Color, 255), taRightJustify);
  end;
end;

procedure TMCBaseChart.DrawTooltip;
var
  W1, W2, MaxW, BoxW, BoxH, Pad, BoxX, BoxY: Integer;
begin
  if not FShowTooltips or not FIsHovering then Exit;
  Pad := 10;

  FBuffer.FontName := FTooltipFont.Name;
  FBuffer.FontHeight := Abs(FTooltipFont.Height);
  if FBuffer.FontHeight = 0 then FBuffer.FontHeight := FTooltipFont.Size;

  FBuffer.FontStyle := [fsBold]; W1 := FBuffer.TextSize(FHoverLine1).cx;
  FBuffer.FontStyle := [];       W2 := FBuffer.TextSize(FHoverLine2).cx;
  MaxW := Max(W1, W2);

  BoxW := MaxW + (Pad * 2);
  BoxH := (FBuffer.FontHeight * 2) + (Pad * 3);
  BoxX := FMouseX + 15; BoxY := FMouseY + 15;

  { Hindari terpotong layar Kanan/Bawah }
  if BoxX + BoxW > Width then BoxX := FMouseX - BoxW - 10;
  if BoxY + BoxH > Height then BoxY := FMouseY - BoxH - 10;

  { Gambar Kotak Popup Tooltip dengan trick FillRect untuk Border 1px }
  FBuffer.FillRect(BoxX, BoxY, BoxX + BoxW, BoxY + BoxH, ColorToBGRAAlpha(FTooltipFont.Color, 150), dmDrawWithTransparency);
  FBuffer.FillRect(BoxX + 1, BoxY + 1, BoxX + BoxW - 1, BoxY + BoxH - 1, ColorToBGRAAlpha(FTooltipBackgroundColor, 230), dmDrawWithTransparency);

  { Gambar Teks (Kategori & Nilai Data) }
  FBuffer.FontStyle := [fsBold];
  FBuffer.TextOut(BoxX + Pad, BoxY + Pad, FHoverLine1, ColorToBGRAAlpha(FTooltipFont.Color, 255), taLeftJustify);
  FBuffer.FontStyle := [];
  FBuffer.TextOut(BoxX + Pad, BoxY + Pad + FBuffer.FontHeight + 5, FHoverLine2, ColorToBGRAAlpha(FTooltipFont.Color, 255), taLeftJustify);
end;

procedure TMCBaseChart.Paint;
begin
  if not Assigned(FBuffer) then
  begin
    if (Width > 0) and (Height > 0) then FBuffer := TBGRABitmap.Create(Width, Height) else Exit;
  end;

  DrawBackground;
  DrawTitle;
  DrawLegend;
  DrawGridAndAxes;
  DrawChart;
  DrawTooltip;      { DI GAMBAR PALING TERAKHIR (TUMPUKAN TERATAS) }

  FBuffer.Draw(Canvas, 0, 0, True);
end;

procedure TMCBaseChart.AddDataset(ADataset: TMCChartDataset); inline; begin Invalidate; end;
procedure TMCBaseChart.ClearData; begin FDatasets.Clear; FLabels.Clear; Invalidate; end;
procedure TMCBaseChart.UpdateChart; inline; begin Invalidate; end;

end.
