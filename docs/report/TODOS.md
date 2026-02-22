<!-- NOTE: THIS IS A GROUND TRUTH FILE. AGENTS MUST NOT MAKE UNREQUESTED CHANGES, ONLY MINIMAL CHANGES ALLOWED.  -->
# TODOS releated to the HW/SW-Codesign report

**GENERAL INFORMATION**:

- The report must span about 8 pages, including figures and tables.
- Ensure usage of clear and concise language and maintain a logical flow of ideas.
- Use skill `$typst-authoring` to gather context on usiung typst for authoring the report, including formatting, structuring, and incorporating figures and tables effectively.
- Use skill `$fpga-vivado-vitis-structure` to gather context within the project structure, including the organization of source files, testbenches, and documentation, to ensure accurate referencing and integration of content in the report.
- The report must be structured into multiple sections, each being defined in report/sections/*.typ, and then included in the main report file.
-

## Include more theoretical background and imp

- [ ] AXI4 Video Stream protocol

## Implementation details on the RGB_TO_GRAYSCALE component

- [ ] The Master and slave interfaces inside the RGB_TO_GRAYSCALE component
- [ ] Sequence diagram of a typical transaction
- [ ] Timing diagram of the signals during a transaction (*.ghw from the testbench)
- [ ] RGB to GRAYSCALE conversion formulas (first optimal floating point, then fixed point, then shift based as implemented in the RTL)

## Implementation details on the CLICK_DETECTOR control FSM component

- Is it mealy or moore FSM?
- Sequence diagram with state transitions and the corresponding signal changes. mermaid?
- fancy table on the different states and resulting output signals of both the base and overlay fsms.

## Impelemntation details on the FRAME_COMPOSITOR component

- [ ] Theoretical background on the computation of the delay (fifo size) for synchronizing the two video streams
- [ ] Sequence diagram of a typical transaction
- [ ] Timing diagram of the signals during a transaction (*.ghw from the testbench)

## Simulation Framework using cocotb and cocotbext-axi

- [ ] Source (+ custom serialization) -> uut -> Sink (+ custom deserialization) structure of the testbenches
- [ ] Testing includes backpressure, monitoring of handshakes, data integrity tests via golden reference from python implementations.
- [ ] Our common utility functions.
- [ ] Overview of all tests implemented and their purpose and other relevant details (i.e. runtime)

## Synthesis and implementation results

- [ ] Resource utilization for the RGB_TO_GRAYSCALE, FRAME_COMPOSITOR, and the entire system
  - relative share of LUTs, FFs, BRAMs, DSPs
- Those information must be extracted from the Vivado reports and logs.
- Make use of typst file I/O capabilities to read relevant data from cleaned up versions of the Vivado reports (i.e. by removing irrelevant information and keeping only necessary and cleaned data in a csv or json format) and then generate tables and figures in the report based on that data using
