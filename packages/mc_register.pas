unit mc_register;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  mc_barchart,
  mc_horizontalbarchart,
  mc_stackedbarchart,
  mc_linechart,
  mc_bubblechart,
  mc_combochart,
  mc_piechart,
  mc_candlestickchart,
  mc_areachart,
  mc_scatterchart,
  mc_radarchart;

procedure Register;

implementation
{$R mc_icons.res}

procedure Register;
begin
  RegisterComponents('ModernChartPro', [
    TMCBarChart,
    TMCHorizontalBarChart,
    TMCStackedBarChart,
    TMCLineChart,
    TMCBubbleChart,
    TMCComboChart,
    TMCPieChart,
    TMCRadarChart ,
    TMCCandlestickChart,
    TMCScatterChart,
    TMCAreaChart
  ]);
end;

end.
