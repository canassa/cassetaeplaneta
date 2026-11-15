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
#include "mmsystem.h" 



#define _GAMES

#include "games.hpp"
#include "event.hpp"

#include "screen.hpp"
#include "3dscreen.hpp"
#include "object.hpp"
#include "3dobject.hpp"

#include "vtree.h"

#include "ctrpanel.hpp"
#include "scene.hpp"
#include "applicat.hpp"

#undef _GAMES

//#include "casseta.hpp"

#include <wing.h>  
#include <stdlib.h> 
#include <stdio.h>   

/*----------------------------------------------------------------------------*\
|                                                                              |
|   g l o b a l   v a r i a b l e s                                            |
|                                                                              |
\*----------------------------------------------------------------------------*/

static  char  szAppName[]="Generic Game";

static  HINSTANCE hInstApp;
static  HWND      hwndApp;
static  HPALETTE  hpalApp;
static  BOOL      fAppActive;

  
int      dx,dy;


// GAME_CLASS *Game;

/*************************************************************************/


	      
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

	InitGame();
	
	Game = new GAME_CLASS();

 
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

	delete Game;
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

	Game->CurrentScene->Screen->Show(hdc);
	
//	Cama->DrawSolid( hwnd, Tela1 );
//	Comoda->DrawSolid( hwnd, Tela1 );


  
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
    static boolean Initiated = false;
    

	if( Initiated )
	{    
	    if( Game->MessageHandling(hwnd, msg, wParam, lParam) )
    	{
    		return DefWindowProc(hwnd,msg,wParam,lParam);
    	}
    }
    
    switch (msg)
    {       
	
      	case WM_CREATE:

			Game->Init( hwnd );
			Initiated = true;
	   		(*SetSystemTimer)( hwnd, REFRESH_TIMER, REFRESH_PERIOD, NULL );

      	break;        
      
//     	case WM_RBUTTONDOWN:  
      
//		break;  
      
      	case WM_DESTROY: 
   			(*KillSystemTimer)( hwnd, REFRESH_TIMER );
	    	PostQuitMessage(0);
	    break;

      	case WM_ACTIVATEAPP:
      		fAppActive = (BOOL)wParam;
      	break;

	    
		case WM_TIMER:
		break;
	
		case WM_SYSTIMER:
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

		    if (Game->CurrentScene->Screen->hpalApp)
		    {
				SelectPalette(hdc, Game->CurrentScene->Screen->hpalApp, FALSE);
			}
		
		    f = RealizePalette(hdc);
		    ReleaseDC(hwnd,hdc);
		
		    if (f)
		    {
				InvalidateRect(hwnd,NULL,TRUE);
			}
		
		    return f;

		case WM_PAINT:
	    	hdc = BeginPaint(hwnd,&ps);
		 	SelectPalette(hdc, Game->CurrentScene->Screen->hpalApp, FALSE);
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



void MessageBox( char *Title, char *Mask, char *Arg ) // , uint Option )
{
	static char Out[100];
	
	sprintf( Out, Mask, Arg );
	
	MessageBox( NULL, Out, Title, MB_APPLMODAL | MB_OK | MB_ICONEXCLAMATION ); // | Option );
}
