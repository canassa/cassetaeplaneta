

#define		CONTROL_PANEL_TIMER			2
#define		CONTROL_PANEL_PERIOD		55


#define ZEMANE_DELTAX   25 // 12 // 37 // 60 // 20     
#define ZEMANE_DELTAY    10     
#define ZEMANE_TIMER      3
#define ZEMANE_PERIOD    100// 170  //60
                          
#define PORTAZE_TIMER	4
#define PORTAZE_PERIOD	300        
        
#define PORTAPAIS_TIMER	4
#define PORTAPAIS_PERIOD	300        
        

#define PORTAB_DELTAX   10 // 12 // 37 // 60 // 20     
#define PORTAB_DELTAY   10     
#define PORTAB_TIMER    5
#define PORTAB_PERIOD   55  //60
                          
                          

extern char 			*ZeManeNames[];
extern int             ZeManeFrames[];
extern int             ZeManeWidth[];
extern int             ZeManeHeight[];


class zemane;
class casseta;


extern zemane	*ZeMane;
extern casseta	*Casseta;
	


class casseta : public application
{                 
public:

	portable	*Bola;
	portable	*Carteira;
	portable	*Camisinha;


	casseta( void );
	
	object *CreatePlayer( void );

    scene *CreateInitScene( char *SceneName );

	control_panel *CreateControlPanel( void );
	status_bar *CreateStatusBar( void );
	
	application *Init( HWND hwnd );

};


#ifdef GAME_CLASS

#undef GAME_CLASS

#endif

#define GAME_CLASS	casseta

