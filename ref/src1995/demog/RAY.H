
class ray
{
public:

	int row,column,block,t,done=0;
	
	long x,y,view_angle,x_cell,y_cell,x_sub_cell,y_sub_cell;
	
	float dx,dy;
	  
	void Init(void);

	int Color;  

	virtual boolean MessageHandling( HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam );
};

