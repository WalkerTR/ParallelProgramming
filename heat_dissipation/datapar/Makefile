CHPL = chpl
FLAGS = --fast

APP = heat_dissipation
APP_SRC = heat_dissipation.chpl util.chpl

$(APP): $(APP_SRC)
	$(CHPL) -o $@ $(FLAGS) $<

clean: 
	rm -f $(APP)

jobclean:
	rm -f HEAT_DISSIPATION.*
