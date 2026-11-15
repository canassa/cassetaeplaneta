
#define _SCENE

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

#undef _SCENE

                   
                   
scene * scene::Init( HWND hwnd )
{             
	Screen = CreateScreen();
    	
 	Screen->Init( hwnd );

	Screen->LocalObjects = &LocalObjects;

 	return this;
};
    
                   
scene::~scene( void ) 
{
 	register object *Obj = LocalObjects.FirstObject;
 	register object *Prev;
     	
 	while( Obj != NULL )
 	{
	 	Game->VisibleObjects.Extract(Obj->To3DObject());
	 	Prev = Obj;
	 	Obj = Obj->Next;
	 	delete Prev;
 	}

	delete Screen;

}

void scene::DefLocal( object *Object )
{
 	LocalObjects.Insert(Object);
	 	
 	Game->VisibleObjects.Insert(Object->To3DObject(), Screen);
};
    
                   
                   
int scene::DefExit( exits *Exit, int PlayerX, int PlayerY, event *_OpenningEvent )	 
{
	Exit->InitExit( PlayerX, PlayerY, NumExits, _OpenningEvent );

	VetExits[NumExits++] = Exit;

	return NumExits-1;
	
};
    
