#include <windows.h>
#include <mmsystem.h>
#include <wing.h>  
#include <stdlib.h> 
#include <stdio.h>   
#include <string.h>

#include "utils.h" 
#include "tblt.h"

#ifdef _GAMEDEFS
	#define	DECLARE
#else
	#define DECLARE extern
#endif        


#define  DELTASCROLL 20
// #define  DELTA	  170	
//#define  BITMAPX 104
//#define  BITMAPY 100 
// #define  PASSO 18   //Tommy 


        
typedef enum { false, true } boolean;
// typedef enum { FALSE, TRUE } BOOL;

typedef unsigned int uint;


typedef struct header
{
  BITMAPINFOHEADER  Header;
  RGBQUAD           aColors[256];
} header;



typedef struct pal
{
  WORD Version;
  WORD NumberOfEntries;
  PALETTEENTRY aEntries[256];
} pal;


class object_list;                 
class object;     
class _3D_object;     
class moveable;
class player;

#ifdef _GAMEDEFS
	char unsigned TransparentColor	= 10; //6
	object_list *ObjectList = NULL;
#else
	extern char unsigned TransparentColor;
	extern object_list *ObjectList;
#endif


DECLARE long Orientation;


#ifdef __cplusplus
extern "C" {
#endif 

BOOL TransparentDIBBits( BITMAPINFO far *pBufferHeader,
          void huge *pBufferBits,
          int nXOriginDest, int nYOriginDest, void const far *pBits,
          BITMAPINFO const far *pBitmapInfo, int nXOriginSrc, int nYOriginSrc,
          int iUsage, char unsigned TransparentColor ); 
          
          
          
BOOL CopyDIBBits( BITMAPINFO far *pBufferHeader,
          void huge *pBufferBits,
          int nXOriginDest, int nYOriginDest, void const far *pBits,
          BITMAPINFO const far *pBitmapInfo, int nXOriginSrc, int nYOriginSrc,
          int iUsage );          

DECLARE WORD (FAR PASCAL *SetSystemTimer)( 	HWND hwnd, int nIDEvent, WORD wElapse,
									FARPROC lpTimerFunction );
									
DECLARE WORD (FAR PASCAL *KillSystemTimer)(	HWND hwnd, int nIDEvent );
									
									
#ifdef __cplusplus
		}
#endif 
                                                                        

char far * AddPointer( char far *p, long n );

typedef enum { MV_LEFT, MV_RIGHT, MV_UP, MV_DOWN } MVDIR;

                                                                        
#define HEIGHT_POWER	4
#define WIDTH_POWER		4                                 

#define	CELL_HEIGHT	(1<<HEIGHT_POWER)                                  
#define	CELL_WIDTH	(1<<WIDTH_POWER) 

#define MAX_OBJ_SCENE	50

#define	MAX_Y		1024
#define MAX_X		1280

#define MAX_LINES	(1+(MAX_Y/CELL_HEIGHT))
#define MAX_COLS	(1+(MAX_X/CELL_WIDTH))

// typedef enum { FREE, BORDER, USED, BUSY } occupation;
   
#define		FREE		((char) 0)
#define		WALL		((char) -1) // -1
   
#define 	occupation	char

class occup_matrix
{
public:
//	unsigned char far * far *Mat;
	occupation 	Mat[MAX_LINES][MAX_COLS];
	object *Obj[MAX_LINES][MAX_COLS];
	object *OccupObject,
		   *LastOccupObject;
	int NLines, NCols;
//	HGLOBAL hMatMem;

	occupation Occupation( int X, int Y, int Width, int Height, object * &OccupObj, occupation &lastocc );

	occupation Occupation( int X, int Y, int Width, int Height );

	occupation Occup( uint Line, uint Col )
	{
	 	return (occupation) Mat[Line][Col];
	};	

	occupation SetOccupation( int X, int Y, occupation Occup, object *o = NULL )
	{
		if( X < 0 || Y < 0 )
		{
			return Occup;
		}
		else
		{
			Obj[Y>>HEIGHT_POWER][X>>WIDTH_POWER] = o;
			return (occupation) (Mat[Y>>HEIGHT_POWER][X>>WIDTH_POWER] = (char) Occup);	
		}
	}	                                                

	occupation SetOccup( int Line, int Col, occupation Occup, object *o = NULL )
	{
		Obj[Line][Col] = o;
		
		return (occupation) (Mat[Line][Col] = (unsigned char) Occup);	
	};	                                                


	occupation IncrOccup( int Line, int Col, object *o )
	{
			Obj[Line][Col] = o;

//			if( Mat[Line][Col] != WALL )		
			if( Mat[Line][Col] >= FREE )		
			{
				return (occupation) (++Mat[Line][Col]);	
			}
			else
			{
				return (occupation) (--Mat[Line][Col]);	

//				Mat[Line][Col] = 1;
//				return (char) 1;
			}
	}	                                                

	occupation DecrOccup( int Line, int Col, object * o )
	{
			Obj[Line][Col] = NULL;
			
			if( Mat[Line][Col] >= FREE )		
			{
				return (occupation) (--Mat[Line][Col]);	
			}
			else
			{
//				return WALL;
				return (occupation) (++Mat[Line][Col]);	
			}
	}	                                                



//	occupation IncrOccupation( int X, int Y, int Width, int Height )
	occupation IncrOccupation( object *o );

//	occupation DecrOccupation( int X, int Y, int Width, int Height )
	occupation DecrOccupation( object *o );


	occup_matrix( uint BufferWidth, uint BufferHeight )
	{      
		register int i = 0, j = 0;
		           
		NLines = 1+(BufferHeight >> HEIGHT_POWER);
		NCols  = 1+(BufferWidth  >> WIDTH_POWER); 
		
		for(i=0; i<NLines; i++)
		{
			for(j=0; j<NCols; j++)
			{
				SetOccup(i,j,FREE);
//				Mat[i][j] = ((unsigned char) FREE);
			}
		}
                 
		LastOccupObject = OccupObject = NULL;                 
		
//      hMatMem = GlobalAlloc( GMEM_ZEROINIT | GMEM_MOVEABLE, NLines * NCols );
//		Mat = (unsigned char far * far *) GlobalLock( hMatMem );
	};
	
	~occup_matrix( void )	
	{
//		GlobalUnlock( hMatMem );
//		GlobalFree( hMatMem );
	};


};



class screen
{       
public:                
	HDC 	hBuffer;
	void far *pBuffer;
	PDIB pBack ;
			
	int 	BufferWidth,
			BufferHeight;
			
	int		ScreenX,
			ScreenY;     
			
	int		ScreenWidth,
			ScreenHeight;     

	int 	PaletteOffSet, 
			NumColors;
		        
	HPALETTE  hpalApp;
	HBITMAP  gbmOldMonoBitmap;
	
	header BufferHeader;


	virtual screen *Init( HWND hwnd );

	screen (void) {};
							
	screen( char *BackName, 
			int	_ScreenX = 0, int _ScreenY = 0, 
			int _ScreenWidth = 640, int _ScreenHeight = 480 )
	{
		                    
   		pBack   = DibOpenFile( BackName );
   
	    BufferWidth = DibWidth(pBack);
    	BufferHeight = DibHeight(pBack);

		                    
		gbmOldMonoBitmap = 0;

		ScreenX = _ScreenX;
		ScreenY = _ScreenY;     
			
		ScreenWidth = _ScreenWidth;
		ScreenHeight = _ScreenHeight;     
	
//		Init( hwnd, pBack );
	            
	};
						

	~screen(void)
	{
    	HBITMAP hbm;

    //  Retrieve the current WinGBitmap, replace with the original
    	hbm   = (HBITMAP)SelectObject(hBuffer, gbmOldMonoBitmap);
    
    //  And delete the WinGBitmap and WinGDC
    	DeleteObject(hbm);
    	DeleteDC(hBuffer);

    	DeleteObject(hpalApp);
	} 

	void Show(HDC hdc)
	{
	  WinGBitBlt(	hdc,0,0,ScreenWidth,ScreenHeight,
	  				hBuffer, ScreenX, ScreenY);  
	};	

	void Paint( void )
	{
        CopyDIBits((BITMAPINFO far *)&BufferHeader,pBuffer,
          0, 0, DibPtr(pBack) ,DibInfo(pBack), DIB_RGB_COLORS,0,0);
    };

	void UpdateBufferSize( void )
	{
        BufferHeader.Header.biWidth = BufferWidth;
        BufferHeader.Header.biHeight = BufferHeight; 
	};

	void SetBufferSize( int Width, int Height )
	{
        BufferHeader.Header.biWidth = Width;
        BufferHeader.Header.biHeight = Height; 
	};


	virtual boolean CantGo( int X, int Y, int Width, int Height )
	{
		return false;
	}

	virtual boolean CanGo( int X, int Y, int Width, int Height )
	{
		return true;
	}

//	virtual int IncrOccupation( int X, int Y, int Width, int Height )
	virtual int IncrOccupation( object *o )
	{
		return 1;
	}

//	virtual int DecrOccupation( int X, int Y, int Width, int Height )
	virtual int DecrOccupation( object *o )
	{
		return 1;
	}

	virtual void Set3DPosition( object *o, int _z = 0)
	{
	}

	virtual screen *SetVanishingPoint(int _XV, int _YV)
	{
		return this;
	}
	
	boolean TestScroll(HDC hdc, moveable *Object, int AuxX, int AuxY );
	long InitBufferHeader( void );  
	void ReserveWindowsPalette( pal &LogicalPalette );  
	void FillPalette( pal &LogicalPalette );  

	virtual screen *SetViewPoint(int _X, int _Y, int _x, int _y, int _z)
	{                               
		return this;
	}

	virtual screen *SetyAxisShift( int _X, int _Y )
	{
		return this;
	}
};    
  

class occup_screen : public screen
{               
public:
	occup_matrix *Occup;
		
	occup_screen(void) { };
					
	occup_screen( char *BackName, 
			int	_ScreenX = 0, int _ScreenY = 0, 
			int _ScreenWidth = 640, int _ScreenHeight = 480 ) :
	screen( BackName, 
			_ScreenX, _ScreenY, 
			_ScreenWidth,_ScreenHeight )
	{};                       
	            
	virtual screen *Init( HWND hwnd )
	{
	 	screen::Init( hwnd );
	 	
	 	Occup = new occup_matrix( BufferWidth, BufferHeight );
	 	
	 	return this;
	}	            
	           
	virtual boolean CanGo( int X, int Y, int Width, int Height )
	{                 
		object *o;    
		occupation occ, lastocc;
		
		occ = Occup->Occupation(X, Y, Width, Height, o, lastocc);
	
		return (boolean) (occ == FREE);
	}

	
	virtual boolean CantGo( int X, int Y, int Width, int Height )
	{
		return (boolean) (!occup_screen::CanGo(X, Y, Width, Height));
	}

//	virtual int IncrOccupation( int X, int Y, int Width, int Height )
	virtual int IncrOccupation( object *o )
	{
		return Occup->IncrOccupation(o);
	}

//	virtual int DecrOccupation( int X, int Y, int Width, int Height )
	virtual int DecrOccupation( object *o )
	{
		return Occup->DecrOccupation(o);
	}

	~occup_screen(void) 
	{
		delete Occup;
	};
					

};


class _3D_screen : public occup_screen
{
public:
	int XV, YV;		// Screen Coordinates of the Vanishing Points;
	
	int v;			// Distance between the viewpoint and the screen; assumed 3*ScreenWidth

	int DX;			// Correction of the x coordinate when the 3D origin is shifted to left or right.
	
	int xv, yv, zv;	// 3D coordinates of the view point

	_3D_screen( char *BackName, 
			int	_ScreenX = 0, int _ScreenY = 0, 
			int _ScreenWidth = 640, int _ScreenHeight = 480 ) :
	occup_screen( BackName, 
			_ScreenX, _ScreenY, 
			_ScreenWidth,_ScreenHeight )
	{
			                    
	};
	
        
        
	virtual void Set3DPosition( _3D_object *o, int _z = 0);

/*
	virtual screen *Init( HWND hwnd )
	{
		occup_screen::Init(hwnd);	

	  	return this;
	}; 
	
*/
	virtual screen *SetVanishingPoint(int _XV, int _YV)
	{
	  	XV = _XV;
	  	YV = ScreenHeight-_YV;
	  	
	  	return this;
	};

	virtual screen *SetViewPoint(int _X, int _Y, int _x, int _y, int _z)
	{               
		_Y = ScreenHeight-_Y;

		xv = _x;
		yv = -_y;
		zv = _z;
				
	  	v = ((long)_y) * ((long)( _Y - YV))/((long)(_z - _Y));
	  	
	  	return this;
	};
                                    
	virtual screen *SetyAxisShift( int _X, int _Y )
	{               
		_Y = ScreenHeight-_Y;
		
		if( _X == 0 )
		{
		    DX = ((long)XV)*((long)_Y)/((long)(YV-_Y));
	  	}                      
	  	else
	  	{
	  		DX = -_X;
	  	}
	  	
	  	return this;
	};
                                    

	                                    


};


/*

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

*/

class sprite
{
public:
//	frame *Frames;                          
	
	unsigned 
	int FrameWidth,
		FrameHeight;
		
	unsigned 
	int NumberOfFrames; // number of frames                              
                              
	PDIB pBitMap; 

	sprite(void)
	{
		NumberOfFrames = 0;
		pBitMap = NULL;	
	}
		
	void Init( PDIB _pBitMap, int _NumberOfFrames, 
	  	  int _FrameWidth, int _FrameHeight )
	{
		   pBitMap = _pBitMap;
		   NumberOfFrames = _NumberOfFrames;

		   FrameWidth  = _FrameWidth;
		   FrameHeight = _FrameHeight;

		   
//		   Frames = new frame[NumberOfFrames];

//		   SetBitMaps( _pBitMap );

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
//	 	delete Frames;
	};

/*
	virtual void far * Frame( int FrameNumber ) // operator []
	{
	  	return	Frames[FrameNumber].pImage;    
	};
*/
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
protected:	
	object *FirstObject;
public:	

	object_list( object * _FirstObject = NULL )
	{
		FirstObject = _FirstObject;
	};
	
	void ReservePalette( header &BufferHeader,pal &LogicalPalette );  
	void PutIntoBuffer( HDC hBuffer, header &BufferHeader, void far *pBuffer );  
	
	friend class object;
};
    

class object
{
public:

	object  *Next,
			*Prev;
			
	int Layer;

	int	X, Y; // 2D coordinates of the object in the buffer of the screen


	        
	int PaletteOffSet, 
		NumColors;
		        
	sprite *Sprites; // all of them must have the same palette range
	    
	uint NumberOfSprites;
	uint CurrentSprite;
	
	uint CurrentFrame;

	HDC hBackBuffer; // with size equal to the biggest frame size
	void far *pBackBuffer;
	header BufferHeader;
	
	HBITMAP gBackOldMonoBitmap;

	boolean IsVisible;


	int BoundX,
		BoundY;
		
	int BoundWidth,
		BoundHeight;  
		

	virtual int x3D(void) { return 0; };
	virtual int y3D(void) { return 0; };
	virtual int z3D(void) { return 0; };
	virtual int w3D(void) { return 0; };
	virtual int h3D(void) { return 0; };
	virtual int d3D(void) { return 0; };
	
	virtual object * DrawSolid( HDC hdc, _3D_screen *Screen ) 
	{
		return this;
	};

	virtual object * DrawSolid( HWND hwnd, _3D_screen *Screen ) 
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
    
/*    
	void far * Frame( void )
	{
		return Sprite().Frame(CurrentFrame);
	};
*/    
	int FrameWidth(void)
	{
		return Sprite().FrameWidth;
	};
    	        
	int FrameHeight(void)
	{
		return Sprite().FrameHeight;	
//		return Sprite().FrameHeight*Orientation;	
	};
    	        
	int FrameX(void)
	{
		return Sprite().FrameX(CurrentFrame);
	};
    	        
	int FrameY(void)
	{
		return Sprite().FrameY(CurrentFrame);	
	};
    	        
	int NumberOfFrames(void)
	{
		return Sprite().NumberOfFrames;
	};
    	        
	void SaveBackGround( HDC hBuffer )
	{
		BitBlt(hBackBuffer,0,0,FrameWidth(), 
     			FrameHeight(), hBuffer, X, Y, SRCCOPY);	
	};

	void RestoreBackGround( HDC hBuffer )
	{
      	BitBlt(hBuffer,X,Y,FrameWidth(), 
      			FrameHeight(), hBackBuffer, 0, 0, SRCCOPY);	
	};

	void PutIntoBuffer( BITMAPINFO far * pBufferHeader, void far *pBuffer )
	{
/*
      	TransparentDIBits(	pBufferHeader, pBuffer, X, Y,
      						Frame(),DibInfo(pBitMap()),
      						0,0,DIB_RGB_COLORS,
    						TransparentColor );              
*/      	
      	TranspDIBits(	pBufferHeader, pBuffer, X, Y,
      						DibPtr(pBitMap()),DibInfo(pBitMap()),
      						FrameX(),FrameY(),
      						FrameWidth(), FrameHeight(),
      						DIB_RGB_COLORS,	TransparentColor );              
	};
    
	virtual void Put(screen *Screen )
	{
		PutIntoBuffer( (BITMAPINFO far * )&(Screen->BufferHeader), 
						Screen->pBuffer );
	};


	virtual void Paint(screen *Screen )
	{
		RestoreBackGround( Screen->hBuffer );
		
		PutIntoBuffer( (BITMAPINFO far * )&(Screen->BufferHeader), 
						Screen->pBuffer );
	};


	virtual void Hide( HDC hdc, screen *Screen )
	{

    // Restore the Background
		RestoreBackGround( Screen->hBuffer );

    // Restore the Background
    	WinGBitBlt( hdc,X-Screen->ScreenX,Y-Screen->ScreenY,
    			FrameWidth(), FrameHeight(), Screen->hBuffer, X,Y); 
	}
	
	virtual void Show( HDC hdc, screen *Screen )
	{
	// Show the object
		WinGBitBlt( hdc,X-Screen->ScreenX,Y-Screen->ScreenY,
    			FrameWidth(), FrameHeight(), Screen->hBuffer, X,Y); 
	};
	
	                           
	RGBQUAD far *pColorTable(void)	
	{
		  return (RGBQUAD far *)
		   (((char far *)pBitMap()) + pBitMap()->biSize);
    };

	virtual int NextFrame(void)  // operator ++
	{
		return 0;
	};	                          
	
	virtual int PreviousFrame(void)
	{
		return 0;
	};	                           
	

	object(void) {};
		
	object( int _X, int _Y, 
			char *BMPName, int _NumberOfFrames, 
			int BMPWidth, int BMPHeight,
			boolean _IsVisible = true, int _Layer = 0  )
	{
		
		if( ObjectList == NULL )		
		{
			ObjectList = new object_list(this);
			Next = Prev = NULL;
		}
		else
		{	
			Next = ObjectList->FirstObject;
			Prev = NULL;
		
			ObjectList->FirstObject->Prev = this;
		
			ObjectList->FirstObject = this;
		}

		X = _X;
		Y = _Y;                         
		Layer = _Layer;
		IsVisible = _IsVisible;
    
    	CurrentSprite = 0;
    	CurrentFrame  = 0;
    	NumberOfSprites = 1;

		BoundX = 0;
		BoundY = 0;
		
		BoundWidth  = BMPWidth;
		BoundHeight = BMPHeight;
		
		Sprites = new sprite;

		Sprites->Init( DibOpenFile(BMPName),
						_NumberOfFrames, BMPWidth, BMPHeight);
    
	};
	
	object( int _X, int _Y, 
			char *BMPName, int _NumberOfFrames, 
			int BMPWidth, int BMPHeight,
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			boolean _IsVisible = true, int _Layer = 0  )
	{
		
		if( ObjectList == NULL )		
		{
			ObjectList = new object_list(this);
			Next = Prev = NULL;
		}
		else
		{	
			Next = ObjectList->FirstObject;
			Prev = NULL;
		
			ObjectList->FirstObject->Prev = this;
		
			ObjectList->FirstObject = this;
		}

		X = _X;
		Y = _Y;                         
		Layer = _Layer;
		IsVisible = _IsVisible;
    
    	CurrentSprite = 0;
    	CurrentFrame  = 0;
    	NumberOfSprites = 1;

		BoundX = _BoundX;
		BoundY = _BoundY;
		
		BoundWidth  = _BoundWidth;
		BoundHeight = _BoundHeight;
		
		Sprites = new sprite;

		Sprites->Init( DibOpenFile(BMPName),
						_NumberOfFrames, BMPWidth, BMPHeight);
    
	};
	
	
	
	object( int _X, int _Y, int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[],
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			boolean _IsVisible = true, int _Layer = 0  )
	{
		if( ObjectList == NULL )		
		{
			ObjectList = new object_list(this);
			Next = Prev = NULL;
		}
		else
		{	
			Next = ObjectList->FirstObject;
			Prev = NULL;
		
			ObjectList->FirstObject->Prev = this;
		
			ObjectList->FirstObject = this;
		}

		X = _X;
		Y = _Y;                         
		Layer = _Layer;
		IsVisible = _IsVisible;
    
    	CurrentSprite = 0;
    	CurrentFrame  = 0;
    	NumberOfSprites = _NumberOfSprites;

		BoundX = _BoundX;
		BoundY = _BoundY;
		
		BoundWidth  = _BoundWidth;
		BoundHeight = _BoundHeight;
		
		Sprites = new sprite[NumberOfSprites];
    	
    	for( uint i=0; i<NumberOfSprites; i++ )
    	{   
			Sprites[i].Init( DibOpenFile(BMPName[i]),
						BMPFrames[i], BMPWidth[i], BMPHeight[i]);
    	}
    
	};

	object( int _X, int _Y, int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[],
			boolean _IsVisible = true, int _Layer = 0  )
	{
		if( ObjectList == NULL )		
		{
			ObjectList = new object_list(this);
			Next = Prev = NULL;
		}
		else
		{	
			Next = ObjectList->FirstObject;
			Prev = NULL;
		
			ObjectList->FirstObject->Prev = this;
		
			ObjectList->FirstObject = this;
		}

		X = _X;
		Y = _Y;                         
		Layer = _Layer;
		IsVisible = _IsVisible;
    
    	CurrentSprite = 0;
    	CurrentFrame  = 0;
    	NumberOfSprites = _NumberOfSprites;

		BoundX = 0;
		BoundY = 0;
		
		BoundWidth  = BMPWidth[0];
		BoundHeight = BMPHeight[0];
		
		Sprites = new sprite[NumberOfSprites];
    	
    	for( uint i=0; i<NumberOfSprites; i++ )
    	{   
			Sprites[i].Init( DibOpenFile(BMPName[i]),
						BMPFrames[i], BMPWidth[i], BMPHeight[i]);
    	}
    
	};

    
    virtual void OccupScreen( screen *Screen )
    {
		Screen->IncrOccupation( this );    
    };
		
    virtual void DesoccupScreen( screen *Screen )
    {
		Screen->DecrOccupation( this );    
    };
		
	object *Init( screen *Screen );

	
	~object(void)
	{
    	HBITMAP hback;
	
    //  Retrieve the current WinGBitmap, replace with the original
    	hback = (HBITMAP)SelectObject(hBackBuffer, gBackOldMonoBitmap);
    
    //  And delete the WinGBitmap and WinGDC
    	DeleteObject(hback);
    
    	DeleteDC(hBackBuffer);
	};


protected:

//	object( int _NumberOfSprites, 
	void InitAnimated( int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[] )
	{
    	NumberOfSprites = _NumberOfSprites;

		Sprites = new sprite[NumberOfSprites];
    	
    	for( uint i=0; i<NumberOfSprites; i++ )
    	{   
			Sprites[i].Init( DibOpenFile(BMPName[i]),
						BMPFrames[i], BMPWidth[i], BMPHeight[i]);
    	}
    
	};

//	object( 
	void InitAnimated( 
			char *BMPName, int BMPFrames, 
			int BMPWidth, int BMPHeight )
	{
    	NumberOfSprites = 1;

		Sprites = new sprite;
    	
		Sprites->Init( DibOpenFile(BMPName),
					BMPFrames, BMPWidth, BMPHeight);
    
	};

//	object( int _X, int _Y, 
	void InitMoveable( int _X, int _Y, 
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			boolean _IsVisible = true, int _Layer = 0  )
	{
		if( ObjectList == NULL )		
		{
			ObjectList = new object_list(this);
			Next = Prev = NULL;
		}
		else
		{	
			Next = ObjectList->FirstObject;
			Prev = NULL;
		
			ObjectList->FirstObject->Prev = this;
		
			ObjectList->FirstObject = this;
		}

		X = _X;
		Y = _Y;                         
		Layer = _Layer;
		IsVisible = _IsVisible;
    
    	CurrentSprite = 0;
    	CurrentFrame  = 0;

		BoundX = _BoundX;
		BoundY = _BoundY;
		
		BoundWidth  = _BoundWidth;
		BoundHeight = _BoundHeight;
		
	};
	


        
};


class animated : virtual public object
{
public:
	int Timer2, Period2;
	
    animated(void) {};
    
	animated(int _X, int _Y, int _NumberOfSprites, 
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
		Timer2 = _Timer;
		Period2 = _Period;

		InitMoveable( 	_X, _Y, 
						_BoundX, _BoundY, 
						_BoundWidth, _BoundHeight, 
						_IsVisible,_Layer  );

		InitAnimated( _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight);

	};

	animated(int _X, int _Y, int _NumberOfSprites, 
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
		Timer2 = _Timer;
		Period2 = _Period;

		InitMoveable( 	_X, _Y, 
						0,0,
						BMPWidth[0], BMPHeight[0], 
						_IsVisible,_Layer  );

		InitAnimated( _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight);

	};

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
    		HBITMAP hback;
    		                             
			HDC hdc = GetDC(hwnd);
			    		                          
			RestoreBackGround( Screen->hBuffer );
		    
		    Show(hdc, Screen);


    		hback = (HBITMAP)SelectObject(hBackBuffer, gBackOldMonoBitmap);
    
    		DeleteObject(hback);
    

        	BufferHeader.Header.biWidth  = NewSprite->FrameWidth; 
        	BufferHeader.Header.biHeight = NewSprite->NumberOfFrames*NewSprite->FrameHeight;
                           
			pBackBuffer = NULL;
			                           
        	hback = WinGCreateBitmap(hBackBuffer,
        	(BITMAPINFO far *)&BufferHeader , &pBackBuffer);   
        	
        	gBackOldMonoBitmap = (HBITMAP)SelectObject(hBackBuffer, hback);
        	
        	     
        	CurrentSprite = SpriteNumber;
    		CurrentFrame = 0;
        	
			SaveBackGround(Screen->hBuffer);
        	Paint(Screen);
        	object::Show(hdc, Screen);

			ReleaseDC(hwnd, hdc);
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

	virtual void InitAnim( HWND hwnd, occup_screen *Screen );
	virtual void EndAnim( HWND hwnd, occup_screen *Screen );
	virtual void EndAnim( HWND hwnd, HDC hdc, occup_screen *Screen );
	virtual void Anim1Frame( HWND hwnd, occup_screen *Screen);

	virtual void StopAnim( HWND hwnd );

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
	int	NewX, NewY;

    int AuxX, AuxY;
    int DeltaX, DeltaY,
    	DistX, DistY;    
	int Dist, Counter;    	
	int IncrNE, IncrE, IncrN;

	int Timer,
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
		InitMoveable( 	_X, _Y, 
						_BoundX, _BoundY, 
						_BoundWidth, _BoundHeight, 
						_IsVisible,_Layer  );


		InitAnimated( _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight);

	
		NewX = OldX = X;
		NewY = OldY = Y;     
		
		Timer = _Timer;
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
		InitMoveable( 	_X, _Y, 
						0,0,
						BMPWidth[0], BMPHeight[0], 
						_IsVisible,_Layer  );


		InitAnimated( _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight);

	
		NewX = OldX = X;
		NewY = OldY = Y;     
		
		Timer = _Timer;
		Period = _Period;                    

    	DeltaX=_DeltaX;
    	DeltaY=_DeltaY;
    	
    	Moving = false;

	};		           

    virtual void SetPosition(int _X, int _Y)
	{
		OldX = X;
		OldY = Y;

      	X = _X;
      	Y = _Y;     
      	
	};

	virtual void Paint(int _X, int _Y, screen *Screen )
	{
		RestoreBackGround( Screen->hBuffer );

		DesoccupScreen( Screen );
				
		SetPosition(_X,_Y);      
		
		OccupScreen( Screen );
		
		SaveBackGround( Screen->hBuffer ); 		

		PutIntoBuffer( (BITMAPINFO far * )&(Screen->BufferHeader), 
						Screen->pBuffer );

	};

	virtual void Show( HDC hdc, screen *Screen )
	{
    // Restore the Background in the screen
    	WinGBitBlt( hdc,OldX-Screen->ScreenX,OldY-Screen->ScreenY,
    			FrameWidth(), FrameHeight(), Screen->hBuffer, OldX,OldY); 

	// Show the object at the screen
		if( OldX != X || OldY != Y )
		{
			object::Show( hdc, Screen );
		}
			
//		WinGBitBlt( hdc,X-Screen->ScreenX,Y-Screen->ScreenY,
//    			FrameWidth(), FrameHeight(), Screen->hBuffer, X,Y); 

	};


	virtual boolean CanGo( occup_screen *Screen);
//	boolean DetectedCollision( object *o );
	virtual boolean DetectedCollision( object *o, screen *Screen );
	virtual boolean CantGo( occup_screen *Screen)
	{
		return (boolean) !CanGo( Screen );
	};

	                           
	boolean	FinishedMovement( void );
	void 	PlanNextPosition( void );

	virtual void InitMove( HWND hwnd, int _NewX, int _NewY, occup_screen *Screen );
	virtual void InitHMove( HWND hwnd, occup_screen *Screen, MVDIR Direction );
	virtual void InitVMove( HWND hwnd, occup_screen *Screen, MVDIR Direction );
	virtual void EndMove( HWND hwnd, occup_screen *Screen );
	virtual void EndMove( HWND hwnd, HDC hdc, occup_screen *Screen );

	virtual void Move1Step( HWND hwnd, occup_screen *Screen);

	void Move( HDC hdc, int NewX, int NewY, screen *Screen);
//	void Move( int NewX, int NewY ) { };		


protected:

	moveable(int _X, int _Y, 
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			int _Timer, int _Period,
			int _DeltaX = 20, int _DeltaY = 20,
			boolean _IsVisible = true, int _Layer = 0  ) 
//	object( _X, _Y, _IsVisible,_Layer  )
	{
	
		InitMoveable( 	_X, _Y, 
						_BoundX, _BoundY, 
						_BoundWidth, _BoundHeight, 
						_IsVisible,_Layer  );

	
		NewX = OldX = X;
		NewY = OldY = Y;     
		
		Timer = _Timer;
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
			int _DeltaX, int _DeltaY,
			boolean _IsVisible = true, int _Layer = 0  ) :
	moveable( _X, _Y,               
			_BoundX, _BoundY, 
			_BoundWidth, _BoundHeight, 
			_Timer, _Period,
			_DeltaX, _DeltaY,
			_IsVisible,_Layer  )
/*	animated( _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight)
*/	{
		InitAnimated( _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight);


		Timer2 = _Timer;
		Period2 = _Period;
		
	};
	

	virtual void Move1Step( HWND hwnd, occup_screen *Screen)
	{
		if( Moving )
		{
			animated::NextFrame();
			moveable::Move1Step( hwnd, Screen );
		}
	};

	virtual void EndMove( HWND hwnd, occup_screen *Screen )
	{
	 	SetCurrentSprite( hwnd, Screen, 0 );
	 	moveable::EndMove(hwnd, Screen);
	};
	
	virtual void EndMove( HWND hwnd, HDC hdc, occup_screen *Screen )
	{
	 	SetCurrentSprite( hwnd, Screen, 0 );
	 	moveable::EndMove(hwnd, hdc, Screen);
	};
	

	virtual void EndAnim( HWND hwnd, occup_screen *Screen )
	{
	 	SetCurrentSprite( hwnd, Screen, 0 );
	 	animated::EndAnim(hwnd, Screen);
	};

	virtual void EndAnim( HWND hwnd, HDC hdc, occup_screen *Screen )
	{
	 	SetCurrentSprite( hwnd, Screen, 0 );
	 	animated::EndAnim(hwnd, hdc, Screen);
	};



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
			int _DeltaX, int _DeltaY,
			boolean _IsVisible = true, int _Layer = 0  ) :
	actor( _X, _Y, _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,
			_BoundX, _BoundY, 
			_BoundWidth, _BoundHeight, 
			_Timer, _Period,
			_DeltaX, _DeltaY,
			_IsVisible,_Layer  )
	{       
		RemainningLifes = 0;	
		Score = 0;
	};                                      
	
 
    virtual void OccupScreen( screen *Screen )
    {
    };
		
    virtual void DesoccupScreen( screen *Screen )
    {
    };
		



};


class _3D_object : virtual public object
{

public:
	
	int x,y,z; // 3D coordinates
	
	int w,h,d; // 3D dimensions in pixels
	
	int X3DO, Y3DO; // Position of the 3D origin in the frame. The Botton-Left-Front corner.

        
        
	virtual int x3D(void); // { return x; };
	virtual int y3D(void); // { return y; };
	virtual int z3D(void); // { return z; };
	virtual int w3D(void); // { return w; };
	virtual int h3D(void); // { return h; };
	virtual int d3D(void); // { return d; };
        

	virtual _3D_object *Init( _3D_screen *Screen );

	virtual _3D_object *Set3DPosition( _3D_screen *Screen, int _z = 0 ); // Determines the 3D position from the 2D ones.

	virtual _3D_object *Set3DOrigin( int _X3DO, int _Y3DO );
	virtual _3D_object *Set3DDimensions( int width, int height, int depth );
        
	virtual object * DrawSolid( HWND hwnd, _3D_screen *Screen );
	virtual object * DrawSolid( HDC hdc, _3D_screen *Screen );

	virtual void TreatCollision( HDC hdc, _3D_screen *Screen);
	
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
		InitMoveable( 	_X, _Y, 
						_BoundX, _BoundY, 
						_BoundWidth, _BoundHeight, 
						_IsVisible,_Layer  );

		InitAnimated( _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight);

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
		InitMoveable( 	_X, _Y, 
						0,0,
						BMPWidth[0], BMPHeight[0], 
						_IsVisible,_Layer  );

		InitAnimated( _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight);

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
		InitMoveable( 	_X, _Y, 
						0,0,
						BMPWidth, BMPHeight, 
						_IsVisible,_Layer  );

		InitAnimated( 
			BMPName, _NumberOfFrames, 
			BMPWidth, BMPHeight);

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
			int _Timer, int _Period,
			boolean _IsVisible = true, int _Layer = 0  ) :
	animated( _X, _Y,  _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,             
			_BoundX, _BoundY, 
			_BoundWidth, _BoundHeight, 
			_Timer, _Period,
			_IsVisible,_Layer  )
	{
	};
	
	virtual void Anim1Frame( HWND hwnd, _3D_screen *Screen);

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
	};
	

	virtual boolean DetectedCollision( object *o, _3D_screen *Screen );
	virtual boolean CanGo( _3D_screen *Screen);

	virtual _3D_object *Set3DPosition( _3D_screen *Screen, int _z = 0 ); // Determines the 3D position from the 2D ones.

    virtual void SetPosition(int _X, int _Y, _3D_screen *Screen)
	{
      	moveable::SetPosition( _X, _Y );
      		
      	Set3DPosition( Screen );       
      	
	};

	virtual void Paint(int _X, int _Y, _3D_screen *Screen )
	{
		RestoreBackGround( Screen->hBuffer );
		
		SetPosition(_X,_Y, Screen);
		
		SaveBackGround( Screen->hBuffer ); 		

		PutIntoBuffer( (BITMAPINFO far * )&(Screen->BufferHeader), 
						Screen->pBuffer );

	};

	virtual void Show( HDC hdc, screen *Screen )
	{
		    
		moveable::Show( hdc, Screen );
		
		char Buff[50];

		sprintf( Buff, "(%03d,%03d)=>(%03d,%03d,%03d)", X+X3DO, Screen->ScreenHeight-Y-Y3DO,
															x,y,z);
		TextOut(hdc, 400, 10, Buff, strlen(Buff));

	};

	virtual void Move1Step( HWND hwnd, _3D_screen *Screen);

	virtual void EndMove( HWND hwnd, _3D_screen *Screen );
	virtual void EndMove( HWND hwnd, HDC hdc, _3D_screen *Screen );


};




class _3D_actor : public _3D_moveable, public _3D_animated
{
public:
	_3D_actor(void) {};

	_3D_actor(int _X, int _Y, int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[],
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			int _Timer, int _Period,
			int _DeltaX, int _DeltaY,
			boolean _IsVisible = true, int _Layer = 0  ) :
	_3D_moveable( _X, _Y,  _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,             
			_BoundX, _BoundY, 
			_BoundWidth, _BoundHeight, 
			_Timer, _Period,
			_DeltaX, _DeltaY,
			_IsVisible,_Layer  )
	{
		Timer2 = _Timer;
		Period2 = _Period;
		
	};
	

	virtual void Move1Step( HWND hwnd, _3D_screen *Screen)
	{
		if( Moving )
		{
			_3D_animated::NextFrame();
			_3D_moveable::Move1Step( hwnd, Screen );
		}
	};


	virtual void EndMove( HWND hwnd, _3D_screen *Screen )
	{
	 	SetCurrentSprite( hwnd, Screen, 0 );
	 	_3D_moveable::EndMove(hwnd, Screen);
	};
	
	virtual void EndMove( HWND hwnd, HDC hdc, _3D_screen *Screen )
	{
	 	SetCurrentSprite( hwnd, Screen, 0 );
	 	_3D_moveable::EndMove(hwnd, hdc, Screen);
	};
	

	virtual void EndAnim( HWND hwnd, _3D_screen *Screen )
	{
	 	SetCurrentSprite( hwnd, Screen, 0 );
	 	_3D_animated::EndAnim(hwnd, Screen);
	};

	virtual void EndAnim( HWND hwnd, HDC hdc, _3D_screen *Screen )
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
//	:                      
	
	_3D_player(void){};
	
	
	_3D_player(int _X, int _Y, int _NumberOfSprites, 
			char *BMPName[], int BMPFrames[], 
			int BMPWidth[], int BMPHeight[],
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			int _Timer, int _Period,
			int _DeltaX, int _DeltaY,
			boolean _IsVisible = true, int _Layer = 0  ) :
	_3D_actor( _X, _Y, _NumberOfSprites, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,
			_BoundX, _BoundY, 
			_BoundWidth, _BoundHeight, 
			_Timer, _Period,
			_DeltaX, _DeltaY,
			_IsVisible,_Layer  )
	{       
	};                                      
	
 
    virtual void OccupScreen( screen *Screen )
    {
    };
		
    virtual void DesoccupScreen( screen *Screen )
    {
    };
		
};



	
	
	



	    
	    