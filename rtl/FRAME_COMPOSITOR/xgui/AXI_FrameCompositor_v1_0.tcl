# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "G_BLUR_SOBEL_DELAY" -parent ${Page_0}
  ipgui::add_param $IPINST -name "G_COMPONENT_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "G_FAST_COLOR" -parent ${Page_0}
  ipgui::add_param $IPINST -name "G_SOBEL_COLOR" -parent ${Page_0}
  ipgui::add_param $IPINST -name "G_SOBEL_DELAY" -parent ${Page_0}


}

proc update_PARAM_VALUE.G_BLUR_SOBEL_DELAY { PARAM_VALUE.G_BLUR_SOBEL_DELAY } {
	# Procedure called to update G_BLUR_SOBEL_DELAY when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.G_BLUR_SOBEL_DELAY { PARAM_VALUE.G_BLUR_SOBEL_DELAY } {
	# Procedure called to validate G_BLUR_SOBEL_DELAY
	return true
}

proc update_PARAM_VALUE.G_COMPONENT_WIDTH { PARAM_VALUE.G_COMPONENT_WIDTH } {
	# Procedure called to update G_COMPONENT_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.G_COMPONENT_WIDTH { PARAM_VALUE.G_COMPONENT_WIDTH } {
	# Procedure called to validate G_COMPONENT_WIDTH
	return true
}

proc update_PARAM_VALUE.G_FAST_COLOR { PARAM_VALUE.G_FAST_COLOR } {
	# Procedure called to update G_FAST_COLOR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.G_FAST_COLOR { PARAM_VALUE.G_FAST_COLOR } {
	# Procedure called to validate G_FAST_COLOR
	return true
}

proc update_PARAM_VALUE.G_SOBEL_COLOR { PARAM_VALUE.G_SOBEL_COLOR } {
	# Procedure called to update G_SOBEL_COLOR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.G_SOBEL_COLOR { PARAM_VALUE.G_SOBEL_COLOR } {
	# Procedure called to validate G_SOBEL_COLOR
	return true
}

proc update_PARAM_VALUE.G_SOBEL_DELAY { PARAM_VALUE.G_SOBEL_DELAY } {
	# Procedure called to update G_SOBEL_DELAY when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.G_SOBEL_DELAY { PARAM_VALUE.G_SOBEL_DELAY } {
	# Procedure called to validate G_SOBEL_DELAY
	return true
}


proc update_MODELPARAM_VALUE.G_COMPONENT_WIDTH { MODELPARAM_VALUE.G_COMPONENT_WIDTH PARAM_VALUE.G_COMPONENT_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.G_COMPONENT_WIDTH}] ${MODELPARAM_VALUE.G_COMPONENT_WIDTH}
}

proc update_MODELPARAM_VALUE.G_SOBEL_COLOR { MODELPARAM_VALUE.G_SOBEL_COLOR PARAM_VALUE.G_SOBEL_COLOR } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.G_SOBEL_COLOR}] ${MODELPARAM_VALUE.G_SOBEL_COLOR}
}

proc update_MODELPARAM_VALUE.G_FAST_COLOR { MODELPARAM_VALUE.G_FAST_COLOR PARAM_VALUE.G_FAST_COLOR } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.G_FAST_COLOR}] ${MODELPARAM_VALUE.G_FAST_COLOR}
}

proc update_MODELPARAM_VALUE.G_SOBEL_DELAY { MODELPARAM_VALUE.G_SOBEL_DELAY PARAM_VALUE.G_SOBEL_DELAY } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.G_SOBEL_DELAY}] ${MODELPARAM_VALUE.G_SOBEL_DELAY}
}

proc update_MODELPARAM_VALUE.G_BLUR_SOBEL_DELAY { MODELPARAM_VALUE.G_BLUR_SOBEL_DELAY PARAM_VALUE.G_BLUR_SOBEL_DELAY } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.G_BLUR_SOBEL_DELAY}] ${MODELPARAM_VALUE.G_BLUR_SOBEL_DELAY}
}

