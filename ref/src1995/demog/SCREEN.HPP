
#ifdef _SCREEN
	#define	DECLARE
#else
	#define DECLARE extern
#endif        


#define  DELTASCROLL 20

                                                                        
#define H_POWER		4
#define W_POWER		4                                 

#define	CELL_HEIGHT	(1<<H_POWER)                                  
#define	CELL_WIDTH	(1<<W_POWER) 

#define MAX_OBJ_SCENE	50

#define	MAX_Y		1024
#define MAX_X		1280

#define MAX_LINES	(1+(MAX_Y/CELL_HEIGHT))
#define MAX_COLS	(1+(MAX_X/CELL_WIDTH))

// typedef enum { FREE, BORDER, USED, BUSY } occupation;
   
#define		FREE		((char) 0)
#define		WALL		((char) -1) // -1
   
#define 	occupation	char
    
class object;    
    
DECLARE occupation 	Mat[MAX_LINES][MAX_COLS];
DECLARE object *Obj[MAX_LINES][MAX_COLS];

class occup_matrix
{
public:
//	unsigned char far * far *Mat;
//	occupation 	Mat[MAX_LINES][MAX_COLS];
//	object *Obj[MAX_LINES][MAX_COLS];
	object *OccupObject,
		   *LastOccupObject;
	int NLines, NCols;
	
	int HEIGHT_POWER, WIDTH_POWER;
	
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
			
			if( Mat[Line][Col] > FREE )		
			{
				return (occupation) (--Mat[Line][Col]);	
			}
			else
			{
//				return WALL;
				return (occupation) (++Mat[Line][Col]);	
			}
	}	                                                



	occupation IncrOccupation( object *o );

	occupation DecrOccupation( object *o );


	occup_matrix( uint BufferWidth, uint BufferHeight, uint _WIDTH_POWER = W_POWER, uint _HEIGHT_POWER = H_POWER )
	{      
		register int i = 0, j = 0;
	
		HEIGHT_POWER = _HEIGHT_POWER; 
		WIDTH_POWER  = _WIDTH_POWER;
		           
		NLines = 1+(BufferHeight >> HEIGHT_POWER);
		NCols  = 1+(BufferWidth  >> WIDTH_POWER); 

		if( NLines > MAX_LINES )
		{
			MessageBox( "Erro FATAL !", "Estouro do número de linhas da matriz de ocupação" );
		}
		
		if( NCols > MAX_COLS )
		{
			MessageBox( "Erro FATAL !", "Estouro do número de colunas da matriz de ocupação" );
		}
		
				
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

	HPALETTE  hpalApp;
	HBITMAP  gbmOldMonoBitmap;

/*	HBITMAP  gbmOldMonoBitmap2;
	
	HDC 	hBuffer2;
	void far *pBuffer2;
*/
	PDIB pBack ;
			
	int 	BufferWidth,
			BufferHeight;
			
	int		ScreenX,
			ScreenY;     
			
	int		ScreenWidth,
			ScreenHeight;     

	int 	PaletteOffSet, 
			NumColors;
		        
	header BufferHeader;
	long Orientation;

	object_list	*LocalObjects;        


    RGBQUAD far *pColorTable(void)
    {
    	return (RGBQUAD far *) 
                    ((char far *)pBack + pBack->biSize);
	};                  


	virtual screen *Init( HWND hwnd );

	screen (void) {};
							
	screen( char *BackName, 
			int	_ScreenX = 0, int _ScreenY = 0, 
			int _ScreenWidth = 640, int _ScreenHeight = 480 )
	{
		                    
   		pBack   = DibOpenFile( BackName );

		if( pBack == NULL )
		{             
			MessageBox( "Erro Fatal!!", "Não foi possível abrir o arquivo: %s", BackName );
		}

	    BufferWidth = DibWidth(pBack);
    	BufferHeight = DibHeight(pBack);

		                    
		gbmOldMonoBitmap = 0;

		ScreenX = _ScreenX;
		ScreenY = _ScreenY;     
			
		ScreenWidth = _ScreenWidth;
		ScreenHeight = _ScreenHeight;     
		
		LocalObjects = NULL;
	
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

/*
    	hbm   = (HBITMAP)SelectObject(hBuffer2, gbmOldMonoBitmap2);
    
    //  And delete the WinGBitmap and WinGDC
    	DeleteObject(hbm);
    	DeleteDC(hBuffer2);
*/    	
    	DibFree(pBack);

	} 

	void Show(HDC hdc)
	{
//		SelectPalette(hdc,hpalApp,FALSE);
//    	RealizePalette(hdc);

	  WinGBitBlt(	hdc,0,0,ScreenWidth,ScreenHeight,
	  				hBuffer, ScreenX, ScreenY);  
	};	

	void Dark(void)
	{
        PatBlt(hBuffer,  0,0, BufferWidth, BufferHeight, BLACKNESS); 
//        PatBlt(hBuffer2, 0,0, BufferWidth, BufferHeight, BLACKNESS); 
	}

	void Paint( void )
	{
      CopyDIBits((BITMAPINFO far *)&BufferHeader,pBuffer,
          0, 0, DibPtr(pBack) ,DibInfo(pBack),0,0, DIB_RGB_COLORS);

/*        CopyDIBits((BITMAPINFO far *)&BufferHeader,pBuffer2,
          0, 0, DibPtr(pBack) ,DibInfo(pBack),0,0, DIB_RGB_COLORS);
*/
/*        TranspDIBits((BITMAPINFO far *)&BufferHeader,pBuffer,
          0, 0, DibPtr(pBack) ,DibInfo(pBack),0,0,ScreenWidth, ScreenHeight,
          DIB_RGB_COLORS, TransparentColor);

        TranspDIBits((BITMAPINFO far *)&BufferHeader,pBuffer2,
          0, 0, DibPtr(pBack) ,DibInfo(pBack),0,0,ScreenWidth, ScreenHeight,
          DIB_RGB_COLORS, TransparentColor);
*/
    };

	void Restore( void )
	{
/*	  	BitBlt(	hBuffer,0,0,BufferWidth,BufferHeight,
	  				hBuffer2, 0, 0, SRCCOPY );  

*/
      CopyDIBits((BITMAPINFO far *)&BufferHeader,pBuffer,
          0, 0, DibPtr(pBack) ,DibInfo(pBack),0,0, DIB_RGB_COLORS);

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

	virtual occupation Occupation( int X, int Y, int Width, int Height, object * &OccupObj, occupation &lastocc )
	{
		return FREE;	
	};

	virtual int IncrOccupation( object *o )
	{
		return 1;
	}

	virtual int DecrOccupation( object *o )
	{
		return 1;
	}

	virtual int ScrollLayers( void )
	{
		return 0;   
	}

	boolean TestScroll(HDC hdc, moveable *Object, int AuxX, int AuxY );
	long InitBufferHeader( void );  
	void ReserveWindowsPalette( pal &LogicalPalette );  
	void FillPalette( pal &LogicalPalette );  

	virtual void Set3DPosition( object *o, int _z = 0)
	{
	}

	virtual screen *SetVanishingPoint(int _XV, int _YV)
	{
		return this;
	}
	
	virtual screen *SetViewPoint(int _X, int _Y, int _x, int _y, int _z)
	{                               
		return this;
	}

	virtual screen *SetyAxisShift( int _X, int _Y )
	{
		return this;
	}


	virtual int XV3D(void) { return 0; };
	virtual int YV3D(void) { return 0; };

	virtual int v3D (void) { return 0; };
	virtual int DX3D(void) { return 0; };

	virtual int xv3D(void) { return 0; };
	virtual int yv3D(void) { return 0; };
	virtual int zv3D(void) { return 0; };
                                             
	virtual occup_screen * ToOccupScreen(void) { return NULL; };                                             
	virtual boolean IsOccupScreen(void) { return false; };                                             

	virtual _3D_screen * To3DScreen(void) { return NULL; };                                             
	virtual boolean Is3DScreen(void) { return false; };                                             
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
	            
	virtual screen *Init( HWND hwnd, int CellPower )
	{
	 	screen::Init( hwnd );
	 	
	 	Occup = new occup_matrix( BufferWidth, BufferHeight, CellPower, CellPower );
	 	
	 	return this;
	}	            
	           
	virtual screen *Init( HWND hwnd )
	{                              
	 	return Init( hwnd, 4 );
	}	            
	           
	virtual occupation Occupation( int X, int Y, int Width, int Height, object * &OccupObj, occupation &lastocc )
	{
		return Occup->Occupation(X, Y, Width, Height, OccupObj, lastocc);	
	};

	virtual boolean CanGo( int X, int Y, int Width, int Height )
	{                 
		object *o;    
		occupation occ, lastocc;
		
		occ = Occupation(X, Y, Width, Height, o, lastocc);
	
		return (boolean) (occ == FREE);
	}

	virtual boolean CantGo( int X, int Y, int Width, int Height )
	{
		return (boolean) (!occup_screen::CanGo(X, Y, Width, Height));
	}

	virtual int IncrOccupation( object *o )
	{
		return Occup->IncrOccupation(o);
	}

	virtual int DecrOccupation( object *o )
	{
		return Occup->DecrOccupation(o);
	}

	~occup_screen(void) 
	{
		delete Occup;
	};
					
	virtual occup_screen * ToOccupScreen(void) { return this; };                                             
	virtual boolean IsOccupScreen(void) { return true; };                                             

};

#undef	DECLARE	    