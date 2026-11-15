class tommy : public _3D_player
{
public:

	tommy(void){};
	
	
	tommy	(int _X, int _Y, int _NumberOfSprites, 
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
	


	virtual void InitAnim( HWND hwnd, _3D_screen *Screen, MVDIR Direction  )
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

                           
	virtual void InitAnimP( HWND hwnd, _3D_screen *Screen )
	{
// 		CurrentSprite = 3;
//	    CurrentFrame = 0;
		SetCurrentSprite(hwnd, Screen, 3);

	    _3D_player::InitAnim(hwnd, Screen);
	}
                           

/*	virtual void EndAnim( HWND hwnd, HDC hdc, _3D_screen *Screen )
	{
// 		CurrentSprite = 0;
//	    CurrentFrame = 0;
		SetCurrentSprite(hwnd, Screen, 0);
	   
	    _3D_player::EndAnim(hwnd, hdc, Screen);
	}
                           
	virtual void EndAnim( HWND hwnd, _3D_screen *Screen )
	{
	   
		HDC hdc = GetDC(hwnd);

	    EndAnim(hwnd, hdc, Screen);
	    
	    ReleaseDC(hwnd, hdc);

	}
*/                           
	virtual void InitMove( HWND hwnd, int _NewX, int _NewY, _3D_screen *Screen )
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
                           
	virtual void InitHMove( HWND hwnd, _3D_screen *Screen, MVDIR Direction )
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
                           
	virtual void InitVMove( HWND hwnd, _3D_screen *Screen, MVDIR Direction )
	{
		StopAnim( hwnd );

	 	if( Direction == MV_DOWN )       
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
	   
	    _3D_player::InitVMove(hwnd, Screen, Direction);
	    
	    if( !Moving )
	    {
			InitAnimP(hwnd, Screen);
	    }
	}
                           
	virtual void EndMove( HWND hwnd, HDC hdc, _3D_screen *Screen )
	{
// 		CurrentSprite = 0;
//	    CurrentFrame = 0;
		SetCurrentSprite(hwnd, Screen, 0);
	   
	    _3D_player::EndMove(hwnd, hdc, Screen);

		InitAnimP(hwnd, Screen);
	}

	virtual void EndMove( HWND hwnd, _3D_screen *Screen )
	{
		HDC hdc = GetDC(hwnd);

	    EndMove(hwnd, hdc, Screen);
	    
	    ReleaseDC(hwnd, hdc);
	}
                           
/*	virtual void Move1Step( HWND hwnd, _3D_screen *Screen)
	{                            
		if( Moving )
		{

			NextFrame();

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
	};

*/
/*	virtual void Anim1Frame( HWND hwnd, _3D_screen *Screen)
	{
			HDC hdc = GetDC(hwnd);

			NextFrame();                                          
           	_3D_object::Paint( Screen );
			TreatCollision(hdc, Screen);
					
   			ReleaseDC(hwnd,hdc);
	}    
*/


};




class tommy_screen : public _3D_screen
{                          
public:
	screen *Init( HWND hwnd )
	{                         
		register int i,j,k;
		
	 	_3D_screen::Init(hwnd);
	 	
		for( i = 0; i < 5; i++ )
		{
		 	for( j = 0; j < 40; j++ )
		 	{
		 		Occup->SetOccup( i, j, WALL );
		 	}
		}   
		    
		
		    
		for( i = 5, k = 8; i < 8; i++, k-=3 )
		{                 
		 	for( j = 0; j < k; j++ )
		 	{
		 		Occup->SetOccup( i, j, WALL );
		 	}
		}   
		

		return this;
	
	}
						
	tommy_screen( char *BackName, 
			int	_ScreenX = 0, int _ScreenY = 0, 
			int _ScreenWidth = 640, int _ScreenHeight = 480 ) :
	_3D_screen( BackName, 
			_ScreenX, _ScreenY, 
			_ScreenWidth,_ScreenHeight )
	{
			                    
	};
	
};
