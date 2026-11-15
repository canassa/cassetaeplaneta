#pragma  warning( disable : 4250 )
        
#include <stdlib.h>
#include <string.h>

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
#include "scenenum.h"
                           
extern HFILE hArch;
extern int Number,X,Y,NumSprites,_3DOriginX,_3DOriginY,_3Dw,_3Dh,_3Dd,NumTimer,PerTimer,DeltaX,DeltaY;
extern int NumFrames,FrameW,FrameH,BoundX,BoundY,BoundW,BoundH,Cor,_3Dz0,PlayerX,PlayerY;
extern int ScreenX,ScreenY,ScreenW,ScreenH,VanishX,VanishY,ViewX,ViewY,View_x,View_y,View_z,AxisX,AxisY;
extern int LinhaSup,ColunaSup,LinhaLatEsq,ColunaLatEsq,DeltaLatEsq,LinhaLatDir,ColunaLatDir,DeltaLatDir;
extern char NomeBMP[9],InitialScene[9],ScreenBMP[9],Name[9],SceneInName[9];
extern BOOL Has_Player,Has_ControlPanel,Has_StatusBar,Is_1Animation,Is_ClickExit;
//boolean Is1Animation,IsClickExit;				      


// exemplo para casos particulares
boolean DefaultMessageHandling( HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam )
{
	return false;
}


boolean (*VetMessageHandling[MAX_SCENES])( HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam ) =
{
  	&DefaultMessageHandling
};


gen_scene::gen_scene(HFILE hArch,char *_Name, boolean _Has_Player, boolean _Has_ControlPanel, boolean _Has_StatusBar, 
										boolean _Is1Animation, 	boolean _IsClickExit ) :
		   scene( _Name, _Has_Player, _Has_ControlPanel, _Has_StatusBar,
		   				 _Is1Animation, _IsClickExit ) 
{ 

//	SeekScene(hArch, _Name);

};


scene *gen_scene::CreateNewScene( int ExitNum )
{       
	if( ExitNum <= NumExits )
	{
		return new gen_scene( 	hArch,
								VetExits[ExitNum]->SceneInName, 
								VetExits[ExitNum]->SceneInHasPlayer,
								VetExits[ExitNum]->SceneInHasControlPanel,
								VetExits[ExitNum]->SceneInHasStatusBar,
								VetExits[ExitNum]->SceneInIs1Animation,
								VetExits[ExitNum]->SceneInIsClickExit
							);
	} 	
	else
	{
		return scene::CreateNewScene( ExitNum );
	}
};


scene *gen_scene::Init( HWND hwnd )
{    

    _3D_object   *Obj;
    exits	     *Exit;
	int          i,j,k;
    _3D_screen   *_3DScreen;
    char         ch;
	char        *BMPcompleto;    
	char         Buffer[256];
	
	SeekScene(hArch, Name);
			
	ReadScreen(hArch,&Number,ScreenBMP,&ScreenX,&ScreenY,&ScreenW,&ScreenH,
						  &VanishX,&VanishY,&ViewX,&ViewY,&View_x,&View_y,&View_z,
						  &AxisX,&AxisY );
    
    SceneNumber = Number;

	BMPcompleto = MontaNome(ScreenBMP,-1);

	Screen = new _3D_screen(BMPcompleto, ScreenX, ScreenY, ScreenW, ScreenH);  //  , Number);
    	
 	_3DScreen = Screen->Init( hwnd )->To3DScreen();

	_3DScreen->LocalObjects = &LocalObjects;

	_3DScreen	->SetVanishingPoint(VanishX, VanishY)
				->SetViewPoint(ViewX, ViewY, View_x, View_y, View_z)
				->SetyAxisShift(AxisX, AxisY);

	ReadLimits(hArch,&LinhaSup,&ColunaSup,&LinhaLatEsq,&ColunaLatEsq,
					  &DeltaLatEsq,&LinhaLatDir,&ColunaLatDir,&DeltaLatDir);
		
	 	
	for( i = 0; i < LinhaSup; i++ )
	{                                             // teto
	 	for( j = 0; j < ColunaSup; j++ )
	 	{
	 		_3DScreen->Occup->SetOccup( i, j, WALL );
	 	}
	}   

	for( i = LinhaSup, k = ColunaLatEsq; i < LinhaLatEsq; i++, k-=DeltaLatEsq ) 
	{                 
	 	for( j = 0; j < k; j++ )
	 	{
	 		_3DScreen->Occup->SetOccup( i, j, WALL );     // triangulo esquerdo
	 	}
	}   

	for( i = LinhaSup, k = 0; i < LinhaLatDir; i++, k+= DeltaLatDir )
	{                 
	 	for( j = ColunaLatDir + k; j < 40; j++ )   //  triangulo direito
	 	{
	 		_3DScreen->Occup->SetOccup( i, j, WALL );
	 	}
	}


	if( Is1Animation )
	{

		ReadExit(hArch,&Number,&X,&Y,NomeBMP,&NumFrames,&FrameW,&FrameH,&BoundX,&BoundY,
		 			&BoundW,&BoundH,&_3DOriginX,&_3DOriginY,&_3Dw,&_3Dh,&_3Dd,&NumTimer,&PerTimer,
		 			SceneInName,&PlayerX,&PlayerY,&Has_Player,&Has_ControlPanel,&Has_StatusBar,
		 			&Is_1Animation, &Is_ClickExit);
		 	                        
		BMPcompleto = MontaNome(NomeBMP,-1);

		AutoExit = new exits(Number,X,Y,BMPcompleto,NumFrames,FrameW,FrameH,BoundX,BoundY,BoundW,BoundH,NumTimer,PerTimer );
			          
		AutoExit->Set3DOrigin(_3DOriginX,_3DOriginY)->Set3DDimensions(_3Dw,_3Dh,_3Dd);
						          
	 	AutoExit->InitExit(_strlwr(SceneInName), PlayerX, PlayerY, (boolean)Has_Player,(boolean)Has_ControlPanel, (boolean)Has_StatusBar, (boolean)Is_1Animation, (boolean)Is_ClickExit);
	}

                             
	do
	{                   
//		SkipSeparators();
	          
		switch( ch = toupper(LookChar(hArch)) )
		{		
		
			case 'L':
			{                 
			
			 	ReadObject(hArch,&Number,&X,&Y,NomeBMP,&FrameW,&FrameH,&BoundX,&BoundY,
			 				&BoundW,&BoundH,&_3DOriginX,&_3DOriginY,&_3Dw,&_3Dh,&_3Dd);
	                       
				BMPcompleto = MontaNome(NomeBMP,-1);
		
				Obj = new _3D_object(Number,X,Y,BMPcompleto,FrameW,FrameH,BoundX,BoundY,BoundW,BoundH);                      
		
				Obj->Set3DOrigin(_3DOriginX,_3DOriginY)->Set3DDimensions(_3Dw,_3Dh,_3Dd); 
		
				DefLocal( Obj );
			}       
			break;
			
			case 'S':
			{
			
			 	ReadStatic(hArch,&Number,&X,&Y,NomeBMP,&NumFrames,&FrameW,&FrameH,
			 					&BoundX,&BoundY,&BoundW,&BoundH,&_3DOriginX,&_3DOriginY,
			 					&_3Dw,&_3Dh,&_3Dd,&NumTimer,&PerTimer);

				BMPcompleto = MontaNome(NomeBMP,-1);

				Obj = new _3D_animated(Number,X,Y,BMPcompleto,NumFrames,FrameW,FrameH,BoundX,BoundY,BoundW,BoundH,NumTimer,PerTimer);                      
		
				Obj->Set3DOrigin(_3DOriginX,_3DOriginY)->Set3DDimensions(_3Dw,_3Dh,_3Dd); 
		
				Game->DefStatic( Obj,Name ); 
			}
	        break;
	        
			case 'A':
			{
			
			 	ReadAnimated(hArch,&Number,&X,&Y,NomeBMP,&NumFrames,&FrameW,&FrameH,
			 					&BoundX,&BoundY,&BoundW,&BoundH,&_3DOriginX,&_3DOriginY,
			 					&_3Dw,&_3Dh,&_3Dd,&NumTimer,&PerTimer);
	                        
				BMPcompleto = MontaNome(NomeBMP,-1);

				Obj = new _3D_animated(Number,X,Y,BMPcompleto,NumFrames,FrameW,FrameH,BoundX,BoundY,BoundW,BoundH,NumTimer,PerTimer);                      
		
				Obj->Set3DOrigin(_3DOriginX,_3DOriginY)->Set3DDimensions(_3Dw,_3Dh,_3Dd); 
		
				DefLocal( Obj );
			}
	        break;
	        
			case 'E':
			{
			 	ReadExit(hArch,&Number,&X,&Y,NomeBMP,&NumFrames,&FrameW,&FrameH,&BoundX,&BoundY,
			 			&BoundW,&BoundH,&_3DOriginX,&_3DOriginY,&_3Dw,&_3Dh,&_3Dd,&NumTimer,&PerTimer,
			 			SceneInName,&PlayerX,&PlayerY,&Has_Player,&Has_ControlPanel,&Has_StatusBar,
			 			&Is_1Animation, &Is_ClickExit);
			 	                        
				BMPcompleto = MontaNome(NomeBMP,-1);

				Exit = new exits(Number,X,Y,BMPcompleto,NumFrames,FrameW,FrameH,BoundX,BoundY,BoundW,BoundH,NumTimer,PerTimer );
					          
				Exit->Set3DOrigin(_3DOriginX,_3DOriginY)->Set3DDimensions(_3Dw,_3Dh,_3Dd);
								          
			 	Exit->InitExit(_strlwr(SceneInName), PlayerX, PlayerY, (boolean)Has_Player, (boolean)Has_ControlPanel, (boolean)Has_StatusBar, (boolean)Is_1Animation, (boolean)Is_ClickExit);
		
				DefLocal( Exit );		 	
			}
			break; 
			default: 
			    if (ch != '[')
			    {                             
					SkipLine( hArch, Buffer );
					MessageBox("Erro Fatal !!", "Linha [%s] inválida" , Buffer);
					exit(1);
				}
			break;
		}
	}		
	while(ch != '[');

        
	object *LocalObj = Screen->LocalObjects->FirstObject;
			
	while( LocalObj != NULL )
	{
        LocalObj->Init( Screen )->Set3DPosition( Screen );

		if( LocalObj->IsExit() )
		{
			DefExit( LocalObj->ToExit() );
		}

	    LocalObj = LocalObj->Next;
	}    
							
	return this;	
}

boolean gen_scene::MessageHandling( HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam )
{
		static boolean Exiting = false;
		static boolean WaitingClick = false;

		HDC hdc;					
				

		if( VetMessageHandling[SceneNumber] != NULL )
		{
			if( (*VetMessageHandling[SceneNumber])( hwnd,msg,wParam,lParam ) )
			{
			    return true;
			}
		}			

    	switch (msg)
	    {       
			case WM_INITSCENE:
			
				Game->ControlPanel->SetText( Name );
				Game->ControlPanel->Put( Screen );
				Game->ControlPanel->Show();      

				if( Is1Animation )
				{
        			AutoExit->Init( Screen )->Set3DPosition( Screen );

					DefExit( AutoExit );

					AutoExit->InitAnim( hwnd, Screen );
					Exiting = true;
				}

				
			break;
			
			case WM_RBUTTONDOWN:
			case WM_LBUTTONDOWN:

				if( WaitingClick )
				{
					Exiting = false;
					Game->DirtyObjects.Reset();
		  			WaitingClick = false;
		  			Game->SetCurrentScene( hwnd, (int) wParam );
		  			return true;
				
				}
				else
				{
					return false;
				}

			break;			

	       	case WM_SYSTIMER: 
		       	
				if( Is1Animation && wParam == (WPARAM) AutoExit->Timer() )
				{                                     
					AutoExit->Anim1Frame(hwnd, Screen);
				}	       	                      
				else	
				if( wParam <= (WPARAM) LAST_SPRITE_TIMER )
				{                                     
					object *LocalObj = Screen->LocalObjects->FirstObject;

					int i = 1;

					do
					{
						while( LocalObj != NULL )
						{
							if( LocalObj->IsAnimating() )
							{
								LocalObj->Anim1Frame(hwnd, Screen);
							}
						
						    LocalObj = LocalObj->Next;
						}    

						LocalObj = Game->FirstStaticObject;
					}
					while( i-- );
					
				}	       	                      
	
				return false;
		  	break; 
		  	 
		  	case WM_EXITSCENE: 	// wParam is the number of the exit that was caught to get out of the current scene

				if( Exiting )
				{
					if( IsClickExit )
					{
			  			WaitingClick = true;
					}
					else
					{
						Exiting = false;
						Game->DirtyObjects.Reset();
			  			WaitingClick = false;
			  			Game->SetCurrentScene( hwnd, (int) wParam );
					}

					return true;
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



int gen_scene::DefExit( exits *Exit, char *_SceneInName, int PlayerX, int PlayerY, event *_OpenningEvent )	 
{
	Exit->InitExit( _SceneInName, PlayerX, PlayerY, NumExits, _OpenningEvent );

	VetExits[NumExits++] = Exit;

	return NumExits-1;
	
};
    
int gen_scene::DefExit( exits *Exit )	 
{
	VetExits[NumExits] = Exit->SetExitNum(NumExits);
             
	NumExits++;
	             
	return NumExits-1;
	
};
    

int gen_scene::DefAltExit( exits *Exit, char *_SceneInName, int PlayerX, int PlayerY )	 
{
	Exit->SetAlternativeExit( _SceneInName, PlayerX, PlayerY, NumExits );

	VetExits[NumExits++] = Exit;

	return NumExits-1;
	
};
    




