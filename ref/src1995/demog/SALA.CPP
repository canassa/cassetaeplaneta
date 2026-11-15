#pragma  warning( disable : 4250 )
        
#include "games.hpp"
#include "event.hpp"
                              
#include "screen.hpp"
#include "3dscreen.hpp"
#include "object.hpp"
#include "3dobject.hpp"
#include "ctrpanel.hpp"

#include "scene.hpp"
#include "vtree.h"
#include "applicat.hpp"

#define _CASSETA

#include "casseta.hpp"

#undef _CASSETA        

#include "zemane.hpp"
#include "sala.hpp"
#include "corredor.hpp"
#include "cozinha.hpp"
#include "pcarnivo.hpp"



sala::sala(	char *_Name,
			boolean _Has_Player, boolean _Has_ControlPanel, boolean _Has_StatusBar, 
			int	_ScreenX, int _ScreenY, 
			int _ScreenWidth, int _ScreenHeight) :
	scene( _Name,
			_Has_Player, _Has_ControlPanel, _Has_StatusBar, 
			_ScreenX, _ScreenY, 
			_ScreenWidth, _ScreenHeight ) 
	{

            // x,y em relacao a origem do fundo ;  dimensoes do frame
		Mesa = new _3D_object(468, 305, "mesa.bmp", 1, 171, 174); // , 0, 0, 117, 158 );
		Poltrona = new _3D_object( 11, 257, "poltrona.bmp", 1, 170, 159); // , 0, 0, 117, 158 );
//		Puff = new _3D_object( 483, 353, "puff.bmp",    1, 59, 45); // , 0, 0, 231, 200 );
		Sofa = new _3D_object( 126, 160, "sofa.bmp",    1, 388, 191); // , 0, 0, 231, 200 );
		
	// (1 campo num de frames) ( 2 campos dim do frame ) ( 4 campos bound x,y,w,h)

//		Gatomove = new _3D_animated( 323, 181, "gatomove.bmp", 3, 137, 85, 3, 1, 137, 85,
		Gatomove = new _3D_animated( 270, 300, "gatomove.bmp", 3, 137, 85, 3, 1, 137, 85,
		                                   ANIMA_SPRITE_TIMER, ANIMA_SPRITE_PERIOD	);
		Cortina = new _3D_animated( 17, 75, "cortina.bmp", 5, 94, 206, 0, 0, 94, 206,
		                                   ANIMA_SPRITE_TIMER, ANIMA_SPRITE_PERIOD	);
    	Porta1 = new exits( 414, 50, "virtcozi.bmp", 1, 40, 110, 0, 0, 40, 100, PORTA_TIMER, PORTA_PERIOD );
    	Porta2 = new exits( 620, 280, "virtport.bmp", 1, 40, 110, 0,0, 40, 110, PORTA_TIMER, PORTA_PERIOD );
    	PCarniExit = new exits( 518, 115, "virtport.bmp", 1, 40, 110, 0, 0, 40, 110, PORTA_TIMER, PORTA_PERIOD );
    	Porta3 = new exits( 600, 390, "virtport.bmp", 1, 40, 110, 0,0, 40, 110, PORTA_TIMER, PORTA_PERIOD );

		
};


scene *sala::CreateNewScene( int ExitNum )
	{       
	if( ExitNum == NumExitPorta1 )               
	{
	 	return new cozinha( "cozinha" , HAS_PLAYER, HAS_CTRL_PANEL, NO_STAT_BAR ); 
	}                                         
	else
	if ( ExitNum == NumExitPorta2 )
	{
	 	return new corredor( "corredor" , HAS_PLAYER, HAS_CTRL_PANEL, NO_STAT_BAR ); 
	}                                         
	else
	if( ExitNum == NumExitPorta3 )
	{
//	 	return new saida( "saida" ); 
	}                                         
	if( ExitNum == NumExitPCarnivora )
	{
	 	return new PCarnivora( "pcarnivora" , NO_PLAYER, HAS_CTRL_PANEL, NO_STAT_BAR ); 
	} 	
	else
	{
		return scene::CreateNewScene( ExitNum );
	}
};


scene *sala::Init( HWND hwnd )
	{    
//	    HDC hdc;
	    
		scene::Init( hwnd );
		
		Screen->SetVanishingPoint(505,20)->SetViewPoint(155,303,0,455,0)->SetyAxisShift(0,330);
		
    // Definição em 3d - 1 par front inf esq do frame , 2par dimensões no olho da caixa

		Sofa->Init( Screen )->Set3DOrigin(0,186)->Set3DDimensions(530,20,10)->Set3DPosition( Screen );
		Poltrona->Init( Screen )->Set3DOrigin(3,156)->Set3DDimensions(150,159,100)->Set3DPosition( Screen );
		Gatomove->Init( Screen )->Set3DOrigin(3,82)->Set3DDimensions(150,100,70)->SetZ0(0)->Set3DPosition( Screen );
		Cortina->Init( Screen )->Set3DOrigin(0,206)->Set3DDimensions(5,300,300)->Set3DPosition( Screen );
//		Puff->Init( Screen )->Set3DOrigin(3,43)->Set3DDimensions(59,45,60)->Set3DPosition( Screen );
		Mesa->Init( Screen )->Set3DOrigin(3,174)->Set3DDimensions(171,70,120)->Set3DPosition( Screen );
    	Porta1->Init( Screen )->Set3DOrigin(10,150)->Set3DDimensions(130,300,5)->Set3DPosition( Screen );
	    Porta2->Init( Screen )->Set3DOrigin(0,70)->Set3DDimensions(40,40,70)->Set3DPosition( Screen );
	    PCarniExit->Init( Screen )->Set3DOrigin(20,100)->Set3DDimensions(90,150,20)->Set3DPosition( Screen );
		Porta3->Init( Screen )->Set3DOrigin(10,300)->Set3DDimensions(5,500,100)->Set3DPosition( Screen );


		Porta1->Put( Screen );
		Porta2->Put( Screen );
		PCarniExit->Put( Screen );
		Porta3->Put( Screen );
		     
		NumExitPorta1 = DefExit( Porta1, 470, 130 ); //  "Cozinha",
		NumExitPorta2 = DefExit( Porta2, 100, 130 ); // "Corredor", 
		NumExitPorta3 = DefExit( Porta3, 470, 130 ); // "Saida", 
		NumExitPCarnivora = DefExit( PCarniExit, 0, 0 );  // Planta Carnivora
		
	    DefLocal(Sofa);
	    DefLocal(Mesa);
	    DefLocal(Poltrona);
//	    DefLocal(Puff);
	    DefLocal(Porta1);
	    DefLocal(Porta2);
	    DefLocal(PCarniExit);
	    DefLocal(Gatomove);
	    DefLocal(Cortina);

		return this;	
	}

boolean sala::MessageHandling( HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam )
	{
//		HDC hdc;					
				
        
    	switch (msg)
	    {       
    		case WM_RBUTTONDOWN:
    		
    			object * Occup3DObj;                         
				occupation lastocc, occ;
				int _X, _Y;
       		
				_X = Screen->ScreenX+LOWORD(lParam);
				_Y = Screen->ScreenY+HIWORD(lParam);
				                
	            occ = Screen->Occupation(Screen->ScreenX+LOWORD(lParam), Screen->ScreenY+HIWORD(lParam), 
	                                        CELL_WIDTH, CELL_HEIGHT, Occup3DObj, lastocc);
				
				if( occ > 0 )                                            
				{               
					if( Occup3DObj != NULL )
					{
						if( Occup3DObj->IsAnimated() )
						{
							if(Occup3DObj->Name == Gatomove->Name)
							{         
								Gatomove->CurrentFrame = 0;
							}
							else
								if(Occup3DObj->Name == Cortina->Name)
								{         
									Cortina->CurrentFrame = 1;
								}
						}
					}
				}
				return false;
			break;

	       	case WM_SYSTIMER: 
	       	
	       	
				if( wParam == (WPARAM) Gatomove->Timer() )
				{                                     
					  if(Gatomove->IsAnimating())
					  {					  
					  		Gatomove->Anim1Frame(hwnd, Screen);
					  }
				}	       	                      

				if( wParam == (WPARAM) Cortina->Timer() )
				{                                     
					  if(Cortina->IsAnimating())
					  {					  
					  		Cortina->Anim1Frame(hwnd, Screen);
					  }
				}	       	                      

//    			hdc = GetDC(hwnd);   			

//                Mesa->DrawSolid( hdc, Screen );      
//                Gatomove->DrawSolid( hdc, Screen );      
//        		Poltrona->DrawSolid( hdc, Screen );      
//        		Puff->DrawSolid( hdc, Screen );      
//		        Sofa->DrawSolid( hdc, Screen ); 
//                Porta1->DrawSolid( hdc, Screen );
//       			Porta2->DrawSolid( hdc, Screen );
//      			PCarniExit->DrawSolid( hdc, Screen );
//       			Porta3->DrawSolid( hdc, Screen );
       			

//       			ReleaseDC(hwnd,hdc);

				return false;
	
		  	break;
		  	default:
	  			return false;
		};                   
		
		return true;
	
	
};


