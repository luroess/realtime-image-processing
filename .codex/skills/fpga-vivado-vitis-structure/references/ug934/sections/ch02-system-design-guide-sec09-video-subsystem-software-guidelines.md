# Video Subsystem Software Guidelines

_Parent: Chapter 2: System Design Guide_
_Source lines: 3823-4702_

Video Subsystem Software Guidelines

Interlace to Progressive Conversion

A deinterlacer can be used after the Video In to AXI4-Stream core to convert the video
format from interlaced to progressive. In this case, the deinterlacer uses the field ID bit, fid,
from the Video In to AXI4-Stream core, as shown in Figure 2-13.

X-Ref Target - Figure 2-13

Video In to AXI4-Stream

Video Input

Data in

data_valid

vblank

hblank

vsync

hsync

field_id

i

D
e
n
t
e
r
l
a
c
e
r

axi_field_id

VTIMING

Video Timing
Controller

(detector)

i

V
d
e
o
P
r
o
c
e
s
s
n
g
C
o
r
e
(
s
)

i

Figure 2-13: Video System with Interlaced Content Using Deinterlacer

X22109-121018

Video Subsystem Software Guidelines

Each video subsystem comprises one or more video pipelines. A video pipeline is any chain
of video IP cores that starts from a Video-In or AXI VDMA (MM2S Channel) core and
terminates on a Video-Out or AXI VDMA (S2MM channel) core.

Each pipeline must be reset, configured, reconfigured, enabled, or disabled starting from
the output (back-end) moving toward the input (front-end). The following is a list of typical
video pipeline operations that must be performed from back-end to front-end:

• Video pipeline reset: Resetting all cores within a pipeline

• Video pipeline configuration: Configuring all cores after reset. Do not Enable the cores

during this step

• Video pipeline dynamic reconfiguration: Configuring all cores without resetting, such

as a frame size change

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

35

Send Feedback


Video Subsystem Software Guidelines

• Video pipeline enable: Enabling all cores within a pipeline

• Video pipeline disable: Disabling all cores within a pipeline

In general, to initialize a video pipe, the following operations should be performed in this
order:

1.

Initialize all video IP drivers.

2. Reset all cores starting from the back-end first, moving forward in the pipe.

3. Configure without enabling all cores starting from the back-end first, moving forward in

the pipe.

4. Enable all cores starting from the back-end first, moving forward in the pipe.

Note: Step one only needs to be done once after boot time. Drivers do not need to be reinitialized
if the video pipeline needs to be reconfigured.

If a video subsystem contains more than one video pipeline, then each pipeline can be
operated upon individually. However, in most applications the input (front-end) pipelines
should be operated upon first, before back-end pipelines to avoid invalid data to be
processed and/or displayed.

Note: Pipelines are operated upon from front-end to back-end. Cores within a pipeline are operated
upon from back-end to front-end.

Video Pipeline Example

Refer to the video subsystem depicted in Figure 2-14 in the following example operations
and C code snippets. This video subsystem contains three video pipelines. The three
pipelines consist of the following cores:

•

Pipeline 1:

Video to AXI4-Stream

Video IP 1

AXI VDMA 1 (S2MM Channel)

°

°

°

•

Pipeline 2:

AXI VDMA 1 (MM2S Channel)

Video Processing Subsystem

AXI VDMA 2 (S2MM Channel)

°

°

°

•

Pipeline 3:

AXI VDMA 2 (MM2S Channel)

Video IP 2

°

°

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

36

Send Feedback
X-Ref Target - Figure 2-14

HDMI

AXI4-Stream to Video

°

Video
To
AXI4
Stream

AXI4-S

Video IP
1

Video Subsystem Software Guidelines

Video IP
2

AXI4-S

AXI4
Stream
To
Video

HDMI

S
-
4
X
A

I

S
-
4
I
X
A

Video
Timing
Controller
Detector

VDMA
1

AXI4-S

Video
Scaler

AXI4-S

VDMA
2

Video
Timing
Controller
Generator

Figure 2-14:

Example Video Subsystem with Three Video Pipelines

To bring up this system in software, the following operations should be performed in the
following order:

1.

Initialize core drivers (Perform One time only) using the <core>_CfgInitialize()
functions.

2. Bring up Pipeline 1 (Input Video Pipeline)

a. SW Reset AXI VDMA 1 (S2MM Channel)

b. SW Reset Video IP 1

c. SW Reset VTC detector

d. Configure AXI VDMA 1 (S2MM Channel)

e. Configure Video IP 1

f. Configure VTC detector

g. Enable AXI VDMA 1 (S2MM Channel)

h. Enable Video IP 1

i.

Enable VTC detector

3. Bring up Pipeline 2 (Scaler Pipeline)

a. SW Reset AXI VDMA 2 (S2MM Channel)

b. SW Reset Scaler

c. SW Reset AXI VDMA 1 (MM2S Channel)

d. Configure AXI VDMA 2 (MM2S Channel)

e. Configure Scaler

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

37

Send Feedback
Video Subsystem Software Guidelines

f. Configure AXI VDMA 1 (MM2S Channel)

g. Enable AXI VDMA 2 (MM2S Channel)

h. Enable Scaler

i.

Enable AXI VDMA 1 (MM2S Channel)

4. Bring up Pipeline 3 (Output Video Pipeline)

a. SW Reset VTC generator

b. SW Reset Video IP 2

c. SW Reset AXI VDMA 2 (MM2S Channel)

d. Configure VTC generator

e. Configure Video IP 2

f. Configure AXI VDMA 2 (MM2S Channel)

g. Enable VTC generator

h. Enable Video IP 2

i.

Enable AXI VDMA 2 (MM2S Channel)

To reconfigure this system, perform the above operations except step 1 (Initialize core
drivers).

Note: VDMA S2MM and MM2S channels should be reset, configured, reconfigured and enabled
separately. Each VDMA channel should be treated as individual cores belonging to separate video
pipelines. Avoid operating on both channels at the same time. The channel operations should be
synchronized to the pipeline to which the channel belongs.

The following C code snippet shows the code needed to bring up the VDMA 1, Scaler, VDMA
2 pipeline:

#include <stdio.h>
#include "platform.h"
#include "xparameters.h"
#include "xscaler.h"
#include "xaxivdma.h"

////////////////////////////////////////////////////////////////////
// Global Defines
////////////////////////////////////////////////////////////////////
#define VIDIN_FBADDR 0x31800000
#define SCALEROUT_FBADDR 0x33000000

#define FRAME_STORE_WIDTH 2048
#define FRAME_STORE_HEIGHT 2048
#define FRAME_STORE_DATA_BYTES 2

#define VDMA_CIRC 1
#define VDMA_NOCIRC 0
#define VDMA_EXT_GENLOCK 0

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

38

Send Feedback
Video Subsystem Software Guidelines

#define VDMA_INT_GENLOCK 2
#define VDMA_S2MM_FSYNC 8
#define COEFF_SET_INDEX 0

////////////////////////////////////////////////////////////////////
// Function Prototypes
////////////////////////////////////////////////////////////////////
void vdma_init(XAxiVdma *VDMAPtr, int device_id);
int vdma_reset(XAxiVdma *VDMAPtr, int direction);
int vdma_setup(XAxiVdma *VDMAPtr,
int direction,
int width,
int height,
int frame_stores,
int start_address,
int mode
);
void scaler_init(XScaler *ScalerPtr, int device_id);
int scaler_setup(XScaler *ScalerInstPtr,
int ScalerInWidth,
int ScalerInHeight,
int ScalerOutWidth,
int ScalerOutHeight);

////////////////////////////////////////////////////////////////////
// Global Core Driver Structures
////////////////////////////////////////////////////////////////////
XAxiVdma VDMA1;
XAxiVdma VDMA2;
XScaler Scaler;

XScalerAperture Aperture;/* Aperture setting */
XScalerStartFraction StartFraction;/* Luma/Chroma Start Fraction setting*/
XScalerCoeffBank CoeffBank;/* Coefficient bank */

////////////////////////////////////////////////////////////////////
// Function: configure_scaler_pipeline()
// Configure Scaler Pipeline (Pipeline 2)
////////////////////////////////////////////////////////////////////
int configure_scaler_pipeline(
int input_x,
int input_y,
int output_x,
int output_y)
{
int Status;
////////////////////////////////////////////////////////////
// Initialize Drivers – Order not important
// Do after clocks are setup
///////////////////////////////////////////////////////////
vdma_init (&VDMA1, 0);
vdma_init (&VDMA2, 1);
scaler_init(&Scaler, 0);

///////////////////////////////////////////////////////////////////////////
// Pipeline 2: Reset Cores
///////////////////////////////////////////////////////////////////////////

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

39

Send Feedback
Video Subsystem Software Guidelines

vdma_reset (&VDMA2, XAXIVDMA_WRITE);
scaler_reset(&Scaler);
vdma_reset (&VDMA1, XAXIVDMA_READ);

///////////////////////////////////////////////////////////////////////////
// Pipeline 2: Configure Cores
///////////////////////////////////////////////////////////////////////////
printf("Setting up VDMA Writer...\n");
vdma_setup(&VDMA2,
XAXIVDMA_WRITE,
output_x,
output_y,
3,
SCALEROUT_FBADDR,
VDMA_NOCIRC|VDMA_INT_GENLOCK);

printf("Setting up Scaler...\n");
scaler_setup(&Scaler, input_x, input_y, output_x, output_y);

printf("Setting up VDMA Reader...\n");
vdma_setup(&VDMA1,
XAXIVDMA_READ,
input_x,
input_y,
3,
VIDIN_FBADDR,
VDMA_NOCIRC|VDMA_INT_GENLOCK|VDMA_S2MM_FSYNC);

///////////////////////////////////////////////////////////////////////////
// Pipeline 2: Enable cores
///////////////////////////////////////////////////////////////////////////

//Enable write VDMA, VDMA2 (S2MM Channel)
Status = XAxiVdma_DmaStart(&VDMA2, XAXIVDMA_WRITE);
if (Status != XST_SUCCESS)
{
printf("ERROR: VDMA2 Start write transfer failed %d\r\n", Status);
return XST_FAILURE;
}

XScaler_Enable(&Scaler);

Status = XAxiVdma_DmaStart(&VDMA1, XAXIVDMA_READ);
if (Status != XST_SUCCESS)
{
printf("ERROR: VDMA1 Start read transfer failed %d\r\n", Status);
return XST_FAILURE;
}

return 1;
}

///////////////////////////////////////////////////////////////////
// Function: vdma_init()
// Initialize VDMA Driver
////////////////////////////////////////////////////////////////////
void vdma_init(XAxiVdma *VDMAPtr, int device_id)
{

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

40

Send Feedback
Video Subsystem Software Guidelines

int Status;
XAxiVdma_Config *VDMACfgPtr;

VDMACfgPtr = XAxiVdma_LookupConfig(device_id);
if (!VDMACfgPtr)
{

printf("ERROR: No VDMA found for ID %d\r\n", device_id);
}

Status = XAxiVdma_CfgInitialize(VDMAPtr,
VDMACfgPtr,
VDMACfgPtr->BaseAddress
);
if (Status != XST_SUCCESS) {
printf( "ERROR: VDMA Configuration Initialization failed %d\r\n",
Status);
}

}
////////////////////////////////////////////////////////////////////
// VDMA Channel Reset
////////////////////////////////////////////////////////////////////
int vdma_reset(XAxiVdma *VDMAPtr, int direction)
{

int Polls;

printf("Resetting VDMA ...\n");
XAxiVdma_Reset(VDMAPtr, direction);
Polls = 100000;

while (Polls && XAxiVdma_ResetNotDone(VDMAPtr, direction)) {
Polls -= 1;
}

if (!Polls) {
printf( "ERROR: VDMA %s channel reset failed %x\n\r",
(direction==XAXIVDMA_READ)?"Read":"Write", 0);

return XST_FAILURE;
}

return 1;
}

////////////////////////////////////////////////////////////////////
// VDMA Channel Configure/Setup
////////////////////////////////////////////////////////////////////
int vdma_setup(XAxiVdma *VDMAPtr, int direction, int width, int height, int
frame_stores, int start_address, int mode)
{
int Status, i, Addr;

XAxiVdma_DmaSetup DmaSetup;

//printf("Setting up VDMA Read Config...\n");
DmaSetup.VertSizeInput = height;

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

41

Send Feedback
Video Subsystem Software Guidelines

DmaSetup.HoriSizeInput = width * FRAME_STORE_DATA_BYTES ;

DmaSetup.Stride = FRAME_STORE_WIDTH * FRAME_STORE_DATA_BYTES ;
DmaSetup.FrameDelay = 0;

DmaSetup.EnableCircularBuf = mode&1;
DmaSetup.EnableSync = mode&1;

DmaSetup.PointNum = (mode>>2) & 1;
DmaSetup.EnableFrameCounter = 0; /* Endless transfers */

DmaSetup.FixedFrameStoreAddr = 0; /* We are not doing parking */

//Only set the number of frames if the VDMA can support more that we need
//NOTE: the VDMA debug features for write to the frame store
// num reg must be enabled.
if(VDMAPtr->MaxNumFrames > frame_stores)
{
Status = XAxiVdma_SetFrmStore(VDMAPtr, frame_stores, direction);
if (Status != XST_SUCCESS) {

printf("WARNING %d: VDMA - Setting Frame Store Number to %d Failed for %s
Channel. Exiting config.\r\n",
Status, frame_stores,
(direction==XAXIVDMA_READ)?"Read":"Write");

return XST_FAILURE;
}
}

Status = XAxiVdma_DmaConfig(VDMAPtr, direction, &DmaSetup);
if (Status != XST_SUCCESS) {
printf("ERROR: VDMA - %s channel config failed. (%d)\r\n",
(direction==XAXIVDMA_READ)?"Read":"Write", Status);

return XST_FAILURE;
}

/* Initialize buffer addresses
*
* These addresses are physical addresses
*/
Addr = start_address;
for(i=0; i < frame_stores; i++) {
printf(" vdma_setup: Address %d = 0x%08x.\n\r", i, Addr);
DmaSetup.FrameStoreStartAddr[i] = Addr;

Addr += FRAME_STORE_WIDTH * FRAME_STORE_HEIGHT * FRAME_STORE_DATA_BYTES;
}

/* Set the buffer addresses for transfer in the DMA engine
* The buffer addresses are physical addresses
*/
Status = XAxiVdma_DmaSetBufferAddr(VDMAPtr, direction,
DmaSetup.FrameStoreStartAddr);
if (Status != XST_SUCCESS) {

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

42

Send Feedback

Video Subsystem Software Guidelines

printf("ERROR: VDMA - %s channel set buffer address failed %d\r\n",
(direction==XAXIVDMA_READ)?"Read":"Write",Status);

return XST_FAILURE;
}

if(direction==XAXIVDMA_WRITE)
{
// use the TUSER bit for the frame sync for the write (S2MM side)
XAxiVdma_FsyncSrcSelect(VDMAPtr,
XAXIVDMA_S2MM_TUSER_FSYNC,
XAXIVDMA_WRITE);
}
else
{
if(mode&0x08)
{
// VDMA Read (MM2S side) for the scaler input must be synced
// to the S2MM frame Sync
XAxiVdma_FsyncSrcSelect(VDMAPtr,
XAXIVDMA_CHAN_OTHER_FSYNC,
XAXIVDMA_READ); // DMA_CR[6:5] = 0b01

}
else
{
// VDMA 2 Read (MM2S side) must be not by synced and in free run
// Its timing is governed by the output VTC generator
// and AXI4-Stream to Video Out
XAxiVdma_FsyncSrcSelect(VDMAPtr, XAXIVDMA_CHAN_FSYNC, XAXIVDMA_READ);
// DMA_CR[6:5] = 0b00
}
}

Status = XAxiVdma_GenLockSourceSelect(VDMAPtr, (mode>>1)&1, direction);
if (Status != XST_SUCCESS) {
printf("ERROR: VDMA - %s channel set gen-lock %s src failed %d\r\n",
(direction==XAXIVDMA_READ)?"Read":"Write",
(((mode>>1)&1)==XAXIVDMA_INTERNAL_GENLOCK)?"Internal":"External",

Status);

return XST_FAILURE;
}

return 1;

}
////////////////////////////////////////////////////////////////////
// Initialize Scaler Driver
////////////////////////////////////////////////////////////////////
void scaler_init(XScaler *ScalerPtr, int device_id)
{
int Status;
XScaler_Config *ScalerCfgPtr;

ScalerCfgPtr = XScaler_LookupConfig(device_id);
if (!ScalerCfgPtr)
{

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

43

Send Feedback
Video Subsystem Software Guidelines

printf("ERROR: No Scaler found for ID %d\r\n", device_id);
}
Status = XScaler_CfgInitialize(ScalerPtr,
ScalerCfgPtr,
ScalerCfgPtr->BaseAddress);
if (Status != XST_SUCCESS) {
printf( "ERROR: Scaler Configuration Initialization failed %d\r\n",
Status);
}

}
////////////////////////////////////////////////////////////////////
// Scaler Configure/Setup
////////////////////////////////////////////////////////////////////
int scaler_setup(XScaler *ScalerInstPtr,

int ScalerInWidth, int ScalerInHeight,
int ScalerOutWidth, int ScalerOutHeight)

{
u8 ChromaFormat;
u8 ChromaLumaShareCoeffBank;
u8 HoriVertShareCoeffBank;

/*
* Disable the scaler before setup and tell the device not to pick up
* the register updates until all are done
*/
XScaler_DisableRegUpdate(ScalerInstPtr);
XScaler_Disable(ScalerInstPtr);

/*
* Load a set of Coefficient values
*/

/* Fetch Chroma Format and Coefficient sharing info */
XScaler_GetCoeffBankSharingInfo(ScalerInstPtr,
&ChromaFormat,
&ChromaLumaShareCoeffBank,
&HoriVertShareCoeffBank);

CoeffBank.SetIndex = COEFF_SET_INDEX;
CoeffBank.PhaseNum = ScalerInstPtr->Config.MaxPhaseNum;
CoeffBank.TapNum = ScalerInstPtr->Config.VertTapNum;

/* Locate coefficients for Horizontal scaling */
CoeffBank.CoeffValueBuf = (s16 *)
XScaler_CoefValueLookup(ScalerInWidth,
ScalerOutWidth,
CoeffBank.TapNum,
CoeffBank.PhaseNum);

/* Load coefficient bank for Horizontal Luma */
XScaler_LoadCoeffBank(ScalerInstPtr, &CoeffBank);

/* Horizontal Chroma bank is loaded only if chroma/luma sharing flag
* is not set */
if (!ChromaLumaShareCoeffBank)
XScaler_LoadCoeffBank(ScalerInstPtr, &CoeffBank);

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

44

Send Feedback
Video Subsystem Software Guidelines

/* Vertical coeff banks are loaded only if horizontal/vertical sharing
* flag is not set
*/
if (!HoriVertShareCoeffBank) {

/* Locate coefficients for Vertical scaling */
CoeffBank.CoeffValueBuf = (s16 *)
XScaler_CoefValueLookup(ScalerInHeight,
ScalerOutHeight,
CoeffBank.TapNum,
CoeffBank.PhaseNum);

/* Load coefficient bank for Vertical Luma */
XScaler_LoadCoeffBank(ScalerInstPtr, &CoeffBank);

/* Vertical Chroma coeff bank is loaded only if chroma/luma
* sharing flag is not set
*/
if (!ChromaLumaShareCoeffBank)
XScaler_LoadCoeffBank(ScalerInstPtr, &CoeffBank);
}

/*
* Load phase-offsets into scaler
*/
StartFraction.LumaLeftHori = 0;
StartFraction.LumaTopVert = 0;
StartFraction.ChromaLeftHori = 0;
StartFraction.ChromaTopVert = 0;
XScaler_SetStartFraction(ScalerInstPtr, &StartFraction);

/*
* Set up Aperture.
*/
Aperture.InFirstLine = 0;
Aperture.InLastLine = ScalerInHeight - 1;

Aperture.InFirstPixel = 0;
Aperture.InLastPixel = ScalerInWidth - 1;

Aperture.OutVertSize = ScalerOutHeight;
Aperture.OutHoriSize = ScalerOutWidth;

// Added by Xilinx 2012.12.10
Aperture.SrcVertSize = ScalerInHeight;
Aperture.SrcHoriSize = ScalerInWidth;

XScaler_SetAperture(ScalerInstPtr, &Aperture);

/*
* Set up phases
*/
XScaler_SetPhaseNum(ScalerInstPtr, ScalerInstPtr->Config.MaxPhaseNum,
ScalerInstPtr->Config.MaxPhaseNum);

/*
* Choose active set indexes for both vertical and horizontal directions
*/

AXI4-Stream Video IP and System Design
UG934 November 16, 2022

www.xilinx.com

45

Send Feedback
