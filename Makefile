all:
	dmd rotate.d ~/arsd/{simpledisplay,color,eventloop,joystick,simpleaudio,stb_truetype,gamehelpers}.d -version=with_eventloop -debug -gc -version=rotate_3d -J/home/me/arsd
	#dmdw rotate.d ~/arsd/{simpledisplay,color,joystick,simpleaudio}.d -version=with_opengl
