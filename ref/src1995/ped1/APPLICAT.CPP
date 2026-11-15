
#define _APPLICAT

#include "games.hpp"
#include "event.hpp"

#include "screen.hpp"
#include "3dscreen.hpp"
#include "object.hpp"
#include "3dobject.hpp"

#include "vtree.h"

#include "scene.hpp"
#include "ctrpanel.hpp"
#include "applicat.hpp"

#undef _APPLICAT




boolean application::MessageHandling( HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam )
{
    static      
    boolean 	InKeyLeft = false,
				InKeyRight = false,
				InKeyUp = false,
				InKeyDown = false,
				Dragging = false,
				Exiting = false;

	static portable *Selected = NULL;         
	static int Under_h = 0;
	
	boolean AnyKeyPressed = false;
	
 	object * Occup3DObj;                         
	occupation lastocc,occ;
	HDC hdc;
	portable *Portable;
	boolean ret = true;
	int _X, _Y, _X1, _Y1;
				
		if( !CurrentScene->MessageHandling( hwnd,msg,wParam,lParam ) )
		{
	    	switch (msg)
		    {       
				case WM_KEYDOWN: 

					if( CurrentScene->HasPlayer() )
					{           
						AnyKeyPressed = true;
						
						switch(wParam)
						{
							case VK_LEFT:
								if( !InKeyLeft )                    
								{                                       
									InKeyLeft = true;                                        
									Player->InitHMove( hwnd, CurrentScene->Screen, MV_LEFT );
									Player->Move1Step(hwnd, CurrentScene->Screen);
								}         
							break;
							case VK_RIGHT:
								if( !InKeyRight )                    
								{                                       
									InKeyRight = true;
									Player->InitHMove( hwnd, CurrentScene->Screen, MV_RIGHT );
									Player->Move1Step(hwnd, CurrentScene->Screen);
								}         
							break;
							case VK_UP:
								if( !InKeyUp )                    
								{                                       
									InKeyUp = true;
									Player->InitVMove( hwnd, CurrentScene->Screen, MV_UP );
									Player->Move1Step(hwnd, CurrentScene->Screen);
								}         
							break;
							case VK_DOWN:
								if( !InKeyDown )                    
								{                                       
									InKeyDown = true;
									Player->InitVMove( hwnd, CurrentScene->Screen, MV_DOWN );
									Player->Move1Step(hwnd, CurrentScene->Screen);
								}         
							break;
							default:
								AnyKeyPressed = false;
								ret = false;
							break;
					    };
					    
//					    if( ret )
					    if( AnyKeyPressed )
					    {
							AnyKeyPressed = false;
							
							if( CurrentScene->HasControlPanel() )
							{
								ControlPanel->Put( CurrentScene->Screen );
							}
			
							if( CurrentScene->HasStatusBar() )
							{
								StatusBar->Put( CurrentScene->Screen );
							}
							
							if( !DirtyObjects.IsEmpty() )
							{
								hdc = GetDC(hwnd);
	
								DirtyObjects.Refresh(hdc, CurrentScene->Screen);
					
								ReleaseDC(hwnd, hdc);
					        }
					    }
					    
				    }
				    else
				    {
						ret = false;
				    }
				    
				break;               
				case WM_KEYUP: 

					if( CurrentScene->HasPlayer() )
					{
						switch(wParam)
						{
							case VK_LEFT:
									InKeyLeft = false;
									Player->EndMove( hwnd, CurrentScene->Screen );
									break;
							case VK_RIGHT:
									InKeyRight = false;
									Player->EndMove( hwnd, CurrentScene->Screen );
									break;
							case VK_UP:
									InKeyUp = false;
									Player->EndMove( hwnd, CurrentScene->Screen );
									break;
							case VK_DOWN:
									InKeyDown = false;
									Player->EndMove( hwnd, CurrentScene->Screen );
									break;
							default:
								ret = false;
					    };
				    }
				    else
				    {
						ret = false;
				    }
					  
				    
		       	break;               
				case WM_LBUTTONDOWN: 
					if( CurrentScene->HasPlayer() )
					{
					    Player->InitMove( hwnd, LOWORD(lParam), HIWORD(lParam), CurrentScene->Screen );
					}
				    else
				    {
						ret = false;
				    }
							
			    break;               
				case WM_MOUSEMOVE: 

					if( CurrentScene->HasControlPanel() )
					{
						if( HIWORD(lParam) > 440 )
						{
							if( !ControlPanel->IsOn() && !ControlPanel->IsAnimating() )
							{
								if( CurrentScene->HasStatusBar() )
								{
									hdc = GetDC(hwnd);
									StatusBar->Restore( CurrentScene->Screen );
									ReleaseDC(hwnd, hdc);
								}
								
								ControlPanel->InitAnim(hwnd, CurrentScene->Screen, MV_UP);
								ControlPanel->Put(CurrentScene->Screen);
							}
						}
						else
						if( HIWORD(lParam) < 340 && !Dragging)
						{                 
							if( ControlPanel->IsOn() && !ControlPanel->IsAnimating() )
							{
								ControlPanel->InitAnim(hwnd, CurrentScene->Screen, MV_DOWN);
								ControlPanel->Put(CurrentScene->Screen);
							}
						}
					}
				    else
				    {
						ret = false;
				    }
			
			    break;               
				case WM_SYSTIMER:
			
					if( CurrentScene->HasControlPanel() && wParam == (WPARAM) ControlPanel->Timer() )
					{   
//						if( CurrentScene->HasControlPanel() )
						{
							ControlPanel->Anim1Frame(hwnd, CurrentScene->Screen);  
                                                     
							if( CurrentScene->HasPlayer() && ControlPanel->object::DetectedCollision( Player ) )
							{
								Player->Put(CurrentScene->Screen);
								Player->TreatCollision( hdc, CurrentScene->Screen, false );
							}
							
							ControlPanel->Put(CurrentScene->Screen);

							if( !DirtyObjects.IsEmpty() )
							{
								hdc = GetDC(hwnd);
				
								DirtyObjects.Refresh(hdc, CurrentScene->Screen);

								ReleaseDC(hwnd, hdc);
							}	


						}
					}
					else
					{
						if( CurrentScene->HasPlayer() && wParam == (WPARAM) Player->Timer() )
						{   
//							if( CurrentScene->HasPlayer() )
							{
								if( !Player->IsMoving() ) 
								{
									Player->Anim1Frame(hwnd, CurrentScene->Screen);
								}
								else
								{
									Player->Move1Step(hwnd, CurrentScene->Screen);
								}
							}
						}
						else
						if( Selected != NULL && wParam == (WPARAM) Selected->Timer() )
						{   
							Selected->Move1Step(hwnd, CurrentScene->Screen);
							
							if( !Selected->IsMoving() )
							{                                  
								Selected->Set3DPosition( CurrentScene->Screen, Under_h );
							 	Selected = NULL;
							}
						}

						if( CurrentScene->HasControlPanel() )
						{
							ControlPanel->Put( CurrentScene->Screen );
						}
		
						if( CurrentScene->HasStatusBar() )
						{
							StatusBar->Put( CurrentScene->Screen );
						}
						
						if( !DirtyObjects.IsEmpty() )
						{
							hdc = GetDC(hwnd);

							DirtyObjects.Refresh(hdc, CurrentScene->Screen);
				
							ReleaseDC(hwnd, hdc);
				        }

					}
																		
					ret = false;
	
			  	break;
				case WM_RBUTTONDOWN: 

					_X = CurrentScene->Screen->ScreenX+LOWORD(lParam);
					_Y = CurrentScene->Screen->ScreenY+HIWORD(lParam);
								                                          
					if( CurrentScene->HasControlPanel() && ControlPanel->IsIn(_X,_Y) )
					{
						if( CurrentScene->MayDropObjects )
						{
							Selected = ControlPanel->SelectedObject( &(Player->To3DPlayer()->Portables), _X, _Y );
		
							if( Selected != NULL )
							{
								Dragging = true;									
								ret = false;
										
								break;								                             
							}
						}
					}

	                
	                occ = CurrentScene->Screen->Occupation(CurrentScene->Screen->ScreenX+LOWORD(lParam), CurrentScene->Screen->ScreenY+HIWORD(lParam), CELL_WIDTH, CELL_HEIGHT, Occup3DObj, lastocc);
	
					if( occ > 0 )                                            
					{               
						if( Occup3DObj != NULL )
						{
							if( Occup3DObj->IsExit() )
							{
	
								if( !CurrentScene->HasPlayer() || abs( Player->X+Player->BoundX()+Player->BoundWidth()/2 -  (Occup3DObj->X+ Occup3DObj->BoundX()+ Occup3DObj->BoundWidth()/2) ) < 3*Player->BoundWidth()/2 )
								{
									if( Occup3DObj->IsOpened() )
									{
										Occup3DObj->InitAnim(hwnd, CurrentScene->Screen );
										Exiting = true;
									}
								}
								
							    ret = true;
							}
							else		
							if( Occup3DObj->IsPortable() )
							{
//								if( !CurrentScene->HasPlayer() || abs( Player->X+Player->BoundX()+Player->BoundWidth()/2 -  (Occup3DObj->X+ Occup3DObj->BoundX()+ Occup3DObj->BoundWidth()/2) ) < 3*Player->BoundWidth()/2 )
//								if( CurrentScene->HasPlayer() && !Player->To3DPlayer()->Portables.IsFull() )
								if( !Player->To3DPlayer()->Portables.IsFull() )
								{
										Portable = Occup3DObj->ToPortable();
										Portable->ChangeOwner(Player->To3DPlayer()); 

//										ControlPanel->Restore( CurrentScene->Screen );		
	
										hdc = GetDC(hwnd);                          
										Portable->ResetDirtyRect();
										Portable->Hide( hdc, CurrentScene->Screen );
										Portable->TreatCollision( hdc, CurrentScene->Screen, false ); // to update the objects that should be colliding with it
										ReleaseDC(hwnd, hdc);

										ControlPanel->Save( CurrentScene->Screen );		
								}
							}
							else		
							if( Occup3DObj->IsAnimated() )
							{
//								if( !CurrentScene->HasPlayer() || abs( Player->X+Player->BoundX()+Player->BoundWidth()/2 -  (Occup3DObj->X+ Occup3DObj->BoundX()+ Occup3DObj->BoundWidth()/2) ) < 3*Player->BoundWidth()/2 )
								{
									Occup3DObj->ToAnimated()->Init1SpriteAnim(hwnd, CurrentScene->Screen);
								}
							}
						}
					}
						
				    ret = false;
			    
			  	break;
				case WM_RBUTTONUP: 
					
					if( Dragging )
					{
						Dragging = false;
						
						_X = CurrentScene->Screen->ScreenX+LOWORD(lParam);
						_Y = CurrentScene->Screen->ScreenY+HIWORD(lParam);
						
						if( ControlPanel->IsOut( _X, _Y ) )
						{
							Portable = Selected;

							Portable->ChangeOwner(CurrentScene); 

							ControlPanel->Restore( CurrentScene->Screen );		
							ControlPanel->TreatCollision( hdc, CurrentScene->Screen );
	
							Portable->SetPosition( 	_X-Portable->FrameWidth()/2, _Y-Portable->FrameHeight()/2, 
													CurrentScene->Screen ); // , Portable->Find_z(CurrentScene->Screen, OccupObj) );

							Portable->Find_z(CurrentScene->Screen, Occup3DObj);

							Portable->Appear( CurrentScene->Screen );
							    
							_X = _X-Portable->FrameWidth()/2 - CurrentScene->Screen->ScreenX;

							Under_h = 0;
							
							if( Occup3DObj != NULL )
							{                                                             
	                                
								if( ! Portable->object::DetectedCollision( Occup3DObj ) )
								{							                                      
									Get2DPosition( CurrentScene->Screen, Occup3DObj->x3D(), Occup3DObj->y3D(), Occup3DObj->z3D()+Occup3DObj->h3D(), _X1, _Y1 );
									Get2DPosition( CurrentScene->Screen, Occup3DObj->x3D(), Occup3DObj->y3D()+Occup3DObj->d3D(), Occup3DObj->z3D()+Occup3DObj->h3D(), _X1, _Y );
	                                
	                                _Y = (_Y1 + _Y)/2+Portable->FrameHeight()/2;

									Portable->InitMove( hwnd, _X, _Y, CurrentScene->Screen );
									Under_h = Occup3DObj->h3D();
		                        }
		                        else
								{
									Selected = NULL;
								}	                        
		                        
							}
							else
							{
								_Y = CurrentScene->Screen->ScreenHeight-100;

								Portable->InitMove( hwnd, _X, _Y, CurrentScene->Screen );
							}                                                                             
							                                      
    						// it is not necessary to treat collision here because 
    						// the portable object will always be in front of any object
    						
							ControlPanel->Put( CurrentScene->Screen );

							hdc = GetDC(hwnd);
//							ControlPanel->TreatCollision( hdc, CurrentScene->Screen );
							ControlPanel->Show();

//							Portable->Show( hdc, CurrentScene->Screen );
							Portable->Show();
							ReleaseDC(hwnd, hdc);
						}

//						Selected = NULL;
	                }
	                
	        	break;
			  	case WM_EXITSCENE: 	// wParam is the number of the exit that was caught to get out of the current scene

					if( Exiting )
					{
						Exiting = false;
						DirtyObjects.Reset();
			  			SetCurrentScene( hwnd, (int) wParam );
			  			ret =  true;
			  		}
			  		else
			  		{
			  		 	ret = false;
			  		}                
			  		
				break;			  	
			  	default:
		  			ret = false;
			};                   
		};
		
		return ret;		
};


application * application::SetCurrentScene( HWND hwnd, int ExitNum )
{                                                                  

		int PlayerNewX 	= CurrentScene->VetExits[ExitNum]->SceneInPlayerX; 
		int PlayerNewY 	= CurrentScene->VetExits[ExitNum]->SceneInPlayerY;  
//		char *Name 		= CurrentScene->VetExits[ExitNum]->SceneInName;   
	    
/*		if( LastScene != NULL )	        
		{
		    if( false ) // strcmp( Name, LastScene->Name ) == 0 )
		    {
				scene *AuxScene = CurrentScene;
				CurrentScene = LastScene;
				LastScene = AuxScene;	    

				CurrentScene->Paint();        
	    	}
		    else    
			{
				delete LastScene;

				LastScene = CurrentScene;
		
				CurrentScene = LastScene->CreateNewScene(ExitNum);
				CurrentScene->Init(hwnd);        
			
			}   
		}
	    else    
		{
			LastScene = CurrentScene;

			CurrentScene = LastScene->CreateNewScene(ExitNum);
			CurrentScene->Init(hwnd);        

		}   
		                 
*/

		LastScene = CurrentScene;
	
		CurrentScene = LastScene->CreateNewScene(ExitNum);
		CurrentScene->Init(hwnd);        
	
		delete LastScene;
		LastScene = NULL;

		Portables.Init(CurrentScene);

        HDC hdc = GetDC(hwnd);

//		Player->Hide(hdc, LastScene->Screen);
		        
//		LastScene->Dark()->Show(hdc);		
		
		if( CurrentScene->HasPlayer() )
		{
			Player->CollideObject = NULL;
			Player->UpdatePalette( hdc, CurrentScene->Screen );
		}
		
		if( CurrentScene->HasStatusBar() )
		{
			StatusBar->UpdatePalette( hdc, CurrentScene->Screen );
			StatusBar->Appear( CurrentScene->Screen );
//			StatusBar->Restore( CurrentScene->Screen );
		}                                            

		if( CurrentScene->HasControlPanel() )
		{
			ControlPanel->UpdatePalette( hdc, CurrentScene->Screen );
			ControlPanel->Appear( CurrentScene->Screen );
		}			

		if( CurrentScene->HasPlayer() )
		{
			Player->SetPosition( PlayerNewX, PlayerNewY, CurrentScene->Screen );				
//			Player->Appear( CurrentScene->Screen );
			Player->Appear( CurrentScene->Screen );
        }
        
		if( CurrentScene->HasStatusBar() )
		{
			StatusBar->Put( CurrentScene->Screen );
    	}
    	
		if( CurrentScene->HasControlPanel() )
		{
			ControlPanel->Put( CurrentScene->Screen );
		}			

		if( CurrentScene->HasPlayer() )
		{
			Player->InitAnimP( hwnd, CurrentScene->Screen );
//			Player->Show( hdc, CurrentScene->Screen );
		}
		
        ReleaseDC( hwnd, hdc );

//		SendMessage( hwnd, WM_PAINT, 0, 0L );
		InvalidateRect(hwnd,NULL,TRUE);

		PostMessage( hwnd, WM_INITSCENE, 0, NULL );
		
		return this;

};  
	

