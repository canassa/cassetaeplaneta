
//#define PORTASALA_TIMER	2
//#define PORTASALA_PERIOD	300        

class sala_screen : public _3D_screen
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
	sala_screen( char *BackName, 
			int	_ScreenX = 0, int _ScreenY = 0, 
			int _ScreenWidth = 640, int _ScreenHeight = 480 ) :
	_3D_screen( BackName, 
			_ScreenX, _ScreenY, 
			_ScreenWidth,_ScreenHeight )
	{
			                    
	};
	
};


/*class portasala : public exits
{          
public:

	portasala(void) { };
	
	portasala(int _X, int _Y,  
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

	virtual void Anim1Frame( HWND hwnd, screen *Screen, object *Comoda)
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

 	
class sala : public scene
{
public:
	_3D_object 	*Poltrona;
	_3D_object 	*Puff;
    _3D_object 	*Sofa;
/*    portasala	*Porta1;
    portasala	*Porta2;
    portasala	*Porta3;
    
	int 		NumExitPorta1, NumExitPorta2, NumExitPorta3;

*/
	sala(	char *_Name,
			int	_ScreenX = 0, int _ScreenY = 0, 
			int _ScreenWidth = 640, int _ScreenHeight = 480 ) :
	scene( _Name, 
			_ScreenX, _ScreenY, 
			_ScreenWidth, _ScreenHeight ) 
	{

		Poltrona = new _3D_object( 0, 236, "poltrona.bmp", 1, 117, 158); // , 0, 0, 117, 158 );
		Puff = new _3D_object( 17, 205, "puff.bmp",    1, 460, 234); // , 0, 0, 231, 200 );
		Sofa = new _3D_object( 17, 205, "sofa.bmp",    1, 460, 234); // , 0, 0, 231, 200 );
//		Porta1 = new portasala( 186, 338, "portcorr.bmp", 3, 85, 360, 5,10, 45, 290, PORTAPAIS_TIMER, PORTAPAIS_PERIOD );
//		Porta2 = new portasala( 70, 22, "portcorr.bmp", 3, 85, 360, 5,10, 45, 290, PORTAPAIS_TIMER, PORTAPAIS_PERIOD );
//		Porta3 = new portasala( 70, 22, "portcorr.bmp", 3, 85, 360, 5,10, 45, 290, PORTAPAIS_TIMER, PORTAPAIS_PERIOD );
		
	 
	};

	virtual screen *CreateScreen( void )
	{       
		return new sala_screen( "corredor.bmp" ) ;
	};

/*	virtual scene *CreateScene( int ExitNum )
	{       
		if( ExitNum == NumExitPorta1 )
		{
		 	return new quartoze( "corredor.bmp" ); 
		}                                         
		else
		{
			return scene::CreateScene( ExitNum );
		}
		if( ExitNum == NumExitPorta2 )
		{
		 	return new quartoze( "fundcozi.bmp" ); 
		}                                         
		else
		{
			return scene::CreateScene( ExitNum );
		}
		if( ExitNum == NumExitPorta3 )
		{
		 	return new quartoze( "fundcozi.bmp" ); 
		}                                         
		else
		{
			return scene::CreateScene( ExitNum );
		}
	};
*/

	~quarpais( void )
	{
		delete Poltrona;
		delete Puff;
		delete Sofa;
		delete Porta1;
		delete Porta2;		
		delete Porta3;		
		
	};

	scene *Init( HWND hwnd )
	{
		scene::Init( hwnd );
		
		Screen->SetVanishingPoint(505,150)->SetViewPoint(155,303,0,455,0)->SetyAxisShift(0,330);

		Poltrona->Init( Screen )->Set3DOrigin(13,222)->Set3DDimensions(500,80,250)->Set3DPosition( Screen );
		Puff->Init( Screen )->Set3DOrigin(4,155)->Set3DDimensions(50,160,100)->Set3DPosition( Screen );
		Sofa->Init( Screen )->Set3DOrigin(4,155)->Set3DDimensions(50,160,100)->Set3DPosition( Screen );
/*		Porta1->Init( Screen )->Set3DOrigin(10,300)->Set3DDimensions(5,500,100)->Set3DPosition( Screen );
		Porta2->Init( Screen )->Set3DOrigin(10,300)->Set3DDimensions(5,500,100)->Set3DPosition( Screen );
		Porta3->Init( Screen )->Set3DOrigin(10,300)->Set3DDimensions(5,500,100)->Set3DPosition( Screen );
*/
		Poltrona->Put( Screen );      
		Puff->Put( Screen );      
		Sofa->Put( Screen ); 
/*		Porta1->Put( Screen );
		Porta2->Put( Screen );
		Porta3->Put( Screen );
		     
		NumExitPorta = DefExit( Porta1, "Corredor", 470, 130 );
		NumExitPorta = DefExit( Porta2, "Cozinha", 470, 130 );
		NumExitPorta = DefExit( Porta3, "Cozinha", 470, 130 ); 
		
//		Porta1->InitAnim( hwnd, Screen );
//		Porta2->InitAnim( hwnd, Screen );
//		Porta3->InitAnim( hwnd, Screen );
*/		

		return this;	
	}

	virtual boolean MessageHandling( HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam )
	{
		HDC hdc;					
				
    
    	switch (msg)
	    {       
	       	case WM_SYSTIMER:                       

    			hdc = GetDC(hwnd);   			

        		Poltrona->DrawSolid( hdc, Screen );      
        		Puff->DrawSolid( hdc, Screen );      
		        Sofa->DrawSolid( hdc, Screen ); 
/*                Porta1->DrawSolid( hdc, Screen );
       			Porta2->DrawSolid( hdc, Screen );
       			Porta3->DrawSolid( hdc, Screen );
       			
*/
       			ReleaseDC(hwnd,hdc);

				return false;
	
		  	break;
		  	default:
	  			return false;
		};                   
		
		return true;
	};
	
};


