/*        
#define _GAMEDEFS

#include "gamedefs.hpp"

#undef _GAMEDEFS

*/

#define _GAMES
#define _SCREEN
#define _OBJECT
#define _3DOBJECT

#include "games.hpp"
#include "screen.hpp"
#include "object.hpp"
#include "3dobject.hpp"

#undef _GAMES
#undef _SCREEN
#undef _OBJECT
#undef _3DOBJECT





//	occupation occup_matrix::incration( int X, int Y, int Width, int Height )
occupation occup_matrix::IncrOccupation( object *o )
{
		if( o->X < 0 || o->Y < 0 )
			return WALL;
		else                       
		{
			register int i,j;

			int LineI = o->Y+o->BoundY >> HEIGHT_POWER;			
			int ColI  = o->X+o->BoundX >> WIDTH_POWER;	

			int LineF = (o->Y+o->BoundY+o->BoundHeight) >> HEIGHT_POWER;
			int ColF  = (o->X+o->BoundX+o->BoundWidth)  >> WIDTH_POWER;	

			for( i = LineI; i <= LineF ; i++ )
			{
			 	for( j = ColI; j < ColF; j++ )
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

			int LineI = o->Y+o->BoundY >> HEIGHT_POWER;			
			int ColI  = o->X+o->BoundX >> WIDTH_POWER;	

			int LineF = (o->Y+o->BoundY+o->BoundHeight) >> HEIGHT_POWER;
			int ColF  = (o->X+o->BoundX+o->BoundWidth)  >> WIDTH_POWER;	

			for( i = LineI; i <= LineF ; i++ )
			{
			 	for( j = ColI; j < ColF; j++ )
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
		if( X < 0 || Y < 0 )
			return WALL;
		else
		{   
			register int i,j,m,n;
			
			occupation occ;
			
			
			lastocc = FREE;
			                         
			Y >>= HEIGHT_POWER;
			X >>= WIDTH_POWER;		
			
			m = Y + (Height >> HEIGHT_POWER);	
			n = X + (Width >> WIDTH_POWER);
                        
			for( i = Y; i < m; i++ )
			{
				for( j = X; j < n; j++ )
				{                
					occ = Mat[i][j];
					OccupObj = Obj[i][j];

    				if( OccupObj == NULL && OccupObject != NULL )
    				{
    					LastOccupObject = OccupObject;
    				}

					OccupObject = Obj[i][j];
					

					if( occ > FREE )
					{
						return occ;
					}       
					else
					if( occ == WALL )
					{
						lastocc = WALL;
					}
					else
					if( occ < FREE )
					{
						return -occ-1;
					}       
				}
			}
					       
	 		return lastocc;
	 	}
};



object * object::Init( screen *Screen )
{
    	HBITMAP hback;              
    	
    	*((header *)&BufferHeader) = Screen->BufferHeader;

        // Creates a Buffer to save the background
        BufferHeader.Header.biWidth  = FrameWidth(); 
        BufferHeader.Header.biHeight = Sprite().NumberOfFrames*FrameHeight();// *Orientation;
        
        hBackBuffer = WinGCreateDC();
        pBackBuffer = NULL;
        
        hback = WinGCreateBitmap(hBackBuffer,
        	(BITMAPINFO far *)&BufferHeader , &pBackBuffer);   
        	
        gBackOldMonoBitmap = (HBITMAP)SelectObject(hBackBuffer, hback);

      	PatBlt(	hBackBuffer, 0, 0, FrameWidth(), FrameHeight(), BLACKNESS); 

      	
		if( IsVisible )
		{                                                                    

			Appear( Screen );
			
      // Save the background that will be erased                             
//			SaveBackGround( Screen->hBuffer ); 

      // Stick the object into its position in the buffer
//        	PutIntoBuffer( (BITMAPINFO far *)&(Screen->BufferHeader), 
//        					Screen->pBuffer );

	  	}

		OccupScreen( Screen );
		
		return this;
};

_3D_object * _3D_object::Init( _3D_screen *Screen )
{            
	object:: Init(Screen);
		
	w = h = d = 0;                   

	return this;	
}


void Get3DPosition( _3D_screen *Screen, int &x, int &y, int z, int X, int Y, int w = 0 )
{            
	long _Y = Y; // Screen->ScreenHeight-(Y-Screen->ScreenY)-Y3DO;
	long _X = X; // (X-Screen->ScreenX)+X3DO;
	
//	z = _z;
	
	x = _X - ((long)(_Y - z))*((long)(_X-Screen->XV))/((long)(_Y-Screen->YV)) + ((long)Screen->DX);

	y = ((long)Screen->v)*(((long)z) - _Y)/(_Y-Screen->YV);

}



void Get2DPosition( _3D_screen *Screen, int x, int y, int z, int &X, int&Y, int w = 0 )
{
 	x -= Screen->DX;

 	X = x + ((long)Screen->XV - x)*(long)y/((long)y+Screen->v);
 	          
	Y = Screen->ScreenHeight - (z + ((long)Screen->YV - z)*(long)y/((long)y+Screen->v));
}  
          
object * _3D_object::DrawSolid( HWND hwnd, _3D_screen *Screen )
{            
	HDC  hdc;
	hdc = GetDC(hwnd);		            

	DrawSolid( hdc, Screen );

	ReleaseDC(hwnd,hdc);

	return this;	
}

	
object * _3D_object::DrawSolid( HDC hdc, _3D_screen *Screen )
{            

	HPEN hpen;
	HGDIOBJ hpenOld;
	int _X, _Y;
		     
	hpen = CreatePen( PS_SOLID, 1, RGB(255,255,0) );
	hpenOld = SelectObject(hdc,hpen);
	
	Get2DPosition( Screen, x,y,z, _X,_Y, w );
	MoveTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x+w,y,z, _X,_Y, w );
	LineTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x+w,y,z+h, _X,_Y, w );
	LineTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x,y,z+h, _X,_Y, w );
	LineTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x,y,z, _X,_Y, w );
	LineTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x,y+d,z, _X,_Y, w );
	LineTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x,y+d,z+h, _X,_Y, w );
	LineTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x+w,y+d,z+h, _X,_Y, w );
	LineTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x+w,y+d,z, _X,_Y, w );
	LineTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x,y+d,z, _X,_Y, w );
	LineTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x,y+d,z+h, _X,_Y, w );
	MoveTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x,y,z+h, _X,_Y, w );
	LineTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x+w,y,z+h, _X,_Y, w );
	MoveTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x+w,y+d,z+h, _X,_Y, w );
	LineTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x+w,y+d,z, _X,_Y, w );
	MoveTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x+w,y,z, _X,_Y, w );
	LineTo( hdc, _X, _Y );
	
	
	SelectObject(hdc,hpenOld);
	DeleteObject(hpen);

	return this;	
}
                

                
int _3D_object::x3D(void) { return x; };
int _3D_object::y3D(void) { return y; };
int _3D_object::z3D(void) { return z; };
int _3D_object::w3D(void) { return w; };
int _3D_object::h3D(void) { return h; };
int _3D_object::d3D(void) { return d; };
        
                
                
boolean _3D_moveable::DetectedCollision( object *o, _3D_screen *Screen )
{
	long _Y = Screen->ScreenHeight-(AuxY-Screen->ScreenY)-Y3DO;
	long _X = (AuxX-Screen->ScreenX)+X3DO;
	
	int _x, _y;

	Get3DPosition( Screen, _x, _y, z, _X, _Y, w );
		
	_x += w*((long)_y)/2L/(_y+(long)Screen->v);

    int
	ox = o->x3D(),
	oy = o->y3D(),
	oz = o->z3D(),
	ow = o->w3D(),
	oh = o->h3D(),
	od = o->d3D();

		if( _x+w < ox ) // o->x3D() )
			return false;
			
		if( _x > ox+ow ) // o->x3D()+o->w3D() )
			return false;
			
		if( _y+d < oy ) // o->y3D() )
			return false;
			
		if( _y > oy+od ) // o->y3D()+o->d3D() )
			return false;
			
		if( z+h < oz ) // o->z3D() )
			return false;
			
		if( z > oz+oh ) // o->z3D()+o->h3D() )
			return false;
			
		return true;
}
	
boolean moveable::DetectedCollision( object *o, screen *Screen )
{
		if( X+BoundWidth < o->X )
			return false;
			
		if( X > o->X+o->BoundWidth )
			return false;
			
		if( Y+BoundHeight < o->Y )
			return false;
			
		if( Y > o->Y+o->BoundHeight )
			return false;
			
		return true;
}
	
boolean moveable::CanGo( occup_screen *Screen)
{
		return Screen->CanGo( AuxX+BoundX, AuxY+BoundY, BoundWidth, BoundHeight );
};


boolean _3D_moveable::CanGo( _3D_screen *Screen)
{
		 	object * Occup3DObj; 
			occupation occ, lastocc;
            
			occ = Screen->Occup->Occupation(AuxX+BoundX, AuxY+BoundY, BoundWidth, BoundHeight, Occup3DObj, lastocc);
			
			if( occ > FREE )
			{
				if( occ == 1 )                                            
				{               
						if( !DetectedCollision(Occup3DObj, Screen) )
						{
							return (boolean) (lastocc == FREE);
						}
						else
						{
							return false;
						}
				}
				else
				{
					return false; // procurar quais os objetos que ocupam a posicão e
									// verificar se algum colide com this.
				}
			
			}
			else                    
			{
				return (boolean) (occ == FREE);
			}
};



_3D_object * _3D_object::Set3DPosition( _3D_screen *Screen, int _z)
{            
	long _Y = Screen->ScreenHeight-(Y-Screen->ScreenY)-Y3DO;
	long _X = (X-Screen->ScreenX)+X3DO;
	
	z = _z;
	
	Get3DPosition( Screen, x, y, z, _X, _Y, w );
		

	return this;
}

_3D_object * _3D_moveable::Set3DPosition( _3D_screen *Screen, int _z)
{            
	long _Y = Screen->ScreenHeight-(Y-Screen->ScreenY)-Y3DO;
	long _X = (X-Screen->ScreenX)+X3DO;
	
	z = _z;

	Get3DPosition( Screen, x, y, z, _X, _Y, w );
		
	x += w*((long)y)/2L/(y+(long)Screen->v);

	return this;
}

_3D_object * _3D_object::Set3DDimensions( int width, int height, int depth )
{            
	w = width;
	h = height;
	d = depth;
	
	return this;
}


_3D_object * _3D_object::Set3DOrigin( int _X3DO, int _Y3DO )
{
	X3DO = _X3DO;
	Y3DO = _Y3DO;

	return this;
}



void _3D_screen::Set3DPosition( _3D_object *o, int _z)
{
	o->Set3DPosition( this, _z );
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

		Orientation = InitBufferHeader();
		
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
                                                           
                
        //  Create a WinGDC and Bitmap, then select away

        hBuffer 	   = WinGCreateDC();
        hbm   = WinGCreateBitmap(hBuffer,
          (BITMAPINFO far *)&BufferHeader, &pBuffer);

       //  Store the old hbitmap to select back in before deleting
        gbmOldMonoBitmap   = (HBITMAP)SelectObject(hBuffer, hbm);
        

        PatBlt(hBuffer, 0,0, ScreenWidth, ScreenHeight, BLACKNESS); 
      
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

	  Object->Paint( Object->X+Scrollx, Object->Y+Scrolly, this );
	   
    }	  
    else
    {
	  Object->Paint( Object->X+Scrollx, Object->Y, this );
    }
  }	  
  else
  {
    if(Scrolly)
    {
	  Scrolly *= DELTASCROLL;

      ScreenY += Scrolly;
	                                            
	  Object->Paint( Object->X, Object->Y+Scrolly, this );
    }	  
    else
    {
	  return(false);
    }
  }  		
   
  Show(hdc);

  return(true);


}


void moveable::Move( HDC hdc, int _NewX, int _NewY, screen *Screen)
{
}    

void moveable::PlanNextPosition( void )
{
			if( IncrE != 0 )
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
            }
            else
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
	         }
};

                        
boolean moveable::FinishedMovement( void )
{
			if( IncrE != 0 )
			{            		
				return (boolean) (abs(AuxX - NewX) <= abs(DeltaX));
			}
			else
			{
				return (boolean) (abs(AuxY - NewY) <= abs(DeltaY));
			}
}                        

void _3D_object::TreatCollision( HDC hdc, _3D_screen *Screen)
{                       
    				object *OccupObj;
	
					if( Screen->Occup->OccupObject != NULL )
					{       
						OccupObj = Screen->Occup->OccupObject;
						
						if( OccupObj->y3D()+OccupObj->d3D() < y )
						{
						    OccupObj->Put( Screen );
						    OccupObj->Show( hdc, Screen );
						}  
						else
						{   
							int _X, _Y;
							
							Get2DPosition( Screen, OccupObj->x3D(), OccupObj->y3D(), OccupObj->x3D(), _X, _Y);
							
							if(	(X+X3DO > 0) && (abs(Screen->XV-(X+X3DO)) > abs(Screen->XV-_X)) )
							{
							    OccupObj->Put( Screen );
							    OccupObj->Show( hdc, Screen );
							}
						}

		               	Show( hdc, Screen );
				    	OccupObj->DrawSolid( hdc, Screen );
					}
					else
					{
	                   	Show( hdc, Screen );

						if( Screen->Occup->LastOccupObject != NULL )
						{
					    	Screen->Occup->LastOccupObject->DrawSolid( hdc, Screen );
						}

	                }

	               	DrawSolid( hdc, Screen );
	            			 
}
                    
void _3D_moveable::Move1Step( HWND hwnd, _3D_screen *Screen)
{                            
	if( Moving )
	{

			HDC hdc = GetDC(hwnd);
        	
			
			PlanNextPosition();
			
			if( CanGo( Screen ) )
			{
                   	Paint( AuxX, AuxY, Screen );

					TreatCollision(hdc, Screen);

					Screen->TestScroll(hdc, this, AuxX, AuxY);

					if( FinishedMovement() )
					{
							EndMove(hwnd, hdc, Screen);
					}
			}
			else
			{
					EndMove(hwnd, hdc, Screen);
			}

   			ReleaseDC(hwnd,hdc);
   	}
}    

void moveable::Move1Step( HWND hwnd, occup_screen *Screen)
{ 
	if( Moving )
	{

			HDC hdc = GetDC(hwnd);
        	
			
			PlanNextPosition();
			
			if( CanGo( Screen ) )
			{
                   	Paint( AuxX, AuxY, Screen );
                   	Show( hdc, Screen );
	            			 
					Screen->TestScroll(hdc, this, AuxX, AuxY);

					if( FinishedMovement() )
					{
							EndMove(hwnd, hdc, Screen);
					}
			}
			else
			{
					EndMove(hwnd, hdc, Screen);
			}

   			ReleaseDC(hwnd,hdc);
   	}
}    


void moveable::InitMove( HWND hwnd, int _NewX, int _NewY, occup_screen *Screen )
{

			DeltaX = abs(DeltaX);
			DeltaY = abs(DeltaY);
			Moving = true;

			if( _NewX + Screen->ScreenX > (Screen->BufferWidth - FrameWidth()/2) )
				NewX = (Screen->BufferWidth - FrameWidth());
			else
        		NewX = _NewX + Screen->ScreenX - (FrameWidth() /2);
        		
        		
			if( _NewY + Screen->ScreenY > (Screen->BufferHeight )) // - FrameHeight()) ) // /2) )
				NewY = (Screen->BufferHeight - FrameHeight());
			else			
            	NewY = _NewY + Screen->ScreenY - FrameHeight(); // /2;
                	
            AuxX=X;
            AuxY=Y;
                        
			DistX = (NewX - AuxX);
            DistY = (NewY - AuxY);
            
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
			else 
			if( DistY == 0 )
			{
				DistY = 1;
			}
			
			if( (DistX == 0) && (DistY == 1) ) 
			{   
				Moving = false;
				return;        
			}
				
			
			if( DistX > DistY )
			{		
				IncrE  = DistY*2;
				Dist   = IncrE - DistX;
                IncrNE = Dist - DistX;
                IncrN  = 0;
            }
            else
            {
				IncrN  = -(DistX*2);
				Dist   = DistY + IncrN;
                IncrNE = Dist + DistY;
                IncrE  = 0;
            }
                
			HDC hdc = GetDC(hwnd);

			SelectPalette(hdc,Screen->hpalApp,FALSE);
     		RealizePalette(hdc);

   			ReleaseDC(hwnd,hdc);
			
       		(*SetSystemTimer)( hwnd, Timer1, Period, NULL );
}

void moveable::InitVMove( HWND hwnd, occup_screen *Screen, MVDIR Direction )
{
			DeltaX = abs(DeltaX);
			DeltaY = abs(DeltaY);
			Moving = true;

        	NewX = X;

			if( Direction == MV_DOWN )
			{
            	NewY = Screen->BufferHeight - (FrameHeight());// /2);
        	}
        	else
			if( Direction == MV_UP )
			{
        		NewY = -FrameHeight() /2;
        	}                     
        	else 
        	{
				Moving = false;
        		return;
        	}
        	
                	
            AuxX=X;
            AuxY=Y;
                        
			DistX = 0;
            DistY = (NewY - AuxY);
            
			if( DistY < 0 ) 
			{
				DeltaY = -DeltaY;
				DistY = -DistY; 
			}               
			else 
			if( DistY == 0 )
			{
				Moving = false;
				return;        
			}
			
			IncrN  = -(DistX*2);
			Dist   = DistY + IncrN;
            IncrNE = Dist + DistY;
            IncrE  = 0;

                
			HDC hdc = GetDC(hwnd);

			SelectPalette(hdc,Screen->hpalApp,FALSE);
     		RealizePalette(hdc);

   			ReleaseDC(hwnd,hdc);
			
       		(*SetSystemTimer)( hwnd, Timer1, Period, NULL );
}


void moveable::InitHMove( HWND hwnd, occup_screen *Screen, MVDIR Direction )
{

			DeltaX = abs(DeltaX);
			DeltaY = abs(DeltaY);
			Moving = true;

			if( Direction == MV_RIGHT )
			{
        		NewX = Screen->BufferWidth - (FrameWidth()); // /2);
        	}
        	else
			if( Direction == MV_LEFT )
			{
        		NewX = -FrameWidth()/2;
        	}
        	else 
        	{
				Moving = false;
        		return;
        	}
        	
            NewY = Y;
                	
            AuxX=X;
            AuxY=Y;
                        
			DistX = (NewX - AuxX);
            DistY = 1;
            
			if( DistX < 0 ) 
			{
				DeltaX = -DeltaX;
				DistX = -DistX;
			}
			else
			if(DistX == 0) 
			{
				Moving = false;
				return;        
			}
			
			IncrE  = DistY*2;
			Dist   = IncrE - DistX;
            IncrNE = Dist - DistX;
            IncrN  = 0;
                
			HDC hdc = GetDC(hwnd);

			SelectPalette(hdc,Screen->hpalApp,FALSE);
     		RealizePalette(hdc);

   			ReleaseDC(hwnd,hdc);
			
       		(*SetSystemTimer)( hwnd, Timer1, Period, NULL );
}

void moveable::EndMove( HWND hwnd, occup_screen *Screen )
{
			HDC hdc = GetDC(hwnd);

			EndMove( hwnd, hdc, Screen );
			
   			ReleaseDC(hwnd,hdc);
}


void moveable::EndMove( HWND hwnd, HDC hdc, occup_screen *Screen )
{
			Moving = false;
			
       		(*KillSystemTimer)( hwnd, Timer1 );

			DeltaX = abs(DeltaX);
			DeltaY = abs(DeltaY);

			NewX = X;
			NewY = Y;
			                   
            Paint( NewX, NewY, Screen );
			Show( hdc, Screen );

			NewX = OldX = X;
			NewY = OldY = Y;     
		
}

void _3D_moveable::EndMove( HWND hwnd, _3D_screen *Screen )
{
			HDC hdc = GetDC(hwnd);

			EndMove( hwnd, hdc, Screen );
			
   			ReleaseDC(hwnd,hdc);
}


void _3D_moveable::EndMove( HWND hwnd, HDC hdc, _3D_screen *Screen )
{
			Moving = false;
			
       		(*KillSystemTimer)( hwnd, Timer1 );

			DeltaX = abs(DeltaX);
			DeltaY = abs(DeltaY);

			NewX = X;
			NewY = Y;
			                   
            Paint( NewX, NewY, Screen );
			TreatCollision( hdc, Screen );

			NewX = OldX = X;
			NewY = OldY = Y;     
		
}



void animated::InitAnim( HWND hwnd, occup_screen *Screen )
{
			HDC hdc = GetDC(hwnd);

			SelectPalette(hdc,Screen->hpalApp,FALSE);
     		RealizePalette(hdc);

   			ReleaseDC(hwnd,hdc);
			
       		(*SetSystemTimer)( hwnd, Timer2, Period2, NULL );
}



void animated::EndAnim( HWND hwnd, occup_screen *Screen )
{

			HDC hdc = GetDC(hwnd);

			EndAnim( hwnd, hdc, Screen );

   			ReleaseDC(hwnd,hdc);
}

void animated::EndAnim( HWND hwnd, HDC hdc, occup_screen *Screen )
{
       		(*KillSystemTimer)( hwnd, Timer2 );

            Paint( Screen );
			Show( hdc, Screen );

}


void animated::StopAnim( HWND hwnd )
{
       		(*KillSystemTimer)( hwnd, Timer2 );
}


void animated::Anim1Frame( HWND hwnd, occup_screen *Screen)
{
			HDC hdc = GetDC(hwnd);

			NextFrame();                                          
           	Paint( Screen );
           	Show( hdc, Screen );

   			ReleaseDC(hwnd,hdc);
}    


void _3D_animated::Anim1Frame( HWND hwnd, _3D_screen *Screen)
{
			HDC hdc = GetDC(hwnd);

			NextFrame();                                          
           	Paint( Screen );
			TreatCollision(hdc, Screen);
					
   			ReleaseDC(hwnd,hdc);
}    



void object_list::ReservePalette( header &BufferHeader,pal &LogicalPalette )  
{
	register int Counter, End;
	object *Object;
	RGBQUAD far * pColorTable;                          
	
	
        for( Object = FirstObject ;Object != NULL; Object = Object->Next )
        {
		
		  pColorTable = Object->pColorTable();

          for( Counter = Object->PaletteOffSet, 
          	   End = Counter+Object->NumColors; 
          	   Counter < End; Counter++)
          {
            // Reserva as cores da palette                          
            // Copia as cores do objeto  
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
                             
		}                             
}

void object_list::PutIntoBuffer( HDC hBuffer, header &BufferHeader, void far *pBuffer )  
{
		object *Object;

        for( Object = FirstObject ;Object != NULL; Object = Object->Next )
        {
                                                                    
			if( Object->IsVisible )
			{                                                                    
      // Save the background that will be erased                             
				Object->SaveBackGround( hBuffer ); 

      // Stick the object into its position in the buffer
        		Object->PutIntoBuffer( (BITMAPINFO far *)&BufferHeader, pBuffer );
    		}
    	}
}




char far * AddPointer( char far *p, long n )
{
	unsigned
	long 		 seg, off, abs;
	
	
	abs = (unsigned long) p;
	
	abs = (unsigned long) ((abs & 0xffff0000) >> 12) + (abs & 0x0000ffff);
	
	abs += n;
	
	seg = ((abs & 0xfffffff0) << 12);
	off = (abs & 0x0000000f);
	
	return (char far *) (seg & off);
	
}	 
	
