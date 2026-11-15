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

#include "demo.h"
#include "gamedefs.hpp"
#include "mmsystem.h" 


#define  DELTASCROLL 20
#define  DELTA	  1	
#define  BITMAPX 104
#define  BITMAPY 100 
#define  PASSO 18   //Tommy 


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

int		 Scrollx=0, Scrolly=0;


/*************************************************************************/

char *TommyNames[] = { "Tommy.bmp" };    
int		TommyFrames[] = { 5 };
int		TommyWidth[] = { 104 };
int		TommyHeight[] = { 100 };
                         
                             
screen 	*Tela1;

object 	*Tommy1,
		*Tommy2;


              
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
    int dx, dy;

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
        cls.style          = CS_BYTEALIGNCLIENT | CS_DBLCLKS; //| CS_VREDRAW | CS_HREDRAW 
        cls.lpfnWndProc    = (WNDPROC)AppWndProc;
        cls.cbWndExtra     = 0;
        cls.cbClsExtra     = 0;

        if (!RegisterClass(&cls))
            return FALSE;
    }

    dx = 640;
    dy = 480;

 	Tela1 = new screen( "back.bmp" ) ;
	Tommy1 = new object( 200, 200, 1, TommyNames, TommyFrames, TommyWidth, TommyHeight ), 
//	Tommy2 = new object( 400, 400, 1, TommyNames, TommyFrames, TommyWidth, TommyHeight ) ;

 
    hwndApp = CreateWindow (szAppName,              // Class name
                            szAppName,              // Caption
                            WS_POPUP |
                            WS_MAXIMIZE,			// Style bits
                            0, 
                            0, 		      			// Position
                            dx,	
                            dy, 			        // Size
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
//  if (hBuffer)
  {

	delete Tela1;
	delete Tommy1;
	delete Tommy2;

  }

  if(hpalApp)
  {
    DeleteObject(hpalApp);
  }
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
//  WinGBitBlt(hdc,0,0,dx,dy, hBuffer, InicioBufferX, InicioBufferY); 
  
  return TRUE;
}         
  
void Teste(HDC hdc, screen *Screen, object *Object ) 
{
  // Checa se nao ultrapassa limites do Buffer
  if ( Screen->ScreenX + Scrollx * DELTASCROLL < 0) 
  {
  	Scrollx=0;
  }
  else 
  if (Screen->ScreenX + Scrollx * DELTASCROLL + Screen->ScreenWidth > Screen->BufferWidth) 
  {
  	Scrollx=0;
  }
	  
  if (Screen->ScreenY + Scrolly * DELTASCROLL < 0) 
  {
  	Scrolly=0;
  }
  else 
  if (Screen->ScreenY + Scrolly * DELTASCROLL + Screen->ScreenHeight > Screen->BufferHeight) 
  {
  	Scrolly=0;
  }

  if (Scrollx || Scrolly)
  {
	  // Recalcula a posicao do Buffer na tela
      Screen->ScreenX += Scrollx * DELTASCROLL;
      Screen->ScreenY += Scrolly * DELTASCROLL;
	                                            
	  Object->NextFrame();                                          
//	  (Spriteorder >= 3) ? (SpriteOrder=0) : ++SpriteOrder;     

	  Object->Paint( Object->X+Scrollx*DELTASCROLL, Object->Y+Scrolly*DELTASCROLL, Screen );
	   
/*	  PaintDoggie(Buffer, Old.x+Scrollx*DELTASCROLL, Old.y+Scrolly*DELTASCROLL );
	  Old.x += Scrollx*DELTASCROLL;
	  Old.y+= Scrolly*DELTASCROLL;
*/
	  Scrollx=0;
	  Scrolly=0;

	  Screen->Show(hdc);
  }	  
   

}


//***********************************************************



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

    
    switch (msg)
    {       
    	
      case WM_CREATE:

		Tela1->Init(hwnd);
		
		Tommy1->Init( Tela1 );
//		Tommy2->Init( Tela1 );
		
  
      break;        
      
      // Faz um scroll horizontal      
      
      case WM_KEYDOWN:  
      
      case WM_DESTROY:
            PostQuitMessage(0);
            break;

      case WM_ACTIVATEAPP:
      fAppActive = (BOOL)wParam;
      break;

      case WM_SIZE:

        break;  
            
            
      case WM_LBUTTONDOWN:       
            
            Tommy1->Move( hwnd, Tela1, LOWORD(lParam), HIWORD(lParam) );
      break;

      case WM_RBUTTONDOWN:  
            
//            Move( hwnd, Tommy2, Tela1, LOWORD(lParam), HIWORD(lParam) );
      break;

      case WM_COMMAND:
            return AppCommand(hwnd,msg,wParam,lParam);
      break;
        
      case WM_CLOSE:
      break;

      case WM_PALETTECHANGED:
      	if ((HWND)wParam == hwnd)
    		break;

      // fall through to WM_QUERYNEWPALETTE

  	case WM_QUERYNEWPALETTE:
      hdc = GetDC(hwnd);

      if (hpalApp)
    		SelectPalette(hdc, hpalApp, FALSE);

      f = RealizePalette(hdc);
      ReleaseDC(hwnd,hdc);

      if (f)
    	InvalidateRect(hwnd,NULL,TRUE);

      return f;

    case WM_PAINT:
      hdc = BeginPaint(hwnd,&ps);
      SelectPalette(hdc, hpalApp, FALSE);
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
    switch(wParam)
    {
        case MENU_ABOUT:
            DialogBox(hInstApp,"AppAbout",hwnd,(DLGPROC)AppAbout);
            break;

        case MENU_EXIT:
            PostMessage(hwnd,WM_CLOSE,0,0L);
            break;
    }
    return 0L;
}
