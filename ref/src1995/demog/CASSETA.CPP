
#include "games.hpp"
#include "event.hpp"

#include "screen.hpp"
#include "3dscreen.hpp"
#include "object.hpp"
#include "3dobject.hpp"

#include "vtree.h"

#include "ctrpanel.hpp"

#include "scene.hpp"
#include "applicat.hpp"

#define _CASSETA

#include "casseta.hpp"

#undef _CASSETA

#include "zemane.hpp"
#include "quarpais.hpp"
#include "quartoze.hpp"


//char 			*ZeManeNames[] = { "boyfrent.bmp", "zemane2.bmp", "zemane1.bmp", "boyfren1.bmp" };    
//int             ZeManeFrames[] = { 1,8,8,4 };
//int             ZeManeWidth[] = { 165,165,165,165 };
//int             ZeManeHeight[] = { 247,247,247,247 };

char 			*ZeManeNames[] = { "passo1.bmp", "passladd.bmp", "passlade.bmp", "passolau.bmp", "passtras.bmp" };    
int             ZeManeFrames[] = { 1,8,8,8,8 };
int             ZeManeWidth[] = { 166,166,166,166,166 };
int             ZeManeHeight[] = { 265,265,265,265,265 };


zemane	*ZeMane;
casseta	*Casseta;


casseta::casseta( void )
{
		Casseta = this;
	
		Bola = new portable( "QuartoZe", 180, 300, "bola.bmp", 1, 50, 50, 
											PORTAB_TIMER, PORTAB_PERIOD,     
											PORTAB_DELTAX, PORTAB_DELTAY );

		Carteira = new portable( "QuartoZe", 500, 300, "carteira.bmp", 1, 20, 14, 
											PORTAB_TIMER, PORTAB_PERIOD,     
											PORTAB_DELTAX, PORTAB_DELTAY );
		
		Camisinha = new portable( "QuarPais", 330, 200, "camisinh.bmp", 1, 20, 20, 
											PORTAB_TIMER, PORTAB_PERIOD,     
											PORTAB_DELTAX, PORTAB_DELTAY );
}	



object * casseta::CreatePlayer( void )
{
	ZeMane = new zemane( 250, 100, 5,       ZeManeNames, ZeManeFrames, 
											ZeManeWidth, ZeManeHeight,
											33, 0, 100, 265,
//											50, 0, 70, 247,
											ZEMANE_TIMER, ZEMANE_PERIOD,     
											ZEMANE_DELTAX, ZEMANE_DELTAY );
												
	return ZeMane;												
};

control_panel * casseta:: CreateControlPanel( void )
{
		return new casseta_panel( 0, 340, "interf.bmp", 4, 640, 120, /* 0, 80, 640, 40, */ 
					CONTROL_PANEL_TIMER, CONTROL_PANEL_PERIOD );
};

status_bar * casseta::CreateStatusBar( void )
{       
		return new status_bar( 0, 420, RGB(255,255,0), "statnew.bmp", 1, 640, 40 );
};



scene *casseta::CreateInitScene( char *SceneName ) 
{
	return new quartoze( SceneName, HAS_PLAYER, HAS_CTRL_PANEL, NO_STAT_BAR, 0, 0, 
					DefaultScreenWidth, DefaultScreenHeight );    
};

application *casseta::Init( HWND hwnd )
{
	Bola->Set3DOrigin(3,46)->Set3DDimensions(50, 50, 50)->SetZ0(0); // ->Init(Screen)->Set3DPosition( Screen );
	Carteira->Set3DOrigin(0,13)->Set3DDimensions(20,14,2)->SetZ0(80); // ->Init(Screen)->Set3DPosition( Screen );
	Camisinha->Set3DOrigin(0,19)->Set3DDimensions(20,20,2)->SetZ0(150); // ->Init(Screen)->Set3DPosition( Screen );


 	application:: Init( hwnd, "QuartoZe" );


	Bola->DefIcon( "minbola.bmp" );
	Carteira->DefIcon( "mincarte.bmp" );
	Camisinha->DefIcon( "mincamis.bmp" );
		


//	ZeMane->Set3DOrigin(30,238)->Set3DDimensions(105,238,50)->Set3DPosition( CurrentScene->Screen );;
	ZeMane->Set3DOrigin(30,254)->Set3DDimensions(105,254,50)->Set3DPosition( CurrentScene->Screen );;

//	ZeMane->InitAnimP( hwnd, CurrentScene->Screen );				
        
    return this;
};



scene * quartoze::CreateNewScene( int ExitNum )
{       
	if( ExitNum == NumExitPorta )
	{
	 	return new quarpais( "Quarpais", HAS_PLAYER, HAS_CTRL_PANEL, NO_STAT_BAR ); 
	}                                         
	else
	{
		return scene::CreateNewScene( ExitNum );
	}
};


scene * quarpais::CreateNewScene( int ExitNum )
{       
	if( ExitNum == NumExitPorta )
	{
	 	return new quartoze( "QuartoZe", HAS_PLAYER, HAS_CTRL_PANEL, NO_STAT_BAR ); 
	}                                         
	else
	{
		return scene::CreateNewScene( ExitNum );
	}
};

