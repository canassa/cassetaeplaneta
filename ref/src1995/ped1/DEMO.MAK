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
FIRSTCPP = TBLT.CPP    
RC = rc
CFLAGS_D_WEXE = /nologo /f- /G3 /FPi87 /Zp4 /W4 /vmg /Zi /AL /Gx- /YX /Od /D "_DEBUG" /D "DEBUG" /D "STRICT" /D "PROFILE" /FR /Zn /GA -c /Fd"DOG.PDB" /Fp"DEMO.PCH"
CFLAGS_R_WEXE = /nologo /f- /G3 /FPi87 /Zp4 /W3 /vmg /AS /YX /Od /D "NDEBUG" /D "STRICT" /FR /Zn cl -c  -Oxwt /Fp"DEMO.PCH"
LFLAGS_D_WEXE = /NOLOGO /NOE /STACK:15000 /NOPACKF /ALIGN:16 /ONERROR:NOEXE /CO /MAP /LINE /NOE/NOD/MAP/AL:16/NOPACKCODE
LFLAGS_R_WEXE = /NOLOGO /NOE /FARCALL /STACK:65000 /NOPACKF /ALIGN:16 /ONERROR:NOEXE /CO /NOE/NOD/MAP/AL:16 /NOPACKCODE
LIBS_D_WEXE = libw llibcew wing wintoon oldnames commdlg.lib mmsystem.lib 
LIBS_R_WEXE = libw slibcew wing wintoon oldnames commdlg.lib mmsystem.lib 
RCFLAGS = /nologo 
RESFLAGS = /nologo /k
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
SBRS = TBLT.SBR \
		UTILS.SBR \
		3DOBJECT.SBR \
		3DSCREEN.SBR \
		OBJECT.SBR \
		SCREEN.SBR \
		APPLICAT.SBR \
		EVENT.SBR \
		CTRPANEL.SBR \
		SCENE.SBR \
		VTREE.SBR \
		GENGAME.SBR \
		GENAPLIC.SBR \
		GENSCENE.SBR \
		READDATA.SBR


FAST32_DEP = 

TBLT_DEP = c:\wing\include\wing.h \
	d:\atr\casseta\aplicat\utils.h \
	d:\atr\casseta\aplicat\tblt.h


UTILS_DEP = d:\atr\casseta\aplicat\utils.h \
	d:\atr\casseta\aplicat\tblt.h


3DOBJECT_DEP = d:\atr\casseta\aplicat\games.hpp \
	c:\wing\include\wing.h \
	d:\atr\casseta\aplicat\utils.h \
	d:\atr\casseta\aplicat\tblt.h \
	d:\atr\casseta\aplicat\event.hpp \
	d:\atr\casseta\aplicat\screen.hpp \
	d:\atr\casseta\aplicat\3dscreen.hpp \
	d:\atr\casseta\aplicat\object.hpp \
	d:\atr\casseta\aplicat\3dobject.hpp \
	d:\atr\casseta\aplicat\vtree.h \
	d:\atr\casseta\aplicat\scene.hpp \
	d:\atr\casseta\aplicat\ctrpanel.hpp \
	d:\atr\casseta\aplicat\applicat.hpp


3DSCREEN_DEP = d:\atr\casseta\aplicat\games.hpp \
	c:\wing\include\wing.h \
	d:\atr\casseta\aplicat\utils.h \
	d:\atr\casseta\aplicat\tblt.h \
	d:\atr\casseta\aplicat\event.hpp \
	d:\atr\casseta\aplicat\screen.hpp \
	d:\atr\casseta\aplicat\3dscreen.hpp \
	d:\atr\casseta\aplicat\object.hpp \
	d:\atr\casseta\aplicat\3dobject.hpp \
	d:\atr\casseta\aplicat\bglayer.hpp


OBJECT_DEP = d:\atr\casseta\aplicat\games.hpp \
	c:\wing\include\wing.h \
	d:\atr\casseta\aplicat\utils.h \
	d:\atr\casseta\aplicat\tblt.h \
	d:\atr\casseta\aplicat\event.hpp \
	d:\atr\casseta\aplicat\screen.hpp \
	d:\atr\casseta\aplicat\3dscreen.hpp \
	d:\atr\casseta\aplicat\object.hpp \
	d:\atr\casseta\aplicat\3dobject.hpp \
	d:\atr\casseta\aplicat\vtree.h \
	d:\atr\casseta\aplicat\scene.hpp \
	d:\atr\casseta\aplicat\ctrpanel.hpp \
	d:\atr\casseta\aplicat\applicat.hpp


SCREEN_DEP = d:\atr\casseta\aplicat\games.hpp \
	c:\wing\include\wing.h \
	d:\atr\casseta\aplicat\utils.h \
	d:\atr\casseta\aplicat\tblt.h \
	d:\atr\casseta\aplicat\screen.hpp \
	d:\atr\casseta\aplicat\object.hpp


APPLICAT_DEP = d:\atr\casseta\aplicat\games.hpp \
	c:\wing\include\wing.h \
	d:\atr\casseta\aplicat\utils.h \
	d:\atr\casseta\aplicat\tblt.h \
	d:\atr\casseta\aplicat\event.hpp \
	d:\atr\casseta\aplicat\screen.hpp \
	d:\atr\casseta\aplicat\3dscreen.hpp \
	d:\atr\casseta\aplicat\object.hpp \
	d:\atr\casseta\aplicat\3dobject.hpp \
	d:\atr\casseta\aplicat\vtree.h \
	d:\atr\casseta\aplicat\scene.hpp \
	d:\atr\casseta\aplicat\ctrpanel.hpp \
	d:\atr\casseta\aplicat\applicat.hpp


EVENT_DEP = d:\atr\casseta\aplicat\games.hpp \
	c:\wing\include\wing.h \
	d:\atr\casseta\aplicat\utils.h \
	d:\atr\casseta\aplicat\tblt.h \
	d:\atr\casseta\aplicat\event.hpp


CTRPANEL_DEP = d:\atr\casseta\aplicat\games.hpp \
	c:\wing\include\wing.h \
	d:\atr\casseta\aplicat\utils.h \
	d:\atr\casseta\aplicat\tblt.h \
	d:\atr\casseta\aplicat\event.hpp \
	d:\atr\casseta\aplicat\screen.hpp \
	d:\atr\casseta\aplicat\3dscreen.hpp \
	d:\atr\casseta\aplicat\object.hpp \
	d:\atr\casseta\aplicat\3dobject.hpp \
	d:\atr\casseta\aplicat\vtree.h \
	d:\atr\casseta\aplicat\ctrpanel.hpp \
	d:\atr\casseta\aplicat\scene.hpp \
	d:\atr\casseta\aplicat\applicat.hpp


SCENE_DEP = d:\atr\casseta\aplicat\games.hpp \
	c:\wing\include\wing.h \
	d:\atr\casseta\aplicat\utils.h \
	d:\atr\casseta\aplicat\tblt.h \
	d:\atr\casseta\aplicat\event.hpp \
	d:\atr\casseta\aplicat\screen.hpp \
	d:\atr\casseta\aplicat\3dscreen.hpp \
	d:\atr\casseta\aplicat\object.hpp \
	d:\atr\casseta\aplicat\3dobject.hpp \
	d:\atr\casseta\aplicat\vtree.h \
	d:\atr\casseta\aplicat\ctrpanel.hpp \
	d:\atr\casseta\aplicat\scene.hpp \
	d:\atr\casseta\aplicat\applicat.hpp


VTREE_DEP = d:\atr\casseta\aplicat\games.hpp \
	c:\wing\include\wing.h \
	d:\atr\casseta\aplicat\utils.h \
	d:\atr\casseta\aplicat\tblt.h \
	d:\atr\casseta\aplicat\event.hpp \
	d:\atr\casseta\aplicat\screen.hpp \
	d:\atr\casseta\aplicat\object.hpp \
	d:\atr\casseta\aplicat\3dscreen.hpp \
	d:\atr\casseta\aplicat\3dobject.hpp \
	d:\atr\casseta\aplicat\scene.hpp \
	d:\atr\casseta\aplicat\ctrpanel.hpp \
	d:\atr\casseta\aplicat\applicat.hpp \
	d:\atr\casseta\aplicat\vtree.h


DEMO_RCDEP = d:\atr\casseta\aplicat\hand.cur \
	d:\atr\casseta\aplicat\right.cur \
	d:\atr\casseta\aplicat\left.cur \
	d:\atr\casseta\aplicat\lighton.ico


GENGAME_DEP = d:\atr\casseta\aplicat\games.hpp \
	c:\wing\include\wing.h \
	d:\atr\casseta\aplicat\utils.h \
	d:\atr\casseta\aplicat\tblt.h \
	d:\atr\casseta\aplicat\event.hpp \
	d:\atr\casseta\aplicat\screen.hpp \
	d:\atr\casseta\aplicat\3dscreen.hpp \
	d:\atr\casseta\aplicat\object.hpp \
	d:\atr\casseta\aplicat\3dobject.hpp \
	d:\atr\casseta\aplicat\vtree.h \
	d:\atr\casseta\aplicat\ctrpanel.hpp \
	d:\atr\casseta\aplicat\scene.hpp \
	d:\atr\casseta\aplicat\applicat.hpp


GENAPLIC_DEP = d:\atr\casseta\aplicat\games.hpp \
	c:\wing\include\wing.h \
	d:\atr\casseta\aplicat\utils.h \
	d:\atr\casseta\aplicat\tblt.h \
	d:\atr\casseta\aplicat\event.hpp \
	d:\atr\casseta\aplicat\screen.hpp \
	d:\atr\casseta\aplicat\3dscreen.hpp \
	d:\atr\casseta\aplicat\object.hpp \
	d:\atr\casseta\aplicat\3dobject.hpp \
	d:\atr\casseta\aplicat\ctrpanel.hpp \
	d:\atr\casseta\aplicat\scene.hpp \
	d:\atr\casseta\aplicat\vtree.h \
	d:\atr\casseta\aplicat\applicat.hpp \
	d:\atr\casseta\aplicat\readdata.hpp \
	d:\atr\casseta\aplicat\scenenum.h


GENSCENE_DEP = d:\atr\casseta\aplicat\games.hpp \
	c:\wing\include\wing.h \
	d:\atr\casseta\aplicat\utils.h \
	d:\atr\casseta\aplicat\tblt.h \
	d:\atr\casseta\aplicat\event.hpp \
	d:\atr\casseta\aplicat\screen.hpp \
	d:\atr\casseta\aplicat\3dscreen.hpp \
	d:\atr\casseta\aplicat\object.hpp \
	d:\atr\casseta\aplicat\3dobject.hpp \
	d:\atr\casseta\aplicat\ctrpanel.hpp \
	d:\atr\casseta\aplicat\scene.hpp \
	d:\atr\casseta\aplicat\vtree.h \
	d:\atr\casseta\aplicat\applicat.hpp \
	d:\atr\casseta\aplicat\readdata.hpp \
	d:\atr\casseta\aplicat\scenenum.h


READDATA_DEP = d:\atr\casseta\aplicat\readdata.hpp


all:	$(PROJ).EXE $(PROJ).BSC

TBLT.OBJ:	TBLT.CPP $(TBLT_DEP)
	$(CPP) $(CFLAGS) $(CPPCREATEPCHFLAG) /c TBLT.CPP

UTILS.OBJ:	UTILS.CPP $(UTILS_DEP)
	$(CPP) $(CFLAGS) $(CPPUSEPCHFLAG) /c UTILS.CPP

3DOBJECT.OBJ:	3DOBJECT.CPP $(3DOBJECT_DEP)
	$(CPP) $(CFLAGS) $(CPPUSEPCHFLAG) /c 3DOBJECT.CPP

3DSCREEN.OBJ:	3DSCREEN.CPP $(3DSCREEN_DEP)
	$(CPP) $(CFLAGS) $(CPPUSEPCHFLAG) /c 3DSCREEN.CPP

OBJECT.OBJ:	OBJECT.CPP $(OBJECT_DEP)
	$(CPP) $(CFLAGS) $(CPPUSEPCHFLAG) /c OBJECT.CPP

SCREEN.OBJ:	SCREEN.CPP $(SCREEN_DEP)
	$(CPP) $(CFLAGS) $(CPPUSEPCHFLAG) /c SCREEN.CPP

APPLICAT.OBJ:	APPLICAT.CPP $(APPLICAT_DEP)
	$(CPP) $(CFLAGS) $(CPPUSEPCHFLAG) /c APPLICAT.CPP

EVENT.OBJ:	EVENT.CPP $(EVENT_DEP)
	$(CPP) $(CFLAGS) $(CPPUSEPCHFLAG) /c EVENT.CPP

CTRPANEL.OBJ:	CTRPANEL.CPP $(CTRPANEL_DEP)
	$(CPP) $(CFLAGS) $(CPPUSEPCHFLAG) /c CTRPANEL.CPP

SCENE.OBJ:	SCENE.CPP $(SCENE_DEP)
	$(CPP) $(CFLAGS) $(CPPUSEPCHFLAG) /c SCENE.CPP

VTREE.OBJ:	VTREE.CPP $(VTREE_DEP)
	$(CPP) $(CFLAGS) $(CPPUSEPCHFLAG) /c VTREE.CPP

DEMO.RES:	DEMO.RC $(DEMO_RCDEP)
	$(RC) $(RCFLAGS) $(RCDEFINES) -r DEMO.RC

GENGAME.OBJ:	GENGAME.CPP $(GENGAME_DEP)
	$(CPP) $(CFLAGS) $(CPPUSEPCHFLAG) /c GENGAME.CPP

GENAPLIC.OBJ:	GENAPLIC.CPP $(GENAPLIC_DEP)
	$(CPP) $(CFLAGS) $(CPPUSEPCHFLAG) /c GENAPLIC.CPP

GENSCENE.OBJ:	GENSCENE.CPP $(GENSCENE_DEP)
	$(CPP) $(CFLAGS) $(CPPUSEPCHFLAG) /c GENSCENE.CPP

READDATA.OBJ:	READDATA.CPP $(READDATA_DEP)
	$(CPP) $(CFLAGS) $(CPPUSEPCHFLAG) /c READDATA.CPP


$(PROJ).EXE::	DEMO.RES

$(PROJ).EXE::	TBLT.OBJ UTILS.OBJ 3DOBJECT.OBJ 3DSCREEN.OBJ OBJECT.OBJ SCREEN.OBJ \
	APPLICAT.OBJ EVENT.OBJ CTRPANEL.OBJ SCENE.OBJ VTREE.OBJ GENGAME.OBJ GENAPLIC.OBJ \
	GENSCENE.OBJ READDATA.OBJ $(OBJS_EXT) $(DEFFILE)
	echo >NUL @<<$(PROJ).CRF
TBLT.OBJ +
UTILS.OBJ +
3DOBJECT.OBJ +
3DSCREEN.OBJ +
OBJECT.OBJ +
SCREEN.OBJ +
APPLICAT.OBJ +
EVENT.OBJ +
CTRPANEL.OBJ +
SCENE.OBJ +
VTREE.OBJ +
GENGAME.OBJ +
GENAPLIC.OBJ +
GENSCENE.OBJ +
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
