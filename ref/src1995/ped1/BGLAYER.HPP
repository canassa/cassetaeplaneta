
class bg_layer : public _3D_moveable
{
public:
	bg_layer(void) {};

	bg_layer(int _X, int _Y,  
			char *BMPName, int BMPFrames, 
			int BMPWidth, int BMPHeight,
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			int _Timer, int _Period,
			int _DeltaX, int _DeltaY  ) :
	_3D_moveable( _X, _Y, 1,
			&BMPName, &BMPFrames, 
			&BMPWidth, &BMPHeight,              
			_BoundX, _BoundY, 
			_BoundWidth, _BoundHeight, 
			_Timer, _Period,
			_DeltaX, _DeltaY )
	{
	};
	
	
	void Scroll( MVDIR Direction )
	{
	 	if( Direction & MV_UP )
	 	{
 	 		Y -= DeltaY;
	 	}
	 	else
	 	if( Direction & MV_DOWN )
	 	{
 	 		Y += DeltaY;
	 	}          

 	 	if( Direction & MV_LEFT )
 	 	{              
 	 		X -= DeltaX;
 	 	}
 	 	else
 	 	if( Direction & MV_RIGHT )
 	 	{              
 	 		X += DeltaX;
 	 	}      

	};

    virtual void OccupScreen( screen *Screen )
    {
    };
		
    virtual void DesoccupScreen( screen *Screen )
    {
    };
	

	virtual void Show( HDC hdc, screen *Screen )
	{
		// Show the screen
		
		Screen->Show(hdc);
	};
	
	
	virtual void Refresh( HDC hdc, screen *Screen )
	{
		// Show the screen
		
		Screen->Show(hdc);
	};
		
	
	virtual void Show( void )
	{
	// put the object in the bag of dirty objects of the scene
	//	Game->DirtyObjects.Insert(this);                                                              
	};
		
	
	
	
	virtual void RestoreBackGround( screen *Screen, int nBuffer = 1 )
	{                                     
		Screen->Restore();
/*	  	BitBlt(Screen->hBuffer,0,0,Screen->BufferWidth, 
	 			Screen->BufferHeight, Screen->hBuffer2, 0, 0, SRCCOPY);	
*/
	}
	
	
	virtual void PutIntoBuffer( BITMAPINFO far * pBufferHeader, void far *pBuff )
	{
		if( X <= 0 )
		{
			if( Y <= 0 )
			{
				  	TranspDIBits(	pBufferHeader, pBuff, 0, 0, //+DirtyY,
				  					DibPtr(pBitMap()),DibInfo(pBitMap()),
									-X,-Y,
			  						FrameWidth(), FrameHeight()*Orientation,
			  						DIB_RGB_COLORS,	TransparentColor );              
			}
			else
			{
				  	TranspDIBits(	pBufferHeader, pBuff, 0, Y, //+DirtyY,
				  					DibPtr(pBitMap()),DibInfo(pBitMap()),
									-X, 0,
			  						FrameWidth(), FrameHeight()*Orientation,
			  						DIB_RGB_COLORS,	TransparentColor );              
			}
	  	}
	  	else
	  	{
			if( Y <= 0 )
			{
				  	TranspDIBits(	pBufferHeader, pBuff, X, 0, //+DirtyY,
				  					DibPtr(pBitMap()),DibInfo(pBitMap()),
									0,-Y,
			  						FrameWidth(), FrameHeight()*Orientation,
			  						DIB_RGB_COLORS,	TransparentColor );              
			}
			else
			{
				  	TranspDIBits(	pBufferHeader, pBuff, X, Y, //+DirtyY,
				  					DibPtr(pBitMap()),DibInfo(pBitMap()),
									0, 0,
			  						FrameWidth(), FrameHeight()*Orientation,
			  						DIB_RGB_COLORS,	TransparentColor );              
			}
			
	  	}
	
	};
	
	
	virtual void Paint(int _X, int _Y, screen *Screen )
	{
		SetPosition(_X,_Y);      
			
		RestoreBackGround( Screen );
	
		PutIntoBuffer( (BITMAPINFO far * )&(Screen->BufferHeader), 
						Screen->pBuffer );
	};
	
	
	virtual void Paint(screen *Screen )
	{
		RestoreBackGround( Screen );
	
		PutIntoBuffer( (BITMAPINFO far * )&(Screen->BufferHeader), 
						Screen->pBuffer );
	};
	
	
};