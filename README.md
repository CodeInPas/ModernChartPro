# Praise
Praise Only To God

# 📊 ModernChartPro for Lazarus

![Lazarus Supported](https://img.shields.io/badge/Lazarus-2.0%2B-blue.svg)
![FPC Supported](https://img.shields.io/badge/FPC-3.2%2B-red.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

**ModernChartPro** is a modern, lightweight, and interactive data visualization component library for Lazarus / Free Pascal. Built on top of the `BGRABitmap` foundation, this component offers extremely smooth graphic rendering (anti-aliasing), transparency support (alpha blending), and interactive animations (hover tooltips) similar to modern web-based charting libraries (like Chart.js).

<img width="950" height="586" alt="mc" src="https://github.com/user-attachments/assets/0988185e-c4d3-4292-8834-fcde499a9d62" />


## ✨ Key Features

- 🎨 **High-Quality Rendering:** Lines, curves, and polygons are rendered with full anti-aliasing using `BGRABitmap`.
- 🖱️ **Interactive (Hover Tooltips):** Smart cursor detection that automatically displays data values when the user hovers over chart elements (points, bars, or pie slices).
- 🧩 **11 Comprehensive Chart Types:** From simple Bar Charts to Candlesticks for financial purposes.
- ⚙️ **Easy Configuration:** Design directly through the Visual Form Designer (Object Inspector) or configure dynamically at Run-Time.
- 💾 **Instant Export:** Equipped with a built-in `SaveToImage` function to export charts as high-resolution PNG files.

## 📦 Available Components

This library registers 11 ready-to-use components into the **ModernChartPro** tab in your Lazarus Component Palette:

1. `TMCBarChart` - Standard vertical bar chart.
2. `TMCHorizontalBarChart` - Horizontal bar chart.
3. `TMCStackedBarChart` - Stacked bar chart for proportional comparison.
4. `TMCLineChart` - Smooth line chart with point markers.
5. `TMCAreaChart` - Trend chart with a shaded bottom area.
6. `TMCPieChart` - 360-degree proportional pie chart.
7. `TMCRadarChart` - Spider web/radar chart for multi-variables.
8. `TMCComboChart` - Visual combination of Bar Chart and Line Chart.
9. `TMCBubbleChart` - 3D scatter chart (X-axis, Y-axis, and Radius/Size).
10. `TMCScatterChart` - Standard scatter chart (X and Y axes).
11. `TMCCandlestickChart` - Financial candlestick chart (Open, High, Low, Close).

## 🛠️ Prerequisites

Before installing ModernChartPro, ensure you have installed the following library in Lazarus:
- **BGRABitmap** (Available and can be downloaded directly via the Online Package Manager / OPM in Lazarus).

## 🚀 Installation Guide

1. *Clone* or *Download* this repository to your computer.
2. Open the Lazarus IDE.
3. Go to the **Package** -> **Open Package File (.lpk)** menu.
4. Locate and select the `modernchartpro.lpk` file from the repository folder.
5. Click the **Compile** button and wait for the process to finish.
6. Click the **Install** button. Lazarus will ask for confirmation to rebuild the IDE. Click *Yes*.
7. Once Lazarus reopens, the **ModernChartPro** tab with custom icons will be available in your Component Palette.

## 📖 Quick Start

Adding data to the chart is very easy. You can use the Object Inspector on the `Datasets` property, or via code (Run-Time):

```pascal
// Example: Adding data to a Bar Chart
BarChart1.Labels.CommaText := 'Jan,Feb,Mar,Apr,May';

with TMCChartDataset(BarChart1.Datasets.Add) do
begin
  LabelName := 'Sales 2023';
  DataValues := '150, 200, 180, 220, 250';
  BackgroundColor := $00E16941; // TColor Format
  BorderWidth := 2;
end;
```

---
## ☕ Support the Project

If you find **ModernChartPro** helpful and want to support its ongoing development, consider buying me a coffee or sending a tip. Any support is deeply appreciated!

[![Ko-fi](https://img.shields.io/badge/Ko--fi-Buy%20Me%20a%20Coffee-F16061?style=for-the-badge&logo=ko-fi&logoColor=white)](https://Ko-fi.com/ainovasinusantara)
[![PayPal](https://img.shields.io/badge/PayPal-Donate-00457C?style=for-the-badge&logo=paypal&logoColor=white)](https://paypal.me/KangOz)

> **💡 Your support keeps the momentum going!**  
> Every contribution directly fuels my passion, energy, and motivation to continuously build, maintain, and release even more useful open-source desktop applications for the developer community.


## 📄 License

This project is licensed under the **MIT License**. You are free to use, modify, and distribute this library for both personal and commercial projects. See the `LICENSE` file for more information.

---

## 🙌 Acknowledgments

* [ChartJS](https://www.chartjs.org/) - For the incredible design system inspiration, color palettes, and aesthetics.
* [BGRABitmap](https://wiki.freepascal.org/BGRABitmap) - An amazing graphics library that enables transparent rendering and anti-aliasing in Lazarus.
* [streamlinehq](https://www.streamlinehq.com/icons/tabler-line?search=button&icon=ico_m1dJb9k6hjHfcTMP) - Visual icon references for the Component Palette.
