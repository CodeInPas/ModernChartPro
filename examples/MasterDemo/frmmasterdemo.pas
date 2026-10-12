unit frmmasterdemo;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, Grids, ComCtrls, StdCtrls,
  mc_dataset, mc_basechart, mc_barchart, mc_horizontalbarchart, mc_stackedbarchart,
  mc_linechart, mc_areachart, mc_piechart, mc_radarchart, mc_combochart,
  mc_bubblechart, mc_scatterchart, mc_candlestickchart;

type
  { TfrmDemo dengan komponen yang sudah dideklarasikan oleh desainer visual (.lfm) }
  TfrmDemo = class(TForm)
    BtnUpdate: TButton;
    GridData: TStringGrid;
    PageControl1: TPageControl;
    PanelBottom: TPanel;

    TabBar: TTabSheet;
    TabHBar: TTabSheet;
    TabStacked: TTabSheet;
    TabLine: TTabSheet;
    TabArea: TTabSheet;
    TabPie: TTabSheet;
    TabRadar: TTabSheet;
    TabCombo: TTabSheet;
    TabBubble: TTabSheet;
    TabScatter: TTabSheet;
    TabCandle: TTabSheet;

    BarChart1: TMCBarChart;
    HBarChart1: TMCHorizontalBarChart;
    StackedChart1: TMCStackedBarChart;
    LineChart1: TMCLineChart;
    AreaChart1: TMCAreaChart;
    PieChart1: TMCPieChart;
    RadarChart1: TMCRadarChart;
    ComboChart1: TMCComboChart;
    BubbleChart1: TMCBubbleChart;
    ScatterChart1: TMCScatterChart;
    CandleChart1: TMCCandlestickChart;

    procedure BtnUpdateClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    procedure InitGridData;
    procedure SetupDatasets;
    procedure BuildChartDatasets(AChart: TMCBaseChart; ADatasetCount: Integer);
  public
  end;

var
  frmDemo: TfrmDemo;

implementation

{$R *.lfm}

procedure TfrmDemo.FormCreate(Sender: TObject);
begin
  InitGridData;
  SetupDatasets;

  { Panggil fungsi update untuk merender chart pertama kali berdasarkan data Grid }
  BtnUpdateClick(Self);
end;

procedure TfrmDemo.InitGridData;
begin
  { Setup Header Kolom }
  GridData.Cells[0, 0] := 'Kategori'; GridData.Cells[1, 0] := 'Dataset 1';
  GridData.Cells[2, 0] := 'Dataset 2'; GridData.Cells[3, 0] := 'Dataset 3';
  GridData.Cells[4, 0] := 'Nilai X';   GridData.Cells[5, 0] := 'Radius (R)';
  GridData.Cells[6, 0] := 'Cdl Open';  GridData.Cells[7, 0] := 'Cdl High';
  GridData.Cells[8, 0] := 'Cdl Low';   GridData.Cells[9, 0] := 'Cdl Close';
  GridData.ColWidths[0] := 90;

  { Data Kategori }
  GridData.Cells[0, 1] := 'Januari';   GridData.Cells[0, 2] := 'Februari';
  GridData.Cells[0, 3] := 'Maret';     GridData.Cells[0, 4] := 'April';
  GridData.Cells[0, 5] := 'Mei';

  { Dataset 1, 2, 3 (Standar Y) }
  GridData.Cells[1, 1] := '65'; GridData.Cells[2, 1] := '28'; GridData.Cells[3, 1] := '15';
  GridData.Cells[1, 2] := '59'; GridData.Cells[2, 2] := '48'; GridData.Cells[3, 2] := '25';
  GridData.Cells[1, 3] := '80'; GridData.Cells[2, 3] := '40'; GridData.Cells[3, 3] := '55';
  GridData.Cells[1, 4] := '81'; GridData.Cells[2, 4] := '19'; GridData.Cells[3, 4] := '35';
  GridData.Cells[1, 5] := '56'; GridData.Cells[2, 5] := '86'; GridData.Cells[3, 5] := '65';

  { Nilai X dan R (Bubble / Scatter) }
  GridData.Cells[4, 1] := '10'; GridData.Cells[5, 1] := '15';
  GridData.Cells[4, 2] := '25'; GridData.Cells[5, 2] := '25';
  GridData.Cells[4, 3] := '40'; GridData.Cells[5, 3] := '10';
  GridData.Cells[4, 4] := '60'; GridData.Cells[5, 4] := '30';
  GridData.Cells[4, 5] := '85'; GridData.Cells[5, 5] := '20';

  { Candlestick (Open, High, Low, Close) }
  GridData.Cells[6, 1] := '100'; GridData.Cells[7, 1] := '130'; GridData.Cells[8, 1] := '90';  GridData.Cells[9, 1] := '120';
  GridData.Cells[6, 2] := '120'; GridData.Cells[7, 2] := '150'; GridData.Cells[8, 2] := '110'; GridData.Cells[9, 2] := '145';
  GridData.Cells[6, 3] := '145'; GridData.Cells[7, 3] := '160'; GridData.Cells[8, 3] := '105'; GridData.Cells[9, 3] := '110';
  GridData.Cells[6, 4] := '110'; GridData.Cells[7, 4] := '120'; GridData.Cells[8, 4] := '80';  GridData.Cells[9, 4] := '95';
  GridData.Cells[6, 5] := '95';  GridData.Cells[7, 5] := '140'; GridData.Cells[8, 5] := '90';  GridData.Cells[9, 5] := '135';
end;

{ Helper untuk membuat dataset dan warna (Agar LFM tetap bersih) }
procedure TfrmDemo.BuildChartDatasets(AChart: TMCBaseChart; ADatasetCount: Integer);
var
  i: Integer;
  DS: TMCChartDataset;
begin
  for i := 0 to ADatasetCount - 1 do
  begin
    DS := TMCChartDataset(AChart.Datasets.Add);
    DS.LabelName := 'Dataset ' + IntToStr(i + 1);
    case i of
      0: begin DS.BackgroundColor := $00E16941; DS.BorderColor := $00CC5231; end;
      1: begin DS.BackgroundColor := $004B67ED; DS.BorderColor := $003649BA; end;
      2: begin DS.BackgroundColor := $003CB44B; DS.BorderColor := $002A7E35; end;
    end;
    DS.BorderWidth := 2;
  end;
end;

procedure TfrmDemo.SetupDatasets;
begin
  BuildChartDatasets(BarChart1, 3);
  BuildChartDatasets(HBarChart1, 3);
  BuildChartDatasets(StackedChart1, 3);
  BuildChartDatasets(LineChart1, 3);
  BuildChartDatasets(AreaChart1, 3);
  BuildChartDatasets(RadarChart1, 3);
  BuildChartDatasets(PieChart1, 3);

  BuildChartDatasets(ComboChart1, 2);
  TMCChartDataset(ComboChart1.Datasets[0]).SeriesType := stBar;
  TMCChartDataset(ComboChart1.Datasets[1]).SeriesType := stLine;

  BuildChartDatasets(BubbleChart1, 1);
  BuildChartDatasets(ScatterChart1, 1);
  BuildChartDatasets(CandleChart1, 1);
end;

procedure TfrmDemo.BtnUpdateClick(Sender: TObject);
var
  i: Integer;
  LabelsStr: TStringList;
  sDS1, sDS2, sDS3: string;
  sBubble, sScatter, sCandle: string;
  Charts: array of TMCBaseChart;
  Chart: TMCBaseChart;
begin
  LabelsStr := TStringList.Create;
  sDS1 := ''; sDS2 := ''; sDS3 := '';
  sBubble := ''; sScatter := ''; sCandle := '';

  for i := 1 to GridData.RowCount - 1 do
  begin
    LabelsStr.Add(GridData.Cells[0, i]);

    if sDS1 <> '' then sDS1 := sDS1 + ','; sDS1 := sDS1 + GridData.Cells[1, i];
    if sDS2 <> '' then sDS2 := sDS2 + ','; sDS2 := sDS2 + GridData.Cells[2, i];
    if sDS3 <> '' then sDS3 := sDS3 + ','; sDS3 := sDS3 + GridData.Cells[3, i];

    if sBubble <> '' then sBubble := sBubble + ',';
    sBubble := sBubble + GridData.Cells[4, i] + ',' + GridData.Cells[1, i] + ',' + GridData.Cells[5, i];

    if sScatter <> '' then sScatter := sScatter + ',';
    sScatter := sScatter + GridData.Cells[4, i] + ',' + GridData.Cells[1, i];

    if sCandle <> '' then sCandle := sCandle + ',';
    sCandle := sCandle + GridData.Cells[6, i] + ',' + GridData.Cells[7, i] + ',' + GridData.Cells[8, i] + ',' + GridData.Cells[9, i];
  end;

  Charts := [BarChart1, HBarChart1, StackedChart1, LineChart1, AreaChart1, RadarChart1];
  for i := 0 to High(Charts) do
  begin
    Chart := Charts[i];
    Chart.Labels.Assign(LabelsStr);
    TMCChartDataset(Chart.Datasets[0]).DataValues := sDS1;
    TMCChartDataset(Chart.Datasets[1]).DataValues := sDS2;
    TMCChartDataset(Chart.Datasets[2]).DataValues := sDS3;
  end;

  TMCChartDataset(PieChart1.Datasets[0]).DataValues := GridData.Cells[1, 1];
  TMCChartDataset(PieChart1.Datasets[1]).DataValues := GridData.Cells[2, 1];
  TMCChartDataset(PieChart1.Datasets[2]).DataValues := GridData.Cells[3, 1];

  ComboChart1.Labels.Assign(LabelsStr);
  TMCChartDataset(ComboChart1.Datasets[0]).DataValues := sDS1;
  TMCChartDataset(ComboChart1.Datasets[1]).DataValues := sDS2;

  TMCChartDataset(BubbleChart1.Datasets[0]).DataValues := sBubble;
  TMCChartDataset(ScatterChart1.Datasets[0]).DataValues := sScatter;

  CandleChart1.Labels.Assign(LabelsStr);
  TMCChartDataset(CandleChart1.Datasets[0]).DataValues := sCandle;

  LabelsStr.Free;
end;

end.
