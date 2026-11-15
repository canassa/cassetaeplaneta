

BOOL ReadPlayer(HFILE HandleArch,int *Number,int *X,int *Y,int *NumSprites,char* NomeBMP,
					int *_3DOriginX,int *_3DOriginY,int *_3Dw,int *_3Dh,int *_3Dd,int *NumTimer,
					int *PerTimer,int *DeltaX,int *DeltaY);
BOOL ReadSprite(HFILE HandleArch,int *NumFrames,int *FrameW,int *FrameH,int *BoundX,
					int *BoundY,int *BoundW,int *BoundH);
BOOL ReadControlPanel(HFILE,int *X,int *Y,char* NomeBMP,int *NumFrames,int *FrameW,
					int *FrameH,int *NumTimer,int *PerTimer);
BOOL ReadStatusBar(HFILE,int *X,int *Y,int *Cor,char* NomeBMP,int *FrameW,int *FrameH);
BOOL ReadFirstScene(HFILE,char* Name,BOOL *Has_Player,BOOL *Has_ControlPanel,BOOL *Has_StatusBar,BOOL *Is_1Animation,BOOL *Is_ClickExit );
BOOL ReadPortable(HFILE,int *Number,char* InitialScene,int *X,int *Y,char* NomeBMP,int *FrameW,
					int *FrameH,int *BoundX,int *BoundY,int *BoundW,int *BoundH,int *_3DOriginX,
					int *_3DOriginY,int *_3Dw,int *_3Dh,int *_3Dd,int *_3Dz0,int *NumTimer,int *PerTimer);

BOOL ReadLimits(HFILE,int *LinhaSup,int *ColunaSup,int *LinhaLatEsq,int *ColunaLatEsq,
					  int *DeltaLatEsq,int *LinhaLatDir,int *ColunaLatDir,int *DeltaLatDir);
BOOL ReadScreen(HFILE,int *Number,char* ScreenBMP,int *ScreenX,int *ScreenY,int *ScreenW,int *ScreenH, 
					int *VanishX, int *VanishY,int *ViewX,int *ViewY,int *View_x,int *View_y,int *View_z,
					int *AxisX,int *AxisY );
BOOL ReadObject(HFILE,int *Number,int *X,int *Y,char* NomeBMP,int *FrameW,int *FrameH,int *BoundX,int *BoundY,
					int *BoundW,int *BoundH,int *_3DOriginX,int *_3DOriginY,int *_3Dx,int *_3Dy,int *_3Dz);
BOOL ReadAnimated(HFILE,int *Number,int *X,int *Y,char* NomeBMP,int *NumFrames,int *FrameW,int *FrameH,int *BoundX,
			 		int *BoundY,int *BoundW,int *BoundH,int *_3DOriginX,int *_3DOriginY,int *_3Dx,int *_3Dy,int *_3Dz,
			 		int *NumTimer,int *PerTimer);
BOOL ReadExit(HFILE,int *Number,int *X,int *Y,char* NomeBMP,int *NumFrames,int *FrameW,int *FrameH,int *BoundX,
			  		int *BoundY,int *BoundW,int *BoundH,int *_3DOriginX,int *_3DOriginY,int *_3Dx,int *_3Dy,int *_3Dz,
			  		int *NumTimer,int *PerTimer,char* SceneInName,int *PlayerX,int *PlayerY,BOOL *HasPlayer,
			  		BOOL *HasControlPanel,BOOL *HasStatusBar,BOOL *Is_1Animation,BOOL *Is_ClickExit);
BOOL ReadStatic(HFILE HandleArch,int *Number,int *X,int *Y,char* NomeBMP,int *NumFrames,int *FrameW,int *FrameH,int *BoundX,
			 		int *BoundY,int *BoundW,int *BoundH,int *_3DOriginX,int *_3DOriginY,int *_3Dx,int *_3Dy,int *_3Dz,
			 		int *NumTimer,int *PerTimer);

char* MontaNome(char*,int);
BOOL  BuildSectionIndex( HFILE );
long  FindSectionOffset(char*);
char  SkipSeparators( HFILE HandleArch, BOOL ErrorAtEnd = TRUE);
char  Comment ( HFILE );
char  SkipLine( HFILE HandleArch, char *Buffer = NULL );
char  SkipChar( HFILE HandleArch );
BOOL  ReadStr ( HFILE, char *, char);
BOOL  SearchLine(HFILE, char*);
HFILE AbreArquivo(char*);
void  FechaArquivo(HFILE);
BOOL  Error( char *Msg, char *Arg = "" );
BOOL  SeekScene(HFILE, char*);
BOOL  BeginSameName(void);
BOOL  EndScene(void);
void  SetOutBlock(void);
void  SetOutScene(void);
long  SavePos(HFILE);
void  RestPos(HFILE,long);
char  LookChar(HFILE HandleArch );
