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
#include "polar.hpp"
#include "zemane.hpp"


static BOOL JaPintei ;    // verifica se o fundo ja foi pintado
static BOOL FPolar ;  // evita que a animação se repita no botão do mouse  
//HCURSOR hcurleft;     // handle do cursor "seta para a esquerda"
//HCURSOR hcurright;    // handle do cursor "seta para a direita"
HCURSOR hcursaida;    // handle do cursor "seta para a direita"
HCURSOR hcurant;      // handle do cursor anterior

geladeira::geladeira(	char *_Name, 
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
		Polar = new _3D_animated( 46, 206, "polar.bmp", 11, 258, 274, 0, 0, 258, 274,
		                                   ANIMA_FULL_TIMER, ANIMA_FULL_PERIOD	);

	 
	};

scene *geladeira::CreateNewScene( int ExitNum )
	{       
		if( ExitNum == NumExitPorta1 )
		{
		 	return new cozinha( "cozinha", HAS_PLAYER, HAS_CTRL_PANEL, NO_STAT_BAR ); 
		}                                         
		else
		if( ExitNum == NumExitPorta2 )
		{
		 	return new cozinha( "cozinha", HAS_PLAYER, HAS_CTRL_PANEL, NO_STAT_BAR ); 
		}                                         
		else
		{
			return scene::CreateNewScene( ExitNum );
		}
	};


scene *geladeira::Init( HWND hwnd )
	{

		HINSTANCE recebe = 0;

        JaPintei = FALSE;
		FPolar = TRUE;  //  permite que o mouse acione a planta carnívora
//        recebe = (HINSTANCE)GetWindowWord(hwnd, GWW_HINSTANCE);

		// inicializa os handles dos cursores 'seta'
//		hcurright = LoadCursor(recebe, "IDC_RIGHT");
//		hcurleft = LoadCursor((HINSTANCE)GetWindowWord(hwnd, GWW_HINSTANCE), "IDC_LEFT");
		hcursaida = LoadCursor(NULL, IDC_SIZEWE);
//		hcurleft = LoadCursor(NULL, IDC_LEFT);
	    hcurant = LoadCursor(NULL, IDC_ARROW);
	 	SetClassWord(hwnd, GCW_HCURSOR, (WORD)hcurant);
		
		
		scene::Init( hwnd );
		
		 // Definição em 3d - 1 par front inf esq do frame , 2par dimensões no olho da caixa
		Screen->SetVanishingPoint(514,102)->SetViewPoint(160,300,0,455,0)->SetyAxisShift(0,345);
		Porta1->Init( Screen )->Set3DOrigin(0,110)->Set3DDimensions(40,110,5)->Set3DPosition( Screen );
		Porta2->Init( Screen )->Set3DOrigin(0,110)->Set3DDimensions(40,110,5)->Set3DPosition( Screen );
		Polar->Init( Screen )->Set3DOrigin(58,313)->Set3DDimensions(200,500,1)->Set3DPosition( Screen );

		NumExitPorta1 = DefExit( Porta1, 58, 115 );  // cozinha
		NumExitPorta2 = DefExit( Porta2, 58, 115 );  // cozinha

	    DefLocal(Polar);

		return this;	
	}

boolean geladeira::MessageHandling( HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam )
	{
		HDC hdc;					
	 	object * Occup3DObj;                         
		occupation lastocc, occ;
		int _X, _Y;
		RECT  leftexit, rightexit;
//		POINT ponto;
		
		SetRect(&leftexit, 0, 270, 40, 380);
		SetRect(&rightexit, 600, 270, 640, 380);

		        
    	switch (msg)
	    {   

	        case WM_PAINT:
	        	
       		    SetTimer(hwnd, 10, 500, NULL); 
	        	
	        	return false;
	             
            case WM_TIMER:
                 
                 KillTimer(hwnd,10);
                 if ( !JaPintei )
                 {
            	 	 JaPintei = TRUE;
				 	 Polar->Init1SpriteAnim(hwnd, Screen); 
            	 }
              
            break;  
            
			case WM_MOUSEMOVE: 
			
/*				ponto.x = LOWORD(lParam);			
				ponto.y = HIWORD(lParam);			

				if((PtInRect(&leftexit, ponto))||(PtInRect(&rightexit, ponto)))
				{
		 		 	SetClassWord(hwnd, GCW_HCURSOR, (WORD)hcursaida);
				}
//				else if(PtInRect(&rightexit, ponto))
//					 {
//						hcurant = SetCursor(hcurleft);
//					 }
					 else
					 {
		 		 	 	SetClassWord(hwnd, GCW_HCURSOR, (WORD)hcurant);
					 }				
*/			break;
            
       		case WM_RBUTTONDOWN:
       		
				_X = this->Screen->ScreenX+LOWORD(lParam);
				_Y = this->Screen->ScreenY+HIWORD(lParam);
								                                          
				if( this->HasControlPanel() && Game->ControlPanel->IsIn(_X,_Y) )
				{
					return true;		
						//break;								                             
				}		  	

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
							if(Occup3DObj->Name == Polar->Name)
							{   
								FPolar  = FALSE; // não permite que o mouse acione
							}                        // a animação
						}
					}
				}   
				return false;

	       	case WM_SYSTIMER:                       

	            if ((JaPintei)&&(FPolar))
	            {
	            	 Polar->Anim1Frame(hwnd, Screen);
	            }


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


