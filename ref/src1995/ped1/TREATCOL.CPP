
void moveable::TreatCollision( HDC hdc, occup_screen *Screen)
{                       
	if( CollideObject != NULL )
	{       
		    CollideObject->Put( Screen );
		    CollideObject->Show( hdc, Screen );
	}
	            			 
/*	
	object *OccupObj;
	
	if( CollideObject != NULL && 
		CollideObject->IsMoving() )
	{       
        int Left, Right, Up, Down;
		
		OccupObj = CollideObject;
		
		if( OccupObj->X < AuxX )
		{
		 	Left = AuxX;
		}                      
		else
		{
			Left = OccupObj->X;
		}
		
		if( OccupObj->X+OccupObj->FrameWidth() > AuxX+FrameWidth() )
		{
		 	Right = AuxX+FrameWidth();
		}                      
		else
		{
			Right = OccupObj->X+OccupObj->FrameWidth();
		}
		
		if( OccupObj->Y < AuxY )
		{
		 	Up = AuxY;
		}                      
		else
		{
			Up = OccupObj->Y;
		}
		
		if( OccupObj->Y+OccupObj->FrameHeight() > AuxY+FrameHeight() )
		{
		 	Down = AuxY+FrameHeight();
		}                      
		else
		{
			Down = OccupObj->Y+OccupObj->FrameHeight();
		}
		
		if( Down > Up && Left < Right ) // collision in fact
		{

			BitBlt(hBackBuffer,Left-AuxX,Up-AuxY,Right-Left,Down-Up, 
    	 			OccupObj->hBackBuffer, Left-OccupObj->X, Up-OccupObj->Y, SRCCOPY);	

			Put( Screen );        	

		}

	}

*/
}
                    

