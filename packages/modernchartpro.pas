{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit modernchartpro;

{$warn 5023 off : no warning about unused units}
interface

uses
  mc_types, mc_utils, mc_dataset, mc_basechart, mc_barchart, 
  mc_horizontalbarchart, mc_register, mc_stackedbarchart, mc_linechart, 
  mc_bubblechart, mc_combochart, mc_piechart, mc_radarchart, 
  mc_candlestickchart, mc_areachart, mc_scatterchart, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('mc_register', @mc_register.Register);
end;

initialization
  RegisterPackage('modernchartpro', @Register);
end.
