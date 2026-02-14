# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "G_COMPONENT_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "G_OUTPUT_WIDTH" -parent ${Page_0}


}

proc update_PARAM_VALUE.G_COMPONENT_WIDTH { PARAM_VALUE.G_COMPONENT_WIDTH } {
	# Procedure called to update G_COMPONENT_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.G_COMPONENT_WIDTH { PARAM_VALUE.G_COMPONENT_WIDTH } {
	# Procedure called to validate G_COMPONENT_WIDTH
	return true
}

proc update_PARAM_VALUE.G_OUTPUT_WIDTH { PARAM_VALUE.G_OUTPUT_WIDTH } {
	# Procedure called to update G_OUTPUT_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.G_OUTPUT_WIDTH { PARAM_VALUE.G_OUTPUT_WIDTH } {
	# Procedure called to validate G_OUTPUT_WIDTH
	return true
}


proc update_MODELPARAM_VALUE.G_COMPONENT_WIDTH { MODELPARAM_VALUE.G_COMPONENT_WIDTH PARAM_VALUE.G_COMPONENT_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.G_COMPONENT_WIDTH}] ${MODELPARAM_VALUE.G_COMPONENT_WIDTH}
}

proc update_MODELPARAM_VALUE.G_OUTPUT_WIDTH { MODELPARAM_VALUE.G_OUTPUT_WIDTH PARAM_VALUE.G_OUTPUT_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.G_OUTPUT_WIDTH}] ${MODELPARAM_VALUE.G_OUTPUT_WIDTH}
}

