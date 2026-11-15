# Microsoft Visual C++ generated build script - Do not modify

PROJ = DEMO
DEBUG = 1
PROGTYPE = 0
CALLER = 
ARGS = 
DLLS = 
D_RCDEFINES = /d_DEBUG 
R_RCDEFINES = /dNDEBUG 
ORIGIN = MSVC
ORIGIN_VER = 1.00
PROJPATH = D:\LC\DEMO\
USEMFC = 0
CC = cl
CPP = cl
CXX = cl
CCREATEPCHFLAG = 
CPPCREATEPCHFLAG = 
CUSEPCHFLAG = 
CPPUSEPCHFLAG = 
FIRSTC =             
FIRSTCPP = DEMO.CPP    
RC = rc
CFLAGS_D_WEXE = /nologo /f- /G2 /FPi87 /W3 /Zi /AS /Od /D "_DEBUG" /D "DEBUG" /D "STRICT" /D "PROFILE" /Fa /FR /GA -c /Fd"DOG.PDB"
CFLAGS_R_WEXE = /nologo /f- /G3 /FPi87 /W3 /AS /O1 /D "NDEBUG" /D "STRICT" /FR cl -c  -Oxwt
LFLAGS_D_WEXE = /NOLOGO /PACKC:61440 /STACK:4096 /ALIGN:16 /ONERROR:NOEXE /CO /MAP /LINE /NOE/NOD/MAP/AL:16/NOPACKCODE
LFLAGS_R_WEXE = /NOLOGO /NOD /PACKC:61440 /STACK:10240 /ALIGN:16 /ONERROR:NOEXE /CO /NOE/NOD/MAP/AL:16/NOPACKCODE
LIBS_D_WEXE = libw slibcew wing oldnames commdlg.lib mmsystem.lib 
LIBS_R_WEXE = libw slibcew wing oldnames commdlg.lib mmsystem.lib 
RCFLAGS = /nologo 
RESFLAGS = /nologo 
RUNFLAGS = 
DEFFILE = DEMO.DEF
OBJS_EXT = FAST32.OBJ 
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
SBRS = DEMO.SBR \
		TBLT.SBR \
		UTILS.SBR \
		GAMEDEFS.SBR


FAST32_DEP = 

DEMO_RCDEP = d:\lc\demo\demo.h \
	d:\lc\demo\lighton.ico


DEMO_DEP = d:\lc\demo\demo.h \
	d:\lc\demo\utils.h \
	c:\wing\include\wing.h


TBLT_DEP = c:\wing\include\wing.h \
	d:\lc\demo\utils.h


UTILS_DEP = d:\lc\demo\utils.h


GAMEDEFS_DEP = d:\lc\demo\gamedefs.hpp \
	c:\wing\include\wing.h \
	d:\lc\demo\utils.h


all:	$(PROJ).EXE $(PROJ).BSC

DEMO.RES:	DEMO.RC $(DEMO_RCDEP)
	$(RC) $(RCFLAGS) $(RCDEFINES) -r DEMO.RC

DEMO.OBJ:	DEMO.CPP $(DEMO_DEP)
	$(CPP) $(CFLAGS) $(CPPCREATEPCHFLAG) /c DEMO.CPP

TBLT.OBJ:	TBLT.CPP $(TBLT_DEP)
	$(CPP) $(CFLAGS) $(CPPUSEPCHFLAG) /c TBLT.CPP

UTILS.OBJ:	UTILS.CPP $(UTILS_DEP)
	$(CPP) $(CFLAGS) $(CPPUSEPCHFLAG) /c UTILS.CPP

GAMEDEFS.OBJ:	GAMEDEFS.CPP $(GAMEDEFS_DEP)
	$(CPP) $(CFLAGS) $(CPPUSEPCHFLAG) /c GAMEDEFS.CPP


$(PROJ).EXE::	DEMO.RES

$(PROJ).EXE::	DEMO.OBJ TBLT.OBJ UTILS.OBJ GAMEDEFS.OBJ $(OBJS_EXT) $(DEFFILE)
	echo >NUL @<<$(PROJ).CRF
DEMO.OBJ +
TBLT.OBJ +
UTILS.OBJ +
GAMEDEFS.OBJ +
$(OBJS_EXT)
$(PROJ).EXE
$(MAPFILE)
d:\msvc\lib\+
d:\msvc\mfc\lib\+
c:\wing\lib\+
c:\vfwdk\lib\+
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
