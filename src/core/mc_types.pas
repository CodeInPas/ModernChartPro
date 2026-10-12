unit mc_types;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, BGRABitmapTypes;

type
  { Jenis grafik dasar yang didukung komponen }
  TMCChartType = (ctBar, ctLine, ctPie, ctDoughnut);

  { Orientasi grafik, sangat berguna untuk Bar Chart (Vertikal / Horizontal) }
  TMCChartOrientation = (coVertical, coHorizontal);

  { Struktur untuk menampung radius sudut secara individual ala CSS/Chart.js
    Berguna untuk membuat Bar Chart dengan "Fully Rounded" atau "Small Radius" }
  TMCBorderRadius = record
    TopLeft: Integer;
    TopRight: Integer;
    BottomLeft: Integer;
    BottomRight: Integer;
  end;

  { Struktur padding untuk mengatur margin internal area kanvas grafik }
  TMCPadding = record
    Top: Integer;
    Right: Integer;
    Bottom: Integer;
    Left: Integer;
  end;

{ Helper inisialisasi record yang di-inline untuk performa maksimal }
function MCBorderRadius(ATopLeft, ATopRight, ABottomLeft, ABottomRight: Integer): TMCBorderRadius; inline;
function MCBorderRadiusAll(ARadius: Integer): TMCBorderRadius; inline;
function MCPadding(ATop, ARight, ABottom, ALeft: Integer): TMCPadding; inline;
function MCPaddingAll(APadding: Integer): TMCPadding; inline;

implementation

function MCBorderRadius(ATopLeft, ATopRight, ABottomLeft, ABottomRight: Integer): TMCBorderRadius; inline;
begin
  Result.TopLeft := ATopLeft;
  Result.TopRight := ATopRight;
  Result.BottomLeft := ABottomLeft;
  Result.BottomRight := ABottomRight;
end;

function MCBorderRadiusAll(ARadius: Integer): TMCBorderRadius; inline;
begin
  Result.TopLeft := ARadius;
  Result.TopRight := ARadius;
  Result.BottomLeft := ARadius;
  Result.BottomRight := ARadius;
end;

function MCPadding(ATop, ARight, ABottom, ALeft: Integer): TMCPadding; inline;
begin
  Result.Top := ATop;
  Result.Right := ARight;
  Result.Bottom := ABottom;
  Result.Left := ALeft;
end;

function MCPaddingAll(APadding: Integer): TMCPadding; inline;
begin
  Result.Top := APadding;
  Result.Right := APadding;
  Result.Bottom := APadding;
  Result.Left := APadding;
end;

end.

