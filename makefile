MAIN=Exploder
TRAY=Systray
MEMORY=memory
$(MAIN).exe: $(MAIN).obj $(TRAY).obj $(MEMORY).obj
        Link /SUBSYSTEM:WINDOWS /LIBPATH:c:\programs\coding~1\compil~1\masm32\lib $(MAIN).obj $(TRAY).obj $(MEMORY).obj
$(TRAY).obj: $(TRAY).asm
	ml /c /coff /Cp $(TRAY).asm
$(MEMORY).obj: $(MEMORY).asm
	ml /c /coff /Cp $(MEMORY).asm
$(MAIN).obj: $(MAIN).asm
        ml /c /coff /Cp $(MAIN).asm