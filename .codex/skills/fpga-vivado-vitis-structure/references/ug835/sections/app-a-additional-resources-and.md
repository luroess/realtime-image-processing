# Appendix A: Additional Resources and

_Source lines: 92502-92674_

Appendix A: Additional Resources and
Legal Notices
Finding Additional Documentation
Technical Information Portal
The AMD Technical Information Portal is an online tool that provides robust search and navigation
for documentation using your web browser. To access the Technical Information Portal, go to https://
docs.amd.com.

Documentation Navigator
Documentation Navigator (DocNav) is an installed tool that provides access to AMD Adaptive
Computing documents, videos, and support resources, which you can filter and search to find
information. To open DocNav:

• From the AMD Vivado™ IDE, select Help > Documentation and Tutorials.
• On Windows, click the Start button and select Xilinx Design Tools > DocNav.
• At the Linux command prompt, enter docnav.

Note: For more information on DocNav, refer to the Documentation Navigator User Guide (UG968).

Design Hubs
AMD Design Hubs provide links to documentation organized by design tasks and other topics, which you
can use to learn key concepts and address frequently asked questions. To access the Design Hubs:

• In DocNav, click the Design Hubs View tab.
• Go to the Design Hubs web page.

Support Resources
For support resources such as Answers, Documentation, Downloads, and Forums, see Support.


Tcl Resources
Training Resources
AMD provides a variety of training courses and QuickTake videos to help you learn more about the
concepts presented in this document. Use these links to explore related training resources:

• UltraFast Design Methodology Training Course

UG835 v2025.2 1993
Send Feedback
November 20, 2025

## Page 1994
<!-- page:1994 -->
Additional Resources and Legal Notices


• Designing with UltraScale and UltraScale+ Architectures Training Course
• Designing FPGAs Using the Vivado Design Suite Training Course
• Vivado Design Suite QuickTake Video: Using the Non-Project Batch Flow
• Vivado Design Suite QuickTake Video: Using Tcl Scripts as Constraint Files in Vivado

References
• Vivado Design Suite User Guide: Design Flows Overview (UG892)
• Vivado Design Suite User Guide: Using the Vivado IDE (UG893)
• Vivado Design Suite User Guide: Using Tcl Scripting (UG894)
• Vivado Design Suite User Guide: Using Constraints (UG903)
• Vivado Design Suite Properties Reference Guide (UG912)

Tcl Developer Xchange
Tcl reference material is available on the Internet. AMD recommends the Tcl Developer Xchange, which
maintains the open source code base for Tcl, and is located at:

http://www.tcl.tk

An introductory tutorial is available at:

http://www.tcl.tk/man/tcl8.5/tutorial/tcltutorial.html

About SDC
Synopsys Design Constraints (SDC) is an accepted industry standard for communicating design intent
to tools, particularly for timing analysis. A reference copy of the SDC specification is available from
Synopsys by registering for the TAP-in program at:

http://www.synopsys.com/Community/Interoperability/Pages/TapinSDC.aspx


Revision History
The following table shows the revision history for this document:

Section Revision Summary
11/20/2025 Version 2025.2
generate_puf_kek, report_slr_crossing Commands Added in 2025.2


UG835 v2025.2 1994
Send Feedback
November 20, 2025

## Page 1995
<!-- page:1995 -->
Additional Resources and Legal Notices


Section Revision Summary
add_qor_checks, create_bd_intf_port, create_qor_ruledeck,
delete_qor_checks, delete_qor_ruledecks, get_dfx_footprint,
get_noc_connections, get_noc_interfaces, get_qor_ruledecks,
get_timing_paths, make_wrapper, opt_design, pr_verify, Commands Modified in 2025.2
program_hw_devices, report_clock_uncertainty, report_place_status,
report_pulse_width, report_timing, report_timing_summary,
validate_board_files, write_cfgmem, xsim
06/16/2025 Version 2025.1
add_qor_checks, clear_noc_solution, create_qor_ruledeck,
delete_qor_checks, delete_qor_ruledecks, finalize_eco, get_qor_ruledecks,
Commands Added in 2025.1
get_qor_timing_paths, move_pblock, report_clock_uncertainty,
report_noc_qos, report_sim_env, write_noc_qos
export_xsim_coverage, get_drc_checks, get_example_designs,
open_checkpoint, phys_opt_design, place_design, read_noc_solution,
report_dfx_summary, report_pulse_width, report_qor_suggestions,
Commands Modified in 2025.1
report_ram_utilization, report_route_status, report_utilization,
validate_cluster_configurations, write_device_image, write_noc_solution,
write_project_tcl
report_noc_addresses Commands Removed in 2025.1


UG835 v2025.2 1995
Send Feedback
November 20, 2025

## Page 1996
<!-- page:1996 -->
Additional Resources and Legal Notices


Please Read: Important Legal Notices
The information presented in this document is for informational purposes only and may contain
technical inaccuracies, omissions, and typographical errors. The information contained herein is
subject to change and may be rendered inaccurate for many reasons, including but not limited to
product and roadmap changes, component and motherboard version changes, new model and/or
product releases, product differences between differing manufacturers, software changes, BIOS
flashes, firmware upgrades, or the like. Any computer system has risks of security vulnerabilities that
cannot be completely prevented or mitigated. AMD assumes no obligation to update or otherwise
correct or revise this information. However, AMD reserves the right to revise this information and
to make changes from time to time to the content hereof without obligation of AMD to notify any
person of such revisions or changes. THIS INFORMATION IS PROVIDED "AS IS." AMD MAKES NO
REPRESENTATIONS OR WARRANTIES WITH RESPECT TO THE CONTENTS HEREOF AND ASSUMES
NO RESPONSIBILITY FOR ANY INACCURACIES, ERRORS, OR OMISSIONS THAT MAY APPEAR
IN THIS INFORMATION. AMD SPECIFICALLY DISCLAIMS ANY IMPLIED WARRANTIES OF NON-
INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR ANY PARTICULAR PURPOSE. IN NO EVENT
WILL AMD BE LIABLE TO ANY PERSON FOR ANY RELIANCE, DIRECT, INDIRECT, SPECIAL, OR
OTHER CONSEQUENTIAL DAMAGES ARISING FROM THE USE OF ANY INFORMATION CONTAINED
HEREIN, EVEN IF AMD IS EXPRESSLY ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

AUTOMOTIVE APPLICATIONS DISCLAIMER
AUTOMOTIVE PRODUCTS (IDENTIFIED AS "XA" IN THE PART NUMBER) ARE NOT WARRANTED
FOR USE IN THE DEPLOYMENT OF AIRBAGS OR FOR USE IN APPLICATIONS THAT AFFECT
CONTROL OF A VEHICLE ("SAFETY APPLICATION") UNLESS THERE IS A SAFETY CONCEPT OR
REDUNDANCY FEATURE CONSISTENT WITH THE ISO 26262 AUTOMOTIVE SAFETY STANDARD
("SAFETY DESIGN"). CUSTOMER SHALL, PRIOR TO USING OR DISTRIBUTING ANY SYSTEMS THAT
INCORPORATE PRODUCTS, THOROUGHLY TEST SUCH SYSTEMS FOR SAFETY PURPOSES. USE OF
PRODUCTS IN A SAFETY APPLICATION WITHOUT A SAFETY DESIGN IS FULLY AT THE RISK OF
CUSTOMER, SUBJECT ONLY TO APPLICABLE LAWS AND REGULATIONS GOVERNING LIMITATIONS
ON PRODUCT LIABILITY.

Copyright
© Copyright 2012-2025 Advanced Micro Devices, Inc. AMD, the AMD Arrow logo, Artix, Kintex,
Spartan, UltraScale, UltraScale+, Versal, Virtex, Vitis, Vivado, Zynq, and combinations thereof are
trademarks of Advanced Micro Devices, Inc. PCI, PCIe, and PCI Express are trademarks of PCI-SIG and
used under license. AMBA, AMBA Designer, Arm, ARM1176JZ-S, CoreSight, Cortex, PrimeCell, Mali,
and MPCore are trademarks of Arm Limited in the US and/or elsewhere. MATLAB and Simulink are
registered trademarks of The MathWorks, Inc. Other product names used in this publication are for
identification purposes only and may be trademarks of their respective companies.


UG835 v2025.2 1996
Send Feedback
November 20, 2025

## Page 1997
<!-- page:1997 -->
_No extractable text on this page._
