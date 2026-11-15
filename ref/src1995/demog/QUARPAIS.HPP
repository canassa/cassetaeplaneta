        

class quarpais_screen : public _3D_screen
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
						
	quarpais_screen( char *BackName, 
			int	_ScreenX = 0, int _ScreenY = 0, 
			int _ScreenWidth = 640, int _ScreenHeight = 480 ) :
	_3D_screen( BackName, 
			_ScreenX, _ScreenY, 
			_ScreenWidth,_ScreenHeight )
	{
			                    
	};
	
};


class quarpais : public scene
{
public:
//	_3D_object 	*Comoda;
	_3D_object 	*CamaPais;

	exits		*Porta;
	
	int 	NumExitPorta;

	quarpais(	char *_Name,
			boolean _Has_Player = true, boolean _Has_ControlPanel = true,
			boolean _Has_StatusBar = true, 
			int	_ScreenX = 0, int _ScreenY = 0, 
			int _ScreenWidth = 640, int _ScreenHeight = 480 ) :
	scene( _Name, 
			_Has_Player, _Has_ControlPanel,
			_Has_StatusBar, 
			_ScreenX, _ScreenY, 
			_ScreenWidth, _ScreenHeight ) 
	{

//		Comoda = new _3D_object( 0, 236, "moveltv2.bmp", 1, 117, 158); // , 0, 0, 117, 158 );
		CamaPais = new _3D_object( 17, 205, "camapais.bmp",    1, 460, 234); // , 0, 0, 231, 200 );

		Porta = new exits( 576, 40, "portpais.bmp", 3, 64, 314, 50,20, 13, 280, PORTAPAIS_TIMER, PORTAPAIS_PERIOD );

/*
		DefLocal(CamaPais);
		DefLocal(Porta);
*/	 
	};

	virtual screen *CreateScreen( void )
	{       
		return new quarpais_screen( "quarpais.bmp" ) ;
	};

	virtual scene *CreateNewScene( int ExitNum );
/*	{       
		if( ExitNum == NumExitPorta )
		{
		 	return new quartoze( "QuartoZe" ); 
		}                                         
		else
		{
			return scene::CreateNewScene( ExitNum );
		}
	};
*/


	~quarpais( void )
	{
/*
//		delete Comoda;
		delete CamaPais;

		delete Porta;
*/
	};

	scene *Init( HWND hwnd )
	{
		scene::Init( hwnd );

		Screen->SetVanishingPoint(505,150)->SetViewPoint(155,303,0,455,0)->SetyAxisShift(0,330);

		CamaPais->Init( Screen )->Set3DOrigin(13,222)->Set3DDimensions(500,80,150)->Set3DPosition( Screen );
//		Comoda->Init( Screen )->Set3DOrigin(4,155)->Set3DDimensions(50,160,100)->Set3DPosition( Screen );

		CamaPais->Put( Screen );      


		Porta->Init( Screen )->Set3DOrigin(60,296)->Set3DDimensions(5,500,100)->Set3DPosition( Screen );


		DefLocal(CamaPais);
		DefLocal(Porta);
		

		NumExitPorta = DefExit( Porta, 250, 100 );
		
		return this;	
	}

	virtual boolean MessageHandling( HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam )
	{
		HDC hdc;					
				
    
    	switch (msg)
	    {       

			case WM_INITSCENE:
			
				Game->ControlPanel->SetText( "Quarto dos Pais" );
				Game->ControlPanel->Put( Screen );
				Game->ControlPanel->Show();
				
			break;
	       	case WM_SYSTIMER:                       

    			hdc = GetDC(hwnd);   			

				if( wParam == (WPARAM) Porta->Timer() )
				{                                     
//					if( Porta->StartExit )
					{
//						Porta->Anim1Frame(hwnd, Screen, Game->Player);
						Porta->Anim1Frame(hwnd, Screen); // , Game->Player);
					}
				}       
					

       			CamaPais->DrawSolid( hdc, Screen );
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


