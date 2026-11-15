

#define 	WM_SYSTIMER             0x0118

#ifdef __cplusplus
extern "C" {
#endif 

extern WORD (FAR PASCAL *SetSystemTimer)( 	HWND hwnd, int nIDEvent, WORD wElapse,
									FARPROC lpTimerFunction );
									
extern WORD (FAR PASCAL *KillSystemTimer)(	HWND hwnd, int nIDEvent );
									
									
#ifdef __cplusplus
		}
#endif 
                                                                        
