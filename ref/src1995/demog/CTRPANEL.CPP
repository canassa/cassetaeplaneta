
#include "games.hpp"
#include "event.hpp"

#include "screen.hpp"
#include "3dscreen.hpp"
#include "object.hpp"
#include "3dobject.hpp"
                          
#include "vtree.h"
                          
#define _CONTROL_PANEL

#include "ctrpanel.hpp"

#undef _CONTROL_PANEL

#include "scene.hpp"
#include "applicat.hpp"



object *status_bar::Init( screen *Screen )
{
  	object::Init( Screen );

	Buffer[0] = '\0';                                                
	Pos = 10;
		
	return this;                                                
};

void status_bar::ResetText( void )
{                        
	Buffer[0] = '\0';
};
			                       
void status_bar::SetText( char *String, int Position )
{
	strcpy( Buffer, String );
	Pos = Position;
};

void status_bar::Update( screen *Screen )
{
	if( Buffer[0] != '\0' )
	{

		SetTextColor( Screen->hBuffer, TextColor );
		SetBkMode( Screen->hBuffer, TRANSPARENT ); 		

		if( Pos != -1 )
		{                                    
			TextOut( Screen->hBuffer, Pos, 460-FrameHeight()+20, Buffer, strlen(Buffer) );
		}
		else
		{
			TextOut( Screen->hBuffer, (640-LOWORD(GetTextExtent(Screen->hBuffer, Buffer, strlen(Buffer))))/2, 460-FrameHeight()+20, Buffer, strlen(Buffer) );
		}

	}
};



control_panel * control_panel::Constr(int _X, int _Y,  
			char *BMPName, int BMPFrames, 
			int BMPWidth, int BMPHeight,
			int _Timer, int _Period, boolean _EndsAtFirstFrame,
		boolean _IsVisible, int _Layer) 
{
		Timer2 = _Timer;
		Period2 = _Period;

		InitAnimated( 1,
			&BMPName, &BMPFrames, 
			&BMPWidth, &BMPHeight);
	
		InitMoveable( 	_X, _Y, 
						_IsVisible,_Layer  );

		w = h = d = 0;                   
    	UnderObj = NULL;

	
		Animating = false;
		_1SpriteAnim = false;
	
		FrameCounter = 0;                                             
			
		EndsAtFirstFrame = _EndsAtFirstFrame;
		
	 	AnimCounter = 0;
	 	On = false;    
	 	
	 	return this;
};


void control_panel::Put( screen *Screen )
{
	if( On && !Animating )
	{
		PutObjects(Screen);
		animated::Put(Screen);
	}
	else
	{
		animated::Put(Screen);
	}

	Update(Screen);

};

object *control_panel::Init( screen *Screen )
{
    
    _3D_animated::Init(Screen);

	SelectObject (Screen->hBuffer,GetStockObject(SYSTEM_FONT));

	Buffer[0] = '\0';                                                
	Pos = 10;
    TextColor = RGB(255,255,0);

	
		
 	x = y = z = 0;
     	
 	w = FrameWidth();
 	h = FrameHeight();
 	d = 1;   
     	
 	return this;
}        
    	                       
void control_panel::ResetText( void )
{                        
	Buffer[0] = '\0';
};
			                       
void control_panel::SetText( char *String, int Position )
{
	strcpy( Buffer, String );
	Pos = Position;
};

void control_panel::Update( screen *Screen )
{
	if( Buffer[0] != '\0' )
	{

		SetTextColor( Screen->hBuffer, TextColor );
		SetBkMode( Screen->hBuffer, TRANSPARENT ); 		

		if( Pos != -1 )
		{                                    
			TextOut( Screen->hBuffer, Pos, 460-PanelHeight()+20, Buffer, strlen(Buffer) );
		}
		else
		{
			TextOut( Screen->hBuffer, (640-LOWORD(GetTextExtent(Screen->hBuffer, Buffer, strlen(Buffer))))/2, 460-PanelHeight()+20, Buffer, strlen(Buffer) );
		}

	}
};


    
void control_panel::InitAnim( HWND hwnd, screen *Screen, MVDIR _Direction ) 
{                                                
	Direction = _Direction;
		
 	AnimCounter = NumberOfFrames()-(_Direction==MV_UP);
 	CurrentFrame = 0;
	        
	if( _Direction == MV_UP )
	{ 	
// 		object::OccupScreen( Screen );
 	}

 	animated::InitAnim(hwnd, Screen);

}


void control_panel::Anim1Frame( HWND hwnd, screen *Screen )
{             
	if(	AnimCounter )
	{                                                              
		AnimCounter--;
		if( Direction == MV_UP )
		{
			NextFrame();
		}
		else
		{              
			PreviousFrame();
		}
			
        if( AnimCounter == 0 )
        {
         	StopAnim( hwnd );

			if( Direction == MV_DOWN )
			{ 	
//        	 	object::DesoccupScreen(Screen);
        	 	On = false;

//		 	 	HideObjects(hwnd, Screen);
        	}              
        	else
        	{
//		   		PutObjects(Screen);
        		On = true;
        	}
				
//			On = (boolean) (Direction == MV_UP);
        }                           
            
//		Paint( Screen );
		Restore(Screen);
		HDC hdc = GetDC(hwnd);
//		Show( hdc, Screen );

/*		if( DetectedFrameCollision( Game->Player ) )
		{                 
			Game->Player->Put( Screen );
//			Game->Player->TreatCollision( hdc, Screen );
		}
*/		
		Put( Screen );
		TreatCollision( hdc, Screen );
		ReleaseDC(hwnd,hdc);

	}                  
	else
	{
		Animating = false;
		_1SpriteAnim = false;
	}
};
	

object_list * control_panel::PutObjects(screen *Screen)
{
	object *aux;
	int Position = 0;
		

	if( !Game->Player->To3DPlayer()->Portables.IsEmpty() )
	{
		aux = Game->Player->To3DPlayer()->Portables.FirstObject;
	
		while( aux != NULL )
		{
		 	PutIcon( Screen, aux->ToPortable(), Position++ );
		
		 	aux = aux->Next;
		}
	
	}
	
	return &(Game->Player->To3DPlayer()->Portables);
}
        
        
boolean control_panel::IsOut( int _X, int _Y )
{

	if( _X < X || _X > X+FrameWidth() )
		return true;
		
	if( _Y < Y || _Y > Y+FrameHeight() )
		return true;
		                            
	return false;
}
	
        
        
void control_panel::PutIcon( screen *Screen, portable *Portable, int Position )
{
	int _Y = Y+70;
	
	int _X = 92;

	if( Portable != NULL )
	{	
		Portable->PutIcon( Screen, _X+Position*56, _Y );
	}
	
};


portable * control_panel::SelectedObject( object_list *Portables, int _X, int _Y )
{
	object *aux = NULL;
	int Position;
	           
	if( !Portables->IsEmpty() )
	{
		Position = (_X - 92)/56;
	
		for( aux = Portables->FirstObject; aux != NULL; aux = aux->Next )
		{    
		    if( Position == 0 )
		    {
		    	break;
		    }
		    else
		    {
				Position--;
		 	}
		}
	         
	}

	if( aux == NULL )
		return NULL;
	else	
		return aux->ToPortable();
}



        
void casseta_panel::PutIcon( screen *Screen, portable *Portable, int Position )
{
	int _Y = Y+70;
	
	int _X = 92;

	if( Portable != NULL )
	{	
		Portable->PutIcon( Screen, _X+Position*56, _Y );
	}
	
};


portable * casseta_panel::SelectedObject( object_list *Portables, int _X, int _Y )
{
	object *aux = NULL;
	int Position;
	           
	if( !Portables->IsEmpty() )
	{
		Position = (_X - 92)/56;
	
		for( aux = Portables->FirstObject; aux != NULL; aux = aux->Next )
		{    
		    if( Position == 0 )
		    {
		    	break;
		    }
		    else
		    {
				Position--;
		 	}
		}
	         
	}

	if( aux == NULL )
		return NULL;
	else	
		return aux->ToPortable();
}



