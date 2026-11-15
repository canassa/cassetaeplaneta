                     
#undef DECLARE                     

#ifdef _APPLICAT
	#define	DECLARE
#else
	#define DECLARE extern
#endif        

#define		MIN_EXIT_DIST		100


class application;

DECLARE application *Game;


class application
{
public:
	scene *CurrentScene;
	scene *LastScene;
	status_bar *StatusBar;

	control_panel *ControlPanel;  

	object_list *ObjectList;
	object		*Player;	

	object_list	Portables;        
	object * FirstStaticObject;
	
	object_bag  DirtyObjects;
	
	object_ordlist VisibleObjects;
		
	screen_type DefaultScreenType;
	
	int DefaultScreenWidth;
	int DefaultScreenHeight;

	virtual boolean MessageHandling( HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam );

	virtual object	*CreatePlayer( void )
	{       
		MessageBox( "CUIDADO !", "Faltou redefinir o método CreatePlayer" );

		return Player;
	};

	virtual scene	*CreateInitScene( char *SceneName )
	{       
		MessageBox( "CUIDADO !", "Faltou redefinir o método CreateInitScene" );

		return CurrentScene;
	};

	virtual control_panel *CreateControlPanel( void )
	{       
		MessageBox( "CUIDADO !", "Faltou redefinir o método CreateControlPanel" );

		return ControlPanel;
	};


	virtual status_bar *CreateStatusBar( void )
	{       
		MessageBox( "CUIDADO !", "Faltou redefinir o método CreateStatusBar" );

		return StatusBar;
	};

	application( void )
	{
		Game = this;                                          

//		Portables.FirstObject = NULL;
		
		CurrentScene = NULL;
		LastScene = NULL;        
		DefaultScreenType = _3D_SCREEN;
		StatusBar = NULL;
		ControlPanel = NULL;
		FirstStaticObject = NULL;


	};
	
	~application( void )
	{
		
		delete CurrentScene;
		if( LastScene != NULL )
		{
			delete LastScene;		
		}        
		
		delete Player;
		delete ControlPanel;
		delete StatusBar;

    	Portables.FreeAll();
	
	};
	
	virtual application *Init( HWND hwnd ) = 0;

	virtual application *Init( HWND hwnd, char *SceneName )
	{
		CurrentScene = CreateInitScene( SceneName );
        
        HDC hdc = GetDC(hwnd);

        PatBlt(hdc, 0,0, DefaultScreenWidth, DefaultScreenHeight, BLACKNESS); 
        
		CurrentScene->Init(hwnd);        


		Portables.Init(CurrentScene);


		StatusBar = CreateStatusBar();
		StatusBar->Init( CurrentScene->Screen );		

		ControlPanel = CreateControlPanel();
		ControlPanel->Init( CurrentScene->Screen );	  

		Player = CreatePlayer();
		Player->Init( CurrentScene->Screen );
		
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
			Player->InitAnimP( hwnd, CurrentScene->Screen );
		}


		PostMessage( hwnd, WM_INITSCENE, 0, NULL );

		return this;		
	}

	application *SetScreenDimensions( int _ScreenWidth = 640, int _ScreenHeight = 480 )
	{
		DefaultScreenWidth  = _ScreenWidth;
		DefaultScreenHeight = _ScreenHeight;	 	
		return this;
	};
                    
	application *SetPlayer( object *_Player )
	{
		Player = _Player;	
		return this;
	};
                    
	application *SetDefaultScreenType( screen_type _ScreenType )
	{
		DefaultScreenType = _ScreenType;	
		return this;
	};


	void DefStatic( object *Object, char *SceneName )
	{                                     
		strcpy(Object->_SceneName, SceneName);
		
		Portables.Insert( Object );
		
		FirstStaticObject = Object;

	};

                    
    
	application *SetCurrentScene( HWND hwnd, int ExitNum );
	
};




class gen_applic : public application
{
public:

	virtual object	*CreatePlayer( void );

	virtual scene	*CreateInitScene( void );

	virtual control_panel *CreateControlPanel( void );


	virtual status_bar *CreateStatusBar( void );

	gen_applic( void );
	
	~gen_applic( void )
	{
	};
	
	virtual application *Init( HWND hwnd );
};


