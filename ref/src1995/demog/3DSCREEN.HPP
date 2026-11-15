
#ifdef _3DSCREEN
	#define	DECLARE
#else
	#define DECLARE extern
#endif        

#define MAX_LAYERS	5


class _3D_screen : public occup_screen
{
public:
	int XV, YV;		// Screen Coordinates of the Vanishing Points;
	
	int v;			// Distance between the viewpoint and the screen

	int DX;			// Correction of the x coordinate when the 3D origin is shifted to left or right.
	
	int xv, yv, zv;	// 3D coordinates of the view point

	_3D_screen( char *BackName, 
			int	_ScreenX = 0, int _ScreenY = 0, 
			int _ScreenWidth = 640, int _ScreenHeight = 480 ) :
	occup_screen( BackName, 
			_ScreenX, _ScreenY, 
			_ScreenWidth,_ScreenHeight )
	{
			                    
	};
	
        
	virtual int XV3D(void) { return XV; };
	virtual int YV3D(void) { return YV; };

	virtual int v3D (void) { return v;  };
	virtual int DX3D(void) { return DX; };

	virtual int xv3D(void) { return xv; };
	virtual int yv3D(void) { return yv; };
	virtual int zv3D(void) { return zv; };
	
        
	virtual void Set3DPosition( _3D_object *o, int _z = 0);

	virtual screen *SetVanishingPoint(int _XV, int _YV);

	virtual screen *SetViewPoint(int _X, int _Y, int _x, int _y, int _z);
                                    
	virtual screen *SetyAxisShift( int _X, int _Y );

	virtual _3D_screen * To3DScreen(void) { return this; };                                             
	virtual boolean Is3DScreen(void) { return true; };                                             


};



class parallax_screen : public _3D_screen
{
public:

	bg_layer	*VetLayers[MAX_LAYERS];
	                          
	int NumLayers;	                          

	parallax_screen( char *BackName, 
			int	_ScreenX = 0, int _ScreenY = 0, 
			int _ScreenWidth = 640, int _ScreenHeight = 480 ) :
	_3D_screen( BackName, 
			_ScreenX, _ScreenY, 
			_ScreenWidth,_ScreenHeight )
	{
		NumLayers = 0;		                    
	};
	
	int DefLayer( bg_layer *Layer, int LayerNum );
	
	virtual int ScrollLayers( int Scrollx, int Scrolly );

	virtual int PaintLayers( void );
	
};




#undef	DECLARE	    