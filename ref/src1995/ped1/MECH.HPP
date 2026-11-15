class mech : public player
{
public:

	mech(void){};
	
	
	mech	(int _X, int _Y, int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[],
			int _Timer, int _Period,
			boolean _IsVisible = true, int _Layer = 0  ) :
	player( _X, _Y, _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,
			_Timer, _Period,
			_IsVisible,_Layer  )
	{		
	};                                      
	

	void InitMove( HWND hwnd, int _NewX, int _NewY, screen *Screen )
	{
	 	if( _NewX < X )       
	 	{
	 		CurrentSprite = 0;
	 	}
	 	else
	 	{
	 		CurrentSprite = 0;
	 	}
	     
	    CurrentFrame = 0;
	   
	    moveable::InitMove(hwnd,_NewX,_NewY, Screen);
	}
                           
	void EndMove( HWND hwnd, HDC hdc, screen *Screen )
	{
 		CurrentSprite = 0;
	    CurrentFrame = 0;
	   
	    moveable::EndMove(hwnd, hdc, Screen);
	}
                           

};
