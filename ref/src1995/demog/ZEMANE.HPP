

class zemane : public _3D_player
{
public:

	zemane(void){};
	
	
	zemane	(int _X, int _Y, int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[],
			int _BoundX, int _BoundY, 
			int _BoundWidth, int _BoundHeight, 
			int _Timer, int _Period,
			int _DeltaX, int _DeltaY,
			boolean _IsVisible = true, int _Layer = 0  ) :
	_3D_player( _X, _Y, _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,
			_BoundX, _BoundY, 
			_BoundWidth, _BoundHeight, 
			_Timer, _Period,
			_DeltaX, _DeltaY,
			_IsVisible,_Layer  )
	{		
	};                                      
	


	virtual void InitAnim( HWND hwnd, screen *Screen, MVDIR Direction  )
	{
	 	if( Direction == MV_RIGHT )       
	 	{
//	 		CurrentSprite = 1;
			SetCurrentSprite(hwnd, Screen, 1);
	 	}
	 	else
	 	{
//	 		CurrentSprite = 2;
			SetCurrentSprite(hwnd, Screen, 2);
	 	}
	     
//	    CurrentFrame = 0;
	   
	    _3D_player::InitAnim(hwnd, Screen);
	}

                           
	virtual void InitAnimP( HWND hwnd, screen *Screen )
	{
// 		CurrentSprite = 3;
//	    CurrentFrame = 0;
		SetCurrentSprite(hwnd, Screen, 3);

	    _3D_player::InitAnim(hwnd, Screen);
	}
                           

	virtual void InitMove( HWND hwnd, int _NewX, int _NewY, screen *Screen )
	{
		StopAnim( hwnd );

	 	if( Screen->ScreenX+_NewX-FrameWidth()/2 < X )       
	 	{
//	 		CurrentSprite = 2;
			SetCurrentSprite(hwnd, Screen, 2);
	 	}
	 	else
	 	{
//	 		CurrentSprite = 1;
			SetCurrentSprite(hwnd, Screen, 1);
	 	}
	     
//	    CurrentFrame = 0;
	   
	    _3D_player::InitMove(hwnd,_NewX,_NewY, Screen);

	    if( !Moving )
	    {
			InitAnimP(hwnd, Screen);
	    }
	}
                           
	virtual void InitHMove( HWND hwnd, screen *Screen, MVDIR Direction )
	{
		StopAnim( hwnd );

	 	if( Direction == MV_RIGHT )       
	 	{
//	 		CurrentSprite = 1;
			SetCurrentSprite(hwnd, Screen, 1);
	 	}
	 	else
	 	{
//	 		CurrentSprite = 2;
			SetCurrentSprite(hwnd, Screen, 2);
	 	}
	     
//	    CurrentFrame = 0;
	   
	    _3D_player::InitHMove(hwnd, Screen, Direction);

	    if( !Moving )
	    {
			InitAnimP(hwnd, Screen);
	    }
	}
                           
	virtual void InitVMove( HWND hwnd, screen *Screen, MVDIR Direction )
	{
		StopAnim( hwnd );

	 	if( Direction == MV_DOWN )       
	 	{
//	 		CurrentSprite = 1;
			SetCurrentSprite(hwnd, Screen, 3);
	 	}
	 	else
	 	{
//	 		CurrentSprite = 2;
			SetCurrentSprite(hwnd, Screen, 4);
	 	}
	     
//	    CurrentFrame = 0;
	   
	    _3D_player::InitVMove(hwnd, Screen, Direction);
	    
	    if( !Moving )
	    {
			InitAnimP(hwnd, Screen);
	    }
	}
                           
	virtual void EndMove( HWND hwnd, HDC hdc, screen *Screen )
	{
	   
	    _3D_player::EndMove(hwnd, hdc, Screen);

		InitAnimP(hwnd, Screen);
	}

	virtual void EndAnim( HWND hwnd, HDC hdc, screen *Screen )
	{
	    _3D_player::EndAnim(hwnd, hdc, Screen);

		InitAnimP(hwnd, Screen);
	}


	virtual void EndAnim( HWND hwnd, screen *Screen )
	{
	   
		HDC hdc = GetDC(hwnd);

	    EndAnim(hwnd, hdc, Screen);
	    
	    ReleaseDC(hwnd, hdc);

	}
                           
};


