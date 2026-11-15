
#define PORTACORR_TIMER	2
#define PORTACORR_PERIOD	300        


class corredor_screen : public _3D_screen
{                          
public:
	screen *Init( HWND hwnd )
	{                         
		register int i,j,k;
		
	 	_3D_screen::Init(hwnd);
	 	
		for( i = 4; i < 40; i++ )
		{
		 	for( j = 0; j < 16; j++ )
		 	{
		 		Occup->SetOccup( i, j, WALL );
		 	}
		}   
		    
		
/*		    
		for( i = 5, k = 8; i < 8; i++, k-=3 )
		{                 
		 	for( j = 0; j < k; j++ )
		 	{
		 		Occup->SetOccup( i, j, WALL );
		 	}
		}   
		
*/
		return this;
	
	}
						
	corredor_screen( char *BackName, 
			int	_ScreenX = 0, int _ScreenY = 0, 
			int _ScreenWidth = 640, int _ScreenHeight = 480 ) :
	_3D_screen( BackName, 
			_ScreenX, _ScreenY, 
			_ScreenWidth,_ScreenHeight )
	{
			                    
	};
	
};

class portacorr : public exits
{          
public:

	portacorr(void) { };
	
	portacorr(int _X, int _Y,  
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


class corredor : public scene
{
public:
	_3D_object 	*Estante;
	_3D_object 	*Telefone;
    portacorr	*Porta1;
//    portacorr	*Porta2;
//    portacorr	*Porta3;

	int 		NumExitPorta1, NumExitPorta2, NumExitPorta3;

	corredor(	char *_Name,
			int	_ScreenX = 0, int _ScreenY = 0, 
			int _ScreenWidth = 640, int _ScreenHeight = 480 ) :
	scene( _Name, 
			_ScreenX, _ScreenY, 
			_ScreenWidth, _ScreenHeight ) 
	{

		Estante = new _3D_object( 338, 370, "estantel.bmp", 1, 124, 122); // , 0, 0, 117, 158 );
		Telefone = new _3D_object( 348, 256, "telefone.bmp",    1, 80, 53); // , 0, 0, 231, 200 );
		Porta1 = new portacorr( 186, 338, "portcorr.bmp", 3, 85, 360, 5,10, 45, 290, PORTACORR_TIMER, PORTACORR_PERIOD );
//		Porta2 = new portacorr( 70, 22, "portcorr.bmp", 3, 85, 360, 5,10, 45, 290, PORTACORR_TIMER, PORTACORR_PERIOD );
//		Porta3 = new portacorr( 70, 22, "portcorr.bmp", 3, 85, 360, 5,10, 45, 290, PORTACORR_TIMER, PORTACORR_PERIOD );

	 
	};

	virtual screen *CreateScreen( void )
	{       
		return new corredor_screen( "corredor.bmp" ) ;
	};

	virtual scene *CreateScene( int ExitNum )
	{       
		if( ExitNum == NumExitPorta1 )
		{
		 	return new quartoze( "quartnew.bmp" ); 
		}                                         
		else
		{
			return scene::CreateScene( ExitNum );
		}
/*		if( ExitNum == NumExitPorta2 )
		{
		 	return new quartoze( "quartnew.bmp" ); 
		}                                         
		else
		{
			return scene::CreateScene( ExitNum );
		}
		if( ExitNum == NumExitPorta3 )
		{
		 	return new quartoze( "quartnew.bmp" ); 
		}                                         
		else
		{
			return scene::CreateScene( ExitNum );
		}
*/		
		
	};

                              
	~corredor( void )
	{
		delete Estante;
		delete Telefone;
		delete Porta1;
//		delete Porta2;		
//		delete Porta3;		
	};

	scene *Init( HWND hwnd )
	{
		scene::Init( hwnd );
		
		Screen->SetVanishingPoint(505,150)->SetViewPoint(155,303,0,455,0)->SetyAxisShift(0,330);

		Estantel->Init( Screen )->Set3DOrigin(13,222)->Set3DDimensions(500,80,250)->Set3DPosition( Screen );
		Telefone->Init( Screen )->Set3DOrigin(4,155)->Set3DDimensions(50,160,100)->Set3DPosition( Screen );
		Porta1->Init( Screen )->Set3DOrigin(10,300)->Set3DDimensions(5,500,100)->Set3DPosition( Screen );
//		Porta2->Init( Screen )->Set3DOrigin(10,300)->Set3DDimensions(5,500,100)->Set3DPosition( Screen );
//		Porta3->Init( Screen )->Set3DOrigin(10,300)->Set3DDimensions(5,500,100)->Set3DPosition( Screen );


		Estantel->Put( Screen );      
        Telefone->Put( Screen );
		Porta1->Put( Screen );
//		Porta2->Put( Screen );
//		Porta3->Put( Screen );
		
		NumExitPorta = DefExit( Porta1, "QuartoZe", 470, 130 );
//		NumExitPorta = DefExit( Porta2, "QuartoZe", 470, 130 );
//		NumExitPorta = DefExit( Porta3, "QuartoZe", 470, 130 );

		
//		Porta1->InitAnim( hwnd, Screen );
//		Porta2->InitAnim( hwnd, Screen );
//		Porta3->InitAnim( hwnd, Screen );
              

		return this;	
	}

	virtual boolean MessageHandling( HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam )
	{
		HDC hdc;					
				
    
    	switch (msg)
	    {       
	       	case WM_SYSTIMER:                       

    			hdc = GetDC(hwnd);   			

       			Estantel->DrawSolid( hdc, Screen );
       			Telefone->DrawSolid( hdc, Screen );
       			Porta1->DrawSolid( hdc, Screen );
//       			Porta2->DrawSolid( hdc, Screen );
//       			Porta3->DrawSolid( hdc, Screen );


       			ReleaseDC(hwnd,hdc);

				return false;
	
		  	break;
		  	default:
	  			return false;
		};                   
		
		return true;
	};
	
};


