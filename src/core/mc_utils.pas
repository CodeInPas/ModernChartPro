unit mc_utils;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Math, BGRABitmap, BGRABitmapTypes;

{ Memetakan nilai dari satu rentang ke rentang lain (sangat efisien untuk plot titik X dan Y layar) }
function MapValue(const Value, InMin, InMax, OutMin, OutMax: Double): Double; inline;

{ Konversi string Hex (misal: '#FF5733' atau 'FF5733') ke TBGRAPixel, umum untuk data warna Chart.js }
function HexToBGRA(HexStr: string; Alpha: Byte = 255): TBGRAPixel;

{ Menggabungkan TColor standar dari Lazarus dengan nilai transparansi (Alpha) }
function ColorToBGRAAlpha(AColor: TColor; AAlpha: Byte): TBGRAPixel; inline;

{ Memformat nilai numerik panjang menjadi label sumbu yang ringkas (Contoh: 15000 -> 15K) }
function FormatAxisLabel(Value: Double): string;

implementation

function MapValue(const Value, InMin, InMax, OutMin, OutMax: Double): Double; inline;
begin
  if InMax = InMin then Exit(OutMin); // Menghindari pengecualian pembagian dengan nol (Divide by zero)
  Result := (Value - InMin) * (OutMax - OutMin) / (InMax - InMin) + OutMin;
end;

function HexToBGRA(HexStr: string; Alpha: Byte = 255): TBGRAPixel;
var
  R, G, B: Byte;
  HexVal: Integer;
begin
  HexStr := StringReplace(HexStr, '#', '', [rfReplaceAll]);

  // Mendukung format hex pendek (misal: #F00 menjadi FF0000)
  if Length(HexStr) = 3 then
    HexStr := HexStr[1] + HexStr[1] + HexStr[2] + HexStr[2] + HexStr[3] + HexStr[3];

  if Length(HexStr) <> 6 then
    Exit(BGRA(0, 0, 0, Alpha)); // Fallback warna hitam jika format tidak valid

  HexVal := StrToIntDef('$' + HexStr, 0);

  // Ekstraksi nilai RGB menggunakan operasi bitwise (shr dan and) untuk performa
  R := (HexVal shr 16) and $FF;
  G := (HexVal shr 8) and $FF;
  B := HexVal and $FF;

  Result := BGRA(R, G, B, Alpha);
end;

function ColorToBGRAAlpha(AColor: TColor; AAlpha: Byte): TBGRAPixel; inline;
begin
  Result := ColorToBGRA(ColorToRGB(AColor)); // Memastikan TColor diubah ke RGB murni sebelum ke BGRA
  Result.alpha := AAlpha;
end;

function FormatAxisLabel(Value: Double): string;
var
  AbsVal: Double;
begin
  AbsVal := Abs(Value);

  if AbsVal >= 1000000 then
    Result := FormatFloat('0.#M', Value / 1000000)
  else if AbsVal >= 1000 then
    Result := FormatFloat('0.#K', Value / 1000)
  else
    Result := FormatFloat('0.##', Value); // Mempertahankan desimal hanya jika diperlukan
end;

end.

