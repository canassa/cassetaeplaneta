#pragma  warning( disable : 4250 )

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

gen_applic	*GenApplic;
HFILE       hArch;

int Number,X,Y,NumSprites,_3DOriginX,_3DOriginY,_3Dw,_3Dh,_3Dd,NumTimer,PerTimer,DeltaX,DeltaY;
int NumFrames,FrameW,FrameH,BoundX,BoundY,BoundW,BoundH,Cor,_3Dz0,PlayerX,PlayerY;
int ScreenX,ScreenY,ScreenW,ScreenH,VanishX,VanishY,ViewX,ViewY,View_x,View_y,View_z,AxisX,AxisY;
int LinhaSup,ColunaSup,LinhaLatEsq,ColunaLatEsq,DeltaLatEsq,LinhaLatDir,ColunaLatDir,DeltaLatDir;
char NomeBMP[9],InitialScene[9],ScreenBMP[9],Name[9],SceneInName[9];
BOOL Has_Player,Has_ControlPanel,Has_StatusBar,Is_1Animation,Is_ClickExit;				      

char* BMPcompleto;

gen_applic::gen_applic( void )
{                     
	GenApplic = this;
}	


object * gen_applic::CreatePlayer( void )
{
    object *Obj;
    int     i;
    char *  p;
    
	ReadPlayer(hArch,&Number,&X,&Y,&NumSprites,NomeBMP,&_3DOriginX,&_3DOriginY,
				&_3Dw,&_3Dh,&_3Dd,&NumTimer,&PerTimer,&DeltaX,&DeltaY);
                      
	Obj = new _3D_player(Number,X,Y,NumTimer,PerTimer,DeltaX,DeltaY);                      

	PDIB _pBitMap;
		
	for( i=0; i < NumSprites; i++ )
	{                   
		ReadSprite(hArch,&NumFrames,&FrameW,&FrameH,&BoundX,&BoundY,&BoundW,&BoundH);
    	
		_pBitMap = DibOpenFile(p = MontaNome(NomeBMP,i));
		 
		if( _pBitMap == 0 )
		{             
			MessageBox( "Erro Fatal!!", "Não foi possível abrir o arquivo: %s", p );
		}
		        	
		Obj->Sprites[i].Init(_pBitMap, NumFrames,FrameW,FrameH,BoundX,BoundY,BoundW,BoundH );
	}

	Obj->Set3DOrigin(_3DOriginX,_3DOriginY)->Set3DDimensions(_3Dw,_3Dh,_3Dd);

	return Obj;												
};

control_panel * gen_applic::CreateControlPanel( void )
{            
	control_panel *c;
	
	ReadControlPanel(hArch,&X,&Y,NomeBMP,&NumFrames,&FrameW,&FrameH,&NumTimer,&PerTimer);

	BMPcompleto = MontaNome(NomeBMP,-1);
                      
//	c = new control_panel(X,Y,BMPcompleto,NumFrames,FrameW,FrameH,NumTimer,PerTimer);
//	c = new control_panel();
	
//	c->Constr(X,Y,BMPcompleto,NumFrames,FrameW,FrameH,NumTimer,PerTimer);
	
//	return c;
	return new control_panel(X,Y,BMPcompleto,NumFrames,FrameW,FrameH,NumTimer,PerTimer);
};

status_bar * gen_applic::CreateStatusBar( void )
{       
	ReadStatusBar(hArch,&X,&Y,&Cor,NomeBMP,&FrameW,&FrameH);

	BMPcompleto = MontaNome(NomeBMP,-1);
                      
	return new status_bar( X,Y,Cor,BMPcompleto,1,FrameW,FrameH );
};



scene *gen_applic::CreateInitScene( void ) 
{
	scene *Scene;
	
//	long Pos;
	      
	ReadFirstScene(hArch,Name,&Has_Player,&Has_ControlPanel,&Has_StatusBar, &Is_1Animation, &Is_ClickExit );

//	Pos = SavePos(hArch);
		
	Scene = new gen_scene(hArch, Name, (boolean) Has_Player, (boolean) Has_ControlPanel, (boolean) Has_StatusBar, (boolean) Is_1Animation, (boolean) Is_ClickExit );

//	RestPos(hArch,Pos);

	return Scene;
};

application *gen_applic::Init( HWND hwnd )
{
	long Pos;
    object *Obj;
	char* NomeBMPico;
	
	hArch = AbreArquivo("casseta.ini");       // abre o arquivo .ini e coloca o ponteiro 
	if(!hArch)								   // no início da primeira linha da sessão 		
	{
		Error( "Não consegui abrir o casseta.ini" );
		return this;
	}
	BuildSectionIndex(hArch);

	SeekScene(hArch, "Casseta");                  

	CurrentScene = CreateInitScene();
        
    HDC hdc = GetDC(hwnd);

    PatBlt(hdc, 0,0, DefaultScreenWidth, DefaultScreenHeight, BLACKNESS); 
        
	Pos = SavePos(hArch);
		
	CurrentScene->Init(hwnd);        

	RestPos(hArch,Pos);

	Player = CreatePlayer();
	Player->Init( CurrentScene->Screen );

	ControlPanel = CreateControlPanel();
	ControlPanel->Init( CurrentScene->Screen );	  

	StatusBar = CreateStatusBar();
	StatusBar->Init( CurrentScene->Screen );		

             
	while( toupper(LookChar(hArch)) == 'P')
	{
		ReadPortable(hArch,&Number,InitialScene,&X,&Y,NomeBMP,&FrameW,&FrameH,&BoundX,
						&BoundY,&BoundW,&BoundH,&_3DOriginX,&_3DOriginY,&_3Dw,&_3Dh,&_3Dd,
						&_3Dz0,&NumTimer,&PerTimer);
                      
		BMPcompleto = MontaNome(NomeBMP,0);

		Obj = new portable(Number,_strlwr(InitialScene),X,Y,BMPcompleto,FrameW,FrameH,BoundX,BoundY,BoundW,BoundH,NumTimer,PerTimer);                      

		NomeBMPico = MontaNome(NomeBMP,2); 
			
		Obj->Set3DOrigin(_3DOriginX,_3DOriginY)->Set3DDimensions(_3Dw,_3Dh,_3Dd)->SetZ0(_3Dz0);
		Obj->ToPortable()->DefIcon(NomeBMPico); 
	}


	Portables.Init(CurrentScene);

		
	if( CurrentScene->HasPlayer() )
	{
		Player->Appear( CurrentScene->Screen );
//			Player->TreatCollision( hdc, CurrentScene->Screen );
	}

	if( CurrentScene->HasStatusBar() )
	{
		StatusBar->Appear(CurrentScene->Screen);
    }
        
	if( CurrentScene->HasControlPanel() )
	{
		ControlPanel->Appear( CurrentScene->Screen );	  
	}

//		CurrentScene->Portables.Put(CurrentScene->Screen);

    ReleaseDC( hwnd, hdc );

	if( CurrentScene->HasPlayer() )
	{
		Player->Set3DPosition( CurrentScene->Screen );

		Player->InitAnimP( hwnd, CurrentScene->Screen );
	}

	PostMessage( hwnd, WM_INITSCENE, 0, NULL );

    return this;
};

void InitGame(void)
{                                  
	for( int i = 0; i < MAX_SCENES; i++)
	{
		VetMessageHandling[i] = NULL;
	}                                                   
	
//	VetMessageHandling[_COZINHA] = &CozinhaMessageHandling;
	
}

