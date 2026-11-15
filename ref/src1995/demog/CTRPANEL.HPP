
#ifdef _CONTROL_PANEL
	#define	DECLARE
#else
	#define DECLARE extern
#endif        


    
struct ctrl_panel
{
	boolean On;
	MVDIR Direction;
	int AnimCounter;


	long TextColor;
	
	char Buffer[200];
	int  Pos;

	_3D_animated o;
};
    
    
class control_panel : public _3D_animated
{
public:

	boolean On;
	MVDIR Direction;
	int AnimCounter;


	long TextColor;
	
	char Buffer[200];
	int  Pos;
	

	control_panel(void) {};

	control_panel(int _X, int _Y, 
			char *BMPName, int BMPFrames, 
			int BMPWidth, int BMPHeight,
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			int _Timer, int _Period, boolean _EndsAtFirstFrame = false,
			boolean _IsVisible = true, int _Layer = 0  ) :
	_3D_animated( _X, _Y, 1,
			&BMPName, &BMPFrames, 
			&BMPWidth, &BMPHeight,
			_BoundX, _BoundY,
			_BoundWidth, _BoundHeight,
			_Timer, _Period, _EndsAtFirstFrame,
			_IsVisible,_Layer  )
	{
	 	AnimCounter = 0;
	 	On = false;
	};

	control_panel(int _X, int _Y,  
				char *BMPName, int BMPFrames, 
				int BMPWidth, int BMPHeight,
				int _Timer, int _Period, boolean _EndsAtFirstFrame = false,
			boolean _IsVisible = true, int _Layer = 0)
			:
		_3D_animated( _X, _Y, 1,
				&BMPName, &BMPFrames, 
				&BMPWidth, &BMPHeight,
				_Timer, _Period, _EndsAtFirstFrame,
				_IsVisible,_Layer  )

	{
/*			Timer2 = _Timer;
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
*/		
		 	AnimCounter = 0;
		 	On = false;
		};
	
	control_panel *Constr(int _X, int _Y,  
				char *BMPName, int BMPFrames, 
				int BMPWidth, int BMPHeight,
				int _Timer, int _Period, boolean _EndsAtFirstFrame = false,
			boolean _IsVisible = true, int _Layer = 0);

	
	virtual boolean IsOn(void) { return On; };
    virtual boolean IsControlPanel(void) { return true; };
    virtual control_panel *ToControlPanel(void) { return this; };

    virtual object *Init( screen *Screen );
    	                       
	void ResetText( void );
			                       
	void SetText( char *String, int Position = -1 );

	void Update( screen *Screen );

	void SetMsgColor( long _TextColor )
	{                                
		TextColor = _TextColor;
	};                          
/*	
	virtual int PanelHeight( void )
	{
		return FrameHeight();
	};
*/	
	virtual int PanelHeight( void )
	{
		return 40 + CurrentFrame*20;
	}
    
    
    virtual void OccupScreen( screen *Screen )
    {
    };
		
    virtual void DesoccupScreen( screen *Screen )
    {
    };
		
	virtual void InitAnim( HWND hwnd, screen *Screen, MVDIR _Direction );
	virtual void Anim1Frame( HWND hwnd, screen *Screen );

	virtual object_list *PutObjects(screen *Screen);

	virtual void Put( screen *Screen );
	
	virtual boolean IsOut( int _X, int _Y );
	virtual boolean IsIn( int _X, int _Y )
	{
		return (boolean) !IsOut(_X,_Y);
	};
	
	virtual portable *SelectedObject( object_list *Portables, int _X, int _Y ); // {return NULL;}; //= 0;
	virtual void PutIcon( screen *Screen, portable *Portable, int Position ); // {}; //= 0;
};


class casseta_panel : public control_panel
{
public:

	casseta_panel(void) {};

	casseta_panel(int _X, int _Y,  
			char *BMPName, int BMPFrames, 
			int BMPWidth, int BMPHeight,
			int _BoundX, int _BoundY,
			int _BoundWidth, int _BoundHeight,
			int _Timer, int _Period,  boolean _EndsAtFirstFrame = false,
			boolean _IsVisible = true, int _Layer = 0  ) :
	control_panel( _X, _Y, 
			BMPName, BMPFrames, 
			BMPWidth,BMPHeight,
			_BoundX, _BoundY,
			_BoundWidth, _BoundHeight,
			_Timer, _Period, _EndsAtFirstFrame,
			_IsVisible,_Layer  )
	{
	};
	
	casseta_panel(int _X, int _Y,  
			char *BMPName, int BMPFrames, 
			int BMPWidth, int BMPHeight,
			int _Timer, int _Period, boolean _EndsAtFirstFrame = false,
			boolean _IsVisible = true, int _Layer = 0  ) :
	control_panel( _X, _Y, 
			BMPName, BMPFrames, 
			BMPWidth,BMPHeight,
			_Timer, _Period, _EndsAtFirstFrame,
			_IsVisible,_Layer  )
	{
	};
	
	virtual portable *SelectedObject( object_list *Portables, int _X, int _Y );
	virtual void PutIcon( screen *Screen, portable *Portable, int Position );

	virtual int PanelHeight( void )
	{
		return 40 + CurrentFrame*20;
	};
    


};



class status_bar : public object
{
public:
                                                           
	long TextColor;
	
	char Buffer[200];
	int  Pos;
	
	status_bar(void) {};

	status_bar(int _X, int _Y,  long _TextColor,
			char *BMPName, int BMPFrames, 
			int BMPWidth, int BMPHeight,
			boolean _IsVisible = true, int _Layer = 0  ) :
	object( _X, _Y, 
			BMPName, BMPFrames, 
			BMPWidth, BMPHeight,
			_IsVisible,_Layer  )
	{                                
		TextColor = _TextColor;
	};
	
    virtual boolean IsStatusBar(void) { return true; };
    virtual status_bar *ToStatusBar(void) { return this; };

    virtual object *Init( screen *Screen );
    	                       
	void ResetText( void );
			                       
	void SetText( char *String, int Position = -1 );

	void Update( screen *Screen );

	void SetMsgColor( long _TextColor )
	{                                
		TextColor = _TextColor;
	};                          
	
    virtual void OccupScreen( screen *Screen )
    {
    };
		
    virtual void DesoccupScreen( screen *Screen )
    {
    };
		


};

#undef DECLARE

