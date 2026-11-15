#define _3DSCREEN

#include "games.hpp"       
#include "event.hpp"

#include "screen.hpp"
#include "3Dscreen.hpp"
#include "object.hpp"
#include "3Dobject.hpp"
#include "bglayer.hpp"


#undef _3DSCREEN

          
          
        
void _3D_screen::Set3DPosition( _3D_object *o, int _z)
{
	o->Set3DPosition( this, _z );
};



screen * _3D_screen::SetVanishingPoint(int _XV, int _YV)
{
  	XV = _XV;
  	YV = ScreenHeight-_YV;
	  	
  	return this;
};

screen * _3D_screen::SetViewPoint(int _X, int _Y, int _x, int _y, int _z)
{               
	_Y = ScreenHeight-_Y;

	xv = _x;
	yv = -_y;
	zv = _z;
				
  	v = ((long)_y) * ((long)( _Y - YV))/((long)(_z - _Y));
	  	
  	return this;
};
                                    
screen * _3D_screen::SetyAxisShift( int _X, int _Y )
{               
	_Y = ScreenHeight-_Y;
		
	if( _X == 0 )
	{
	    DX = ((long)XV)*((long)_Y)/((long)(YV-_Y));
  	}                      
  	else
  	{
  		DX = -_X;
  	}
	  	
  	return this;
};
                                    

	                                    
int parallax_screen::DefLayer( bg_layer *Layer, int LayerNum )
{                              
	VetLayers[LayerNum-1] = Layer;
		
	if( LayerNum > MAX_LAYERS )
	{
	    MessageBox( "Estouro no número de Layers", "", "Erro Fatal!" );
	}
	else
	if( NumLayers < LayerNum )
	{
		NumLayers = LayerNum;
	}
		
	return LayerNum;
};
	
int parallax_screen::ScrollLayers( int Scrollx, int Scrolly )
{ 
	register int i = 0;
	register int Mask = 0;
		
	if( Scrollx > 0 )
	{
		Mask = MV_RIGHT;
	}
	else
	if( Scrollx < 0 )
	{
		Mask = MV_LEFT;
	}       
		
	if( Scrolly > 0 )
	{
		Mask |= MV_UP;
	}
	else
	if( Scrolly < 0 )
	{
		Mask |= MV_DOWN;
	}       
		
	Restore();
		
	for( ; i < NumLayers; i++ )
	{
		VetLayers[i]->Scroll( (MVDIR) Mask );
		VetLayers[i]->Put( this );
	}

	return NumLayers;

};

int parallax_screen::PaintLayers( void )
{   
	register int i = 0;
		
	Restore();
		
	for( ; i < NumLayers; i++ )
	{
		VetLayers[i]->Put( this );
	}

	return NumLayers;
}
	


          

