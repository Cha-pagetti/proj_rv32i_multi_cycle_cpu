

# vcs Make file
RTL_DIR   = ./rtl
PKG_DIR   = ./rtl/pkg
TB_DIR    = ./tb
BUILD_DIR = ./build
INC_DIR   = +incdir+$(RTL_DIR)
SIMV_DIR  = ./build/simv
SIMV_OPTS := -cm line+cond+fsm+tgl+branch+assert -cm_dir coverage.vdb -cm_name sim1
SIMV_OPTS += +UVM_VERBOSITY=UVM_HIGH
VCS_OPT   = -full64 -sverilog -debug_access+all -kdb -lca \
            -timescale=1ns/1ps \
            -ntb_opts uvm-1.2 \
            $(INC_DIR) \
            -o $(SIMV_DIR)

all: run simv

generate_f:
	rm -f files.f
	find $(PKG_DIR) \( -name "*.v" -o -name "*.sv" \) | sort >  files.f
	find $(RTL_DIR) -path $(PKG_DIR) -prune -o \
	      \( -name "*.v" -o -name "*.sv" \) -print | sort >> files.f
	find $(TB_DIR)  \( -name "*.v" -o -name "*.sv" \) | sort >> files.f

run: generate_f
	mkdir -p $(BUILD_DIR)
	vcs      $(VCS_OPT) -f files.f

simv:
	$(SIMV_DIR) $(SIMV_OPTS)

verdi:
	verdi -dbdir $(BUILD_DIR)/simv.daidir -ssf wave.fsdb &

clean:
	rm -rf $(BUILD_DIR) csrc novas* ucli.key verdiLog files.f *.fsdb inter.fsdb .inter.fsdb.tbsim sys*

.PHONY: all generate_f run simv verdi clean
