#include <windows.h>
#include <windowsx.h>
#include <mmsystem.h>
#include <wing.h>  
#include <stdlib.h> 
#include <stdio.h>   
#include <string.h>

#include "utils.h" 
#include "tblt.h"

#ifdef _GAMES
	#define	DECLARE
#else
	#define DECLARE extern
#endif        


        
typedef enum { false, true } boolean;
// typedef enum { FALSE, TRUE } BOOL;

typedef unsigned int uint;


typedef struct header
{
  BITMAPINFOHEADER  Header;
  RGBQUAD           aColors[256];
} header;



typedef struct pal
{
  WORD Version;
  WORD NumberOfEntries;
  PALETTEENTRY aEntries[256];
} pal;


#ifdef _GAMES
	char unsigned TransparentColor	= 11; //6
#else
	extern char unsigned TransparentColor;
#endif


// DECLARE long Orientation;

#define MAX_SCENES 200

#define MAX_NAME_LEN	20

#define LAST_SPRITE_TIMER 10
#define FIRST_SPRITE_TIMER 5

#define 	WM_SYSTIMER             0x0118

#define		WM_INITSCENE			WM_USER+1
#define		WM_EXITSCENE			WM_USER+2
#define		WM_ENDANIM				WM_USER+3
#define		WM_ENDMOVE				WM_USER+4
#define		WM_PLAYERMOVE			WM_USER+5

#define     REFRESH_TIMER	1
#define     REFRESH_PERIOD	50 

#define		HAS_PLAYER				true
#define		NO_PLAYER				false

#define		HAS_CTRL_PANEL			true
#define		NO_CTRL_PANEL			false

#define		HAS_STAT_BAR			true
#define		NO_STAT_BAR				false

#define		IS_VISIBLE				true
#define		NOT_VISIBLE				false

#define		PORTAB_DELTA_X          0
#define		PORTAB_DELTA_Y          10
	


#ifdef __cplusplus
extern "C" {
#endif 

BOOL TransparentDIBBits( BITMAPINFO far *pBufferHeader,
          void huge *pBufferBits,
          int nXOriginDest, int nYOriginDest, void const far *pBits,
          BITMAPINFO const far *pBitmapInfo, int nXOriginSrc, int nYOriginSrc,
          int iUsage, char unsigned TransparentColor ); 
          
          
          
BOOL CopyDIBBits( BITMAPINFO far *pBufferHeader,
          void huge *pBufferBits,
          int nXOriginDest, int nYOriginDest, void const far *pBits,
          BITMAPINFO const far *pBitmapInfo, int nXOriginSrc, int nYOriginSrc,
          int iUsage );          

DECLARE WORD (FAR PASCAL *SetSystemTimer)( 	HWND hwnd, int nIDEvent, WORD wElapse,
									FARPROC lpTimerFunction );
									
DECLARE WORD (FAR PASCAL *KillSystemTimer)(	HWND hwnd, int nIDEvent );
									
									
#ifdef __cplusplus
		}
#endif 
                                                                        

// void MessageBox( char *Mask, char *Arg, char *Title ); // , uint Option = 0 );
void MessageBox( char *Title, char *Mask, char *Arg = NULL ); // , uint Option )

class object_list;                 
class object;     
class _3D_object;     
class moveable;
class animated;
class actor;
class player;
class scene;
class portable;
class exits;
class status_bar;
class control_panel;
class _3D_player;
class _3D_game_player;
class bg_layer;       
class _3D_screen;
class occup_screen;
class parallax_screen;

void InitGame(void);              

extern boolean (*VetMessageHandling[MAX_SCENES])( HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam );


#define GAME_CLASS	gen_applic


#undef	DECLARE	    