
#ifdef _3DOBJECT
	#define	DECLARE
#else
	#define DECLARE extern
#endif        


void Get3DPosition( screen *Screen, int &x, int &y, int z, int X, int Y, int w = 0 );
void Get2DPosition( screen *Screen, int x, int y, int z, int &X, int&Y, int w = 0 );


class _3D_object : virtual public object
{

public:
	
	int x,y,z; // 3D coordinates
	
	int w,h,d; // 3D dimensions in pixels
	
	int X3DO, Y3DO; // Position of the 3D origin in the frame. The Botton-Left-Front corner.

	object *UnderObj; // The object that is under this.

	virtual int x3D(void); // { return x; };
	virtual int y3D(void); // { return y; };
	virtual int z3D(void); // { return z; };
	virtual int w3D(void); // { return w; };
	virtual int h3D(void); // { return h; };
	virtual int d3D(void); // { return d; };
        
	virtual int X3DOrg(void) { return X3DO; };
	virtual int Y3DOrg(void) { return Y3DO; };

	virtual int z03D(void) { return 0; };

    virtual boolean Is3DObject(void) { return true; };
    virtual _3D_object *To3DObject(void) { return this; };

	virtual int Find_z( screen *Screen, object * &OccupObj );

	virtual boolean IsOn( object *Object, screen *Screen );
	virtual boolean IsOver( object *o, screen *Screen );
	virtual boolean IsCloserThan( _3D_object* OccupObj, screen *Screen );
	
	virtual void TreatCollision( HDC hdc, screen *Screen, boolean SelfRefr = true );
	virtual boolean DetectedCollision( object *o, screen *Screen );
	
	virtual object *Init( screen *Screen );

    virtual void SetPosition(int _X, int _Y, screen *Screen, int _z);
    virtual void SetPosition(int _X, int _Y, screen *Screen );
    

	virtual object *Set3DPosition( screen *Screen, int _z ); // Determines the 3D position from the 2D ones.
	virtual object *Set3DPosition( screen *Screen ); // Determines the 3D position from the 2D ones.

	virtual object *Set3DOrigin( int _X3DO, int _Y3DO );
	virtual object *Set3DDimensions( int width, int height, int depth );
        
	virtual object * DrawSolid( HWND hwnd, screen *Screen );
	virtual object * DrawSolid( HDC hdc, screen *Screen );

//	virtual object *SetZ0( int _z0 ) { return this; };                                                
	


    _3D_object(void) {};
    
	_3D_object(int _X, int _Y, int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[],
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			int _Timer, int _Period,
			boolean _IsVisible = true, int _Layer = 0  ) 
/*			:
	object( _X, _Y, _NumberOfSprites, 		// não funciona devido ao virtual na heranca
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,
			_IsVisible,_Layer  )
*/ 
	{
		InitAnimated( _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight, 
			_BoundX, _BoundY, 
			_BoundWidth, _BoundHeight);

		InitMoveable( 	_X, _Y, 
						_IsVisible,_Layer  );


		w = h = d = 0;                   
    	UnderObj = NULL;
	};

	_3D_object(int _X, int _Y, int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[],
			int _Timer, int _Period,
			boolean _IsVisible = true, int _Layer = 0  ) 
/*			:
	object( _X, _Y, _NumberOfSprites, 		// não funciona devido ao virtual na heranca
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,
			_IsVisible,_Layer  )
*/ 
	{

		InitAnimated( _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight);

		InitMoveable( 	_X, _Y, 
						_IsVisible,_Layer  );

		w = h = d = 0;                   
    	UnderObj = NULL;

	};
        

	_3D_object(int _X, int _Y, 
			char *BMPName, int BMPFrames, 
			int BMPWidth, int BMPHeight,
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			boolean _IsVisible = true, int _Layer = 0  ) 
/*			:
	object( _X, _Y, _NumberOfSprites, 		// não funciona devido ao virtual na heranca
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,
			_IsVisible,_Layer  )
*/ 
	{
		InitAnimated( 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight, 
			_BoundX, _BoundY, 
			_BoundWidth, _BoundHeight);

		InitMoveable( 	_X, _Y, 
						_IsVisible,_Layer  );


		w = h = d = 0;                   
    	UnderObj = NULL;

	};

	_3D_object( int _X, int _Y, 
			char *BMPName, int _NumberOfFrames, 
			int BMPWidth, int BMPHeight,
			boolean _IsVisible = true, int _Layer = 0  )
/*			:
	object( _X, _Y, _NumberOfSprites, 		// não funciona devido ao virtual na heranca
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,
			_IsVisible,_Layer  )
*/ 
	{
		InitAnimated( 
			BMPName, _NumberOfFrames, 
			BMPWidth, BMPHeight);

		InitMoveable( 	_X, _Y, 
						_IsVisible,_Layer  );


		w = h = d = 0;                   
    	UnderObj = NULL;

	};
        
	_3D_object(int _X, int _Y, int _NumberOfSprites, 
			int _Timer, int _Period,
			boolean _IsVisible = true, int _Layer = 0  ) 
/*			:
	object( _X, _Y, _NumberOfSprites, 		// não funciona devido ao virtual na heranca
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,
			_IsVisible,_Layer  )
*/ 
	{

		InitAnimated( _NumberOfSprites );

		InitMoveable( 	_X, _Y, 
						_IsVisible,_Layer  );

		w = h = d = 0;                   
    	UnderObj = NULL;

	};
        


	_3D_object(int _Name, int _X, int _Y, 
			char *BMPName, 
			int BMPWidth, int BMPHeight,
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			boolean _IsVisible = true, int _Layer = 0  ) 
/*			:
	object( _X, _Y, _NumberOfSprites, 		// não funciona devido ao virtual na heranca
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,
			_IsVisible,_Layer  )
*/ 
	{
		InitAnimated( 
			BMPName, 1, 
			BMPWidth, BMPHeight, 
			_BoundX, _BoundY, 
			_BoundWidth, _BoundHeight);

		InitMoveable( 	_X, _Y, 
						_IsVisible,_Layer  );

        Name = _Name;
		w = h = d = 0;                   
    	UnderObj = NULL;

	};


        
};


class _3D_animated : public animated, virtual public _3D_object
{
public:
	_3D_animated(void) {};

	_3D_animated(int _X, int _Y, int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[],
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			int _Timer, int _Period, boolean _EndsAtFirstFrame = true,
			boolean _IsVisible = true, int _Layer = 0  ) :
	animated( _X, _Y,  _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,             
			_BoundX, _BoundY, 
			_BoundWidth, _BoundHeight, 
			_Timer, _Period,_EndsAtFirstFrame,
			_IsVisible,_Layer  )
	{

		w = h = d = 0;                   
    	UnderObj = NULL;

	};

	
	_3D_animated(int _X, int _Y, 
			char *BMPName, int BMPFrames, 
			int BMPWidth, int BMPHeight,
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			int _Timer, int _Period, boolean _EndsAtFirstFrame = true,
			boolean _IsVisible = true, int _Layer = 0  ) :
	animated( _X, _Y,  1, 
			&BMPName, &BMPFrames, 
			&BMPWidth, &BMPHeight,             
			_BoundX, _BoundY, 
			_BoundWidth, _BoundHeight, 
			_Timer, _Period,_EndsAtFirstFrame,
			_IsVisible,_Layer  )
	{

		w = h = d = 0;                   
    	UnderObj = NULL;

	};

	_3D_animated(int _X, int _Y, int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[],
			int _Timer, int _Period, boolean _EndsAtFirstFrame = true,
			boolean _IsVisible = true, int _Layer = 0  ) :
	animated( _X, _Y,  _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,             
			_Timer, _Period,_EndsAtFirstFrame,
			_IsVisible,_Layer  )
	{

		w = h = d = 0;                   
    	UnderObj = NULL;

	};

	_3D_animated(int _X, int _Y, int _NumberOfSprites, 
			int _Timer, int _Period, boolean _EndsAtFirstFrame = true,
			boolean _IsVisible = true, int _Layer = 0  ) :
	animated( _X, _Y,  _NumberOfSprites, 
			_Timer, _Period,_EndsAtFirstFrame,
			_IsVisible,_Layer  )
	{

		w = h = d = 0;                   
    	UnderObj = NULL;

	};

	_3D_animated(int _Name, int _X, int _Y, 
			char *BMPName, int BMPFrames, 
			int BMPWidth, int BMPHeight,
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			int _Timer, int _Period, boolean _EndsAtFirstFrame = true,
			boolean _IsVisible = true, int _Layer = 0  ) :
	animated( _X, _Y,  1, 
			&BMPName, &BMPFrames, 
			&BMPWidth, &BMPHeight,             
			_BoundX, _BoundY, 
			_BoundWidth, _BoundHeight, 
			_Timer, _Period,_EndsAtFirstFrame,
			_IsVisible,_Layer  )
	{
        Name = _Name;
		w = h = d = 0;                   
    	UnderObj = NULL;

	};


	
	virtual void Anim1Frame( HWND hwnd, screen *Screen);

	virtual void InitAnim( HWND hwnd, screen *Screen ) 
	{
		animated::InitAnim( hwnd, Screen );
	};

	virtual void EndAnim( HWND hwnd, screen *Screen ) 
	{
		animated::EndAnim( hwnd, Screen );
	};

	virtual void EndAnim( HWND hwnd, HDC hdc, screen *Screen ) 
	{
		animated::EndAnim( hwnd, hdc, Screen );
	};

	virtual void Paint( screen *Screen )
	{
		animated::Paint(Screen);
	};

	virtual void Appear( screen *Screen )
	{
	 	CurrentFrame = 0;
		animated::Appear(Screen);
	};

	virtual int NextFrame(void)  // operator ++
	{             
		return animated::NextFrame();
	};	                          
	
	virtual int PreviousFrame(void)
	{
		return animated::PreviousFrame();
	};

	virtual void StopAnim( HWND hwnd )
	{
		animated::StopAnim(hwnd);
	}

	virtual int Timer(void)
	{
		return animated::Timer();
	};


};



class _3D_moveable : public moveable, virtual public _3D_object
{
public:
	_3D_moveable(void) {};

	_3D_moveable(int _X, int _Y, int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[],
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			int _Timer, int _Period,
			int _DeltaX, int _DeltaY,
			boolean _IsVisible = true, int _Layer = 0  ) :
	moveable( _X, _Y,  _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,
			_BoundX, _BoundY, 
			_BoundWidth, _BoundHeight, 
			_Timer, _Period,
			_DeltaX, _DeltaY,
			_IsVisible,_Layer  )
	{

		w = h = d = 0;                   
    	UnderObj = NULL;

	};
	
	_3D_moveable(int _X, int _Y, 
			char *BMPName, int BMPFrames, 
			int BMPWidth, int BMPHeight,
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			int _Timer, int _Period,
			int _DeltaX, int _DeltaY,
			boolean _IsVisible = true, int _Layer = 0  ) :
	moveable( _X, _Y,  1,
			&BMPName, &BMPFrames, 
			&BMPWidth, &BMPHeight,
			_BoundX, _BoundY, 
			_BoundWidth, _BoundHeight, 
			_Timer, _Period,
			_DeltaX, _DeltaY,
			_IsVisible,_Layer  )
	{

		w = h = d = 0;                   
    	UnderObj = NULL;

	};
	
	_3D_moveable(int _X, int _Y, int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[],
			int _Timer, int _Period,
			int _DeltaX, int _DeltaY,
			boolean _IsVisible = true, int _Layer = 0  ) :
	moveable( _X, _Y,  _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,
			_Timer, _Period,
			_DeltaX, _DeltaY,
			_IsVisible,_Layer  )
	{

		w = h = d = 0;                   
    	UnderObj = NULL;

	};
	
	_3D_moveable(int _X, int _Y, int _NumberOfSprites, 
			int _Timer, int _Period,
			int _DeltaX, int _DeltaY,
			boolean _IsVisible = true, int _Layer = 0  ) :
	moveable( _X, _Y,  _NumberOfSprites, 
			_Timer, _Period,
			_DeltaX, _DeltaY,
			_IsVisible,_Layer  )
	{

		w = h = d = 0;                   
    	UnderObj = NULL;

	};
	


	virtual object *Init( screen *Screen );
	
	virtual boolean CanGo( screen *Screen );

	virtual object *Set3DPosition( screen *Screen, int _z ); // Determines the 3D position from the 2D ones.
	virtual object *Set3DPosition( screen *Screen ); // Determines the 3D position from the 2D ones.

    virtual void SetPosition(int _X, int _Y, screen *Screen, int _z);
    virtual void SetPosition(int _X, int _Y, screen *Screen );
    
	virtual void Paint(int _X, int _Y, screen *Screen );
	virtual void Show( HDC hdc, screen *Screen );
	
	virtual void Move1Step( HWND hwnd, screen *Screen);

	virtual void EndMove( HWND hwnd, screen *Screen );
	virtual void EndMove( HWND hwnd, HDC hdc, screen *Screen );

	virtual void InitMove( HWND hwnd, int _NewX, int _NewY, screen *Screen )
	{
	    moveable::InitMove(hwnd,_NewX,_NewY, Screen);
	}
                           
	virtual void InitHMove( HWND hwnd, screen *Screen, MVDIR Direction )
	{
	    moveable::InitHMove(hwnd, Screen, Direction);
	}
                           
	virtual void InitVMove( HWND hwnd, screen *Screen, MVDIR Direction )
	{
	    moveable::InitVMove(hwnd, Screen, Direction);
	}


    virtual void SetPosition(int _X, int _Y)
	{
		moveable::SetPosition(_X,_Y);
	};

    virtual boolean IsMoving(void) 
    { 
    	return moveable::IsMoving();
    };
    
	virtual int Timer(void)
	{
		return moveable::Timer();
	};

	virtual void Show( void );

};




class _3D_actor : public _3D_moveable, public _3D_animated
{
public:
	object_list	Portables;

	_3D_actor(void) {};

	~_3D_actor(void) { Portables.FreeAll(); };

	_3D_actor(int _X, int _Y, int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[],
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			int _Timer, int _Period, 
			int _DeltaX, int _DeltaY, boolean _EndsAtFirstFrame = true,
			boolean _IsVisible = true, int _Layer = 0  ) :
	_3D_moveable( _X, _Y,  _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,             
			_BoundX, _BoundY, 
			_BoundWidth, _BoundHeight, 
			_Timer, _Period,
			_DeltaX, _DeltaY,
			_IsVisible,_Layer  ), Portables( MAX_OBJECT_PORT )
	{
		Timer1 = Timer2 = _Timer;
		Period = Period2 = _Period;           
		
		EndsAtFirstFrame = _EndsAtFirstFrame;
		
	};
	
	_3D_actor(int _X, int _Y, int _NumberOfSprites, 
			int _Timer, int _Period,
			int _DeltaX, int _DeltaY, boolean _EndsAtFirstFrame = true,
			boolean _IsVisible = true, int _Layer = 0  ) :
	_3D_moveable( _X, _Y,  _NumberOfSprites, 
			_Timer, _Period,
			_DeltaX, _DeltaY,
			_IsVisible,_Layer  ), Portables( MAX_OBJECT_PORT )
	{
		Timer1 = Timer2 = _Timer;
		Period = Period2 = _Period;

		EndsAtFirstFrame = _EndsAtFirstFrame;		
	};
	
    virtual int	Timer(void) { return Timer1; };


	virtual void Move1Step( HWND hwnd, screen *Screen)
	{
		if( Moving )
		{
			_3D_animated::NextFrame();
			_3D_moveable::Move1Step( hwnd, Screen );
		}
	};


	virtual void EndMove( HWND hwnd, screen *Screen )
	{
	 	SetCurrentSprite( hwnd, Screen, 0 );
	 	_3D_moveable::EndMove(hwnd, Screen);
	};
	
	virtual void EndMove( HWND hwnd, HDC hdc, screen *Screen )
	{
	 	SetCurrentSprite( hwnd, Screen, 0 );
	 	_3D_moveable::EndMove(hwnd, hdc, Screen);
	};
	

	virtual void Appear( screen *Screen )
	{
	 	CurrentFrame = 0;
		_3D_moveable::Appear(Screen);
	};

	virtual void EndAnim( HWND hwnd, screen *Screen )
	{
	 	SetCurrentSprite( hwnd, Screen, 0 );
	 	_3D_animated::EndAnim(hwnd, Screen);
	};

	virtual void EndAnim( HWND hwnd, HDC hdc, screen *Screen )
	{
	 	SetCurrentSprite( hwnd, Screen, 0 );
	 	_3D_animated::EndAnim(hwnd, hdc, Screen);
	};



};


class _3D_player : public _3D_actor
{   
public:
	int RemainningLifes;
	long Score;

	
	_3D_player(void){};
	
	_3D_player(int _X, int _Y, int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[],
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			int _Timer, int _Period,
			int _DeltaX, int _DeltaY, 
			boolean _IsVisible = false, int _Layer = 0  ) :
	_3D_actor( _X, _Y, _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,
			_BoundX, _BoundY, 
			_BoundWidth, _BoundHeight, 
			_Timer, _Period,
			_DeltaX, _DeltaY, true,
			_IsVisible,_Layer  )
	{       
	};                                      

/*	
	_3D_player(int _X, int _Y, int _NumberOfSprites, 
			int _Timer, int _Period,
			int _DeltaX, int _DeltaY, 
			boolean _IsVisible = false, int _Layer = 0  ) :
	_3D_actor( _X, _Y, _NumberOfSprites, 
			_Timer, _Period,
			_DeltaX, _DeltaY, true,
			_IsVisible,_Layer  )
	{       
	};                                      
*/	
	_3D_player(int _Name, int _X, int _Y, 
			int _Timer, int _Period,
			int _DeltaX, int _DeltaY, 
			boolean _IsVisible = false, int _Layer = 0  ) :
	_3D_actor( _X, _Y, 1, 
			_Timer, _Period,
			_DeltaX, _DeltaY, true,
			_IsVisible,_Layer  )
	{            
		Name = _Name;
	};                                      
	
    virtual boolean IsPlayer(void) { return true; };
    virtual boolean Is3DPlayer(void) { return true; };
    virtual _3D_player *To3DPlayer(void) { return this; };

	virtual void Anim1Frame( HWND hwnd, screen *Screen);
	virtual void Move1Step( HWND hwnd, screen *Screen);
	virtual void Put( screen *Screen);

    virtual void OccupScreen( screen *Screen )
    {
    };
		
    virtual void DesoccupScreen( screen *Screen )
    {
    };
		
};



class exits : public _3D_animated
{ 
public:	

	char SceneInName[MAX_NAME_LEN];
	
	int	SceneInPlayerX,
		SceneInPlayerY;
	
	boolean	SceneInHasPlayer,
			SceneInHasControlPanel,
			SceneInHasStatusBar;

	boolean	SceneInIsClickExit,
			SceneInIs1Animation;

	
	event *OpenningEvent;
	
	int ExitNum;
	int ExitAnimCounter;	
	boolean StartExit;
	
	object *KeyObject;	
	
	int AlternativeExitNum;

	char AltSceneInName[MAX_NAME_LEN];
	
	int	AltSceneInPlayerX,
		AltSceneInPlayerY;
	
	    
	exits( void )
	{
		OpenningEvent = (event *) & Always;
		SceneInName[0] = '\0';
		SceneInPlayerX = 200;
		SceneInPlayerY = 100;
		ExitNum = -1;
		ExitAnimCounter = 0;
		StartExit = false;
		EndsAtFirstFrame = false;
				             
		w = h = d = 0;                   
	
		KeyObject = NULL;
		AlternativeExitNum = -1;
		AltSceneInName[0] = '\0';
		AltSceneInPlayerX = 200;
		AltSceneInPlayerY = 100;               
		
		SceneInHasPlayer = true;
		SceneInHasControlPanel = true;
		SceneInHasStatusBar = true;

		SceneInIsClickExit = false;
		SceneInIs1Animation = false;

		
	};


	exits(int _Name, int _X, int _Y,  
			char *BMPName, int BMPFrames, 
			int BMPWidth, int BMPHeight,
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			int _Timer, int _Period, boolean _EndsAtFirstFrame = false,
			boolean _IsVisible = true, int _Layer = 0  ) :
	_3D_animated( _X, _Y,  1, 
			&BMPName, &BMPFrames, 
			&BMPWidth, &BMPHeight,             
			_BoundX, _BoundY, 
			_BoundWidth, _BoundHeight, 
			_Timer, _Period, _EndsAtFirstFrame,
			_IsVisible,_Layer  )
	{           
	
		Name =_Name;
		
		OpenningEvent = (event *) & Always;
		SceneInName[0] = '\0';
		SceneInPlayerX = 200;
		SceneInPlayerY = 100;
		ExitNum = -1;
		ExitAnimCounter = 0;
		StartExit = false;

		w = h = d = 0;                   

		KeyObject = NULL;
		AlternativeExitNum = -1;
		AltSceneInName[0] = '\0';
		AltSceneInPlayerX = 200;
		AltSceneInPlayerY = 100;
	
		SceneInHasPlayer = true;
		SceneInHasControlPanel = true;
		SceneInHasStatusBar = true;

		SceneInIsClickExit = false;
		SceneInIs1Animation = false;
	};
		
		
	exits(int _X, int _Y,  
			char *BMPName, int BMPFrames, 
			int BMPWidth, int BMPHeight,
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			int _Timer, int _Period, boolean _EndsAtFirstFrame = false,
			boolean _IsVisible = true, int _Layer = 0  ) :
	_3D_animated( _X, _Y,  1, 
			&BMPName, &BMPFrames, 
			&BMPWidth, &BMPHeight,             
			_BoundX, _BoundY, 
			_BoundWidth, _BoundHeight, 
			_Timer, _Period, _EndsAtFirstFrame,
			_IsVisible,_Layer  )
	{
		OpenningEvent = (event *) & Always;
		SceneInName[0] = '\0';
		SceneInPlayerX = 200;
		SceneInPlayerY = 100;
		ExitNum = -1;
		ExitAnimCounter = 0;
		StartExit = false;

		w = h = d = 0;                   

		KeyObject = NULL;
		AlternativeExitNum = -1;
		AltSceneInName[0] = '\0';
		AltSceneInPlayerX = 200;
		AltSceneInPlayerY = 100;
	
		SceneInHasPlayer = true;
		SceneInHasControlPanel = true;
		SceneInHasStatusBar = true;

		SceneInIsClickExit = false;
		SceneInIs1Animation = false;
	};
		

	exits(int _X, int _Y,  
			int _Timer, int _Period, boolean _EndsAtFirstFrame = false,
			boolean _IsVisible = true, int _Layer = 0  ) :
	_3D_animated( _X, _Y,  1, 
			_Timer, _Period, _EndsAtFirstFrame,
			_IsVisible,_Layer  )
	{
		OpenningEvent = (event *) & Always;
		SceneInName[0] = '\0';
		SceneInPlayerX = 200;
		SceneInPlayerY = 100;
		ExitNum = -1;
		ExitAnimCounter = 0;
		StartExit = false;
	

		w = h = d = 0;                   

		KeyObject = NULL;
		AlternativeExitNum = -1;
		AltSceneInName[0] = '\0';
		AltSceneInPlayerX = 200;
		AltSceneInPlayerY = 100;
	
		SceneInHasPlayer = true;
		SceneInHasControlPanel = true;
		SceneInHasStatusBar = true;

		SceneInIsClickExit = false;
		SceneInIs1Animation = false;
	};
		

		
		    
	exits *InitExit( int PlayerX, int PlayerY, int _ExitNum, event *_OpenningEvent = (event *) &Always )
	{                         
		SceneInPlayerX = PlayerX;
		SceneInPlayerY = PlayerY;

	 	OpenningEvent = _OpenningEvent;                                 
	 	
	 	ExitNum = _ExitNum;

		StartExit = false;

	 	return this;
	};

	exits *InitExit( char *_SceneInName, int PlayerX, int PlayerY, int _ExitNum, event *_OpenningEvent = (event *) &Always )
	{                         
		strncpy( SceneInName, _SceneInName, MAX_NAME_LEN-1 );
		SceneInName[MAX_NAME_LEN-1] ='\0';

		SceneInPlayerX = PlayerX;
		SceneInPlayerY = PlayerY;

	 	OpenningEvent = _OpenningEvent;                                 
	 	
	 	ExitNum = _ExitNum;

		StartExit = false;

	 	return this;
	};

		

	exits *InitExit( char *_SceneInName, int PlayerX, int PlayerY, boolean HasPlayer, boolean HasControlPanel, boolean HasStatusBar, boolean IsClickExit,
						boolean Is1Animation  )
	{                         
		strncpy( SceneInName, _SceneInName, MAX_NAME_LEN-1 );
		SceneInName[MAX_NAME_LEN-1] ='\0';

		SceneInPlayerX = PlayerX;
		SceneInPlayerY = PlayerY;

		SceneInHasPlayer 		= HasPlayer;
		SceneInHasControlPanel 	= HasControlPanel;
		SceneInHasStatusBar 	= HasStatusBar;

		SceneInIsClickExit = IsClickExit;
		SceneInIs1Animation = Is1Animation;

	 	OpenningEvent = (event *) &Always;                                 
	 	
	 	ExitNum = -1;

		StartExit = false;

	 	return this;
	};

	exits *SetAlternativeExit( char *_SceneInName, int PlayerX, int PlayerY, int _ExitNum = -1 )
	{                         
		strncpy( SceneInName, _SceneInName, MAX_NAME_LEN-1 );
		SceneInName[MAX_NAME_LEN-1] ='\0';

		SceneInPlayerX = PlayerX;
		SceneInPlayerY = PlayerY;

	 	AlternativeExitNum = _ExitNum;

	 	return this;
	};

	exits *SetExitNum( int _ExitNum )
	{                         
	 	ExitNum = _ExitNum;

	 	return this;
	};


	exits *SetAlternativeExitNum( int _ExitNum )
	{                         
	 	AlternativeExitNum = _ExitNum;

	 	return this;
	};

	exits *SetKeyObject( object *_KeyObject )
	{                         
	 	KeyObject = _KeyObject;

	 	return this;
	};

		
	boolean IsOpened( void )
	{
		return( OpenningEvent != NULL ? OpenningEvent->HasOccurred() : false );
	};	

	boolean HasKey( _3D_actor *Actor = NULL );
	        
	virtual boolean IsExit( void ) { return true; };
    virtual exits *ToExit(void){ return this; };

	virtual int ExitNumber( void ) { return ExitNum; };


	virtual void Put( screen *Screen ) 
	{                         
	 	object::Put(Screen);
	}

        
	virtual void InitAnim( HWND hwnd, screen *Screen );

	virtual void Anim1Frame( HWND hwnd, screen *Screen );

//	virtual void Anim1Frame( HWND hwnd, screen *Screen, object *OccupObject1, object *OccupObject2 = NULL );

};



class portable : public _3D_moveable
{       
public:
    _3D_actor  *Owner;
                                  
//	char _SceneName[MAX_NAME_LEN+1];
	                                  
	PDIB pIcon;        
	char *IconName;
	int IconWidth;
	int IconHeight;

	boolean HasBeenTouched;
		
//	int z0;
	    
	portable(void) {};
		
	portable( char *FirstSceneName, int _X, int _Y, 
			int _Timer, int _Period,
			int _DeltaX, int _DeltaY,
			boolean _IsVisible = false, int _Layer = 0  );

	portable( char *FirstSceneName, int _X, int _Y, 
			char *BMPName, int _NumberOfFrames, 
			int BMPWidth, int BMPHeight,
			int _Timer, int _Period,
			int _DeltaX, int _DeltaY,
			boolean _IsVisible = false, int _Layer = 0  );
/*			:
	_3D_moveable(_X, _Y, 1, 
			&BMPName,  &BMPFrames, 
			&BMPWidth, &BMPHeight,
			_Timer, _Period,
			_DeltaX, _DeltaY,
			_IsVisible, _Layer  ) 

*/ 	        

	portable(int _Name, char *FirstSceneName, int _X, int _Y, 
			char *BMPName, 
			int BMPWidth, int BMPHeight,
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			int _Timer, int _Period, 
			boolean _IsVisible = true, int _Layer = 0  ) ;

	virtual boolean CanGo( screen *Screen );

	virtual boolean IsOn( object *Object, screen *Screen );

	virtual void SetPosition(int _X, int _Y, screen *Screen );
	virtual void SetPosition(int _X, int _Y, screen *Screen, int _z);

	virtual object *Set3DPosition( screen *Screen );
	virtual object *Set3DPosition( screen *Screen, int _z);

    virtual boolean IsPortable(void){ return true; };
    virtual portable *ToPortable(void){ return this; };

//	virtual char *SceneName(void) { return _SceneName; };

	object *ChangeOwner( _3D_actor 	*NewOwner );
	object *ChangeOwner( scene 		*NewScene );
	
	portable *DefIcon( 	char *_IconName, int _IconWidth = 40, int _IconHeight = 40 )
	{
		IconName   = _IconName;
		IconWidth  = _IconWidth;
		IconHeight = _IconHeight;	
		
		pIcon = DibOpenFile(IconName);
		
		return this;
	}
                                                
	virtual object *SetZ0( int _z0 )
	{
		z = _z0;
		return this;
	};                                                
	
//	virtual int z03D(void) { return z0; };

	void PutIcon( screen *Screen, int _X, int _Y );
};
    



#undef	DECLARE	    

	
	
	



	    
	    