
= Abstract
This revision aligns the implementation report with the current repository state and the TODO requirements for component-level technical depth. The active processing chain covered in this version is RGB #sym.arrow Grayscale #sym.arrow 3x3 line-buffer/window #sym.arrow Sobel #sym.arrow Frame compositor, with runtime control handled by the debounced click-detector path.

The report focuses on repository-owned assets under `rtl/`, `testbench/`, and `docs/report/analysis/`. In particular, this draft adds protocol background, per-component interface contracts, waveform-backed transaction timing, and synthesis evidence extracted from Vivado reports into CSV/JSON that are directly consumed by Typst in this document.

// \section{Einleitung (Shared)}
// \label{sec:einleitung}

// In der folgenden Projektarbeit wird die Umsetzung des Projekts \textit{\getTitleDe} beschrieben.
// In diesem Projekt soll auf einem FPGA-Chip ein Videostream einer Kamera in Realtime durch verschiedene Modifikationen manipuliert und über HDMI auf einem Monitor ausgegeben werden.
// Das Projekt wurde als Gruppenarbeit von Valentin Bumeder, Jan Duchscherer, Justin Löber, Lukas Roess bearbeitet.


// \subsection{Projektziel}
// Ziel des Projekts ist die Implementierung einer Pipeline zur Veränderung eines Videostreams auf dem FPGA-Board \textit{Digilent Zybo Z7-10 (Zynq-7010)}\cite{digilent_zybo_nodate-1}.
// Als Input für den Videostream soll eine \textit{Pcam 5C (OV5640)}\cite{digilent_pcam_nodate} Kamera genutzt werden.
// Auf den Videostream sollen verschiedene Modifikationen angewendet werden können, welche durch die Buttons auf dem Board gesteuert werden können.
// Als erste Modifikation in der Pipeline soll der RGB-Stream in ein Graubild verwandelt werden.
// Aufbauend darauf wird ein Lowpass-Filter implementiert, um Bildinhalte weichzuzeichnen.
// Zuletzt soll als Mindestanforderung ein Kantendetektionsfilter angewandt werden.
// Das Ausgangssignal ist durch die Modifikationen ein Schwarz-Weiß-Bild, welches die detektierten Kanten im Videostream zeigt. \newline

// Nach Erfüllung des Projektziels wird optional die Implementierung der detektierten Kanten als Overlay auf den RGB-Stream,
// der FAST Corner Detection oder weiterer morphologischer Operationen angestrebt.

// \subsection{Referenzprojekt}

// Als Grundlage für das Projekt wird das \textit{Zybo Z7 Pcam 5C Demo}-Projekt\cite{digilent_zybo_nodate} verwendet.
// Dieses Projekt beinhaltet eine einfache Videostreaming-Pipeline auf der gegebenen Hardware unter Nutzung von AXI4-Videopixel-Streams.
// Die eigens entwickelten Module sollen als IP-Blocks in das Demoprojekt integriert und der Video-Output über HDMI dadurch verändert werden.


= Scope

- RTL modules and wrappers in `rtl/` for grayscale conversion, blur/sobel processing, compositing, and pipeline integration.
- cocotb verification framework in `testbench/`, including reusable AXI stream drivers/monitors and target-based execution.
- AXI4-Stream framing correctness, backpressure behavior, and frame-boundary control semantics.
- Synthesis/implementation utilization evidence for key modules and full-system placement.

