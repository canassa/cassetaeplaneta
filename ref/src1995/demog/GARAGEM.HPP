
#define PORTAGARA_TIMER	2
#define PORTAGARA_PERIOD	300        

class garagem_screen : public _3D_screen
{                          
public:
/*	screen *Init( HWND hwnd )
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
*/						
	garagem_screen( char *BackName, 
			int	_ScreenX = 0, int _ScreenY = 0, 
			int _ScreenWidth = 640, int _ScreenHeight = 480 ) :
	_3D_screen( BackName, 
			_ScreenX, _ScreenY, 
			_ScreenWidth,_ScreenHeight )
	{
			                    
	};
	
};

class portagara : public exits
{          
public:

	portagara(void) { };
	
	portagara(int _X, int _Y,  
			char *BMPName, int BMPFrames, 
			int BMPWidth, int BMPHeight,
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			int _Timer, int _Period,
			boolean _IsVisible = true, int _Layer = 0  ) :
	exits( _X, _Y,  
			BMPName,  BMPFrames, 
			BMPWidth, BMPHeight,             
			_BoundX, _BoundY, 
			_BoundWidth, _BoundHeight, 
			_Timer, _Period,
			_IsVisible,_Layer  )
	{
	};

/*	virtual void Anim1Frame( HWND hwnd, screen *Screen, object *Comoda)
	{

			HDC hdc = GetDC(hwnd);

			if( hdc == NULL )
			{
				MessageBox( NULL, "Estouro no número de HDCs", "Erro Fatal !", MB_OK | MB_APPLMODAL | MB_ICONEXCLAMATION );
			}
			else
			{
				CollideObject = Comoda;

				NextFrame();                                          
    	       	Paint( Screen );
				object::TreatCollision(hdc, Screen); // specifically 2D collision handling
		    	Show( hdc, Screen );
	   		}

   			ReleaseDC(hwnd,hdc);

	}

*/	
	

};


class garagem : public scene
{
public:
//	_3D_object 	*Carro;
	int 		NumExitPorta;


	garagem(	char *_Name,
			int	_ScreenX = 0, int _ScreenY = 0, 
			int _ScreenWidth = 640, int _ScreenHeight = 480 ) :
	scene( _Name, 
			_ScreenX, _ScreenY, 
			_ScreenWidth, _ScreenHeight ) 
	{

//		Carro = new _3D_object( 0, 236, "moveltv2.bmp", 1, 117, 158); // , 0, 0, 117, 158 );
		Porta = new portagara( 186, 338, "portgara.bmp", 3, 85, 360, 5,10, 45, 290, PORTACORR_TIMER, PORTACORR_PERIOD );
	 
	};

	virtual screen *CreateScreen( void )
	{       
		return new garagem_screen( "garagem.bmp" ) ;
	};

	virtual scene *CreateScene( int ExitNum )
	{       
		if( ExitNum == NumExitPorta )
		{
		 	return new cozinha( "fundcozi.bmp" ); 
		}                                         
		else
		{
			return scene::CreateScene( ExitNum );
		}

     };

	~quarpais( void )
	{
//		delete Carro;
	};	

	scene *Init( HWND hwnd )
	{
		scene::Init( hwnd );
		
		Screen->SetVanishingPoint(505,150)->SetViewPoint(155,303,0,455,0)->SetyAxisShift(0,330);

//		Carro->Init( Screen )->Set3DOrigin(4,155)->Set3DDimensions(50,160,100)->Set3DPosition( Screen );
		Porta->Init( Screen )->Set3DOrigin(10,300)->Set3DDimensions(5,500,100)->Set3DPosition( Screen );

		Carro->Put( Screen ); 
		Porta1->Put( Screen ); 
		
		NumExitPorta = DefExit( Porta, "Cozinha", 470, 130 ); 
		
//		Porta1->InitAnim( hwnd, Screen );
		
		return this;	
	}

	virtual boolean MessageHandling( HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam )
	{
		HDC hdc;					
				
    
    	switch (msg)
	    {       
	       	case WM_SYSTIMER:                       

    			hdc = GetDC(hwnd);   			

//       			Carro->DrawSolid( hdc, Screen );
       			Porta->DrawSolid( hdc, Screen );
       			
       			

       			ReleaseDC(hwnd,hdc);

				return false;
	
		  	break;
		  	default:
	  			return false;
		};                   
		
		return true;
	};
	
};


