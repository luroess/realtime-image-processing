# UG934 AXI4-Stream Video Rules

Derived from `ug934.full.md` using `markitdown` extraction.

## Non-negotiable Protocol Rules

1. Map Start Of Frame (SOF) to AXI4-Stream `TUSER[0]` and assert it only on the first valid pixel of each frame/field.
   Related sections: Video Subsystem Software Guidelines (sections/ch02-system-design-guide-sec09-video-subsystem-software-guidelines.md), Propagating SOF and EOL Signals (sections/ch03-ip-development-guide-sec08-propagating-sof-and-eol-signals.md)
   Evidence snippets:
   - READY SOF EOL
   - Start of Frame Signal The start of frame (SOF) signal is physically transmitted over the AXI4-Stream TUSER0 signal, and signifies the first pixel of a video field or frame. The SOF pulse is one valid transaction wide, and must coincide with the first pixel of the field or frame (Figure 1-2).
   - The start of frame (SOF) signal is physically transmitted over the AXI4-Stream TUSER0 signal, and signifies the first pixel of a video field or frame. The SOF pulse is one valid transaction wide, and must coincide with the first pixel of the field or frame (Figure 1-2). SOF functions as a frame synchronization signal, allowing downstream cores to reinitialize,
   - signal, and signifies the first pixel of a video field or frame. The SOF pulse is one valid transaction wide, and must coincide with the first pixel of the field or frame (Figure 1-2). SOF functions as a frame synchronization signal, allowing downstream cores to reinitialize, and detect the first pixel of a field or frame.

2. Map End Of Line (EOL) to AXI4-Stream `TLAST` and assert it on the last valid pixel of each line.
   Related sections: Propagating SOF and EOL Signals (sections/ch03-ip-development-guide-sec08-propagating-sof-and-eol-signals.md)
   Evidence snippets:
   - Start Of Frame End Of Line 1
   - SOF EOL 1.
   - SOF EOL READY/VALID Handshake
   - and detect the first pixel of a field or frame. End of Line Signal The end of line (EOL) signal is physically transmitted over the AXI4-Stream TLAST signal,

3. Transfer only active video samples on AXI4-Stream video; blanking intervals are not transported.
   Related sections: Video Timing Information (sections/ch02-system-design-guide-sec01-video-timing-information.md), Propagating Video Timing Information (sections/ch02-system-design-guide-sec02-propagating-video-timing-information.md), Timing Representation (sections/ch03-ip-development-guide-sec03-timing-representation.md), Input/Output Timing (sections/ch03-ip-development-guide-sec04-input-output-timing.md)
   Evidence snippets:
   - AXI4-Stream Signaling Interface The AXI4-Stream carries active video data, driven by both the master and slave interfaces as seen in Figure 1-1.
   - Figure 1-1: Video IP with Multiple AXI4-Stream Slave (Input) and Master (Output) Interfaces Blank periods, audio data, and ancillary data packets are not transferred through the video protocol over AXI4-Stream. All signals listed in Table 1-1 and Table 1-2 are required for video over AXI4-Stream interfaces.
   - Introduction During valid transfers, DATA only carries active video data. Blank periods and ancillary data packets are not transferred by video over AXI4-Stream.
   - During valid transfers, DATA only carries active video data. Blank periods and ancillary data packets are not transferred by video over AXI4-Stream. Start of Frame Signal

4. Do not treat ancillary/non-video payload as regular AXI4-Stream video pixels; deembed/discard or handle separately.
   Related sections: Ancillary Data (sections/ch02-system-design-guide-sec07-ancillary-data.md)
   Evidence snippets:
   - Figure 1-1: Video IP with Multiple AXI4-Stream Slave (Input) and Master (Output) Interfaces Blank periods, audio data, and ancillary data packets are not transferred through the video protocol over AXI4-Stream. All signals listed in Table 1-1 and Table 1-2 are required for video over AXI4-Stream interfaces.
   - Introduction During valid transfers, DATA only carries active video data. Blank periods and ancillary data packets are not transferred by video over AXI4-Stream.
   - from TUSER is not recovered. Transferring timing information or ancillary data embedded in the AXI4-Stream video stream is also prohibited, either in the form of a header or as a watermark. No method is provided for, or expected from processing cores to distinguish timing information or
   - stream is also prohibited, either in the form of a header or as a watermark. No method is provided for, or expected from processing cores to distinguish timing information or ancillary data packets from valid pixel data. When video data is re-formatted, for example video scaling changes the active frame dimensions, no mechanism is provided or expected to change timing or stream information embedded in video data.

## Usage

- Apply these rules when modifying AXI4-Stream video paths, framing, or protocol adaptation logic.
- If ambiguity remains, inspect the related split section files under `references/ug934/sections/`.
