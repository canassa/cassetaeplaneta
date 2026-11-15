
#undef DECLARE                     
#ifdef _SCENE
	#define	DECLARE
#else
	#define DECLARE extern
#endif        



#define	MAX_EXITS 10

typedef enum { _SCREEN, _OCCUP_SCREEN, _3D_SCREEN, _NEW_SCREEN } screen_type;

/*
screen *NewScreen( 	char *_Name, screen_type _ScreenType,
					int	_ScreenX = 0, int _ScreenY = 0, 
					int _ScreenWidth = 640, int _ScreenHeight = 480 )
{				
		screen *Screen;
		
		switch(_ScreenType)
		{                                                
			case _SCREEN:
				Screen = new screen( _Name, 
									_ScreenX, _ScreenY, 
									_ScreenWidth,_ScreenHeight );
				break;

			case _OCCUP_SCREEN:
				Screen = new occup_screen( _Name, 
									_ScreenX, _ScreenY, 
									_ScreenWidth,_ScreenHeight );
				break;

			case _3D_SCREEN:
				Screen = new _3D_screen( _Name, 
									_ScreenX, _ScreenY, 
									_ScreenWidth,_ScreenHeight );
				break;
			default:  
				Screen = NULL;
				break;
		};

		return Screen;		
}   	

*/


class scene
{   
public:
	screen *Screen;
	
	exits  *VetExits[MAX_EXITS];
	
	int    NumExits;
	
	char   Name[MAX_NAME_LEN];

	object_list	LocalObjects;        
	
	boolean _HasPlayer,
			_HasStatusBar,
			_HasControlPanel;
			
	boolean Is1Animation, 
			IsClickExit;
			
	exits		 *AutoExit;
	
	boolean MayDropObjects;   
	
	int SceneNumber;
	
	virtual boolean MessageHandling( HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam ) = 0;

	scene( void ) 
	{
		Name[0] = '\0';
		NumExits = 0;
		Screen = NULL;
		_HasPlayer = true;
		_HasStatusBar = true;
		_HasControlPanel = true;

		Is1Animation = false; 
		IsClickExit = false;  

		AutoExit = NULL;	

		MayDropObjects = true;
		
	};
	
	scene( char *_Name, 
			boolean _Has_Player = true, boolean _Has_ControlPanel = true,
			boolean _Has_StatusBar = true, 
			int	_ScreenX = 0, int _ScreenY = 0, 
			int _ScreenWidth = 640, int _ScreenHeight = 480 ) 
	{

		strncpy( Name, _Name, MAX_NAME_LEN-1 );
		Name[MAX_NAME_LEN-1] ='\0';
		
		NumExits = 0;
		_HasPlayer = _Has_Player;
		_HasStatusBar = _Has_StatusBar;
		_HasControlPanel = _Has_ControlPanel;

		Is1Animation = false; 
		IsClickExit = false;  

		AutoExit = NULL;	

		MayDropObjects = true;

	};                       

	scene( char *_Name, 
			boolean _Has_Player = true, boolean _Has_ControlPanel = true,
			boolean _Has_StatusBar = true, boolean _Is1Animation = false,
			boolean _IsClickExit = false ) 
	{

		strncpy( Name, _Name, MAX_NAME_LEN-1 );
		Name[MAX_NAME_LEN-1] ='\0';
		
		NumExits = 0;
		_HasPlayer = _Has_Player;
		_HasStatusBar = _Has_StatusBar;
		_HasControlPanel = _Has_ControlPanel;

		Is1Animation = _Is1Animation; 
		IsClickExit = _IsClickExit; 

		AutoExit = NULL;	

		MayDropObjects = true;

	};                       

	~scene( void );
		
	virtual boolean HasPlayer(void) { return _HasPlayer; };
	virtual boolean HasControlPanel(void) { return _HasControlPanel; };
	virtual boolean HasStatusBar(void) { return _HasStatusBar; };
	
	virtual void DefLocal( object *Object );
	    
	virtual screen *CreateScreen( void )
	{       
		MessageBox( Name, "Faltou redefinir o método CreateScreen"  );

		return Screen;
	};


	virtual scene *CreateNewScene( int ExitNum )
	{       
		MessageBox( Name, "Faltou redefinir o método CreateNewScene" );

		return this;
	};


    virtual scene *Init( HWND hwnd );    

    virtual scene *Show( HDC hdc )
    {
     	Screen->Show( hdc );
     	
     	return this;
    };
    
    virtual scene *Dark( void )
    {
     	Screen->Dark();
     	
     	return this;
    };
    
    virtual scene *Paint( void )
    {
     	Screen->Paint();
     	
     	return this;
    };
    

	virtual int DefExit( exits *Exit, int PlayerX, int PlayerY, event *_OpenningEvent = (event *) &Always );

    virtual exits *Exit( int ExitNumber )
    {
      	return( ExitNumber < NumExits ? VetExits[ExitNumber] : NULL );
    };

	
	scene *EnableDropObjects( void )
	{
		MayDropObjects = true;

		return this;
	};
	
	scene *DisableDropObjects( void )
	{
		MayDropObjects = false;

		return this;
	};
	
};


class gen_scene : public scene
{   
public:

	gen_scene( void ) 
	{
	};
	
	gen_scene( HFILE hArch,char *_Name, 
			boolean _Has_Player = true, boolean _Has_ControlPanel = true,
			boolean _Has_StatusBar = true, boolean _Is1Animation = false, 
			boolean _IsClickExit = false );

	~gen_scene( void ) { };



	virtual boolean MessageHandling( HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam );

	virtual scene *CreateNewScene( int ExitNum );

    virtual scene *Init( HWND hwnd );    

	virtual int DefAltExit( exits *Exit, char *_SceneInName, int PlayerX, int PlayerY );	 

	virtual int DefExit( exits *Exit, char *_SceneInName, int PlayerX, int PlayerY, event *_OpenningEvent = (event *) &Always );

	virtual int DefExit( exits *Exit );
};


