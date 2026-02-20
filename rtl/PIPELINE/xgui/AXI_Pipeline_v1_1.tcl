# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "G_BLURR_BIAS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "G_BLURR_COEFF_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "G_BLURR_KERNEL_COEFFS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "G_BLURR_KERNEL_SIZE" -parent ${Page_0}
  ipgui::add_param $IPINST -name "G_BLURR_NORMALIZE_DIVISOR" -parent ${Page_0}
  ipgui::add_param $IPINST -name "G_CLK_FREQ_HZ" -parent ${Page_0}
  ipgui::add_param $IPINST -name "G_DEBOUNCE_NS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "G_EDGE_COLOR" -parent ${Page_0}
  ipgui::add_param $IPINST -name "G_LINE_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "G_NUM_ROW" -parent ${Page_0}
  ipgui::add_param $IPINST -name "G_PIXEL_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "G_SOBEL_MEAN_SHIFT" -parent ${Page_0}
  ipgui::add_param $IPINST -name "G_SOBEL_MEAN_UPDATE_INTERVAL" -parent ${Page_0}
  ipgui::add_param $IPINST -name "G_SOBEL_THRESHOLD" -parent ${Page_0}
  ipgui::add_param $IPINST -name "G_SOBEL_THRESHOLD_GAIN_DEN" -parent ${Page_0}
  ipgui::add_param $IPINST -name "G_SOBEL_THRESHOLD_GAIN_NUM" -parent ${Page_0}
  ipgui::add_param $IPINST -name "G_SOBEL_THRESHOLD_OFFSET" -parent ${Page_0}


}

proc update_PARAM_VALUE.G_BLURR_BIAS { PARAM_VALUE.G_BLURR_BIAS } {
	# Procedure called to update G_BLURR_BIAS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.G_BLURR_BIAS { PARAM_VALUE.G_BLURR_BIAS } {
	# Procedure called to validate G_BLURR_BIAS
	return true
}

proc update_PARAM_VALUE.G_BLURR_COEFF_WIDTH { PARAM_VALUE.G_BLURR_COEFF_WIDTH } {
	# Procedure called to update G_BLURR_COEFF_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.G_BLURR_COEFF_WIDTH { PARAM_VALUE.G_BLURR_COEFF_WIDTH } {
	# Procedure called to validate G_BLURR_COEFF_WIDTH
	return true
}

proc update_PARAM_VALUE.G_BLURR_KERNEL_COEFFS { PARAM_VALUE.G_BLURR_KERNEL_COEFFS } {
	# Procedure called to update G_BLURR_KERNEL_COEFFS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.G_BLURR_KERNEL_COEFFS { PARAM_VALUE.G_BLURR_KERNEL_COEFFS } {
	# Procedure called to validate G_BLURR_KERNEL_COEFFS
	return true
}

proc update_PARAM_VALUE.G_BLURR_KERNEL_SIZE { PARAM_VALUE.G_BLURR_KERNEL_SIZE } {
	# Procedure called to update G_BLURR_KERNEL_SIZE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.G_BLURR_KERNEL_SIZE { PARAM_VALUE.G_BLURR_KERNEL_SIZE } {
	# Procedure called to validate G_BLURR_KERNEL_SIZE
	return true
}

proc update_PARAM_VALUE.G_BLURR_NORMALIZE_DIVISOR { PARAM_VALUE.G_BLURR_NORMALIZE_DIVISOR } {
	# Procedure called to update G_BLURR_NORMALIZE_DIVISOR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.G_BLURR_NORMALIZE_DIVISOR { PARAM_VALUE.G_BLURR_NORMALIZE_DIVISOR } {
	# Procedure called to validate G_BLURR_NORMALIZE_DIVISOR
	return true
}

proc update_PARAM_VALUE.G_CLK_FREQ_HZ { PARAM_VALUE.G_CLK_FREQ_HZ } {
	# Procedure called to update G_CLK_FREQ_HZ when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.G_CLK_FREQ_HZ { PARAM_VALUE.G_CLK_FREQ_HZ } {
	# Procedure called to validate G_CLK_FREQ_HZ
	return true
}

proc update_PARAM_VALUE.G_DEBOUNCE_NS { PARAM_VALUE.G_DEBOUNCE_NS } {
	# Procedure called to update G_DEBOUNCE_NS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.G_DEBOUNCE_NS { PARAM_VALUE.G_DEBOUNCE_NS } {
	# Procedure called to validate G_DEBOUNCE_NS
	return true
}

proc update_PARAM_VALUE.G_EDGE_COLOR { PARAM_VALUE.G_EDGE_COLOR } {
	# Procedure called to update G_EDGE_COLOR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.G_EDGE_COLOR { PARAM_VALUE.G_EDGE_COLOR } {
	# Procedure called to validate G_EDGE_COLOR
	return true
}

proc update_PARAM_VALUE.G_LINE_WIDTH { PARAM_VALUE.G_LINE_WIDTH } {
	# Procedure called to update G_LINE_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.G_LINE_WIDTH { PARAM_VALUE.G_LINE_WIDTH } {
	# Procedure called to validate G_LINE_WIDTH
	return true
}

proc update_PARAM_VALUE.G_NUM_ROW { PARAM_VALUE.G_NUM_ROW } {
	# Procedure called to update G_NUM_ROW when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.G_NUM_ROW { PARAM_VALUE.G_NUM_ROW } {
	# Procedure called to validate G_NUM_ROW
	return true
}

proc update_PARAM_VALUE.G_PIXEL_WIDTH { PARAM_VALUE.G_PIXEL_WIDTH } {
	# Procedure called to update G_PIXEL_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.G_PIXEL_WIDTH { PARAM_VALUE.G_PIXEL_WIDTH } {
	# Procedure called to validate G_PIXEL_WIDTH
	return true
}

proc update_PARAM_VALUE.G_SOBEL_MEAN_SHIFT { PARAM_VALUE.G_SOBEL_MEAN_SHIFT } {
	# Procedure called to update G_SOBEL_MEAN_SHIFT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.G_SOBEL_MEAN_SHIFT { PARAM_VALUE.G_SOBEL_MEAN_SHIFT } {
	# Procedure called to validate G_SOBEL_MEAN_SHIFT
	return true
}

proc update_PARAM_VALUE.G_SOBEL_MEAN_UPDATE_INTERVAL { PARAM_VALUE.G_SOBEL_MEAN_UPDATE_INTERVAL } {
	# Procedure called to update G_SOBEL_MEAN_UPDATE_INTERVAL when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.G_SOBEL_MEAN_UPDATE_INTERVAL { PARAM_VALUE.G_SOBEL_MEAN_UPDATE_INTERVAL } {
	# Procedure called to validate G_SOBEL_MEAN_UPDATE_INTERVAL
	return true
}

proc update_PARAM_VALUE.G_SOBEL_THRESHOLD { PARAM_VALUE.G_SOBEL_THRESHOLD } {
	# Procedure called to update G_SOBEL_THRESHOLD when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.G_SOBEL_THRESHOLD { PARAM_VALUE.G_SOBEL_THRESHOLD } {
	# Procedure called to validate G_SOBEL_THRESHOLD
	return true
}

proc update_PARAM_VALUE.G_SOBEL_THRESHOLD_GAIN_DEN { PARAM_VALUE.G_SOBEL_THRESHOLD_GAIN_DEN } {
	# Procedure called to update G_SOBEL_THRESHOLD_GAIN_DEN when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.G_SOBEL_THRESHOLD_GAIN_DEN { PARAM_VALUE.G_SOBEL_THRESHOLD_GAIN_DEN } {
	# Procedure called to validate G_SOBEL_THRESHOLD_GAIN_DEN
	return true
}

proc update_PARAM_VALUE.G_SOBEL_THRESHOLD_GAIN_NUM { PARAM_VALUE.G_SOBEL_THRESHOLD_GAIN_NUM } {
	# Procedure called to update G_SOBEL_THRESHOLD_GAIN_NUM when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.G_SOBEL_THRESHOLD_GAIN_NUM { PARAM_VALUE.G_SOBEL_THRESHOLD_GAIN_NUM } {
	# Procedure called to validate G_SOBEL_THRESHOLD_GAIN_NUM
	return true
}

proc update_PARAM_VALUE.G_SOBEL_THRESHOLD_OFFSET { PARAM_VALUE.G_SOBEL_THRESHOLD_OFFSET } {
	# Procedure called to update G_SOBEL_THRESHOLD_OFFSET when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.G_SOBEL_THRESHOLD_OFFSET { PARAM_VALUE.G_SOBEL_THRESHOLD_OFFSET } {
	# Procedure called to validate G_SOBEL_THRESHOLD_OFFSET
	return true
}


proc update_MODELPARAM_VALUE.G_CLK_FREQ_HZ { MODELPARAM_VALUE.G_CLK_FREQ_HZ PARAM_VALUE.G_CLK_FREQ_HZ } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.G_CLK_FREQ_HZ}] ${MODELPARAM_VALUE.G_CLK_FREQ_HZ}
}

proc update_MODELPARAM_VALUE.G_DEBOUNCE_NS { MODELPARAM_VALUE.G_DEBOUNCE_NS PARAM_VALUE.G_DEBOUNCE_NS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.G_DEBOUNCE_NS}] ${MODELPARAM_VALUE.G_DEBOUNCE_NS}
}

proc update_MODELPARAM_VALUE.G_PIXEL_WIDTH { MODELPARAM_VALUE.G_PIXEL_WIDTH PARAM_VALUE.G_PIXEL_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.G_PIXEL_WIDTH}] ${MODELPARAM_VALUE.G_PIXEL_WIDTH}
}

proc update_MODELPARAM_VALUE.G_LINE_WIDTH { MODELPARAM_VALUE.G_LINE_WIDTH PARAM_VALUE.G_LINE_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.G_LINE_WIDTH}] ${MODELPARAM_VALUE.G_LINE_WIDTH}
}

proc update_MODELPARAM_VALUE.G_NUM_ROW { MODELPARAM_VALUE.G_NUM_ROW PARAM_VALUE.G_NUM_ROW } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.G_NUM_ROW}] ${MODELPARAM_VALUE.G_NUM_ROW}
}

proc update_MODELPARAM_VALUE.G_BLURR_KERNEL_SIZE { MODELPARAM_VALUE.G_BLURR_KERNEL_SIZE PARAM_VALUE.G_BLURR_KERNEL_SIZE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.G_BLURR_KERNEL_SIZE}] ${MODELPARAM_VALUE.G_BLURR_KERNEL_SIZE}
}

proc update_MODELPARAM_VALUE.G_BLURR_COEFF_WIDTH { MODELPARAM_VALUE.G_BLURR_COEFF_WIDTH PARAM_VALUE.G_BLURR_COEFF_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.G_BLURR_COEFF_WIDTH}] ${MODELPARAM_VALUE.G_BLURR_COEFF_WIDTH}
}

proc update_MODELPARAM_VALUE.G_BLURR_KERNEL_COEFFS { MODELPARAM_VALUE.G_BLURR_KERNEL_COEFFS PARAM_VALUE.G_BLURR_KERNEL_COEFFS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.G_BLURR_KERNEL_COEFFS}] ${MODELPARAM_VALUE.G_BLURR_KERNEL_COEFFS}
}

proc update_MODELPARAM_VALUE.G_BLURR_NORMALIZE_DIVISOR { MODELPARAM_VALUE.G_BLURR_NORMALIZE_DIVISOR PARAM_VALUE.G_BLURR_NORMALIZE_DIVISOR } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.G_BLURR_NORMALIZE_DIVISOR}] ${MODELPARAM_VALUE.G_BLURR_NORMALIZE_DIVISOR}
}

proc update_MODELPARAM_VALUE.G_BLURR_BIAS { MODELPARAM_VALUE.G_BLURR_BIAS PARAM_VALUE.G_BLURR_BIAS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.G_BLURR_BIAS}] ${MODELPARAM_VALUE.G_BLURR_BIAS}
}

proc update_MODELPARAM_VALUE.G_SOBEL_THRESHOLD { MODELPARAM_VALUE.G_SOBEL_THRESHOLD PARAM_VALUE.G_SOBEL_THRESHOLD } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.G_SOBEL_THRESHOLD}] ${MODELPARAM_VALUE.G_SOBEL_THRESHOLD}
}

proc update_MODELPARAM_VALUE.G_SOBEL_MEAN_SHIFT { MODELPARAM_VALUE.G_SOBEL_MEAN_SHIFT PARAM_VALUE.G_SOBEL_MEAN_SHIFT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.G_SOBEL_MEAN_SHIFT}] ${MODELPARAM_VALUE.G_SOBEL_MEAN_SHIFT}
}

proc update_MODELPARAM_VALUE.G_SOBEL_MEAN_UPDATE_INTERVAL { MODELPARAM_VALUE.G_SOBEL_MEAN_UPDATE_INTERVAL PARAM_VALUE.G_SOBEL_MEAN_UPDATE_INTERVAL } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.G_SOBEL_MEAN_UPDATE_INTERVAL}] ${MODELPARAM_VALUE.G_SOBEL_MEAN_UPDATE_INTERVAL}
}

proc update_MODELPARAM_VALUE.G_SOBEL_THRESHOLD_GAIN_NUM { MODELPARAM_VALUE.G_SOBEL_THRESHOLD_GAIN_NUM PARAM_VALUE.G_SOBEL_THRESHOLD_GAIN_NUM } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.G_SOBEL_THRESHOLD_GAIN_NUM}] ${MODELPARAM_VALUE.G_SOBEL_THRESHOLD_GAIN_NUM}
}

proc update_MODELPARAM_VALUE.G_SOBEL_THRESHOLD_GAIN_DEN { MODELPARAM_VALUE.G_SOBEL_THRESHOLD_GAIN_DEN PARAM_VALUE.G_SOBEL_THRESHOLD_GAIN_DEN } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.G_SOBEL_THRESHOLD_GAIN_DEN}] ${MODELPARAM_VALUE.G_SOBEL_THRESHOLD_GAIN_DEN}
}

proc update_MODELPARAM_VALUE.G_SOBEL_THRESHOLD_OFFSET { MODELPARAM_VALUE.G_SOBEL_THRESHOLD_OFFSET PARAM_VALUE.G_SOBEL_THRESHOLD_OFFSET } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.G_SOBEL_THRESHOLD_OFFSET}] ${MODELPARAM_VALUE.G_SOBEL_THRESHOLD_OFFSET}
}

proc update_MODELPARAM_VALUE.G_EDGE_COLOR { MODELPARAM_VALUE.G_EDGE_COLOR PARAM_VALUE.G_EDGE_COLOR } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.G_EDGE_COLOR}] ${MODELPARAM_VALUE.G_EDGE_COLOR}
}

