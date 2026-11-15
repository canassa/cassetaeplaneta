#define _3DOBJECT

#include "games.hpp"
#include "event.hpp"

#include "screen.hpp"
#include "3dscreen.hpp"
#include "object.hpp"
#include "3dobject.hpp"

#include "vtree.h"

#undef _3DOBJECT

#include "scene.hpp"
#include "ctrpanel.hpp"
#include "applicat.hpp"




object * _3D_object::Init( screen *Screen )
{            
	object:: Init(Screen);
		
//	w = h = d = 0;                   

	return this;	
}

object * _3D_moveable::Init( screen *Screen )
{            
	moveable::Init(Screen);

//	w = h = d = 0;                   
	
	return this;
}

void _3D_moveable::Show( void )
{
// put the object in the bag of dirty objects of the scene
	Game->DirtyObjects.Insert(this);                                                              
};
	

void Get3DPosition( screen *Screen, int &x, int &y, int z, int X, int Y, int w )
{            
	long _Y = Y; // Screen->ScreenHeight-(Y-Screen->ScreenY)-Y3DO;
	long _X = X; // (X-Screen->ScreenX)+X3DO;
	
//	z = _z;

	if( _Y != Screen->YV3D() ) 	
	{
		x = _X - ((long)(_Y - z))*((long)(_X-Screen->XV3D()))/((long)(_Y-Screen->YV3D())) + ((long)Screen->DX3D());

		y = ((long)Screen->v3D())*(((long)z) - _Y)/(_Y-Screen->YV3D());
	}
	else
	{
		x = _X  + ((long)Screen->DX3D());

		y = Screen->YV3D();
	}

}


void Get2DPosition( screen *Screen, int x, int y, int z, int &X, int&Y, int w )
{
 	x -= Screen->DX3D();

 	X = x + ((long)Screen->XV3D() - x)*(long)y/((long)y+Screen->v3D());
 	          
	Y = Screen->ScreenHeight - (z + ((long)Screen->YV3D() - z)*(long)y/((long)y+Screen->v3D()));
}  
          
object * _3D_object::DrawSolid( HWND hwnd, screen *Screen )
{            
	HDC  hdc;
	hdc = GetDC(hwnd);		            

	#ifdef Debug 
	   	DrawSolid( hdc, Screen );
	#endif

	ReleaseDC(hwnd,hdc);

	return this;	
}

	
object * _3D_object::DrawSolid( HDC hdc, screen *Screen )
{            

	HPEN hpen;
	HGDIOBJ hpenOld;
	int _X, _Y;
		     
	hpen = CreatePen( PS_SOLID, 1, RGB(255,255,0) );
	hpenOld = SelectObject(hdc,hpen);
	
	Get2DPosition( Screen, x,y,z, _X,_Y, w );
	MoveTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x+w,y,z, _X,_Y, w );
	LineTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x+w,y,z+h, _X,_Y, w );
	LineTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x,y,z+h, _X,_Y, w );
	LineTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x,y,z, _X,_Y, w );
	LineTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x,y+d,z, _X,_Y, w );
	LineTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x,y+d,z+h, _X,_Y, w );
	LineTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x+w,y+d,z+h, _X,_Y, w );
	LineTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x+w,y+d,z, _X,_Y, w );
	LineTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x,y+d,z, _X,_Y, w );
	LineTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x,y+d,z+h, _X,_Y, w );
	MoveTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x,y,z+h, _X,_Y, w );
	LineTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x+w,y,z+h, _X,_Y, w );
	MoveTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x+w,y+d,z+h, _X,_Y, w );
	LineTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x+w,y+d,z, _X,_Y, w );
	MoveTo( hdc, _X, _Y );
	
	Get2DPosition( Screen, x+w,y,z, _X,_Y, w );
	LineTo( hdc, _X, _Y );
	
	
	SelectObject(hdc,hpenOld);
	DeleteObject(hpen);

	return this;	
}
                

                
int _3D_object::x3D(void) { return x; };
int _3D_object::y3D(void) { return y; };
int _3D_object::z3D(void) { return z; };
int _3D_object::w3D(void) { return w; };
int _3D_object::h3D(void) { return h; };
int _3D_object::d3D(void) { return d; };
        
                
                
boolean _3D_object::DetectedCollision( object *o, screen *Screen )
{
	long _Y = Screen->ScreenHeight-(AuxY-Screen->ScreenY)-Y3DO;
	long _X = (AuxX-Screen->ScreenX)+X3DO;
	
	int _x, _y;

	Get3DPosition( Screen, _x, _y, z, _X, _Y, w );
		
	_x += w*((long)_y)/2L/(_y+(long)Screen->v3D());

    int
	ox = o->x3D(),
	oy = o->y3D(),
	oz = o->z3D(),
	ow = o->w3D(),
	oh = o->h3D(),
	od = o->d3D();

		if( _x+w < ox ) // o->x3D() )
			return false;
			
		if( _x > ox+ow ) // o->x3D()+o->w3D() )
			return false;
			
		if( _y+d < oy ) // o->y3D() )
			return false;
			
		if( _y > oy+od ) // o->y3D()+o->d3D() )
			return false;
			
		if( z+h < oz ) // o->z3D() )
			return false;
			
		if( z > oz+oh ) // o->z3D()+o->h3D() )
			return false;
			
		return true;
}
	

boolean portable::CanGo( screen *Screen)
{               
	return true;
};


boolean _3D_moveable::CanGo( screen *Screen)
{
		 	object * Occup3DObj; 
			occupation occ, lastocc;
	object *OccupObj;
	int i = 1;

            
			occ = Screen->Occupation(AuxX+BoundX(), AuxY+BoundY(), BoundWidth(), BoundHeight(), Occup3DObj, lastocc);

//			CollideObject = Occup3DObj;
						
			if( occ > FREE )
			{
				OccupObj = Screen->LocalObjects->FirstObject;

				do
				{	
					while( OccupObj != NULL )
					{
						if( OccupObj->IsVisible )
						{
							if( DetectedCollision( OccupObj, Screen ) )
							{
								return false;					
						    }
						}
							    
					    OccupObj = OccupObj->Next;
					}    
				
					OccupObj = Game->Portables.FirstObject;
				}
				while( i-- > 0 );
	
				return (boolean) (lastocc == FREE);
			}
			else                    
			{
				return (boolean) (occ == FREE);
			}
};



object * _3D_object::Set3DPosition( screen *Screen )
{                                                 
	int _z = Find_z(Screen, UnderObj);	
                                        
	return Set3DPosition( Screen, _z );                                        
}

object * portable::Set3DPosition( screen *Screen )
{                                                 
	int _z = Find_z(Screen, UnderObj);	
                                        
	return _3D_moveable::Set3DPosition( Screen, _z );                                        
}

object * _3D_moveable::Set3DPosition( screen *Screen )
{                                                 
	return Set3DPosition( Screen, 0 );                                        
}

object * _3D_object::Set3DPosition( screen *Screen, int _z)
{            
	long _Y = Screen->ScreenHeight-(Y-Screen->ScreenY)-Y3DO;
	long _X = (X-Screen->ScreenX)+X3DO;
	
	z = _z;
	
	Get3DPosition( Screen, x, y, z, _X, _Y, w );
		

	return this;
}

object * _3D_moveable::Set3DPosition( screen *Screen, int _z)
{            
/*	long _Y = Screen->ScreenHeight-(Y-Screen->ScreenY)-Y3DO;
	long _X = (X-Screen->ScreenX)+X3DO;
	
	z = _z;

	Get3DPosition( Screen, x, y, z, _X, _Y, w );
*/
	_3D_object::Set3DPosition( Screen, _z );
			
	x += w*((long)y)/2L/(y+(long)Screen->v3D());

	return this;
}

object * portable::Set3DPosition( screen *Screen, int _z)
{            
	return _3D_moveable::Set3DPosition( Screen, _z );
}



/*
object * _3D_moveable::Set3DPosition( screen *Screen )
{            
/ *	long _Y = Screen->ScreenHeight-(Y-Screen->ScreenY)-Y3DO;
	long _X = (X-Screen->ScreenX)+X3DO;
	
	z = _z;

	Get3DPosition( Screen, x, y, z, _X, _Y, w );
* /
	int _z = Find_z(Screen, UnderObj);	

	return Set3DPosition( Screen, _z );
}
*/

void portable::SetPosition(int _X, int _Y, screen *Screen )
{
  	moveable::SetPosition( _X, _Y );

	x = y = z = 0;
	    
//	int _z = Find_z(Screen, UnderObj);      		
	
//  	_3D_moveable::Set3DPosition( Screen, z ); // _z );       
      	
}

void portable::SetPosition(int _X, int _Y, screen *Screen, int _z)
{
  	_3D_moveable::SetPosition( _X, _Y, Screen, _z );
};

void _3D_moveable::SetPosition(int _X, int _Y, screen *Screen )
{
  	moveable::SetPosition( _X, _Y );
      		
  	Set3DPosition( Screen, 0 );       
      	
};

void _3D_moveable::SetPosition(int _X, int _Y, screen *Screen, int _z)
{
  	moveable::SetPosition( _X, _Y );
      		
  	Set3DPosition( Screen, _z );       
};

void _3D_object::SetPosition(int _X, int _Y, screen *Screen )
{
  	object::SetPosition( _X, _Y );
    
	int _z = Find_z(Screen, UnderObj);      		
	
  	Set3DPosition( Screen, _z );       
      	
};

void _3D_object::SetPosition(int _X, int _Y, screen *Screen, int _z)
{
  	object::SetPosition( _X, _Y );
    
  	Set3DPosition( Screen, _z );       
      	
};

void _3D_moveable::Paint(int _X, int _Y, screen *Screen )
{
	DesoccupScreen( Screen );
				
	SetPosition(_X,_Y, Screen);
		
//		RestoreBackGround( Screen->hBuffer );
	RestoreBackGround( Screen,1 );

	OccupScreen( Screen );

//		SaveBackGround( Screen->hBuffer ); 		
//		SaveBackGround( Screen->hBuffer2 ); 		

	SaveBackGround( Screen ); // , 2 ); 		

	Put( Screen );
	
//	PutIntoBuffer( (BITMAPINFO far * )&(Screen->BufferHeader), 
//					Screen->pBuffer );
					
};

void _3D_moveable::Show( HDC hdc, screen *Screen )
{
		    
	moveable::Show( hdc, Screen );
		
	char Buff[50];

	sprintf( Buff, "(%03d,%03d)=>(%03d,%03d,%03d)", X+X3DO, Screen->ScreenHeight-Y-Y3DO,
														x,y,z);
	if( Game->CurrentScene->HasStatusBar() )
	{
		Game->StatusBar->SetText( Buff, 100 );
	}

};


object * _3D_object::Set3DDimensions( int width, int height, int depth )
{            
	w = width;
	h = height;
	d = depth;
	
	return this;
}


object * _3D_object::Set3DOrigin( int _X3DO, int _Y3DO )
{
	X3DO = _X3DO;
	Y3DO = _Y3DO;

	return this;
}

                    
boolean portable::IsOn( object *o, screen *Screen )
{
	return _3D_object::IsOn( o, Screen ); // false;
}

boolean _3D_object::IsOn( object *o, screen *Screen )
{
	long _Y = Screen->ScreenHeight-(Y-Screen->ScreenY)-Y3DO;
	long _X = (X-Screen->ScreenX)+X3DO;
	
	int _x, _y;

	Get3DPosition( Screen, _x, _y, z, _X, _Y, w );
		
	if( _y > 0 )
	{
		_x += w*((long)_y)/2L/(_y+(long)Screen->v3D());
	}
	else
	{
		_x += w/2L;
	}
	

    int
	ox = o->x3D(),
	oy = o->y3D(),
	oz = o->z3D(),
	ow = o->w3D(),
	oh = o->h3D(),
	od = o->d3D();

		if( _x+w < ox ) // o->x3D() )
			return false;
			
		if( _x > ox+ow ) // o->x3D()+o->w3D() )
			return false;
			
		if( _y+d < oy ) // o->y3D() )
			return false;
			
		if( _y > oy+od ) // o->y3D()+o->d3D() )
			return false;
			
//		if( z+h <= oz ) // o->z3D() )
		if( z < oz ) // o->z3D() )
			return true;
		else
			return false;
}
                            
                    
boolean _3D_object::IsOver( object *o, screen *Screen )
{

		if( X+BoundX()+BoundWidth() < o->X+o->BoundX() )
			return false;
			
		if( X+BoundX() > o->X+o->BoundX()+o->BoundWidth() )
			return false;
			
		if( Y+BoundY() < o->Y+o->BoundY() ) 
			return true;
		else
			return false;
}
                            
                            
                            
int _3D_object::Find_z( screen *Screen, object * &OccupObj )
{
	
	register int i = 1;               

			
	OccupObj = Screen->LocalObjects->FirstObject;
			
	do
	{	
		while( OccupObj != NULL )
		{
			if( OccupObj->IsVisible )
			{
				if( OccupObj->Name != Name )
				{
					if( IsOver( OccupObj, Screen ) || object::DetectedCollision( OccupObj ) ) // , Screen ) )
					{
						return OccupObj->z3D()+OccupObj->h3D();
				    }
				}
			}
										    
		    OccupObj = OccupObj->Next;
		}    
							
		OccupObj = Game->Portables.FirstObject;
	}
	while( i-- > 0 );

	OccupObj = NULL;
	return 0;
}
                                       

boolean _3D_object::IsCloserThan( _3D_object * OccupObj, screen *Screen ) 
{
	boolean refresh = true;
//	register _3D_object *Occup3DObj = OccupObj->To3DObject();	
	
	if( OccupObj->y+OccupObj->d < y )
	{                         
			refresh = false;						    
	}  
	else
	if( OccupObj->y > y+d )
	{                         
			refresh = true;						    
	}  
	else
 	if( IsOn( OccupObj, Screen ) )
//	if( OccupObj->z3D() > z )
	{
		refresh = false;						    
	}
	else
 	if( OccupObj->IsOn( this, Screen ) )
//	if( OccupObj->z3D() < z )
	{
		refresh = true;						    
	}
	else
	{   
		int _X, _Y;
		
		if( !object::DetectedCollision( OccupObj ) )
		{
		 	return true;
		}		
		else				
		if( (X+X3DO > 0) ) //&& OccupObj->y3D() < y )
		{                                   
			Get2DPosition( Screen, OccupObj->x, OccupObj->y, OccupObj->z, _X, _Y);
												                                                          
			if(	abs(Screen->XV3D()-(X+X3DO)) > abs(Screen->XV3D()-_X) )
			{
				refresh = false;						    
			}
			else
			{
				refresh = true;						    
			}
		}                               
		else	// if the object is fully inside this then it mus be over, otherwise it would be !IsVisible
//	 	if( IsOn( OccupObj, Screen ) )
	 	{
			refresh = false;						    
	 	}

	}

	return refresh;
}
                                       
/*
                            
void _3D_object::TreatCollision( HDC hdc, screen *Screen, boolean SelfRefr )
{                       
	object *OccupObj;
	int i;               
	boolean refresh;

	if( InCollision )
		return;
	else
		InCollision = true;
		
	OccupObj = Screen->LocalObjects->FirstObject;
                   
	i = 1;
//	refresh = false;

	do
	{	
		while( OccupObj != NULL )
		{
			if( OccupObj->IsVisible && !OccupObj->InCollision )
			{
				if( DetectedDirtyCollision( OccupObj ) ) // , Screen ) )
				{
					       
				    OccupObj->Put( Screen );
				    OccupObj->TreatCollision( hdc, Screen );

					if( SelfRefr && IsCloserThan( OccupObj, Screen ) )
					{
						PutDirty( Screen );
					}                 
					
			       	Show();
			    	OccupObj->DrawSolid( hdc, Screen );
			    }
			}
				    
		    OccupObj = OccupObj->Next;
		}    
	
		OccupObj = Game->Portables.FirstObject;
	}
	while( i-- > 0 );
	
//  Show( hdc, Screen );
    Show();

   	DrawSolid( hdc, Screen );

	InCollision = false;	            			 
}

*/

void _3D_object::TreatCollision( HDC hdc, screen *Screen, boolean SelfRefr )
{                 
	register object_node *Node;
	register _3D_object *OccupObj;
	boolean refresh;

	Node = Game->VisibleObjects.First;
                   
	refresh = true;


	while( Node != NULL )
	{
		OccupObj = Node->Obj;
		
		if( OccupObj->IsVisible && OccupObj->Name != Name )
		{
			if( DetectedDirtyCollision( OccupObj ) ) // , Screen ) )
			{
			    OccupObj->Put( Screen );

//				if( !refresh || (refresh = IsCloserThan( OccupObj, Screen )) )
				if( IsVisible && IsCloserThan( OccupObj, Screen ) )
				{
					PutDirty( Screen );
				}                 
					
		       	Show();

				#ifdef Debug 
					if( hdc != 0 )
					{
		    			OccupObj->DrawSolid( hdc, Screen );
		    		}
		    	#endif
		    }
		}
				    
	    Node = Node->r;
	}    
	
/*	if( Game->CurrentScene->HasControlPanel() )
	{
		Game->ControlPanel->Put( Game->CurrentScene->Screen );
	}
*/		
    Show();

	#ifdef Debug 
	   	DrawSolid( hdc, Screen );
	#endif

}

                    
void _3D_moveable::Move1Step( HWND hwnd, screen *Screen)
{                            
	if( Moving )
	{

			HDC hdc = GetDC(hwnd);
        	
			
			PlanNextPosition();
			
			if( CanGo( Screen ) )
			{
					ResetDirtyRect();                                      
                   	Paint( AuxX, AuxY, Screen );

					TreatCollision(hdc, Screen);

					Screen->TestScroll(hdc, this, AuxX, AuxY);

					if( FinishedMovement() )
					{
							EndMove(hwnd, hdc, Screen);
					}
			}
			else
			{
					EndMove(hwnd, hdc, Screen);
			}

   			ReleaseDC(hwnd,hdc);
   	}
}    

void _3D_moveable::EndMove( HWND hwnd, screen *Screen )
{
			HDC hdc = GetDC(hwnd);

			EndMove( hwnd, hdc, Screen );
			
   			ReleaseDC(hwnd,hdc);
}


void _3D_moveable::EndMove( HWND hwnd, HDC hdc, screen *Screen )
{
			Moving = false;
			
       		(*KillSystemTimer)( hwnd, Timer1 );

			DeltaX = abs(DeltaX);
			DeltaY = abs(DeltaY);
/*
			NewX = X;
			NewY = Y;
			                   
            Paint( NewX, NewY, Screen );
			TreatCollision( hdc, Screen );
*/
			NewX = OldX = X;
			NewY = OldY = Y;     

       		PostMessage( hwnd, WM_ENDMOVE, Name, NULL );
}


void _3D_animated::Anim1Frame( HWND hwnd, screen *Screen)
{
	HDC hdc = GetDC(hwnd);

	if( hdc == NULL )
	{
		MessageBox( "Erro Fatal !", "Estouro no número de HDCs" );
	}
	else
	{
		NextFrame();    
		ResetDirtyRect();                                      
       	Paint( Screen );
//		TreatCollision(hdc, Screen);
		if((Game->CurrentScene->HasPlayer())&&(Game->Player->Is3DPlayer())&&(Name != Game->Player->Name))
		{			
			if( Game->Player->To3DPlayer()->IsCloserThan( this, Screen ) )
			{
				TreatCollision(hdc, Screen);			
				Game->Player->ResetDirtyRect();                                      
				Game->Player->TreatCollision(hdc, Screen);			
				ResetDirtyRect();                                      
			}                 
			else
			{
				Game->Player->TreatCollision(hdc, Screen);			
				ResetDirtyRect();                                      
				TreatCollision(hdc, Screen);			
			}
		}
		else
		{
			TreatCollision(hdc, Screen);			
		}
				
	}

	ReleaseDC(hwnd,hdc);

	if( _1SpriteAnim )
	{
		if( --FrameCounter <= 0 )
		{
			StopAnim(hwnd);
		}
	}
}


void _3D_player::Put( screen *Screen )
{
	_3D_actor::Put( Screen );

/*	if( DetectedFrameCollision( Game->ControlPanel ) )
	{
		Game->ControlPanel->Put( Screen );
	}
*/
}


void _3D_player::Anim1Frame( HWND hwnd, screen *Screen )
{
	_3D_actor::Anim1Frame( hwnd, Screen );

/*	if( DetectedFrameCollision( Game->ControlPanel ) )
	{
		Game->ControlPanel->Put( Screen );
	}
*/
}

void _3D_player::Move1Step( HWND hwnd, screen *Screen )
{
	_3D_actor::Move1Step( hwnd, Screen );

	PostMessage( hwnd, WM_PLAYERMOVE, Name, (((long)Y)<<16) & ((long)X) );
	
/*	if( DetectedFrameCollision( Game->ControlPanel ) )
	{
		Game->ControlPanel->Put( Screen );
	}
*/
}


boolean exits::HasKey( _3D_actor *Actor )
{
	if( KeyObject == NULL )
	{
		return true;
	}
	else
	{
		object *Object;
		                                  
		if( Actor == NULL )
		{
			Actor = Game->Player->To3DPlayer();
		}
					                                  
		for( Object = Actor->Portables.FirstObject; Object != NULL; Object = Object->Next )
		{
		 	if( Object->Name = KeyObject->Name )
		 	{
		 		break;
		 	}
		}	
		 	
		return (boolean) (Object != NULL);
	}
}
        


void exits::InitAnim( HWND hwnd, screen *Screen ) 
{                         
 	ExitAnimCounter = NumberOfFrames()-1;
 	CurrentFrame = 0;
	StartExit = true;
	
	if(	ExitAnimCounter )
	{   
		if( HasKey() || AlternativeExitNum != -1)
		{
			if( Game->CurrentScene->HasPlayer() )
			{	
		    	Game->Player->StopAnim(hwnd);
		    }

		 	_3D_animated::InitAnim(hwnd, Screen);
		}
	}
	else
	{
		StartExit = false;
		if( HasKey() )
		{
			PostMessage( hwnd, WM_EXITSCENE, ExitNum, 0L );
		}
		else
		if( AlternativeExitNum != -1 )
		{
			PostMessage( hwnd, WM_EXITSCENE, AlternativeExitNum, 0L );
		}
	}
}

/*
void exits::Anim1Frame( HWND hwnd, screen *Screen )
{
	if(	ExitAnimCounter )
	{   
			ExitAnimCounter--;
		 	_3D_animated::Anim1Frame(hwnd, Screen);
	}
	else
	{
		StartExit = false;
		StopAnim(hwnd);                                
		PostMessage( hwnd, WM_EXITSCENE, ExitNum, 0L );
	}
};
*/

//void exits::Anim1Frame( HWND hwnd, screen *Screen, object *OccupObject1, object *OccupObject2 )
void exits::Anim1Frame( HWND hwnd, screen *Screen )
{
	if(	ExitAnimCounter )
	{   
			ExitAnimCounter--;

			NextFrame();                                          
			ResetDirtyRect();                                      
	       	Paint( Screen );
				
			HDC hdc = GetDC(hwnd);

			if( hdc == NULL )
			{
				MessageBox( "Erro Fatal !", "Estouro no número de HDCs" );
			}
			else
			{
	//			TreatCollision(hdc, Screen);  does not work because the player is not in any list.
				if( Game->Player->Is3DPlayer() )
				{			
					if( Game->Player->To3DPlayer()->IsCloserThan( this, Screen ) )
					{
						TreatCollision(hdc, Screen);			
						Game->Player->ResetDirtyRect();                                      
						Game->Player->TreatCollision(hdc, Screen);			
						ResetDirtyRect();                                      
					}                 
					else
					{
						Game->Player->TreatCollision(hdc, Screen);			
						ResetDirtyRect();                                      
						TreatCollision(hdc, Screen);			
					}
				}
				else
				{
					TreatCollision(hdc, Screen);			
				}
				
	/*			if( OccupObject1 != NULL )
				{
					if( OccupObject2 != NULL )
					{
						if( OccupObject1->y3D() < OccupObject2->y3D() )
						{
							CollideObject = OccupObject2;
							object::TreatCollision(hdc, Screen); // specifically 2D collision handling
							CollideObject = OccupObject1;
							object::TreatCollision(hdc, Screen); // specifically 2D collision handling
						}						
						else
						{
							CollideObject = OccupObject1;
							object::TreatCollision(hdc, Screen); // specifically 2D collision handling
							CollideObject = OccupObject2;
							object::TreatCollision(hdc, Screen); // specifically 2D collision handling
						}						
					}
					else
					{
							CollideObject = OccupObject1;
							object::TreatCollision(hdc, Screen); // specifically 2D collision handling
					}
				}
	
	
	//	    	Show( hdc, Screen );
	
				Player->Show();
		    	Show();
	*/      }
	
			ReleaseDC( hwnd, hdc );
	}
	else
	{
		StartExit = false;
		StopAnim(hwnd);
		
		if( HasKey() )
		{
			PostMessage( hwnd, WM_EXITSCENE, ExitNum, 0L );
		}
		else
		if( AlternativeExitNum != -1 )
		{
			PostMessage( hwnd, WM_EXITSCENE, AlternativeExitNum, 0L );
		}
				
	}
};



portable::portable(int _Name, char *FirstSceneName, int _X, int _Y, 
		char *BMPName, 
		int BMPWidth, int BMPHeight,
		int _BoundX, int _BoundY,
		int _BoundWidth, int _BoundHeight,
		int _Timer, int _Period, 
		boolean _IsVisible, int _Layer ) :
_3D_moveable( _X, _Y,
		BMPName, 1, 
		BMPWidth, BMPHeight,             
		_BoundX, _BoundY, 
		_BoundWidth, _BoundHeight, 
		_Timer, _Period,
		PORTAB_DELTA_X, PORTAB_DELTA_Y,
		_IsVisible,_Layer  ) 
{          
	Name =_Name;
	
	Owner = NULL;
	strncpy( _SceneName, FirstSceneName, MAX_NAME_LEN-1 );
	_SceneName[MAX_NAME_LEN-1] ='\0';

	z = 0;
			
	Game->Portables.Insert( this );
}; 	        
 	        





portable::portable( char *FirstSceneName, int _X, int _Y, 
		char *BMPName, int _NumberOfFrames, 
		int BMPWidth, int BMPHeight,
		int _Timer, int _Period,
		int _DeltaX, int _DeltaY,
		boolean _IsVisible, int _Layer )
		:
_3D_moveable(_X, _Y, 1, 
		&BMPName,  &_NumberOfFrames, 
		&BMPWidth, &BMPHeight,
		_Timer, _Period,
		_DeltaX, _DeltaY,
		_IsVisible, _Layer  ) 
/*
_3D_object( _X, _Y, 
		BMPName, _NumberOfFrames, 
		BMPWidth, BMPHeight,
		_IsVisible, _Layer )			
*/
{ 
	Owner = NULL;
	strncpy( _SceneName, FirstSceneName, MAX_NAME_LEN-1 );
	_SceneName[MAX_NAME_LEN-1] ='\0';

	z = 0;
			
	Game->Portables.Insert( this );
}; 	        
 	        

portable::portable( char *FirstSceneName, int _X, int _Y, 
		int _Timer, int _Period,
		int _DeltaX, int _DeltaY,
		boolean _IsVisible, int _Layer )
		:
_3D_moveable(_X, _Y, 1, 
		_Timer, _Period,
		_DeltaX, _DeltaY,
		_IsVisible, _Layer  ) 
/*
_3D_object( _X, _Y, 
		BMPName, _NumberOfFrames, 
		BMPWidth, BMPHeight,
		_IsVisible, _Layer )			
*/
{ 
	Owner = NULL;
	strncpy( _SceneName, FirstSceneName, MAX_NAME_LEN-1 );
	_SceneName[MAX_NAME_LEN-1] ='\0';

	z = 0;

	HasBeenTouched = false;
	
	Game->Portables.Insert( this );
}; 	        
 	        

object * portable::ChangeOwner( _3D_actor 	*NewOwner )
{
	if( Owner != NULL )
	{                             
		if( Owner != NewOwner )
		{
		    Owner->Portables.Exclude(this); 
			Owner = NewOwner;
			Owner->Portables.Insert( this );		
		};
	}
	else
	{
	    Game->Portables.Exclude(this); 
		Owner = NewOwner;
		_SceneName[0] = '\0';
		Owner->Portables.Insert( this );		
	}

	Game->VisibleObjects.Extract( this );

	HasBeenTouched = true;
	
	return this;
}

object * portable::ChangeOwner( scene 		*NewScene )
{
	if( Owner != NULL )
	{
	    Owner->Portables.Exclude(this); 

		Owner = NULL;
		strncpy( _SceneName, NewScene->Name, MAX_NAME_LEN-1 );
		_SceneName[MAX_NAME_LEN-1] ='\0';
	
		Game->Portables.Insert( this );			
		Game->VisibleObjects.Insert( this, NewScene->Screen );
	}
	else
	{
		strncpy( _SceneName, NewScene->Name, MAX_NAME_LEN-1 );
		_SceneName[MAX_NAME_LEN-1] ='\0';

		Game->VisibleObjects.Extract( this );
		Game->VisibleObjects.Insert( this, NewScene->Screen );
	}

	HasBeenTouched = true;

	return this;
}

	
	
void portable::PutIcon( screen *Screen, int _X, int _Y )
{
  	TranspDIBits((BITMAPINFO far * )&Screen->BufferHeader, Screen->pBuffer, _X, _Y,
  						DibPtr(pIcon),DibInfo(pIcon),
  						0,0,
  						IconWidth, IconHeight*Orientation,
  						DIB_RGB_COLORS,	TransparentColor );              
};
 	        
/*
void portable::HideIcon( HDC hdc, screen *Screen, int _X, int _Y )
{
	 // WinGStretchBlt(...);
};
*/ 	        

