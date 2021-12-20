
SOURCE_FILES=finder.swift stderr.swift dirsize.swift main.swift

all: trash

docs: trash.1

trash: $(SOURCE_FILES)
	@echo
	@echo ---- Compiling:
	@echo ======================================
	swiftc -Osize -remove-runtime-asserts -o $@ $(SOURCE_FILES)
	strip $@

clean:
	@echo
	@echo ---- Cleaning up:
	@echo ======================================
	-rm -Rf trash
