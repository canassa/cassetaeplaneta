# Microsoft Visual C++ generated build script - Do not modify

PROJ = TESTE
DEBUG = 1
PROGTYPE = 0
CALLER = 
ARGS = 
DLLS = 
D_RCDEFINES = -d_DEBUG
R_RCDEFINES = -dNDEBUG
ORIGIN = MSVC
ORIGIN_VER = 1.00
PROJPATH = D:\ATR\CASSETA\APLICAT\
USEMFC = 0
CC = cl
CPP = cl
CXX = cl
CCREATEPCHFLAG = 
CPPCREATEPCHFLAG = 
CUSEPCHFLAG = 
CPPUSEPCHFLAG = 
FIRSTC =             
FIRSTCPP =             
RC = rc
CFLAGS_D_WEXE = /nologo /W3 /FR /G2 /Zi /D_DEBUG /Od /AM /GA /Fd"TESTE.PDB"
CFLAGS_R_WEXE = /nologo /W3 /FR /O1 /DNDEBUG /AM /GA
LFLAGS_D_WEXE = /NOLOGO /ONERROR:NOEXE /NOD /PACKC:61440 /CO /ALIGN:16 /STACK:10240
LFLAGS_R_WEXE = /NOLOGO /ONERROR:NOEXE /NOD /PACKC:61440 /ALIGN:16 /STACK:10240
LIBS_D_WEXE = oldnames libw commdlg shell olecli olesvr mlibcew
LIBS_R_WEXE = oldnames libw commdlg shell olecli olesvr mlibcew
RCFLAGS = /nologo
RESFLAGS = /nologo
RUNFLAGS = 
DEFFILE = DEMO.DEF
OBJS_EXT = 
LIBS_EXT = 
!if "$(DEBUG)" == "1"
CFLAGS = $(CFLAGS_D_WEXE)
LFLAGS = $(LFLAGS_D_WEXE)
LIBS = $(LIBS_D_WEXE)
MAPFILE = nul
RCDEFINES = $(D_RCDEFINES)
!else
CFLAGS = $(CFLAGS_R_WEXE)
LFLAGS = $(LFLAGS_R_WEXE)
LIBS = $(LIBS_R_WEXE)
MAPFILE = nul
RCDEFINES = $(R_RCDEFINES)
!endif
!if [if exist MSVC.BND del MSVC.BND]
!endif
SBRS = READDATA.SBR


DEMO_RCDEP = d:\atr\casseta\aplicat\hand.cur \
	d:\atr\casseta\aplicat\right.cur \
	d:\atr\casseta\aplicat\left.cur \
	d:\atr\casseta\aplicat\lighton.ico


READDATA_DEP = d:\atr\casseta\aplicat\event.hpp \
	d:\atr\casseta\aplicat\screen.hpp \
	d:\atr\casseta\aplicat\3dscreen.hpp \
	d:\atr\casseta\aplicat\object.hpp \
	d:\atr\casseta\aplicat\3dobject.hpp \
	d:\atr\casseta\aplicat\ctrpanel.hpp \
	d:\atr\casseta\aplicat\scene.hpp \
	d:\atr\casseta\aplicat\vtree.h \
	d:\atr\casseta\aplicat\applicat.hpp \
	d:\atr\casseta\aplicat\readdata.hpp


all:	$(PROJ).EXE $(PROJ).BSC

DEMO.RES:	DEMO.RC $(DEMO_RCDEP)
	$(RC) $(RCFLAGS) $(RCDEFINES) -r DEMO.RC

READDATA.OBJ:	READDATA.CPP $(READDATA_DEP)
	$(CPP) $(CFLAGS) $(CPPUSEPCHFLAG) /c READDATA.CPP


$(PROJ).EXE::	DEMO.RES

$(PROJ).EXE::	READDATA.OBJ $(OBJS_EXT) $(DEFFILE)
	echo >NUL @<<$(PROJ).CRF
READDATA.OBJ +
$(OBJS_EXT)
$(PROJ).EXE
$(MAPFILE)
c:\msvc\lib\+
c:\msvc\mfc\lib\+
c:\wing\lib\+
c:\wintoon\lib\+
$(LIBS)
$(DEFFILE);
<<
	link $(LFLAGS) @$(PROJ).CRF
	$(RC) $(RESFLAGS) DEMO.RES $@
	@copy $(PROJ).CRF MSVC.BND

$(PROJ).EXE::	DEMO.RES
	if not exist MSVC.BND 	$(RC) $(RESFLAGS) DEMO.RES $@

run: $(PROJ).EXE
	$(PROJ) $(RUNFLAGS)


$(PROJ).BSC: $(SBRS)
	bscmake @<<
/o$@ $(SBRS)
<<
