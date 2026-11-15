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

#include "casseta.hpp"
#include "cozinha.hpp"
#include "brother.hpp"
#include "barata.hpp"
#include "zemane.hpp"

//static BOOL JaPintei ;    // verifica se o fundo ja foi pintado
		 BOOL FPe ;  // evita que a animação se repita no botão do mouse  
//       BOOL IsAnimating; // permite que seja chamada a próxima animação 

barata::barata(	char *_Name, 
			boolean _Has_Player, boolean _Has_ControlPanel, boolean _Has_StatusBar, 
			int	_ScreenX, int _ScreenY, 
			int _ScreenWidth , int _ScreenHeight) :
	scene( _Name,
			_Has_Player, _Has_ControlPanel, _Has_StatusBar, 
			_ScreenX, _ScreenY, 
			_ScreenWidth, _ScreenHeight ) 
	{

    // (x,y em relacao a origem do fundo ;  dimensoes do frame)
	// (1 campo num de frames) ( 2 campos dim do frame ) ( 4 campos bound x,y,w,h)

		Porta1 = new exits( 0, 270, "virtport.bmp", 1, 40, 110, 0,0, 40, 110, PORTA_TIMER, PORTA_PERIOD );
		Porta2 = new exits( 600, 270, "virtport.bmp", 1, 40, 110, 0,0, 40, 110, PORTA_TIMER, PORTA_PERIOD );
		Pe = new _3D_animated( 0, 0, "barapisa.bmp", 15	, 540, 480, 50, 0, 540, 480,
		                                   ANIMA_FULL_TIMER, ANIMA_FULL_PERIOD	);
	 
	};

scene *barata::CreateNewScene( int ExitNum )
	{       
		if( ExitNum == NumExitPorta1 )
		{
		 	return new bugbrother( "bugbrother", NO_PLAYER, HAS_CTRL_PANEL, NO_STAT_BAR ); 
		}                                         
		else
		if( ExitNum == NumExitPorta2 )
		{
		 	return new bugbrother( "bugbrother", NO_PLAYER, HAS_CTRL_PANEL, NO_STAT_BAR ); 
		}                                         
		else
		{
			return scene::CreateNewScene( ExitNum );
		}
	};


scene *barata::Init( HWND hwnd )
	{
//        JaPintei = FALSE;
		FPe = TRUE;  //  permite que o mouse acione a animação do pé
//        IsAnimating = FALSE;
        
		scene::Init( hwnd );
		
		 // Definição em 3d - 1 par front inf esq do frame , 2par dimensões no olho da caixa
		Screen->SetVanishingPoint(514,102)->SetViewPoint(160,300,0,455,0)->SetyAxisShift(0,345);
		Porta1->Init( Screen )->Set3DOrigin(0,110)->Set3DDimensions(40,110,5)->Set3DPosition( Screen );
		Porta2->Init( Screen )->Set3DOrigin(0,110)->Set3DDimensions(40,110,5)->Set3DPosition( Screen );
		Pe->Init( Screen )->Set3DOrigin(50,480)->Set3DDimensions(200,500,1)->Set3DPosition( Screen );

		NumExitPorta1 = DefExit( Porta1, 0, 0 );  // bugbrother
		NumExitPorta2 = DefExit( Porta2, 0, 0 );  // bugbrother

	    DefLocal(Pe);

		return this;	
	}

boolean barata::MessageHandling( HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam )
	{

		HDC hdc;					
//	 	object * Occup3DObj;                         
//		occupation lastocc, occ;
		int _X, _Y;
        
    	switch (msg)
	    {   
	                                                       
			case WM_INITSCENE:
			
				Game->ControlPanel->SetText( "" );
				Game->ControlPanel->Put( Screen );
				Game->ControlPanel->Show();
				Pe->Init1SpriteAnim(hwnd,Game->CurrentScene->Screen);
				Pe->Anim1Frame(hwnd, Screen);
				
			break;

//	        case WM_PAINT:
	        	
//	       		    SetTimer(hwnd, 10, 500, NULL); 
	        	
//	        	return false;

			case WM_ENDANIM:
			
//                if ( IsAnimating ) 
//				{     
//					FPe = FALSE;
//					IsAnimating = FALSE;
//				    SetTimer(hwnd, 10, 2000, NULL); 
//				}
       		    (*SetSystemTimer)( hwnd, FREEZE_TIMER, FREEZE_PERIOD, NULL );
                 
            break;
										              
                
       		case WM_RBUTTONDOWN:

//              int _X, _Y;
				_X = this->Screen->ScreenX+LOWORD(lParam);
				_Y = this->Screen->ScreenY+HIWORD(lParam);
								                                          
				if( this->HasControlPanel() && Game->ControlPanel->IsIn(_X,_Y) )
				{
					return true;		
						//break;								                             
				}		  	
				                
/*				_X = Screen->ScreenX+LOWORD(lParam);
	  			_Y = Screen->ScreenY+HIWORD(lParam);

	            occ = Screen->Occupation(Screen->ScreenX+LOWORD(lParam), Screen->ScreenY+HIWORD(lParam), 
	                                        CELL_WIDTH, CELL_HEIGHT, Occup3DObj, lastocc);
				
				if( occ > 0 )                                            
				{               
					if( Occup3DObj != NULL )
					{
						if( Occup3DObj->IsAnimated() )
						{
							if(Occup3DObj->Name == Pe->Name)
							{  
					  			Game->SetCurrentScene( hwnd, (int) NumExitPorta1 );
								FPe  = FALSE; // não permite que o mouse acione a animação
							}
						}
					}
				}   
*/				return false;

	       	case WM_SYSTIMER:                       

				if( wParam == (WPARAM) Pe->Timer() )
				{  
					Pe->Anim1Frame(hwnd, Screen);
				}       

				if( wParam == (WPARAM) FREEZE_TIMER )
				{  
						 KillTimer(hwnd,FREEZE_TIMER);
			  			 Game->SetCurrentScene( hwnd, (int) NumExitPorta1 );
				}       


//	            if ((JaPintei)&&(FPe))
//	            if (FPe)
//	            {
//					  if(Pe->IsAnimating())
//					  {					  
//		            	 Pe->Anim1Frame(hwnd, Screen);
//		            	 IsAnimating = TRUE;
//					  }
//	            }

//				if( wParam == (WPARAM) Porta1->Timer() )
//				{  
//					Porta1->Anim1Frame(hwnd, Screen);
//				}       

//				if( wParam == (WPARAM) Porta2->Timer() )
//				{       
//					Porta2->Anim1Frame(hwnd, Screen);
//				}       

    			hdc = GetDC(hwnd);   			

     			Porta1->DrawSolid( hdc, Screen );
     			Porta2->DrawSolid( hdc, Screen );

       			ReleaseDC(hwnd,hdc);

				return false;
	
		  	break;
	  	default:
	  			return false;
		};                   
		
		
		return true;

};


