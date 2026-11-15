/**************************************************************************

   A sprite demo for WinG

 **************************************************************************/
/**************************************************************************

    (C) Copyright 1994 Microsoft Corp.  All rights reserved.

    You have a royalty-free right to use, modify, reproduce and 
    distribute the Sample Files (and/or any modified version) in 
    any way you find useful, provided that you agree that 
    Microsoft has no warranty obligations or liability for any 
    Sample Application Files which are modified. 

 **************************************************************************/

#include <windows.h>
// #include "demo.h"
#include "mmsystem.h" 

// #include "gamedefs.hpp"  

#define  _GAMES

#include "games.hpp"
#include "screen.hpp"
#include "3Dscreen.hpp"
#include "object.hpp"
#include "3Dobject.hpp"

#undef  _GAMES

#include "tommy.hpp"

#include <wing.h>  
#include <stdlib.h> 
#include <stdio.h>   
/*
#define  DELTASCROLL 20
#define  DELTA    1     
#define  BITMAPX 104
#define  BITMAPY 100 
#define  PASSO 18   //Tommy 

*/


/*----------------------------------------------------------------------------*\
|                                                                              |
|   g l o b a l   v a r i a b l e s                                            |
|                                                                              |
\*----------------------------------------------------------------------------*/

static  char  szAppName[]="WinG Sprite Demo";

static  HINSTANCE hInstApp;
static  HWND      hwndApp;
static  HPALETTE  hpalApp;
static  BOOL      fAppActive;

/*typedef struct header
{
  BITMAPINFOHEADER  Header;
  RGBQUAD           aColors[256];
} header;
*/
  
header          BufferH;  
header    &BufferHeader = BufferH;
//header    BufferHeader;
//long      Orientation = 1;     // assume bottom-up DIBs
void far *pBuffer = 0;
HDC       Buffer = 0;  

void far *pBackBuffer = 0;
HDC       BackBuffer = 0;

// char unsigned TransparentColor = 20;

/*
typedef struct pal
{
  WORD Version;
  WORD NumberOfEntries;
  PALETTEENTRY aEntries[256];
} pal;
*/
pal LP = 
{
  0x300,
  256
};

pal &LogicalPalette = LP;
//pal LogicalPalette ;

HBITMAP  gbmOldMonoBitmap = 0;
HBITMAP  gBackOldMonoBitmap = 0;
PDIB     pBitmap, pBack;
int      BackX, BackY;
int      DogX, DogY;
int      dx,dy;
POINT    Old; 
int      InicioBufferX=0, InicioBufferY=0;           
int              Scrollx=0, Scrolly=0;
int              SpriteOrder=1;


/*************************************************************************/

char *TommyNames[] = { "boyfrent.bmp", "zemane2.bmp", "zemane1.bmp", "boyfren1.bmp" };    
int             TommyFrames[] = { 1,8,8,4 };
int             TommyWidth[] = { 165,165,165,165 };
int             TommyHeight[] = { 247,247,247,247 };

/*
char *TommyNames[] = { "Tommy0.bmp", "Tommy1.bmp", "Tommy2.bmp" };    
int             TommyFrames[] = { 1,5,5 };
int             TommyWidth[] = { 104,104,104 };
int             TommyHeight[] = { 100,100,100 };
*/
/*
char *TommyNames[] = { "Mech2.bmp", "Mech2.bmp", "Mech2.bmp" };    
int             TommyFrames[] = { 1,2,2 };
int             TommyWidth[] = { 50,50,50 };
int             TommyHeight[] = { 50,50,50 };
*/			 
			     
tommy_screen  *Tela1;

tommy   *Tommy1,
		*Tommy2;

_3D_object 	*Comoda,
		*Cama;

#define TOMMY_DELTAX   25 // 12 // 37 // 60 // 20     
#define TOMMY_DELTAY    20     
#define TOMMY_TIMER             1
#define TOMMY_PERIOD    170  //60
#define WM_SYSTIMER             0x0118
	      
/*----------------------------------------------------------------------------*\
|                                                                              |
|   f u n c t i o n   d e f i n i t i o n s                                    |
|                                                                              |
\*----------------------------------------------------------------------------*/

LONG FAR PASCAL _export  AppWndProc(HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam);
LONG  AppCommand (HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam);

void  AppExit(void);
BOOL  AppIdle(void);

/*----------------------------------------------------------------------------*\
|   AppAbout( hDlg, uiMessage, wParam, lParam )                                |
|                                                                              |
|   Description:                                                               |
|       This function handles messages belonging to the "About" dialog box.    |
|       The only message that it looks for is WM_COMMAND, indicating the user  |
|       has pressed the "OK" button.  When this happens, it takes down         |
|       the dialog box.                                                        |
|                                                                              |
|   Arguments:                                                                 |
|       hDlg            window handle of about dialog window                   |
|       uiMessage       message number                                         |
|       wParam          message-dependent                                      |
|       lParam          message-dependent                                      |
|                                                                              |
|   Returns:                                                                   |
|       TRUE if message has been processed, else FALSE                         |
|                                                                              |
\*----------------------------------------------------------------------------*/
BOOL FAR PASCAL _export AppAbout(HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam)
{
    switch (msg)
    {
	case WM_COMMAND:
      if (LOWORD(wParam) == IDOK)
	    {
		EndDialog(hwnd,TRUE);
	    }
	    break;

	case WM_INITDIALOG:
	    return TRUE;
    }
    return FALSE;
}

/*----------------------------------------------------------------------------*\
|   AppInit( hInst, hPrev)                                                     |
|                                                                              |
|   Description:                                                               |
|       This is called when the application is first loaded into               |
|       memory.  It performs all initialization that doesn't need to be done   |
|       once per instance.                                                     |
|                                                                              |
|   Arguments:                                                                 |
|       hInstance       instance handle of current instance                    |
|       hPrev           instance handle of previous instance                   |
|                                                                              |
|   Returns:                                                                   |
|       TRUE if successful, FALSE if not                                       |
|                                                                              |
\*----------------------------------------------------------------------------*/
BOOL AppInit(HINSTANCE hInst,HINSTANCE hPrev,int sw,LPSTR szCmdLine)
{
    WNDCLASS cls;

    /* Save instance handle for DialogBoxes */
    hInstApp = hInst;

// Clear the System Palette so that WinG blting runs at full speed.
    ClearSystemPalette();

    if (!hPrev)
    {
	/*
	 *  Register a class for the main application window
	 */
	cls.hCursor        = LoadCursor(NULL,IDC_ARROW);
	cls.hIcon          = LoadIcon(hInst,"AppIcon");
	cls.lpszMenuName   = NULL; //"AppMenu";
	cls.lpszClassName  = szAppName;
	cls.hbrBackground  = (HBRUSH) NULL;
	cls.hInstance      = hInst;
	cls.style          = CS_BYTEALIGNCLIENT | CS_DBLCLKS | CS_VREDRAW | CS_HREDRAW ;
	cls.lpfnWndProc    = (WNDPROC)AppWndProc;
	cls.cbWndExtra     = 0;
	cls.cbClsExtra     = 0;

	if (!RegisterClass(&cls))
	    return FALSE;
    }

    dx = 640;
    dy = 480;


	Tela1 = new tommy_screen( "quarvazi.bmp" ) ;
//    Tela1 = new tommy_screen( "back2.bmp" ) ;
	Comoda = new _3D_object( 0, 236, "moveltv2.bmp", 1, 117, 158); // , 0, 0, 117, 158 );
	Cama = new _3D_object( 410, 260, "cama.bmp",    1, 231, 200); // , 0, 0, 231, 200 );
	 
	Tommy1 = new tommy( 250, 100, 4,        TommyNames, TommyFrames, 
										TommyWidth, TommyHeight,
										50, 0, 70, 247,
										TOMMY_TIMER, TOMMY_PERIOD,     
										TOMMY_DELTAX, TOMMY_DELTAY );

//      Tommy2 = new object( 400, 400, 1, TommyNames, TommyFrames, TommyWidth, TommyHeight ) ;


 
    hwndApp = CreateWindow (szAppName,              // Class name
			    szAppName,              // Caption
			    WS_POPUP |
//                            WS_MAXIMIZE |                     // Style bits
			    WS_CAPTION |
			    WS_BORDER ,                 // Style bits
//                          WS_OVERLAPPEDWINDOW |
//                            WS_HSCROLL |
//                            WS_VSCROLL                            // Style bits
			    0, 
			    0,                                  // Position
			    dx, 
			    dy,                                 // Size
			    (HWND)NULL,             // Parent window (no parent)
			    (HMENU)NULL,            // use class menu
			    hInst,                  // handle to window instance
			    (LPSTR)NULL             // no params to pass on
			   );

    ShowWindow(hwndApp,sw);


    return TRUE;
}


/*----------------------------------------------------------------------------*\
|   AppExit()                                                                  |
|                                                                              |
|   Description:                                                               |
|     App is just about to exit, cleanup.                                      |
|                                                                              |
\*----------------------------------------------------------------------------*/
void AppExit()
{

	delete Tela1;
	delete Tommy1;
//      delete Tommy2;

	delete Comoda;
	delete Cama;
}

/*----------------------------------------------------------------------------*\
|   WinMain( hInst, hPrev, lpszCmdLine, cmdShow )                              |
|                                                                              |
|   Description:                                                               |
|       The main procedure for the App.  After initializing, it just goes      |
|       into a message-processing loop until it gets a WM_QUIT message         |
|       (meaning the app was closed).                                          |
|                                                                              |
|   Arguments:                                                                 |
|       hInst           instance handle of this instance of the app            |
|       hPrev           instance handle of previous instance, NULL if first    |
|       szCmdLine       ->null-terminated command line                         |
|       cmdShow         specifies how the window is initially displayed        |
|                                                                              |
|   Returns:                                                                   |
|       The exit code as specified in the WM_QUIT message.                     |
|                                                                              |
\*----------------------------------------------------------------------------*/



void MessageLoop(HINSTANCE hInst, HINSTANCE hPrev, LPSTR szCmdLine, int sw)
{
    MSG     msg;         

    /*
     * Polling messages from event queue
     */
    for (;;)
    {
	if (PeekMessage(&msg, NULL, 0, 0,PM_REMOVE))
	{
	    if (msg.message == WM_QUIT)
		break;

	    TranslateMessage(&msg);
	    DispatchMessage(&msg);
	}
	else
	{
	    if (AppIdle())
		WaitMessage();
	}
    }

}


int PASCAL WinMain(HINSTANCE hInst, HINSTANCE hPrev, LPSTR szCmdLine, int sw)
{
    MSG     msg;         
    char mensagem[40]="O aplicativo já está aberto !!!";
    
    
	SetSystemTimer  =   (WORD (FAR PASCAL *)( HWND, int, WORD, FARPROC ))
						GetProcAddress(GetModuleHandle("USER"), (LPSTR)  11L);
	KillSystemTimer =   (WORD (FAR PASCAL *)( HWND, int ))
						GetProcAddress(GetModuleHandle("USER"), (LPSTR) 182L);
	
    if (hPrev != NULL) 
    {
	MessageBox (NULL,mensagem,mensagem,MB_APPLMODAL|MB_OK);
	return FALSE;
    }


    /* Call initialization procedure */
    if (!AppInit(hInst,hPrev,sw,szCmdLine))
    {
		return FALSE;
	}
    

    /*
     * Polling messages from event queue
     */
	MessageLoop(hInst, hPrev, szCmdLine, sw);


    AppExit();
    return msg.wParam;
}



/*----------------------------------------------------------------------------*\
|   AppIdle()                                                                  |
|                                                                              |
|   Description:                                                               |
|     Place to do idle time stuff.                                             |
|                                                                              |
\*----------------------------------------------------------------------------*/
BOOL AppIdle()
{
    if (fAppActive)
    {
  //
  // we are the foreground app.
  //
  return TRUE;      // nothing to do.
    }
    else
    {
  //
  // we are a background app.
  //
  return TRUE;      // nothing to do.
    }
}

/*----------------------------------------------------------------------------*\
|   AppPaint(hwnd, hdc)                                                        |
|                                                                              |
|   Description:                                                               |
|       The paint function.                                                    |
|                                                                              |
|   Arguments:                                                                 |
|       hwnd             window painting into                                  |
|       hdc              display context to paint to                           |
|                                                                              |
\*----------------------------------------------------------------------------*/
AppPaint (HWND hwnd, HDC hdc)
{

	Tela1->Show(hdc);
	Cama->DrawSolid( hwnd, Tela1 );
	Comoda->DrawSolid( hwnd, Tela1 );


  
  return TRUE;
}         
  
/*----------------------------------------------------------------------------*\
|   AppWndProc( hwnd, uiMessage, wParam, lParam )                              |
|                                                                              |
|   Description:                                                               |
|       The window proc for the app's main (tiled) window.  This processes all |
|       of the parent window's messages.                                       |
|                                                                              |
\*----------------------------------------------------------------------------*/
LONG FAR PASCAL _export AppWndProc(HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam)
{
    PAINTSTRUCT ps;
    HDC hdc;
    BOOL f;  
//    int DeltaX=DELTA, DeltaY=DELTA;
    static      boolean InKeyLeft = false,
				InKeyRight = false,
				InKeyUp = false,
				InKeyDown = false,
				InKeySub = false,
				InKeyAdd = false,
				InitAnim = true;
				
    
    switch (msg)
    {       
	
      case WM_CREATE:

		Tela1->Init(hwnd)->SetVanishingPoint(514,102)->SetViewPoint(160,300,0,455,0)->SetyAxisShift(0,345);

		Cama->Init( Tela1 )->Set3DOrigin(2,196)->Set3DDimensions(230,80,330)->Set3DPosition( Tela1 );
		Comoda->Init( Tela1 )->Set3DOrigin(4,155)->Set3DDimensions(50,160,100)->Set3DPosition( Tela1 );;

		Tommy1->Init( Tela1 )->Set3DOrigin(30,238)->Set3DDimensions(105,238,50)->Set3DPosition( Tela1 );;

		Tommy1->InitAnimP( hwnd, Tela1 );				
//              Tommy2->Init( Tela1 );
		
      break;        
      
      // Faz um scroll horizontal      
      
      case WM_RBUTTONDOWN:  
      
	//break;  
      
      case WM_DESTROY:
	    PostQuitMessage(0);
	    break;

      case WM_ACTIVATEAPP:
      fAppActive = (BOOL)wParam;
      break;

      case WM_SIZE:

	break;  
	    
	case WM_KEYDOWN: 

		switch(wParam)
		{
			case VK_LEFT:
				if( !InKeyLeft )                    
				{                                       
					InKeyLeft = true;
					Tommy1->InitHMove( hwnd, Tela1, MV_LEFT );
				}         
			break;
			case VK_RIGHT:
				if( !InKeyRight )                    
				{                                       
					InKeyRight = true;
					Tommy1->InitHMove( hwnd, Tela1, MV_RIGHT );
				}         
			break;
			case VK_UP:
				if( !InKeyUp )                    
				{                                       
					InKeyUp = true;
					Tommy1->InitVMove( hwnd, Tela1, MV_UP );
				}         
			break;
			case VK_DOWN:
				if( !InKeyDown )                    
				{                                       
					InKeyDown = true;
					Tommy1->InitVMove( hwnd, Tela1, MV_DOWN );
				}         
			break;
			case VK_ADD:
				if( !InKeyAdd )                    
				{                                       
					InKeyAdd = true;   
					Tommy1->InitAnim( hwnd, Tela1, MV_RIGHT );
				}         
			break;
			case VK_SUBTRACT:
				if( !InKeySub )                    
				{                                       
					InKeySub = true;   
					Tommy1->InitAnim( hwnd, Tela1, MV_LEFT );
				}         
			break;
	    };
	    
	break;               
	case WM_KEYUP: 
		       
		switch(wParam)
		{
			case VK_LEFT:
					InKeyLeft = false;
					Tommy1->EndMove( hwnd, Tela1 );
					break;
			case VK_RIGHT:
					InKeyRight = false;
					Tommy1->EndMove( hwnd, Tela1 );
					break;
			case VK_UP:
					InKeyUp = false;
					Tommy1->EndMove( hwnd, Tela1 );
					break;
			case VK_DOWN:
					InKeyDown = false;
					Tommy1->EndMove( hwnd, Tela1 );
					break;
			case VK_ADD:
					InKeyAdd = false;
					Tommy1->EndAnim( hwnd, Tela1 );
					break;
			case VK_SUBTRACT:
					InKeySub = false;
					Tommy1->EndAnim( hwnd, Tela1 );
					break;
	    };
	    
       break;               
	case WM_LBUTTONDOWN: 
		
	    Tommy1->InitMove( hwnd, LOWORD(lParam), HIWORD(lParam), Tela1 );
//            Tommy1->Move( hdc, LOWORD(lParam), HIWORD(lParam), Tela1 );

       break;               
       
	case WM_TIMER:
		break;
	
	case WM_SYSTIMER:
		

			if( wParam == (WPARAM) Tommy1->Timer() )
			{   
				if( !Tommy1->IsMoving() ) 
				{
					Tommy1->Anim1Frame(hwnd, Tela1);
				}
				else
					Tommy1->Move1Step(hwnd, Tela1);

/*				hdc = GetDC(hwnd);
				Tela1->Show(hdc);
				ReleaseDC(hwnd,hdc);
*/
				Cama->DrawSolid( hwnd, Tela1 );
				Comoda->DrawSolid( hwnd, Tela1 );

			}




		  break;

	case WM_COMMAND:
	    return AppCommand(hwnd,msg,wParam,lParam);
	
	case WM_CLOSE:
      break;

	case WM_PALETTECHANGED:
      if ((HWND)wParam == hwnd)
    break;

      // fall through to WM_QUERYNEWPALETTE

  case WM_QUERYNEWPALETTE:
      hdc = GetDC(hwnd);

      if (Tela1->hpalApp)
		SelectPalette(hdc, Tela1->hpalApp, FALSE);

      f = RealizePalette(hdc);
      ReleaseDC(hwnd,hdc);

      if (f)
	InvalidateRect(hwnd,NULL,TRUE);

      return f;

	case WM_PAINT:
	     hdc = BeginPaint(hwnd,&ps);
	 SelectPalette(hdc, Tela1->hpalApp, FALSE);
	 RealizePalette(hdc);
	     AppPaint (hwnd,hdc);
	 EndPaint(hwnd,&ps);
	 return 0L;
    }    
    
    return DefWindowProc(hwnd,msg,wParam,lParam);
}

/*----------------------------------------------------------------------------*\
|   AppCommand(hwnd, msg, wParam, lParam )                                     |
|                                                                              |
|   Description:                                                               |
|     Handles WM_COMMAND messages for the main window (hwndApp)                |
|   of the parent window's messages.                                           |
|                                                                              |
\*----------------------------------------------------------------------------*/
LONG AppCommand (HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam)
{
/*    switch(wParam)
    {
	case MENU_ABOUT:
	    DialogBox(hInstApp,"AppAbout",hwnd,(DLGPROC)AppAbout);
	    break;

	case MENU_EXIT:
	    PostMessage(hwnd,WM_CLOSE,0,0L);
	    break;
    }
*/
    return 0L;
}
