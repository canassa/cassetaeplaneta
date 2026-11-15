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
#include "readdata.hpp" 
#include "msghandl.hpp" 
#include "scenenum.h"

/*
// exemplo para casos particulares
boolean CozinhaMessageHandling( HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam )
{
	static BOOL  FBaranda = FALSE;
 	object * Occup3DObj;                         
	occupation lastocc, occ;
	int _X, _Y;
    
	switch (msg)
    {   
	    	    
   		case WM_RBUTTONDOWN:
       		
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
						if ( HasBaranda)//se a barata ja foi clicada uma pela
						{
							if(Occup3DObj->Name == Baranda->Name)
							{   
								if( !FIsCrawling )      
								{                   
									FBaranda  = TRUE;
									Barata->Init( Screen )->Set3DOrigin(50,114)->
										Set3DDimensions(120,100,80)->Set3DPosition( Screen );
								}	
								else // a barata ainda não foi clicada	
								{
									FBaranda  = FALSE;
								}
							}
						}
						if(Occup3DObj->Name == Barata->Name)  
						{                                     // só permite que a próxima animação seja 
							if(( FIsCrawling )&& ( FBaranda ))// chamada se a barata estiver no lugar certo
							{   
								HasBaranda = FALSE;
								return false;
							}	
							else	
							{
								return true;
							}  
						}	
						if(Occup3DObj->Name == Tomates3->Name)  
						{                                     // só permite que os tomates sejam
							if( !FIsSplashed )                // esmagados uma vez só
							{                
								FTomate = TRUE;
								return false;
							}	
							else	
							{
								return true;
							}
						}
					}
				}
			}   
			return false;
			    
	  	break;

       	case WM_SYSTIMER: 
	       	

			if( (wParam == (WPARAM) Tomates3->Timer()) && (FTomate))
			{                                     
				  if(Tomates3->IsAnimating())
				  {					  
				  		Tomates3->Anim1Frame(hwnd, Screen);
				  		FIsSplashed = TRUE;
				  }
			}       

			if(( wParam == (WPARAM) Barata->Timer()) && ( FIsCrawling )&& ( FBaranda ))
			{                                     
				  if(Barata->IsAnimating())      // só permite que a próxima animação seja 
				  {					             // chamada se a barata estiver no lugar certo
				  		Barata->Anim1Frame(hwnd, Screen);
				  }
			}       
			if ( HasBaranda)
			{
				if(( wParam == (WPARAM) Baranda->Timer() )&& ( FBaranda )) // se a barata estiver
				{                                                           // na posição inicial
					  if(Baranda->IsAnimating())
					  {		
							FIsCrawling = TRUE;
					  		Baranda->Anim1Frame(hwnd, Screen);
					  }
				}	       	                      
			}                

			return false;
	
  	break;
	  	default:
  			return false;
	};                   
		
	return false;
}
*/
boolean QuartozeMessageHandling( HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam )
	{

	 	static object * Occup3DObj = NULL;                         
		occupation lastocc, occ;
		int _X, _Y;
    
    	switch (msg)
	    {  
	    
       		case WM_LBUTTONDOWN: 
       		                             
       		                             
       			if((Occup3DObj != NULL)&&(Occup3DObj->IsAnimating())) 
       			{
		       	 	Occup3DObj->EndAnim(hwnd, Game->CurrentScene->Screen);  
		       	 	Occup3DObj = NULL;
				}
				return false;  
                     
       		break;                     

       		case WM_RBUTTONDOWN:
       		
        			if((Occup3DObj == NULL) || !Occup3DObj->IsAnimating()) 
       				{

						_X = Game->CurrentScene->Screen->ScreenX+LOWORD(lParam);
						_Y = Game->CurrentScene->Screen->ScreenY+HIWORD(lParam);
			                
		                occ = Game->CurrentScene->Screen->Occupation(Game->CurrentScene->Screen->
		                					ScreenX+LOWORD(lParam), Game->CurrentScene->Screen->ScreenY+
		                					HIWORD(lParam),CELL_WIDTH, CELL_HEIGHT, Occup3DObj, lastocc);
			
						if( occ > 0 )                                            
						{               
							if( Occup3DObj != NULL )
							{
								if( Occup3DObj->IsAnimated() )
								{
									if(Occup3DObj->Name == _RADIO) 
									{
										Occup3DObj->ToAnimated()->InitAnim(hwnd, Game->CurrentScene->Screen);
										return true;
									}
									 
								}
							}
						}
						
						Occup3DObj = NULL;
					}	
				else
       			if(Occup3DObj != NULL) 
       			{
		       	 	Occup3DObj->EndAnim(hwnd, Game->CurrentScene->Screen);  
		       	 	Occup3DObj = NULL;
				}
				return false;
			    
		  	break;
	       	
					       	                      
	       	case WM_SYSTIMER: 
	       	
				if( (Occup3DObj != NULL)&&(wParam == (WPARAM) Occup3DObj->Timer()) )
				{                                     
			  		Occup3DObj->Anim1Frame(hwnd, Game->CurrentScene->Screen);   
				}
				else
				{
					return false;
				}
	
		  	break;
	  	default:
	  			return false;
		};                   
		
		
		return true;

};

