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
#include "demo.h"
#include "mmsystem.h" 
#include "utils.h"       
#include "gamedefs.hpp"
#include <wing.h>  
#include <stdlib.h> 
#include <stdio.h>   

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

/*typedef struct header
{
  BITMAPINFOHEADER  Header;
  RGBQUAD           aColors[256];
} header;
*/
  
header		BufferH;  
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
int 	 BackX, BackY;
int      DogX, DogY;
int      dx,dy;
POINT    Old; 
int 	 InicioBufferX=0, InicioBufferY=0;	     
int		 Scrollx=0, Scrolly=0;
int		 SpriteOrder=1;


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


   	pBitmap = DibOpenFile("tommy.bmp");
   	pBack   = DibOpenFile("back.bmp");
   
    pBitmap->biWidth  = BITMAPX;
    pBitmap->biHeight = BITMAPY;                                  
                                       
  
    BackX = DibWidth(pBack);
    BackY = DibHeight(pBack);


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
  if (Buffer)
  {



    HBITMAP hbm;
    HBITMAP hback;

    //  Retrieve the current WinGBitmap, replace with the original
    hbm   = (HBITMAP)SelectObject(Buffer, gbmOldMonoBitmap);
    hback = (HBITMAP)SelectObject(BackBuffer, gBackOldMonoBitmap);
    
    //  And delete the WinGBitmap and WinGDC
    DeleteObject(hbm);
    DeleteObject(hback);
    
    DeleteDC(Buffer);
    DeleteDC(BackBuffer);


	delete Tela1;
	delete Tommy1;
//	delete Tommy2;

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
|   PaintDoggie                                                       		   |
|                                                                              |
\*----------------------------------------------------------------------------*/


void PaintDoggie( HDC hdc, int X, int Y )
{
  int DestinationX;
  int DestinationY;
  int Width = BITMAPX;
  int Height = BITMAPY;
  LPVOID BitmapOffset;
  DestinationX = X;
  DestinationY = Y;	
    
   //Restore the old background
  BitBlt(Buffer,Old.x,Old.y,Width, Height,
  	  BackBuffer,0,0, SRCCOPY); 
                               
 //  Save the background that will be erased                             
  BitBlt(BackBuffer,0,0,Width,Height,
      Buffer,X,Y, SRCCOPY);
      
  (LPVOID) BitmapOffset = ((char far *) DibPtr(pBitmap)) 
  						  + SpriteOrder*(BITMAPX*BITMAPY);    
   
	(SpriteOrder >= 3) ? (SpriteOrder=0) : ++SpriteOrder;                                   
                                          
//   Paint to the Buffer
  TransparentDIBits((BITMAPINFO far *)&BufferHeader,pBuffer,X,
    Y, BitmapOffset, DibInfo(pBitmap),
    0, 0, DIB_RGB_COLORS,
    TransparentColor);                
    
 /*   CopyDIBits((BITMAPINFO far *)&BufferHeader,pBuffer,X,
    Y, BitmapOffset, DibInfo(pBitmap),
    0, 0, DIB_RGB_COLORS); //Teste da rotina de cópia  */
                            
}                                 

/*----------------------------------------------------------------------------*\
|   CarPaint (HWND hwnd, HDC hdc, int X, int Y)                                                     |
                                                                             |
\*----------------------------------------------------------------------------*/
CarPaint (HWND hwnd, HDC hdc, int X, int Y) 
{    
    // Restaura o background
    WinGBitBlt(hdc,Old.x-InicioBufferX,Old.y-InicioBufferY,BITMAPX, BITMAPY,Buffer,Old.x,Old.y); 
	
	// Mostra o objeto
	WinGBitBlt(hdc,X-InicioBufferX,Y-InicioBufferY,BITMAPX,BITMAPY,Buffer,X,Y);
	
	return TRUE;
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

//  WinGBitBlt(hdc,0,0,dx,dy,Buffer, InicioBufferX, InicioBufferY); 
  
  return TRUE;
}         
  
void Teste(HDC hdc) {
  // Checa se nao ultrapassa limites do Buffer
  if (InicioBufferX + Scrollx * DELTASCROLL < 0) Scrollx=0;
  else if (InicioBufferX + Scrollx * DELTASCROLL + dx > BackX) Scrollx=0;
	  
  if (InicioBufferY + Scrolly * DELTASCROLL < 0) Scrolly=0;
  else if (InicioBufferY + Scrolly * DELTASCROLL + dy > BackY) Scrolly=0;

  

  if (Scrollx || Scrolly)
  {
	  // Recalcula a posicao do Buffer na tela
      InicioBufferX += Scrollx * DELTASCROLL;
      InicioBufferY += Scrolly * DELTASCROLL;
	  
	  (SpriteOrder >= 3) ? (SpriteOrder=0) : ++SpriteOrder;     
	  PaintDoggie(Buffer, Old.x+Scrollx*DELTASCROLL, Old.y+Scrolly*DELTASCROLL );
	  Old.x += Scrollx*DELTASCROLL;
	  Old.y+= Scrolly*DELTASCROLL;
	  Scrollx=0;
	  Scrolly=0;
	  WinGBitBlt(hdc,0,0,dx,dy,Buffer, InicioBufferX, InicioBufferY);  
  }	  
   

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
    long int i;
    int X;
    int Y;     
    int AuxX, AuxY;
    int DeltaX=DELTA, DeltaY=DELTA,
    	DistX, DistY;    
	register int Dist, Counter;    	
	int IncrNE, IncrE, IncrN;

    
    switch (msg)
    {       
    	
      case WM_CREATE:

/*	
	{

        //  Create a new WinGDC and 8-bit WinGBitmap



        HBITMAP hbm;   
        HBITMAP hback;
          int Counter;
          HDC Screen;
          RGBQUAD far *pColorTable;

        //  Get WinG to recommend the fastest DIB format

        if(WinGRecommendDIBFormat((BITMAPINFO far *)&BufferHeader))
        {
          //  make sure it's 8bpp and remember the orientation

          BufferHeader.Header.biBitCount = 8;
          BufferHeader.Header.biCompression = BI_RGB;
          Orientation = BufferHeader.Header.biHeight;
        }
        else
        {
          //  set it up ourselves
  
          BufferHeader.Header.biSize = sizeof(BITMAPINFOHEADER);
          BufferHeader.Header.biPlanes = 1;
          BufferHeader.Header.biBitCount = 8;
          BufferHeader.Header.biCompression = BI_RGB;
          BufferHeader.Header.biSizeImage = 0;
          BufferHeader.Header.biClrUsed = 0;
          BufferHeader.Header.biClrImportant = 0;
        }

        BufferHeader.Header.biWidth  = BackX; 
        BufferHeader.Header.biHeight = BackY * Orientation; 

        //  create an identity palette from the DIB's color table

        //  get the 20 system colors as PALETTEENTRIES
    
          Screen = GetDC(0);

          GetSystemPaletteEntries(Screen,0,10,LogicalPalette.aEntries);
          GetSystemPaletteEntries(Screen,246,10,
                LogicalPalette.aEntries + 246);

        ReleaseDC(0,Screen);

        // initialize the logical palette and DIB color table

          for(Counter = 0;Counter < 10;Counter++)
          {
            // copy the system colors into the DIB header
            // WinG will do this in WinGRecommendDIBFormat,
            // but it may have failed above so do it here anyway
            
            BufferHeader.aColors[Counter].rgbRed =
                    LogicalPalette.aEntries[Counter].peRed;
            BufferHeader.aColors[Counter].rgbGreen =
                    LogicalPalette.aEntries[Counter].peGreen;
            BufferHeader.aColors[Counter].rgbBlue =
                    LogicalPalette.aEntries[Counter].peBlue;
            BufferHeader.aColors[Counter].rgbReserved = 0;

            LogicalPalette.aEntries[Counter].peFlags = 0;

            BufferHeader.aColors[Counter + 246].rgbRed =
                  LogicalPalette.aEntries[Counter + 246].peRed;
            BufferHeader.aColors[Counter + 246].rgbGreen =
                  LogicalPalette.aEntries[Counter + 246].peGreen;
            BufferHeader.aColors[Counter + 246].rgbBlue =
                  LogicalPalette.aEntries[Counter + 246].peBlue;
            BufferHeader.aColors[Counter + 246].rgbReserved = 0;

            LogicalPalette.aEntries[Counter + 246].peFlags = 0;
          }
                             
                             
/ *		  pColorTable = (RGBQUAD far *)
            ((char far *)pBitmap + pBitmap->biSize);

          for(Counter = 10;Counter < 45;Counter++)
          {
            // Reserva 35 cores da palette                          
            // Copia as cores do personagem principal             
            BufferHeader.aColors[Counter].rgbRed =
              LogicalPalette.aEntries[Counter].peRed =
                pColorTable[Counter].rgbRed;
            BufferHeader.aColors[Counter].rgbGreen =
              LogicalPalette.aEntries[Counter].peGreen =
                pColorTable[Counter].rgbGreen;
            BufferHeader.aColors[Counter].rgbBlue =

              LogicalPalette.aEntries[Counter].peBlue =
                pColorTable[Counter].rgbBlue;
            BufferHeader.aColors[Counter].rgbReserved = 0;
            LogicalPalette.aEntries[Counter].peFlags = PC_NOCOLLAPSE;
          }                             
                             
* /                             

          pColorTable = (RGBQUAD far *)
            ((char far *)pBack + pBack->biSize);

          for(Counter = 10;Counter < 246;Counter++)
          {
            // copy from the original color table to the WinGBitmap's
            // color table and the logical palette
            BufferHeader.aColors[Counter].rgbRed =
              LogicalPalette.aEntries[Counter].peRed =
                pColorTable[Counter].rgbRed;
            BufferHeader.aColors[Counter].rgbGreen =
              LogicalPalette.aEntries[Counter].peGreen =
                pColorTable[Counter].rgbGreen;
            BufferHeader.aColors[Counter].rgbBlue =

              LogicalPalette.aEntries[Counter].peBlue =
                pColorTable[Counter].rgbBlue;
            BufferHeader.aColors[Counter].rgbReserved = 0;
            LogicalPalette.aEntries[Counter].peFlags = PC_NOCOLLAPSE;
          }

          hpalApp = CreatePalette((LOGPALETTE far *)&LogicalPalette);
                                                           
                
        //  Create a WinGDC and Bitmap, then select away
        Buffer 	   = WinGCreateDC();
        
        BackBuffer = WinGCreateDC();
        
        hbm   = WinGCreateBitmap(Buffer,
          (BITMAPINFO far *)&BufferHeader, &pBuffer);
          
          
        
        // Creates a Buffer to save the background
        BufferHeader.Header.biWidth  = BITMAPX; 
        BufferHeader.Header.biHeight = BITMAPY * Orientation;
        hback = WinGCreateBitmap(BackBuffer,
        	(BITMAPINFO far *)&BufferHeader , &pBackBuffer);   
        	
        	
         
         
        //  Store the old hbitmap to select back in before deleting
        gbmOldMonoBitmap   = (HBITMAP)SelectObject(Buffer, hbm);
        
        gBackOldMonoBitmap = (HBITMAP)SelectObject(BackBuffer, hback);
        
      }

*/
		Tela1->Init(hwnd);
		Tommy1->Init( Tela1 );
		
		BufferHeader = Tela1->BufferHeader;
		Buffer = Tela1->hBuffer;
		pBuffer = Tela1->pBuffer;
		hpalApp = Tela1->hpalApp;
		BackBuffer = Tommy1->hBackBuffer;
		pBackBuffer = Tommy1->pBackBuffer;
				
//		Tommy2->Init( Tela1 );
		
  
  
      break;        
      
      // Faz um scroll horizontal      
      
      case WM_RBUTTONDOWN:  
      
        break;  
      case WM_KEYDOWN:  
      
      case WM_DESTROY:
            PostQuitMessage(0);
            break;

      case WM_ACTIVATEAPP:
      fAppActive = (BOOL)wParam;
      break;

      case WM_SIZE:

/*        BufferHeader.Header.biWidth = BackX;//LOWORD(lParam);
        BufferHeader.Header.biHeight = BackY * Orientation;//HIWORD(lParam) 

      dx = LOWORD(lParam);
        dy = HIWORD(lParam);

/ *    if(Buffer)
      {
        HBITMAP hbm;

        //  Create a new 8-bit WinGBitmap with the new size
        BufferHeader.Header.biWidth = BackX;//LOWORD(lParam);
        BufferHeader.Header.biHeight = BackY * Orientation;//HIWORD(lParam) 
        hbm = WinGCreateBitmap(Buffer,
          (BITMAPINFO far *)&BufferHeader, &pBuffer);

        //  Select it in and delete the old one
        hbm = (HBITMAP)SelectObject(Buffer, hbm);
        DeleteObject(hbm);
        
      }

		Tela1->UpdateBufferHeader( LOWORD(lParam), HIWORD(lParam) );
* /      
//      hdc=GetDC(hwnd);
      PatBlt(Buffer, 0,0,dx,dy, BLACKNESS); 
      PatBlt(BackBuffer, 0, 0, BITMAPX, BITMAPY, BLACKNESS);
//      ReleaseDC(hwnd,hdc);
      

      // Draw the background to the Buffer
      CopyDIBits((BITMAPINFO far *)&BufferHeader,pBuffer,
        0, 0, DibPtr(pBack) ,DibInfo(pBack), DIB_RGB_COLORS,0,0);
       
      // Save the background that will be erased                             
      BitBlt(BackBuffer,0,0,BITMAPX,BITMAPY,
      Buffer,dx/2,dy/2, SRCCOPY);
      Old.x=dx/2;
      Old.y=dy/2;
                  
      //DibFree(pBack);            
                  
      //  Stick the doggie into the center of the buffer
      TransparentDIBits((BITMAPINFO far *)&BufferHeader,pBuffer,dx/2,
    		dy/2,DibPtr(pBitmap),DibInfo(pBitmap),0,0,DIB_RGB_COLORS,
    		TransparentColor);    
*/          	
        break;  
            
            
        case WM_LBUTTONDOWN: 
        	
        	   
            Tommy1->Move( hwnd, Tela1, LOWORD(lParam), HIWORD(lParam) );
            
/*
        	X = LOWORD(lParam)-(BITMAPX>>1)+ InicioBufferX;
            Y = HIWORD(lParam)-(BITMAPY - 10)+ InicioBufferY;
           
                
                	
            AuxX=Old.x;
            AuxY=Old.y;
                        
			DistX = (X - AuxX);
            DistY = (Y - AuxY);
            
			if( DistX < 0 ) 
			{
				DeltaX = -DeltaX;
				DistX = -DistX;
			}
			
			if( DistY < 0 ) 
			{
				DeltaY = -DeltaY;
				DistY = -DistY; 
			} 
			
			
			Counter = 0 ; 
			
			if ((DistX < PASSO) && (DistY < BITMAPY>>1)) break;
			
			hdc = GetDC(hwnd);
			
			SelectPalette(hdc,hpalApp,FALSE);
        	RealizePalette(hdc);
			if( DistX > DistY )
			{		
				IncrE  = DistY<<1;
				Dist   = IncrE - DistX;
                IncrNE = Dist - DistX;
                
            	do
            	{    
            		
            		if( Dist <= 0 )
            		{
            			Dist += IncrE;
                		AuxX += DeltaX;
                	}
                	else
                	{
            			Dist += IncrNE;
                		AuxX += DeltaX;
                		AuxY += DeltaY; 	            		
            	
	               	}            
	               	Counter += DELTA;
	               	if( Counter > PASSO)
                        {
                        	Counter = 0;
	            			PaintDoggie(hdc, AuxX ,AuxY );
	            			CarPaint(hwnd,hdc, AuxX, AuxY); 
	            			 
						    Old.x=AuxX;
						    Old.y=AuxY; 
						    
						    if (AuxX - InicioBufferX > 500) 
						    	Scrollx=1;
						    else if (AuxX - InicioBufferX < 40)
						    	Scrollx = -1;
						    if (AuxY - InicioBufferY > 300)
						    	Scrolly = 1;
						    else if (AuxY - InicioBufferY < 40)
						    	Scrolly = -1;
						     
						    if (Scrollx || Scrolly)
						    	Teste(hdc);
						    else
						    	for (i=0; i<160000; i++);
						    						    
	            		}
                                   
                                             
            	} while ( abs(AuxX - X) > DELTA );  
            }
            else
			{		
				IncrN  = -(DistX<<1);
				Dist   = DistY + IncrN;
                IncrNE = Dist + DistY;
                
            	do
            	{   
            		if( Dist > 0 )
            		{
            			Dist += IncrN;
                		AuxY += DeltaY;
                	}
                	else
                	{
            			Dist += IncrNE;
                		AuxX += DeltaX;
                		AuxY += DeltaY;                          
            	
	               	}  
	               	if( Counter++ == PASSO)
                        {
                        	Counter = 0;
	            			PaintDoggie(hdc, AuxX ,AuxY );
	            			CarPaint(hwnd,hdc, AuxX, AuxY);
	            			 
							Old.x=AuxX;
							Old.y=AuxY;
							
							if (AuxX - InicioBufferX > 500) 
						    	Scrollx=1;
						    else if (AuxX - InicioBufferX < 40)
						    	Scrollx = -1;
						    if (AuxY - InicioBufferY > 300)
						    	Scrolly = 1;
						    else if (AuxY - InicioBufferY < 40)
						    	Scrolly = -1;
						     
						    if (Scrollx || Scrolly)  						    	
						      	Teste(hdc);
						    else for (i=0; i<160000; i++);
						    
	            	}  	               	
                                            
            	} while (abs(AuxY - Y) > DELTA);  
            }
	        
	        SpriteOrder=4;                          
            PaintDoggie(hdc, X,Y);
            AppPaint(hwnd, hdc);
             
  			Old.x=X;
  			Old.y=Y;              
       		ReleaseDC(hwnd,hdc);
*/
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
