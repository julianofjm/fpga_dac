target = "xilinx"
action = "synthesis"

syn_device = "XC6SLX45T"
syn_grade = "-3"
syn_package = "FGG484"
syn_top = "fpga_dac"
syn_project = "fpga_dac.xise"

files = [	"clk_gen.vhd",
			"dac_dds.vhd",
			"dac_spi.vhd",
			"dac_config.vhd",
			"fpga_dac.vhd",
			"fpga_dac.ucf",
			"ipcore_dds/dds_compiler_v5_0.vhd",
			"ipcore_dds/dds_compiler_v5_0.ngc",
			"ipcore_dir/clk_pll.vhd",
			"ipcore_dir/chipscope_icon.vhd",
			"ipcore_dir/chipscope_ila.vhd",
			"ipcore_dir/chipscope_icon.ngc",
			"ipcore_dir/chipscope_ila.ngc"
		]
		
modules = { "local" : [
                        "wb_rs232_syscon",
                        "../general-cores"	# crossbar,  gc_reset and gc_sync_ffs
                      ] }

