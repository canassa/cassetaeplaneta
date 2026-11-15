#define _OBJECT

#include "games.hpp"
#include "event.hpp"

#include "screen.hpp"
#include "3dscreen.hpp"
#include "object.hpp"
#include "3dobject.hpp"

#include "vtree.h"

#undef _OBJECT

#include "scene.hpp"
#include "ctrpanel.hpp"
#include "applicat.hpp"


int NewName(void)
{
	static	int ObjectName = 0;
	
	return ObjectName++;
}


void object::Show( void )
{
// put the object in the bag of dirty objects of the scene
	Game->DirtyObjects.Insert(this);                                                              
};
	
void object::Show( HDC hdc, screen *Screen )
{

// put the object in the bag of dirty objects of the scene
//	Game->DirtyObjects.Insert(this);                                                              

	// Show the object
	WinGBitBlt( hdc,X-Screen->ScreenX,Y-Screen->ScreenY,
			FrameWidth(), FrameHeight(), Screen->hBuffer, X,Y); 

};


void object::Refresh( HDC hdc, screen *Screen )
{
// Show the object
	WinGBitBlt( hdc,X-Screen->ScreenX,Y-Screen->ScreenY,
			FrameWidth(), FrameHeight(), Screen->hBuffer, X,Y); 
};
	

void moveable::Show( void )
{
// put the object in the bag of dirty objects of the scene
	Game->DirtyObjects.Insert(this);                                                              
};
	

void moveable::Show( HDC hdc, screen *Screen )
{
// Restore the Background in the screen
	WinGBitBlt( hdc,OldX-Screen->ScreenX,OldY-Screen->ScreenY,
			FrameWidth(), FrameHeight(), Screen->hBuffer, OldX, OldY); 

// Show the object at the screen
	if( OldX != X || OldY != Y )
	{
		object::Show( hdc, Screen );
	}
			
//		WinGBitBlt( hdc,X-Screen->ScreenX,Y-Screen->ScreenY,
//    			FrameWidth(), FrameHeight(), Screen->hBuffer, X,Y); 

};
	
void moveable::Refresh( HDC hdc, screen *Screen )
{
// Restore the Background in the screen
	WinGBitBlt( hdc,OldX-Screen->ScreenX,OldY-Screen->ScreenY,
			FrameWidth(), FrameHeight(), Screen->hBuffer, OldX, OldY); 

// Show the object at the screen
	if( OldX != X || OldY != Y )
	{
		object::Refresh( hdc, Screen );
	}
			
//		WinGBitBlt( hdc,X-Screen->ScreenX,Y-Screen->ScreenY,
//    			FrameWidth(), FrameHeight(), Screen->hBuffer, X,Y); 

};

        
        
void object::SaveBackGround( HDC hBuffer )
{                  
//	BitBlt(hBackBuffer,0,0,FrameWidth(), 
// 			FrameHeight(), hBuffer, X, Y, SRCCOPY);	  
};

void object::RestoreBackGround( HDC hBuffer )
{
/*
  	BitBlt(hBuffer,X,Y,FrameWidth(), 
 			FrameHeight(), hBackBuffer, 0, 0, SRCCOPY);	
*/
};


void object::SaveBackGround( screen *Screen, int nBuffer )
{
/*  	PutDIBits(	(BITMAPINFO far * )&BufferHeader, pBuffer, 0, 0,
  						Screen->pBuffer,(BITMAPINFO far * )&(Screen->BufferHeader), 
  						X,Y,
  						FrameWidth(), FrameHeight()*Orientation,
  						DIB_RGB_COLORS );              
*/
//	if( nBuffer == 1 )
		SaveBackGround( Screen->hBuffer );
//	else
//		SaveBackGround( Screen->hBuffer2 );

}

void object::RestoreBackGround( screen *Screen, int nBuffer )
{
/*	if( false ) // Screen->Orientation > 0 )
	{
		PutDIBits(	(BITMAPINFO far * )&(Screen->BufferHeader), Screen->pBuffer, X, Y,
  						(void far *) (((char far *)DibPtr(Screen->pBack))+(Screen->BufferHeader.Header.biHeight-1)*WIDTHBYTES(DibWidth(Screen->pBack))),
  						DibInfo(Screen->pBack), //(BITMAPINFO far * )&(Screen->BufferHeader),  
  						X,Y,
  						FrameWidth(), FrameHeight(), // *Screen->Orientation,
  						DIB_RGB_COLORS );              
	}
	else
	{
		PutDIBits(	(BITMAPINFO far * )&(Screen->BufferHeader), Screen->pBuffer, X, Y,
  						DibPtr(Screen->pBack), DibInfo(Screen->pBack), //(BITMAPINFO far * )&(Screen->BufferHeader),  
  						X,Y,
  						FrameWidth(), FrameHeight(), // *Screen->Orientation,
  						DIB_RGB_COLORS );              
  	}
*/

/*  	BitBlt(Screen->hBuffer,X,Y,FrameWidth(), 
 			FrameHeight(), Screen->hBuffer2, X, Y, SRCCOPY);	
*/
/*  	TranspDIBits(	(BITMAPINFO far * )&(Screen->BufferHeader), 
						Screen->pBuffer, X, Y,
  						DibPtr(Screen->pBack),DibInfo(Screen->pBack),
  						X,Y,
  						FrameWidth(), FrameHeight(), // *Orientation,
  						DIB_RGB_COLORS,	TransparentColor );              
*/
  	PutDIBits(	(BITMAPINFO far * )&(Screen->BufferHeader), 
						Screen->pBuffer, X, Y,
  						DibPtr(Screen->pBack),DibInfo(Screen->pBack),
  						X,Y,
  						FrameWidth(), FrameHeight(), // *Orientation,
  						DIB_RGB_COLORS );              
/*	if( nBuffer == 1 )
		RestoreBackGround( Screen->hBuffer );
	else
		RestoreBackGround( Screen->hBuffer2 );
*/	
}

void moveable::RestoreBackGround( screen *Screen, int nBuffer )
{   
	register int left, top;
	register int width, height;
	
	if( OldX < X )
	{
		if( OldY < Y )
		{
	  		left  = OldX;
	  		top   = OldY;
		}
		else
		{
	  		left  = OldX;
	  		top   = Y;
		}
	}   
	else
	{
		if( OldY < Y )
		{
	  		left  = X;
	  		top   = OldY;
		}
		else
		{
	  		left  = X;
	  		top   = Y;
		}
	}   

/*	  		
	DirtyW = width = FrameWidth()+_DeltaX();
	DirtyH = height = FrameHeight()+_DeltaY();

	DirtyX = left-X;
	DirtyY = top-Y;
*/	        
	width = FrameWidth()+_DeltaX();
	height = FrameHeight()+_DeltaY();

	SetDirtyRect( left-X, top-Y, width, height );
		        
/*  	BitBlt(	Screen->hBuffer,  left, top, width, height, 
  			Screen->hBuffer2, left, top, SRCCOPY);	
*/
  	TranspDIBits(	(BITMAPINFO far * )&(Screen->BufferHeader), 
						Screen->pBuffer, left, top, 
  						DibPtr(Screen->pBack),DibInfo(Screen->pBack),
  						left, top, 
  						width, height, 
  						DIB_RGB_COLORS,	TransparentColor );              

}

void object::PutDirtyIntoBuffer( BITMAPINFO far * pBufferHeader, void far *pBuff )
{
/*
  	TransparentDIBits(	pBufferHeader, pBuffer, X, Y,
  						Frame(),DibInfo(pBitMap()),
  						0,0,DIB_RGB_COLORS,
						TransparentColor );              
*/      	
/*  	TranspDIBits(	pBufferHeader, pBuff, X, Y,
  						DibPtr(pBitMap()),DibInfo(pBitMap()),
  						FrameX(),FrameY(),
  						FrameWidth(), FrameHeight()*Orientation,
  						DIB_RGB_COLORS,	TransparentColor );              
*/
/*  	TranspDIBits(	pBufferHeader, pBuff, X+DirtyX, Y, //+DirtyY,
  						DibPtr(pBitMap()),DibInfo(pBitMap()),
  						FrameX()+DirtyX,FrameY(), // +DirtyY,
  						DirtyW, FrameHeight()*Orientation, // DirtyH*Orientation,
  						DIB_RGB_COLORS,	TransparentColor );              
*/
  	TranspDIBits(	pBufferHeader, pBuff, X+LastDirtyX, Y+LastDirtyY,
  						DibPtr(pBitMap()),DibInfo(pBitMap()),
  						FrameX()+LastDirtyX,FrameY()+LastDirtyY,
  						LastDirtyW, LastDirtyH*Orientation,
  						DIB_RGB_COLORS,	TransparentColor );              

};



void object::PutIntoBuffer( BITMAPINFO far * pBufferHeader, void far *pBuff )
{
/*
  	TransparentDIBits(	pBufferHeader, pBuffer, X, Y,
  						Frame(),DibInfo(pBitMap()),
  						0,0,DIB_RGB_COLORS,
						TransparentColor );              
*/      	
/*  	TranspDIBits(	pBufferHeader, pBuff, X, Y,
  						DibPtr(pBitMap()),DibInfo(pBitMap()),
  						FrameX(),FrameY(),
  						FrameWidth(), FrameHeight()*Orientation,
  						DIB_RGB_COLORS,	TransparentColor );              
*/
/*  	TranspDIBits(	pBufferHeader, pBuff, X+DirtyX, Y, //+DirtyY,
  						DibPtr(pBitMap()),DibInfo(pBitMap()),
  						FrameX()+DirtyX,FrameY(), // +DirtyY,
  						DirtyW, FrameHeight()*Orientation, // DirtyH*Orientation,
  						DIB_RGB_COLORS,	TransparentColor );              
*/
  	TranspDIBits(	pBufferHeader, pBuff, X+DirtyX, Y+DirtyY,
  						DibPtr(pBitMap()),DibInfo(pBitMap()),
  						FrameX()+DirtyX,FrameY()+DirtyY,
  						DirtyW, DirtyH*Orientation,
  						DIB_RGB_COLORS,	TransparentColor );              

};


void moveable::PutIntoBuffer( BITMAPINFO far * pBufferHeader, void far *pBuff )
{
/*
  	TransparentDIBits(	pBufferHeader, pBuffer, X, Y,
  						Frame(),DibInfo(pBitMap()),
  						0,0,DIB_RGB_COLORS,
						TransparentColor );              
*/      	
  	TranspDIBits(	pBufferHeader, pBuff, X, Y,
  						DibPtr(pBitMap()),DibInfo(pBitMap()),
  						FrameX(),FrameY(),
  						FrameWidth(), FrameHeight()*Orientation,
  						DIB_RGB_COLORS,	TransparentColor );              

};


void moveable::Paint(int _X, int _Y, screen *Screen )
{
	DesoccupScreen( Screen );
				
	SetPosition(_X,_Y);      
		
//		RestoreBackGround( Screen->hBuffer );
	RestoreBackGround( Screen,1 );

	OccupScreen( Screen );
		
	SaveBackGround( Screen ); //, 2 ); 		
//		SaveBackGround( Screen->hBuffer2 ); 		
//		SaveBackGround( Screen->hBuffer ); 		

	Put( Screen );
//	PutIntoBuffer( (BITMAPINFO far * )&(Screen->BufferHeader), 
//					Screen->pBuffer );

};


object * object::UpdatePalette( HDC hdc, screen *Screen )
{
/*    	HBITMAP hback;
    	uint nChanges =0;                                    
    	
	
    //  Retrieve the current WinGBitmap, replace with the original
    	hback = (HBITMAP)SelectObject(hBackBuffer, gBackOldMonoBitmap);
    
    //  And delete the WinGBitmap
    	DeleteObject(hback);
*/
		InCollision = false;
		InShowQueue = false;	
	

		SelectPalette(hdc,Screen->hpalApp,FALSE);
 		RealizePalette(hdc);

    	*((header *)&BufferHeader) = Screen->BufferHeader;
	
    	hpalObj = Screen->hpalApp;

        Orientation = WinGRecommendDIBFormat((BITMAPINFO far *)&BufferHeader);   

        // Creates a Buffer to save the background
        BufferHeader.Header.biWidth  = FrameWidth(); 
        BufferHeader.Header.biHeight = Sprite().NumberOfFrames*FrameHeight()*Orientation;
        
/*        pBackBuffer = NULL;
//        pBackBuffer = (void far *) &pBuffer;

        hback = WinGCreateBitmap(hBackBuffer,
        	(BITMAPINFO far *)&BufferHeader , &pBackBuffer);        	

		pBuffer = pBackBuffer = WinGGetDIBPointer( hback, NULL );
		
		if( hback == 0 )
		{
			MessageBox( "Erro Fatal !", "Não foi possível criar o BitMap do Objeto!" );
		}
		        	
        gBackOldMonoBitmap = (HBITMAP)SelectObject(hBackBuffer, hback);

      	PatBlt(	hBackBuffer, 0, 0, FrameWidth(), FrameHeight(), BLACKNESS); 
*/
		CollideObject = NULL;				

		if( !Initialized )
		{
    		Initialized = true;
			Name = NewName();
		}

		ResetDirtyRect();
	
		return this;        
};

object * object::Init( screen *Screen )
{
/*    HBITMAP hback;              
*/    
	if( !Initialized )
	{
    	Initialized = true;
		InCollision = false;
		InShowQueue = false;	
    	
    	*((header *)&BufferHeader) = Screen->BufferHeader;
    	
    	hpalObj = Screen->hpalApp;

        Orientation = WinGRecommendDIBFormat((BITMAPINFO far *)&BufferHeader);   

        // Creates a Buffer to save the background
        BufferHeader.Header.biWidth  = FrameWidth(); 
        BufferHeader.Header.biHeight = Sprite().NumberOfFrames*FrameHeight()*Orientation;
        
/*
        hBackBuffer = WinGCreateDC();
//        pBackBuffer = (void far *) &pBuffer;
        pBackBuffer = NULL;
        
        hback = WinGCreateBitmap(hBackBuffer,
        	(BITMAPINFO far *)&BufferHeader , &pBackBuffer);   

		pBuffer = pBackBuffer = WinGGetDIBPointer( hback, NULL );

		if( hback == 0 )
		{
			MessageBox( "Erro Fatal !", "Não foi possível criar o BitMap do Objeto!" );
		}
		        	
        gBackOldMonoBitmap = (HBITMAP)SelectObject(hBackBuffer, hback);

      	PatBlt(	hBackBuffer, 0, 0, FrameWidth(), FrameHeight(), BLACKNESS); 

*/      	

		ResetDirtyRect();
		
		if( IsVisible )
		{                                                                    
			Appear( Screen );
	  	}

//		Name = NewName(); movi para o constructor

		CollideObject = NULL;				
	}

	
	return this;
};

boolean object::DetectedCollision( object *o ) // , screen *Screen )
{
		if( X+BoundX()+BoundWidth() < o->X+o->BoundX() )
			return false;
			
		if( X+BoundX() > o->X+o->BoundX()+o->BoundWidth() )
			return false;
			
		if( Y+BoundY()+BoundHeight() < o->Y+o->BoundY() )
			return false;
			
		if( Y+BoundY() > o->Y+o->BoundY()+o->BoundHeight() )
			return false;
			
		return true;
}


boolean object::DetectedFrameCollision( object *o ) // , screen *Screen )
{
		if( X+FrameWidth() < o->X )
			return false;
			
		if( X > o->X+o->FrameWidth() )
			return false;
			
		if( Y+FrameHeight() < o->Y )
			return false;
			
		if( Y > o->Y+o->FrameHeight() )
			return false;
			
		return true;
}

boolean object::DetectedDirtyCollision( object *o ) // , screen *Screen )
{                           

		if( X+DirtyX+DirtyW < o->X )
			return false;
			
		if( X+DirtyX > o->X+o->FrameWidth() )
			return false;
			
		if( Y+DirtyY+DirtyH < o->Y )
			return false;
			
		if( Y+DirtyY > o->Y+o->FrameHeight() )
			return false;
                           

		if( o->X > X+DirtyX )
		{
		 	o->DirtyX = 0;
		 	LastDirtyX = o->X-X;
		}				  
		else
		{
		 	o->DirtyX = X+DirtyX-o->X;
		 	LastDirtyX = DirtyX;
		}				  
                     
		if( LastDirtyX < 0 )
		{
	 		LastDirtyX = 0;
	 	}

		if( o->Y > Y+DirtyY )
		{
		 	o->DirtyY = 0;
		 	LastDirtyY = o->Y-Y;
		}				  
		else
		{
		 	o->DirtyY = Y+DirtyY-o->Y;
		 	LastDirtyY = DirtyY;
		}				             
		
		if( LastDirtyY < 0 )
		{
	 		LastDirtyY = 0;
	 	}


		if( o->X+o->FrameWidth() > X+DirtyX+DirtyW )
		{
		 	o->DirtyW = X+DirtyX+DirtyW-o->X-o->DirtyX;
		}				  
		else
		{
		 	o->DirtyW = o->FrameWidth()-o->DirtyX;
		}				             
                              
		if( LastDirtyX+o->DirtyW > FrameWidth() )                              
		{
	 		LastDirtyW = FrameWidth()-LastDirtyX;
	 	}
	 	else
	 	{
	 		LastDirtyW = o->DirtyW;
	 	}

		if( o->Y+o->FrameHeight() > Y+DirtyY+DirtyH )
		{
		 	o->DirtyH = Y+DirtyY+DirtyH-o->Y-o->DirtyY;
		}				  
		else
		{
		 	o->DirtyH = o->FrameHeight()-o->DirtyY;
		}				             

		if( LastDirtyY+o->DirtyH > FrameHeight() )                              
		{
	 		LastDirtyH = FrameHeight()-LastDirtyY;
	 	}
	 	else
	 	{
		 	LastDirtyH = o->DirtyH;
		}
					
		return true;
}




/*	
boolean player::CanGo( occup_screen *Screen)
{
//		return Screen->CanGo( AuxX+BoundX(), AuxY+BoundY(), BoundWidth(), BoundHeight() );
	 	object * OccupObj; 
		occupation lastocc;
            
		return (boolean) (Screen->Occup->Occupation(AuxX+BoundX(), AuxY+BoundY(), BoundWidth(), BoundHeight(), OccupObj, lastocc) == FREE );
};
*/
boolean moveable::CanGo( screen *Screen)
{
//		return Screen->CanGo( AuxX+BoundX(), AuxY+BoundY(), BoundWidth(), BoundHeight() );

	 	object * OccupObj; 
		occupation occ, lastocc;
            
		occ = Screen->Occupation(AuxX+BoundX(), AuxY+BoundY(), BoundWidth(), BoundHeight(), OccupObj, lastocc);
			
		CollideObject = OccupObj;

		if( occ > FREE )
		{
			if( lastocc != WALL )
			{
				if( OccupObj != NULL )
				{
					if( OccupObj->Name == Name )
					{   
						CollideObject = NULL;
						return true; // (boolean) (lastocc == FREE);
					}
					else
					{
						return false; 	// procurar quais os objetos que ocupam a posicão e
										// verificar se algum colide com this.
					}
                }
                else
                {
					return true; // (boolean) (lastocc == FREE);
                }
            }
            else
            {
				CollideObject = NULL;
            	return false;
            }
		}
		else                    
		{
			CollideObject = NULL;
			return (boolean) (occ == FREE);
		}

};


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

void moveable::Move1Step( HWND hwnd, screen *Screen)
{ 
	if( Moving )
	{

			HDC hdc = GetDC(hwnd);
        	
			
			PlanNextPosition();
			
			if( CanGo( Screen ) )
			{
					ResetDirtyRect();                                      
       				Paint( AuxX, AuxY, Screen );
                 	TreatCollision( hdc, Screen );
//				   	Show( hdc, Screen );
				   	Show();
	            			 
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
                    

void object::TreatCollision( HDC hdc, screen *Screen, boolean SelfRefr )
{                       
	if( CollideObject != NULL )
	{       
		    CollideObject->Put( Screen );
//		    CollideObject->Show( hdc, Screen );
		    CollideObject->Show();
	}
	            			 
};
  
/*  
void moveable::TreatCollision( HDC hdc, occup_screen *Screen)
{                       
	object *OccupObj;
	
	if( CollideObject != NULL && 
		CollideObject->IsMoving() )
	{       
        int Left, Right, Up, Down;
		
		OccupObj = CollideObject;
		
		if( OccupObj->X < AuxX )
		{
		 	Left = AuxX;
		}                      
		else
		{
			Left = OccupObj->X;
		}
		
		if( OccupObj->X+OccupObj->FrameWidth() > AuxX+FrameWidth() )
		{
		 	Right = AuxX+FrameWidth();
		}                      
		else
		{
			Right = OccupObj->X+OccupObj->FrameWidth();
		}
		
		if( OccupObj->Y < AuxY )
		{
		 	Up = AuxY;
		}                      
		else
		{
			Up = OccupObj->Y;
		}
		
		if( OccupObj->Y+OccupObj->FrameHeight() > AuxY+FrameHeight() )
		{
		 	Down = AuxY+FrameHeight();
		}                      
		else
		{
			Down = OccupObj->Y+OccupObj->FrameHeight();
		}
		
		if( Down > Up && Left < Right ) // collision in fact
		{

			BitBlt(hBackBuffer,Left-AuxX,Up-AuxY,Right-Left,Down-Up, 
    	 			OccupObj->hBackBuffer, Left-OccupObj->X, Up-OccupObj->Y, SRCCOPY);	

			Put( Screen );        	

		}

	}
}
*/                    


                    

void moveable::InitMove( HWND hwnd, int _NewX, int _NewY, screen *Screen )
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
                
/*			HDC hdc = GetDC(hwnd);

			SelectPalette(hdc,Screen->hpalApp,FALSE);
     		RealizePalette(hdc);

   			ReleaseDC(hwnd,hdc);
*/			
       		(*SetSystemTimer)( hwnd, Timer1, Period, NULL );
}

void moveable::InitVMove( HWND hwnd, screen *Screen, MVDIR Direction )
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

                
/*			HDC hdc = GetDC(hwnd);

			SelectPalette(hdc,Screen->hpalApp,FALSE);
     		RealizePalette(hdc);

   			ReleaseDC(hwnd,hdc);
*/			
       		(*SetSystemTimer)( hwnd, Timer1, Period, NULL );
}


void moveable::InitHMove( HWND hwnd, screen *Screen, MVDIR Direction )
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
                
/*			HDC hdc = GetDC(hwnd);

			SelectPalette(hdc,Screen->hpalApp,FALSE);
     		RealizePalette(hdc);

   			ReleaseDC(hwnd,hdc);
*/			
       		(*SetSystemTimer)( hwnd, Timer1, Period, NULL );
}

void moveable::EndMove( HWND hwnd, screen *Screen )
{
			HDC hdc = GetDC(hwnd);

			EndMove( hwnd, hdc, Screen );
			
   			ReleaseDC(hwnd,hdc);
}


void moveable::EndMove( HWND hwnd, HDC hdc, screen *Screen )
{
			Moving = false;
			
       		(*KillSystemTimer)( hwnd, Timer1 );

			DeltaX = abs(DeltaX);
			DeltaY = abs(DeltaY);
/*
			NewX = X;
			NewY = Y;
			                   
            Paint( NewX, NewY, Screen );
//			Show( hdc, Screen );
			Show();
*/
			NewX = OldX = X;
			NewY = OldY = Y;     

       		PostMessage( hwnd, WM_ENDMOVE, Name, NULL );
		
}

void animated::InitAnim( HWND hwnd, screen *Screen )
{
/*			HDC hdc = GetDC(hwnd);

			SelectPalette(hdc,Screen->hpalApp,FALSE);
     		RealizePalette(hdc);

   			ReleaseDC(hwnd,hdc);
*/			
			Animating = true;
			
			_1SpriteAnim = false;

       		(*SetSystemTimer)( hwnd, Timer2, Period2, NULL );
}

void animated::Init1SpriteAnim( HWND hwnd, screen *Screen )
{
/*			HDC hdc = GetDC(hwnd);

			SelectPalette(hdc,Screen->hpalApp,FALSE);
     		RealizePalette(hdc);

   			ReleaseDC(hwnd,hdc);
*/			
			Animating = true;
 
			FrameCounter = NumberOfFrames()-!EndsAtFirstFrame;
			_1SpriteAnim = true;
			
       		(*SetSystemTimer)( hwnd, Timer2, Period2, NULL );
}




void animated::EndAnim( HWND hwnd, screen *Screen )
{
			HDC hdc = GetDC(hwnd);

			EndAnim( hwnd, hdc, Screen );

   			ReleaseDC(hwnd,hdc);
}

void animated::EndAnim( HWND hwnd, HDC hdc, screen *Screen )
{
/*			Animating = false;
			_1SpriteAnim = false;

       		(*KillSystemTimer)( hwnd, Timer2 );
*/
			StopAnim( hwnd );
			
            Paint( Screen );
//			Show( hdc, Screen );
			Show();

}


void animated::StopAnim( HWND hwnd )
{
			Animating = false;
			_1SpriteAnim = false;
       		
       		PostMessage( hwnd, WM_ENDANIM, Name, NULL );

       		(*KillSystemTimer)( hwnd, Timer2 );
       		
}


void animated::Anim1Frame( HWND hwnd, screen *Screen)
{
//	HDC hdc = GetDC(hwnd);

	NextFrame();                                          
	ResetDirtyRect();                                      
   	Paint( Screen );
//	Show( hdc, Screen );
	Show();

	if( _1SpriteAnim )
	{
		if( --FrameCounter == 0 )
		{
			StopAnim(hwnd);		
		}
	}

//	ReleaseDC(hwnd,hdc);
}    



void player::Put( screen *Screen )
{
	actor::Put( Screen );
}


void player::Anim1Frame( HWND hwnd, screen *Screen )
{
	actor::Anim1Frame( hwnd, Screen );
}

void player::Move1Step( HWND hwnd, screen *Screen )
{
	actor::Move1Step( hwnd, Screen );

	PostMessage( hwnd, WM_PLAYERMOVE, Name, (((long)Y)<<16) & ((long)X) );
}





boolean object_list::Contains( object *Object )
{
	return (boolean) (Object->List == this);
}

object_list *object_list::Insert( object *Object )
{
	if( !Contains( Object ) )
	{
		if( FirstObject == NULL )		
		{
			FirstObject = Object;
			FirstObject->Next = FirstObject->Prev = NULL;
			
			Object->List = this;
			NumObjects++;
		}
		else
		if( NumObjects < MaxObjects )
		{	
			Object->Next = FirstObject;
			Object->Prev = NULL;
			
			FirstObject->Prev = Object;
			FirstObject = Object;
			
			Object->List = this;
			
			NumObjects++;
		}               
	}
		
	return this;
}

object_list * object_list::Exclude( object *Object )
{
	if( Contains( Object ) )
	{
		if( Object->Prev == NULL )		
		{
			FirstObject = Object->Next;
			
			if( FirstObject != NULL )
			{
				FirstObject->Prev = NULL;
			}
		}
		else
		{	
			Object->Prev->Next = Object->Next;

			if( Object->Next != NULL )
			{
				Object->Next->Prev = Object->Prev;
			}
		}
			
		Object->Prev = 
		Object->Next = NULL;
		Object->List = NULL;

		NumObjects--;
	}   
		
	return this;
}



void object_list::FreeAll( void )
{
	object *Object;
	              
	if( !IsEmpty() )
	{        
		Object = FirstObject->Next; 

		while( FirstObject != NULL  )
		{
		 	delete FirstObject;
		 	FirstObject = Object; 

			if( Object != NULL )
			{
			 	Object = Object->Next;
			}
		}	
		
		NumObjects = 0;
	}
}


void object_list::Restore(screen *Screen)
{
	object *Object;
	
	for( Object = FirstObject; Object != NULL; Object = Object->Next )
	{
	 	Object->Restore( Screen );
	}	
}

void object_list::Put(screen *Screen)		
{
	object *Object;
	
	for( Object = FirstObject; Object != NULL; Object = Object->Next )
	{
	 	Object->Put( Screen );
	}	
}


void object_list::Init( scene *Scene )		
{
	object *Object;
	_3D_object *_3DObject;
	
	for( Object = FirstObject; Object != NULL; Object = Object->Next )
	{       
		_3DObject = Object->To3DObject();

		if( _stricmp( Scene->Name, Object->SceneName() ) == 0 )
		{                
			if( _3DObject == NULL )
			{
	 			Object->Init( Scene->Screen );
	 			Object->Set3DPosition( Scene->Screen );
	 			Object->Appear( Scene->Screen );
			}
			else
			{
//				if( _3DObject->IsPortable() )
				{
		 			_3DObject->Init( Scene->Screen );
		 			_3DObject->Set3DPosition( Scene->Screen, _3DObject->z );
	 				_3DObject->Appear( Scene->Screen );
	 			}
			}

			Game->VisibleObjects.Insert( _3DObject, Scene->Screen );

 		}  
 		else
 		{
			Game->VisibleObjects.Extract( _3DObject );
 		 	Object->IsVisible = false;
 		}

	}	
}




	
/*
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


*/

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

