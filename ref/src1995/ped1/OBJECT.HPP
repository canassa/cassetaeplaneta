
#ifdef _OBJECT
	#define	DECLARE
#else
	#define DECLARE extern
#endif        

typedef enum { MV_LEFT = 1, MV_RIGHT = 2, MV_UP = 4, MV_DOWN = 8 } MVDIR; // do not change the order!!


int NewName(void);


#define MAX_OBJECT_QTY	30
#define MAX_OBJECT_PORT	8


class frame
{
public:
	int BoundX,
		BoundY;
		
	int BoundWidth,
		BoundHeight;  
		
//	void far *pImage;

	frame(void)
	{	
//		pImage = NULL;
		BoundX = 0;
		BoundY = 0;
		BoundWidth = 0;
		BoundHeight = 0;
	};
			
	frame( int _BoundX, int _BoundY, int _BoundWidth, int _BoundHeight )
	{
		BoundX = _BoundX;
		BoundY = _BoundY;
		BoundWidth = _BoundWidth;
		BoundHeight = _BoundHeight;
	};
		
};



class sprite
{
public:
	frame *Frames;                          
	
	unsigned 
	int FrameWidth,
		FrameHeight;
		
	unsigned 
	int NumberOfFrames; // number of frames                              
                              
	PDIB pBitMap; 

	int BoundX,
		BoundY;
		
	int BoundWidth,
		BoundHeight;  
		

	sprite(void)
	{
		NumberOfFrames = 0;
		pBitMap = NULL;	
	}
		
	void Init( PDIB _pBitMap, int _NumberOfFrames, 
	  	  int _FrameWidth, int _FrameHeight,
	  	  int _BoundX = 0, int _BoundY = 0,  int _BoundWidth = 0, int _BoundHeight = 0 )
	{
		   pBitMap = _pBitMap;
		   NumberOfFrames = _NumberOfFrames;

		   FrameWidth  = _FrameWidth;
		   FrameHeight = _FrameHeight;
          
			BoundX = _BoundX;
			BoundY = _BoundY;

			if( _BoundWidth == 0 )
			{
				BoundWidth = _FrameWidth;
			}
			else
			{
				BoundWidth = _BoundWidth;
			}
						
			if( _BoundHeight == 0 )
			{			
				BoundHeight = _FrameHeight;
			}
			else
			{			
				BoundHeight = _BoundHeight;
			}
			
		   
		   Frames = new frame[NumberOfFrames];

	};


	void SetFrameBounds( int FrameNumber,  	
						 int _BoundX, int _BoundY, 
						 int _BoundWidth, int _BoundHeight )
	{
		Frames[FrameNumber].BoundX = _BoundX;
		Frames[FrameNumber].BoundY = _BoundY;
		Frames[FrameNumber].BoundWidth = _BoundWidth;
		Frames[FrameNumber].BoundHeight = _BoundHeight;
	};
		

	void SetSpriteBounds( int _BoundX, int _BoundY, 
						  int _BoundWidth, int _BoundHeight )
	{
		BoundX = _BoundX;
		BoundY = _BoundY;
		BoundWidth = _BoundWidth;
		BoundHeight = _BoundHeight;
	};
		


/*
    void SetBitMaps( PDIB _pBitMap )
    {                               
        
//        char __huge *p = (char __huge *) DibPtr(_pBitMap);
    	
		 	for( unsigned int i=0; i<NumberOfFrames; i++ )
		 	{   
				Frames[i].BoundX = 0;		 		
				Frames[i].BoundY = 0;		 		
				Frames[i].BoundWidth = 0;		 		
				Frames[i].BoundHeight = 0;		 		

//		 	 	Frames[i].pImage = p;
//				p += (((long)FrameWidth)*((long)FrameHeight));		 	 	                


		 	}		   			
    };                                        

*/	
	~sprite( void )
	{
	 	delete Frames;
	 	DibFree( pBitMap );
	};


	virtual frame * Frame( int FrameNumber ) // operator []
	{
	  	return	&Frames[FrameNumber];    
	};

	int FrameX(int FrameNumber)
	{
		return 0; // FrameNumber*FrameWidth se os frames estiverem na horizontal
	};
    	        
	int FrameY(int FrameNumber)
	{
		return FrameNumber*FrameHeight;	// 0 se os frames estiverem na horizontal
	};
    	        

    
};

class object_list
{
public:	
	object *FirstObject;
	int		NumObjects;
	int		MaxObjects;

	object_list( object * _FirstObject, int _MaxObjects = MAX_OBJECT_QTY )
	{
		FirstObject = _FirstObject;
		NumObjects = 0;                                          
		MaxObjects = _MaxObjects;
	};

	object_list( int _MaxObjects = MAX_OBJECT_QTY )
	{
		FirstObject = NULL;
		NumObjects = 0;                                          
		MaxObjects = _MaxObjects;
	};

	boolean Contains( object *Object );
	object_list *Insert( object *Object );
	object_list *Exclude( object *Object );

	boolean IsEmpty(void)
	{
		return (boolean) (FirstObject == NULL);
	};

	boolean IsFull(void)
	{
		return (boolean) (NumObjects == MaxObjects);
	};            
	
	void FreeAll(void);		
	void Restore(screen *Screen);		
	void Put(screen *Screen);		
	void Init(scene *Scene);

//	void ReservePalette( header &BufferHeader,pal &LogicalPalette );  
//	void PutIntoBuffer( HDC hBuffer, header &BufferHeader, void far *pBuffer );  
	
	friend class object;
};
    

class object
{
public:

	object  *Next,
			*Prev;
	object_list *List;			
			
	int Layer;

	int	X, Y; // 2D coordinates of the object in the buffer of the screen

	int Name;
	        
	int PaletteOffSet, 
		NumColors;
		        
	sprite *Sprites; // all of them must have the same palette range
	    
	uint NumberOfSprites;
	uint CurrentSprite;
	
	uint CurrentFrame;

/*	HDC hBackBuffer; // with size equal to the biggest frame size
	void far *pBackBuffer;
	void far *pBuffer;
*/
	header BufferHeader;
	HPALETTE  hpalObj;
	
	HBITMAP gBackOldMonoBitmap;
	long Orientation;

	boolean IsVisible;

    boolean Initialized;
/*
	int BoundX,
		BoundY;
		
	int BoundWidth,
		BoundHeight;  
*/		
	object *CollideObject;
	boolean InCollision;        
	boolean InShowQueue;
	int		PosShowQueue;
	
	int AuxX, AuxY;
	
//	RECT	DirtyRect;

	int DirtyX, DirtyY;
	int DirtyW, DirtyH;

	int LastDirtyX, LastDirtyY;
	int LastDirtyW, LastDirtyH;


	char _SceneName[MAX_NAME_LEN+1];


	virtual char *SceneName(void) { return _SceneName; };
//	virtual char *SceneName(void) { return ""; };

	virtual int x3D(void) { return 0; };
	virtual int y3D(void) { return 0; };
	virtual int z3D(void) { return 0; };
	virtual int w3D(void) { return 0; };
	virtual int h3D(void) { return 0; };
	virtual int d3D(void) { return 0; };


	virtual int X3DOrg(void) { return 0; };
	virtual int Y3DOrg(void) { return 0; };
	
	virtual int _OldX(void) { return X; };
	virtual int _OldY(void) { return Y; };
	
	virtual int _DeltaX(void) { return 0; };
	virtual int _DeltaY(void) { return 0; };

	virtual int Find_z( screen *Screen ) { return 0; };
	
	virtual object *Set3DPosition( screen *Screen, int _z = 0 ) 
	{
		return this;
	};

	virtual object *Set3DOrigin( int _X3DO, int _Y3DO ) 
	{
		return this;
	};

	virtual object *Set3DDimensions( int width, int height, int depth ) 
	{
		return this;
	};

	virtual object *SetZ0( int _z0 )
	{
		return this;
	};                                                
	
	virtual object * DrawSolid( HDC hdc, screen *Screen ) 
	{
		return this;
	};

	virtual object * DrawSolid( HWND hwnd, screen *Screen ) 
	{
		return this;
	};

    sprite &Sprite( void )
    {
    	return Sprites[CurrentSprite];
    };
    
//    sprite &SetCurrentSprite( int SpriteNumber )
    sprite &SetCurrentSprite( HWND hwnd, screen *Screen, int SpriteNumber )
    {
    	return Sprites[CurrentSprite];
   	}
    
    PDIB pBitMap(void)
    {
      return Sprite().pBitMap;
    };
    
    
	frame *Frame( void )
	{
		return Sprite().Frame(CurrentFrame);
	};
    
	int FrameWidth(void)
	{
		return Sprite().FrameWidth;
	};
    	        
	int FrameHeight(void)
	{
		return Sprite().FrameHeight;	
	};
    	        
	int FrameX(void)
	{
		return Sprite().FrameX(CurrentFrame);
	};
    	        
	int FrameY(void)
	{
		return Sprite().FrameY(CurrentFrame);	
	};
    	        
	int BoundWidth(void)
	{
		return Sprite().BoundWidth;
	};
    	        
	int BoundHeight(void)
	{
		return Sprite().BoundHeight;	
	};
    	        
	int BoundX(void)
	{
		return Sprite().BoundX;
	};
    	        
	int BoundY(void)
	{
		return Sprite().BoundY;	
	};
    	        
	int NumberOfFrames(void)
	{
		return Sprite().NumberOfFrames;
	};

	void ResetDirtyRect( void )
	{
		LastDirtyX = DirtyX = 0;
		LastDirtyY = DirtyY = 0;		
		LastDirtyW = DirtyW = FrameWidth();
		LastDirtyH = DirtyH = FrameHeight();		
	};		

	virtual void SetDirtyRect( int left, int top, int width, int height )
	{                    
		
		if( DirtyX > left )
		{		                                            
			if( DirtyX+DirtyW > left+width )
			{
				DirtyW  = DirtyX+DirtyW-left;
			}                                  
			else
			{
				DirtyW = width;
			}

			DirtyX = left;		
		}
		else
		{
			if( DirtyX+DirtyW < left+width )
			{
				DirtyW  = left+width-DirtyX;
			}
			
		}
		
		if( DirtyY > top )
		{   
			if( DirtyY+DirtyH > top+height )		
			{
				DirtyH = DirtyY+DirtyH-top;		
			}                  
			else
			{
				DirtyH = height;
			}

			DirtyY = top;
		}                      
		else
		{
			if( DirtyY+DirtyH < top+height )		
			{
				DirtyH = top+height-DirtyY;		
			}
		}
		
	};
    	        
	virtual boolean DetectedDirtyCollision( object *o );  // , screen *Screen )    	        

	void SaveBackGround( HDC hBuffer );
	void RestoreBackGround( HDC hBuffer );

	void SaveBackGround( screen *Screen, int nBuffer = 1 );
	virtual void RestoreBackGround( screen *Screen, int nBuffer = 1 );

	virtual void PutIntoBuffer( BITMAPINFO far * pBufferHeader, void far *pBuff );
	    
	virtual void Put( screen *Screen )
	{
		PutIntoBuffer( (BITMAPINFO far * )&(Screen->BufferHeader), 
						Screen->pBuffer );

//		PutIntoBuffer( (BITMAPINFO far * )&(Screen->BufferHeader), 
//						Screen->pBuffer2 );
	};

	virtual void PutDirtyIntoBuffer( BITMAPINFO far * pBufferHeader, void far *pBuff );
	    
	virtual void PutDirty( screen *Screen )
	{
		PutDirtyIntoBuffer( (BITMAPINFO far * )&(Screen->BufferHeader), 
						Screen->pBuffer );

//		PutIntoBuffer( (BITMAPINFO far * )&(Screen->BufferHeader), 
//						Screen->pBuffer2 );
	};

	virtual void Restore( screen *Screen )
	{
// 		Restore the Background
//		RestoreBackGround( Screen->hBuffer );
		RestoreBackGround( Screen,1 );
//		RestoreBackGround( Screen,2 );
	};

	virtual void Save( screen *Screen )
	{
// 		Save the Background
		SaveBackGround( Screen,1 );
//		SaveBackGround( Screen,2 );
	};

	virtual void Paint( screen *Screen )
	{
//		RestoreBackGround( Screen->hBuffer );
//		RestoreBackGround( Screen );
		Restore( Screen );

		OccupScreen( Screen );

		Put(Screen);
		
/*		PutIntoBuffer( (BITMAPINFO far * )&(Screen->BufferHeader), 
						Screen->pBuffer );

		PutIntoBuffer( (BITMAPINFO far * )&(Screen->BufferHeader), 
						Screen->pBuffer2 );
*/	};


	virtual void Hide( HDC hdc, screen *Screen )
	{
		//	Take out from the buffer
		Disappear( Screen );

    // Restore the Background
    
    	Show();
    
/*    	WinGBitBlt( hdc,X-Screen->ScreenX,Y-Screen->ScreenY,
    			FrameWidth(), FrameHeight(), Screen->hBuffer, X,Y); 
*/
	}
	
	virtual void Show( void );
	virtual void Show( HDC hdc, screen *Screen );
	
	virtual void Refresh( HDC hdc, screen *Screen );
	
	virtual void Disappear( screen *Screen )
	{
	
    // Restore the Background
//		RestoreBackGround( Screen->hBuffer );
		Restore( Screen );

		DesoccupScreen( Screen );
		
		IsVisible = false;

	};
	                           
	virtual void Appear( screen *Screen )
	{
//		SaveBackGround( Screen->hBuffer );
		SaveBackGround( Screen );

		CurrentFrame = 0;
				
		Put(Screen);

		OccupScreen( Screen );

		IsVisible = true;
		
/*		PutIntoBuffer( (BITMAPINFO far * )&(Screen->BufferHeader), 
						Screen->pBuffer );

		PutIntoBuffer( (BITMAPINFO far * )&(Screen->BufferHeader), 
						Screen->pBuffer2 );
*/
	};

	object * UpdatePalette( HDC hdc, screen *Screen );

	RGBQUAD far *pColorTable(void)	
	{
		  return (RGBQUAD far *)
		   (((char far *)pBitMap()) + pBitMap()->biSize);
    };


	object *Insert( object_list *aList )
	{
	 	aList->Insert( this );
	 	return this;
	}

	object *Exclude( object_list *aList )
	{
	 	aList->Exclude( this );
	 	return this;
	}               
	
	boolean Belongs( object_list *aList )
	{
	 	return aList->Contains( this );
	}               
	

	object(void) 
	{
//		_SceneName[0] = '\0';
//		Name = NewName();
	};
		
	object( int _X, int _Y, 
			char *BMPName, int _NumberOfFrames, 
			int BMPWidth, int BMPHeight,
			boolean _IsVisible = true, int _Layer = 0  )
	{
		_SceneName[0] = '\0';
		Name = NewName();

		X = _X;
		Y = _Y;                         
		Layer = _Layer;
		IsVisible = _IsVisible;
    
    	Initialized = false;

    	CurrentSprite = 0;
    	CurrentFrame  = 0;
    	NumberOfSprites = 1;

//		BoundX = 0;
//		BoundY = 0;
		
//		BoundWidth  = BMPWidth;
//  	BoundHeight = BMPHeight;
		
		Sprites = new sprite;

		PDIB _pBitMap = DibOpenFile(BMPName);
		 
		if( _pBitMap == 0 )
		{             
			MessageBox( "Erro Fatal!!", "Não foi possível abrir o arquivo: %s", BMPName );
		}
		        	
		Sprites->Init( _pBitMap, _NumberOfFrames, BMPWidth, BMPHeight);
    
	};

	
	object( int _X, int _Y, 
			char *BMPName, int _NumberOfFrames, 
			int BMPWidth, int BMPHeight,
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			boolean _IsVisible = true, int _Layer = 0  )
	{
		
		_SceneName[0] = '\0';
		Name = NewName();

		X = _X;
		Y = _Y;                         
		Layer = _Layer;
		IsVisible = _IsVisible;
    
    	Initialized = false;

    	CurrentSprite = 0;
    	CurrentFrame  = 0;
    	NumberOfSprites = 1;

/*		BoundX = _BoundX;
		BoundY = _BoundY;
		
		BoundWidth  = _BoundWidth;
		BoundHeight = _BoundHeight;
*/		
		Sprites = new sprite;


		PDIB _pBitMap = DibOpenFile(BMPName);
		 
		if( _pBitMap == 0 )
		{             
			MessageBox( "Erro Fatal!!", "Não foi possível abrir o arquivo: %s", BMPName );
		}
		        	

		Sprites->Init( _pBitMap, _NumberOfFrames, BMPWidth, BMPHeight,
						_BoundX, _BoundY, _BoundWidth, _BoundHeight	);
    
	};
	
	
	
	object( int _X, int _Y, int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[],
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			boolean _IsVisible = true, int _Layer = 0  )
	{

		_SceneName[0] = '\0';
		Name = NewName();

		X = _X;
		Y = _Y;                         
		Layer = _Layer;
		IsVisible = _IsVisible;
    
    	Initialized = false;

    	CurrentSprite = 0;
    	CurrentFrame  = 0;
    	NumberOfSprites = _NumberOfSprites;

/*		BoundX = _BoundX;
		BoundY = _BoundY;
		
		BoundWidth  = _BoundWidth;
		BoundHeight = _BoundHeight;
*/		
		Sprites = new sprite[NumberOfSprites];
    	    
		PDIB _pBitMap;
		
    	for( uint i=0; i<NumberOfSprites; i++ )
    	{   
			_pBitMap = DibOpenFile(BMPName[i]);
		 
			if( _pBitMap == 0 )
			{             
				MessageBox( "Erro Fatal!!", "Não foi possível abrir o arquivo: %s", BMPName[i] );
			}
		        	
			Sprites[i].Init( _pBitMap,
						BMPFrames[i], BMPWidth[i], BMPHeight[i],
					_BoundX, _BoundY, _BoundWidth, _BoundHeight);
    	}
    
	};

	object( int _X, int _Y, int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[],
			boolean _IsVisible = true, int _Layer = 0  )
	{
     
		_SceneName[0] = '\0';
		Name = NewName();

		X = _X;
		Y = _Y;                         
		Layer = _Layer;
		IsVisible = _IsVisible;
    
    	Initialized = false;

    	CurrentSprite = 0;
    	CurrentFrame  = 0;
    	NumberOfSprites = _NumberOfSprites;

//		BoundX = 0;
//		BoundY = 0;
		
//		BoundWidth  = BMPWidth[0];
//		BoundHeight = BMPHeight[0];
		
		Sprites = new sprite[NumberOfSprites];
    	
		PDIB _pBitMap;
		
    	for( uint i=0; i<NumberOfSprites; i++ )
    	{   
			_pBitMap = DibOpenFile(BMPName[i]);
		 
			if( _pBitMap == 0 )
			{             
				MessageBox( "Erro Fatal!!", "Não foi possível abrir o arquivo: %s", BMPName[i] );
			}
		        	
			Sprites[i].Init( _pBitMap,
						BMPFrames[i], BMPWidth[i], BMPHeight[i]);
    	}
    
	};

	object( int _X, int _Y, int _NumberOfSprites, 
			boolean _IsVisible = true, int _Layer = 0  )
	{

		_SceneName[0] = '\0';
		Name = NewName();

		X = _X;
		Y = _Y;                         
		Layer = _Layer;
		IsVisible = _IsVisible;
    
    	Initialized = false;

    	CurrentSprite = 0;
    	CurrentFrame  = 0;
    	NumberOfSprites = _NumberOfSprites;
    
	};


    
    virtual void OccupScreen( screen *Screen )
    {
		Screen->IncrOccupation( this );    
    };
		
    virtual void DesoccupScreen( screen *Screen )
    {
		Screen->DecrOccupation( this );    
    };
		
	virtual object *Init( screen *Screen );

	virtual boolean CanGo( screen *Screen)
	{
	 	return false;
	};
	
	virtual boolean CantGo( screen *Screen)
	{
		return (boolean) !CanGo( Screen );
	};


	virtual int NextFrame(void)	{ return 0; };	                          
	virtual int PreviousFrame(void) { return 0; };	                           
	virtual void InitAnim( HWND hwnd, screen *Screen ) { };
	virtual void InitAnimP( HWND hwnd, screen *Screen ) { };
	virtual void EndAnim( HWND hwnd, screen *Screen ) { };
	virtual void EndAnim( HWND hwnd, HDC hdc, screen *Screen ) { };
	virtual void Anim1Frame( HWND hwnd, screen *Screen) { };
	virtual void StopAnim( HWND hwnd ) { };

	
	virtual void InitMove( HWND hwnd, int _NewX, int _NewY, screen *Screen ) { };
	virtual void InitHMove( HWND hwnd, screen *Screen, MVDIR Direction ) { };
	virtual void InitVMove( HWND hwnd, screen *Screen, MVDIR Direction ) { };
	virtual void EndMove( HWND hwnd, screen *Screen ) { };
	virtual void EndMove( HWND hwnd, HDC hdc, screen *Screen ) { };
	virtual void Move1Step( HWND hwnd, screen *Screen) { };
    
    virtual int	Timer(void) { return -1; };
    virtual boolean IsMoving(void) { return false; };
	virtual boolean IsAnimating(void) {  return false; }
    virtual void SetPosition(int _X, int _Y)
	{
      	X = _X;
      	Y = _Y;     
      	
	};

    virtual void SetPosition(int _X, int _Y, screen *Screen) { };

    virtual boolean IsPlayer(void) { return false; };
    virtual player *ToPlayer(void) { return NULL; };

    virtual boolean Is3DPlayer(void) { return false; };
    virtual _3D_player *To3DPlayer(void) { return NULL; };

    virtual boolean  IsAnimated(void) { return false; };
    virtual animated *ToAnimated(void) { return NULL; };

    virtual boolean  IsMoveable(void) { return false; };
    virtual moveable *ToMoveable(void) { return NULL; };

    virtual boolean IsActor(void) { return false; };
    virtual actor   *ToActor(void) { return NULL; };

    virtual boolean Is3DObject(void) { return false; };
    virtual _3D_object *To3DObject(void) { return NULL; };

    virtual boolean IsStatusBar(void) { return false; };
    virtual status_bar *ToStatusBar(void) { return NULL; };

    virtual boolean IsControlPanel(void) { return false; };
    virtual control_panel *ToControlPanel(void) { return NULL; };

    virtual boolean IsPortable(void){ return false; };
    virtual portable *ToPortable(void){ return NULL; };
	
//	virtual void TreatCollision( HDC hdc, screen *Screen);
	virtual void TreatCollision( HDC hdc, screen *Screen, boolean SelfRefr = true );
	virtual boolean DetectedCollision( object *o );
	virtual boolean DetectedFrameCollision( object *o );
	                           
	virtual boolean CollisionHandling( player *p ) { return false; };
	virtual boolean CollisionHandling( _3D_player *p ) { return false; };


	virtual boolean IsExit( void ) { return false; };
    virtual exits  *ToExit( void ){ return NULL; };
	virtual boolean IsOpened( void ) { return false; };
	virtual int ExitNumber( void ) { return -1; };

	virtual boolean IsClass1( void ) { return false; };
	virtual boolean IsClass2( void ) { return false; };
	virtual boolean IsClass3( void ) { return false; };
	virtual boolean IsClass4( void ) { return false; };
	virtual boolean IsClass5( void ) { return false; };

//	#include "objext.hpp"                                           

	~object(void)
	{
/*    	HBITMAP hback;
	
    //  Retrieve the current WinGBitmap, replace with the original
    	hback = (HBITMAP)SelectObject(hBackBuffer, gBackOldMonoBitmap);
    
    //  And delete the WinGBitmap and WinGDC
    	DeleteObject(hback);
    
    	DeleteDC(hBackBuffer);
*/    	
	};



protected:

//	object( int _NumberOfSprites, 
	void InitAnimated( int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[],
			int _BoundX = 0, int _BoundY = 0,  int _BoundWidth = 0, int _BoundHeight = 0 )
	{
		_SceneName[0] = '\0';
		Name = NewName();

    	NumberOfSprites = _NumberOfSprites;

		Sprites = new sprite[NumberOfSprites];
    	
    	for( uint i=0; i<NumberOfSprites; i++ )
    	{   
			Sprites[i].Init( DibOpenFile(BMPName[i]),
						BMPFrames[i], BMPWidth[i], BMPHeight[i],
						_BoundX, _BoundY, _BoundWidth, _BoundHeight);
    	}
    
	};

//	object( 
	void InitAnimated( 
			char *BMPName, int BMPFrames, 
			int BMPWidth, int BMPHeight,
			int _BoundX = 0, int _BoundY = 0,  int _BoundWidth = 0, int _BoundHeight = 0 )
	{
		_SceneName[0] = '\0';
		Name = NewName();

    	NumberOfSprites = 1;

		Sprites = new sprite;
    	
		PDIB _pBitMap = DibOpenFile(BMPName);
		 
		if( _pBitMap == 0 )
		{             
			MessageBox( "Erro Fatal!!", "Não foi possível abrir o arquivo: %s", BMPName );
		}
		        	
		Sprites->Init(  _pBitMap, BMPFrames, BMPWidth, BMPHeight,
						_BoundX, _BoundY, _BoundWidth, _BoundHeight);
    
	};

	void InitAnimated( int _NumberOfSprites ) 
	{
		_SceneName[0] = '\0';
		Name = NewName();

    	NumberOfSprites = _NumberOfSprites;

		Sprites = new sprite[NumberOfSprites];
	};

//	object( int _X, int _Y, 
	void InitMoveable( int _X, int _Y, 
//			int _BoundX, int _BoundY,
//			int _BoundWidth, int _BoundHeight,
			boolean _IsVisible = true, int _Layer = 0  )
	{
		_SceneName[0] = '\0';
		Name = NewName();

		X = _X;
		Y = _Y;                         
		Layer = _Layer;
		IsVisible = _IsVisible;
    
    	Initialized = false;

    	CurrentSprite = 0;
    	CurrentFrame  = 0;

/*		BoundX = _BoundX;
		BoundY = _BoundY;
		
		BoundWidth  = _BoundWidth;
		BoundHeight = _BoundHeight;
*/		
	};
	


        
};


class animated : virtual public object
{
public:
	int Timer2, Period2;

	int FrameCounter;
		
	boolean _1SpriteAnim;                       
	
	boolean EndsAtFirstFrame;

	boolean Animating;
	
    animated(void) {};
    
	animated(int _X, int _Y, int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[],
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			int _Timer, int _Period, boolean _EndsAtFirstFrame = true,
			boolean _IsVisible = true, int _Layer = 0  ) 
/*			:
	object( _X, _Y, _NumberOfSprites, 		// não funciona devido ao virtual na heranca
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,
			_IsVisible,_Layer  )
*/ 
	{
		Timer2 = _Timer;
		Period2 = _Period;

		InitAnimated( _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,
			_BoundX, _BoundY, 
			_BoundWidth, _BoundHeight );

		InitMoveable( 	_X, _Y, 
						_IsVisible,_Layer  );

		Animating = false;
		_1SpriteAnim = false;

		FrameCounter = 0;                                             
		
		EndsAtFirstFrame = _EndsAtFirstFrame;

	};

	animated(int _X, int _Y, int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[],
			int _Timer, int _Period, boolean _EndsAtFirstFrame = true,
			boolean _IsVisible = true, int _Layer = 0  ) 
/*			:
	object( _X, _Y, _NumberOfSprites, 		// não funciona devido ao virtual na heranca
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,
			_IsVisible,_Layer  )
*/ 
	{
		Timer2 = _Timer;
		Period2 = _Period;

		InitAnimated( _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight);
			
		InitMoveable( 	_X, _Y, 
						_IsVisible,_Layer  );

		Animating = false;
		_1SpriteAnim = false;

		FrameCounter = 0;

		EndsAtFirstFrame = _EndsAtFirstFrame;

	};

	animated(int _X, int _Y, int _NumberOfSprites, 
			int _Timer, int _Period, boolean _EndsAtFirstFrame = true,
			boolean _IsVisible = true, int _Layer = 0  ) 
/*			:
	object( _X, _Y, _NumberOfSprites, 		// não funciona devido ao virtual na heranca
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,
			_IsVisible,_Layer  )
*/ 
	{
		Timer2 = _Timer;
		Period2 = _Period;

		InitAnimated( _NumberOfSprites );
			
		InitMoveable( 	_X, _Y, 
						_IsVisible,_Layer  );

		Animating = false;
		_1SpriteAnim = false;

		FrameCounter = 0;

		EndsAtFirstFrame = _EndsAtFirstFrame;

	};

	virtual boolean IsAnimating(void) {  return Animating; }

    sprite &SetCurrentSprite( HWND hwnd, screen *Screen, int SpriteNumber )
    {
    	
		sprite *NewSprite = &(Sprites[SpriteNumber]);
		sprite *OldSprite = &(Sprites[CurrentSprite]);
		
		    	                             
    	if( OldSprite->FrameWidth  == NewSprite->FrameWidth &&
    		OldSprite->FrameHeight == NewSprite->FrameHeight )
		{    		
    	 	CurrentSprite = SpriteNumber;
    		CurrentFrame = 0;
    	}
    	else
    	{   
/*    		HBITMAP hback;
    		                             
			HDC hdc = GetDC(hwnd);
*/			    		                          
			Disappear( Screen );
			Show();

/*    		hback = (HBITMAP)SelectObject(hBackBuffer, gBackOldMonoBitmap);
    
    		DeleteObject(hback);
    

        	BufferHeader.Header.biWidth  = NewSprite->FrameWidth; 
        	BufferHeader.Header.biHeight = NewSprite->NumberOfFrames*NewSprite->FrameHeight;
                           
			pBackBuffer = NULL;
			                           
        	hback = WinGCreateBitmap(hBackBuffer,
        	(BITMAPINFO far *)&BufferHeader , &pBackBuffer);   
        	
        	gBackOldMonoBitmap = (HBITMAP)SelectObject(hBackBuffer, hback);
        	
*/        	     
        	CurrentSprite = SpriteNumber;
    		CurrentFrame = 0;
        	
        	Appear(Screen);
//			object::Show( hdc, Screen );
			Show();

/*			ReleaseDC(hwnd, hdc);
*/
    	}
    	 
    	return Sprite();
   	};
    
	virtual int NextFrame(void)  // operator ++
	{
		if( Sprite().NumberOfFrames-1 == CurrentFrame )
		{
			CurrentFrame = 0;
		}
		else
		{
			CurrentFrame ++; 
		}
		
		return CurrentFrame;
	};	                          
	
	virtual int PreviousFrame(void)
	{
		if( CurrentFrame == 0 )
		{
			CurrentFrame = Sprite().NumberOfFrames-1;
		}
		else
		{
			CurrentFrame --; 
		}
		
		return CurrentFrame;
	};	                           

    virtual int	Timer(void) { return Timer2; };


	virtual void Put( screen *Screen )
	{
		PutIntoBuffer( (BITMAPINFO far * )&(Screen->BufferHeader), 
						Screen->pBuffer );
	};

	virtual void Restore( screen *Screen )
	{
// 		Restore the Background
//		RestoreBackGround( Screen->hBuffer );
		RestoreBackGround( Screen,1 );
	};


	virtual void Save( screen *Screen )
	{
// 		Save the Background
		SaveBackGround( Screen ); // ,2 );
	};


/*	virtual void Paint( screen *Screen )
	{
		RestoreBackGround( Screen->hBuffer );
		
		PutIntoBuffer( (BITMAPINFO far * )&(Screen->BufferHeader), 
						Screen->pBuffer );
	};


	virtual void Appear( screen *Screen )
	{
		SaveBackGround( Screen->hBuffer );
		
		CurrentFrame = 0;
		
		PutIntoBuffer( (BITMAPINFO far * )&(Screen->BufferHeader), 
						Screen->pBuffer );

		OccupScreen( Screen );
	};

*/

	virtual void InitAnim( HWND hwnd, screen *Screen );
	virtual void Init1SpriteAnim( HWND hwnd, screen *Screen );
	virtual void EndAnim( HWND hwnd, screen *Screen );
	virtual void EndAnim( HWND hwnd, HDC hdc, screen *Screen );
	virtual void Anim1Frame( HWND hwnd, screen *Screen);

	virtual void StopAnim( HWND hwnd );

    virtual boolean  IsAnimated(void) { return true; };
    virtual animated *ToAnimated(void) { return this; };

//	#include "aniext.hpp"                                           


// protected:

/*	animated(int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[] ) :
	object( _NumberOfSprites, 				// não funciona devido ao virtual na heranca
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight)
	{
/ *		InitAnimated( _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight);
* /
	};

*/	

};

class moveable : virtual public object
{      
public:
	int XSpeed,
		YSpeed;
		
	int Direction;
	
	int XMax, XMin,
		YMax, YMin;
		               
	int	OldX, OldY;

//	int RefOldX, RefOldY;

	int	NewX, NewY;

//    int AuxX, AuxY;
    int DeltaX, DeltaY,
    	DistX, DistY;    
	int Dist, Counter;    	
	int IncrNE, IncrE, IncrN;

	int Timer1,
		Period;
		
	boolean Moving;
                
    moveable(void) {};

    
	moveable(int _X, int _Y, int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[],
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			int _Timer, int _Period, 
			int _DeltaX = 20, int _DeltaY = 20,
			boolean _IsVisible = true, int _Layer = 0  ) 
/*			:
	object( _X, _Y, _NumberOfSprites, 	// não funciona devido ao virtual na heranca
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

	
		NewX = OldX = X;
		NewY = OldY = Y;     
		
		Timer1 = _Timer;
		Period = _Period;                    

    	DeltaX=_DeltaX;
    	DeltaY=_DeltaY;
    	
    	Moving = false;

	};		           

	moveable(int _X, int _Y, int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[],
			int _Timer, int _Period, 
			int _DeltaX = 20, int _DeltaY = 20,
			boolean _IsVisible = true, int _Layer = 0  ) 
/*			:
	object( _X, _Y, _NumberOfSprites, 	// não funciona devido ao virtual na heranca
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

	
		NewX = OldX = X;
		NewY = OldY = Y;     
		
		Timer1 = _Timer;
		Period = _Period;                    

    	DeltaX=_DeltaX;
    	DeltaY=_DeltaY;
    	
    	Moving = false;

	};		           

	moveable(int _X, int _Y, int _NumberOfSprites, 
			int _Timer, int _Period, 
			int _DeltaX = 20, int _DeltaY = 20,
			boolean _IsVisible = true, int _Layer = 0  ) 
/*			:
	object( _X, _Y, _NumberOfSprites, 	// não funciona devido ao virtual na heranca
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,
			_IsVisible,_Layer  )
 
*/
	{

		InitAnimated( _NumberOfSprites );

		InitMoveable( 	_X, _Y, 
						_IsVisible,_Layer  );

	
		NewX = OldX = X;
		NewY = OldY = Y;     
		
		Timer1 = _Timer;
		Period = _Period;                    

    	DeltaX=_DeltaX;
    	DeltaY=_DeltaY;
    	
    	Moving = false;

	};		           

	virtual object *Init( screen *Screen )
	{
    	object::Init( Screen );
	
		CollideObject = NULL;
		
		return this;
	};

    virtual void SetPosition(int _X, int _Y)
	{
		OldX = X;
		OldY = Y;

      	X = _X;
      	Y = _Y;     
      	
	};

	virtual int _OldX(void) { return OldX; };
	virtual int _OldY(void) { return OldY; };

	virtual int _DeltaX(void) { return abs(DeltaX); };
	virtual int _DeltaY(void) { return abs(DeltaY); };
	
    virtual int	Timer(void) { return Timer1; };
    virtual boolean IsMoving(void) { return Moving; };

	virtual void RestoreBackGround( screen *Screen, int nBuffer = 1 );
	virtual void PutIntoBuffer( BITMAPINFO far * pBufferHeader, void far *pBuff );
    
	virtual void Paint(int _X, int _Y, screen *Screen );

	virtual void Disappear( screen *Screen )
	{
//		RestoreBackGround( Screen->hBuffer );
		RestoreBackGround( Screen,1 );

		DesoccupScreen( Screen );

		IsVisible = false;

		OldX = X;
		OldY = Y;
	};

	virtual void Appear( screen *Screen )
	{
//		SaveBackGround( Screen->hBuffer );
		SaveBackGround( Screen ); //, 2 );
		
		CurrentFrame = 0;
		
		PutIntoBuffer( (BITMAPINFO far * )&(Screen->BufferHeader), 
						Screen->pBuffer );

		OccupScreen( Screen );

		IsVisible = true;

		OldX = X;
		OldY = Y;

	};

	virtual void Show( HDC hdc, screen *Screen );
	virtual void Show( void );
	
	virtual void Refresh( HDC hdc, screen *Screen );

	virtual boolean CanGo( screen *Screen);

	boolean	FinishedMovement( void );
	void 	PlanNextPosition( void );

	virtual void InitMove( HWND hwnd, int _NewX, int _NewY, screen *Screen );
	virtual void InitHMove( HWND hwnd, screen *Screen, MVDIR Direction );
	virtual void InitVMove( HWND hwnd, screen *Screen, MVDIR Direction );
	virtual void EndMove( HWND hwnd, screen *Screen );
	virtual void EndMove( HWND hwnd, HDC hdc, screen *Screen );
	virtual void Move1Step( HWND hwnd, screen *Screen);

	void Move( HDC hdc, int NewX, int NewY, screen *Screen);
//	void Move( int NewX, int NewY ) { };		


    virtual boolean  IsMoveable(void) { return true; };
    virtual moveable *ToMoveable(void) { return this; };


//	#include "movext.hpp"                                           


protected:

	moveable(int _X, int _Y, 
//			int _BoundX, int _BoundY,
//			int _BoundWidth, int _BoundHeight,
			int _Timer, int _Period,
			int _DeltaX = 20, int _DeltaY = 20,
			boolean _IsVisible = true, int _Layer = 0  ) 
//	object( _X, _Y, _IsVisible,_Layer  )
	{
	
		InitMoveable( 	_X, _Y, 
						_IsVisible,_Layer );

	
		NewX = OldX = X;
		NewY = OldY = Y;     
		
		Timer1 = _Timer;
		Period = _Period;                    

    	DeltaX=_DeltaX;
    	DeltaY=_DeltaY;
    	
    	Moving = false;

	};		           



};                                  

class actor : public moveable, public animated
{
public:
	actor(void) {};

	actor(int _X, int _Y, int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[],
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			int _Timer, int _Period,
			int _DeltaX, int _DeltaY, boolean _EndsAtFirstFrame = true,
			boolean _IsVisible = true, int _Layer = 0  ) :
	moveable( _X, _Y, 
			_Timer, _Period,
			_DeltaX, _DeltaY,
			_IsVisible,_Layer  )
/*	animated( _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight)
*/	{
		InitAnimated( _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,               
			_BoundX, _BoundY, 
			_BoundWidth, _BoundHeight);


		Timer2 = _Timer;
		Period2 = _Period;

		Animating = false;
		FrameCounter = 0;
		
		EndsAtFirstFrame = _EndsAtFirstFrame;
				
	};
	

	actor(int _X, int _Y, int _NumberOfSprites, 
			int _Timer, int _Period,
			int _DeltaX, int _DeltaY, boolean _EndsAtFirstFrame = true,
			boolean _IsVisible = true, int _Layer = 0  ) :
	moveable( _X, _Y, 
			_Timer, _Period,
			_DeltaX, _DeltaY,
			_IsVisible,_Layer  )
/*	animated( _NumberOfSprites)
*/	{
		InitAnimated( _NumberOfSprites );


		Timer2 = _Timer;
		Period2 = _Period;

		Animating = false;
		FrameCounter = 0;

		EndsAtFirstFrame = _EndsAtFirstFrame;
				
	};
	

    virtual int	Timer(void) { return Timer1; };

	virtual void Move1Step( HWND hwnd, screen *Screen)
	{
		if( Moving )
		{
			animated::NextFrame();
			moveable::Move1Step( hwnd, Screen );
		}
	};

	virtual void EndMove( HWND hwnd, screen *Screen )
	{
	 	SetCurrentSprite( hwnd, Screen, 0 );
	 	moveable::EndMove(hwnd, Screen);
	};
	
	virtual void EndMove( HWND hwnd, HDC hdc, screen *Screen )
	{
	 	SetCurrentSprite( hwnd, Screen, 0 );
	 	moveable::EndMove(hwnd, hdc, Screen);
	};
	

	virtual void EndAnim( HWND hwnd, screen *Screen )
	{
	 	SetCurrentSprite( hwnd, Screen, 0 );
	 	animated::EndAnim(hwnd, Screen);
	};

	virtual void EndAnim( HWND hwnd, HDC hdc, screen *Screen )
	{
	 	SetCurrentSprite( hwnd, Screen, 0 );
	 	animated::EndAnim(hwnd, hdc, Screen);
	};


	virtual void Paint( screen *Screen )
	{
		animated::Paint(Screen);
	};

	virtual void Show( HDC hdc, screen *Screen )
	{
		moveable::Show( hdc, Screen );
	};

	virtual void Appear( screen *Screen )
	{
		moveable::Appear(Screen);
	};

	virtual object *Init( screen *Screen )
	{
    	return moveable::Init( Screen );
	};

	virtual boolean CanGo( screen *Screen)
	{
    	return moveable::CanGo( Screen );
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

    virtual void SetPosition(int _X, int _Y)
	{
		moveable::SetPosition(_X,_Y);
	};

    virtual boolean IsMoving(void) 
    { 
    	return moveable::IsMoving();
    };

    virtual boolean IsActor(void) { return true; };
    virtual actor   *ToActor(void) { return this; };

//	#include "actext.hpp"                                           

};

class player : public actor
{   
public:
	int RemainningLifes;
	long Score;

//	:                      
	player(void){};
	
	
	player	(int _X, int _Y, int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[],
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			int _Timer, int _Period,
			int _DeltaX, int _DeltaY, boolean _EndsAtFirstFrame = true,
			boolean _IsVisible = false, int _Layer = 0  ) :
	actor( _X, _Y, _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,
			_BoundX, _BoundY, 
			_BoundWidth, _BoundHeight, 
			_Timer, _Period,
			_DeltaX, _DeltaY, _EndsAtFirstFrame,
			_IsVisible,_Layer  )
	{       
		RemainningLifes = 0;	
		Score = 0;
	};                                      
	
	player	(int _X, int _Y, int _NumberOfSprites, 
			int _Timer, int _Period,
			int _DeltaX, int _DeltaY, boolean _EndsAtFirstFrame = true,
			boolean _IsVisible = false, int _Layer = 0  ) :
	actor( _X, _Y, _NumberOfSprites, 
			_Timer, _Period,
			_DeltaX, _DeltaY, _EndsAtFirstFrame,
			_IsVisible,_Layer  )
	{       
		RemainningLifes = 0;	
		Score = 0;
	};                                      
/* 
    virtual void OccupScreen( screen *Screen )
    {
    };
		
    virtual void DesoccupScreen( screen *Screen )
    {
    };
*/		

//	virtual boolean CanGo( occup_screen *Screen);
    virtual boolean IsPlayer(void) { return true; };
    virtual player *ToPlayer(void) { return this; };


	virtual void Put( screen *Screen );
	virtual void Anim1Frame( HWND hwnd, screen *Screen );
	virtual void Move1Step( HWND hwnd, screen *Screen );


//	#include "plaext.hpp"                                           

};



class object_bag
{
public:                                       
 #define width 	right
 #define height 	bottom

	object *Objects[MAX_OBJECT_QTY];
	int NumberOfObjects;
//	RECT	DirtyRects[MAX_OBJECT_QTY];
	
	object_bag( void )
	{
		NumberOfObjects = 0;
	};
	
	int Insert( object *Object )
	{
//		register RECT *pRect;

		if( Object->InShowQueue )
		{   
/*			pRect = &DirtyRects[Object->PosShowQueue];
			
	  		if( pRect->width < Object->FrameWidth() )
	  		{
	  			pRect->width = Object->FrameWidth();
	  		}
	  		
	  		if( pRect->height < Object->FrameHeight() )
	  		{
	  			pRect->height = Object->FrameHeight();
	  		}
*/
			return Object->PosShowQueue;
		}                              
		
			
		if( NumberOfObjects == MAX_OBJECT_QTY )
		{
			MessageBox( "Erro Fatal!!", "Não foi posível inserir um objeto na lista de atualizações de tela\r\nAumente o valor da constante MAX_OBJECT_QTY" );
		}
		else
		{
/*			pRect = &DirtyRects[NumberOfObjects];
			
			if( Object->_OldX() < Object->X )
			{
				if( Object->_OldY() < Object->Y )
				{
			  		pRect->left  = Object->_OldX();
			  		pRect->top   = Object->_OldY();
	  			}
	  			else
	  			{
			  		pRect->left  = Object->_OldX();
			  		pRect->top   = Object->Y;
	  			}
	  		}   
	  		else
			{
				if( Object->_OldY() < Object->Y )
				{
			  		pRect->left  = Object->X;
			  		pRect->top   = Object->_OldY();
	  			}
	  			else
	  			{
			  		pRect->left  = Object->X;
			  		pRect->top   = Object->Y;
	  			}
	  		}   
	  		
	  		pRect->width = Object->FrameWidth()+Object->_DeltaX();
	  		pRect->height = Object->FrameHeight()+Object->_DeltaY();
*/
			Objects[NumberOfObjects] = Object;	  		                            
			Object->InShowQueue = true;
			Object->PosShowQueue = NumberOfObjects;
	  		                            
	  		NumberOfObjects++;
	  	}                          
	  	
	  	return NumberOfObjects-1;
	};                                    
	
	void Reset( void )
	{
		register int i = 0;

		for( i = 0; i < NumberOfObjects; i++ )
		{                               
			Objects[i]->InShowQueue = false;
			Objects[i]->ResetDirtyRect();
		}             

		NumberOfObjects = 0;
	};
	
	boolean IsEmpty( void )
	{
		return (boolean) (NumberOfObjects == 0);
	};
	
	void Refresh(HDC hdc, screen *Screen)
	{
		register int i = 0;
//		register RECT *pRect;
		register object *Object;
		

		SelectPalette(hdc,Screen->hpalApp,FALSE);
   		RealizePalette(hdc);

		for( i = 0; i < NumberOfObjects; i++ )
		{                               
/*			pRect = &DirtyRects[i];
			
			WinGBitBlt( hdc,pRect->left-Screen->ScreenX,pRect->top-Screen->ScreenY,
    					pRect->width, pRect->height, Screen->hBuffer, pRect->left, pRect->top); 
*/    					       
			Object = Objects[i];    
			
			WinGBitBlt( hdc,Object->X+Object->DirtyX-Screen->ScreenX,Object->Y+Object->DirtyY-Screen->ScreenY,
    					Object->DirtyW, Object->DirtyH, Screen->hBuffer, Object->X+Object->DirtyX, Object->Y+Object->DirtyY); 
    					
			Object->InShowQueue = false;
			Object->ResetDirtyRect();
		}             

		NumberOfObjects = 0;
	};

#undef width 	
#undef height 	
	
};

	    
#undef	DECLARE	    
