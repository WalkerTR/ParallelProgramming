CHPL = chpl
FLAGS = --fast
MULTILOCALE_FLAGS = CHPL_COMM=gasnet CHPL_COMM_SUBSTRATE=ibv

APP = heat_dissipation
APP_SRC = heat_dissipation.chpl util.chpl

$(APP): $(APP_SRC)
	$(MULTILOCALE_FLAGS) $(CHPL) -o $@ $(FLAGS) $<

clean: 
	rm -f $(APP) $(APP)_real

jobclean:
	rm -f HEAT_DISSIPATION.*
