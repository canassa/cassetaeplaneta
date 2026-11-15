        
        
class quartoze_screen : public _3D_screen
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
		    
		
		    
		for( i = 5, k = 7; i < 8; i++, k-=3 )
		{                 
		 	for( j = 0; j < k; j++ )
		 	{
		 		Occup->SetOccup( i, j, WALL );
		 	}
		}   
		

		return this;
	
	}
						
	quartoze_screen( char *BackName, 
			int	_ScreenX = 0, int _ScreenY = 0, 
			int _ScreenWidth = 640, int _ScreenHeight = 480 ) :
	_3D_screen( BackName, 
			_ScreenX, _ScreenY, 
			_ScreenWidth,_ScreenHeight )
	{
			                    
	};
	
};


class quartoze : public scene
{
public:
	_3D_object 	*Comoda,
				*Cama,
				*MesaInv;

	exits		*Porta;

/*
	portable	*Bola;
	portable	*Carteira;
	portable	*Camisinha;
*/	
	int 		NumExitPorta;
	

	quartoze(	char *_Name,
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
		Comoda = new _3D_object( 0, 0, "tvemovel.bmp", 1, 155, 479); // , 0, 0, 140, 479 );

		Cama = new _3D_object( 410, 260, "cama.bmp",    1, 231, 200); // , 0, 0, 231, 200 );

		MesaInv = new _3D_object( 225, 210, "mesainv.bmp",    1, 50, 5); // , 0, 0, 231, 200 );
/*		
		Bola = new portable( this, 180, 300, "bola.bmp", 1, 50, 50 );
		Carteira = new portable( this, 450, 300, "carteira.bmp", 1, 20, 14 );
		Camisinha = new portable( this, 500, 300, "camisinh.bmp", 1, 20, 20 );
*/		
		Porta = new exits( 67, 25, "portnew4.bmp", 5, 136, 332, 5,10, 45, 290, PORTAZE_TIMER, PORTAZE_PERIOD );

/*		DefLocal(Comoda);
		DefLocal(Cama);
		DefLocal(MesaInv);
		DefLocal(Porta);
*/			 
	};

	virtual screen *CreateScreen( void )
	{       
		return new quartoze_screen( "quarnew2.bmp" ) ;
	};

	virtual scene *CreateNewScene( int ExitNum );
/*	{       
		if( ExitNum == NumExitPorta )
		{
		 	return new quarpais( "Quarpais" ); 
		}                                         
		else
		{
			return scene::CreateNewScene( ExitNum );
		}
	};
*/

    
	~quartoze( void )
	{
/*		delete Comoda;
		delete Cama;  
		delete MesaInv;
		delete Porta;
*/	};

	scene *Init( HWND hwnd )
	{
		scene::Init( hwnd );

		Screen->SetVanishingPoint(514,102)->SetViewPoint(160,300,0,455,0)->SetyAxisShift(0,345);

		Cama->Init( Screen )->Set3DOrigin(2,190)->Set3DDimensions(230,80,330)->Set3DPosition( Screen );

		MesaInv->Init( Screen )->Set3DOrigin(2,5)->Set3DDimensions(50,5,80)->Set3DPosition( Screen );
		
//		Comoda->Init( Screen )->Set3DOrigin(4,155)->Set3DDimensions(50,160,100)->Set3DPosition( Screen );
		Comoda->Init( Screen )->Set3DOrigin(0,479)->Set3DDimensions(70,250,110)->Set3DPosition( Screen );

/*
		Bola->Init( Screen )->Set3DOrigin(3,46)->Set3DDimensions(50, 50, 50)->Set3DPosition( Screen );

		Carteira->Init( Screen )->Set3DOrigin(0,13)->Set3DDimensions(20,14,2)->Set3DPosition( Screen );

		Camisinha->Init( Screen )->Set3DOrigin(0,19)->Set3DDimensions(20,20,2)->Set3DPosition( Screen );
*/
		Porta->Init( Screen )->Set3DOrigin(10,300)->Set3DDimensions(5,500,100)->Set3DPosition( Screen );


//		Porta->Put( Screen );
		Comoda->Put( Screen );      


		DefLocal(Cama);
		DefLocal(Comoda);
		DefLocal(MesaInv);
		DefLocal(Porta);
		


/*
		Bola->DefIcon( "minbola.bmp" );
		Carteira->DefIcon( "mincarte.bmp" );
		Camisinha->DefIcon( "mincamis.bmp" );
*/
		
//		NumExitPorta = DefExit( Porta, "QuarPais", 470, 130 );
		NumExitPorta = DefExit( Porta, 470, 130 );
		
//		Porta->InitAnim( hwnd, Screen );


		return this;	
	}

	virtual boolean MessageHandling( HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam )
	{
	    static      
	    boolean 	InKeySub = false,
					InKeyAdd = false;
		HDC hdc;					
//	 	object * Occup3DObj; 
//		occupation lastocc,occ;
            
				
    
    	switch (msg)
	    {       
			case WM_INITSCENE:
			
				Game->ControlPanel->SetText( "Quarto do Ze Mane" );
				Game->ControlPanel->Put( Screen );
				Game->ControlPanel->Show();

//				Game->Player->InitAnimP( hwnd, Game->CurrentScene->Screen );
				
			break;
			case WM_KEYDOWN: 
		
				switch(wParam)
				{
					case VK_ADD:
						if( !InKeyAdd )                    
						{                                       
							InKeyAdd = true;   
//							Game->Player->InitAnim( hwnd, Screen, MV_RIGHT );
							ZeMane->InitAnim( hwnd, Screen, MV_RIGHT );
						}         
					break;
					case VK_SUBTRACT:
						if( !InKeySub )                    
						{                                       
							InKeySub = true;   
//							Game->Player->InitAnim( hwnd, Screen, MV_LEFT );
							ZeMane->InitAnim( hwnd, Screen, MV_LEFT );
						}         
					break;
					default:
						return false;
			    };
			    
			break;               
			case WM_KEYUP: 
				       
				switch(wParam)
				{
					case VK_ADD:
							InKeyAdd = false;
//							Game->Player->EndAnim( hwnd, Screen );
							ZeMane->EndAnim( hwnd, Screen );
							break;
					case VK_SUBTRACT:
							InKeySub = false;
//							Game->Player->EndAnim( hwnd, Screen );
							ZeMane->EndAnim( hwnd, Screen );
							break;
					default:
						return false;
			    };
			    
	       	break;               
	       	case WM_SYSTIMER:                       

    			hdc = GetDC(hwnd);   			

				if( wParam == (WPARAM) Porta->Timer() )
				{                                     
//					if( Porta->StartExit )
					{
//						Porta->Anim1Frame(hwnd, Screen, Comoda, Game->Player);
						Porta->Anim1Frame(hwnd, Screen); // , Comoda, Game->Player);
					}
				}       
					
       			Cama->DrawSolid( hdc, Screen );
       			Comoda->DrawSolid( hdc, Screen );
       			Porta->DrawSolid( hdc, Screen );
/*
       			Bola->DrawSolid( hdc, Screen );
       			Carteira->DrawSolid( hdc, Screen );
       			Camisinha->DrawSolid( hdc, Screen );
*/
       			ReleaseDC(hwnd,hdc);

				return false;
	
		  	break;
/*			case WM_RBUTTONDOWN 
                
                occ = Screen->Occupation(Screen->ScreenX+LOWORD(lParam), Screen->ScreenY+HIWORD(lParam), CELL_WIDTH, CELL_HEIGHT, Occup3DObj, lastocc)

				if( occ == 1 )                                            
				{               
					if( Occup3DObj != NULL && Occup3DObj->IsExit() )
					{
						PostMessage( hwnd, WM_EXITSCENE, Occup3DObj->ExitNumber(), 0L );
					}		
				}
					
			    return true;
			    
	        break;
*/		  	default:
	  			return false;
		};                   
		
		
		return true;
	};
};


