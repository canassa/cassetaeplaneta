
#define _SCREEN

#include "games.hpp"
#include "screen.hpp"
#include "object.hpp"
//#include "3dobject.hpp"

#undef _SCREEN




//	occupation occup_matrix::incration( int X, int Y, int Width, int Height )
occupation occup_matrix::IncrOccupation( object *o )
{
		if( o->X < 0 || o->Y < 0 )
			return WALL;
		else                       
		{
			register int i,j;

			int LineI = o->Y+o->BoundY() >> HEIGHT_POWER;			
			int ColI  = o->X+o->BoundX() >> WIDTH_POWER;	

			int LineF = (o->Y+o->BoundY()+o->BoundHeight()) >> HEIGHT_POWER;
			int ColF  = (o->X+o->BoundX()+o->BoundWidth())  >> WIDTH_POWER;	

			for( i = LineI; i <= LineF ; i++ )
			{
			 	for( j = ColI; j <= ColF; j++ )
		 		{
		 			IncrOccup( i, j, o );
			 	}
			}
			return (char) 1;
		}
}	                                                

//	occupation occup_matrix::DecrOccupation( int X, int Y, int Width, int Height )
occupation occup_matrix::DecrOccupation( object *o )
{
		if( o->X < 0 || o->Y < 0 )
			return WALL;
		else                       
		{
			register int i,j;

			int LineI = o->Y+o->BoundY() >> HEIGHT_POWER;			
			int ColI  = o->X+o->BoundX() >> WIDTH_POWER;	

			int LineF = (o->Y+o->BoundY()+o->BoundHeight()) >> HEIGHT_POWER;
			int ColF  = (o->X+o->BoundX()+o->BoundWidth())  >> WIDTH_POWER;	

			for( i = LineI; i <= LineF ; i++ )
			{
			 	for( j = ColI; j <= ColF; j++ )
		 		{
		 			DecrOccup( i, j, o );
			 	}
			}
			return (char) 1;
		}
}	                                                


occupation occup_matrix::Occupation( int X, int Y, int Width, int Height )
{                                                                       
	object *OccupObj = NULL;
	occupation lastocc;
	
	return Occupation( X, Y, Width, Height, OccupObj, lastocc );
}


occupation occup_matrix::Occupation( int X, int Y, int Width, int Height, object * &OccupObj, occupation &lastocc )
{                   
		occupation occ, maxocc;

		maxocc = lastocc = FREE;
		OccupObj = OccupObject = NULL;

		if( X < 0 || Y < 0 )
			return WALL;
		else
		{   
			register int i,j,m,n;
			                         
			Y >>= HEIGHT_POWER;
			X >>= WIDTH_POWER;		
			
			m = Y + (Height >> HEIGHT_POWER);	
			n = X + (Width >> WIDTH_POWER);
                        
			for( i = Y; i <= m; i++ )
			{
				for( j = X; j <= n; j++ )
				{                
					occ = Mat[i][j];

					if( occ == WALL )
					{
						lastocc = WALL;
					}
					else
					{
						if( maxocc == FREE )
						{
							OccupObj = Obj[i][j];
		
		    				if( OccupObj == NULL && OccupObject != NULL )
		    				{
		    					LastOccupObject = OccupObject;
		    				}
		
							OccupObject = Obj[i][j];
						
							if( occ > FREE )
							{
								maxocc = occ;
							}       
							else
							if( occ < FREE )
							{
								maxocc = -occ-1;
								lastocc = WALL;
							}       
						}
						else
						if( occ < FREE )
						{
							lastocc = WALL;
						}       
					}
				}
			}

	 		return (maxocc == FREE ? lastocc : maxocc);
	 	}
};



screen *screen::Init( HWND hwnd )
{
         //  Create a new WinGDC and 8-bit WinGBitmap

        HBITMAP hbm;   
        HDC Screen;
         
		pal LogicalPalette =
		{
		  0x300,
		  256
		};

		// get the 20 windows palette colors
        Screen = GetDC(0);

        GetSystemPaletteEntries(Screen,0,10,LogicalPalette.aEntries);
        GetSystemPaletteEntries(Screen,246,10,
                LogicalPalette.aEntries + 246);

        ReleaseDC(0,Screen);

        // initialize the logical palette and DIB color table with the 20 colors
		ReserveWindowsPalette( LogicalPalette );

//		ObjectList->ReservePalette( BufferHeader, LogicalPalette );

		// fill the palette with other 236 colors of the bitmap
		FillPalette( LogicalPalette );
				                             

        hpalApp = CreatePalette((LOGPALETTE far *)&LogicalPalette);
                                                           

		Orientation = InitBufferHeader();
		
                
        //  Create a WinGDC and Bitmap, then select away

        hBuffer 	   = WinGCreateDC();
        
        pBuffer = NULL;  // (void far *) &pBuffer;
//        pBuffer2 = NULL; // (void far *) &pBuffer2;
        
        hbm   = WinGCreateBitmap(hBuffer,
          (BITMAPINFO far *)&BufferHeader, &pBuffer);
        
//		pBuffer = WinGGetDIBPointer( hbm, NULL );
		        
       //  Store the old hbitmap to select back in before deleting
        gbmOldMonoBitmap   = (HBITMAP)SelectObject(hBuffer, hbm);
        


/*
        hBuffer2 	   = WinGCreateDC();
        hbm   = WinGCreateBitmap(hBuffer2,
          (BITMAPINFO far *)&BufferHeader, &pBuffer2);

//		pBuffer2 = WinGGetDIBPointer( hbm, NULL );
		
       //  Store the old hbitmap to select back in before deleting
        gbmOldMonoBitmap2   = (HBITMAP)SelectObject(hBuffer2, hbm);
*/        

//        PatBlt(hBuffer, 0,0, ScreenWidth, ScreenHeight, BLACKNESS); 
//        PatBlt(hBuffer2, 0,0, ScreenWidth, ScreenHeight, BLACKNESS); 
  		Dark();    
		
		HDC hdc = GetDC(hwnd);
  		Show(hdc);
  		ReleaseDC(hwnd, hdc);
	
      // Draw the background to the Buffer
        Paint();

		// Initialize the object at each one's position in the screen
//		ObjectList->PutIntoBuffer( hBuffer, BufferHeader, pBuffer );

	  	return this;

}

long screen::InitBufferHeader(void)  
{
		long 	Orientation = 1l;
                                                    
        //  Get WinG to recommend the fastest DIB format
           
        Orientation = WinGRecommendDIBFormat((BITMAPINFO far *)&BufferHeader);   

        if( Orientation )
        {
          //  make sure it's 8bpp and remember the orientation

          BufferHeader.Header.biBitCount = 8;
          BufferHeader.Header.biCompression = BI_RGB;
          Orientation = (BufferHeader.Header.biHeight < 0 ? -1l : 1l);
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
          Orientation = 1l;
        }

        BufferHeader.Header.biWidth  = BufferWidth; 
        BufferHeader.Header.biHeight = BufferHeight * Orientation; 

        return Orientation;
}


void screen::ReserveWindowsPalette( pal &LogicalPalette )  
{
		register int Counter;

        //  create an identity palette from the DIB's color table

        //  get the 20 system colors as PALETTEENTRIES
    

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
                             
}


void screen::FillPalette( pal &LogicalPalette )  
{
	register int Counter;
                          
	RGBQUAD far * pColorTable;                          
	
        pColorTable = (RGBQUAD far *) 
                    ((char far *)pBack + pBack->biSize);

	
/*          for(Counter = PaletteOffSet,
         	  End = Counter+NumColors; 
          	  Counter < End;Counter++)
*/

		  for(Counter = 10; Counter < 246;Counter++)
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
            LogicalPalette.aEntries[Counter].peFlags = PC_RESERVED;
          }
}


boolean screen::TestScroll(HDC hdc, moveable *Object, int AuxX, int AuxY ) 
{       
	register
	int		 Scrollx=0, Scrolly=0;	

	if( ! Object->IsPlayer() )
	{
		return false;
	}	
	
    if (AuxX - ScreenX > 500) 
    	Scrollx=1;
    else if (AuxX - ScreenX < 40)
    	Scrollx = -1;

    if (AuxY - ScreenY > 300)
    	Scrolly = 1;
    else if (AuxY - ScreenY < 40)
	   	Scrolly = -1;

  if (!(Scrollx || Scrolly))
  	return false;


  // Checa se nao ultrapassa limites do Buffer

 if( Scrollx > 0 )
 {
  if (ScreenX + DELTASCROLL + ScreenWidth > BufferWidth) 
  {
  	Scrollx=0;
  }
 }
 else if( Scrollx < 0 )
 {
  if ( ScreenX - DELTASCROLL < 0) 
  {
  	Scrollx=0;
  }
 }
 	  
 if( Scrolly > 0 )
 {
  if (ScreenY + DELTASCROLL + ScreenHeight > BufferHeight) 
  {
  	Scrolly=0;
  }             
 }
 else if( Scrolly < 0 )
 {
  if (ScreenY - DELTASCROLL < 0) 
  {
  	Scrolly=0;
  }
 }

  // Recalcula a posicao do Buffer na tela

  if (Scrollx)
  {
	Scrollx *= DELTASCROLL;         

    ScreenX += Scrollx;
	
   	if(Scrolly)
   	{
	  Scrolly *= DELTASCROLL;

      ScreenY += Scrolly;

	  ScrollLayers();
	  Object->Paint( Object->X+Scrollx, Object->Y+Scrolly, this );
	  Object->TreatCollision( hdc, this );
	   
    }	  
    else
    {
	  ScrollLayers();
	  Object->Paint( Object->X+Scrollx, Object->Y, this );
	  Object->TreatCollision( hdc, this );
    }
  }	  
  else
  {
    if(Scrolly)
    {
	  Scrolly *= DELTASCROLL;

      ScreenY += Scrolly;
	                                            
	  ScrollLayers();
	  Object->Paint( Object->X, Object->Y+Scrolly, this );
	  Object->TreatCollision( hdc, this );
    }	  
    else
    {
	  return(false);
    }
  }  		
   
  Show(hdc);

  return(true);


}

